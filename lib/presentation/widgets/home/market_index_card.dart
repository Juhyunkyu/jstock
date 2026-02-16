import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/ohlc_data.dart';
import '../../providers/market_data_providers.dart';
import '../shared/return_badge.dart';

/// 시장 지수 카드 - 나스닥 100 & S&P 500 나란히 표시
class MarketIndexCard extends ConsumerWidget {
  const MarketIndexCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    final nasdaqCard = _CompactIndexSection(
      title: 'NASDAQ 100',
      symbol: '^NDX',
      stateProvider: marketIndexProvider,
      onRefresh: () => ref.read(marketIndexProvider.notifier).loadNasdaqData(),
      onPeriodChanged: (range, interval) {
        ref.read(marketIndexProvider.notifier).loadChartData(
          range: range,
          interval: interval,
        );
      },
    );

    final sp500Card = _CompactIndexSection(
      title: 'S&P 500',
      symbol: '^GSPC',
      stateProvider: sp500IndexProvider,
      onRefresh: () => ref.read(sp500IndexProvider.notifier).loadSp500Data(),
      onPeriodChanged: (range, interval) {
        ref.read(sp500IndexProvider.notifier).loadChartData(
          range: range,
          interval: interval,
        );
      },
    );

    if (isMobile) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            nasdaqCard,
            const SizedBox(height: 8),
            sp500Card,
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: nasdaqCard),
          const SizedBox(width: 12),
          Expanded(child: sp500Card),
        ],
      ),
    );
  }
}

/// 컴팩트 지수 섹션 (캔들차트 + 이동평균선)
class _CompactIndexSection extends ConsumerStatefulWidget {
  final String title;
  final String symbol;
  final StateNotifierProvider<dynamic, MarketIndexState> stateProvider;
  final VoidCallback onRefresh;
  final void Function(String range, String interval) onPeriodChanged;

  const _CompactIndexSection({
    required this.title,
    required this.symbol,
    required this.stateProvider,
    required this.onRefresh,
    required this.onPeriodChanged,
  });

  @override
  ConsumerState<_CompactIndexSection> createState() => _CompactIndexSectionState();
}

class _CompactIndexSectionState extends ConsumerState<_CompactIndexSection> {
  String _selectedPeriod = '일';

  // initState에서 차트 로드 제거 - provider에서 이미 6개월 데이터 로드

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(widget.stateProvider);
    final isDesktop = MediaQuery.of(context).size.width >= 768;

    return Container(
      padding: EdgeInsets.fromLTRB(
        isDesktop ? 14 : 10, isDesktop ? 12 : 8,
        isDesktop ? 14 : 10, isDesktop ? 14 : 10,
      ),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.appBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 헤더: 지수명 + 가격 + 등락률 + 새로고침 (한 줄)
          GestureDetector(
            onTap: () {
              context.go(
                '/index/${Uri.encodeComponent(widget.symbol)}?from=home',
              );
            },
            child: Row(
              children: [
                Text(
                  widget.title,
                  style: TextStyle(
                    fontSize: isDesktop ? 15 : 13,
                    fontWeight: FontWeight.w600,
                    color: context.appTextPrimary,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.arrow_forward_ios,
                  size: isDesktop ? 12 : 10,
                  color: context.appTextHint,
                ),
                const Spacer(),
                if (state.hasData) ...[
                  Text(
                    _formatPrice(state.price),
                    style: TextStyle(
                      fontSize: isDesktop ? 16 : 14,
                      fontWeight: FontWeight.w700,
                      color: context.appTextPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(width: 5),
                  ReturnBadge(
                    value: state.changePercent,
                    size: ReturnBadgeSize.small,
                    colorScheme: ReturnBadgeColorScheme.redBlue,
                    decimals: 2,
                    showIcon: false,
                  ),
                ] else
                  Text(
                    '-',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: context.appTextHint,
                    ),
                  ),
                const SizedBox(width: 8),
                if (state.isLoading)
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: context.appTextHint,
                    ),
                  )
                else
                  GestureDetector(
                    onTap: widget.onRefresh,
                    behavior: HitTestBehavior.opaque,
                    child: Icon(
                      Icons.refresh_rounded,
                      size: isDesktop ? 16 : 14,
                      color: context.appTextHint,
                    ),
                  ),
              ],
            ),
          ),

          // 기간 선택 + 이동평균선 범례 (한 줄)
          const SizedBox(height: 6),
          Row(
            children: [
              _CompactPeriodSelector(
                selectedPeriod: _selectedPeriod,
                onPeriodChanged: (period) {
                  setState(() => _selectedPeriod = period);
                  _loadChartData(period);
                },
              ),
              const Spacer(),
              const _MALegend(),
            ],
          ),

          // 캔들스틱 차트
          const SizedBox(height: 6),
          SizedBox(
            height: isDesktop ? 280.0 : 140.0,
            child: state.hasChart
                ? _CandlestickChart(
                    data: state.chartData,
                    selectedPeriod: _selectedPeriod,
                  )
                : Center(
                    child: state.isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            '차트 없음',
                            style: const TextStyle(
                              color: AppColors.textHint,
                              fontSize: 10,
                            ),
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  void _loadChartData(String period) {
    String range;
    String interval;

    switch (period) {
      case '일':
        range = '6mo';  // 120일 이평선 위해 충분한 데이터
        interval = '1day';
        break;
      case '주':
        range = '2y';
        interval = '1week';
        break;
      case '월':
        range = '10y';
        interval = '1month';
        break;
      default:
        range = '6mo';
        interval = '1day';
    }

    widget.onPeriodChanged(range, interval);
  }

  String _formatPrice(double price) {
    return price.toStringAsFixed(2).replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (match) => '${match[1]},',
        );
  }
}

/// 컴팩트 기간 선택기
class _CompactPeriodSelector extends StatelessWidget {
  final String selectedPeriod;
  final ValueChanged<String> onPeriodChanged;

  const _CompactPeriodSelector({
    required this.selectedPeriod,
    required this.onPeriodChanged,
  });

  static const periods = ['일', '주', '월'];

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 768;
    return Row(
      children: periods.map((period) {
        final isSelected = period == selectedPeriod;
        return Padding(
          padding: const EdgeInsets.only(right: 4),
          child: GestureDetector(
            onTap: () => onPeriodChanged(period),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: isDesktop ? 10 : 8, vertical: isDesktop ? 4 : 3),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.gray800 : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: isSelected ? null : Border.all(color: AppColors.gray300, width: 0.5),
              ),
              child: Text(
                period,
                style: TextStyle(
                  fontSize: isDesktop ? 12 : 10,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// 이동평균선 범례
class _MALegend extends StatelessWidget {
  const _MALegend();

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 768;
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        _legendItem('5', const Color(0xFFFF6B6B), isDesktop),
        _legendItem('20', const Color(0xFFFFD93D), isDesktop),
        _legendItem('60', const Color(0xFF6BCB77), isDesktop),
        _legendItem('120', const Color(0xFF4D96FF), isDesktop),
      ],
    );
  }

  Widget _legendItem(String label, Color color, bool isDesktop) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: isDesktop ? 12 : 10,
            height: 2,
            color: color,
          ),
          const SizedBox(width: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: isDesktop ? 10 : 8,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// 캔들스틱 차트 (이동평균선 포함, 확대/축소/스크롤 지원)
class _CandlestickChart extends StatefulWidget {
  final List<OHLCData> data;
  final String selectedPeriod;

  const _CandlestickChart({
    required this.data,
    required this.selectedPeriod,
  });

  @override
  State<_CandlestickChart> createState() => _CandlestickChartState();
}

class _CandlestickChartState extends State<_CandlestickChart> {
  static const int _minVisibleCount = 15;
  static const int _defaultVisibleCount = 60;

  int _visibleCount = _defaultVisibleCount;
  int _scrollOffset = 0; // 0 = 가장 최근 데이터가 오른쪽 끝
  int _baseVisibleCount = _defaultVisibleCount;

  @override
  void didUpdateWidget(covariant _CandlestickChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data.length != widget.data.length ||
        oldWidget.selectedPeriod != widget.selectedPeriod) {
      _visibleCount = _defaultVisibleCount.clamp(1, widget.data.length.clamp(1, _defaultVisibleCount));
      _scrollOffset = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    if (data.isEmpty) {
      return const Center(
        child: Text('데이터 없음', style: TextStyle(color: AppColors.textHint, fontSize: 10)),
      );
    }

    final maxVisible = data.length;
    final visibleCount = _visibleCount.clamp(_minVisibleCount, maxVisible);
    final maxOffset = (maxVisible - visibleCount).clamp(0, maxVisible);
    final scrollOffset = _scrollOffset.clamp(0, maxOffset);

    final endIdx = data.length - scrollOffset;
    final startIdx = (endIdx - visibleCount).clamp(0, data.length);
    final displayData = data.sublist(startIdx, endIdx);

    // 이동평균 계산 (전체 데이터 기준)
    final ma5 = _calculateMA(data, 5);
    final ma20 = _calculateMA(data, 20);
    final ma60 = _calculateMA(data, 60);
    final ma120 = _calculateMA(data, 120);

    // 표시 범위에 맞게 자르기
    final displayMa5 = _sliceMA(ma5, startIdx, endIdx);
    final displayMa20 = _sliceMA(ma20, startIdx, endIdx);
    final displayMa60 = _sliceMA(ma60, startIdx, endIdx);
    final displayMa120 = _sliceMA(ma120, startIdx, endIdx);

    return Listener(
      onPointerSignal: (event) {
        if (event is PointerScrollEvent) {
          _onMouseWheel(event.scrollDelta.dy);
        }
      },
      child: GestureDetector(
        onScaleStart: _onScaleStart,
        onScaleUpdate: _onScaleUpdate,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return CustomPaint(
              size: Size(constraints.maxWidth, constraints.maxHeight),
              painter: _CandlestickPainter(
                data: displayData,
                ma5: displayMa5,
                ma20: displayMa20,
                ma60: displayMa60,
                ma120: displayMa120,
                selectedPeriod: widget.selectedPeriod,
                isDesktop: MediaQuery.of(context).size.width >= 768,
              ),
            );
          },
        ),
      ),
    );
  }

  List<double> _sliceMA(List<double> ma, int startIdx, int endIdx) {
    if (ma.length <= startIdx) return <double>[];
    return ma.sublist(startIdx, endIdx.clamp(0, ma.length));
  }

  void _onMouseWheel(double deltaY) {
    setState(() {
      final zoomStep = (_visibleCount * 0.1).round().clamp(1, 10);
      if (deltaY > 0) {
        _visibleCount = (_visibleCount + zoomStep).clamp(_minVisibleCount, widget.data.length);
      } else {
        _visibleCount = (_visibleCount - zoomStep).clamp(_minVisibleCount, widget.data.length);
      }
      final maxOffset = (widget.data.length - _visibleCount).clamp(0, widget.data.length);
      _scrollOffset = _scrollOffset.clamp(0, maxOffset);
    });
  }

  void _onScaleStart(ScaleStartDetails details) {
    _baseVisibleCount = _visibleCount;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    setState(() {
      if (details.pointerCount >= 2) {
        // 핀치 줌
        _visibleCount = (_baseVisibleCount / details.scale)
            .round()
            .clamp(_minVisibleCount, widget.data.length);
      } else {
        // 수평 드래그 (한 손가락)
        final sensitivity = _visibleCount / 200.0;
        final delta = (details.focalPointDelta.dx * sensitivity).round();
        _scrollOffset = (_scrollOffset + delta)
            .clamp(0, (widget.data.length - _visibleCount).clamp(0, widget.data.length));
      }
      final maxOffset = (widget.data.length - _visibleCount).clamp(0, widget.data.length);
      _scrollOffset = _scrollOffset.clamp(0, maxOffset);
    });
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
}

/// 캔들스틱 페인터
class _CandlestickPainter extends CustomPainter {
  final List<OHLCData> data;
  final List<double> ma5;
  final List<double> ma20;
  final List<double> ma60;
  final List<double> ma120;
  final String selectedPeriod;
  final bool isDesktop;

  _CandlestickPainter({
    required this.data,
    required this.ma5,
    required this.ma20,
    required this.ma60,
    required this.ma120,
    required this.selectedPeriod,
    required this.isDesktop,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    const double topPadding = 5;
    const double bottomPadding = 20;
    const double rightPadding = 35;
    const double leftPadding = 5;

    final chartWidth = size.width - leftPadding - rightPadding;
    final chartHeight = size.height - topPadding - bottomPadding;

    // Y축 범위 계산
    double minY = double.infinity;
    double maxY = double.negativeInfinity;

    for (final candle in data) {
      if (candle.low < minY) minY = candle.low;
      if (candle.high > maxY) maxY = candle.high;
    }

    // 이동평균선 범위도 포함
    for (final ma in [ma5, ma20, ma60, ma120]) {
      for (final v in ma) {
        if (!v.isNaN) {
          if (v < minY) minY = v;
          if (v > maxY) maxY = v;
        }
      }
    }

    final range = maxY - minY;
    final padding = range * 0.05;
    minY -= padding;
    maxY += padding;

    // 캔들 너비 계산
    final candleWidth = chartWidth / data.length;
    final bodyWidth = candleWidth * 0.7;

    // 캔들 그리기
    for (int i = 0; i < data.length; i++) {
      final candle = data[i];
      final x = leftPadding + i * candleWidth + candleWidth / 2;

      final openY = topPadding + (1 - (candle.open - minY) / (maxY - minY)) * chartHeight;
      final closeY = topPadding + (1 - (candle.close - minY) / (maxY - minY)) * chartHeight;
      final highY = topPadding + (1 - (candle.high - minY) / (maxY - minY)) * chartHeight;
      final lowY = topPadding + (1 - (candle.low - minY) / (maxY - minY)) * chartHeight;

      final isUp = candle.close >= candle.open;
      final color = isUp ? AppColors.stockUp : AppColors.stockDown;

      // 심지 (wick)
      final wickPaint = Paint()
        ..color = color
        ..strokeWidth = 1;
      canvas.drawLine(Offset(x, highY), Offset(x, lowY), wickPaint);

      // 몸통 (body)
      final bodyPaint = Paint()
        ..color = color
        ..style = isUp ? PaintingStyle.stroke : PaintingStyle.fill
        ..strokeWidth = 1;

      final bodyTop = isUp ? closeY : openY;
      final bodyBottom = isUp ? openY : closeY;
      final bodyHeight = (bodyBottom - bodyTop).abs();

      canvas.drawRect(
        Rect.fromLTWH(x - bodyWidth / 2, bodyTop, bodyWidth, bodyHeight < 1 ? 1 : bodyHeight),
        bodyPaint,
      );
    }

    // 이동평균선 그리기
    _drawMA(canvas, ma5, const Color(0xFFFF6B6B), chartWidth, chartHeight, minY, maxY, leftPadding, topPadding);
    _drawMA(canvas, ma20, const Color(0xFFFFD93D), chartWidth, chartHeight, minY, maxY, leftPadding, topPadding);
    _drawMA(canvas, ma60, const Color(0xFF6BCB77), chartWidth, chartHeight, minY, maxY, leftPadding, topPadding);
    _drawMA(canvas, ma120, const Color(0xFF4D96FF), chartWidth, chartHeight, minY, maxY, leftPadding, topPadding);

    // Y축 라벨
    _drawYAxisLabels(canvas, size, minY, maxY, topPadding, chartHeight, rightPadding);

    // X축 날짜 라벨
    _drawXAxisLabels(canvas, size, leftPadding, chartWidth, topPadding, chartHeight, bottomPadding);
  }

  void _drawMA(Canvas canvas, List<double> ma, Color color, double chartWidth, double chartHeight, double minY, double maxY, double leftPadding, double topPadding) {
    if (ma.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final path = Path();
    bool started = false;
    final candleWidth = chartWidth / data.length;

    for (int i = 0; i < ma.length && i < data.length; i++) {
      if (ma[i].isNaN) continue;

      final x = leftPadding + i * candleWidth + candleWidth / 2;
      final y = topPadding + (1 - (ma[i] - minY) / (maxY - minY)) * chartHeight;

      if (!started) {
        path.moveTo(x, y);
        started = true;
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);
  }

  void _drawYAxisLabels(Canvas canvas, Size size, double minY, double maxY, double topPadding, double chartHeight, double rightPadding) {
    final textStyle = TextStyle(
      color: AppColors.textHint,
      fontSize: isDesktop ? 10 : 8,
    );

    final values = [maxY, (maxY + minY) / 2, minY];
    final yPositions = [topPadding, topPadding + chartHeight / 2, topPadding + chartHeight];

    for (int i = 0; i < values.length; i++) {
      final textSpan = TextSpan(
        text: _formatAxisPrice(values[i]),
        style: textStyle,
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: ui.TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(size.width - rightPadding + 4, yPositions[i] - textPainter.height / 2),
      );
    }
  }

  void _drawXAxisLabels(Canvas canvas, Size size, double leftPadding, double chartWidth, double topPadding, double chartHeight, double bottomPadding) {
    if (data.isEmpty) return;

    final textStyle = TextStyle(
      color: AppColors.textHint,
      fontSize: isDesktop ? 10 : 8,
    );

    // 4개의 라벨 표시
    final labelCount = 4;
    final step = (data.length / labelCount).floor();

    for (int i = 0; i < labelCount; i++) {
      final idx = (i * step).clamp(0, data.length - 1);
      final date = data[idx].date;
      final x = leftPadding + idx * (chartWidth / data.length) + (chartWidth / data.length) / 2;

      String label;
      switch (selectedPeriod) {
        case '일':
          label = DateFormat('MM/dd').format(date);
          break;
        case '주':
          label = DateFormat('yy/MM').format(date);
          break;
        case '월':
          label = DateFormat('yyyy').format(date);
          break;
        default:
          label = DateFormat('MM/dd').format(date);
      }

      final textSpan = TextSpan(text: label, style: textStyle);
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: ui.TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, topPadding + chartHeight + 4),
      );
    }
  }

  String _formatAxisPrice(double price) {
    if (price >= 10000) {
      return '${(price / 1000).toStringAsFixed(1)}K';
    } else if (price >= 1000) {
      return '${(price / 1000).toStringAsFixed(2)}K';
    }
    return price.toStringAsFixed(0);
  }

  @override
  bool shouldRepaint(covariant _CandlestickPainter oldDelegate) {
    return oldDelegate.data != data ||
           oldDelegate.selectedPeriod != selectedPeriod ||
           oldDelegate.isDesktop != isDesktop;
  }
}
