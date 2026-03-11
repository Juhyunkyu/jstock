import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// 공유 InfoRow — 보유 상세 / 사이클 상세 / 거래 상세 공통 사용
class InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final double fontSize;
  final bool flexible;

  const InfoRow({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.fontSize = 13,
    this.flexible = false,
  });

  @override
  Widget build(BuildContext context) {
    final valueWidget = Text(
      value,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
        color: valueColor ?? context.appTextPrimary,
      ),
      textAlign: flexible ? TextAlign.end : null,
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: fontSize,
            color: context.appTextSecondary,
          ),
        ),
        if (flexible) Flexible(child: valueWidget) else valueWidget,
      ],
    );
  }
}
