import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/krw_formatter.dart';
import '../../../data/models/cycle.dart';
import '../../../domain/trading/trading_math.dart';
import '../../../presentation/providers/cycle_providers.dart';
import '../../../presentation/providers/stock_providers.dart';
import '../../../presentation/providers/api_providers.dart';
import '../shared/ticker_logo.dart';
import '../shared/return_badge.dart';
import 'strategy_badge.dart';
import 'signal_display.dart';

/// 활성 사이클 카드 위젯 (My 탭 리스트용)
///
/// 실시간 가격/환율을 ref.watch로 구독하여 평가금액, 수익률, 신호를 자동 갱신합니다.
class ActiveCycleCard extends ConsumerWidget {
  final Cycle cycle;
  final VoidCallback? onTap;

  const ActiveCycleCard({
    super.key,
    required this.cycle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prices = ref.watch(currentPricesProvider);
    final currentPrice = prices[cycle.ticker] ?? 0.0;
    final liveExchangeRate = ref.watch(currentExchangeRateProvider);
    final signal = ref.watch(cycleSignalProvider(cycle.id));

    final evaluatedAmount = TradingMath.evaluatedAmount(
      cycle.totalShares,
      currentPrice,
      liveExchangeRate,
    );
    final investedAmount = cycle.seedAmount - cycle.remainingCash;
    final profitLoss = evaluatedAmount - investedAmount;
    final isProfit = profitLoss >= 0;
    final profitColor = isProfit ? AppColors.red500 : AppColors.blue500;

    final returnRate = cycle.totalShares > 0 && cycle.averagePrice > 0
        ? TradingMath.returnRate(currentPrice, cycle.averagePrice)
        : 0.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.appSurface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: context.isDarkMode
                  ? Colors.white.withValues(alpha: 0.03)
                  : Colors.black.withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // === 상단: 종목 정보 + 수익률 배지 ===
            Row(
              children: [
                TickerLogo(
                  ticker: cycle.ticker,
                  size: 32,
                  borderRadius: 8,
                ),
                const SizedBox(width: 8),
                Text(
                  cycle.ticker,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: context.appTickerColor,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    cycle.name,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.appTextSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (cycle.totalShares > 0)
                  ReturnBadge(
                    value: returnRate,
                    size: ReturnBadgeSize.small,
                    colorScheme: ReturnBadgeColorScheme.redBlue,
                    decimals: 1,
                  )
                else
                  ReturnBadge(
                    value: null,
                    size: ReturnBadgeSize.small,
                    nullLabel: '\uB300\uAE30',
                  ),
              ],
            ),
            const SizedBox(height: 6),

            // === 전략 배지 ===
            StrategyBadge(strategyType: cycle.strategyType),

            if (cycle.totalShares > 0) ...[
              const SizedBox(height: 10),

              // === 중간: 평가금액 + 손익 ===
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '\uD3C9\uAC00\uAE08\uC561',
                        style: TextStyle(
                          fontSize: 10,
                          color: context.appTextSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${formatKrwWithComma(evaluatedAmount)}\u2009\uC6D0',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: context.appTextPrimary,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '\uC190\uC775',
                        style: TextStyle(
                          fontSize: 10,
                          color: context.appTextSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${isProfit ? '+' : ''}${formatKrwWithComma(profitLoss)}\u2009\uC6D0',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: profitColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // === 하단 정보 행: 평균단가 | 현재가 | 잔여현금 ===
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: context.appBackground,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _InfoColumn(
                        label: '\uD3C9\uADE0\uB2E8\uAC00',
                        value: '\$${cycle.averagePrice.toStringAsFixed(2)}',
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 24,
                      color: context.appDivider,
                    ),
                    Expanded(
                      child: _InfoColumn(
                        label: '\uD604\uC7AC\uAC00',
                        value: '\$${currentPrice.toStringAsFixed(2)}',
                        valueColor: _getPriceColor(context, returnRate),
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 24,
                      color: context.appDivider,
                    ),
                    Expanded(
                      child: _InfoColumn(
                        label: '\uC794\uC5EC\uD604\uAE08',
                        value: _formatCash(cycle.remainingCash),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 8),

            // === 신호 배지 ===
            SignalDisplay(
              signal: signal,
              size: SignalDisplaySize.compact,
            ),
          ],
        ),
      ),
    );
  }

  Color _getPriceColor(BuildContext context, double returnRate) {
    if (returnRate > 0) return AppColors.red500;
    if (returnRate < 0) return AppColors.blue500;
    return context.appTextPrimary;
  }

  /// 잔여현금 포맷: 10,000 이상이면 "N만" 형식
  String _formatCash(double cash) {
    if (cash >= 10000) {
      final man = cash / 10000;
      if (man == man.roundToDouble()) {
        return '${man.round().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}만';
      }
      return '${man.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}만';
    }
    return formatKrwWithComma(cash);
  }
}

class _InfoColumn extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoColumn({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: context.appTextSecondary,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: valueColor ?? context.appTextPrimary,
          ),
        ),
      ],
    );
  }
}
