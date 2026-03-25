import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/services/technical_indicator_service.dart';
import 'chart_controls.dart';
import 'sub_chart_painters.dart';

const _uuid = Uuid();

// -----------------------------------------------------------------
// RSI Drawing Line model (memory-only, no Hive)
// fullDataIndex: zoom/scroll-safe absolute index into fullData
// -----------------------------------------------------------------

class RsiDrawingLine {
  final String id;
  double startRsi; // RSI value (0~100)
  int startFullIndex; // fullData index
  double endRsi;
  int endFullIndex;
  int colorValue;
  double strokeWidth;
  bool isLocked;

  RsiDrawingLine({
    required this.id,
    required this.startRsi,
    required this.startFullIndex,
    required this.endRsi,
    required this.endFullIndex,
    this.colorValue = 0xFFFF6B6B,
    this.strokeWidth = 1.5,
    this.isLocked = false,
  });

  RsiDrawingLine copyWith({
    int? colorValue,
    double? strokeWidth,
    bool? isLocked,
  }) {
    return RsiDrawingLine(
      id: id,
      startRsi: startRsi,
      startFullIndex: startFullIndex,
      endRsi: endRsi,
      endFullIndex: endFullIndex,
      colorValue: colorValue ?? this.colorValue,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      isLocked: isLocked ?? this.isLocked,
    );
  }
}

// -----------------------------------------------------------------
// Preset colors
// -----------------------------------------------------------------

const List<int> _presetColors = [
  0xFFFF6B6B, // red
  0xFF4ECDC4, // teal
  0xFFFFD93D, // yellow
  0xFF6BCB77, // green
  0xFF4D96FF, // blue
  0xFFFF8C42, // orange
  0xFFE879F9, // purple
  0xFF94A3B8, // gray
];

// -----------------------------------------------------------------
// RsiDrawingOverlay
// -----------------------------------------------------------------

class RsiDrawingOverlay extends StatefulWidget {
  final double chartWidth;
  final double chartHeight;
  final List<double?> rsiValues; // displayData basis
  final List<double?> fullRsiValues; // fullData basis (for snap)
  final bool isDarkMode;
  final Color textColor;
  final int displayDataLength;
  final int scrollOffset; // fullData offset

  // RSI header
  final String rsiLabel;
  final Color rsiLabelColor;
  final IndicatorSignal? rsiSignal;

  // crosshair
  final double? crosshairX;

  // 부모 소유 lines (리빌드에도 보존)
  final List<RsiDrawingLine>? externalLines;
  final VoidCallback? onLinesChanged;
  final VoidCallback? onHelpTap;

  const RsiDrawingOverlay({
    super.key,
    required this.chartWidth,
    required this.chartHeight,
    required this.rsiValues,
    required this.fullRsiValues,
    required this.isDarkMode,
    required this.textColor,
    required this.displayDataLength,
    required this.scrollOffset,
    required this.rsiLabel,
    required this.rsiLabelColor,
    this.rsiSignal,
    this.crosshairX,
    this.externalLines,
    this.onLinesChanged,
    this.onHelpTap,
  });

  @override
  State<RsiDrawingOverlay> createState() => RsiDrawingOverlayState();
}

class RsiDrawingOverlayState extends State<RsiDrawingOverlay> {
  // 부모가 externalLines를 전달하면 그것을 사용, 아니면 로컬
  final List<RsiDrawingLine> _localLines = [];
  List<RsiDrawingLine> get _lines => widget.externalLines ?? _localLines;

  bool _isDrawing = false;
  String? _selectedLineId;

  // First point (waiting for second)
  int? _firstPointFullIndex;
  double? _firstPointRsi;

  // Anchor drag
  String? _draggingLineId;
  String? _draggingAnchor; // 'start' or 'end'

  bool get isDrawing => _isDrawing;

  /// lines 변경 시 setState + 부모 알림
  void _notifyLines() {
    setState(() {});
    widget.onLinesChanged?.call();
  }

  // --- coordinate transforms (same constants as RSIPainter) ---

  static const double _leftPadding = 10.0;
  static const double _rightPadding = 50.0;
  static const double _topPadding = 4.0;
  static const double _bottomPadding = 4.0;

  double get _chartAreaWidth => widget.chartWidth - _leftPadding - _rightPadding;
  double get _candleWidth => widget.displayDataLength > 0
      ? _chartAreaWidth / widget.displayDataLength
      : 1.0;
  double get _drawableHeight => widget.chartHeight - _topPadding - _bottomPadding;

  double _toY(double rsiValue) =>
      _topPadding + (1 - rsiValue / 100) * _drawableHeight;

  double _fromY(double y) =>
      ((1 - (y - _topPadding) / _drawableHeight) * 100).clamp(0.0, 100.0);

  /// Convert fullData index to screen X (may be offscreen)
  double _fullIndexToX(int fullIndex) {
    final displayIndex = fullIndex - widget.scrollOffset;
    return _leftPadding + displayIndex * _candleWidth + _candleWidth / 2;
  }

  int _xToDisplayIndex(double x) =>
      ((x - _leftPadding) / _candleWidth).round().clamp(0, widget.displayDataLength - 1);

  /// Get RSI value for a fullData index
  double? _rsiAtFullIndex(int fullIndex) {
    if (fullIndex < 0 || fullIndex >= widget.fullRsiValues.length) return null;
    return widget.fullRsiValues[fullIndex];
  }

  // --- External point placement from main chart ---

  /// Called by parent when main chart long-press places a point
  void addPointFromMainChart(int fullIndex) {
    if (!_isDrawing) return;

    final rsi = _rsiAtFullIndex(fullIndex);
    if (rsi == null) return;

    if (_firstPointFullIndex == null) {
      // First point
      setState(() {
        _firstPointFullIndex = fullIndex;
        _firstPointRsi = rsi;
      });
    } else {
      // Second point -> create line
      _lines.add(RsiDrawingLine(
        id: _uuid.v4(),
        startRsi: _firstPointRsi!,
        startFullIndex: _firstPointFullIndex!,
        endRsi: rsi,
        endFullIndex: fullIndex,
      ));
      _firstPointFullIndex = null;
      _firstPointRsi = null;
      _notifyLines();
    }
  }

  @override
  void didUpdateWidget(RsiDrawingOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  // --- hit test: distance from point to line segment ---

  double _distanceToSegment(Offset point, Offset a, Offset b) {
    final ab = b - a;
    final ap = point - a;
    final lenSq = ab.dx * ab.dx + ab.dy * ab.dy;
    if (lenSq == 0) return (point - a).distance;
    final t = (ap.dx * ab.dx + ap.dy * ab.dy) / lenSq;
    final clamped = t.clamp(0.0, 1.0);
    final proj = Offset(a.dx + clamped * ab.dx, a.dy + clamped * ab.dy);
    return (point - proj).distance;
  }

  String? _hitTestLine(Offset localPos) {
    const hitRadius = 12.0;
    for (final line in _lines.reversed) {
      final a = Offset(_fullIndexToX(line.startFullIndex), _toY(line.startRsi));
      final b = Offset(_fullIndexToX(line.endFullIndex), _toY(line.endRsi));
      if (_distanceToSegment(localPos, a, b) < hitRadius) {
        return line.id;
      }
    }
    return null;
  }

  String? _hitTestAnchor(Offset localPos, RsiDrawingLine line) {
    const anchorRadius = 14.0;
    final startOff = Offset(_fullIndexToX(line.startFullIndex), _toY(line.startRsi));
    final endOff = Offset(_fullIndexToX(line.endFullIndex), _toY(line.endRsi));
    if ((localPos - startOff).distance < anchorRadius) return 'start';
    if ((localPos - endOff).distance < anchorRadius) return 'end';
    return null;
  }

  // --- gesture handlers ---

  void _handleTap(TapUpDetails details) {
    final pos = details.localPosition;

    if (_isDrawing) {
      // In drawing mode, tap on RSI chart = direct point placement
      final displayIdx = _xToDisplayIndex(pos.dx);
      final fullIdx = displayIdx + widget.scrollOffset;
      final rsi = _rsiAtFullIndex(fullIdx);
      if (rsi == null) return;

      if (_firstPointFullIndex == null) {
        setState(() {
          _firstPointFullIndex = fullIdx;
          _firstPointRsi = rsi;
        });
      } else {
        _lines.add(RsiDrawingLine(
          id: _uuid.v4(),
          startRsi: _firstPointRsi!,
          startFullIndex: _firstPointFullIndex!,
          endRsi: rsi,
          endFullIndex: fullIdx,
        ));
        _firstPointFullIndex = null;
        _firstPointRsi = null;
        _notifyLines();
      }
      return;
    }

    // Non-drawing mode: select/deselect
    final hitId = _hitTestLine(pos);
    setState(() {
      _selectedLineId = hitId;
    });
  }

  void _handleDragStart(DragStartDetails details) {
    if (_isDrawing) return;
    if (_selectedLineId == null) return;

    final line = _lines.cast<RsiDrawingLine?>().firstWhere(
      (l) => l!.id == _selectedLineId,
      orElse: () => null,
    );
    if (line == null || line.isLocked) return;

    final anchor = _hitTestAnchor(details.localPosition, line);
    if (anchor != null) {
      setState(() {
        _draggingLineId = line.id;
        _draggingAnchor = anchor;
      });
    }
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (_draggingLineId == null || _draggingAnchor == null) return;

    final line = _lines.cast<RsiDrawingLine?>().firstWhere(
      (l) => l!.id == _draggingLineId,
      orElse: () => null,
    );
    if (line == null) return;

    final pos = details.localPosition;
    final displayIdx = _xToDisplayIndex(pos.dx);
    final fullIdx = displayIdx + widget.scrollOffset;
    final rsi = _rsiAtFullIndex(fullIdx);
    if (rsi == null) return;

    setState(() {
      if (_draggingAnchor == 'start') {
        line.startFullIndex = fullIdx;
        line.startRsi = rsi;
      } else {
        line.endFullIndex = fullIdx;
        line.endRsi = rsi;
      }
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    _draggingLineId = null;
    _draggingAnchor = null;
    _notifyLines();
  }

  // --- actions ---

  void _deleteSelected() {
    if (_selectedLineId == null) return;
    _lines.removeWhere((l) => l.id == _selectedLineId);
    _selectedLineId = null;
    _notifyLines();
  }

  void _clearAll() {
    if (_lines.isEmpty) return;
    _lines.clear();
    _selectedLineId = null;
    _firstPointFullIndex = null;
    _firstPointRsi = null;
    _isDrawing = false;
    _notifyLines();
  }

  void _showSettings() {
    if (_selectedLineId == null) return;
    final line = _lines.cast<RsiDrawingLine?>().firstWhere(
      (l) => l!.id == _selectedLineId,
      orElse: () => null,
    );
    if (line == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _RsiLineSettingsSheet(
        line: line,
        onSave: (updated) {
          final idx = _lines.indexWhere((l) => l.id == updated.id);
          if (idx >= 0) {
            _lines[idx] = RsiDrawingLine(
              id: updated.id,
              startRsi: _lines[idx].startRsi,
              startFullIndex: _lines[idx].startFullIndex,
              endRsi: _lines[idx].endRsi,
              endFullIndex: _lines[idx].endFullIndex,
              colorValue: updated.colorValue,
              strokeWidth: updated.strokeWidth,
              isLocked: updated.isLocked,
            );
          }
          _notifyLines();
        },
      ),
    );
  }

  // --- build ---

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 768;
    final headerFontSize = isDesktop ? 13.0 : 11.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- RSI header + draw button + clear button ---
        Padding(
          padding: EdgeInsets.only(top: isDesktop ? 6 : 2, bottom: isDesktop ? 2 : 0),
          child: Row(
            children: [
              Text(
                widget.rsiLabel,
                style: TextStyle(
                  color: widget.rsiLabelColor,
                  fontSize: headerFontSize,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 4),
              // Trendline draw toggle
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isDrawing = !_isDrawing;
                    if (!_isDrawing) {
                      _firstPointFullIndex = null;
                      _firstPointRsi = null;
                    }
                    _selectedLineId = null;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: _isDrawing
                        ? (widget.isDarkMode
                            ? AppColors.darkAccent.withAlpha(30)
                            : AppColors.primary.withAlpha(20))
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Icon(
                    Icons.show_chart, // trendline icon
                    size: isDesktop ? 15 : 13,
                    color: _isDrawing
                        ? (widget.isDarkMode ? AppColors.darkAccent : AppColors.primary)
                        : widget.textColor.withAlpha(150),
                  ),
                ),
              ),
              // Clear all button (visible when lines exist)
              if (_lines.isNotEmpty) ...[
                const SizedBox(width: 2),
                GestureDetector(
                  onTap: _clearAll,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Icon(
                      Icons.delete_sweep_outlined,
                      size: isDesktop ? 15 : 13,
                      color: widget.textColor.withAlpha(150),
                    ),
                  ),
                ),
              ],
              // Drawing mode hint
              if (_isDrawing)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(
                    _firstPointFullIndex == null ? '1st' : '2nd',
                    style: TextStyle(
                      fontSize: 9,
                      color: widget.isDarkMode ? AppColors.darkAccent : AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              const Spacer(),
              // 신호 배지
              if (widget.rsiSignal != null)
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: SignalBadge(signal: widget.rsiSignal!),
                ),
              // 설명 아이콘 (탭 영역 확대)
              if (widget.onHelpTap != null)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onHelpTap,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Icon(
                      Icons.help_outline,
                      size: isDesktop ? 14 : 12,
                      color: widget.textColor.withAlpha(150),
                    ),
                  ),
                ),
            ],
          ),
        ),
        // --- RSI chart + drawing overlay ---
        SizedBox(
          height: widget.chartHeight,
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              // Base RSI chart
              CustomPaint(
                size: Size(widget.chartWidth, widget.chartHeight),
                painter: RSIPainter(
                  rsiValues: widget.rsiValues,
                  isDarkMode: widget.isDarkMode,
                  textColor: widget.textColor,
                ),
              ),
              // Drawing lines overlay
              CustomPaint(
                size: Size(widget.chartWidth, widget.chartHeight),
                painter: _RsiLinePainter(
                  lines: _lines,
                  selectedLineId: _selectedLineId,
                  firstPointOffset: _firstPointFullIndex != null
                      ? Offset(
                          _fullIndexToX(_firstPointFullIndex!),
                          _toY(_firstPointRsi!),
                        )
                      : null,
                  chartWidth: widget.chartWidth,
                  chartHeight: widget.chartHeight,
                  displayDataLength: widget.displayDataLength,
                  scrollOffset: widget.scrollOffset,
                  fullRsiValues: widget.fullRsiValues,
                  isDarkMode: widget.isDarkMode,
                ),
              ),
              // Crosshair
              if (widget.crosshairX != null)
                Positioned(
                  left: widget.crosshairX,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 0.8,
                    color: widget.textColor.withAlpha(80),
                  ),
                ),
              // Gesture layer
              GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTapUp: _handleTap,
                onPanStart: !_isDrawing ? _handleDragStart : null,
                onPanUpdate: !_isDrawing ? _handleDragUpdate : null,
                onPanEnd: !_isDrawing ? _handleDragEnd : null,
              ),
              // Selection buttons
              if (_selectedLineId != null)
                _buildSelectionButtons(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSelectionButtons() {
    final line = _lines.cast<RsiDrawingLine?>().firstWhere(
      (l) => l!.id == _selectedLineId,
      orElse: () => null,
    );
    if (line == null) return const SizedBox.shrink();

    final midX = (_fullIndexToX(line.startFullIndex) + _fullIndexToX(line.endFullIndex)) / 2;
    final midY = (_toY(line.startRsi) + _toY(line.endRsi)) / 2;

    final btnTop = (midY - 28).clamp(0.0, widget.chartHeight - 24);
    final btnLeft = (midX - 28).clamp(0.0, widget.chartWidth - 56);

    return Positioned(
      left: btnLeft,
      top: btnTop,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ActionButton(
            icon: Icons.delete_outline,
            color: AppColors.red500,
            bgColor: widget.isDarkMode
                ? AppColors.darkCardBackground
                : AppColors.surface,
            onTap: _deleteSelected,
          ),
          const SizedBox(width: 4),
          _ActionButton(
            icon: Icons.settings_outlined,
            color: widget.isDarkMode
                ? AppColors.darkTextSecondary
                : AppColors.gray500,
            bgColor: widget.isDarkMode
                ? AppColors.darkCardBackground
                : AppColors.surface,
            onTap: _showSettings,
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------
// Mini action button
// -----------------------------------------------------------------

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color bgColor;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: bgColor,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(30),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Icon(icon, size: 14, color: color),
      ),
    );
  }
}

// -----------------------------------------------------------------
// RSI Drawing Line Painter — now with RSI value labels
// -----------------------------------------------------------------

class _RsiLinePainter extends CustomPainter {
  final List<RsiDrawingLine> lines;
  final String? selectedLineId;
  final Offset? firstPointOffset;
  final double chartWidth;
  final double chartHeight;
  final int displayDataLength;
  final int scrollOffset;
  final List<double?> fullRsiValues;
  final bool isDarkMode;

  _RsiLinePainter({
    required this.lines,
    this.selectedLineId,
    this.firstPointOffset,
    required this.chartWidth,
    required this.chartHeight,
    required this.displayDataLength,
    required this.scrollOffset,
    required this.fullRsiValues,
    required this.isDarkMode,
  });

  static const double _leftPadding = 10.0;
  static const double _rightPadding = 50.0;
  static const double _topPadding = 4.0;
  static const double _bottomPadding = 4.0;

  double get _areaWidth => chartWidth - _leftPadding - _rightPadding;
  double get _candleWidth => displayDataLength > 0 ? _areaWidth / displayDataLength : 1.0;
  double get _drawableH => chartHeight - _topPadding - _bottomPadding;

  double _toX(int fullIndex) {
    final displayIndex = fullIndex - scrollOffset;
    return _leftPadding + displayIndex * _candleWidth + _candleWidth / 2;
  }

  double _toY(double rsi) => _topPadding + (1 - rsi / 100) * _drawableH;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    // 차트 영역만 클리핑 (Y축 라벨 영역 rightPadding 제외)
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width - _rightPadding, size.height));

    for (final line in lines) {
      final isSelected = line.id == selectedLineId;
      final color = Color(line.colorValue);

      final startOff = Offset(_toX(line.startFullIndex), _toY(line.startRsi));
      final endOff = Offset(_toX(line.endFullIndex), _toY(line.endRsi));

      // Line segment
      final paint = Paint()
        ..color = color
        ..strokeWidth = line.strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(startOff, endOff, paint);

      // Anchor points
      final anchorRadius = isSelected ? 5.0 : 3.5;
      final anchorPaint = Paint()..color = color..style = PaintingStyle.fill;
      canvas.drawCircle(startOff, anchorRadius, anchorPaint);
      canvas.drawCircle(endOff, anchorRadius, anchorPaint);

      // Selection border
      if (isSelected) {
        final borderPaint = Paint()
          ..color = isDarkMode ? Colors.white.withAlpha(180) : Colors.black.withAlpha(120)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;
        canvas.drawCircle(startOff, anchorRadius + 1.5, borderPaint);
        canvas.drawCircle(endOff, anchorRadius + 1.5, borderPaint);
      }

      // RSI value labels at endpoints
      _drawRsiLabel(canvas, startOff, line.startRsi, color, isStart: true);
      _drawRsiLabel(canvas, endOff, line.endRsi, color, isStart: false);
    }

    // First point preview
    if (firstPointOffset != null) {
      final dotPaint = Paint()
        ..color = const Color(0xFFFF6B6B)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(firstPointOffset!, 4, dotPaint);

      final ringPaint = Paint()
        ..color = const Color(0xFFFF6B6B).withAlpha(80)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(firstPointOffset!, 8, ringPaint);

      // Show RSI value for first point too
      // Calculate RSI from Y position
      final rsi = ((1 - (firstPointOffset!.dy - _topPadding) / _drawableH) * 100).clamp(0.0, 100.0);
      _drawRsiLabel(canvas, firstPointOffset!, rsi, const Color(0xFFFF6B6B), isStart: true);
    }

    canvas.restore();
  }

  void _drawRsiLabel(Canvas canvas, Offset anchor, double rsi, Color color, {required bool isStart}) {
    final text = rsi.toStringAsFixed(1);
    final textSpan = TextSpan(
      text: text,
      style: TextStyle(
        color: color,
        fontSize: 9,
        fontWeight: FontWeight.w600,
      ),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: ui.TextDirection.ltr,
    );
    textPainter.layout();

    // RSI >= 50: label above anchor, RSI < 50: label below anchor
    final dx = anchor.dx - textPainter.width / 2;
    final dy = rsi >= 50
        ? anchor.dy - textPainter.height - 4  // above
        : anchor.dy + 6;                       // below

    // Background for readability
    final bgRect = Rect.fromLTWH(
      dx - 2, dy - 1,
      textPainter.width + 4, textPainter.height + 2,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(bgRect, const Radius.circular(2)),
      Paint()..color = (isDarkMode ? Colors.black : Colors.white).withAlpha(180),
    );

    textPainter.paint(canvas, Offset(dx, dy));
  }

  @override
  bool shouldRepaint(covariant _RsiLinePainter oldDelegate) => true;
}

// -----------------------------------------------------------------
// RSI Line Settings Bottom Sheet
// -----------------------------------------------------------------

class _RsiLineSettingsSheet extends StatefulWidget {
  final RsiDrawingLine line;
  final ValueChanged<RsiDrawingLine> onSave;

  const _RsiLineSettingsSheet({
    required this.line,
    required this.onSave,
  });

  @override
  State<_RsiLineSettingsSheet> createState() => _RsiLineSettingsSheetState();
}

class _RsiLineSettingsSheetState extends State<_RsiLineSettingsSheet> {
  late int _colorValue;
  late double _strokeWidth;
  late bool _isLocked;

  static const List<_StrokeOption> _strokeOptions = [
    _StrokeOption(label: '얇게', value: 1.0),
    _StrokeOption(label: '보통', value: 1.5),
    _StrokeOption(label: '굵게', value: 3.0),
  ];

  @override
  void initState() {
    super.initState();
    _colorValue = widget.line.colorValue;
    _strokeWidth = widget.line.strokeWidth;
    _isLocked = widget.line.isLocked;
  }

  void _emitChange() {
    widget.onSave(widget.line.copyWith(
      colorValue: _colorValue,
      strokeWidth: _strokeWidth,
      isLocked: _isLocked,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDarkMode ? AppColors.darkCardBackground : AppColors.cardBackground;
    final textPrimary = isDarkMode ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final textSecondary = isDarkMode ? AppColors.darkTextSecondary : AppColors.textSecondary;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDarkMode ? AppColors.darkBorder : AppColors.gray300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'RSI 선 설정',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Text('색상', style: TextStyle(fontSize: 13, color: textSecondary)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _presetColors.map((c) {
              final isSelected = c == _colorValue;
              return GestureDetector(
                onTap: () {
                  setState(() => _colorValue = c);
                  _emitChange();
                },
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Color(c),
                    shape: BoxShape.circle,
                    border: isSelected
                        ? Border.all(
                            color: isDarkMode ? Colors.white : Colors.black,
                            width: 2,
                          )
                        : null,
                    boxShadow: isSelected
                        ? [BoxShadow(color: Color(c).withAlpha(80), blurRadius: 6)]
                        : null,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Text('굵기', style: TextStyle(fontSize: 13, color: textSecondary)),
          const SizedBox(height: 8),
          Row(
            children: _strokeOptions.map((opt) {
              final isSelected = (_strokeWidth - opt.value).abs() < 0.01;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(opt.label),
                  selected: isSelected,
                  onSelected: (_) {
                    setState(() => _strokeWidth = opt.value);
                    _emitChange();
                  },
                  labelStyle: TextStyle(
                    fontSize: 12,
                    color: isSelected ? Colors.white : textSecondary,
                  ),
                  selectedColor: isDarkMode ? AppColors.darkAccent : AppColors.primary,
                  backgroundColor: isDarkMode ? AppColors.darkSurface : AppColors.gray100,
                  side: BorderSide.none,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('위치 잠금', style: TextStyle(fontSize: 13, color: textSecondary)),
              Switch.adaptive(
                value: _isLocked,
                onChanged: (v) {
                  setState(() => _isLocked = v);
                  _emitChange();
                },
                activeColor: isDarkMode ? AppColors.darkAccent : AppColors.primary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StrokeOption {
  final String label;
  final double value;
  const _StrokeOption({required this.label, required this.value});
}
