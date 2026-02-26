import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// 컴팩트 기간 선택기 (일/주/월)
class CompactPeriodSelector extends StatelessWidget {
  final String selectedPeriod;
  final ValueChanged<String> onPeriodChanged;

  const CompactPeriodSelector({
    super.key,
    required this.selectedPeriod,
    required this.onPeriodChanged,
  });

  static const periods = ['일', '주', '월'];

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 768;
    return Row(
      children: periods.map((period) {
        final isSelected = period == selectedPeriod;
        return Padding(
          padding: const EdgeInsets.only(right: 4),
          child: GestureDetector(
            onTap: () => onPeriodChanged(period),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: isDesktop ? 10 : 8, vertical: isDesktop ? 4 : 3),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.gray800 : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: isSelected ? null : Border.all(color: AppColors.gray300, width: 0.5),
              ),
              child: Text(
                period,
                style: TextStyle(
                  fontSize: isDesktop ? 12 : 10,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// 이동평균선 범례 (5/20/60/120)
class MALegend extends StatelessWidget {
  const MALegend({super.key});

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 768;
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        _legendItem('5', const Color(0xFFFF6B6B), isDesktop),
        _legendItem('20', const Color(0xFFFFD93D), isDesktop),
        _legendItem('60', const Color(0xFF6BCB77), isDesktop),
        _legendItem('120', const Color(0xFF4D96FF), isDesktop),
      ],
    );
  }

  Widget _legendItem(String label, Color color, bool isDesktop) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: isDesktop ? 12 : 10,
            height: 2,
            color: color,
          ),
          const SizedBox(width: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: isDesktop ? 10 : 8,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
