import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../presentation/screens/home/home_screen.dart';
import '../presentation/screens/stocks/stocks_screen.dart';
import '../presentation/screens/stocks/search_screen.dart';
import '../presentation/screens/stocks/cycle_setup_screen.dart';
import '../presentation/screens/stocks/cycle_detail_screen.dart';
import '../presentation/screens/holdings/archived_holding_detail_screen.dart';
import '../presentation/screens/holdings/holding_detail_screen.dart';
import '../presentation/screens/holdings/holding_setup_screen.dart';
import '../presentation/screens/history/history_screen.dart';
import '../presentation/screens/settings/settings_screen.dart';
import '../presentation/screens/index/index_detail_screen.dart';
import '../presentation/screens/watchlist/watchlist_screen.dart';
import '../presentation/widgets/common/main_shell.dart';
import '../presentation/widgets/stocks/popular_etf_list.dart';
import '../core/utils/symbol_name_resolver.dart';

/// 앱 라우터 설정
class AppRouter {
  AppRouter._();

  static final _rootNavigatorKey = GlobalKey<NavigatorState>();
  static final _shellNavigatorKey = GlobalKey<NavigatorState>();

  /// 라우트 경로 상수
  static const String home = '/';
  static const String watchlist = '/watchlist';
  static const String stocks = '/stocks';
  static const String stocksSearch = '/stocks/search';
  static const String stocksSetup = '/stocks/setup/:ticker';
  static const String stocksDetail = '/stocks/:cycleId';
  static const String holdingsSetup = '/holdings/setup/:ticker';
  static const String holdingsDetail = '/holdings/:holdingId';
  static const String holdingsArchived = '/holdings/:holdingId/archived';
  static const String indexDetail = '/index/:symbol';
  static const String history = '/history';
  static const String settings = '/settings';

  /// GoRouter 인스턴스
  static final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: home,
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
              final ticker = state.pathParameters['ticker']!;
              final etfInfo = state.extra as PopularEtf?;
              return CycleSetupScreen(ticker: ticker, etfInfo: etfInfo);
            },
          ),
          GoRoute(
            path: stocksDetail,
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
