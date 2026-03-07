import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/cycle.dart';

/// 전략 유형을 표시하는 소형 배지 위젯
///
/// Alpha Cycle V3 → 딥블루/인디고 배지 + 쉴드 아이콘
/// 순정 무한매수법 → 에메랄드/그린 배지 + 로켓 아이콘
class StrategyBadge extends StatelessWidget {
  final StrategyType strategyType;

  const StrategyBadge({
    super.key,
    required this.strategyType,
  });

  @override
  Widget build(BuildContext context) {
    final config = _getConfig(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: config.color.withValues(alpha: context.isDarkMode ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: config.color.withValues(alpha: context.isDarkMode ? 0.30 : 0.20),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            config.icon,
            size: 13,
            color: config.color,
          ),
          const SizedBox(width: 4),
          Text(
            config.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: config.color,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  _StrategyConfig _getConfig(BuildContext context) {
    final isDark = context.isDarkMode;
    switch (strategyType) {
      case StrategyType.alphaCycleV3:
        return _StrategyConfig(
          label: 'Alpha',
          icon: Icons.shield_outlined,
          color: isDark ? AppColors.blue400 : AppColors.blue600,
        );
      case StrategyType.infiniteBuy:
        return _StrategyConfig(
          label: '\uBB34\uD55C\uB9E4\uC218',
          icon: Icons.rocket_launch_outlined,
          color: isDark ? AppColors.green400 : AppColors.green600,
        );
    }
  }
}

class _StrategyConfig {
  final String label;
  final IconData icon;
  final Color color;

  const _StrategyConfig({
    required this.label,
    required this.icon,
    required this.color,
  });
}
