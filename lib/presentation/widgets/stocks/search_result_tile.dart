import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/services/api/finnhub_service.dart';
import '../shared/return_badge.dart';

/// 검색 결과 타일
class SearchResultTile extends StatelessWidget {
  final SearchResult result;
  final bool isDisabled;
  final StockQuote? quote;
  final VoidCallback? onTap;

  const SearchResultTile({
    super.key,
    required this.result,
    required this.isDisabled,
    this.quote,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
              : _getTypeColor(result.type).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            result.symbol.substring(0, result.symbol.length > 2 ? 2 : result.symbol.length),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isDisabled ? context.appTextHint : _getTypeColor(result.type),
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
                      result.symbol,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isDisabled ? context.appTextHint : context.appTextPrimary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.gray100,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        result.type,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                          color: context.appTextHint,
                        ),
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
                  result.name,
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
        ],
      ),
      trailing: isDisabled
          ? null
          : quote != null
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
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
                      value: quote!.changePercent,
                      size: ReturnBadgeSize.small,
                      colorScheme: ReturnBadgeColorScheme.redBlue,
                      decimals: 2,
                      showIcon: false,
                    ),
                  ],
                )
              : const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
    );
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'ETF':
        return AppColors.blue500;
      case 'INDEX':
        return AppColors.amber500;
      default:
        return AppColors.green500;
    }
  }
}
