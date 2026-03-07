import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/services/notification/web_notification_service.dart';
import '../../providers/watchlist_providers.dart';
import '../../providers/watchlist_group_providers.dart';
import '../../widgets/shared/confirm_dialog.dart';
import '../../widgets/watchlist/watchlist_tab_bar.dart';
import '../../widgets/watchlist/watchlist_group_content.dart';
import '../../widgets/watchlist/alert_settings_sheet.dart';
import '../../widgets/watchlist/watchlist_settings_sheet.dart';
import '../../widgets/common/notification_bell_button.dart';

/// 관심종목 화면 (탭 기반 그룹 지원)
class WatchlistScreen extends ConsumerStatefulWidget {
  const WatchlistScreen({super.key});

  @override
  ConsumerState<WatchlistScreen> createState() => _WatchlistScreenState();
}

class _WatchlistScreenState extends ConsumerState<WatchlistScreen> {
  int _selectedTabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final watchlistState = ref.watch(watchlistProvider);
    final groupState = ref.watch(watchlistGroupProvider);

    // 탭 라벨 구성: 보유 | 최근 | [사용자 그룹들...]
    final tabLabels = <String>[
      '보유',
      '최근',
      ...groupState.groups.map((g) => g.name),
    ];

    // 탭 인덱스 범위 보정
    if (_selectedTabIndex >= tabLabels.length) {
      _selectedTabIndex = 0;
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
                    // 탭 바
                    WatchlistTabBar(
                      tabLabels: tabLabels,
                      selectedIndex: _selectedTabIndex,
                      onTap: (index) =>
                          setState(() => _selectedTabIndex = index),
                      onSettingsTap: () => _showSettingsSheet(context),
                    ),
                    // 탭 콘텐츠
                    Expanded(
                      child: _buildTabContent(watchlistState, groupState),
                    ),
                  ],
                ),
    );
  }

  Widget _buildTabContent(
    WatchlistState watchlistState,
    WatchlistGroupState groupState,
  ) {
    // 0 = 보유, 1 = 최근, 2+ = 사용자 그룹
    if (_selectedTabIndex == 0) {
      return WatchlistGroupContent(
        tabType: WatchlistTabType.owned,
        onTickerTap: (ticker) => _onTickerTap(ticker),
        onRemoveFromWatchlist: _onRemove,
        onAlertTap: _onAlertTap,
      );
    }

    if (_selectedTabIndex == 1) {
      return WatchlistGroupContent(
        tabType: WatchlistTabType.recent,
        onTickerTap: (ticker) => _onTickerTap(ticker),
        onRemoveFromWatchlist: _onRemove,
        onAlertTap: _onAlertTap,
      );
    }

    // 사용자 그룹
    final groupIndex = _selectedTabIndex - 2;
    if (groupIndex >= 0 && groupIndex < groupState.groups.length) {
      final group = groupState.groups[groupIndex];
      return WatchlistGroupContent(
        key: ValueKey(group.id),
        tabType: WatchlistTabType.custom,
        groupId: group.id,
        onTickerTap: (ticker) => _onTickerTap(ticker),
        onRemoveFromWatchlist: _onRemove,
        onAlertTap: _onAlertTap,
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
      isScrollControlled: true,
      backgroundColor: context.appSurface,
      builder: (context) => const WatchlistSettingsSheet(),
    );
  }

  void _onTickerTap(String ticker) {
    context.go('/index/${Uri.encodeComponent(ticker)}?from=watchlist');
  }

  Future<void> _onRemove(String ticker) async {
    final confirmed = await ConfirmDialog.show(
      context: context,
      title: '관심종목 삭제',
      message: '$ticker을(를) 관심종목에서 삭제하시겠습니까?',
      confirmText: '삭제',
      isDanger: true,
    );
    if (confirmed && mounted) {
      ref.read(watchlistProvider.notifier).remove(ticker);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$ticker 관심종목에서 삭제됨'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
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
      isScrollControlled: true,
      backgroundColor: context.appSurface,
      builder: (context) => AlertSettingsSheet(
        item: item,
        currentPrice: currentPrice,
      ),
    );
  }
}
