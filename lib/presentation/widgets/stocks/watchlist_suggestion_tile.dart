import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/services/api/finnhub_service.dart';
import '../shared/return_badge.dart';

/// 관심종목 추천 타일
class WatchlistSuggestionTile extends StatelessWidget {
  final String ticker;
  final String name;
  final StockQuote? quote;
  final bool isDisabled;
  final VoidCallback? onTap;

  const WatchlistSuggestionTile({
    super.key,
    required this.ticker,
    required this.name,
    required this.quote,
    required this.isDisabled,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final changePercent = quote?.changePercent ?? 0;

    return ListTile(
      onTap: onTap,
      enabled: !isDisabled,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isDisabled
              ? AppColors.gray100
              : AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            ticker.substring(0, ticker.length > 2 ? 2 : ticker.length),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isDisabled ? context.appTextHint : AppColors.primary,
            ),
          ),
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      ticker,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isDisabled ? context.appTextHint : context.appTextPrimary,
                      ),
                    ),
                    if (isDisabled) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.gray200,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          '추가됨',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w500,
                            color: context.appTextHint,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDisabled ? context.appTextHint : context.appTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (quote != null && !isDisabled) ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '\$${quote!.currentPrice.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: context.appTextPrimary,
                  ),
                ),
                ReturnBadge(
                  value: changePercent,
                  size: ReturnBadgeSize.small,
                  colorScheme: ReturnBadgeColorScheme.redBlue,
                  decimals: 2,
                  showIcon: false,
                ),
              ],
            ),
          ],
        ],
      ),
      trailing: isDisabled
          ? null
          : Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: context.appTextHint,
            ),
    );
  }
}
