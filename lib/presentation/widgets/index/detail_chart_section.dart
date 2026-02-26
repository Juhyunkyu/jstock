import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/ohlc_data.dart';
import '../../../data/services/technical_indicator_service.dart';
import '../../providers/settings_providers.dart';
import '../../utils/chart_utils.dart';
import 'chart_controls.dart';
import 'detail_candlestick_painter.dart';
import 'indicator_help_dialog.dart';
import 'sub_chart_painters.dart';

/// 상세 차트 섹션 (줌/스크롤, 지표 토글, 기간 선택 포함)
class DetailChartSection extends ConsumerStatefulWidget {
  final List<OHLCData> chartData;
  final String selectedPeriod;
  final ValueChanged<String> onPeriodChanged;
  final bool showPivotLines;
  final Map<String, double>? pivotLevels;
  final TechnicalIndicatorService indicatorService;
  final double? currentPrice;
  final double? previousClose;

  const DetailChartSection({
    super.key,
    required this.chartData,
    required this.selectedPeriod,
    required this.onPeriodChanged,
    required this.showPivotLines,
    this.pivotLevels,
    required this.indicatorService,
    this.currentPrice,
    this.previousClose,
  });

  @override
  ConsumerState<DetailChartSection> createState() => _DetailChartSectionState();
}

class _DetailChartSectionState extends ConsumerState<DetailChartSection> {
  // 줌/스크롤 상태 (모든 차트 동기화용)
  int _visibleCount = 80;
  int _scrollOffset = 0;
  int _startVisibleCount = 80;
  double _dragRemainder = 0.0; // 소수점 캔들 이동량 누적
  static const int _minVisible = 20;
  static const int _maxVisible = 200;

  // 보조 지표 토글 상태
  late Set<String> _activeIndicators;

  @override
  void initState() {
    super.initState();
    // 저장된 보조지표 설정 로드
    final saved = ref.read(settingsProvider).chartIndicators;
    _activeIndicators = saved.isEmpty ? {} : saved.split(',').toSet();
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
        _dragRemainder += dx / candleWidth;
        final candleShift = _dragRemainder.truncate();
        if (candleShift != 0) {
          _dragRemainder -= candleShift;
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

  void _toggleIndicator(String key) {
    setState(() {
      if (_activeIndicators.contains(key)) {
        _activeIndicators.remove(key);
      } else {
        _activeIndicators.add(key);
      }
    });
    // Hive에 저장 (비동기, UI 블록 없음)
    ref.read(settingsProvider.notifier).updateChartIndicators(_activeIndicators);
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
    final ma5 = calculateMA(widget.chartData, 5);
    final ma20 = calculateMA(widget.chartData, 20);
    final ma60 = calculateMA(widget.chartData, 60);
    final ma120 = calculateMA(widget.chartData, 120);

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
      volCurrentValue = formatVolume(displayData.last.volume);
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
      obvLabel = 'OBV: ${formatVolume(displayOBV!.last)}';
    }

    return Container(
      color: context.appSurface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 지표 선택 칩
          IndicatorChips(
            activeIndicators: _activeIndicators,
            onToggle: _toggleIndicator,
            onHelpTap: (key) => showIndicatorHelpDialog(context, key),
          ),
          const SizedBox(height: 8),
          // 기간 선택 + MA 범례 한 줄
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ChartPeriodSelector(
                  selectedPeriod: widget.selectedPeriod,
                  onPeriodChanged: widget.onPeriodChanged,
                ),
                const SizedBox(width: 12),
                const LegendItem(label: '5일', color: Color(0xFFFF6B6B)),
                const LegendItem(label: '20일', color: Color(0xFFFFD93D)),
                const LegendItem(label: '60일', color: Color(0xFF6BCB77)),
                const LegendItem(label: '120일', color: Color(0xFF4D96FF)),
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
                      onScaleStart: (_) { _startVisibleCount = _visibleCount; _dragRemainder = 0.0; },
                      onScaleUpdate: (details) => _handleZoomScroll(details, chartWidth),
                      child: Listener(
                        onPointerSignal: _handlePointerSignal,
                        child: Column(
                          children: [
                            // 메인 캔들스틱 차트 (+ BB, Ichimoku 오버레이)
                            SizedBox(
                              height: 300,
                              child: CustomPaint(
                                size: Size(chartWidth, 300),
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
                                  currentPrice: widget.currentPrice,
                                  previousClose: widget.previousClose,
                                ),
                              ),
                            ),
                            // 거래량 서브차트
                            if (_activeIndicators.contains('VOL')) ...[
                              SubChartHeader(
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
                              SubChartHeader(
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
                              SubChartHeader(
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
                              SubChartHeader(
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
                              SubChartHeader(
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
}
