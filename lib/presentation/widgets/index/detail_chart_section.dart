import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/ohlc_data.dart';
import '../../../data/services/technical_indicator_service.dart';
import 'detail_candlestick_painter.dart';
import 'sub_chart_painters.dart';

/// 상세 차트 섹션 (줌/스크롤, 지표 토글, 기간 선택 포함)
class DetailChartSection extends StatefulWidget {
  final List<OHLCData> chartData;
  final String selectedPeriod;
  final ValueChanged<String> onPeriodChanged;
  final bool showPivotLines;
  final Map<String, double>? pivotLevels;
  final TechnicalIndicatorService indicatorService;

  const DetailChartSection({
    super.key,
    required this.chartData,
    required this.selectedPeriod,
    required this.onPeriodChanged,
    required this.showPivotLines,
    this.pivotLevels,
    required this.indicatorService,
  });

  @override
  State<DetailChartSection> createState() => _DetailChartSectionState();
}

class _DetailChartSectionState extends State<DetailChartSection> {
  // 줌/스크롤 상태 (모든 차트 동기화용)
  int _visibleCount = 80;
  int _scrollOffset = 0;
  int _startVisibleCount = 80;
  static const int _minVisible = 20;
  static const int _maxVisible = 200;

  // 보조 지표 토글 상태
  Set<String> _activeIndicators = {'VOL'};

  @override
  void initState() {
    super.initState();
    // 최신 데이터가 보이도록 스크롤 위치 설정
    if (widget.chartData.isNotEmpty) {
      _scrollOffset = (widget.chartData.length - _visibleCount).clamp(0, widget.chartData.length);
    }
  }

  @override
  void didUpdateWidget(DetailChartSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // chartData가 변경되면 스크롤 위치 재설정
    if (widget.chartData.length != oldWidget.chartData.length) {
      _scrollOffset = (widget.chartData.length - _visibleCount).clamp(0, widget.chartData.length);
    }
  }

  void _handleZoomScroll(ScaleUpdateDetails details, double chartWidth) {
    setState(() {
      final totalLen = widget.chartData.length;
      if (details.scale != 1.0) {
        // 우측(최신 데이터) 고정
        final rightEdge = _scrollOffset + _visibleCount;
        _visibleCount = (_startVisibleCount / details.scale).round().clamp(_minVisible, _maxVisible);
        final maxOff = (totalLen - _visibleCount).clamp(0, totalLen);
        _scrollOffset = (rightEdge - _visibleCount).clamp(0, maxOff);
      }
      if (details.pointerCount == 1) {
        final dx = details.focalPointDelta.dx;
        final candleWidth = chartWidth / _visibleCount;
        final candleShift = (dx / candleWidth).round();
        if (candleShift != 0) {
          final maxOff = (totalLen - _visibleCount).clamp(0, totalLen);
          _scrollOffset = (_scrollOffset - candleShift).clamp(0, maxOff);
        }
      }
    });
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      GestureBinding.instance.pointerSignalResolver.register(event, (PointerSignalEvent resolvedEvent) {
        final scrollEvent = resolvedEvent as PointerScrollEvent;
        setState(() {
          final totalLen = widget.chartData.length;
          // 우측(최신 데이터) 고정: 줌 전 우측 끝 위치 기억
          final rightEdge = _scrollOffset + _visibleCount;
          final delta = scrollEvent.scrollDelta.dy > 0 ? 5 : -5;
          _visibleCount = (_visibleCount + delta).clamp(_minVisible, _maxVisible);
          // 우측 끝을 고정한 채 offset 재계산
          final maxOff = (totalLen - _visibleCount).clamp(0, totalLen);
          _scrollOffset = (rightEdge - _visibleCount).clamp(0, maxOff);
        });
      });
    }
  }

  String _formatVolume(double v) {
    final absV = v.abs();
    final sign = v < 0 ? '-' : '';
    if (absV >= 1e9) return '$sign${(absV / 1e9).toStringAsFixed(1)}B';
    if (absV >= 1e6) return '$sign${(absV / 1e6).toStringAsFixed(1)}M';
    if (absV >= 1e3) return '$sign${(absV / 1e3).toStringAsFixed(0)}K';
    return '$sign${absV.toStringAsFixed(0)}';
  }

  double? _lastNonNull(List<double?> values) {
    for (int i = values.length - 1; i >= 0; i--) {
      if (values[i] != null) return values[i];
    }
    return null;
  }

  T? _lastValid<T>(List<T> values, bool Function(T) isValid) {
    for (int i = values.length - 1; i >= 0; i--) {
      if (isValid(values[i])) return values[i];
    }
    return null;
  }

  List<double> _calculateMA(List<OHLCData> data, int period) {
    if (data.length < period) return [];
    final result = <double>[];
    for (int i = 0; i < data.length; i++) {
      if (i < period - 1) {
        result.add(double.nan);
      } else {
        double sum = 0;
        for (int j = i - period + 1; j <= i; j++) {
          sum += data[j].close;
        }
        result.add(sum / period);
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.chartData.isEmpty) {
      return Container(
        color: context.appSurface,
        padding: const EdgeInsets.all(16),
        child: Center(child: Text('차트 데이터 없음', style: TextStyle(color: context.appTextHint))),
      );
    }

    final totalLen = widget.chartData.length;
    final visible = _visibleCount.clamp(_minVisible, totalLen.clamp(_minVisible, _maxVisible));
    final maxOffset = (totalLen - visible).clamp(0, totalLen);
    final offset = _scrollOffset.clamp(0, maxOffset);
    final end = (offset + visible).clamp(0, totalLen);

    final displayData = widget.chartData.sublist(offset, end);

    // MA 계산
    final ma5 = _calculateMA(widget.chartData, 5);
    final ma20 = _calculateMA(widget.chartData, 20);
    final ma60 = _calculateMA(widget.chartData, 60);
    final ma120 = _calculateMA(widget.chartData, 120);

    List<double> sliceMA(List<double> ma) {
      if (ma.length <= offset) return [];
      return ma.sublist(offset, end.clamp(0, ma.length));
    }

    final displayMa5 = sliceMA(ma5);
    final displayMa20 = sliceMA(ma20);
    final displayMa60 = sliceMA(ma60);
    final displayMa120 = sliceMA(ma120);

    // 보조 지표 계산 (활성화된 것만)
    final closes = widget.chartData.map((e) => e.close).toList();
    final lastClose = closes.last;

    // BB
    List<BBResult>? displayBB;
    IndicatorSignal? bbSignal;
    String? bbSummary;
    if (_activeIndicators.contains('BB')) {
      final bb = widget.indicatorService.calculateBollingerBands(closes);
      displayBB = bb.sublist(offset, end.clamp(0, bb.length));
      final lastBB = _lastValid(bb, (b) => b.upper != null);
      if (lastBB != null) {
        bbSignal = widget.indicatorService.getBBSignal(lastClose, lastBB);
        bbSummary = 'BB: 상단 ${lastBB.upper!.toStringAsFixed(1)} / 중심 ${lastBB.middle!.toStringAsFixed(1)} / 하단 ${lastBB.lower!.toStringAsFixed(1)}';
      }
    }

    // Ichimoku
    List<IchimokuResult>? displayIchimoku;
    IndicatorSignal? ichSignal;
    String? ichSummary;
    if (_activeIndicators.contains('ICH')) {
      final ich = widget.indicatorService.calculateIchimoku(widget.chartData);
      displayIchimoku = ich.sublist(offset, end.clamp(0, ich.length));
      final lastIch = _lastValid(ich, (i) => i.tenkan != null);
      if (lastIch != null) {
        ichSignal = widget.indicatorService.getIchimokuSignal(lastClose, lastIch);
        final cloudDir = (lastIch.senkouA != null && lastIch.senkouB != null)
            ? (lastClose > (lastIch.senkouA! > lastIch.senkouB! ? lastIch.senkouA! : lastIch.senkouB!) ? '▲' : '▼')
            : '-';
        ichSummary = '일목: 전환 ${lastIch.tenkan?.toStringAsFixed(1) ?? '-'} 기준 ${lastIch.kijun?.toStringAsFixed(1) ?? '-'} 구름 $cloudDir';
      }
    }

    // RSI
    List<double?>? displayRSI;
    IndicatorSignal? rsiSignal;
    if (_activeIndicators.contains('RSI')) {
      final rsi = widget.indicatorService.calculateRSI(closes);
      displayRSI = rsi.sublist(offset, end.clamp(0, rsi.length));
      final lastRsi = _lastNonNull(rsi);
      if (lastRsi != null) {
        rsiSignal = widget.indicatorService.getRSISignal(lastRsi);
      }
    }

    // MACD
    List<MACDResult>? displayMACD;
    IndicatorSignal? macdSignal;
    if (_activeIndicators.contains('MACD')) {
      final macd = widget.indicatorService.calculateMACD(closes);
      displayMACD = macd.sublist(offset, end.clamp(0, macd.length));
      final lastMacd = _lastValid(macd, (m) => m.macdLine != null);
      final prevMacd = macd.length >= 2 ? _lastValid(macd.sublist(0, macd.length - 1), (m) => m.macdLine != null) : null;
      if (lastMacd != null) {
        macdSignal = widget.indicatorService.getMACDSignal(lastMacd, prevMacd);
      }
    }

    // Stochastic
    List<StochResult>? displayStoch;
    IndicatorSignal? stochSignal;
    if (_activeIndicators.contains('STOCH')) {
      final stoch = widget.indicatorService.calculateStochastic(widget.chartData);
      displayStoch = stoch.sublist(offset, end.clamp(0, stoch.length));
      final lastStoch = _lastValid(stoch, (s) => s.k != null);
      final prevStoch = stoch.length >= 2 ? _lastValid(stoch.sublist(0, stoch.length - 1), (s) => s.k != null) : null;
      if (lastStoch != null) {
        stochSignal = widget.indicatorService.getStochSignal(lastStoch, prevStoch);
      }
    }

    // OBV
    List<double>? displayOBV;
    IndicatorSignal? obvSignal;
    if (_activeIndicators.contains('OBV')) {
      final obv = widget.indicatorService.calculateOBV(widget.chartData);
      displayOBV = obv.sublist(offset, end.clamp(0, obv.length));
      if (obv.length >= 10) {
        obvSignal = widget.indicatorService.getOBVSignal(obv, closes);
      }
    }

    // Volume current value
    String? volCurrentValue;
    if (_activeIndicators.contains('VOL') && displayData.isNotEmpty) {
      volCurrentValue = _formatVolume(displayData.last.volume);
    }

    // RSI 현재값 라벨
    String? rsiLabel;
    if (_activeIndicators.contains('RSI') && displayRSI != null) {
      final lastRsi = _lastNonNull(displayRSI!);
      rsiLabel = lastRsi != null ? 'RSI(14): ${lastRsi.toStringAsFixed(1)}' : 'RSI(14)';
    }

    // MACD 현재값 라벨
    String? macdLabel;
    if (_activeIndicators.contains('MACD') && displayMACD != null) {
      final lastMacd = _lastValid(displayMACD!, (m) => m.macdLine != null);
      if (lastMacd != null) {
        final m = lastMacd.macdLine?.toStringAsFixed(2) ?? '-';
        final s = lastMacd.signalLine?.toStringAsFixed(2) ?? '-';
        macdLabel = 'MACD: $m / Signal: $s';
      } else {
        macdLabel = 'MACD(12,26,9)';
      }
    }

    // STOCH 현재값 라벨
    String? stochLabel;
    if (_activeIndicators.contains('STOCH') && displayStoch != null) {
      final lastStoch = _lastValid(displayStoch!, (s) => s.k != null);
      if (lastStoch != null) {
        final kStr = lastStoch.k?.toStringAsFixed(1) ?? '-';
        final dStr = lastStoch.d?.toStringAsFixed(1) ?? '-';
        stochLabel = '%K: $kStr  %D: $dStr';
      } else {
        stochLabel = 'STOCH(14,3)';
      }
    }

    // OBV 현재값 라벨
    String? obvLabel;
    if (_activeIndicators.contains('OBV') && displayOBV != null && displayOBV!.isNotEmpty) {
      obvLabel = 'OBV: ${_formatVolume(displayOBV!.last)}';
    }

    return Container(
      color: context.appSurface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 지표 선택 칩
          _buildIndicatorChips(),
          const SizedBox(height: 8),
          // 기간 선택 + MA 범례 한 줄
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildPeriodSelector(),
                const SizedBox(width: 12),
                _legendItem('5일', const Color(0xFFFF6B6B)),
                _legendItem('20일', const Color(0xFFFFD93D)),
                _legendItem('60일', const Color(0xFF6BCB77)),
                _legendItem('120일', const Color(0xFF4D96FF)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // 차트 영역 (제스처로 줌/스크롤) + 우측 여백(페이지 스크롤용)
          LayoutBuilder(
            builder: (context, constraints) {
              // 데스크톱/태블릿에서 우측 여백 추가 (마우스 휠로 페이지 스크롤 가능 영역)
              final screenWidth = MediaQuery.of(context).size.width;
              final rightMargin = screenWidth >= 768 ? 40.0 : 0.0;
              final chartWidth = constraints.maxWidth - rightMargin;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 차트 영역 (휠 = 줌, 드래그 = 스크롤)
                  SizedBox(
                    width: chartWidth,
                    child: GestureDetector(
                      onScaleStart: (_) => _startVisibleCount = _visibleCount,
                      onScaleUpdate: (details) => _handleZoomScroll(details, chartWidth),
                      child: Listener(
                        onPointerSignal: _handlePointerSignal,
                        child: Column(
                          children: [
                            // 메인 캔들스틱 차트 (+ BB, Ichimoku 오버레이)
                            SizedBox(
                              height: 280,
                              child: CustomPaint(
                                size: Size(chartWidth, 280),
                                painter: DetailCandlestickPainter(
                                  data: displayData,
                                  ma5: displayMa5,
                                  ma20: displayMa20,
                                  ma60: displayMa60,
                                  ma120: displayMa120,
                                  selectedPeriod: widget.selectedPeriod,
                                  showPivotLines: widget.showPivotLines,
                                  pivotLevels: widget.showPivotLines ? widget.pivotLevels : null,
                                  bollingerBands: displayBB,
                                  ichimoku: displayIchimoku,
                                  bbSummary: bbSummary,
                                  ichSummary: ichSummary,
                                  bbSignal: bbSignal,
                                  ichSignal: ichSignal,
                                  isDarkMode: Theme.of(context).brightness == Brightness.dark,
                                  textColor: context.appTextSecondary,
                                  cardBgColor: context.appSurface,
                                ),
                              ),
                            ),
                            // 거래량 서브차트
                            if (_activeIndicators.contains('VOL')) ...[
                              _buildSubChartHeader(
                                label: volCurrentValue != null ? 'VOL: $volCurrentValue' : 'VOL',
                                labelColor: context.appTextSecondary,
                              ),
                              SizedBox(
                                height: 50,
                                child: CustomPaint(
                                  size: Size(chartWidth, 50),
                                  painter: VolumePainter(
                                    data: displayData,
                                    isDarkMode: Theme.of(context).brightness == Brightness.dark,
                                    textColor: context.appTextSecondary,
                                  ),
                                ),
                              ),
                            ],
                            // RSI 서브차트
                            if (_activeIndicators.contains('RSI') && displayRSI != null) ...[
                              _buildSubChartHeader(
                                label: rsiLabel ?? 'RSI(14)',
                                labelColor: Theme.of(context).brightness == Brightness.dark
                                    ? const Color(0xFFCE93D8) : const Color(0xFF7B1FA2),
                                signal: rsiSignal,
                              ),
                              SizedBox(
                                height: 100,
                                child: CustomPaint(
                                  size: Size(chartWidth, 100),
                                  painter: RSIPainter(
                                    rsiValues: displayRSI,
                                    isDarkMode: Theme.of(context).brightness == Brightness.dark,
                                    textColor: context.appTextSecondary,
                                  ),
                                ),
                              ),
                            ],
                            // MACD 서브차트
                            if (_activeIndicators.contains('MACD') && displayMACD != null) ...[
                              _buildSubChartHeader(
                                label: macdLabel ?? 'MACD(12,26,9)',
                                labelColor: const Color(0xFF2196F3),
                                signal: macdSignal,
                              ),
                              SizedBox(
                                height: 100,
                                child: CustomPaint(
                                  size: Size(chartWidth, 100),
                                  painter: MACDPainter(
                                    macdValues: displayMACD,
                                    isDarkMode: Theme.of(context).brightness == Brightness.dark,
                                    textColor: context.appTextSecondary,
                                  ),
                                ),
                              ),
                            ],
                            // 스토캐스틱 서브차트
                            if (_activeIndicators.contains('STOCH') && displayStoch != null) ...[
                              _buildSubChartHeader(
                                label: stochLabel ?? 'STOCH(14,3)',
                                labelColor: const Color(0xFF2196F3),
                                signal: stochSignal,
                              ),
                              SizedBox(
                                height: 100,
                                child: CustomPaint(
                                  size: Size(chartWidth, 100),
                                  painter: StochasticPainter(
                                    stochValues: displayStoch,
                                    isDarkMode: Theme.of(context).brightness == Brightness.dark,
                                    textColor: context.appTextSecondary,
                                  ),
                                ),
                              ),
                            ],
                            // OBV 서브차트
                            if (_activeIndicators.contains('OBV') && displayOBV != null) ...[
                              _buildSubChartHeader(
                                label: obvLabel ?? 'OBV',
                                labelColor: const Color(0xFF10B981),
                                signal: obvSignal,
                              ),
                              SizedBox(
                                height: 80,
                                child: CustomPaint(
                                  size: Size(chartWidth, 80),
                                  painter: OBVPainter(
                                    obvValues: displayOBV,
                                    isDarkMode: Theme.of(context).brightness == Brightness.dark,
                                    textColor: context.appTextSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  // 우측 여백 (마우스 휠 = 페이지 스크롤)
                  if (rightMargin > 0)
                    SizedBox(width: rightMargin),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    const periods = ['일봉', '주봉', '월봉'];
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: context.appIconBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: periods.map((period) {
          final isSelected = period == widget.selectedPeriod;
          return GestureDetector(
            onTap: () => widget.onPeriodChanged(period),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: isSelected ? context.appSurface.withValues(alpha: 0.5) : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                boxShadow: isSelected
                    ? [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 4, offset: const Offset(0, 1))]
                    : null,
              ),
              child: Text(
                period,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? context.appTextPrimary : context.appTextHint,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildIndicatorChips() {
    const indicators = [
      {'key': 'VOL', 'label': 'VOL'},
      {'key': 'BB', 'label': 'BB'},
      {'key': 'RSI', 'label': 'RSI'},
      {'key': 'MACD', 'label': 'MACD'},
      {'key': 'STOCH', 'label': 'STOCH'},
      {'key': 'ICH', 'label': '일목'},
      {'key': 'OBV', 'label': 'OBV'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: indicators.map((ind) {
          final key = ind['key']!;
          final label = ind['label']!;
          final isActive = _activeIndicators.contains(key);

          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  if (isActive) {
                    _activeIndicators.remove(key);
                  } else {
                    _activeIndicators.add(key);
                  }
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isActive ? context.appSurface : context.appIconBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isActive ? context.appBorder : context.appDivider,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                        color: isActive ? context.appTextPrimary : context.appTextHint,
                      ),
                    ),
                    const SizedBox(width: 3),
                    GestureDetector(
                      onTap: () => _showIndicatorHelpDialog(key),
                      child: Icon(Icons.help_outline, size: 14, color: context.appTextHint),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showIndicatorHelpDialog(String key) {
    String title;
    String description;

    switch (key) {
      case 'VOL':
        title = '거래량 (Volume)';
        description = '거래량은 일정 기간 동안 거래된 주식의 수량입니다.\n\n'
            '• 양봉(상승): 빨간색 바\n'
            '• 음봉(하락): 파란색 바\n'
            '• 거래량 급증: 큰 관심 또는 추세 전환 신호\n'
            '• 상승 + 거래량 증가: 강한 상승 추세\n'
            '• 상승 + 거래량 감소: 상승 피로, 반전 가능';
        break;
      case 'RSI':
        title = 'RSI (14)';
        description = 'RSI(Relative Strength Index)는 주가의 상승/하락 강도를 0~100으로 나타내는 지표입니다.\n\n'
            '• 공식: RSI = 100 - (100 / (1 + RS))\n'
            '  RS = 14일간 평균 상승폭 / 평균 하락폭\n\n'
            '• 70 이상: 과매수 구간 (매도 검토)\n'
            '• 30 이하: 과매도 구간 (매수 검토)\n'
            '• 50 위: 상승 추세, 50 아래: 하락 추세\n\n'
            '다이버전스:\n'
            '• 가격은 신고가인데 RSI는 하락 → 하락 반전 신호\n'
            '• 가격은 신저가인데 RSI는 상승 → 상승 반전 신호';
        break;
      case 'MACD':
        title = 'MACD (12,26,9)';
        description = 'MACD는 두 이동평균선의 차이로 추세와 모멘텀을 분석하는 지표입니다.\n\n'
            '• MACD선 (파랑): 12일 EMA - 26일 EMA\n'
            '• 시그널선 (주황): MACD의 9일 EMA\n'
            '• 히스토그램: MACD선 - 시그널선\n\n'
            '매매 신호:\n'
            '• 골든크로스: MACD선이 시그널선을 상향 돌파 → 매수\n'
            '• 데드크로스: MACD선이 시그널선을 하향 돌파 → 매도\n'
            '• 히스토그램 양전환: 상승 모멘텀 강화\n'
            '• 히스토그램 음전환: 하락 모멘텀 강화';
        break;
      case 'BB':
        title = '볼린저 밴드 (20,2)';
        description = '볼린저 밴드는 이동평균선 위아래로 표준편차 밴드를 그려 변동성을 분석합니다.\n\n'
            '• 상한밴드 (빨강): 20일 SMA + 2σ\n'
            '• 중심밴드 (점선): 20일 SMA\n'
            '• 하한밴드 (파랑): 20일 SMA - 2σ\n\n'
            '매매 신호:\n'
            '• 상한밴드 돌파: 과매수 (매도 검토)\n'
            '• 하한밴드 돌파: 과매도 (매수 검토)\n'
            '• 밴드 수축 (스퀴즈): 변동성 감소 → 큰 움직임 예고\n'
            '• 밴드워크: 밴드를 따라 이동하면 강한 추세';
        break;
      case 'STOCH':
        title = '스토캐스틱 (14,3)';
        description = '스토캐스틱은 현재가가 일정 기간의 고가-저가 범위 중 어디에 위치하는지 보여줍니다.\n\n'
            '• %K (파랑): 현재 위치 (빠른 선)\n'
            '• %D (주황): %K의 3일 이동평균 (느린 선)\n\n'
            '매매 신호:\n'
            '• 80 이상: 과매수 구간 (매도 검토)\n'
            '• 20 이하: 과매도 구간 (매수 검토)\n'
            '• %K가 %D를 상향 돌파 (골든크로스) → 매수\n'
            '• %K가 %D를 하향 돌파 (데드크로스) → 매도\n'
            '• 과매도 구간에서 골든크로스 → 강한 매수 신호';
        break;
      case 'ICH':
        title = '일목균형표';
        description = '일목균형표는 추세, 지지/저항, 모멘텀을 한눈에 보여주는 일본식 기술 지표입니다.\n\n'
            '• 전환선 (빨강): 9일 중간값\n'
            '• 기준선 (파랑): 26일 중간값\n'
            '• 구름 (선행스팬 A+B): 미래 지지/저항 영역\n'
            '• 후행스팬 (초록): 현재가를 26일 전에 표시\n\n'
            '매매 신호:\n'
            '• 가격이 구름 위: 상승 추세\n'
            '• 가격이 구름 아래: 하락 추세\n'
            '• 전환선 > 기준선: 매수 신호\n'
            '• 구름 두께: 지지/저항 강도 표시';
        break;
      case 'OBV':
        title = 'OBV (On-Balance Volume)';
        description = 'OBV는 거래량의 누적 흐름으로 매수/매도 압력을 측정합니다.\n\n'
            '• 계산: 가격 상승일 → OBV + 거래량\n'
            '        가격 하락일 → OBV - 거래량\n\n'
            '매매 신호:\n'
            '• OBV 상승 + 가격 상승: 상승 추세 확인\n'
            '• OBV 하락 + 가격 하락: 하락 추세 확인\n'
            '• OBV 상승 + 가격 하락 (상승 다이버전스): 반등 신호\n'
            '• OBV 하락 + 가격 상승 (하락 다이버전스): 하락 전환 신호';
        break;
      default:
        return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.appSurface,
        title: Text(
          title,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: context.appTextPrimary),
        ),
        content: SingleChildScrollView(
          child: Text(
            description,
            style: TextStyle(fontSize: 13, color: context.appTextSecondary, height: 1.6),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  Widget _legendItem(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 12, height: 2, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  /// 서브차트 헤더 (라벨 + 신호배지)
  Widget _buildSubChartHeader({
    required String label,
    required Color labelColor,
    IndicatorSignal? signal,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 2),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(color: labelColor, fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          if (signal != null) _buildSignalBadge(signal),
        ],
      ),
    );
  }

  /// 신호 배지 위젯
  Widget _buildSignalBadge(IndicatorSignal signal) {
    Color bgColor;
    Color fgColor;
    switch (signal.type) {
      case SignalType.strongBuy:
        bgColor = AppColors.stockUp.withAlpha(40);
        fgColor = AppColors.stockUp;
        break;
      case SignalType.buy:
        bgColor = AppColors.stockUp.withAlpha(25);
        fgColor = AppColors.stockUp;
        break;
      case SignalType.neutral:
        bgColor = context.appIconBg;
        fgColor = context.appTextHint;
        break;
      case SignalType.sell:
        bgColor = AppColors.stockDown.withAlpha(25);
        fgColor = AppColors.stockDown;
        break;
      case SignalType.strongSell:
        bgColor = AppColors.stockDown.withAlpha(40);
        fgColor = AppColors.stockDown;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        signal.label,
        style: TextStyle(color: fgColor, fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}
