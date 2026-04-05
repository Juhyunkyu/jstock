import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/korean_number_formatter.dart';
import '../../../../core/utils/krw_formatter.dart';
import '../../../../data/models/cycle.dart';
import '../../../../domain/trading/ladder_cycle_service.dart';
import '../../../providers/providers.dart';
import 'cycle_setup_helpers.dart';

/// 시드 금액 입력 필드
class CycleSeedInput extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final double seedAmount;
  final VoidCallback onChanged;

  const CycleSeedInput({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.seedAmount,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: context.appSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.appBorder),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: context.appTextPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: '10,000,000',
                    hintStyle: TextStyle(
                      color: context.appTextHint,
                      fontWeight: FontWeight.w400,
                    ),
                    border: InputBorder.none,
                  ),
                  onChanged: (_) => onChanged(),
                ),
              ),
              Text(
                '원',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: context.appTextSecondary,
                ),
              ),
            ],
          ),
        ),
        // 한글 금액 표시
        if (seedAmount > 0)
          Padding(
            padding: const EdgeInsets.only(left: 14, top: 4),
            child: Text(
              formatKoreanAmountFull(seedAmount),
              style: TextStyle(
                fontSize: 13,
                color: context.appTextSecondary,
              ),
            ),
          ),
      ],
    );
  }
}

/// 별명 입력 필드
class CycleNicknameInput extends StatelessWidget {
  final TextEditingController controller;

  const CycleNicknameInput({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLength: 20,
      style: TextStyle(
        fontSize: 15,
        color: context.appTextPrimary,
      ),
      decoration: InputDecoration(
        hintText: '예: 공격형, 장기투자...',
        hintStyle: TextStyle(color: context.appTextHint),
        counterStyle: TextStyle(color: context.appTextHint),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: context.appBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: context.appAccent),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
      ),
    );
  }
}

/// 자동 계산 프리뷰 카드
class CycleCalculationPreview extends ConsumerWidget {
  final StrategyType selectedStrategy;
  final double seedAmount;
  final String? selectedTicker;

  // Alpha params
  final double initialEntryRatio;
  final double firstProfitTarget;

  // Infinite buy params
  final double takeProfitPercent;
  final int totalRounds;

  // Ladder params
  final int ladderSteps;
  final int ladderPreset;
  final String ladderWeights;
  final String ladderTriggers;
  final List<double> customWeightPercents;
  final double Function(double baseSeed) calculateActualSeed;

  const CycleCalculationPreview({
    super.key,
    required this.selectedStrategy,
    required this.seedAmount,
    required this.selectedTicker,
    required this.initialEntryRatio,
    required this.firstProfitTarget,
    required this.takeProfitPercent,
    required this.totalRounds,
    required this.ladderSteps,
    required this.ladderPreset,
    required this.ladderWeights,
    required this.ladderTriggers,
    required this.customWeightPercents,
    required this.calculateActualSeed,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (seedAmount <= 0) return const SizedBox.shrink();

    final isAlpha = selectedStrategy == StrategyType.alphaCycleV3;
    final isLadder = selectedStrategy == StrategyType.ladderCycle;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isLadder ? '자동 계산 — $ladderSteps단계 투입 계획' : '자동 계산',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: context.appTextSecondary,
            ),
          ),
          const SizedBox(height: 8),
          if (isAlpha) ...[
            CalcRow(
              label: '초기 진입금',
              value: '${formatKrwWithComma(seedAmount * initialEntryRatio)}\u2009원',
              subLabel: '(${(initialEntryRatio * 100).toStringAsFixed(0)}%)',
            ),
            const SizedBox(height: 6),
            CalcRow(
              label: '잔여 현금',
              value:
                  '${formatKrwWithComma(seedAmount * (1 - initialEntryRatio))}\u2009원',
              subLabel: '(${((1 - initialEntryRatio) * 100).toStringAsFixed(0)}%)',
            ),
            const SizedBox(height: 6),
            CalcRow(
              label: '익절 목표',
              value: '+${firstProfitTarget.toStringAsFixed(0)}%',
            ),
          ] else if (isLadder) ...[
            if (ladderPreset == 3) ...[
              Builder(builder: (_) {
                final actualSeed = calculateActualSeed(seedAmount);
                final customTotal = customWeightPercents
                    .take(ladderSteps)
                    .fold<double>(0, (s, v) => s + v);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CalcRow(
                      label: '시드 금액',
                      value: '${formatKrwWithComma(seedAmount)}\u2009원',
                    ),
                    if ((customTotal - 100.0).abs() > 0.5) ...[
                      const SizedBox(height: 6),
                      CalcRow(
                        label: '커스텀 합계',
                        value: '${customTotal.toStringAsFixed(0)}%',
                      ),
                      const SizedBox(height: 6),
                      CalcRow(
                        label: '실제 투입 예정',
                        value: '${formatKrwWithComma(actualSeed)}\u2009원',
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '⚠ 시드가 자동으로 조정됩니다',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.amber500,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    _LadderCalcRows(
                      seed: actualSeed,
                      ladderSteps: ladderSteps,
                      ladderWeights: ladderWeights,
                      ladderTriggers: ladderTriggers,
                    ),
                  ],
                );
              }),
            ] else ...[
              _LadderCalcRows(
                seed: seedAmount,
                ladderSteps: ladderSteps,
                ladderWeights: ladderWeights,
                ladderTriggers: ladderTriggers,
              ),
            ],
          ] else ...[
            _InfiniteBuyCalcRows(
              seed: seedAmount,
              totalRounds: totalRounds,
              takeProfitPercent: takeProfitPercent,
              selectedTicker: selectedTicker,
            ),
          ],
        ],
      ),
    );
  }
}

class _InfiniteBuyCalcRows extends ConsumerWidget {
  final double seed;
  final int totalRounds;
  final double takeProfitPercent;
  final String? selectedTicker;

  const _InfiniteBuyCalcRows({
    required this.seed,
    required this.totalRounds,
    required this.takeProfitPercent,
    required this.selectedTicker,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perRound = seed / totalRounds;
    final exchangeRate = ref.watch(currentExchangeRateProvider);
    final quote = ref.watch(
      stockQuoteProvider.select((s) => selectedTicker != null
          ? s.quotes[selectedTicker!]
          : null),
    );
    final currentPrice = quote?.currentPrice ?? 0.0;

    final perRoundUsd =
        exchangeRate > 0 ? perRound / exchangeRate : 0.0;

    final shares =
        currentPrice > 0 ? (perRoundUsd / currentPrice).floor() : 0;

    return Column(
      children: [
        CalcRow(
          label: '1회 매수금액',
          value: '${formatKrwWithComma(perRound)}\u2009원',
          subLabel: perRoundUsd > 0
              ? '(약 \$${perRoundUsd.toStringAsFixed(1)})'
              : null,
        ),
        if (currentPrice > 0 && shares > 0) ...[
          const SizedBox(height: 6),
          CalcRow(
            label: '매수 주수 (현재가 기준)',
            value: '약 $shares주',
            subLabel: '(\$${currentPrice.toStringAsFixed(2)})',
          ),
        ],
        const SizedBox(height: 6),
        CalcRow(
          label: '총 회차',
          value: '$totalRounds회',
        ),
        const SizedBox(height: 6),
        CalcRow(
          label: '익절 목표',
          value: '+${takeProfitPercent.toStringAsFixed(0)}%',
        ),
      ],
    );
  }
}

class _LadderCalcRows extends StatelessWidget {
  final double seed;
  final int ladderSteps;
  final String ladderWeights;
  final String ladderTriggers;

  const _LadderCalcRows({
    required this.seed,
    required this.ladderSteps,
    required this.ladderWeights,
    required this.ladderTriggers,
  });

  @override
  Widget build(BuildContext context) {
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
}
