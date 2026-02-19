import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/watchlist_item.dart';
import '../../../data/services/notification/web_notification_service.dart';
import '../../providers/watchlist_alert_provider.dart';
import '../../providers/watchlist_providers.dart';
import '../../widgets/shared/confirm_dialog.dart';
import '../../widgets/common/responsive_grid.dart';
import '../../widgets/watchlist/watchlist_tile.dart';
import '../../widgets/watchlist/add_watchlist_sheet.dart';
import '../../widgets/watchlist/alert_settings_sheet.dart';
import '../../widgets/common/notification_bell_button.dart';

/// 관심종목 화면 (실시간 WebSocket 업데이트 지원)
class WatchlistScreen extends ConsumerStatefulWidget {
  const WatchlistScreen({super.key});

  @override
  ConsumerState<WatchlistScreen> createState() => _WatchlistScreenState();
}

class _WatchlistScreenState extends ConsumerState<WatchlistScreen> {
  @override
  Widget build(BuildContext context) {
    final watchlistState = ref.watch(watchlistProvider);

    // 알림 감시 활성화
    final alerts = ref.watch(watchlistAlertMonitorProvider);
    if (alerts.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        for (final alert in alerts) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    alert.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    alert.body,
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
              backgroundColor: alert.type == 'target'
                  ? AppColors.stockUp.withValues(alpha: 0.9)
                  : AppColors.amber600.withValues(alpha: 0.9),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 5),
              margin: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
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
            onPressed: () => ref.read(watchlistProvider.notifier).refreshQuotes(),
          ),
          const NotificationBellButton(),
        ],
      ),
      floatingActionButton: FloatingActionButton.small(
        onPressed: () => _showAddDialog(context),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: watchlistState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : watchlistState.items.isEmpty
              ? _buildEmptyState()
              : Builder(
                  builder: (context) {
                    final useGrid = ResponsiveGrid.shouldUseGrid(context);

                    if (useGrid) {
                      final itemW = ResponsiveGrid.gridItemWidth(context);
                      return RefreshIndicator(
                        onRefresh: () => ref.read(watchlistProvider.notifier).refreshQuotes(),
                        child: ListView(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          children: [
                            Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: ResponsiveGrid.horizontalPadding,
                              ),
                              child: Wrap(
                                spacing: ResponsiveGrid.spacing,
                                runSpacing: ResponsiveGrid.runSpacing,
                                children: List.generate(watchlistState.items.length, (index) {
                                  final item = watchlistState.items[index];
                                  return SizedBox(
                                    width: itemW,
                                    child: WatchlistTile(
                                      key: ValueKey(item.ticker),
                                      item: item,
                                      index: index,
                                      inGrid: true,
                                      onTap: () => _onItemTap(item),
                                      onRemove: () => _onRemove(item.ticker),
                                      onAlertTap: (currentPrice) =>
                                          _showAlertSettings(item, currentPrice),
                                    ),
                                  );
                                }),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return RefreshIndicator(
                      onRefresh: () => ref.read(watchlistProvider.notifier).refreshQuotes(),
                      child: ReorderableListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        itemCount: watchlistState.items.length,
                        buildDefaultDragHandles: false,
                        onReorder: (oldIndex, newIndex) {
                          ref.read(watchlistProvider.notifier).reorder(oldIndex, newIndex);
                        },
                        proxyDecorator: (child, index, animation) {
                          return AnimatedBuilder(
                            animation: animation,
                            builder: (context, child) {
                              final elevation = Tween<double>(begin: 0, end: 6).animate(animation).value;
                              return Material(
                                elevation: elevation,
                                color: context.appSurface,
                                shadowColor: context.isDarkMode
                                    ? Colors.white.withValues(alpha: 0.2)
                                    : Colors.black45,
                                borderRadius: BorderRadius.circular(8),
                                child: child,
                              );
                            },
                            child: child,
                          );
                        },
                        itemBuilder: (context, index) {
                          final item = watchlistState.items[index];
                          return WatchlistTile(
                            key: ValueKey(item.ticker),
                            item: item,
                            index: index,
                            onTap: () => _onItemTap(item),
                            onRemove: () => _onRemove(item.ticker),
                            onAlertTap: (currentPrice) =>
                                _showAlertSettings(item, currentPrice),
                          );
                        },
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bookmark_border_rounded,
            size: 64,
            color: context.appBorder,
          ),
          const SizedBox(height: 16),
          Text(
            '관심종목이 없습니다',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: context.appTextSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '오른쪽 하단 + 버튼을 눌러\n관심종목을 추가해보세요',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: context.appTextHint,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showAddDialog(context),
            icon: const Icon(Icons.add),
            label: const Text('관심종목 추가'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.appSurface,
      builder: (context) => const AddWatchlistSheet(),
    );
  }

  void _onItemTap(WatchlistItem item) {
    context.go(
      '/index/${Uri.encodeComponent(item.ticker)}?from=watchlist',
    );
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

  Future<void> _showAlertSettings(WatchlistItem item, double? currentPrice) async {
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
