import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/krw_formatter.dart';
import '../../../../data/models/cycle.dart';

/// 초기 매수 가이드 카드 (대기중 — 포지션 없을 때)
///
/// 전략별 초기 진입금 추천 + 현재가 기준 주수 계산
class CycleInitialBuyGuide extends StatelessWidget {
  final Cycle cycle;
  final double currentPrice;
  final double liveExchangeRate;

  const CycleInitialBuyGuide({
    super.key,
    required this.cycle,
    required this.currentPrice,
    required this.liveExchangeRate,
  });

  @override
  Widget build(BuildContext context) {
    final isAlpha = cycle.strategyType == StrategyType.alphaCycleV3;
    final buyAmountKrw = isAlpha
        ? cycle.initialEntryAmount
        : cycle.unitAmount;
    final label = isAlpha ? '초기 진입금' : '1회차 매수금';
    final ratio = isAlpha
        ? '시드의 ${(cycle.initialEntryRatio * 100).toStringAsFixed(0)}%'
        : '${cycle.totalRounds}회 분할';

    // 주수 계산
    final priceKrw = currentPrice * liveExchangeRate;
    final shares = priceKrw > 0 ? (buyAmountKrw / priceKrw).floor() : 0;
    final actualAmount = shares * priceKrw;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.secondary, AppColors.secondaryDark],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.secondary.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb_outline, size: 16, color: Colors.white70),
              const SizedBox(width: 6),
              Text(
                '$label 추천',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white70,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  ratio,
                  style: const TextStyle(fontSize: 11, color: Colors.white60),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            formatKrwWithComma(buyAmountKrw.round().toDouble()),
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          if (currentPrice > 0 && shares > 0)
            Text(
              '\$${currentPrice.toStringAsFixed(2)} × $shares주 = ${formatKrwWithComma(actualAmount.round().toDouble())}원',
              style: const TextStyle(fontSize: 12, color: Colors.white60),
            )
          else
            const Text(
              '현재가 로딩 후 주수가 표시됩니다',
              style: TextStyle(fontSize: 12, color: Colors.white54),
            ),
        ],
      ),
    );
  }
}
