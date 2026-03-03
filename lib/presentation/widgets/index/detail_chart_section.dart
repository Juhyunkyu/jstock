import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/chart_drawing.dart';
import '../../../data/models/ohlc_data.dart';
import '../../../data/services/technical_indicator_service.dart';
import '../../providers/drawing_providers.dart';
import '../../providers/settings_providers.dart';
import '../../utils/chart_coordinate_utils.dart';
import '../../utils/chart_utils.dart';
import 'chart_controls.dart';
import 'detail_candlestick_painter.dart';
import 'drawing_guide_bar.dart';
// drawing_help_dialog.dart — 도움말은 오버레이로 인라인 처리
import 'drawing_overlay_painter.dart';
import 'drawing_selection_buttons.dart';
import 'drawing_settings_sheet.dart';
import 'drawing_toolbar.dart';
import 'indicator_help_dialog.dart';
import 'sub_chart_painters.dart';

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

  static const _uuid = Uuid();

  // 기본 드로잉 색상 팔레트
  static const List<int> _drawingColors = [
    0xFFFF6B6B, // 빨강
    0xFF4ECDC4, // 청록
    0xFFFFD93D, // 노랑
    0xFF6BCB77, // 초록
    0xFF4D96FF, // 파랑
    0xFFFF8C42, // 주황
  ];
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

  // ═══════════════════════════════════════════════════════════════
  // 드로잉 제스처 핸들러
  // ═══════════════════════════════════════════════════════════════

  void _handleChartTap(
    TapUpDetails details,
    double chartWidth,
    List<OHLCData> displayData,
    List<BBResult>? displayBB,
    List<IchimokuResult>? displayIchimoku,
    String? bbSummary,
    String? ichSummary,
    int scrollOffset,
  ) {
    // 인라인 버튼(Listener)이 먼저 처리한 경우 → 탭 무시
    if (_ignoreNextTap) {
      _ignoreNextTap = false;
      return;
    }

    final localPos = details.localPosition;
    final yRange = ChartCoordinateCalculator.calculate(
      data: displayData,
      width: chartWidth,
      height: 300,
      bollingerBands: displayBB,
      ichimoku: displayIchimoku,
      bbSummary: bbSummary,
      ichSummary: ichSummary,
    );

    if (_drawingMode != DrawingMode.none) {
      _handleDrawingTap(localPos, yRange, displayData, scrollOffset);
      return;
    }

    // 인라인 버튼 영역 탭 무시 (버튼이 자체 처리)
    if (_selectedDrawingId != null) {
      final selY = _getSelectedLineY(yRange);
      if (selY != null &&
          localPos.dx >= 14 && localPos.dx <= 50 &&
          localPos.dy >= selY - 38 && localPos.dy <= selY + 38) {
        return;
      }
    }

    // 일반 모드: hit test → 가장 가까운 드로잉 선택
    _handleSelectionTap(localPos, yRange, displayData, scrollOffset);
  }

  void _handleDrawingTap(
    Offset localPos,
    ChartYRange yRange,
    List<OHLCData> displayData,
    int scrollOffset,
  ) {
    final price = yRange.fromY(localPos.dy);

    // 수평선: 탭으로도 배치
    if (_drawingMode == DrawingMode.horizontalLine) {
      _createHorizontalLine(price);
      return;
    }

    // 측정/지지저항: 탭으로는 동작하지 않음 (드래그 전용)
    if (_drawingMode == DrawingMode.measure ||
        _drawingMode == DrawingMode.supportResistanceZone) {
      return;
    }

    final dataIndex = yRange.fromX(localPos.dx);
    final fullIndex = dataIndex + scrollOffset;

    DateTime? date;
    if (fullIndex >= 0 && fullIndex < widget.chartData.length) {
      date = widget.chartData[fullIndex].date;
    }

    // 추세선: 2탭 배치
    if (_drawingMode == DrawingMode.trendLine) {
      if (!_waitingSecondPoint) {
        setState(() {
          _tempTrendLineStartDate = date;
          _tempTrendLineStartPrice = price;
          _waitingSecondPoint = true;
        });
      } else {
        _createTrendLine(
          _tempTrendLineStartDate!,
          _tempTrendLineStartPrice!,
          date!,
          price,
        );
      }
    }

    // 피보나치: 2탭 배치 (100% 고점 → 0% 저점)
    if (_drawingMode == DrawingMode.fibonacci) {
      if (!_waitingSecondPoint) {
        setState(() {
          _tempTrendLineStartDate = date;
          _tempTrendLineStartPrice = price;
          _waitingSecondPoint = true;
        });
      } else {
        _createFibonacci(
          _tempTrendLineStartDate!,
          _tempTrendLineStartPrice!,
          date!,
          price,
        );
      }
    }
  }

  void _handleSelectionTap(
    Offset localPos,
    ChartYRange yRange,
    List<OHLCData> displayData,
    int scrollOffset,
  ) {
    final drawings = ref.read(chartDrawingProvider);
    const hitThreshold = 20.0; // px — 터치 정밀도 고려
    String? closestId;
    double closestDist = double.infinity;

    for (final drawing in drawings) {
      double dist;
      switch (drawing.type) {
        case DrawingType.horizontalLine:
          final lineY = yRange.toY(drawing.price);
          dist = (localPos.dy - lineY).abs();
          break;
        case DrawingType.trendLine:
          dist = _trendLineDistance(localPos, drawing, yRange, scrollOffset);
          break;
        case DrawingType.fibonacci:
          dist = _fibonacciDistance(localPos, drawing, yRange);
          break;
        case DrawingType.supportResistanceZone:
          dist = _zoneDistance(localPos, drawing, yRange);
          break;
      }
      if (dist < closestDist) {
        closestDist = dist;
        closestId = drawing.id;
      }
    }

    setState(() {
      _selectedDrawingId = closestDist <= hitThreshold ? closestId : null;
    });
    _notifyDrawingActive();
  }

  double _trendLineDistance(
    Offset point,
    ChartDrawing drawing,
    ChartYRange yRange,
    int scrollOffset,
  ) {
    if (drawing.startDate == null || drawing.endDate == null ||
        drawing.startPrice == null || drawing.endPrice == null) {
      return double.infinity;
    }

    // 날짜 → fullData 인덱스
    final startIdx = _findDateIndex(widget.chartData, drawing.startDate!);
    final endIdx = _findDateIndex(widget.chartData, drawing.endDate!);
    if (startIdx == null || endIdx == null) return double.infinity;

    final startX = yRange.toX(startIdx - scrollOffset);
    final startY = yRange.toY(drawing.startPrice!);
    final endX = yRange.toX(endIdx - scrollOffset);
    final endY = yRange.toY(drawing.endPrice!);

    // 점과 직선 사이 거리 공식
    final dx = endX - startX;
    final dy = endY - startY;
    final lenSq = dx * dx + dy * dy;
    if (lenSq == 0) return (point - Offset(startX, startY)).distance;
    return ((point.dx - startX) * dy - (point.dy - startY) * dx).abs() /
        math.sqrt(lenSq);
  }

  int? _findDateIndex(List<OHLCData> data, DateTime target) {
    if (data.isEmpty) return null;
    int bestIdx = 0;
    int bestDiff = (data[0].date.difference(target).inMinutes).abs();
    for (int i = 1; i < data.length; i++) {
      final diff = (data[i].date.difference(target).inMinutes).abs();
      if (diff < bestDiff) {
        bestDiff = diff;
        bestIdx = i;
      }
    }
    return bestIdx;
  }

  void _createHorizontalLine(double price) {
    final drawing = ChartDrawing(
      id: _uuid.v4(),
      symbol: widget.symbol,
      type: DrawingType.horizontalLine,
      price: price,
      colorValue: _drawingColors[_colorIndex % _drawingColors.length],
    );
    _colorIndex++;
    ref.read(chartDrawingProvider.notifier).addDrawing(drawing);
    setState(() {
      _drawingMode = DrawingMode.none;
    });
    _notifyDrawingActive();
  }

  void _createTrendLine(
    DateTime startDate,
    double startPrice,
    DateTime endDate,
    double endPrice,
  ) {
    final drawing = ChartDrawing(
      id: _uuid.v4(),
      symbol: widget.symbol,
      type: DrawingType.trendLine,
      price: startPrice, // 참조용
      startDate: startDate,
      startPrice: startPrice,
      endDate: endDate,
      endPrice: endPrice,
      colorValue: _drawingColors[_colorIndex % _drawingColors.length],
    );
    _colorIndex++;
    ref.read(chartDrawingProvider.notifier).addDrawing(drawing);
    setState(() {
      _drawingMode = DrawingMode.none;
      _waitingSecondPoint = false;
      _tempTrendLineStartDate = null;
      _tempTrendLineStartPrice = null;
    });
    _notifyDrawingActive();
  }

  /// 피보나치 되돌림 생성
  void _createFibonacci(
    DateTime startDate,
    double startPrice,
    DateTime endDate,
    double endPrice,
  ) {
    final drawing = ChartDrawing(
      id: _uuid.v4(),
      symbol: widget.symbol,
      type: DrawingType.fibonacci,
      price: startPrice, // 참조용
      startDate: startDate,
      startPrice: startPrice, // 100% (고점)
      endDate: endDate,
      endPrice: endPrice, // 0% (저점)
      colorValue: _drawingColors[_colorIndex % _drawingColors.length],
    );
    _colorIndex++;
    ref.read(chartDrawingProvider.notifier).addDrawing(drawing);
    setState(() {
      _drawingMode = DrawingMode.none;
      _waitingSecondPoint = false;
      _tempTrendLineStartDate = null;
      _tempTrendLineStartPrice = null;
    });
    _notifyDrawingActive();
  }

  /// 지지/저항 영역 생성
  void _createSRZone(double upperPrice, double lowerPrice) {
    // 상한이 하한보다 높도록 보장
    final upper = math.max(upperPrice, lowerPrice);
    final lower = math.min(upperPrice, lowerPrice);
    final drawing = ChartDrawing(
      id: _uuid.v4(),
      symbol: widget.symbol,
      type: DrawingType.supportResistanceZone,
      price: upper,
      lowerPrice: lower,
      colorValue: _drawingColors[_colorIndex % _drawingColors.length],
    );
    _colorIndex++;
    ref.read(chartDrawingProvider.notifier).addDrawing(drawing);
    setState(() {
      _drawingMode = DrawingMode.none;
    });
    _notifyDrawingActive();
  }

  /// 전체 드로잉 초기화
  void _resetAllDrawings() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.appSurface,
        title: Text(
          '드로잉 초기화',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: context.appTextPrimary),
        ),
        content: Text(
          '이 차트의 모든 드로잉을 삭제하시겠습니까?\n삭제된 드로잉은 복구할 수 없습니다.',
          style: TextStyle(fontSize: 13, color: context.appTextSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('취소', style: TextStyle(color: context.appTextHint)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(chartDrawingProvider.notifier).clearAllForSymbol(widget.symbol);
              setState(() {
                _selectedDrawingId = null;
              });
              _notifyDrawingActive();
            },
            child: const Text('삭제', style: TextStyle(color: AppColors.stockDown)),
          ),
        ],
      ),
    );
  }

  /// 피보나치 hit test: 가장 가까운 레벨 선까지 거리
  double _fibonacciDistance(Offset point, ChartDrawing drawing, ChartYRange yRange) {
    if (drawing.startPrice == null || drawing.endPrice == null) {
      return double.infinity;
    }
    final highPrice = drawing.startPrice!;
    final lowPrice = drawing.endPrice!;
    const levels = [0.0, 0.236, 0.382, 0.5, 0.618, 0.786, 1.0];

    double minDist = double.infinity;
    for (final ratio in levels) {
      final price = lowPrice + (highPrice - lowPrice) * ratio;
      final lineY = yRange.toY(price);
      final dist = (point.dy - lineY).abs();
      if (dist < minDist) minDist = dist;
    }
    return minDist;
  }

  /// 지지/저항 영역 hit test
  double _zoneDistance(Offset point, ChartDrawing drawing, ChartYRange yRange) {
    final upperY = yRange.toY(drawing.price);
    final lowerY = yRange.toY(drawing.lowerPrice);
    final top = math.min(upperY, lowerY);
    final bottom = math.max(upperY, lowerY);

    // 영역 안이면 0
    if (point.dy >= top && point.dy <= bottom) return 0;
    // 밖이면 가장 가까운 경계까지
    return math.min((point.dy - top).abs(), (point.dy - bottom).abs());
  }

  void _deleteSelectedDrawing() {
    if (_selectedDrawingId == null) return;
    ref.read(chartDrawingProvider.notifier).removeDrawing(_selectedDrawingId!);
    setState(() {
      _selectedDrawingId = null;
    });
    _notifyDrawingActive();
  }

  void _cancelDrawing() {
    setState(() {
      _drawingMode = DrawingMode.none;
      _waitingSecondPoint = false;
      _tempTrendLineStartDate = null;
      _tempTrendLineStartPrice = null;
      _isDraggingNewLine = false;
      _tempHorizontalPrice = null;
      _isMeasuring = false;
      _measureStartFullIndex = null;
      _measureEndFullIndex = null;
      _measureStartPrice = null;
      _measureEndPrice = null;
      _isDraggingNewZone = false;
      _tempZoneUpperPrice = null;
      _tempZoneLowerPrice = null;
    });
    _notifyDrawingActive();
  }

  // ═══════════════════════════════════════════════════════════════
  // 인라인 드로잉 토글 버튼
  // ═══════════════════════════════════════════════════════════════

  final GlobalKey _drawingToggleKey = GlobalKey();
  OverlayEntry? _drawingMenuOverlay;
  OverlayEntry? _toolHelpOverlay;

  Widget _buildDrawingToggle() {
    final isDesktop = MediaQuery.of(context).size.width >= 600;

    if (_drawingMode != DrawingMode.none) {
      // 드로잉 모드 활성 → 취소(X) 버튼
      final size = isDesktop ? 28.0 : 24.0;
      return GestureDetector(
        onTap: _cancelDrawing,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: context.isDarkMode ? AppColors.gray700 : AppColors.gray400,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.close, size: isDesktop ? 15 : 13, color: Colors.white),
        ),
      );
    }

    // 기본 → 연필 아이콘 + 커스텀 팝업
    return GestureDetector(
      key: _drawingToggleKey,
      onTap: _toggleDrawingMenu,
      child: Padding(
        padding: EdgeInsets.all(isDesktop ? 4 : 2),
        child: Icon(Icons.edit, size: isDesktop ? 20 : 16, color: context.appTextHint),
      ),
    );
  }

  void _toggleDrawingMenu() {
    if (_drawingMenuOverlay != null) {
      _dismissDrawingMenu();
      return;
    }

    // 선택된 드로잉 해제 (설정/삭제 버튼 제거)
    if (_selectedDrawingId != null) {
      setState(() {
        _selectedDrawingId = null;
      });
      _notifyDrawingActive();
    }

    final renderBox = _drawingToggleKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    final isDesktop = MediaQuery.of(context).size.width >= 600;

    _drawingMenuOverlay = OverlayEntry(
      builder: (ctx) => Stack(
        children: [
          // 배경 탭 → 메뉴 닫기
          Positioned.fill(
            child: GestureDetector(
              onTap: _dismissDrawingMenu,
              behavior: HitTestBehavior.opaque,
              child: const ColoredBox(color: Colors.transparent),
            ),
          ),
          // 메뉴 버블 (연필 아이콘 아래에 표시)
          Positioned(
            right: MediaQuery.of(context).size.width - offset.dx - size.width - 4,
            top: offset.dy + size.height + 6,
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 4 : 4,
                  vertical: isDesktop ? 4 : 4,
                ),
                decoration: BoxDecoration(
                  color: context.appCardBackground,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(30),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                  border: Border.all(
                    color: context.appDivider,
                    width: 0.5,
                  ),
                ),
                child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildMenuItem(
                            icon: Icons.horizontal_rule,
                            label: '수평선',
                            helpKey: 'horizontalLine',
                            isDesktop: isDesktop,
                            onTap: () => _selectDrawingMode(DrawingMode.horizontalLine),
                          ),
                          _buildMenuItem(
                            icon: Icons.trending_up,
                            label: '추세선',
                            helpKey: 'trendLine',
                            isDesktop: isDesktop,
                            onTap: () => _selectDrawingMode(DrawingMode.trendLine),
                          ),
                          _buildMenuItem(
                            icon: Icons.stacked_line_chart,
                            label: '피보나치',
                            helpKey: 'fibonacci',
                            isDesktop: isDesktop,
                            onTap: () => _selectDrawingMode(DrawingMode.fibonacci),
                          ),
                          _buildMenuItem(
                            icon: Icons.view_stream,
                            label: '지지/저항',
                            helpKey: 'supportResistanceZone',
                            isDesktop: isDesktop,
                            onTap: () => _selectDrawingMode(DrawingMode.supportResistanceZone),
                          ),
                          _buildMenuItem(
                            icon: Icons.straighten,
                            label: '측정',
                            helpKey: 'measure',
                            isDesktop: isDesktop,
                            onTap: () => _selectDrawingMode(DrawingMode.measure),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Divider(height: 1, color: context.appDivider),
                          ),
                          _buildMenuItem(
                            icon: Icons.delete_sweep,
                            label: '초기화',
                            isDesktop: isDesktop,
                            onTap: () {
                              _dismissDrawingMenu();
                              _resetAllDrawings();
                            },
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_drawingMenuOverlay!);
  }

  /// 메뉴 아이템 (수직 일렬, 도구는 ? 포함)
  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    required bool isDesktop,
    required VoidCallback onTap,
    String? helpKey,
  }) {
    final iconSize = isDesktop ? 18.0 : 16.0;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isDesktop ? 8 : 6,
          vertical: isDesktop ? 6 : 5,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: isDesktop ? 22 : 20,
              child: Icon(icon, size: iconSize, color: context.appTextPrimary),
            ),
            SizedBox(width: isDesktop ? 8 : 6),
            Text(
              label,
              style: TextStyle(
                fontSize: isDesktop ? 13 : 12,
                fontWeight: FontWeight.w500,
                color: context.appTextPrimary,
              ),
            ),
            if (helpKey != null) ...[
              SizedBox(width: isDesktop ? 8 : 6),
              GestureDetector(
                onTap: () {
                  _showToolHelpOverlay(helpKey);
                },
                child: Icon(
                  Icons.help_outline,
                  size: isDesktop ? 15 : 14,
                  color: context.appTextHint,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _selectDrawingMode(DrawingMode mode) {
    _dismissDrawingMenu();
    setState(() {
      _drawingMode = mode;
      _selectedDrawingId = null;
      _waitingSecondPoint = false;
      _tempTrendLineStartDate = null;
      _tempTrendLineStartPrice = null;
      _isMeasuring = false;
      _measureStartFullIndex = null;
      _measureEndFullIndex = null;
      _measureStartPrice = null;
      _measureEndPrice = null;
      _isDraggingNewZone = false;
      _tempZoneUpperPrice = null;
      _tempZoneLowerPrice = null;
    });
    _notifyDrawingActive();
  }

  void _dismissDrawingMenu() {
    _dismissToolHelp();
    _drawingMenuOverlay?.remove();
    _drawingMenuOverlay = null;
  }

  void _dismissToolHelp() {
    _toolHelpOverlay?.remove();
    _toolHelpOverlay = null;
  }

  void _showToolHelpOverlay(String helpKey) {
    _dismissToolHelp();

    final helpData = _getToolHelpData(helpKey);
    if (helpData == null) return;

    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 600;

    _toolHelpOverlay = OverlayEntry(
      builder: (ctx) => Stack(
        children: [
          // 배경 탭 → 도움말만 닫기 (메뉴는 유지)
          Positioned.fill(
            child: GestureDetector(
              onTap: _dismissToolHelp,
              behavior: HitTestBehavior.translucent,
              child: const SizedBox.expand(),
            ),
          ),
          // 도움말 카드 (화면 중앙)
          Positioned(
            left: isDesktop ? screenWidth * 0.25 : 24,
            right: isDesktop ? screenWidth * 0.25 : 24,
            top: isDesktop ? 120 : 100,
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.appSurface,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(40),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(color: context.appDivider, width: 0.5),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(helpData['icon'] as IconData, size: 20, color: context.appAccent),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            helpData['title'] as String,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: context.appTextPrimary,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: _dismissToolHelp,
                          child: Icon(Icons.close, size: 18, color: context.appTextHint),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: isDesktop ? 300 : 250),
                      child: SingleChildScrollView(
                        child: Text(
                          helpData['description'] as String,
                          style: TextStyle(
                            fontSize: 13,
                            color: context.appTextSecondary,
                            height: 1.6,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_toolHelpOverlay!);
  }

  Map<String, dynamic>? _getToolHelpData(String key) {
    switch (key) {
      case 'horizontalLine':
        return {
          'icon': Icons.horizontal_rule,
          'title': '수평선',
          'description': '특정 가격 수준에 수평선을 그려 주요 지지/저항 가격대를 표시합니다.\n\n'
              '사용법:\n'
              '• 차트를 탭하거나 드래그하여 수평선을 배치합니다\n'
              '• 선을 탭하여 선택 → 드래그로 위치를 조정합니다\n'
              '• 선택 후 ⚙ 버튼으로 색상/굵기/잠금을 설정합니다\n\n'
              '활용법:\n'
              '• 과거 고점/저점에 배치하여 지지/저항 레벨 확인\n'
              '• 심리적 가격대(정수, 예: 600, 620)에 표시\n'
              '• 이전 돌파 후 지지로 전환된 레벨 추적\n'
              '• 여러 수평선으로 주요 가격 구간을 한눈에 파악',
        };
      case 'trendLine':
        return {
          'icon': Icons.trending_up,
          'title': '추세선',
          'description': '두 점을 연결하여 가격의 추세 방향과 강도를 시각화합니다.\n\n'
              '사용법:\n'
              '• 시작점과 끝점을 순서대로 탭하여 추세선을 그립니다\n'
              '• 선택 후 앵커(●)를 드래그하면 기울기를 조정합니다\n'
              '• 선 자체를 드래그하면 평행 이동합니다\n\n'
              '활용법:\n'
              '• 상승 추세: 연속된 저점(바닥)을 연결\n'
              '• 하락 추세: 연속된 고점(꼭대기)을 연결\n'
              '• 추세선 이탈(브레이크아웃)은 추세 전환 신호\n'
              '• 추세선에 닿을 때의 반등 → 매수/매도 타이밍',
        };
      case 'fibonacci':
        return {
          'icon': Icons.stacked_line_chart,
          'title': '피보나치 되돌림',
          'description': '가격 조정 시 되돌림 수준을 예측하는 7개 피보나치 레벨을 표시합니다.\n\n'
              '사용법:\n'
              '• 고점(100%)을 먼저 탭 → 저점(0%)을 탭합니다\n'
              '• 0%, 23.6%, 38.2%, 50%, 61.8%, 78.6%, 100% 레벨이 표시됩니다\n'
              '• 앵커(●)를 드래그하여 범위를 조정합니다\n\n'
              '활용법:\n'
              '• 38.2%와 61.8%가 가장 중요한 되돌림 레벨\n'
              '• 50%는 심리적 중간 지점으로 빈번하게 반응\n'
              '• 상승 후 조정 시: 되돌림 레벨에서의 반등 → 매수 기회\n'
              '• 하락 후 반등 시: 되돌림 레벨에서의 저항 → 매도 기회\n'
              '• 여러 피보나치 레벨이 겹치는 구간은 강한 지지/저항',
        };
      case 'supportResistanceZone':
        return {
          'icon': Icons.view_stream,
          'title': '지지/저항 영역',
          'description': '가격이 반복적으로 반등하거나 저항받는 구간을 영역으로 표시합니다.\n\n'
              '사용법:\n'
              '• 차트를 위아래로 드래그하여 가격 영역을 설정합니다\n'
              '• 선택 후 상/하 경계선을 개별 드래그하여 범위를 조정합니다\n'
              '• 영역 내부를 드래그하면 전체가 평행 이동합니다\n\n'
              '활용법:\n'
              '• 단일 수평선보다 현실적인 지지/저항 분석 가능\n'
              '• 거래량이 집중된 가격대에 설정하면 효과적\n'
              '• 과거에 여러 번 반등/저항이 일어난 구간을 커버\n'
              '• 영역 돌파 시 강한 추세 전환 신호로 해석',
        };
      case 'measure':
        return {
          'icon': Icons.straighten,
          'title': '측정 도구',
          'description': '두 지점 간의 가격 변화, 변동률, 캔들 수를 실시간으로 측정합니다.\n\n'
              '사용법:\n'
              '• 차트를 드래그하여 시작점→끝점을 지정합니다\n'
              '• 드래그 중 가격 차이, 변동률(%), 캔들 수가 표시됩니다\n'
              '• 드래그를 놓으면 측정이 사라지고 바로 재측정 가능합니다\n\n'
              '활용법:\n'
              '• 특정 구간의 수익률이나 기간을 빠르게 확인\n'
              '• 과거 상승/하락 패턴의 크기(폭, 기간)를 측정\n'
              '• 현재 움직임과 과거 패턴을 비교하여 목표가 산정\n'
              '• 캔들 수로 시간 경과를 직관적으로 파악',
        };
      default:
        return null;
    }
  }

  @override
  void dispose() {
    _dismissDrawingMenu();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════
  // 통합 드래그 제스처 (수평선 배치 + 기존 선 이동 + 스크롤/줌)
  // ═══════════════════════════════════════════════════════════════

  void _handleScaleStart(ScaleStartDetails details, double chartWidth,
      ChartYRange yRange) {
    // 1) 수평선 드래그 배치 모드
    if (_drawingMode == DrawingMode.horizontalLine) {
      final price = yRange.fromY(details.localFocalPoint.dy);
      setState(() {
        _isDraggingNewLine = true;
        _tempHorizontalPrice = price;
        _cachedYRange = yRange;
      });
      return;
    }

    // 2) 지지/저항 영역 드래그 배치 모드
    if (_drawingMode == DrawingMode.supportResistanceZone) {
      final price = yRange.fromY(details.localFocalPoint.dy);
      setState(() {
        _isDraggingNewZone = true;
        _tempZoneUpperPrice = price;
        _tempZoneLowerPrice = price;
        _cachedYRange = yRange;
      });
      return;
    }

    // 3) 측정 도구 드래그 모드
    if (_drawingMode == DrawingMode.measure) {
      final price = yRange.fromY(details.localFocalPoint.dy);
      final dataIndex = yRange.fromX(details.localFocalPoint.dx);
      final fullIndex = (dataIndex + _scrollOffset).clamp(0, widget.chartData.length - 1);
      setState(() {
        _isMeasuring = true;
        _measureStartFullIndex = fullIndex;
        _measureStartPrice = price;
        _measureEndFullIndex = fullIndex;
        _measureEndPrice = price;
        _cachedYRange = yRange;
      });
      return;
    }

    // 인라인 버튼 영역 터치 → 제스처 무시 (버튼이 자체 처리)
    if (_selectedDrawingId != null) {
      final selY = _getSelectedLineY(yRange);
      final touchX = details.localFocalPoint.dx;
      final touchY = details.localFocalPoint.dy;
      if (selY != null &&
          touchX >= 14 && touchX <= 50 &&
          touchY >= selY - 38 && touchY <= selY + 38) {
        return;
      }
    }

    // 4) 선택된 드로잉 드래그 이동 (잠금 아니고, 근처)
    if (_drawingMode == DrawingMode.none && _selectedDrawingId != null) {
      final drawings = ref.read(chartDrawingProvider);
      final selected = drawings.where((d) => d.id == _selectedDrawingId).firstOrNull;
      if (selected != null && !selected.isLocked) {
        final touchX = details.localFocalPoint.dx;
        final touchY = details.localFocalPoint.dy;
        bool isNearLine = false;

        if (selected.type == DrawingType.horizontalLine) {
          final lineY = yRange.toY(selected.price);
          isNearLine = (touchY - lineY).abs() <= 30;
        } else if (selected.type == DrawingType.trendLine &&
            selected.startDate != null && selected.endDate != null &&
            selected.startPrice != null && selected.endPrice != null) {
          // 앵커 점 근처인지 먼저 확인 (25px 이내 → 앵커 드래그)
          final startIdx = _findDateIndex(widget.chartData, selected.startDate!);
          final endIdx = _findDateIndex(widget.chartData, selected.endDate!);
          if (startIdx != null && endIdx != null) {
            final startX = yRange.toX(startIdx - _scrollOffset);
            final startY = yRange.toY(selected.startPrice!);
            final endX = yRange.toX(endIdx - _scrollOffset);
            final endY = yRange.toY(selected.endPrice!);

            final distToStart = (Offset(touchX, touchY) - Offset(startX, startY)).distance;
            final distToEnd = (Offset(touchX, touchY) - Offset(endX, endY)).distance;

            const anchorThreshold = 25.0;
            if (distToStart <= anchorThreshold || distToEnd <= anchorThreshold) {
              final anchor = distToStart <= distToEnd ? 'start' : 'end';
              setState(() {
                _isMovingDrawing = true;
                _movingDrawingId = selected.id;
                _draggingAnchor = anchor;
                _cachedYRange = yRange;
              });
              return;
            }
          }

          // 선 몸통 근처 → 평행 이동
          final dist = _trendLineDistance(
            Offset(touchX, touchY), selected, yRange, _scrollOffset,
          );
          isNearLine = dist <= 30;
        } else if (selected.type == DrawingType.fibonacci &&
            selected.startDate != null && selected.endDate != null &&
            selected.startPrice != null && selected.endPrice != null) {
          // 피보나치 앵커 드래그 (100%/0% 앵커)
          final startIdx = _findDateIndex(widget.chartData, selected.startDate!);
          final endIdx = _findDateIndex(widget.chartData, selected.endDate!);
          if (startIdx != null && endIdx != null) {
            final startX = yRange.toX(startIdx - _scrollOffset);
            final startY = yRange.toY(selected.startPrice!);
            final endX = yRange.toX(endIdx - _scrollOffset);
            final endY = yRange.toY(selected.endPrice!);

            final distToStart = (Offset(touchX, touchY) - Offset(startX, startY)).distance;
            final distToEnd = (Offset(touchX, touchY) - Offset(endX, endY)).distance;

            const anchorThreshold = 25.0;
            if (distToStart <= anchorThreshold || distToEnd <= anchorThreshold) {
              final anchor = distToStart <= distToEnd ? 'start' : 'end';
              setState(() {
                _isMovingDrawing = true;
                _movingDrawingId = selected.id;
                _draggingAnchor = anchor;
                _cachedYRange = yRange;
              });
              return;
            }
          }

          // 레벨 선 근처 → 평행 이동
          final dist = _fibonacciDistance(Offset(touchX, touchY), selected, yRange);
          isNearLine = dist <= 30;
        } else if (selected.type == DrawingType.supportResistanceZone) {
          // 지지/저항 영역: 상/하변 드래그 또는 평행 이동
          final upperY = yRange.toY(selected.price);
          final lowerY = yRange.toY(selected.lowerPrice);

          const edgeThreshold = 15.0;
          if ((touchY - upperY).abs() <= edgeThreshold) {
            // 상변 드래그
            setState(() {
              _isMovingDrawing = true;
              _movingDrawingId = selected.id;
              _draggingAnchor = 'upper';
              _cachedYRange = yRange;
            });
            return;
          } else if ((touchY - lowerY).abs() <= edgeThreshold) {
            // 하변 드래그
            setState(() {
              _isMovingDrawing = true;
              _movingDrawingId = selected.id;
              _draggingAnchor = 'lower';
              _cachedYRange = yRange;
            });
            return;
          }

          // 영역 내부 → 평행 이동
          final topY = math.min(upperY, lowerY);
          final bottomY = math.max(upperY, lowerY);
          isNearLine = touchY >= topY - 5 && touchY <= bottomY + 5;
        }

        if (isNearLine) {
          setState(() {
            _isMovingDrawing = true;
            _movingDrawingId = selected.id;
            _draggingAnchor = null;
            _moveStartY = touchY;
            _moveStartPrice = selected.price;
            _moveStartStartPrice = selected.startPrice;
            _moveStartEndPrice = selected.endPrice;
            _cachedYRange = yRange;
          });
          return;
        }
      }
    }

    // 5) 기본: 스크롤/줌
    _startVisibleCount = _visibleCount;
    _dragRemainder = 0.0;
  }

  void _handleScaleUpdate(ScaleUpdateDetails details, double chartWidth,
      ChartYRange yRange) {
    // 1) 수평선 드래그 배치 → 미리보기 업데이트
    if (_isDraggingNewLine && _cachedYRange != null) {
      setState(() {
        _tempHorizontalPrice = _cachedYRange!.fromY(details.localFocalPoint.dy);
      });
      return;
    }

    // 2) 지지/저항 영역 드래그 배치
    if (_isDraggingNewZone && _cachedYRange != null) {
      setState(() {
        _tempZoneLowerPrice = _cachedYRange!.fromY(details.localFocalPoint.dy);
      });
      return;
    }

    // 3) 측정 도구 드래그
    if (_isMeasuring && _cachedYRange != null) {
      final price = _cachedYRange!.fromY(details.localFocalPoint.dy);
      final dataIndex = _cachedYRange!.fromX(details.localFocalPoint.dx);
      final fullIndex = (dataIndex + _scrollOffset).clamp(0, widget.chartData.length - 1);
      setState(() {
        _measureEndFullIndex = fullIndex;
        _measureEndPrice = price;
      });
      return;
    }

    // 4) 기존 드로잉 드래그 이동 / 앵커 드래그
    if (_isMovingDrawing && _movingDrawingId != null && _cachedYRange != null) {
      final currentX = details.localFocalPoint.dx;
      final currentY = details.localFocalPoint.dy;
      final currentPrice = _cachedYRange!.fromY(currentY);
      final drawings = ref.read(chartDrawingProvider);
      final target = drawings.where((d) => d.id == _movingDrawingId).firstOrNull;
      if (target != null) {
        // 추세선/피보나치 앵커 드래그
        if (_draggingAnchor != null &&
            (target.type == DrawingType.trendLine || target.type == DrawingType.fibonacci)) {
          final displayIdx = _cachedYRange!.fromX(currentX);
          final fullIdx = (displayIdx + _scrollOffset).clamp(0, widget.chartData.length - 1);
          final newDate = widget.chartData[fullIdx].date;
          final newPrice = currentPrice;

          if (_draggingAnchor == 'start') {
            ref.read(chartDrawingProvider.notifier).updateDrawingLocal(
              target.copyWith(startDate: newDate, startPrice: newPrice),
            );
          } else {
            ref.read(chartDrawingProvider.notifier).updateDrawingLocal(
              target.copyWith(endDate: newDate, endPrice: newPrice),
            );
          }
        }
        // 지지/저항 영역 상/하변 드래그
        else if (_draggingAnchor == 'upper' && target.type == DrawingType.supportResistanceZone) {
          ref.read(chartDrawingProvider.notifier).updateDrawingLocal(
            target.copyWith(price: currentPrice),
          );
        } else if (_draggingAnchor == 'lower' && target.type == DrawingType.supportResistanceZone) {
          ref.read(chartDrawingProvider.notifier).updateDrawingLocal(
            target.copyWith(lowerPrice: currentPrice),
          );
        }
        // 추세선/피보나치 평행 이동
        else if ((target.type == DrawingType.trendLine || target.type == DrawingType.fibonacci) &&
            _moveStartStartPrice != null && _moveStartEndPrice != null &&
            _moveStartY != null) {
          final startPrice = _cachedYRange!.fromY(_moveStartY!);
          final priceDelta = currentPrice - startPrice;
          ref.read(chartDrawingProvider.notifier).updateDrawingLocal(
            target.copyWith(
              startPrice: _moveStartStartPrice! + priceDelta,
              endPrice: _moveStartEndPrice! + priceDelta,
            ),
          );
        }
        // 지지/저항 영역 평행 이동
        else if (target.type == DrawingType.supportResistanceZone &&
            _moveStartPrice != null && _moveStartY != null) {
          final startPrice = _cachedYRange!.fromY(_moveStartY!);
          final priceDelta = currentPrice - startPrice;
          final zoneHeight = target.price - target.lowerPrice;
          ref.read(chartDrawingProvider.notifier).updateDrawingLocal(
            target.copyWith(
              price: _moveStartPrice! + priceDelta,
              lowerPrice: _moveStartPrice! - zoneHeight + priceDelta,
            ),
          );
        }
        // 수평선: price 직접 업데이트
        else {
          ref.read(chartDrawingProvider.notifier)
              .updateDrawingLocal(target.copyWith(price: currentPrice));
        }
      }
      return;
    }

    // 5) 기본: 스크롤/줌 (드로잉 모드 중에는 비활성)
    if (_drawingMode == DrawingMode.none) {
      _handleZoomScroll(details, chartWidth);
    }
  }

  void _handleScaleEnd(ScaleEndDetails details) {
    // 1) 수평선 드래그 배치 완료 → 선 확정
    if (_isDraggingNewLine && _tempHorizontalPrice != null) {
      _createHorizontalLine(_tempHorizontalPrice!);
      setState(() {
        _isDraggingNewLine = false;
        _tempHorizontalPrice = null;
        _cachedYRange = null;
      });
      return;
    }

    // 2) 지지/저항 영역 드래그 배치 완료 → 영역 생성
    if (_isDraggingNewZone && _tempZoneUpperPrice != null && _tempZoneLowerPrice != null) {
      // 최소 높이 체크 (너무 작으면 무시)
      if ((_tempZoneUpperPrice! - _tempZoneLowerPrice!).abs() > 0.01) {
        _createSRZone(_tempZoneUpperPrice!, _tempZoneLowerPrice!);
      }
      setState(() {
        _isDraggingNewZone = false;
        _tempZoneUpperPrice = null;
        _tempZoneLowerPrice = null;
        _cachedYRange = null;
      });
      return;
    }

    // 3) 측정 도구 드래그 완료 → 상태 클리어 (모드 유지)
    if (_isMeasuring) {
      setState(() {
        _isMeasuring = false;
        _measureStartFullIndex = null;
        _measureEndFullIndex = null;
        _measureStartPrice = null;
        _measureEndPrice = null;
        _cachedYRange = null;
      });
      return;
    }

    // 4) 기존 드로잉 이동 완료 → Hive 저장
    if (_isMovingDrawing && _movingDrawingId != null) {
      final drawings = ref.read(chartDrawingProvider);
      final target = drawings.where((d) => d.id == _movingDrawingId).firstOrNull;
      if (target != null) {
        ref.read(chartDrawingProvider.notifier).updateDrawing(target);
      }
      setState(() {
        _isMovingDrawing = false;
        _movingDrawingId = null;
        _cachedYRange = null;
        _moveStartY = null;
        _moveStartPrice = null;
        _moveStartStartPrice = null;
        _moveStartEndPrice = null;
        _draggingAnchor = null;
      });
      return;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // 설정 패널
  // ═══════════════════════════════════════════════════════════════

  void _showDrawingSettings() {
    if (_selectedDrawingId == null) return;
    final drawings = ref.read(chartDrawingProvider);
    final drawing = drawings.where((d) => d.id == _selectedDrawingId).firstOrNull;
    if (drawing == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DrawingSettingsSheet(
        drawing: drawing,
        onSave: (updated) {
          ref.read(chartDrawingProvider.notifier).updateDrawing(updated);
        },
      ),
    );
  }

  /// 선택된 드로잉의 Y 픽셀 좌표 계산 (인라인 버튼 위치용)
  double? _getSelectedLineY(ChartYRange yRange) {
    if (_selectedDrawingId == null) return null;
    final drawings = ref.read(chartDrawingProvider);
    final selected = drawings.where((d) => d.id == _selectedDrawingId).firstOrNull;
    if (selected == null) return null;

    if (selected.type == DrawingType.horizontalLine) {
      return yRange.toY(selected.price);
    }
    // 추세선/피보나치: 중간점의 Y 좌표 사용
    if (selected.type == DrawingType.trendLine || selected.type == DrawingType.fibonacci) {
      if (selected.startPrice != null && selected.endPrice != null) {
        return yRange.toY((selected.startPrice! + selected.endPrice!) / 2);
      }
    }
    // 지지/저항 영역: 중간 가격의 Y 좌표
    if (selected.type == DrawingType.supportResistanceZone) {
      return yRange.toY((selected.price + selected.lowerPrice) / 2);
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
      final lastRsi = _lastNonNull(displayRSI);
      rsiLabel = lastRsi != null ? 'RSI(14): ${lastRsi.toStringAsFixed(1)}' : 'RSI(14)';
    }

    // MACD 현재값 라벨
    String? macdLabel;
    if (_activeIndicators.contains('MACD') && displayMACD != null) {
      final lastMacd = _lastValid(displayMACD, (m) => m.macdLine != null);
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
      final lastStoch = _lastValid(displayStoch, (s) => s.k != null);
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
    if (_activeIndicators.contains('OBV') && displayOBV != null && displayOBV.isNotEmpty) {
      obvLabel = 'OBV: ${formatVolume(displayOBV.last)}';
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
                child: Center(child: _buildDrawingToggle()),
              ),
            ],
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
                    child: Builder(
                      builder: (context) {
                        final yRange = ChartCoordinateCalculator.calculate(
                          data: displayData,
                          width: chartWidth,
                          height: 300,
                          bollingerBands: displayBB,
                          ichimoku: displayIchimoku,
                          bbSummary: bbSummary,
                          ichSummary: ichSummary,
                        );
                        final selectedLineY = _getSelectedLineY(yRange);
                        final nextColor = _drawingColors[_colorIndex % _drawingColors.length];
                        return GestureDetector(
                          onScaleStart: (details) =>
                              _handleScaleStart(details, chartWidth, yRange),
                          onScaleUpdate: (details) =>
                              _handleScaleUpdate(details, chartWidth, yRange),
                          onScaleEnd: _handleScaleEnd,
                          onTapUp: (details) => _handleChartTap(
                            details, chartWidth, displayData, displayBB,
                            displayIchimoku, bbSummary, ichSummary, offset,
                          ),
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
                                      // 가이드 바 (드로잉 모드 시 상단)
                                      Positioned(
                                        top: 0,
                                        left: 0,
                                        right: 0,
                                        child: DrawingGuideBar(
                                          drawingMode: _drawingMode,
                                          waitingSecondPoint: _waitingSecondPoint,
                                          onCancel: _cancelDrawing,
                                        ),
                                      ),
                                      // 인라인 선택 버튼 (선 좌측, 선택 시만)
                                      if (_selectedDrawingId != null && selectedLineY != null)
                                        DrawingSelectionButtons(
                                          lineY: selectedLineY,
                                          onSettings: () {
                                            _ignoreNextTap = true;
                                            _showDrawingSettings();
                                          },
                                          onDelete: () {
                                            _ignoreNextTap = true;
                                            _deleteSelectedDrawing();
                                          },
                                        ),
                                    ],
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
