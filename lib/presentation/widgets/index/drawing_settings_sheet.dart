import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/chart_drawing.dart';

/// 드로잉 설정 BottomSheet
///
/// 색상 스와치(8개), 굵기 ChoiceChip(3단계), 잠금 스위치
/// 변경 즉시 onSave 콜백 호출 (별도 저장 버튼 없음)
class DrawingSettingsSheet extends StatefulWidget {
  final ChartDrawing drawing;
  final ValueChanged<ChartDrawing> onSave;

  const DrawingSettingsSheet({
    super.key,
    required this.drawing,
    required this.onSave,
  });

  @override
  State<DrawingSettingsSheet> createState() => _DrawingSettingsSheetState();
}

class _DrawingSettingsSheetState extends State<DrawingSettingsSheet> {
  late int _colorValue;
  late double _strokeWidth;
  late bool _isLocked;

  /// 프리셋 색상 8개
  static const List<int> _presetColors = [
    0xFFFF6B6B, // 빨강
    0xFF4ECDC4, // 청록
    0xFFFFD93D, // 노랑
    0xFF6BCB77, // 초록
    0xFF4D96FF, // 파랑
    0xFFFF8C42, // 주황
    0xFFE879F9, // 보라
    0xFF94A3B8, // 회색
  ];

  /// 굵기 옵션
  static const List<_StrokeOption> _strokeOptions = [
    _StrokeOption(label: '얇게', value: 1.0),
    _StrokeOption(label: '보통', value: 2.0),
    _StrokeOption(label: '굵게', value: 3.0),
  ];

  @override
  void initState() {
    super.initState();
    _colorValue = widget.drawing.colorValue;
    _strokeWidth = widget.drawing.strokeWidth;
    _isLocked = widget.drawing.isLocked;
  }

  void _emitChange() {
    widget.onSave(widget.drawing.copyWith(
      colorValue: _colorValue,
      strokeWidth: _strokeWidth,
      isLocked: _isLocked,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: BoxDecoration(
        color: context.appCardBackground,
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
                color: context.appDivider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // 제목
          Text(
            '선 설정',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: context.appTextPrimary,
            ),
          ),
          const SizedBox(height: 16),

          // 색상 섹션
          Text(
            '색상',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: context.appTextSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _presetColors.map((c) => _buildColorSwatch(c)).toList(),
          ),
          const SizedBox(height: 20),

          // 굵기 섹션
          Text(
            '굵기',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: context.appTextSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _strokeOptions.map((opt) {
              final isActive = _strokeWidth == opt.value;
              return ChoiceChip(
                label: Text(opt.label),
                selected: isActive,
                onSelected: (_) {
                  setState(() => _strokeWidth = opt.value);
                  _emitChange();
                },
                selectedColor: context.appAccent,
                labelStyle: TextStyle(
                  color: isActive ? Colors.white : context.appTextPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                backgroundColor: context.appSurface,
                side: BorderSide(
                  color: isActive ? context.appAccent : context.appBorder,
                ),
                showCheckmark: false,
              );
            }).toList(),
          ),
          const SizedBox(height: 12),

          // 잠금 스위치
          SwitchListTile(
            title: Text(
              '위치 잠금',
              style: TextStyle(
                fontSize: 14,
                color: context.appTextPrimary,
              ),
            ),
            subtitle: Text(
              '활성화하면 드래그로 이동할 수 없습니다',
              style: TextStyle(
                fontSize: 12,
                color: context.appTextHint,
              ),
            ),
            value: _isLocked,
            onChanged: (val) {
              setState(() => _isLocked = val);
              _emitChange();
            },
            activeColor: context.appAccent,
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  Widget _buildColorSwatch(int colorVal) {
    final isActive = _colorValue == colorVal;
    return GestureDetector(
      onTap: () {
        setState(() => _colorValue = colorVal);
        _emitChange();
      },
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Color(colorVal),
          shape: BoxShape.circle,
          border: isActive
              ? Border.all(color: context.appTextPrimary, width: 2.5)
              : Border.all(color: context.appBorder, width: 1),
        ),
        child: isActive
            ? const Icon(Icons.check, size: 18, color: Colors.white)
            : null,
      ),
    );
  }
}

class _StrokeOption {
  final String label;
  final double value;
  const _StrokeOption({required this.label, required this.value});
}
