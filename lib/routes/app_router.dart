import 'dart:js_interop';
import 'dart:js_interop_unsafe';

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

/// 모달(BottomSheet, Dialog) 열림 상태를 추적하는 NavigatorObserver
///
/// 브라우저 뒤로가기 시 모달이 열려있으면 모달만 닫고 페이지 이동을 방지하기 위해 사용.
/// index.html의 popstate 핸들러와 연동.
///
/// 모달 열림 → history.pushState (모달 전용 엔트리 추가)
/// 뒤로가기 → popstate가 모달 엔트리를 자연 소비 → JS 핸들러가 모달 닫기
/// 수동 닫기 → history.back()으로 모달 엔트리 제거 + suppress 플래그
class _ModalObserver extends NavigatorObserver {
  int openCount = 0;
  bool _closedByBackButton = false;

  void _syncToJs() {
    try {
      globalContext['_flutterModalCount'] = openCount.toJS;
      if (openCount > 0) {
        globalContext['_closeFlutterModal'] = _closeTopModal.toJS;
      } else {
        globalContext['_closeFlutterModal'] = null;
      }
    } catch (e) {
      debugPrint('[ModalObserver] JS sync error: $e');
    }
  }

  /// 모달 열림 → 히스토리 엔트리 추가
  void _pushModalEntry() {
    try {
      _callHistoryPushState();
    } catch (e) {
      debugPrint('[ModalObserver] pushState error: $e');
    }
  }

  /// 모달 수동 닫힘 → 히스토리 엔트리 제거 (suppress 플래그로 popstate 무시)
  void _removeModalEntry() {
    try {
      globalContext['_suppressModalPopstate'] = true.toJS;
      _callHistoryBack();
    } catch (e) {
      debugPrint('[ModalObserver] back error: $e');
    }
  }

  @override
  void didPush(Route route, Route? previousRoute) {
    if (route is PopupRoute) {
      openCount++;
      _syncToJs();
      _pushModalEntry();
    }
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    if (route is PopupRoute && openCount > 0) {
      final wasByBack = _closedByBackButton;
      _closedByBackButton = false;
      openCount--;
      _syncToJs();
      // 뒤로가기로 닫힌 경우 → 엔트리가 이미 소비됨, 제거 불필요
      // 수동으로 닫힌 경우 → 모달 엔트리를 제거해야 함
      if (!wasByBack) {
        _removeModalEntry();
      }
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

/// JS interop: history.pushState(state, '', url)
@JS('history.pushState')
external void _jsPushState(JSAny? state, JSString title, JSString url);

/// JS interop: history.back()
@JS('history.back')
external void _jsHistoryBack();

/// JS interop: location.href
@JS('location.href')
external JSString get _jsLocationHref;

void _callHistoryPushState() {
  _jsPushState(null, ''.toJS, _jsLocationHref);
}

void _callHistoryBack() {
  _jsHistoryBack();
}

/// 최상위 모달 닫기 (JS popstate 핸들러에서 호출)
void _closeTopModal() {
  final observer = AppRouter._modalObserver;
  observer._closedByBackButton = true;
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

  /// push/pop이 브라우저 히스토리에 반영되도록 설정
  /// go_router v14+에서 기본값이 false → push()가 히스토리에 안 들어감
  /// → 물리 뒤로가기 시 detail 페이지를 건너뛰고 탭/종료로 점프하는 버그 발생
  static void init() {
    GoRouter.optionURLReflectsImperativeAPIs = true;
  }

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
              final forDetail = state.uri.queryParameters['forDetail'] == 'true';
              return SearchScreen(forHolding: forHolding, forDetail: forDetail);
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
