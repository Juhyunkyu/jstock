import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/services/notification/web_notification_service.dart';
import '../../providers/stock_providers.dart';
import '../../widgets/shared/confirm_dialog.dart';
import '../../widgets/watchlist/watchlist_tab_bar.dart';
import '../../widgets/watchlist/watchlist_group_content.dart';
import '../../widgets/watchlist/alert_settings_sheet.dart';
import '../../widgets/watchlist/group_selection_sheet.dart';
import '../../widgets/watchlist/watchlist_settings_sheet.dart';
import '../../widgets/common/notification_bell_button.dart';
import '../../providers/providers.dart';

/// 관심종목 화면 (탭 기반 그룹 지원 + 스와이프 전환)
class WatchlistScreen extends ConsumerStatefulWidget {
  const WatchlistScreen({super.key});

  @override
  ConsumerState<WatchlistScreen> createState() => _WatchlistScreenState();
}

class _WatchlistScreenState extends ConsumerState<WatchlistScreen> {
  late PageController _pageController;
  int _lastTabCount = 0;

  @override
  void initState() {
    super.initState();
    final initialPage = ref.read(selectedWatchlistTabProvider);
    _pageController = PageController(initialPage: initialPage);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
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

    // 탭 수가 바뀌었으면 PageController 재생성 (그룹 추가/삭제 시)
    if (_lastTabCount != tabLabels.length) {
      _lastTabCount = tabLabels.length;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pageController.hasClients) {
          final safeIndex = selectedTabIndex.clamp(0, tabLabels.length - 1);
          _pageController.jumpToPage(safeIndex);
        }
      });
    }

    // 탭 인덱스 범위 보정
    final tabIndex = selectedTabIndex >= tabLabels.length ? 0 : selectedTabIndex;

    // 탭 변경 시 PageView도 동기화
    ref.listen<int>(selectedWatchlistTabProvider, (prev, next) {
      if (_pageController.hasClients && next < tabLabels.length) {
        _pageController.jumpToPage(next);
      }
    });

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
                    // 탭 바
                    WatchlistTabBar(
                      tabLabels: tabLabels,
                      selectedIndex: tabIndex,
                      onTap: (index) =>
                          ref.read(selectedWatchlistTabProvider.notifier).state = index,
                      onSettingsTap: () => _showSettingsSheet(context),
                    ),
                    // 탭 콘텐츠 (스와이프 가능)
                    Expanded(
                      child: PageView.builder(
                        controller: _pageController,
                        itemCount: tabLabels.length,
                        onPageChanged: (index) {
                          ref.read(selectedWatchlistTabProvider.notifier).state = index;
                        },
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
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: context.appSurface,
      builder: (context) => const WatchlistSettingsSheet(),
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
      // 삭제 후에도 보유 또는 다른 그룹에 있으면 알림 유지
      final ownedTickers = ref.read(userTickersProvider);
      final groupState = ref.read(watchlistGroupProvider);
      final inOwned = ownedTickers.contains(ticker);
      final groupCount = groupState.groups
          .where((g) => g.containsTicker(ticker))
          .length;
      // 현재 삭제 대상이 그룹 소속이면 1개 빼야 함
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
      // 알림 대상에서 빠지는 경우 알림 해제
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
    final item = watchlistState.items
        .where((i) => i.ticker == ticker)
        .firstOrNull;
    if (item == null) return;

    if (!WebNotificationService.isPermissionGranted) {
      await WebNotificationService.requestPermission();
    }

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: context.appSurface,
      builder: (context) => AlertSettingsSheet(
        item: item,
        currentPrice: currentPrice,
      ),
    );
  }
}
