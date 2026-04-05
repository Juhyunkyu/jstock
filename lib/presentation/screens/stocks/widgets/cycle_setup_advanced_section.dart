import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/cycle.dart';
import '../../../../domain/trading/ladder_cycle_service.dart';
import '../../../../core/utils/krw_formatter.dart';
import 'cycle_setup_helpers.dart';

/// 고급 설정 ExpansionTile 래퍼
class CycleAdvancedSettings extends StatelessWidget {
  final StrategyType selectedStrategy;
  final bool showAdvanced;
  final ValueChanged<bool> onExpansionChanged;
  final Widget child;

  const CycleAdvancedSettings({
    super.key,
    required this.selectedStrategy,
    required this.showAdvanced,
    required this.onExpansionChanged,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: showAdvanced,
          onExpansionChanged: onExpansionChanged,
          tilePadding: const EdgeInsets.symmetric(horizontal: 14),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          leading: Icon(
            Icons.tune,
            size: 20,
            color: context.appTextSecondary,
          ),
          title: Text(
            '고급 설정',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: context.appTextPrimary,
            ),
          ),
          children: [child],
        ),
      ),
    );
  }
}

/// Alpha Cycle V3 고급 설정 슬라이더 모음
class AlphaAdvancedSettings extends StatelessWidget {
  final double initialEntryRatio;
  final double weightedBuyThreshold;
  final double effectivePerPercent;
  final double seedAmount;
  final double panicBuyThreshold;
  final double panicBuyMultiplier;
  final double firstProfitTarget;
  final double profitTargetStep;
  final double minProfitTarget;
  final double cashSecureRatio;
  final ValueChanged<double> onInitialEntryRatioChanged;
  final ValueChanged<double> onWeightedBuyThresholdChanged;
  final ValueChanged<double> onWeightedBuyPerPercentChanged;
  final ValueChanged<double> onPanicBuyThresholdChanged;
  final ValueChanged<double> onPanicBuyMultiplierChanged;
  final ValueChanged<double> onFirstProfitTargetChanged;
  final ValueChanged<double> onProfitTargetStepChanged;
  final ValueChanged<double> onMinProfitTargetChanged;
  final ValueChanged<double> onCashSecureRatioChanged;

  const AlphaAdvancedSettings({
    super.key,
    required this.initialEntryRatio,
    required this.weightedBuyThreshold,
    required this.effectivePerPercent,
    required this.seedAmount,
    required this.panicBuyThreshold,
    required this.panicBuyMultiplier,
    required this.firstProfitTarget,
    required this.profitTargetStep,
    required this.minProfitTarget,
    required this.cashSecureRatio,
    required this.onInitialEntryRatioChanged,
    required this.onWeightedBuyThresholdChanged,
    required this.onWeightedBuyPerPercentChanged,
    required this.onPanicBuyThresholdChanged,
    required this.onPanicBuyMultiplierChanged,
    required this.onFirstProfitTargetChanged,
    required this.onProfitTargetStepChanged,
    required this.onMinProfitTargetChanged,
    required this.onCashSecureRatioChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ParamSlider(
          label: '초기 진입 비율 (시드의)',
          value: initialEntryRatio,
          min: 0.05,
          max: 0.50,
          divisions: 9,
          format: (v) => '${(v * 100).toStringAsFixed(0)}%',
          onChanged: onInitialEntryRatioChanged,
        ),
        ParamSlider(
          label: '가중매수 발동 기준 (손실률)',
          value: weightedBuyThreshold,
          min: -50.0,
          max: -5.0,
          divisions: 9,
          format: (v) => '${v.toStringAsFixed(0)}%',
          onChanged: onWeightedBuyThresholdChanged,
        ),
        ParamSlider(
          label: '가중매수 1%당 금액',
          value: effectivePerPercent,
          min: seedAmount * 0.00003,
          max: seedAmount * 0.00015,
          divisions: 12,
          format: (v) => '${(v / 10000).toStringAsFixed(1)}만원',
          onChanged: onWeightedBuyPerPercentChanged,
        ),
        ParamSlider(
          label: '승부수 발동 기준 (손실률)',
          value: panicBuyThreshold,
          min: -80.0,
          max: -30.0,
          divisions: 10,
          format: (v) => '${v.toStringAsFixed(0)}%',
          onChanged: onPanicBuyThresholdChanged,
        ),
        ParamSlider(
          label: '승부수 투입 배율 (평가금의)',
          value: panicBuyMultiplier,
          min: 0.20,
          max: 1.00,
          divisions: 8,
          format: (v) => '${(v * 100).toStringAsFixed(0)}%',
          onChanged: onPanicBuyMultiplierChanged,
        ),
        ParamSlider(
          label: '첫 익절 목표 (수익률)',
          value: firstProfitTarget,
          min: 10.0,
          max: 50.0,
          divisions: 8,
          format: (v) => '+${v.toStringAsFixed(0)}%',
          onChanged: onFirstProfitTargetChanged,
        ),
        ParamSlider(
          label: '연속 익절 감소폭',
          value: profitTargetStep,
          min: 1.0,
          max: 10.0,
          divisions: 9,
          format: (v) => '${v.toStringAsFixed(0)}%p',
          onChanged: onProfitTargetStepChanged,
        ),
        ParamSlider(
          label: '최소 익절 목표 (수익률)',
          value: minProfitTarget,
          min: 5.0,
          max: 20.0,
          divisions: 3,
          format: (v) => '+${v.toStringAsFixed(0)}%',
          onChanged: onMinProfitTargetChanged,
        ),
        ParamSlider(
          label: '현금 확보 비율 (총자산의)',
          value: cashSecureRatio,
          min: 0.10,
          max: 0.50,
          divisions: 8,
          format: (v) => '${(v * 100).toStringAsFixed(1)}%',
          onChanged: onCashSecureRatioChanged,
        ),
      ],
    );
  }
}

/// Steady (무한매수법) 고급 설정
class SteadyAdvancedSettings extends StatelessWidget {
  final SteadyVersion steadyVersion;
  final double takeProfitPercent;
  final int totalRounds;
  final double sellQuarterPercent;
  final bool compoundEnabled;
  final ValueChanged<double> onTakeProfitPercentChanged;
  final ValueChanged<int> onTotalRoundsChanged;
  final ValueChanged<double> onSellQuarterPercentChanged;
  final ValueChanged<bool> onCompoundEnabledChanged;

  const SteadyAdvancedSettings({
    super.key,
    required this.steadyVersion,
    required this.takeProfitPercent,
    required this.totalRounds,
    required this.sellQuarterPercent,
    required this.compoundEnabled,
    required this.onTakeProfitPercentChanged,
    required this.onTotalRoundsChanged,
    required this.onSellQuarterPercentChanged,
    required this.onCompoundEnabledChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ParamSlider(
          label: '익절 목표',
          value: takeProfitPercent,
          min: 5.0,
          max: 30.0,
          divisions: 5,
          format: (v) => '+${v.toStringAsFixed(0)}%',
          onChanged: onTakeProfitPercentChanged,
        ),
        ParamSlider(
          label: '총 분할 회차',
          value: totalRounds.toDouble(),
          min: 20.0,
          max: 80.0,
          divisions: 12,
          format: (v) => '${v.toInt()}회',
          onChanged: (v) => onTotalRoundsChanged(v.toInt()),
        ),
        if (steadyVersion != SteadyVersion.v1)
          ParamSlider(
            label: '매도 LOC 비율 (보유량의)',
            value: sellQuarterPercent,
            min: 0.10,
            max: 0.50,
            divisions: 8,
            format: (v) => '${(v * 100).toStringAsFixed(0)}%',
            onChanged: onSellQuarterPercentChanged,
          ),
        if (steadyVersion == SteadyVersion.v3_0)
          _CompoundToggle(
            compoundEnabled: compoundEnabled,
            onChanged: onCompoundEnabledChanged,
          ),
      ],
    );
  }
}

class _CompoundToggle extends StatelessWidget {
  final bool compoundEnabled;
  final ValueChanged<bool> onChanged;

  const _CompoundToggle({
    required this.compoundEnabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '반복리 활성화',
            style: TextStyle(
              fontSize: 12,
              color: context.appTextSecondary,
            ),
          ),
          Switch(
            value: compoundEnabled,
            onChanged: onChanged,
            activeColor: context.appAccent,
          ),
        ],
      ),
    );
  }
}

/// Ladder Cycle 고급 설정 (분할 단계 + 비율 프리셋 + 커스텀 슬라이더)
class LadderAdvancedSettings extends StatelessWidget {
  final int ladderSteps;
  final int ladderPreset;
  final double seedAmount;
  final String ladderWeights;
  final String ladderTriggers;
  final List<double> customWeightPercents;
  final double Function(double baseSeed) calculateActualSeed;
  final ValueChanged<int> onStepsChanged;
  final ValueChanged<int> onPresetChanged;
  final void Function(int index, double value) onCustomWeightChanged;

  const LadderAdvancedSettings({
    super.key,
    required this.ladderSteps,
    required this.ladderPreset,
    required this.seedAmount,
    required this.ladderWeights,
    required this.ladderTriggers,
    required this.customWeightPercents,
    required this.calculateActualSeed,
    required this.onStepsChanged,
    required this.onPresetChanged,
    required this.onCustomWeightChanged,
  });

  static const _presetNames = ['가속', '피보', '마틴', '커스텀'];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 분할 단계
        Text(
          '분할 단계',
          style: TextStyle(fontSize: 12, color: context.appTextSecondary),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<int>(
            segments: [3, 4, 5, 6].map((n) => ButtonSegment<int>(
              value: n,
              label: Text(
                '$n',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: ladderSteps == n
                      ? Colors.white
                      : context.appTextSecondary,
                ),
              ),
            )).toList(),
            selected: {ladderSteps},
            onSelectionChanged: (selected) => onStepsChanged(selected.first),
            style: _amberSegmentedStyle(context),
          ),
        ),
        const SizedBox(height: 16),

        // 비율 프리셋
        Text(
          '비율 프리셋',
          style: TextStyle(fontSize: 12, color: context.appTextSecondary),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<int>(
            segments: List.generate(4, (i) => ButtonSegment<int>(
              value: i,
              label: Text(
                _presetNames[i],
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: ladderPreset == i
                      ? Colors.white
                      : context.appTextSecondary,
                ),
              ),
            )),
            selected: {ladderPreset},
            showSelectedIcon: false,
            onSelectionChanged: (selected) => onPresetChanged(selected.first),
            style: _amberSegmentedStyle(context),
          ),
        ),
        const SizedBox(height: 16),

        // 투입 계획 미리보기
        if (seedAmount > 0) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.appBackground,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '투입 계획 미리보기',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: context.appTextHint,
                  ),
                ),
                const SizedBox(height: 8),
                _buildLadderCalcRows(calculateActualSeed(seedAmount)),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // 커스텀 슬라이더
        if (ladderPreset == 3)
          _CustomWeightSliders(
            ladderSteps: ladderSteps,
            customWeightPercents: customWeightPercents,
            onChanged: onCustomWeightChanged,
          ),
      ],
    );
  }

  Widget _buildLadderCalcRows(double seed) {
    final weights = parseLadderWeights(ladderWeights, steps: ladderSteps);
    final triggers = parseLadderTriggers(ladderTriggers, steps: ladderSteps);
    final totalWeight = weights.fold<int>(0, (s, w) => s + w);

    if (totalWeight == 0) return const SizedBox.shrink();

    return Column(
      children: List.generate(weights.length.clamp(0, ladderSteps), (i) {
        final amount = seed * weights[i] / totalWeight;
        final pct = weights[i] / totalWeight * 100;
        final triggerStr = i < triggers.length
            ? triggers[i].toStringAsFixed(0)
            : '?';
        return Padding(
          padding: EdgeInsets.only(bottom: i < ladderSteps - 1 ? 6 : 0),
          child: CalcRow(
            label: '${i + 1}단계 ($triggerStr%)',
            value: '${formatKrwWithComma(amount)}\u2009원',
            subLabel: '(${pct.toStringAsFixed(2)}%)',
          ),
        );
      }),
    );
  }

  static ButtonStyle _amberSegmentedStyle(BuildContext context) {
    return ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.amber600;
        }
        return context.appSurface;
      }),
      side: WidgetStateProperty.all(
        BorderSide(color: context.appBorder, width: 0.5),
      ),
      shape: WidgetStateProperty.all(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}

class _CustomWeightSliders extends StatelessWidget {
  final int ladderSteps;
  final List<double> customWeightPercents;
  final void Function(int index, double value) onChanged;

  const _CustomWeightSliders({
    required this.ladderSteps,
    required this.customWeightPercents,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final sum = customWeightPercents
        .take(ladderSteps)
        .fold<double>(0, (s, v) => s + v);
    final isValid = (sum - 100.0).abs() <= 0.5;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...List.generate(ladderSteps, (i) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 48,
                  child: Text(
                    '${i + 1}단계',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.appTextSecondary,
                    ),
                  ),
                ),
                Expanded(
                  child: SliderTheme(
                    data: SliderThemeData(
                      activeTrackColor: AppColors.amber500,
                      inactiveTrackColor: context.appDivider,
                      thumbColor: AppColors.amber500,
                      overlayColor: AppColors.amber500.withValues(alpha: 0.12),
                      trackHeight: 3,
                      thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 7),
                    ),
                    child: Slider(
                      value: i < customWeightPercents.length
                          ? customWeightPercents[i].clamp(0, 100)
                          : 0,
                      min: 0,
                      max: 100,
                      divisions: 100,
                      onChanged: (v) => onChanged(i, v),
                    ),
                  ),
                ),
                SizedBox(
                  width: 40,
                  child: Text(
                    '${i < customWeightPercents.length ? customWeightPercents[i].toStringAsFixed(0) : 0}%',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: context.appTextPrimary,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              '합계: ${sum.toStringAsFixed(0)}%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isValid ? context.appTextSecondary : AppColors.amber500,
              ),
            ),
          ],
        ),
        if (!isValid) ...[
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              sum < 100
                  ? 'ℹ 시드의 ${sum.toStringAsFixed(0)}%만 사용됩니다'
                  : '⚠ 시드 초과 (${sum.toStringAsFixed(0)}% 필요)',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.amber500,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// 공통 파라미터 슬라이더
class ParamSlider extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String Function(double) format;
  final ValueChanged<double> onChanged;

  const ParamSlider({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.format,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: context.appTextSecondary,
                ),
              ),
              Text(
                format(value),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: context.appAccent,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: context.appAccent,
              inactiveTrackColor: context.appDivider,
              thumbColor: context.appAccent,
              overlayColor: context.appAccent.withValues(alpha: 0.12),
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
