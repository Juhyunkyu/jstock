import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// 선택된 드로잉 선 좌측에 표시되는 인라인 버튼 (설정 + 삭제)
class DrawingSelectionButtons extends StatelessWidget {
  /// 선의 Y 픽셀 좌표
  final double lineY;

  /// 설정 버튼 콜백
  final VoidCallback onSettings;

  /// 삭제 버튼 콜백
  final VoidCallback onDelete;

  const DrawingSelectionButtons({
    super.key,
    required this.lineY,
    required this.onSettings,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 14,
      // 두 버튼 세로 배치 (32 + 4 + 32 = 68) → 중앙 정렬
      top: lineY - 34,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _CircleIconButton(
            icon: Icons.settings,
            color: context.appAccent,
            onTap: onSettings,
          ),
          const SizedBox(height: 4),
          _CircleIconButton(
            icon: Icons.delete_outline,
            color: AppColors.stockDown,
            onTap: onDelete,
          ),
        ],
      ),
    );
  }
}

/// Listener 기반 원형 버튼 (부모 GestureDetector 제스처 아레나 우회)
class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _CircleIconButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerUp: (_) => onTap(),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
          ],
        ),
        child: Icon(icon, size: 16, color: Colors.white),
      ),
    );
  }
}
