import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/watchlist_item.dart';
import '../../../data/services/notification/web_notification_service.dart';
import '../../providers/providers.dart';
import '../../widgets/shared/confirm_dialog.dart';
import '../../widgets/watchlist/watchlist_tab_bar.dart';
import '../../widgets/watchlist/watchlist_group_content.dart';
import '../../widgets/watchlist/alert_settings_sheet.dart';
import '../../widgets/watchlist/group_selection_sheet.dart';
import '../../widgets/watchlist/watchlist_settings_sheet.dart';
import '../../widgets/common/notification_bell_button.dart';

/// 관심종목 화면 (탭 기반 그룹 지원 + 스와이프 전환)
class WatchlistScreen extends ConsumerStatefulWidget {
  const WatchlistScreen({super.key});

  @override
  ConsumerState<WatchlistScreen> createState() => _WatchlistScreenState();
}

class _WatchlistScreenState extends ConsumerState<WatchlistScreen> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _currentPage = ref.read(selectedWatchlistTabProvider);
    _pageController = PageController(initialPage: _currentPage);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onTabTap(int index) {
    ref.read(selectedWatchlistTabProvider.notifier).state = index;
    if (_pageController.hasClients) {
      _pageController.jumpToPage(index);
    }
  }

  void _onPageChanged(int index) {
    ref.read(selectedWatchlistTabProvider.notifier).state = index;
    setState(() => _currentPage = index);
  }

  @override
  Widget build(BuildContext context) {
    final watchlistState = ref.watch(watchlistProvider);
    final groupState = ref.watch(watchlistGroupProvider);
    final selectedTabIndex = ref.watch(selectedWatchlistTabProvider);

    // 탭 라벨 구성: 보유 | 최근 | [사용자 그룹들...]
    final tabLabels = <String>[
      '보유',
      '최근',
      ...groupState.groups.map((g) => g.name),
    ];

    // 탭 인덱스 범위 보정
    final tabIndex = selectedTabIndex >= tabLabels.length ? 0 : selectedTabIndex;

    // 외부에서 탭 변경 시 (뒤로가기 복귀 등) PageView 동기화
    if (_pageController.hasClients && tabIndex != _currentPage) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pageController.hasClients && tabIndex < tabLabels.length) {
          _pageController.jumpToPage(tabIndex);
          _currentPage = tabIndex;
        }
      });
    }

    return Scaffold(
      backgroundColor: context.appBackground,
      appBar: AppBar(
        backgroundColor: context.appSurface,
        elevation: 0,
        toolbarHeight: 64,
        title: const Text('관심종목'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: context.appTextSecondary),
            onPressed: () =>
                ref.read(watchlistProvider.notifier).refreshQuotes(),
          ),
          const NotificationBellButton(),
        ],
      ),
      body: watchlistState.isLoading || groupState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : watchlistState.error != null
              ? _buildErrorState(watchlistState.error!)
              : Column(
                  children: [
                    // 검색 바
                    InkWell(
                      onTap: () => context.push('/stocks/search?forDetail=true'),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: context.appIconBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.search, size: 20, color: context.appTextHint),
                            const SizedBox(width: 10),
                            Text(
                              '종목 검색 (티커 또는 기업명)',
                              style: TextStyle(fontSize: 14, color: context.appTextHint),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // 탭 바
                    WatchlistTabBar(
                      tabLabels: tabLabels,
                      selectedIndex: tabIndex,
                      onTap: _onTabTap,
                      onSettingsTap: () => _showSettingsSheet(context),
                    ),
                    // 탭 콘텐츠 (스와이프 가능)
                    Expanded(
                      child: PageView.builder(
                        controller: _pageController,
                        itemCount: tabLabels.length,
                        onPageChanged: _onPageChanged,
                        itemBuilder: (context, index) {
                          return _buildPageContent(index, watchlistState, groupState);
                        },
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildPageContent(
    int tabIndex,
    WatchlistState watchlistState,
    WatchlistGroupState groupState,
  ) {
    // 0 = 보유, 1 = 최근, 2+ = 사용자 그룹
    if (tabIndex == 0) {
      return WatchlistGroupContent(
        tabType: WatchlistTabType.owned,
        onTickerTap: (ticker) => _onTickerTap(ticker),
        onRemoveFromWatchlist: _onRemove,
        onRemoveFromRecent: _onRemoveFromRecent,
        onAlertTap: _onAlertTap,
        onStarTap: _onStarTap,
      );
    }

    if (tabIndex == 1) {
      return WatchlistGroupContent(
        tabType: WatchlistTabType.recent,
        onTickerTap: (ticker) => _onTickerTap(ticker),
        onRemoveFromWatchlist: _onRemove,
        onRemoveFromRecent: _onRemoveFromRecent,
        onAlertTap: _onAlertTap,
        onStarTap: _onStarTap,
        onClearAllRecent: _onClearAllRecent,
      );
    }

    // 사용자 그룹
    final groupIndex = tabIndex - 2;
    if (groupIndex >= 0 && groupIndex < groupState.groups.length) {
      final group = groupState.groups[groupIndex];
      return WatchlistGroupContent(
        key: ValueKey(group.id),
        tabType: WatchlistTabType.custom,
        groupId: group.id,
        onTickerTap: (ticker) => _onTickerTap(ticker),
        onRemoveFromWatchlist: _onRemove,
        onRemoveFromRecent: _onRemoveFromRecent,
        onRemoveFromGroup: _onRemoveFromGroup,
        onAlertTap: _onAlertTap,
        onStarTap: _onStarTap,
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 64,
            color: context.appTextHint,
          ),
          const SizedBox(height: 16),
          Text(
            error,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: context.appTextSecondary,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => ref.read(watchlistProvider.notifier).load(),
            icon: const Icon(Icons.refresh),
            label: const Text('다시 시도'),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.appAccent,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _showSettingsSheet(BuildContext context) {
    // 현재 선택된 탭이 사용자 그룹이면 그 그룹 ID 전달
    final tabIndex = ref.read(selectedWatchlistTabProvider);
    final groups = ref.read(watchlistGroupProvider).groups;
    String? currentGroupId;
    if (tabIndex >= 2 && tabIndex - 2 < groups.length) {
      currentGroupId = groups[tabIndex - 2].id;
    }

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: context.appSurface,
      builder: (context) => WatchlistSettingsSheet(initialGroupId: currentGroupId),
    );
  }

  void _onTickerTap(String ticker) {
    context.go('/index/${Uri.encodeComponent(ticker)}?from=watchlist');
  }

  Future<void> _onRemove(String ticker) async {
    final watchlistState = ref.read(watchlistProvider);
    final item = watchlistState.items
        .where((i) => i.ticker == ticker)
        .firstOrNull;

    // 알림이 있는 종목: 삭제 후에도 알림 대상인지 확인
    String message = '$ticker을(를) 삭제하시겠습니까?';
    if (item != null && item.hasAlert) {
      final ownedTickers = ref.read(userTickersProvider);
      final groupState = ref.read(watchlistGroupProvider);
      final inOwned = ownedTickers.contains(ticker);
      final groupCount = groupState.groups
          .where((g) => g.containsTicker(ticker))
          .length;
      final remainsEligible = inOwned || groupCount > 1;

      if (!remainsEligible) {
        message = '$ticker에 ${item.alertSummary} 알림이 설정되어 있습니다.\n'
            '삭제하면 알림도 함께 삭제됩니다.';
      }
    }

    final confirmed = await ConfirmDialog.show(
      context: context,
      title: '종목 삭제',
      message: message,
      confirmText: '삭제',
      isDanger: true,
    );
    if (confirmed && mounted) {
      if (item != null && item.hasAlert) {
        final ownedTickers = ref.read(userTickersProvider);
        final groupState = ref.read(watchlistGroupProvider);
        final inOwned = ownedTickers.contains(ticker);
        final groupCount = groupState.groups
            .where((g) => g.containsTicker(ticker))
            .length;
        if (!inOwned && groupCount <= 1) {
          await ref.read(watchlistProvider.notifier).clearAllAlerts(ticker);
        }
      }

      ref.read(watchlistProvider.notifier).remove(ticker);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$ticker 삭제됨'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _onRemoveFromRecent(String ticker) {
    ref.read(recentViewProvider.notifier).remove(ticker);
  }

  Future<void> _onRemoveFromGroup(String groupId, String ticker) async {
    final watchlistState = ref.read(watchlistProvider);
    final item = watchlistState.items
        .where((i) => i.ticker == ticker)
        .firstOrNull;

    // 알림이 있는 종목: 이 그룹 제거 후에도 알림 대상인지 확인
    String message = '$ticker을(를) 이 그룹에서 제거하시겠습니까?';
    bool willLoseAlert = false;
    if (item != null && item.hasAlert) {
      final ownedTickers = ref.read(userTickersProvider);
      final groupState = ref.read(watchlistGroupProvider);
      final inOwned = ownedTickers.contains(ticker);
      // 현재 그룹 포함해서 카운트 → 1이면 이 그룹에만 있음
      final groupCount = groupState.groups
          .where((g) => g.containsTicker(ticker))
          .length;
      willLoseAlert = !inOwned && groupCount <= 1;

      if (willLoseAlert) {
        message = '$ticker에 ${item.alertSummary} 알림이 설정되어 있습니다.\n'
            '이 그룹에서 제거하면 알림도 함께 삭제됩니다.';
      }
    }

    final confirmed = await ConfirmDialog.show(
      context: context,
      title: '그룹에서 제거',
      message: message,
      confirmText: '제거',
      isDanger: true,
    );
    if (confirmed && mounted) {
      // 알림 정리 (마지막 그룹이었으면 알림 삭제)
      if (willLoseAlert) {
        await ref.read(watchlistProvider.notifier).clearAllAlerts(ticker);
      }

      ref.read(watchlistGroupProvider.notifier).removeTicker(groupId, ticker);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(willLoseAlert
              ? '$ticker 그룹에서 제거됨 (알림도 삭제됨)'
              : '$ticker 그룹에서 제거됨'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _onClearAllRecent() {
    ref.read(recentViewProvider.notifier).clearAll();
  }

  void _onStarTap(String ticker) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: context.appSurface,
      builder: (context) => GroupSelectionSheet(ticker: ticker),
    );
  }

  void _onAlertTap(String ticker, double? currentPrice) async {
    final watchlistState = ref.read(watchlistProvider);
    var item = watchlistState.items
        .where((i) => i.ticker == ticker)
        .firstOrNull;

    // WatchlistItem이 없으면 자동 생성 (보유 종목이지만 관심종목에 미등록인 경우)
    if (item == null) {
      final newItem = WatchlistItem(
        ticker: ticker,
        name: ticker,
        exchange: '',
        type: 'stock',
      );
      await ref.read(watchlistProvider.notifier).add(newItem);
      item = ref.read(watchlistProvider).items
          .where((i) => i.ticker == ticker)
          .firstOrNull;
      if (item == null) return;
    }

    // 알림 권한은 시트 안에서 처리 (여기서 await하면 mounted 문제 발생 가능)
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: context.appSurface,
      builder: (context) => AlertSettingsSheet(
        item: item!,
        currentPrice: currentPrice,
      ),
    );
  }
}
