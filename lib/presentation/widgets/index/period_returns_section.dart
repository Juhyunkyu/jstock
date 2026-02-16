import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// 기간별 수익률 섹션 위젯
class PeriodReturnsSection extends StatelessWidget {
  final Map<String, double> periodReturns;

  const PeriodReturnsSection({
    super.key,
    required this.periodReturns,
  });

  @override
  Widget build(BuildContext context) {
    final periods = ['1D', '1W', '1M', '3M', 'YTD', '1Y'];
    final labels = ['1일', '1주', '1개월', '3개월', 'YTD', '1년'];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: context.appSurface,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: List.generate(periods.length, (i) {
          final value = periodReturns[periods[i]];
          final isPositive = (value ?? 0) >= 0;
          final color = value != null
              ? (isPositive ? AppColors.stockUp : AppColors.stockDown)
              : context.appTextHint;
          final bgColor = value != null
              ? (isPositive
                  ? (isDark ? const Color(0xFF2D1A1A) : const Color(0xFFFEF2F2))
                  : (isDark ? const Color(0xFF1A2D3D) : const Color(0xFFEFF6FF)))
              : context.appIconBg;

          return Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                children: [
                  Text(
                    value != null
                        ? '${isPositive ? '+' : ''}${value.toStringAsFixed(1)}%'
                        : '-',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    labels[i],
                    style: TextStyle(
                      fontSize: 10,
                      color: context.appTextHint,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
