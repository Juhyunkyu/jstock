import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/notification_record.dart';
import '../../../data/services/notification/web_notification_service.dart';
import '../../../data/services/pwa/pwa_update_service.dart';
import '../../../routes/app_router.dart';
import '../../providers/providers.dart';
import '../../providers/fear_greed_providers.dart';
import '../../providers/notification_history_provider.dart';
import 'app_title_logo.dart';
import 'offline_banner.dart';
import 'update_banner.dart';

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
  bool _updateAvailable = false;

  @override
  void initState() {
    super.initState();
    // PWA 업데이트 감지: 5초마다 체크 (JS에서 설정한 플래그 읽기)
    _checkForPWAUpdate();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      // 전역: 브라우저 알림 권한 요청 (비동기, 대화상자 응답을 기다리지 않음)
      WebNotificationService.requestPermission();

      // 전역 초기화: 알림 저장소 + 관심종목을 병렬 로드 후 완료 대기
      // → 알림 저장소 미초기화 상태에서 알림 트리거 시 저장 실패 방지
      await Future.wait([
        ref.read(notificationHistoryProvider.notifier).load(),
        ref.read(watchlistProvider.notifier).load(),
        ref.read(watchlistGroupProvider.notifier).load(),
        ref.read(recentViewProvider.notifier).load(),
      ]);

      if (!mounted) return;

      // 초기화 완료 후 알림 감시 등록
      // fireImmediately: true → 이미 충족된 조건 즉시 처리 (초기화 중 놓친 알림 복구)
      ref.listenManual(watchlistAlertMonitorProvider, (prev, next) {
        if (next.isEmpty) return;
        _handleWatchlistAlerts(next);
      }, fireImmediately: true);
      ref.listenManual(fearGreedAlertMonitorProvider, (prev, next) {
        if (next == null) return;
        _handleFearGreedAlert(next);
      }, fireImmediately: true);
    });
  }

  /// PWA 업데이트 플래그를 주기적으로 확인
  void _checkForPWAUpdate() {
    Future.delayed(const Duration(seconds: 5), () {
      if (!mounted) return;
      if (PWAUpdateService.checkForUpdate() && !_updateAvailable) {
        setState(() => _updateAvailable = true);
        return; // 업데이트 발견 시 더 이상 체크하지 않음
      }
      _checkForPWAUpdate(); // 재귀 호출로 반복 체크
    });
  }


  /// 관심종목 알림 처리 (빌드 밖에서 안전하게 실행)
  void _handleWatchlistAlerts(List<AlertNotification> alerts) {
    try {
      final muted = ref.read(settingsProvider).notificationMuted;
      final notifier = ref.read(notificationHistoryProvider.notifier);
      for (final alert in alerts) {
        // 벨 배지 먼저 저장 (절대 실패하면 안 됨)
        notifier.addFromAlert(alert);
        // 브라우저 알림은 마스터 스위치가 켜져있을 때만
        if (!muted) {
          try {
            WebNotificationService.show(title: alert.title, body: alert.body);
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('[AlertError] Watchlist alert failed: $e');
    }
  }

  /// 공포탐욕지수 알림 처리 (빌드 밖에서 안전하게 실행)
  void _handleFearGreedAlert(FearGreedAlertResult alert) {
    try {
      // 벨 배지 먼저 저장
      final record = NotificationRecord(
        id: 'fg_${DateTime.now().millisecondsSinceEpoch}',
        ticker: 'F&G',
        title: alert.title,
        body: alert.body,
        type: 'fear_greed',
        triggeredAt: DateTime.now(),
      );
      ref.read(notificationHistoryProvider.notifier).addRecord(record);
      // 브라우저 알림은 마스터 스위치가 켜져있을 때만
      final muted = ref.read(settingsProvider).notificationMuted;
      if (!muted) {
        try {
          WebNotificationService.show(title: alert.title, body: alert.body);
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[AlertError] Fear & Greed alert failed: $e');
    }
  }

  /// 업데이트 배너 + 오프라인 배너 + 콘텐츠를 Column으로 합성
  Widget _wrapWithBanner(Widget child) {
    return Column(
      children: [
        if (_updateAvailable) const UpdateBanner(),
        const OfflineBanner(),
        Expanded(child: child),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTopLevel = _isTopLevelTab(context);
    final selectedIndex = _getSelectedIndex(context);
    // "Back to home first" 패턴:
    // - 홈이 아닌 최상위 탭 → 뒤로가기 시 홈으로 이동 (앱 종료 방지)
    // - 홈 탭 또는 서브페이지 → 기본 뒤로가기 동작 허용
    final shouldInterceptBack = isTopLevel && selectedIndex != 0;

    return PopScope(
      canPop: !shouldInterceptBack,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && shouldInterceptBack) {
          Router.neglect(context, () => context.go(AppRouter.home));
        }
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
        final width = constraints.maxWidth;

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
                  child: _wrapWithBanner(
                    Align(
                      alignment: Alignment.topLeft,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: desktopMaxWidth),
                        child: widget.child,
                      ),
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
            body: _wrapWithBanner(
              Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: tabletMaxWidth),
                  child: widget.child,
                ),
              ),
            ),
            bottomNavigationBar: const _BottomNavBar(),
          );
        }

        // Mobile (<768px): BottomNav only for main tabs
        return Scaffold(
          body: _wrapWithBanner(widget.child),
          bottomNavigationBar: const _BottomNavBar(),
        );
      },
      ),
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
          padding: EdgeInsets.only(top: 12, bottom: 28),
          child: Center(child: AppTitleLogo(fontSize: 22)),
        ),
        destinations: const [
          NavigationRailDestination(
            icon: Icon(Icons.home_outlined, size: 26),
            selectedIcon: Icon(Icons.home_rounded, size: 26),
            label: Text('홈', style: TextStyle(fontSize: 15)),
          ),
          NavigationRailDestination(
            icon: Icon(Icons.bookmark_border_outlined, size: 26),
            selectedIcon: Icon(Icons.bookmark_rounded, size: 26),
            label: Text('관심종목', style: TextStyle(fontSize: 15)),
          ),
          NavigationRailDestination(
            icon: Icon(Icons.trending_up_outlined, size: 26),
            selectedIcon: Icon(Icons.trending_up_rounded, size: 26),
            label: Text('My', style: TextStyle(fontSize: 15)),
          ),
          NavigationRailDestination(
            icon: Icon(Icons.history_outlined, size: 26),
            selectedIcon: Icon(Icons.history_rounded, size: 26),
            label: Text('거래내역', style: TextStyle(fontSize: 15)),
          ),
          NavigationRailDestination(
            icon: Icon(Icons.edit_note_outlined, size: 26),
            selectedIcon: Icon(Icons.edit_note_rounded, size: 26),
            label: Text('메모', style: TextStyle(fontSize: 15)),
          ),
          NavigationRailDestination(
            icon: Icon(Icons.settings_outlined, size: 26),
            selectedIcon: Icon(Icons.settings_rounded, size: 26),
            label: Text('설정', style: TextStyle(fontSize: 15)),
          ),
        ],
      ),
    );
  }
}

/// 6개 메인 탭의 최상위 경로 (서브페이지 제외)
const _topLevelTabRoutes = {
  AppRouter.home,       // '/'
  AppRouter.watchlist,  // '/watchlist'
  AppRouter.stocks,     // '/stocks'
  AppRouter.history,    // '/history'
  AppRouter.memo,       // '/memo'
  AppRouter.settings,   // '/settings'
};

/// 현재 경로가 6개 메인 탭 중 하나인지 (서브페이지가 아닌 정확한 탭 경로)
bool _isTopLevelTab(BuildContext context) {
  final location = GoRouterState.of(context).uri.path;
  return _topLevelTabRoutes.contains(location);
}

int _getSelectedIndex(BuildContext context) {
  final location = GoRouterState.of(context).uri.path;
  if (location.startsWith(AppRouter.watchlist)) return 1;
  if (location.startsWith('/stocks')) return 2;
  if (location.startsWith('/holdings')) return 2;
  if (location.startsWith(AppRouter.history)) return 3;
  if (location.startsWith(AppRouter.memo)) return 4;
  if (location.startsWith(AppRouter.settings)) return 5;
  // /index/* detail pages highlight Home tab
  return 0;
}

void _navigateTo(int index, BuildContext context) {
  // 열린 모달(바텀시트, 다이얼로그 등)을 먼저 닫기
  for (final key in [AppRouter.shellNavigatorKey, AppRouter.rootNavigatorKey]) {
    final nav = key.currentState;
    if (nav != null) {
      while (nav.canPop()) {
        nav.pop();
      }
    }
  }

  // Router.neglect: 탭 전환 시 브라우저 히스토리에 쌓지 않음
  // → 뒤로가기 시 방문한 탭을 역순으로 돌아가지 않음 (업계 표준)
  final routes = [
    AppRouter.home,
    AppRouter.watchlist,
    AppRouter.stocks,
    AppRouter.history,
    AppRouter.memo,
    AppRouter.settings,
  ];
  if (index >= 0 && index < routes.length) {
    Router.neglect(context, () => context.go(routes[index]));
  }
}

class _BottomNavBar extends StatelessWidget {
  const _BottomNavBar();

  static const _items = [
    (icon: Icons.home_outlined, selectedIcon: Icons.home_rounded, label: '홈'),
    (icon: Icons.bookmark_border_outlined, selectedIcon: Icons.bookmark_rounded, label: '관심'),
    (icon: Icons.trending_up_outlined, selectedIcon: Icons.trending_up_rounded, label: 'My'),
    (icon: Icons.history_outlined, selectedIcon: Icons.history_rounded, label: '거래내역'),
    (icon: Icons.edit_note_outlined, selectedIcon: Icons.edit_note_rounded, label: '메모'),
    (icon: Icons.settings_outlined, selectedIcon: Icons.settings_rounded, label: '설정'),
  ];

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _getSelectedIndex(context);

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
        child: SizedBox(
          height: 60,
          child: Row(
            children: List.generate(_items.length, (index) {
              final item = _items[index];
              final isSelected = index == selectedIndex;
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _navigateTo(index, context),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isSelected ? item.selectedIcon : item.icon,
                        size: 22,
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : context.appTextHint,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : context.appTextHint,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
