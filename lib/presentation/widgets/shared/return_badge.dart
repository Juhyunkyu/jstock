import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// 색상 체계
enum ReturnBadgeColorScheme {
  /// 국제식: 수익=초록, 손실=빨강
  greenRed,

  /// 한국식: 상승=빨강, 하락=파랑
  redBlue,
}

/// 배지 크기
enum ReturnBadgeSize {
  /// 11px 텍스트, 아이콘 12, 패딩 h:6/v:3
  small,

  /// 13px 텍스트, 아이콘 16, 패딩 h:10/v:5
  medium,
}

/// 앱 전역 등락률 배지 위젯
///
/// 둥근 컨테이너에 반투명 배경 + trending 아이콘 + 볼드 퍼센트 텍스트.
/// 다크모드 자동 대응.
class ReturnBadge extends StatelessWidget {
  /// 등락률 값 (%). null이면 [nullLabel] 표시.
  final double? value;

  /// 배지 크기
  final ReturnBadgeSize size;

  /// 색상 체계
  final ReturnBadgeColorScheme colorScheme;

  /// 소수점 자릿수 (기본 1)
  final int decimals;

  /// trending 아이콘 표시 여부
  final bool showIcon;

  /// value가 null일 때 표시할 라벨 (기본: '완료')
  final String? nullLabel;

  const ReturnBadge({
    super.key,
    required this.value,
    this.size = ReturnBadgeSize.medium,
    this.colorScheme = ReturnBadgeColorScheme.greenRed,
    this.decimals = 1,
    this.showIcon = true,
    this.nullLabel,
  });

  @override
  Widget build(BuildContext context) {
    if (value == null) {
      return _buildNullBadge(context);
    }
    return _buildValueBadge(context, value!);
  }

  Widget _buildNullBadge(BuildContext context) {
    final label = nullLabel ?? '완료';
    final isSmall = size == ReturnBadgeSize.small;
    final hPad = isSmall ? 6.0 : 10.0;
    final vPad = isSmall ? 3.0 : 5.0;
    final fontSize = isSmall ? 11.0 : 13.0;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
      decoration: BoxDecoration(
        color: context.appTextHint.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: context.appTextHint,
        ),
      ),
    );
  }

  Widget _buildValueBadge(BuildContext context, double val) {
    final isPositive = val >= 0;
    final isSmall = size == ReturnBadgeSize.small;

    // 색상 결정
    final Color bgColor;
    final Color fgColor;

    switch (colorScheme) {
      case ReturnBadgeColorScheme.greenRed:
        bgColor = isPositive ? context.appReturnProfitBg : context.appReturnLossBg;
        fgColor = isPositive ? context.appReturnProfitFg : context.appReturnLossFg;
      case ReturnBadgeColorScheme.redBlue:
        bgColor = isPositive ? context.appStockChangePlusBg : context.appStockChangeMinusBg;
        fgColor = isPositive ? context.appStockChangePlusFg : context.appStockChangeMinusFg;
    }

    // 크기 결정
    final hPad = isSmall ? 6.0 : 10.0;
    final vPad = isSmall ? 3.0 : 5.0;
    final fontSize = isSmall ? 11.0 : 13.0;
    final iconSize = isSmall ? 12.0 : 16.0;

    final text = '${isPositive ? '+' : ''}${val.toStringAsFixed(decimals)}%';

    return Container(
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon) ...[
            Icon(
              isPositive
                  ? Icons.trending_up_rounded
                  : Icons.trending_down_rounded,
              size: iconSize,
              color: fgColor,
            ),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              color: fgColor,
            ),
          ),
        ],
      ),
    );
  }
}
