import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/notification_record.dart';
import '../../../data/services/notification/web_notification_service.dart';
import '../../../routes/app_router.dart';
import '../../providers/fear_greed_providers.dart';
import '../../providers/notification_history_provider.dart';
import '../../providers/watchlist_alert_provider.dart';
import '../../providers/watchlist_providers.dart';
import 'app_title_logo.dart';

/// 메인 쉘 위젯
///
/// 하단 네비게이션 바를 포함하는 앱의 기본 레이아웃입니다.
/// 화면 크기에 따라 반응형 레이아웃을 제공합니다:
/// - 모바일 (<768px): 하단 네비게이션 바
/// - 태블릿 (768-1199px): 하단 네비게이션 + 중앙 정렬 콘텐츠
/// - 데스크톱 (≥1200px): 사이드 네비게이션 레일 + 중앙 정렬 콘텐츠
class MainShell extends ConsumerStatefulWidget {
  final Widget child;

  const MainShell({
    super.key,
    required this.child,
  });

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // 전역: 브라우저 알림 권한 요청
      WebNotificationService.requestPermission();
      // 전역: 알림 내역 로드 (watchlist보다 먼저 — Hive 초기화 우선)
      ref.read(notificationHistoryProvider.notifier).load();
      // 전역: 관심종목 로드 + WebSocket 구독
      ref.read(watchlistProvider.notifier).load();

      // 알림 감시: ref.listen()으로 side effects를 빌드 밖에서 안전하게 실행
      ref.listenManual(watchlistAlertMonitorProvider, (prev, next) {
        if (next.isEmpty) return;
        _handleWatchlistAlerts(next);
      });
      ref.listenManual(fearGreedAlertMonitorProvider, (prev, next) {
        if (next == null) return;
        _handleFearGreedAlert(next);
      });
    });
  }

  /// 현재 라우트가 메인 탭(홈, 관심종목, My, 거래내역, 설정)인지 확인
  bool _isMainTabRoute(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    return location == '/' ||
        location == '/watchlist' ||
        location == '/stocks' ||
        location == '/history' ||
        location == '/settings';
  }

  /// 관심종목 알림 처리 (빌드 밖에서 안전하게 실행)
  void _handleWatchlistAlerts(List<AlertNotification> alerts) {
    try {
      final notifier = ref.read(notificationHistoryProvider.notifier);
      for (final alert in alerts) {
        WebNotificationService.show(title: alert.title, body: alert.body);
        notifier.addFromAlert(alert);
      }
    } catch (e) {
      // 알림 처리 실패 시 앱 크래시 방지
      debugPrint('[AlertError] Watchlist alert failed: $e');
    }
  }

  /// 공포탐욕지수 알림 처리 (빌드 밖에서 안전하게 실행)
  void _handleFearGreedAlert(FearGreedAlertResult alert) {
    try {
      WebNotificationService.show(title: alert.title, body: alert.body);
      final record = NotificationRecord(
        id: 'fg_${DateTime.now().millisecondsSinceEpoch}',
        ticker: 'F&G',
        title: alert.title,
        body: alert.body,
        type: 'fear_greed',
        triggeredAt: DateTime.now(),
      );
      ref.read(notificationHistoryProvider.notifier).addRecord(record);
    } catch (e) {
      debugPrint('[AlertError] Fear & Greed alert failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isMainTab = _isMainTabRoute(context);

        // Desktop (>=1200px): Extended NavigationRail + 좌측 정렬 콘텐츠
        if (width >= 1200) {
          const sidebarWidth = 220.0;
          final available = width - sidebarWidth;
          final desktopMaxWidth = (available * 0.95).clamp(0.0, 1600.0);

          return Scaffold(
            backgroundColor: context.appBackground,
            body: Row(
              children: [
                _buildNavigationRail(context),
                Expanded(
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: desktopMaxWidth),
                      child: widget.child,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        // Tablet (>=768px): BottomNav only for main tabs
        // 비율 기반 maxWidth: 화면 폭의 95%, 최대 1100px
        if (width >= 768) {
          final tabletMaxWidth = (width * 0.95).clamp(0.0, 1100.0);
          return Scaffold(
            backgroundColor: context.appBackground,
            body: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: tabletMaxWidth),
                child: widget.child,
              ),
            ),
            bottomNavigationBar: isMainTab ? const _BottomNavBar() : null,
          );
        }

        // Mobile (<768px): BottomNav only for main tabs
        return Scaffold(
          body: widget.child,
          bottomNavigationBar: isMainTab ? const _BottomNavBar() : null,
        );
      },
    );
  }

  Widget _buildNavigationRail(BuildContext context) {
    final selectedIndex = _getSelectedIndex(context);

    return Container(
      decoration: BoxDecoration(
        color: context.appSurface,
        border: Border(
          right: BorderSide(
            color: context.appDivider,
            width: 1,
          ),
        ),
      ),
      child: NavigationRail(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) => _navigateTo(index, context),
        extended: true,
        minExtendedWidth: 220,
        backgroundColor: Colors.transparent,
        indicatorColor:
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
        leading: const Padding(
          padding: EdgeInsets.only(top: 8, bottom: 24, left: 16),
          child: AppTitleLogo(fontSize: 18),
        ),
        destinations: const [
          NavigationRailDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: Text('홈'),
          ),
          NavigationRailDestination(
            icon: Icon(Icons.bookmark_border_outlined),
            selectedIcon: Icon(Icons.bookmark_rounded),
            label: Text('관심종목'),
          ),
          NavigationRailDestination(
            icon: Icon(Icons.trending_up_outlined),
            selectedIcon: Icon(Icons.trending_up_rounded),
            label: Text('My'),
          ),
          NavigationRailDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history_rounded),
            label: Text('거래내역'),
          ),
          NavigationRailDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: Text('설정'),
          ),
        ],
      ),
    );
  }
}

int _getSelectedIndex(BuildContext context) {
  final location = GoRouterState.of(context).uri.path;
  if (location.startsWith(AppRouter.watchlist)) return 1;
  if (location.startsWith('/stocks')) return 2;
  if (location.startsWith('/holdings')) return 2;
  if (location.startsWith(AppRouter.history)) return 3;
  if (location.startsWith(AppRouter.settings)) return 4;
  // /index/* detail pages highlight Home tab
  return 0;
}

void _navigateTo(int index, BuildContext context) {
  switch (index) {
    case 0:
      context.go(AppRouter.home);
      break;
    case 1:
      context.go(AppRouter.watchlist);
      break;
    case 2:
      context.go(AppRouter.stocks);
      break;
    case 3:
      context.go(AppRouter.history);
      break;
    case 4:
      context.go(AppRouter.settings);
      break;
  }
}

class _BottomNavBar extends StatelessWidget {
  const _BottomNavBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.appSurface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: NavigationBar(
          height: 65,
          elevation: 0,
          backgroundColor: Colors.transparent,
          indicatorColor:
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
          selectedIndex: _getSelectedIndex(context),
          onDestinationSelected: (index) => _navigateTo(index, context),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: '홈',
            ),
            NavigationDestination(
              icon: Icon(Icons.bookmark_border_outlined),
              selectedIcon: Icon(Icons.bookmark_rounded),
              label: '관심종목',
            ),
            NavigationDestination(
              icon: Icon(Icons.trending_up_outlined),
              selectedIcon: Icon(Icons.trending_up_rounded),
              label: 'My',
            ),
            NavigationDestination(
              icon: Icon(Icons.history_outlined),
              selectedIcon: Icon(Icons.history_rounded),
              label: '거래내역',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings_rounded),
              label: '설정',
            ),
          ],
        ),
      ),
    );
  }
}
