import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/models/cycle.dart';
import '../presentation/screens/home/home_screen.dart';
import '../presentation/screens/stocks/cycle_detail_screen.dart';
import '../presentation/screens/stocks/cycle_setup_screen.dart';
import '../presentation/screens/stocks/search_screen.dart';
import '../presentation/screens/stocks/stocks_screen.dart';
import '../presentation/screens/holdings/archived_holding_detail_screen.dart';
import '../presentation/screens/holdings/holding_detail_screen.dart';
import '../presentation/screens/holdings/holding_setup_screen.dart';
import '../presentation/screens/history/history_screen.dart';
import '../presentation/screens/memo/memo_screen.dart';
import '../presentation/screens/settings/settings_screen.dart';
import '../presentation/screens/index/index_detail_screen.dart';
import '../presentation/screens/watchlist/watchlist_screen.dart';
import '../presentation/widgets/common/main_shell.dart';
import '../presentation/widgets/stocks/popular_etf_list.dart';
import '../core/utils/symbol_name_resolver.dart';

/// 모달(BottomSheet, Dialog) 열림 상태를 추적하는 NavigatorObserver
///
/// 브라우저 뒤로가기 시 모달이 열려있으면 모달만 닫고 페이지 이동을 방지하기 위해 사용.
class _ModalObserver extends NavigatorObserver {
  int openCount = 0;

  @override
  void didPush(Route route, Route? previousRoute) {
    if (route is PopupRoute) openCount++;
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    if (route is PopupRoute && openCount > 0) openCount--;
  }

  @override
  void didRemove(Route route, Route? previousRoute) {
    if (route is PopupRoute && openCount > 0) openCount--;
  }
}

/// 앱 라우터 설정
class AppRouter {
  AppRouter._();

  static final _rootNavigatorKey = GlobalKey<NavigatorState>();

  /// Root navigator key (모달 닫기용)
  static GlobalKey<NavigatorState> get rootNavigatorKey => _rootNavigatorKey;
  static final _shellNavigatorKey = GlobalKey<NavigatorState>();

  /// Shell navigator key (모달 닫기용)
  static GlobalKey<NavigatorState> get shellNavigatorKey => _shellNavigatorKey;

  /// 모달 추적 옵저버
  static final _modalObserver = _ModalObserver();

  /// 현재 라우트 경로 (모달 닫기 시 복귀용)
  static String _currentLocation = '/';

  /// 라우트 경로 상수
  static const String home = '/';
  static const String watchlist = '/watchlist';
  static const String stocks = '/stocks';
  static const String stocksSearch = '/stocks/search';
  static const String stocksSetup = '/stocks/setup';
  static const String cycleDetail = '/stocks/detail/:cycleId';
  static const String holdingsSetup = '/holdings/setup/:ticker';
  static const String holdingsDetail = '/holdings/:holdingId';
  static const String holdingsArchived = '/holdings/:holdingId/archived';
  static const String indexDetail = '/index/:symbol';
  static const String history = '/history';
  static const String memo = '/memo';
  static const String settings = '/settings';

  /// GoRouter 인스턴스
  static final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    observers: [_modalObserver],
    initialLocation: home,
    redirect: (context, state) {
      final newPath = state.matchedLocation;

      // 모달이 열려있는 상태에서 뒤로가기 → 모달만 닫고 현재 페이지 유지
      if (_modalObserver.openCount > 0 && newPath != _currentLocation) {
        final rootNav = _rootNavigatorKey.currentState;
        if (rootNav != null && rootNav.canPop()) {
          rootNav.pop();
        }
        return _currentLocation;
      }

      _currentLocation = newPath;
      return null;
    },
    routes: [
      // 하단 네비게이션을 포함하는 쉘 라우트
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          // 메인 탭 라우트 (NoTransitionPage)
          GoRoute(
            path: home,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: HomeScreen(),
            ),
          ),
          GoRoute(
            path: watchlist,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: WatchlistScreen(),
            ),
          ),
          GoRoute(
            path: stocks,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: StocksScreen(),
            ),
          ),
          GoRoute(
            path: history,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: HistoryScreen(),
            ),
          ),
          GoRoute(
            path: memo,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: MemoScreen(),
            ),
          ),
          GoRoute(
            path: settings,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: SettingsScreen(),
            ),
          ),

          // 종목 관리 상세 라우트
          GoRoute(
            path: stocksSearch,
            builder: (context, state) {
              final forHolding = state.uri.queryParameters['forHolding'] == 'true';
              return SearchScreen(forHolding: forHolding);
            },
          ),
          GoRoute(
            path: stocksSetup,
            builder: (context, state) {
              final strategy = state.uri.queryParameters['strategy'];
              return CycleSetupScreen(
                initialStrategy: strategy == 'infiniteBuy'
                    ? StrategyType.infiniteBuy
                    : StrategyType.alphaCycleV3,
              );
            },
          ),
          GoRoute(
            path: cycleDetail,
            builder: (context, state) {
              final cycleId = state.pathParameters['cycleId']!;
              return CycleDetailScreen(cycleId: cycleId);
            },
          ),
          // 보유 관련 라우트
          GoRoute(
            path: holdingsSetup,
            builder: (context, state) {
              final ticker = state.pathParameters['ticker']!;
              final etfInfo = state.extra as PopularEtf?;
              return HoldingSetupScreen(ticker: ticker, etfInfo: etfInfo);
            },
          ),
          GoRoute(
            path: holdingsArchived,
            builder: (context, state) {
              final holdingId = state.pathParameters['holdingId']!;
              return ArchivedHoldingDetailScreen(holdingId: holdingId);
            },
          ),
          GoRoute(
            path: holdingsDetail,
            builder: (context, state) {
              final holdingId = state.pathParameters['holdingId']!;
              return HoldingDetailScreen(holdingId: holdingId);
            },
          ),

          // 지수 상세 라우트
          GoRoute(
            path: indexDetail,
            builder: (context, state) {
              final symbol = state.pathParameters['symbol']!;
              final name = SymbolNameResolver.resolve(symbol);
              return IndexDetailScreen(symbol: symbol, name: name);
            },
          ),
        ],
      ),
    ],
  );
}
