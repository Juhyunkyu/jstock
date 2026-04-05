import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/watchlist_item.dart';
import '../../providers/api_providers.dart';
import '../../providers/stock_providers.dart';
import '../common/responsive_grid.dart';
import '../shared/return_badge.dart';
import '../shared/ticker_logo.dart';
import 'watchlist_helpers.dart';
import 'watchlist_tile.dart';
import '../../providers/providers.dart';

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
  final void Function(String ticker) onRemoveFromRecent;
  final void Function(String groupId, String ticker)? onRemoveFromGroup;
  final void Function(String ticker, double? currentPrice) onAlertTap;
  final void Function(String ticker) onStarTap;
  final VoidCallback? onClearAllRecent;

  const WatchlistGroupContent({
    super.key,
    required this.tabType,
    this.groupId,
    required this.onTickerTap,
    required this.onRemoveFromWatchlist,
    required this.onRemoveFromRecent,
    this.onRemoveFromGroup,
    required this.onAlertTap,
    required this.onStarTap,
    this.onClearAllRecent,
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

    // 관심종목에 있는 티커는 WatchlistItem 활용, 없으면 시세만 표시
    final items = <_TickerDisplayItem>[];
    for (final ticker in tickers) {
      final watchlistItem = watchlistState.items
          .where((w) => w.ticker == ticker)
          .firstOrNull;
      items.add(_TickerDisplayItem(
        ticker: ticker,
        watchlistItem: watchlistItem,
      ));
    }

    final useGrid = ResponsiveGrid.shouldUseGrid(context);
    // 탭별 액션 표시 규칙
    // 보유: ★ + 🔔 / 최근: ★ + 🗑 / 사용자 그룹: ★ + 🔔 + 🗑
    final canAlert = tabType == WatchlistTabType.owned || tabType == WatchlistTabType.custom;
    final canDelete = tabType == WatchlistTabType.recent || tabType == WatchlistTabType.custom;

    // 탭 종류별 삭제 라우팅
    void handleRemove(String ticker) {
      if (tabType == WatchlistTabType.recent) {
        onRemoveFromRecent(ticker);
      } else if (tabType == WatchlistTabType.custom && groupId != null && onRemoveFromGroup != null) {
        onRemoveFromGroup!(groupId!, ticker);
      } else {
        onRemoveFromWatchlist(ticker);
      }
    }

    Widget buildWatchlistTile(
        _TickerDisplayItem item, int idx, {bool grid = false}) {
      return WatchlistTile(
        item: item.watchlistItem!,
        index: idx,
        inGrid: grid,
        showAlert: canAlert,
        showDelete: canDelete,
        onTap: () => onTickerTap(item.ticker),
        onRemove: () => handleRemove(item.ticker),
        onAlertTap: (price) => onAlertTap(item.ticker, price),
        onStarTap: () => onStarTap(item.ticker),
      );
    }

    Widget buildSimpleTile(_TickerDisplayItem item, {bool grid = false}) {
      return _SimpleTickerTile(
        ticker: item.ticker,
        inGrid: grid,
        showAlert: canAlert,
        showDelete: canDelete,
        onTap: () => onTickerTap(item.ticker),
        onStarTap: () => onStarTap(item.ticker),
        onAlertTap: canAlert ? (price) => onAlertTap(item.ticker, price) : null,
        onDelete: canDelete ? () => handleRemove(item.ticker) : null,
      );
    }

    // 최근 탭: "전체삭제" 버튼
    Widget? clearAllButton;
    if (tabType == WatchlistTabType.recent && onClearAllRecent != null && items.isNotEmpty) {
      clearAllButton = Padding(
        padding: const EdgeInsets.only(right: 16, top: 4, bottom: 2),
        child: Align(
          alignment: Alignment.centerRight,
          child: GestureDetector(
            onTap: onClearAllRecent,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Text(
                '전체삭제',
                style: TextStyle(
                  fontSize: 12,
                  color: context.appTextHint,
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (useGrid) {
      final itemW = ResponsiveGrid.gridItemWidth(context);
      return ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          if (clearAllButton != null) clearAllButton,
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: ResponsiveGrid.horizontalPadding,
            ),
            child: Wrap(
              spacing: ResponsiveGrid.spacing,
              runSpacing: ResponsiveGrid.runSpacing,
              children: items.map((item) {
                final w = item.watchlistItem != null
                    ? buildWatchlistTile(item, items.indexOf(item), grid: true)
                    : buildSimpleTile(item, grid: true);
                return SizedBox(width: itemW, child: w);
              }).toList(),
            ),
          ),
        ],
      );
    }

    // 모바일: 세로 리스트
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: items.length + (clearAllButton != null ? 1 : 0),
      itemBuilder: (context, index) {
        if (clearAllButton != null && index == 0) {
          return clearAllButton;
        }
        final itemIndex = clearAllButton != null ? index - 1 : index;
        final item = items[itemIndex];
        if (item.watchlistItem != null) {
          return buildWatchlistTile(item, itemIndex);
        }
        return buildSimpleTile(item);
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

  _TickerDisplayItem({
    required this.ticker,
    this.watchlistItem,
  });
}

/// 관심종목에 없는 티커의 간단 타일 (시세만 표시, 자동 fetch)
class _SimpleTickerTile extends ConsumerStatefulWidget {
  final String ticker;
  final bool inGrid;
  final bool showAlert;
  final bool showDelete;
  final VoidCallback onTap;
  final VoidCallback? onStarTap;
  final VoidCallback? onDelete;
  final void Function(double? currentPrice)? onAlertTap;

  const _SimpleTickerTile({
    super.key,
    required this.ticker,
    this.inGrid = false,
    this.showAlert = false,
    this.showDelete = false,
    required this.onTap,
    this.onStarTap,
    this.onDelete,
    this.onAlertTap,
  });

  @override
  ConsumerState<_SimpleTickerTile> createState() => _SimpleTickerTileState();
}

class _SimpleTickerTileState extends ConsumerState<_SimpleTickerTile> {
  bool _fetchRequested = false;

  @override
  void initState() {
    super.initState();
    _fetchQuoteIfNeeded();
  }

  void _fetchQuoteIfNeeded() {
    if (_fetchRequested) return;
    final quote = ref.read(stockQuoteProvider).quotes[widget.ticker];
    if (quote == null) {
      _fetchRequested = true;
      ref.read(stockQuoteProvider.notifier).fetchQuote(widget.ticker);
    }
  }

  @override
  Widget build(BuildContext context) {
    final quote = ref.watch(
      stockQuoteProvider.select((s) => s.quotes[widget.ticker]),
    );

    return Container(
      decoration: widget.inGrid
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
            onTap: widget.onTap,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Builder(
                builder: (context) {
                  final watchlistState = ref.watch(watchlistProvider);
                  final watchlistItem = watchlistState.items
                      .where((w) => w.ticker == widget.ticker)
                      .firstOrNull;
                  final exchange = watchlistItem?.exchange ?? '';
                  final type = watchlistItem?.type ?? '';

                  return Row(
                    children: [
                      TickerLogo(ticker: widget.ticker, size: 38, borderRadius: 7),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Row(
                          children: [
                            Text(
                              widget.ticker,
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
                                formatBadge(exchange, type),
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w500,
                                  color: context.appTextHint,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (quote != null) ...[
                        Text(
                          formatPrice(ref.watch(
                            closingPricesProvider.select(
                              (map) => map[widget.ticker] ?? quote.currentPrice,
                            ),
                          )),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: context.appTextPrimary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        ReturnBadge(
                          value: quote.changePercent,
                          size: ReturnBadgeSize.small,
                          colorScheme: ReturnBadgeColorScheme.redBlue,
                          decimals: 2,
                        ),
                      ] else ...[
                        Text(
                          '—',
                          style: TextStyle(
                            fontSize: 15,
                            color: context.appTextHint,
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),

          // 액션 행 (별표 + 알림 + 삭제) — WatchlistTile과 동일 레이아웃
          if (widget.onStarTap != null || widget.showAlert || widget.showDelete) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Divider(height: 1, color: context.appDivider),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  // Star — padding horizontal:12, vertical:7, icon size 18
                  if (widget.onStarTap != null) ...[
                    _StarIcon(
                      ticker: widget.ticker,
                      onTap: widget.onStarTap!,
                    ),
                    Container(width: 1, height: 16, color: context.appDivider),
                  ],
                  // Alert area (탭하면 알림 설정 시트 열기)
                  if (widget.showAlert)
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          final price = ref.read(stockQuoteProvider).quotes[widget.ticker]?.currentPrice;
                          widget.onAlertTap?.call(price);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.notifications_none,
                                size: 14,
                                color: context.appTextHint,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '알림 없음',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: context.appTextHint,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  // Spacer when no alert — 삭제를 우측으로 밀어줌
                  if (!widget.showAlert) const Spacer(),
                  // Delete — padding horizontal:16, vertical:7, icon size 16
                  if (widget.showDelete && widget.onDelete != null) ...[
                    Container(width: 1, height: 16, color: context.appDivider),
                    GestureDetector(
                      onTap: widget.onDelete,
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
                ],
              ),
            ),
          ],

          if (!widget.inGrid)
            Container(height: 4, color: context.appBackground),
        ],
      ),
    );
  }
}

/// 별표 아이콘 (그룹 소속 여부 표시)
class _StarIcon extends ConsumerWidget {
  final String ticker;
  final VoidCallback onTap;

  const _StarIcon({required this.ticker, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isInGroup = ref.watch(isTickerInAnyGroupProvider(ticker));
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Icon(
          isInGroup ? Icons.star : Icons.star_border,
          size: 18,
          color: isInGroup ? AppColors.amber500 : context.appTextHint,
        ),
      ),
    );
  }
}
