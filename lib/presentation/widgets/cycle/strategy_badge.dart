import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/cycle.dart';
import '../../providers/settings_providers.dart';

/// 전략 유형을 표시하는 소형 배지 위젯
///
/// Smart Cycle → 딥블루/인디고 배지 + 쉴드 아이콘
/// Steady Cycle → 에메랄드/그린 배지 + ∞ 아이콘
///
/// settingsProvider에서 사용자 지정 차트 색상을 읽어 앱 전체에 통일된 색상 적용
class StrategyBadge extends ConsumerWidget {
  final StrategyType strategyType;
  final SteadyVersion? steadyVersion;
  final int? ladderMode;

  const StrategyBadge({
    super.key,
    required this.strategyType,
    this.steadyVersion,
    this.ladderMode,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = _getConfig(context, ref);

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

  _StrategyConfig _getConfig(BuildContext context, WidgetRef ref) {
    final isDark = context.isDarkMode;
    final settings = ref.watch(settingsProvider);

    switch (strategyType) {
      case StrategyType.alphaCycleV3:
        return _StrategyConfig(
          label: 'Smart',
          icon: Icons.shield_outlined,
          color: settings.alphaCycleChartColor != 0
              ? Color(settings.alphaCycleChartColor)
              : (isDark ? AppColors.blue400 : AppColors.blue600),
        );
      case StrategyType.infiniteBuy:
        final versionLabel = switch (steadyVersion) {
          SteadyVersion.v2_2 => 'Steady V2.2',
          SteadyVersion.v3_0 => 'Steady V3.0',
          _ => 'Steady',
        };
        return _StrategyConfig(
          label: versionLabel,
          icon: Icons.all_inclusive,
          color: settings.steadyCycleChartColor != 0
              ? Color(settings.steadyCycleChartColor)
              : (isDark ? AppColors.green400 : AppColors.green600),
        );
      case StrategyType.ladderCycle:
        final modeLabel = switch (ladderMode) {
          0 => 'Ladder 안정형',
          1 => 'Ladder 공격형',
          2 => 'Ladder 초공격형',
          _ => 'Ladder',
        };
        return _StrategyConfig(
          label: modeLabel,
          icon: Icons.stacked_bar_chart,
          color: settings.ladderCycleChartColor != 0
              ? Color(settings.ladderCycleChartColor)
              : (isDark ? AppColors.amber400 : AppColors.amber500),
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
