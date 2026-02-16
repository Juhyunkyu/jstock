import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// Alpha Cycle 앱 타이틀 로고 위젯
///
/// ∞ 아이콘 + "Alpha Cycle" 텍스트 (심플 스타일)
///
/// 사용처:
/// - 데스크톱 사이드바 (fontSize: 18)
/// - 홈 화면 앱바 (fontSize: 22)
/// - 스플래시 화면 (fontSize: 30)
/// - 설정 화면 푸터 (fontSize: 16)
class AppTitleLogo extends StatelessWidget {
  final double fontSize;
  final Color? iconColor;
  final Color? textColor;
  final FontWeight fontWeight;

  const AppTitleLogo({
    super.key,
    required this.fontSize,
    this.iconColor,
    this.textColor,
    this.fontWeight = FontWeight.w700,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveIconColor = iconColor ?? Theme.of(context).colorScheme.primary;
    final effectiveTextColor = textColor ?? context.appTextPrimary;
    final iconSize = fontSize * 1.2;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.all_inclusive,
          size: iconSize,
          color: effectiveIconColor,
        ),
        SizedBox(width: fontSize * 0.4),
        Text(
          'Alpha Cycle',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: fontWeight,
            color: effectiveTextColor,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }
}
