import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../providers/api_providers.dart';
import '../shared/return_badge.dart';
import 'popular_etf_list.dart';

/// 종목 정보 카드 (실시간 시세 표시)
class StockInfoCard extends ConsumerWidget {
  final String ticker;
  final PopularEtf? etfInfo;

  const StockInfoCard({
    super.key,
    required this.ticker,
    this.etfInfo,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quoteState = ref.watch(stockQuoteProvider);
    final quote = quoteState.quotes[ticker];
    final currentPrice = quote?.currentPrice;
    final changePercent = quote?.changePercent ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                ticker.substring(0, 2),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ticker,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: context.appTextPrimary,
                  ),
                ),
                if (etfInfo != null)
                  Text(
                    etfInfo!.name,
                    style: TextStyle(
                      fontSize: 14,
                      color: context.appTextSecondary,
                    ),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (currentPrice != null)
                Text(
                  '\$${currentPrice.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: context.appTextPrimary,
                  ),
                )
              else
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              const SizedBox(height: 4),
              if (currentPrice != null)
                ReturnBadge(
                  value: changePercent,
                  colorScheme: ReturnBadgeColorScheme.redBlue,
                  decimals: 2,
                  showIcon: false,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
