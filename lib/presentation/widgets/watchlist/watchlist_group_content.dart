import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/watchlist_item.dart';
import '../../../data/services/api/finnhub_service.dart';
import '../../providers/api_providers.dart';
import '../../providers/watchlist_providers.dart';
import '../../providers/watchlist_group_providers.dart';
import '../../providers/stock_providers.dart';
import '../common/responsive_grid.dart';
import '../shared/return_badge.dart';
import '../shared/ticker_logo.dart';
import 'watchlist_helpers.dart';
import 'watchlist_tile.dart';

/// 관심종목 그룹 탭 콘텐츠
///
/// 탭 종류에 따라 다른 콘텐츠를 표시합니다:
/// - 보유: 활성 사이클 + 보유 종목 (읽기 전용)
/// - 최근: 최근 조회 종목 (읽기 전용)
/// - 사용자 그룹: 사용자 정의 티커 목록 (편집 가능)
enum WatchlistTabType { owned, recent, custom }

class WatchlistGroupContent extends ConsumerWidget {
  final WatchlistTabType tabType;
  final String? groupId;
  final void Function(String ticker) onTickerTap;
  final void Function(String ticker) onRemoveFromWatchlist;
  final void Function(String ticker, double? currentPrice) onAlertTap;

  const WatchlistGroupContent({
    super.key,
    required this.tabType,
    this.groupId,
    required this.onTickerTap,
    required this.onRemoveFromWatchlist,
    required this.onAlertTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    switch (tabType) {
      case WatchlistTabType.owned:
        return _buildOwnedContent(context, ref);
      case WatchlistTabType.recent:
        return _buildRecentContent(context, ref);
      case WatchlistTabType.custom:
        return _buildCustomContent(context, ref);
    }
  }

  /// 보유 탭: 활성 사이클 + 보유 종목 티커
  Widget _buildOwnedContent(BuildContext context, WidgetRef ref) {
    final tickers = ref.watch(userTickersProvider);
    if (tickers.isEmpty) {
      return _buildEmptyState(context, '보유 중인 종목이 없습니다');
    }
    return _buildTickerList(context, ref, tickers, isEditable: false);
  }

  /// 최근 탭: 최근 조회 종목
  Widget _buildRecentContent(BuildContext context, WidgetRef ref) {
    final recentItems = ref.watch(recentViewProvider);
    if (recentItems.isEmpty) {
      return _buildEmptyState(context, '최근 조회한 종목이 없습니다');
    }
    final tickers = recentItems.map((e) => e.ticker).toList();
    return _buildTickerList(context, ref, tickers, isEditable: false);
  }

  /// 사용자 그룹 탭: 사용자 정의 티커 목록
  Widget _buildCustomContent(BuildContext context, WidgetRef ref) {
    final groupState = ref.watch(watchlistGroupProvider);
    if (groupId == null) return const SizedBox.shrink();

    final group = groupState.groups
        .where((g) => g.id == groupId)
        .firstOrNull;

    if (group == null || group.tickers.isEmpty) {
      return _buildEmptyState(
        context,
        '종목이 없습니다\n설정에서 종목을 추가해보세요',
      );
    }

    return _buildTickerList(context, ref, group.tickers, isEditable: true);
  }

  /// 티커 리스트 빌드 (관심종목에 있는 티커는 WatchlistTile, 없으면 간단 타일)
  Widget _buildTickerList(
    BuildContext context,
    WidgetRef ref,
    List<String> tickers, {
    required bool isEditable,
  }) {
    final watchlistState = ref.watch(watchlistProvider);
    final quoteState = ref.watch(stockQuoteProvider);

    // 관심종목에 있는 티커는 WatchlistItem 활용, 없으면 시세만 표시
    final items = <_TickerDisplayItem>[];
    for (final ticker in tickers) {
      final watchlistItem = watchlistState.items
          .where((w) => w.ticker == ticker)
          .firstOrNull;
      final quote = quoteState.quotes[ticker];
      items.add(_TickerDisplayItem(
        ticker: ticker,
        watchlistItem: watchlistItem,
        quote: quote,
      ));
    }

    final useGrid = ResponsiveGrid.shouldUseGrid(context);

    if (useGrid) {
      final itemW = ResponsiveGrid.gridItemWidth(context);
      return ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: ResponsiveGrid.horizontalPadding,
            ),
            child: Wrap(
              spacing: ResponsiveGrid.spacing,
              runSpacing: ResponsiveGrid.runSpacing,
              children: items.map((item) {
                if (item.watchlistItem != null) {
                  return SizedBox(
                    width: itemW,
                    child: WatchlistTile(
                      item: item.watchlistItem!,
                      index: items.indexOf(item),
                      inGrid: true,
                      onTap: () => onTickerTap(item.ticker),
                      onRemove: () => onRemoveFromWatchlist(item.ticker),
                      onAlertTap: (price) => onAlertTap(item.ticker, price),
                    ),
                  );
                }
                return SizedBox(
                  width: itemW,
                  child: _SimpleTickerTile(
                    ticker: item.ticker,
                    quote: item.quote,
                    inGrid: true,
                    onTap: () => onTickerTap(item.ticker),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      );
    }

    // 모바일: 세로 리스트
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        if (item.watchlistItem != null) {
          return WatchlistTile(
            key: ValueKey(item.ticker),
            item: item.watchlistItem!,
            index: index,
            onTap: () => onTickerTap(item.ticker),
            onRemove: () => onRemoveFromWatchlist(item.ticker),
            onAlertTap: (price) => onAlertTap(item.ticker, price),
          );
        }
        return _SimpleTickerTile(
          key: ValueKey(item.ticker),
          ticker: item.ticker,
          quote: item.quote,
          onTap: () => onTickerTap(item.ticker),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              tabType == WatchlistTabType.owned
                  ? Icons.account_balance_wallet_outlined
                  : tabType == WatchlistTabType.recent
                      ? Icons.history
                      : Icons.folder_outlined,
              size: 48,
              color: context.appBorder,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: context.appTextHint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 내부 데이터 클래스
class _TickerDisplayItem {
  final String ticker;
  final WatchlistItem? watchlistItem;
  final StockQuote? quote;

  _TickerDisplayItem({
    required this.ticker,
    this.watchlistItem,
    this.quote,
  });
}

/// 관심종목에 없는 티커의 간단 타일 (시세만 표시)
class _SimpleTickerTile extends StatelessWidget {
  final String ticker;
  final StockQuote? quote;
  final bool inGrid;
  final VoidCallback onTap;

  const _SimpleTickerTile({
    super.key,
    required this.ticker,
    this.quote,
    this.inGrid = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: inGrid
          ? BoxDecoration(
              color: context.appSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.appBorder),
            )
          : BoxDecoration(color: context.appSurface),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  TickerLogo(ticker: ticker, size: 38, borderRadius: 7),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      ticker,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: context.appTickerColor,
                      ),
                    ),
                  ),
                  if (quote != null) ...[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          formatPrice(quote!.currentPrice),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: context.appTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        ReturnBadge(
                          value: quote!.changePercent,
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
          if (!inGrid)
            Container(height: 4, color: context.appBackground),
        ],
      ),
    );
  }
}
