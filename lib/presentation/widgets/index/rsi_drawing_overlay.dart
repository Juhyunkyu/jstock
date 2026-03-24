import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/services/technical_indicator_service.dart';
import 'chart_controls.dart';
import 'sub_chart_painters.dart';

const _uuid = Uuid();

// ─────────────────────────────────────────────────────────────
// RSI Drawing Line 모델 (메모리 전용, Hive 저장 안 함)
// ─────────────────────────────────────────────────────────────

class RsiDrawingLine {
  final String id;
  double startY; // RSI 값 (0~100)
  int startIndex; // displayData 기준 인덱스
  double endY;
  int endIndex;
  int colorValue;
  double strokeWidth;
  bool isLocked;

  RsiDrawingLine({
    required this.id,
    required this.startY,
    required this.startIndex,
    required this.endY,
    required this.endIndex,
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
      startY: startY,
      startIndex: startIndex,
      endY: endY,
      endIndex: endIndex,
      colorValue: colorValue ?? this.colorValue,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      isLocked: isLocked ?? this.isLocked,
    );
  }
}

// ─────────────────────────────────────────────────────────────
// 프리셋 색상 (drawing_settings_sheet.dart 와 동일 팔레트)
// ─────────────────────────────────────────────────────────────

const List<int> _presetColors = [
  0xFFFF6B6B, // 빨강
  0xFF4ECDC4, // 청록
  0xFFFFD93D, // 노랑
  0xFF6BCB77, // 초록
  0xFF4D96FF, // 파랑
  0xFFFF8C42, // 주황
  0xFFE879F9, // 보라
  0xFF94A3B8, // 회색
];

// ─────────────────────────────────────────────────────────────
// RsiDrawingOverlay — RSI 헤더 + 차트 + 드로잉 레이어 자기완결 위젯
// ─────────────────────────────────────────────────────────────

class RsiDrawingOverlay extends StatefulWidget {
  final double chartWidth;
  final double chartHeight;
  final List<double?> rsiValues;
  final bool isDarkMode;
  final Color textColor;
  final int displayDataLength;

  // RSI 헤더 정보
  final String rsiLabel;
  final Color rsiLabelColor;
  final IndicatorSignal? rsiSignal;

  // 수직 십자선
  final double? crosshairX;

  const RsiDrawingOverlay({
    super.key,
    required this.chartWidth,
    required this.chartHeight,
    required this.rsiValues,
    required this.isDarkMode,
    required this.textColor,
    required this.displayDataLength,
    required this.rsiLabel,
    required this.rsiLabelColor,
    this.rsiSignal,
    this.crosshairX,
  });

  @override
  State<RsiDrawingOverlay> createState() => _RsiDrawingOverlayState();
}

class _RsiDrawingOverlayState extends State<RsiDrawingOverlay> {
  final List<RsiDrawingLine> _lines = [];
  bool _isDrawing = false;
  String? _selectedLineId;

  // 그리기 모드: 첫 번째 점
  int? _firstPointIndex;
  double? _firstPointRsiValue;

  // 앵커 드래그
  String? _draggingLineId;
  String? _draggingAnchor; // 'start' or 'end'

  // ─── 좌표 변환 (RSIPainter 와 동일 상수) ───

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

  double _toX(int index) =>
      _leftPadding + index * _candleWidth + _candleWidth / 2;

  int _fromX(double x) =>
      ((x - _leftPadding) / _candleWidth).round().clamp(0, widget.displayDataLength - 1);

  // ─── 히트 테스트: 선분과 점의 거리 ───

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

  // ─── 선 근처 탭 → 선택 ───

  String? _hitTestLine(Offset localPos) {
    const hitRadius = 12.0;
    for (final line in _lines.reversed) {
      final a = Offset(_toX(line.startIndex), _toY(line.startY));
      final b = Offset(_toX(line.endIndex), _toY(line.endY));
      if (_distanceToSegment(localPos, a, b) < hitRadius) {
        return line.id;
      }
    }
    return null;
  }

  // ─── 앵커 히트 테스트 ───

  String? _hitTestAnchor(Offset localPos, RsiDrawingLine line) {
    const anchorRadius = 14.0;
    final startOff = Offset(_toX(line.startIndex), _toY(line.startY));
    final endOff = Offset(_toX(line.endIndex), _toY(line.endY));
    if ((localPos - startOff).distance < anchorRadius) return 'start';
    if ((localPos - endOff).distance < anchorRadius) return 'end';
    return null;
  }

  // ─── 제스처 핸들러 ───

  void _handleTap(TapUpDetails details) {
    final pos = details.localPosition;

    if (_isDrawing) {
      // 그리기 모드
      final idx = _fromX(pos.dx);
      final rsiVal = _fromY(pos.dy);

      if (_firstPointIndex == null) {
        // 첫 번째 점
        setState(() {
          _firstPointIndex = idx;
          _firstPointRsiValue = rsiVal;
        });
      } else {
        // 두 번째 점 → 선 생성
        setState(() {
          _lines.add(RsiDrawingLine(
            id: _uuid.v4(),
            startY: _firstPointRsiValue!,
            startIndex: _firstPointIndex!,
            endY: rsiVal,
            endIndex: idx,
          ));
          _firstPointIndex = null;
          _firstPointRsiValue = null;
          _isDrawing = false;
        });
      }
      return;
    }

    // 비 그리기 모드: 선택/해제
    final hitId = _hitTestLine(pos);
    setState(() {
      _selectedLineId = hitId;
    });
  }

  void _handleDragStart(DragStartDetails details) {
    if (_isDrawing) return;
    if (_selectedLineId == null) return;

    final line = _lines.firstWhere(
      (l) => l.id == _selectedLineId,
      orElse: () => _lines.first,
    );
    if (line.id != _selectedLineId) return;
    if (line.isLocked) return;

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

    final line = _lines.firstWhere(
      (l) => l.id == _draggingLineId,
      orElse: () => _lines.first,
    );
    if (line.id != _draggingLineId) return;

    final pos = details.localPosition;
    final idx = _fromX(pos.dx);
    final rsiVal = _fromY(pos.dy);

    setState(() {
      if (_draggingAnchor == 'start') {
        line.startIndex = idx;
        line.startY = rsiVal;
      } else {
        line.endIndex = idx;
        line.endY = rsiVal;
      }
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    setState(() {
      _draggingLineId = null;
      _draggingAnchor = null;
    });
  }

  // ─── 삭제 ───

  void _deleteSelected() {
    if (_selectedLineId == null) return;
    setState(() {
      _lines.removeWhere((l) => l.id == _selectedLineId);
      _selectedLineId = null;
    });
  }

  // ─── 설정 바텀시트 ───

  void _showSettings() {
    if (_selectedLineId == null) return;
    final line = _lines.firstWhere(
      (l) => l.id == _selectedLineId,
      orElse: () => _lines.first,
    );
    if (line.id != _selectedLineId) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _RsiLineSettingsSheet(
        line: line,
        onSave: (updated) {
          setState(() {
            final idx = _lines.indexWhere((l) => l.id == updated.id);
            if (idx >= 0) {
              _lines[idx] = RsiDrawingLine(
                id: updated.id,
                startY: _lines[idx].startY,
                startIndex: _lines[idx].startIndex,
                endY: _lines[idx].endY,
                endIndex: _lines[idx].endIndex,
                colorValue: updated.colorValue,
                strokeWidth: updated.strokeWidth,
                isLocked: updated.isLocked,
              );
            }
          });
        },
      ),
    );
  }

  // ─── 빌드 ───

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 768;
    final headerFontSize = isDesktop ? 13.0 : 11.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ─── RSI 헤더 + 연필 버튼 ───
        Padding(
          padding: EdgeInsets.only(top: isDesktop ? 6 : 4, bottom: 2),
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
              // 연필 토글 버튼
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isDrawing = !_isDrawing;
                    if (!_isDrawing) {
                      _firstPointIndex = null;
                      _firstPointRsiValue = null;
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
                    Icons.edit,
                    size: isDesktop ? 15 : 13,
                    color: _isDrawing
                        ? (widget.isDarkMode ? AppColors.darkAccent : AppColors.primary)
                        : widget.textColor.withAlpha(150),
                  ),
                ),
              ),
              const Spacer(),
              if (widget.rsiSignal != null)
                SizedBox(
                  width: 50,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: SignalBadge(signal: widget.rsiSignal!),
                  ),
                ),
            ],
          ),
        ),
        // ─── RSI 차트 + 드로잉 오버레이 ───
        SizedBox(
          height: widget.chartHeight,
          child: Stack(
            children: [
              // 기존 RSI 차트
              CustomPaint(
                size: Size(widget.chartWidth, widget.chartHeight),
                painter: RSIPainter(
                  rsiValues: widget.rsiValues,
                  isDarkMode: widget.isDarkMode,
                  textColor: widget.textColor,
                ),
              ),
              // 드로잉 선 오버레이
              CustomPaint(
                size: Size(widget.chartWidth, widget.chartHeight),
                painter: _RsiLinePainter(
                  lines: _lines,
                  selectedLineId: _selectedLineId,
                  firstPointOffset: _firstPointIndex != null
                      ? Offset(_toX(_firstPointIndex!), _toY(_firstPointRsiValue!))
                      : null,
                  chartWidth: widget.chartWidth,
                  chartHeight: widget.chartHeight,
                  displayDataLength: widget.displayDataLength,
                  isDarkMode: widget.isDarkMode,
                ),
              ),
              // 수직 십자선
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
              // 제스처 레이어
              GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTapUp: _handleTap,
                onPanStart: !_isDrawing ? _handleDragStart : null,
                onPanUpdate: !_isDrawing ? _handleDragUpdate : null,
                onPanEnd: !_isDrawing ? _handleDragEnd : null,
              ),
              // 선택된 선의 삭제/설정 버튼
              if (_selectedLineId != null)
                _buildSelectionButtons(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSelectionButtons() {
    final line = _lines.firstWhere(
      (l) => l.id == _selectedLineId,
      orElse: () => _lines.first,
    );
    if (line.id != _selectedLineId) return const SizedBox.shrink();

    // 선 중간 좌표
    final midX = (_toX(line.startIndex) + _toX(line.endIndex)) / 2;
    final midY = (_toY(line.startY) + _toY(line.endY)) / 2;

    // 버튼을 선 위에 배치 (약간 위로)
    final btnTop = (midY - 28).clamp(0.0, widget.chartHeight - 24);
    final btnLeft = (midX - 28).clamp(0.0, widget.chartWidth - 56);

    return Positioned(
      left: btnLeft,
      top: btnTop,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 삭제 버튼
          _ActionButton(
            icon: Icons.delete_outline,
            color: AppColors.red500,
            bgColor: widget.isDarkMode
                ? AppColors.darkCardBackground
                : AppColors.surface,
            onTap: _deleteSelected,
          ),
          const SizedBox(width: 4),
          // 설정 버튼
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

// ─────────────────────────────────────────────────────────────
// 미니 액션 버튼
// ─────────────────────────────────────────────────────────────

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

// ─────────────────────────────────────────────────────────────
// RSI 드로잉 선 Painter
// ─────────────────────────────────────────────────────────────

class _RsiLinePainter extends CustomPainter {
  final List<RsiDrawingLine> lines;
  final String? selectedLineId;
  final Offset? firstPointOffset; // 첫 번째 점 미리보기
  final double chartWidth;
  final double chartHeight;
  final int displayDataLength;
  final bool isDarkMode;

  _RsiLinePainter({
    required this.lines,
    this.selectedLineId,
    this.firstPointOffset,
    required this.chartWidth,
    required this.chartHeight,
    required this.displayDataLength,
    required this.isDarkMode,
  });

  static const double _leftPadding = 10.0;
  static const double _rightPadding = 50.0;
  static const double _topPadding = 4.0;
  static const double _bottomPadding = 4.0;

  double get _areaWidth => chartWidth - _leftPadding - _rightPadding;
  double get _candleWidth => displayDataLength > 0 ? _areaWidth / displayDataLength : 1.0;
  double get _drawableH => chartHeight - _topPadding - _bottomPadding;

  double _toX(int idx) => _leftPadding + idx * _candleWidth + _candleWidth / 2;
  double _toY(double rsi) => _topPadding + (1 - rsi / 100) * _drawableH;

  @override
  void paint(Canvas canvas, Size size) {
    // 선 그리기
    for (final line in lines) {
      final isSelected = line.id == selectedLineId;
      final color = Color(line.colorValue);

      final startOff = Offset(_toX(line.startIndex), _toY(line.startY));
      final endOff = Offset(_toX(line.endIndex), _toY(line.endY));

      // 선분
      final paint = Paint()
        ..color = color
        ..strokeWidth = line.strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(startOff, endOff, paint);

      // 앵커 포인트
      final anchorRadius = isSelected ? 5.0 : 3.5;
      final anchorPaint = Paint()..color = color..style = PaintingStyle.fill;
      canvas.drawCircle(startOff, anchorRadius, anchorPaint);
      canvas.drawCircle(endOff, anchorRadius, anchorPaint);

      // 선택 시 앵커 테두리
      if (isSelected) {
        final borderPaint = Paint()
          ..color = isDarkMode ? Colors.white.withAlpha(180) : Colors.black.withAlpha(120)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;
        canvas.drawCircle(startOff, anchorRadius + 1.5, borderPaint);
        canvas.drawCircle(endOff, anchorRadius + 1.5, borderPaint);
      }
    }

    // 첫 번째 점 미리보기
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
    }
  }

  @override
  bool shouldRepaint(covariant _RsiLinePainter oldDelegate) => true;
}

// ─────────────────────────────────────────────────────────────
// RSI 선 설정 바텀시트
// ─────────────────────────────────────────────────────────────

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
          // 드래그 핸들
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

          // 색상 선택
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

          // 굵기 선택
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

          // 잠금 토글
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
