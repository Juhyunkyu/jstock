import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/watchlist_item.dart';
import '../../providers/api_providers.dart';
import '../shared/return_badge.dart';
import '../shared/ticker_logo.dart';
import 'watchlist_helpers.dart';

/// 관심종목 타일 (실시간 업데이트를 위해 ConsumerWidget 사용)
class WatchlistTile extends ConsumerWidget {
  final WatchlistItem item;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onRemove;
  final void Function(double? currentPrice) onAlertTap;
  final bool inGrid;

  const WatchlistTile({
    super.key,
    required this.item,
    required this.index,
    required this.onTap,
    required this.onRemove,
    required this.onAlertTap,
    this.inGrid = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quoteState = ref.watch(stockQuoteProvider);
    final quote = quoteState.quotes[item.ticker];

    final tileContent = Container(
      decoration: inGrid
          ? BoxDecoration(
              color: context.appSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.appBorder),
              boxShadow: [
                BoxShadow(
                  color: context.isDarkMode
                      ? Colors.white.withValues(alpha: 0.03)
                      : Colors.black.withValues(alpha: 0.05),
                  blurRadius: 6,
                  offset: const Offset(0, 1),
                ),
              ],
            )
          : BoxDecoration(color: context.appSurface),
      clipBehavior: inGrid ? Clip.antiAlias : Clip.none,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 메인 콘텐츠 (탭 → 상세 페이지)
          GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.only(
                  left: 16, right: 16, top: 10, bottom: 10),
              child: Row(
                children: [
                  // 아바타 (알림 배지 포함)
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      TickerLogo(
                        ticker: item.ticker,
                        size: 38,
                        borderRadius: 7,
                        backgroundColor: getTypeColor(item.type)
                            .withValues(alpha: 0.1),
                        textColor: getTypeColor(item.type),
                      ),
                      if (item.hasAlert)
                        Positioned(
                          top: -3,
                          right: -3,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: AppColors.amber500,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: context.appSurface,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 10),
                  // 종목명 / 거래소
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              item.ticker,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: context.appTickerColor,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: context.appIconBg,
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Text(
                                formatBadge(item.exchange, item.type),
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w500,
                                  color: context.appTextHint,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: context.appTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 현재가 / 등락률
                  if (quote != null) ...[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          formatPrice(quote.currentPrice),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: context.appTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        ReturnBadge(
                          value: quote.changePercent,
                          size: ReturnBadgeSize.small,
                          colorScheme: ReturnBadgeColorScheme.redBlue,
                          decimals: 2,
                        ),
                      ],
                    ),
                  ] else ...[
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // 구분선
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Divider(height: 1, color: context.appDivider),
          ),

          // 액션 행 (알림 + 삭제)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                // 알림 버튼
                Expanded(
                  child: GestureDetector(
                    onTap: () => onAlertTap(quote?.currentPrice),
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            item.hasAlert
                                ? Icons.notifications_active
                                : Icons.notifications_none,
                            size: 16,
                            color: item.hasAlert
                                ? AppColors.amber600
                                : context.appTextHint,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              item.alertSummary,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: item.hasAlert
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: item.hasAlert
                                    ? AppColors.amber600
                                    : context.appTextHint,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // 구분선
                Container(
                  width: 1,
                  height: 16,
                  color: context.appDivider,
                ),

                // 삭제 버튼
                GestureDetector(
                  onTap: onRemove,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                    child: Icon(
                      Icons.delete_outline,
                      size: 16,
                      color: context.appTextHint,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 타일 간 간격 (리스트 모드에서만)
          if (!inGrid)
            Container(height: 4, color: context.appBackground),
        ],
      ),
    );

    // 그리드 모드: 드래그 불필요
    if (inGrid) return tileContent;

    // 리스트 모드: 드래그 지원
    return ReorderableDelayedDragStartListener(
      index: index,
      child: tileContent,
    );
  }
}
