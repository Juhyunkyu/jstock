import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/chart_drawing.dart';
import '../../../data/models/ohlc_data.dart';
import '../../../data/services/technical_indicator_service.dart';
import '../../providers/settings_providers.dart';
import '../../utils/chart_coordinate_utils.dart';
import '../../utils/chart_utils.dart';
import 'chart_controls.dart';
import 'chart_drawing_hit_test.dart';
import 'chart_drawing_menu.dart';
import 'chart_indicator_calculator.dart';
import 'chart_sub_charts.dart';
import 'detail_candlestick_painter.dart';
import 'drawing_guide_bar.dart';
// drawing_help_dialog.dart — 도움말은 오버레이로 인라인 처리
import 'candle_info_overlay.dart';
import 'drawing_overlay_painter.dart';
import 'drawing_selection_buttons.dart';
import 'drawing_settings_sheet.dart';
import 'drawing_toolbar.dart';
import 'indicator_help_dialog.dart';
import '../../providers/providers.dart';

part 'chart_drawing_gesture_handler.dart';

const _uuid = Uuid();

// 기본 드로잉 색상 팔레트
const List<int> _drawingColors = [
  0xFFFF6B6B, // 빨강
  0xFF4ECDC4, // 청록
  0xFFFFD93D, // 노랑
  0xFF6BCB77, // 초록
  0xFF4D96FF, // 파랑
  0xFFFF8C42, // 주황
];

/// 상세 차트 섹션 (줌/스크롤, 지표 토글, 기간 선택 포함)
class DetailChartSection extends ConsumerStatefulWidget {
  final String symbol;
  final List<OHLCData> chartData;
  final String selectedPeriod;
  final ValueChanged<String> onPeriodChanged;
  final bool showPivotLines;
  final Map<String, double>? pivotLevels;
  final TechnicalIndicatorService indicatorService;
  final double? currentPrice;
  final double? previousClose;
  final ValueChanged<bool>? onDrawingActiveChanged;

  const DetailChartSection({
    super.key,
    required this.symbol,
    required this.chartData,
    required this.selectedPeriod,
    required this.onPeriodChanged,
    required this.showPivotLines,
    this.pivotLevels,
    required this.indicatorService,
    this.currentPrice,
    this.previousClose,
    this.onDrawingActiveChanged,
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

  // 드로잉 상태
  DrawingMode _drawingMode = DrawingMode.none;
  String? _selectedDrawingId;
  DateTime? _tempTrendLineStartDate;
  double? _tempTrendLineStartPrice;
  bool _waitingSecondPoint = false;

  // 드래그 배치/이동 상태
  bool _isDraggingNewLine = false;    // 새 수평선 드래그 배치 중
  bool _isMovingDrawing = false;      // 기존 선 드래그 이동 중
  String? _movingDrawingId;           // 이동 중인 드로잉 ID
  double? _tempHorizontalPrice;       // 미리보기 가격
  ChartYRange? _cachedYRange;         // 캐시된 좌표계 (드래그 중)
  double? _moveStartY;               // 이동 시작 터치 Y 좌표
  double? _moveStartPrice;           // 이동 시작 시 price 값
  double? _moveStartStartPrice;      // 이동 시작 시 startPrice (추세선용)
  double? _moveStartEndPrice;        // 이동 시작 시 endPrice (추세선용)
  String? _draggingAnchor;           // 앵커 드래그: 'start' 또는 'end' (null이면 평행 이동)
  bool _ignoreNextTap = false;        // 인라인 버튼 터치 시 탭 무시 플래그

  // 캔들 선택 상태
  int? _selectedCandleIndex; // widget.chartData 기준 full index, null이면 미선택

  // 측정 도구 상태 (Hive 비저장)
  bool _isMeasuring = false;
  int? _measureStartFullIndex;
  int? _measureEndFullIndex;
  double? _measureStartPrice;
  double? _measureEndPrice;

  // 지지/저항 영역 드래그 배치 상태
  bool _isDraggingNewZone = false;
  double? _tempZoneUpperPrice;
  double? _tempZoneLowerPrice;

  /// 부모 스크롤 비활성화 콜백 호출
  void _notifyDrawingActive() {
    widget.onDrawingActiveChanged?.call(
      _drawingMode != DrawingMode.none || _selectedDrawingId != null,
    );
  }

  int _colorIndex = 0;

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
    // 드로잉 로드
    ref.read(chartDrawingProvider.notifier).loadForSymbol(widget.symbol);
  }

  @override
  void didUpdateWidget(DetailChartSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // chartData나 기간 변경 시 캔들 선택 초기화 + 스크롤 위치 재설정
    if (widget.chartData.length != oldWidget.chartData.length ||
        widget.selectedPeriod != oldWidget.selectedPeriod) {
      _selectedCandleIndex = null;
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

  // 드로잉 제스처 핸들러, 생성, 액션, 드래그 제스처는
  // chart_drawing_gesture_handler.dart (part file)의
  // _DrawingGestureHandler extension에 정의됨

  // hit-test 유틸리티 (part file에서도 사용)
  double _trendLineDistance(
    Offset point, ChartDrawing drawing, ChartYRange yRange, int scrollOffset,
  ) => ChartDrawingHitTest.trendLineDistance(
        point, drawing, yRange, scrollOffset, widget.chartData);

  int? _findDateIndex(List<OHLCData> data, DateTime target) =>
      ChartDrawingHitTest.findDateIndex(data, target);

  double _fibonacciDistance(Offset point, ChartDrawing drawing, ChartYRange yRange) =>
      ChartDrawingHitTest.fibonacciDistance(point, drawing, yRange);

  double _zoneDistance(Offset point, ChartDrawing drawing, ChartYRange yRange) =>
      ChartDrawingHitTest.zoneDistance(point, drawing, yRange);

  double? _getSelectedLineY(ChartYRange yRange) =>
      ChartDrawingHitTest.getSelectedLineY(
        _selectedDrawingId, ref.read(chartDrawingProvider), yRange);

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

    // 보조 지표 일괄 계산
    final ind = ChartIndicatorCalculator.calculate(
      fullData: widget.chartData,
      displayData: displayData,
      offset: offset,
      end: end,
      activeIndicators: _activeIndicators,
      indicatorService: widget.indicatorService,
    );

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
          // 기간 선택 + MA 범례 + 드로잉 버튼
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ChartPeriodSelector(
                        selectedPeriod: widget.selectedPeriod,
                        onPeriodChanged: widget.onPeriodChanged,
                      ),
                      const SizedBox(width: 4),
                      const LegendItem(label: '5', color: Color(0xFFFF6B6B), darkColor: Color(0xFFE04848)),
                      const LegendItem(label: '20', color: Color(0xFFFFD93D), darkColor: Color(0xFFCC9E00)),
                      const LegendItem(label: '60', color: Color(0xFF6BCB77), darkColor: Color(0xFF3DA34D)),
                      const LegendItem(label: '120', color: Color(0xFF4D96FF), darkColor: Color(0xFF2B6ED4)),
                    ],
                  ),
                ),
              ),
              // Y축 가격 영역(rightPadding 50px) 중앙에 정렬
              SizedBox(
                width: 50,
                child: Center(
                  child: ChartDrawingMenuButton(
                    drawingMode: _drawingMode,
                    selectedDrawingId: _selectedDrawingId,
                    onSelectMode: selectDrawingMode,
                    onCancel: cancelDrawing,
                    onResetAll: resetAllDrawings,
                    onDeselectDrawing: () {
                      setState(() {
                        _selectedDrawingId = null;
                      });
                      _notifyDrawingActive();
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 차트 영역 (제스처로 줌/스크롤) + 우측 여백(페이지 스크롤용)
          LayoutBuilder(
            builder: (context, constraints) {
              // 데스크톱/태블릿에서 우측 여백 추가 (마우스 휠로 페이지 스크롤 가능 영역)
              final screenWidth = MediaQuery.sizeOf(context).width;
              final rightMargin = screenWidth >= 768 ? 40.0 : 0.0;
              final chartWidth = constraints.maxWidth - rightMargin;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 차트 영역 (휠 = 줌, 드래그 = 스크롤)
                  SizedBox(
                    width: chartWidth,
                    child: Builder(
                      builder: (context) {
                        final yRange = ChartCoordinateCalculator.calculate(
                          data: displayData,
                          width: chartWidth,
                          height: 300,
                          bollingerBands: ind.displayBB,
                          ichimoku: ind.displayIchimoku,
                          bbSummary: ind.bbSummary,
                          ichSummary: ind.ichSummary,
                        );
                        final selectedLineY = _getSelectedLineY(yRange);
                        final nextColor = _drawingColors[_colorIndex % _drawingColors.length];
                        return GestureDetector(
                          onScaleStart: (details) =>
                              handleScaleStart(details, chartWidth, yRange),
                          onScaleUpdate: (details) =>
                              handleScaleUpdate(details, chartWidth, yRange),
                          onScaleEnd: handleScaleEnd,
                          onTapUp: (details) => handleChartTap(
                            details, chartWidth, displayData, ind.displayBB,
                            ind.displayIchimoku, ind.bbSummary, ind.ichSummary, offset,
                          ),
                          onLongPressStart: (details) => _handleCandleScrubStart(details, yRange, offset),
                          onLongPressMoveUpdate: (details) => _handleCandleScrubUpdate(details, yRange, offset),
                          onLongPressEnd: (_) => _handleCandleScrubEnd(),
                          child: Listener(
                            onPointerSignal: _drawingMode == DrawingMode.none && !_isMeasuring
                                ? _handlePointerSignal : null,
                            child: Column(
                              children: [
                                // 메인 캔들스틱 차트
                                SizedBox(
                                  height: 300,
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      // 캔들스틱 차트
                                      CustomPaint(
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
                                          bollingerBands: ind.displayBB,
                                          ichimoku: ind.displayIchimoku,
                                          bbSummary: ind.bbSummary,
                                          ichSummary: ind.ichSummary,
                                          bbSignal: ind.bbSignal,
                                          ichSignal: ind.ichSignal,
                                          isDarkMode: Theme.of(context).brightness == Brightness.dark,
                                          isDesktop: screenWidth >= 768,
                                          textColor: context.appTextSecondary,
                                          cardBgColor: context.appSurface,
                                          currentPrice: widget.currentPrice,
                                          previousClose: widget.previousClose,
                                          selectedCandleIndex: (_selectedCandleIndex != null &&
                                              _selectedCandleIndex! >= offset && _selectedCandleIndex! < end)
                                              ? _selectedCandleIndex! - offset
                                              : null,
                                        ),
                                      ),
                                      // 드로잉 오버레이 (+ 미리보기)
                                      CustomPaint(
                                        size: Size(chartWidth, 300),
                                        painter: DrawingOverlayPainter(
                                          drawings: ref.watch(chartDrawingProvider),
                                          displayData: displayData,
                                          fullData: widget.chartData,
                                          scrollOffset: offset,
                                          yRange: yRange,
                                          selectedDrawingId: _selectedDrawingId,
                                          isDarkMode: Theme.of(context).brightness == Brightness.dark,
                                          tempHorizontalPrice: _tempHorizontalPrice,
                                          tempColorValue: (_isDraggingNewLine || _isDraggingNewZone) ? nextColor : null,
                                          tempTrendStartDate: _waitingSecondPoint ? _tempTrendLineStartDate : null,
                                          tempTrendStartPrice: _waitingSecondPoint ? _tempTrendLineStartPrice : null,
                                          tempMeasureStartIndex: _isMeasuring ? _measureStartFullIndex : null,
                                          tempMeasureStartPrice: _isMeasuring ? _measureStartPrice : null,
                                          tempMeasureEndIndex: _isMeasuring ? _measureEndFullIndex : null,
                                          tempMeasureEndPrice: _isMeasuring ? _measureEndPrice : null,
                                          tempZoneUpperPrice: _isDraggingNewZone ? _tempZoneUpperPrice : null,
                                          tempZoneLowerPrice: _isDraggingNewZone ? _tempZoneLowerPrice : null,
                                        ),
                                      ),
                                      // 캔들 정보 플로팅 팝업 (캔들 바로 옆에 표시)
                                      if (_selectedCandleIndex != null &&
                                          _selectedCandleIndex! >= offset && _selectedCandleIndex! < end) ...[
                                        () {
                                          final displayIdx = _selectedCandleIndex! - offset;
                                          final candleX = yRange.toX(displayIdx);
                                          final selectedCandle = widget.chartData[_selectedCandleIndex!];
                                          // X: 캔들 왼쪽 절반이면 오른쪽에, 오른쪽이면 왼쪽에
                                          final isLeftHalf = candleX < chartWidth / 2;
                                          final gap = 16.0; // 캔들과 팝업 간격
                                          return Positioned(
                                            top: 0,
                                            left: isLeftHalf ? candleX + gap : null,
                                            right: isLeftHalf ? null : chartWidth - candleX + gap,
                                            child: CandleInfoOverlay(
                                              candle: selectedCandle,
                                              previousCandle: _selectedCandleIndex! > 0
                                                  ? widget.chartData[_selectedCandleIndex! - 1]
                                                  : null,
                                              selectedPeriod: widget.selectedPeriod,
                                              candleX: candleX,
                                              chartWidth: chartWidth,
                                              indicators: ind,
                                              displayIndex: displayIdx,
                                            ),
                                          );
                                        }(),
                                      ],
                                      // 가이드 바 (드로잉 모드 시 상단)
                                      Positioned(
                                        top: 0,
                                        left: 0,
                                        right: 0,
                                        child: DrawingGuideBar(
                                          drawingMode: _drawingMode,
                                          waitingSecondPoint: _waitingSecondPoint,
                                          onCancel: cancelDrawing,
                                        ),
                                      ),
                                      // 인라인 선택 버튼 (선 좌측, 선택 시만)
                                      if (_selectedDrawingId != null && selectedLineY != null)
                                        DrawingSelectionButtons(
                                          lineY: selectedLineY,
                                          onSettings: () {
                                            _ignoreNextTap = true;
                                            showDrawingSettings();
                                          },
                                          onDelete: () {
                                            _ignoreNextTap = true;
                                            deleteSelectedDrawing();
                                          },
                                        ),
                                    ],
                                  ),
                                ),
                                // 서브 차트 목록
                                SubChartList(
                                  activeIndicators: _activeIndicators,
                                  indicators: ind,
                                  displayData: displayData,
                                  chartWidth: chartWidth,
                                  selectedCandleDisplayIndex: (_selectedCandleIndex != null &&
                                      _selectedCandleIndex! >= offset && _selectedCandleIndex! < end)
                                      ? _selectedCandleIndex! - offset
                                      : null,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
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
