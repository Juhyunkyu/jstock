import 'dart:js_interop';

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
import '../presentation/screens/memo/memo_create_edit_screen.dart';
import '../presentation/screens/memo/memo_detail_screen.dart';
import '../presentation/screens/settings/settings_screen.dart';
import '../presentation/screens/index/index_detail_screen.dart';
import '../presentation/screens/watchlist/watchlist_screen.dart';
import '../presentation/widgets/common/main_shell.dart';
import '../presentation/widgets/stocks/popular_etf_list.dart';
import '../core/utils/symbol_name_resolver.dart';

/// JS interop: window._flutterModalCount (모달 열림 수)
@JS('_flutterModalCount')
external set _jsModalCount(JSNumber value);

/// JS interop: window._closeFlutterModal (모달 닫기 콜백)
@JS('_closeFlutterModal')
external set _jsCloseModal(JSFunction? value);

/// 모달(BottomSheet, Dialog) 열림 상태를 추적하는 NavigatorObserver
///
/// 브라우저 뒤로가기 시 모달이 열려있으면 모달만 닫고 페이지 이동을 방지하기 위해 사용.
/// index.html의 popstate 핸들러와 연동:
/// - window._flutterModalCount: 열린 모달 수
/// - window._closeFlutterModal: 최상위 모달 닫기 콜백
class _ModalObserver extends NavigatorObserver {
  int openCount = 0;

  void _syncToJs() {
    _jsModalCount = openCount.toJS;
    if (openCount > 0) {
      _jsCloseModal = _closeTopModal.toJS;
    } else {
      _jsCloseModal = null;
    }
  }

  @override
  void didPush(Route route, Route? previousRoute) {
    if (route is PopupRoute) {
      openCount++;
      _syncToJs();
    }
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    if (route is PopupRoute && openCount > 0) {
      openCount--;
      _syncToJs();
    }
  }

  @override
  void didRemove(Route route, Route? previousRoute) {
    if (route is PopupRoute && openCount > 0) {
      openCount--;
      _syncToJs();
    }
  }
}

/// 최상위 모달 닫기 (JS popstate 핸들러에서 호출)
void _closeTopModal() {
  final rootNav = AppRouter._rootNavigatorKey.currentState;
  if (rootNav != null && rootNav.canPop()) {
    rootNav.pop();
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
  static const String memoCreate = '/memo/create';
  static const String memoDetail = '/memo/detail/:memoId';
  static const String memoEdit = '/memo/edit/:memoId';
  static const String settings = '/settings';

  /// GoRouter 인스턴스
  static final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    observers: [_modalObserver],
    initialLocation: home,
    // 모달 뒤로가기는 index.html의 popstate 핸들러에서 처리
    // (go_router redirect보다 먼저 실행, stopImmediatePropagation으로 차단)
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
            path: memoCreate,
            builder: (context, state) => const MemoCreateEditScreen(),
          ),
          GoRoute(
            path: memoDetail,
            builder: (context, state) {
              final memoId = state.pathParameters['memoId']!;
              return MemoDetailScreen(memoId: memoId);
            },
          ),
          GoRoute(
            path: memoEdit,
            builder: (context, state) {
              final memoId = state.pathParameters['memoId']!;
              return MemoCreateEditScreen(memoId: memoId);
            },
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
