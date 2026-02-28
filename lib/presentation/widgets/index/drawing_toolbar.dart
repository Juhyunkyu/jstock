import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// 드로잉 모드
enum DrawingMode {
  none,
  horizontalLine,
  trendLine,
  fibonacci,
  supportResistanceZone,
  measure,
}

/// 드로잉 도구 팔레트 + FAB 버튼
///
/// - 기본: ✏️ 버튼 → 탭하면 팔레트 팝업
/// - 드로잉 모드: ✕ 버튼 (취소)
class DrawingToolbar extends StatefulWidget {
  final DrawingMode drawingMode;
  final ValueChanged<DrawingMode> onModeChanged;
  final VoidCallback onCancel;

  const DrawingToolbar({
    super.key,
    required this.drawingMode,
    required this.onModeChanged,
    required this.onCancel,
  });

  @override
  State<DrawingToolbar> createState() => _DrawingToolbarState();
}

class _DrawingToolbarState extends State<DrawingToolbar> {
  bool _showPalette = false;

  @override
  void didUpdateWidget(DrawingToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.drawingMode != DrawingMode.none) {
      _showPalette = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // 팔레트 (버튼 위에 표시, 아이콘만)
        if (_showPalette) ...[
          _buildIconButton(
            icon: Icons.horizontal_rule,
            onTap: () {
              setState(() => _showPalette = false);
              widget.onModeChanged(DrawingMode.horizontalLine);
            },
          ),
          const SizedBox(height: 6),
          _buildIconButton(
            icon: Icons.trending_up,
            onTap: () {
              setState(() => _showPalette = false);
              widget.onModeChanged(DrawingMode.trendLine);
            },
          ),
          const SizedBox(height: 8),
        ],
        // 메인 버튼 (축소)
        _buildCircleButton(
          icon: widget.drawingMode != DrawingMode.none ? Icons.close : Icons.edit,
          color: widget.drawingMode != DrawingMode.none
              ? (context.isDarkMode ? AppColors.gray700 : AppColors.gray400)
              : context.appAccent,
          size: 30,
          iconSize: 15,
          onTap: _onFabTap,
        ),
      ],
    );
  }

  void _onFabTap() {
    if (widget.drawingMode != DrawingMode.none) {
      widget.onCancel();
      return;
    }
    setState(() => _showPalette = !_showPalette);
  }

  Widget _buildCircleButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    double size = 30,
    double iconSize = 15,
  }) {
    return Material(
      color: color,
      elevation: 2,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, size: iconSize, color: Colors.white),
        ),
      ),
    );
  }

  /// 팔레트 아이콘 버튼 (텍스트 없이 아이콘만)
  Widget _buildIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: context.appCardBackground,
      elevation: 2,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 30,
          height: 30,
          child: Icon(icon, size: 16, color: context.appTextPrimary),
        ),
      ),
    );
  }
}
