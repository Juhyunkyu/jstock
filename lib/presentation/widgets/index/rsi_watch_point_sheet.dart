import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/ohlc_data.dart';
import '../../../data/models/rsi_watch_point.dart';
import '../../../data/services/technical_indicator_service.dart';
import '../../providers/rsi_divergence_providers.dart';

const _uuid = Uuid();

/// 선택된 기간(한글) -> interval 문자열 변환
String _periodToInterval(String selectedPeriod) {
  switch (selectedPeriod) {
    case '주봉':
      return '1week';
    case '월봉':
      return '1month';
    case '일봉':
    default:
      return '1day';
  }
}

/// interval 문자열 -> 한글 레이블
String _intervalLabel(String interval) {
  switch (interval) {
    case '1week':
      return '주봉';
    case '1month':
      return '월봉';
    case '1day':
    default:
      return '일봉';
  }
}

// ================================================================
// 감시점 설정 바텀시트 (신규)
// ================================================================

void showWatchPointSetupSheet({
  required BuildContext context,
  required WidgetRef ref,
  required String symbol,
  required DateTime date,
  required double price,
  required double rsi,
  required String selectedPeriod,
  List<OHLCData>? chartData,
  TechnicalIndicatorService? indicatorService,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => _WatchPointSetupSheet(
      ref: ref,
      symbol: symbol,
      date: date,
      price: price,
      rsi: rsi,
      selectedPeriod: selectedPeriod,
      chartData: chartData,
      indicatorService: indicatorService,
    ),
  );
}

class _WatchPointSetupSheet extends StatefulWidget {
  final WidgetRef ref;
  final String symbol;
  final DateTime date;
  final double price;
  final double rsi;
  final String selectedPeriod;
  final List<OHLCData>? chartData;
  final TechnicalIndicatorService? indicatorService;

  const _WatchPointSetupSheet({
    required this.ref,
    required this.symbol,
    required this.date,
    required this.price,
    required this.rsi,
    required this.selectedPeriod,
    this.chartData,
    this.indicatorService,
  });

  @override
  State<_WatchPointSetupSheet> createState() => _WatchPointSetupSheetState();
}

class _WatchPointSetupSheetState extends State<_WatchPointSetupSheet> {
  late int _mode;

  @override
  void initState() {
    super.initState();
    // 자동 모드 추천
    if (widget.rsi >= 60) {
      _mode = RsiWatchMode.bearish;
    } else if (widget.rsi <= 40) {
      _mode = RsiWatchMode.bullish;
    } else {
      _mode = RsiWatchMode.bearish; // 기본값
    }
  }

  void _submit() {
    final point = RsiWatchPoint(
      id: _uuid.v4(),
      ticker: widget.symbol,
      mode: _mode,
      watchPrice: widget.price,
      watchRsi: widget.rsi,
      watchDate: widget.date,
      interval: _periodToInterval(widget.selectedPeriod),
    );
    widget.ref.read(rsiWatchPointProvider.notifier).addWatchPoint(point);

    // chartData/indicatorService를 pop 전에 캡처 (pop 후 widget 접근 불가)
    final chartData = widget.chartData;
    final indicatorService = widget.indicatorService;
    final ref = widget.ref;
    final scaffoldMessenger = ScaffoldMessenger.of(context); // pop 전에 캡처

    Navigator.of(context).pop();

    // 과거 돌파 즉시 체크
    if (chartData != null && indicatorService != null) {
      _checkHistoricalBreach(point, chartData, indicatorService, ref, scaffoldMessenger);
    }
  }

  /// 감시점 설정 직후, 이미 로드된 차트 데이터에서 과거 돌파를 즉시 확인
  /// BB 터치 필터 + 자동 갱신 루프 적용
  void _checkHistoricalBreach(
    RsiWatchPoint point,
    List<OHLCData> chartData,
    TechnicalIndicatorService indicatorService,
    WidgetRef ref,
    ScaffoldMessengerState scaffoldMessenger,
  ) {
    // 감시점 날짜의 인덱스 찾기
    int watchIndex = -1;
    for (int i = 0; i < chartData.length; i++) {
      final d = chartData[i].date;
      if (d.year == point.watchDate.year &&
          d.month == point.watchDate.month &&
          d.day == point.watchDate.day) {
        watchIndex = i;
        break;
      }
    }
    if (watchIndex < 0) return;

    // RSI + BB 계산
    final closes = chartData.map((d) => d.close).toList();
    final rsiValues = indicatorService.calculateRSI(closes);
    final bbValues = indicatorService.calculateBollingerBands(closes);

    // 지역 변수로 현재 감시 기준 (자동 갱신 시 변경됨)
    double currentWatchPrice = point.watchPrice;
    double currentWatchRsi = point.watchRsi;
    DateTime currentWatchDate = point.watchDate;
    bool divergenceFound = false;
    int? divergenceIndex;
    double? divergenceRsi;
    double? divergencePrice;

    debugPrint('[RsiWatch] watchIndex=$watchIndex, mode=${point.mode == RsiWatchMode.bearish ? "bearish" : "bullish"}, watchPrice=${point.watchPrice}, watchRsi=${point.watchRsi}');
    debugPrint('[RsiWatch] chartData.length=${chartData.length}, rsiValues.length=${rsiValues.length}, bbValues.length=${bbValues.length}');

    int priceBreachCount = 0;
    int bbTouchCount = 0;

    // 감시점 이후 캔들 순회
    for (int i = watchIndex + 1; i < chartData.length; i++) {
      if (i >= rsiValues.length || rsiValues[i] == null) continue;
      if (i >= bbValues.length) continue;
      final bb = bbValues[i];

      // 1. 가격 돌파 체크
      bool priceBreached;
      if (point.mode == RsiWatchMode.bearish) {
        priceBreached = chartData[i].high > currentWatchPrice;
      } else {
        priceBreached = chartData[i].low < currentWatchPrice;
      }
      if (!priceBreached) continue;
      priceBreachCount++;

      // 2. BB 터치 체크
      bool bbTouched;
      if (point.mode == RsiWatchMode.bearish) {
        bbTouched = bb.upper != null && chartData[i].high >= bb.upper!;
      } else {
        bbTouched = bb.lower != null && chartData[i].low <= bb.lower!;
      }
      if (!bbTouched) {
        if (priceBreachCount <= 3) {
          debugPrint('[RsiWatch] [$i] price breached but BB NOT touched: high=${chartData[i].high}, bb.upper=${bb.upper}, low=${chartData[i].low}, bb.lower=${bb.lower}');
        }
        continue;
      }
      bbTouchCount++;
      debugPrint('[RsiWatch] [$i] BB TOUCHED! high=${chartData[i].high}, bb.upper=${bb.upper}, low=${chartData[i].low}, bb.lower=${bb.lower}, rsi=${rsiValues[i]}');

      // 3. RSI 비교
      final candleRsi = rsiValues[i]!;
      bool isDivergence;
      if (point.mode == RsiWatchMode.bearish) {
        isDivergence = candleRsi < currentWatchRsi;
      } else {
        isDivergence = candleRsi > currentWatchRsi;
      }

      if (isDivergence) {
        // 다이버전스 확정!
        divergenceFound = true;
        divergenceIndex = i;
        divergenceRsi = candleRsi;
        divergencePrice = chartData[i].close;
        break;
      } else {
        // 다이버전스 아님 → 이 지점을 새 기준점으로 자동 갱신
        if (point.mode == RsiWatchMode.bearish) {
          currentWatchPrice = chartData[i].high;
        } else {
          currentWatchPrice = chartData[i].low;
        }
        currentWatchRsi = candleRsi;
        currentWatchDate = chartData[i].date;
        // 루프 계속 (다음 돌파 찾기)
      }
    }

    debugPrint('[RsiWatch] Result: priceBreaches=$priceBreachCount, bbTouches=$bbTouchCount, divergence=$divergenceFound, renewed=${currentWatchPrice != point.watchPrice}');

    if (divergenceFound && divergenceIndex != null) {
      // 다이버전스 확인 → 감시점 트리거 + 알림
      ref.read(rsiWatchPointProvider.notifier).markTriggered(
        point.id,
        triggeredPrice: divergencePrice!,
        triggeredRsi: divergenceRsi!,
      );
      _showDivergenceResult(point, divergencePrice!, divergenceRsi!, chartData[divergenceIndex!].date, scaffoldMessenger);
    } else if (currentWatchPrice != point.watchPrice || currentWatchRsi != point.watchRsi) {
      // 자동 갱신 발생 (다이버전스 없이 기준점만 업데이트)
      // Hive 업데이트: 새 기준점으로 감시점 갱신
      final updatedPoint = RsiWatchPoint(
        id: point.id,
        ticker: point.ticker,
        mode: point.mode,
        watchPrice: currentWatchPrice,
        watchRsi: currentWatchRsi,
        watchDate: currentWatchDate,
        interval: point.interval,
        createdAt: point.createdAt,
        isActive: true,
        rsiPeriod: point.rsiPeriod,
      );
      ref.read(rsiWatchPointProvider.notifier).updateWatchPoint(updatedPoint);

      debugPrint('[RsiWatch] Auto-renewed: ${point.ticker} → price=$currentWatchPrice, RSI=$currentWatchRsi');
    }
    // 돌파 자체가 없었으면 아무것도 안 함 (미래 실시간 감시 대기)
  }

  /// 과거 돌파 다이버전스 결과를 SnackBar로 즉시 표시
  void _showDivergenceResult(
    RsiWatchPoint point,
    double breachPrice,
    double breachRsi,
    DateTime breachDate,
    ScaffoldMessengerState scaffoldMessenger,
  ) {
    final isBearish = point.mode == RsiWatchMode.bearish;
    final modeLabel = isBearish ? '하락' : '상승';

    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Text(
          '$modeLabel 다이버전스 감지!\n'
          'RSI ${point.watchRsi.toStringAsFixed(1)} -> ${breachRsi.toStringAsFixed(1)}  '
          '(\$${breachPrice.toStringAsFixed(2)}, ${DateFormat('yyyy-MM-dd').format(breachDate)})',
        ),
        backgroundColor: isBearish ? AppColors.red500 : AppColors.blue500,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final cardBg = isDark ? AppColors.darkCardBackground : AppColors.cardBackground;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final accent = isDark ? AppColors.darkAccent : AppColors.primary;
    final dateFmt = DateFormat('yyyy-MM-dd');

    final isBearish = _mode == RsiWatchMode.bearish;
    final directionText = isBearish
        ? '\$${widget.price.toStringAsFixed(2)}를 위로 돌파하면'
        : '\$${widget.price.toStringAsFixed(2)}를 아래로 이탈하면';

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 드래그 핸들
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkBorder : AppColors.gray300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'RSI 다이버전스 감시점 설정',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 16),

            // 종목 / 날짜 / 가격 / RSI 정보
            _InfoRow(label: '종목', value: widget.symbol, textColor: textPrimary, labelColor: textSecondary),
            const SizedBox(height: 8),
            _InfoRow(label: '날짜', value: dateFmt.format(widget.date), textColor: textPrimary, labelColor: textSecondary),
            const SizedBox(height: 8),
            _InfoRow(label: '가격', value: '\$${widget.price.toStringAsFixed(2)}', textColor: textPrimary, labelColor: textSecondary),
            const SizedBox(height: 8),
            _InfoRow(label: 'RSI', value: widget.rsi.toStringAsFixed(1), textColor: textPrimary, labelColor: textSecondary),
            const SizedBox(height: 8),
            _InfoRow(label: '차트', value: widget.selectedPeriod, textColor: textPrimary, labelColor: textSecondary),
            const SizedBox(height: 16),

            // 모드 선택 SegmentedButton
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<int>(
                segments: [
                  ButtonSegment<int>(
                    value: RsiWatchMode.bearish,
                    label: Text(
                      '고점 감시 (하락 div)',
                      style: TextStyle(fontSize: 12, color: _mode == RsiWatchMode.bearish ? Colors.white : textSecondary),
                    ),
                  ),
                  ButtonSegment<int>(
                    value: RsiWatchMode.bullish,
                    label: Text(
                      '저점 감시 (상승 div)',
                      style: TextStyle(fontSize: 12, color: _mode == RsiWatchMode.bullish ? Colors.white : textSecondary),
                    ),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: (sel) => setState(() => _mode = sel.first),
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return accent;
                    }
                    return isDark ? AppColors.darkSurface : AppColors.gray100;
                  }),
                  side: WidgetStateProperty.all(BorderSide(
                    color: isDark ? AppColors.darkBorder : AppColors.gray300,
                  )),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 설명 문구
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.gray50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '가격이 $directionText\nRSI를 확인하여 다이버전스를 감지합니다.',
                style: TextStyle(fontSize: 13, color: textSecondary, height: 1.5),
              ),
            ),
            const SizedBox(height: 20),

            // 설정하기 버튼
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('설정하기', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================================================================
// 감시점 관리 바텀시트 (기존 감시점 탭)
// ================================================================

void showWatchPointManageSheet({
  required BuildContext context,
  required WidgetRef ref,
  required RsiWatchPoint watchPoint,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => _WatchPointManageSheet(
      ref: ref,
      watchPoint: watchPoint,
    ),
  );
}

class _WatchPointManageSheet extends StatefulWidget {
  final WidgetRef ref;
  final RsiWatchPoint watchPoint;

  const _WatchPointManageSheet({
    required this.ref,
    required this.watchPoint,
  });

  @override
  State<_WatchPointManageSheet> createState() => _WatchPointManageSheetState();
}

class _WatchPointManageSheetState extends State<_WatchPointManageSheet> {
  late int _mode;

  @override
  void initState() {
    super.initState();
    _mode = widget.watchPoint.mode;
  }

  void _updateMode(int newMode) {
    setState(() => _mode = newMode);
    final point = widget.watchPoint;
    point.mode = newMode;
    widget.ref.read(rsiWatchPointProvider.notifier).updateWatchPoint(point);
  }

  void _togglePause() {
    widget.ref.read(rsiWatchPointProvider.notifier).toggleActive(widget.watchPoint.id);
    Navigator.of(context).pop();
  }

  void _delete() {
    widget.ref.read(rsiWatchPointProvider.notifier).removeWatchPoint(widget.watchPoint.id);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final cardBg = isDark ? AppColors.darkCardBackground : AppColors.cardBackground;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final accent = isDark ? AppColors.darkAccent : AppColors.primary;
    final dateFmt = DateFormat('yyyy-MM-dd');
    final wp = widget.watchPoint;

    final statusText = wp.isTriggered
        ? '다이버전스 감지됨'
        : wp.isActive
            ? '감시 중'
            : '일시정지';
    final statusColor = wp.isTriggered
        ? AppColors.green500
        : wp.isActive
            ? accent
            : context.appTextHint;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 드래그 핸들
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkBorder : AppColors.gray300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'RSI 감시점 관리',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 16),

            // 종목 + 모드 정보
            Text(
              '${wp.ticker}  ${RsiWatchMode.shortLabel(wp.mode)} (${RsiWatchMode.label(wp.mode)})',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: textPrimary),
            ),
            const SizedBox(height: 12),

            _InfoRow(label: '설정일', value: dateFmt.format(wp.watchDate), textColor: textPrimary, labelColor: textSecondary),
            const SizedBox(height: 6),
            _InfoRow(
              label: '가격',
              value: '\$${wp.watchPrice.toStringAsFixed(2)}',
              textColor: textPrimary,
              labelColor: textSecondary,
            ),
            const SizedBox(height: 6),
            _InfoRow(label: 'RSI', value: wp.watchRsi.toStringAsFixed(1), textColor: textPrimary, labelColor: textSecondary),
            const SizedBox(height: 6),
            _InfoRow(label: '차트', value: _intervalLabel(wp.interval), textColor: textPrimary, labelColor: textSecondary),
            const SizedBox(height: 12),

            // 트리거 결과 (있으면)
            if (wp.isTriggered) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : AppColors.green50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '다이버전스 감지 결과',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textPrimary),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '가격: \$${wp.triggeredPrice?.toStringAsFixed(2) ?? '-'}  '
                      'RSI: ${wp.triggeredRsi?.toStringAsFixed(1) ?? '-'}',
                      style: TextStyle(fontSize: 13, color: textSecondary),
                    ),
                    if (wp.triggeredAt != null)
                      Text(
                        '감지 시각: ${DateFormat('yyyy-MM-dd HH:mm').format(wp.triggeredAt!)}',
                        style: TextStyle(fontSize: 12, color: textSecondary),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // 모드 변경 (트리거 전만)
            if (!wp.isTriggered) ...[
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<int>(
                  segments: [
                    ButtonSegment<int>(
                      value: RsiWatchMode.bearish,
                      label: Text(
                        '고점 감시',
                        style: TextStyle(fontSize: 12, color: _mode == RsiWatchMode.bearish ? Colors.white : textSecondary),
                      ),
                    ),
                    ButtonSegment<int>(
                      value: RsiWatchMode.bullish,
                      label: Text(
                        '저점 감시',
                        style: TextStyle(fontSize: 12, color: _mode == RsiWatchMode.bullish ? Colors.white : textSecondary),
                      ),
                    ),
                  ],
                  selected: {_mode},
                  onSelectionChanged: (sel) => _updateMode(sel.first),
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return accent;
                      }
                      return isDark ? AppColors.darkSurface : AppColors.gray100;
                    }),
                    side: WidgetStateProperty.all(BorderSide(
                      color: isDark ? AppColors.darkBorder : AppColors.gray300,
                    )),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // 상태
            Row(
              children: [
                Text('상태: ', style: TextStyle(fontSize: 13, color: textSecondary)),
                Text(statusText, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: statusColor)),
              ],
            ),
            const SizedBox(height: 20),

            // 액션 버튼
            Row(
              children: [
                // 일시정지/재개 (트리거 전만)
                if (!wp.isTriggered)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _togglePause,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: accent,
                        side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.gray300),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        wp.isActive ? '일시정지' : '재개',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
                if (!wp.isTriggered) const SizedBox(width: 12),
                // 삭제
                Expanded(
                  child: ElevatedButton(
                    onPressed: _delete,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.red500,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('삭제', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ================================================================
// 공통 정보 행
// ================================================================

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color textColor;
  final Color labelColor;

  const _InfoRow({
    required this.label,
    required this.value,
    required this.textColor,
    required this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 50,
          child: Text(label, style: TextStyle(fontSize: 13, color: labelColor)),
        ),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: textColor)),
      ],
    );
  }
}
