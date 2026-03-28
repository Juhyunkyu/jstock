import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// 상단 토스트 알림 (업계 표준: 토스증권, 로빈후드 스타일)
/// FAB이나 하단 네비를 가리지 않도록 앱바 아래에서 내려옴
void showTopToast(
  BuildContext context,
  String message, {
  Duration duration = const Duration(seconds: 2),
  Color? backgroundColor,
  IconData? icon,
}) {
  final overlay = Overlay.of(context);
  late OverlayEntry entry;

  entry = OverlayEntry(
    builder: (context) => _TopToastWidget(
      message: message,
      duration: duration,
      backgroundColor: backgroundColor,
      icon: icon,
      onDismiss: () => entry.remove(),
    ),
  );

  // 기존 토스트 제거 (중복 방지)
  overlay.insert(entry);
}

/// 성공 토스트 (초록)
void showSuccessToast(BuildContext context, String message) {
  showTopToast(context, message, icon: Icons.check_circle_outline, backgroundColor: AppColors.green600);
}

/// 에러 토스트 (빨강)
void showErrorToast(BuildContext context, String message) {
  showTopToast(context, message, icon: Icons.error_outline, backgroundColor: AppColors.red500, duration: const Duration(seconds: 4));
}

class _TopToastWidget extends StatefulWidget {
  final String message;
  final Duration duration;
  final Color? backgroundColor;
  final IconData? icon;
  final VoidCallback onDismiss;

  const _TopToastWidget({
    required this.message,
    required this.duration,
    this.backgroundColor,
    this.icon,
    required this.onDismiss,
  });

  @override
  State<_TopToastWidget> createState() => _TopToastWidgetState();
}

class _TopToastWidgetState extends State<_TopToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _fadeAnimation = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();

    // 자동 사라짐
    Future.delayed(widget.duration, () {
      if (mounted) {
        _controller.reverse().then((_) {
          if (mounted) widget.onDismiss();
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = widget.backgroundColor ??
        (isDark ? const Color(0xFF2D333B) : const Color(0xFF323232));
    final topPadding = MediaQuery.of(context).padding.top;
    final screenWidth = MediaQuery.sizeOf(context).width;
    // 반응형: 모바일 전체폭, 태블릿/데스크톱 최대 400px
    final maxWidth = screenWidth >= 768 ? 400.0 : screenWidth - 32;

    return Positioned(
      top: topPadding + 8,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: GestureDetector(
                onVerticalDragEnd: (_) {
                  _controller.reverse().then((_) {
                    if (mounted) widget.onDismiss();
                  });
                },
                child: Container(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(40),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.icon != null) ...[
                        Icon(widget.icon, size: 18, color: Colors.white),
                        const SizedBox(width: 8),
                      ],
                      Flexible(
                        child: Text(
                          widget.message,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
