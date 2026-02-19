import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/watchlist_item.dart';
import '../../data/repositories/watchlist_repository.dart';
import '../../data/services/api/finnhub_service.dart';
import 'api_providers.dart';

/// 관심종목 저장소 Provider
final watchlistRepositoryProvider = Provider<WatchlistRepository>((ref) {
  return WatchlistRepository();
});

/// 관심종목 목록 상태 (시세는 stockQuoteProvider에서 관리)
class WatchlistState {
  final List<WatchlistItem> items;
  final bool isLoading;
  final String? error;

  const WatchlistState({
    this.items = const [],
    this.isLoading = false,
    this.error,
  });

  /// 티커 목록 반환 (WebSocket 구독용)
  List<String> get tickers => items.map((e) => e.ticker).toList();

  WatchlistState copyWith({
    List<WatchlistItem>? items,
    bool? isLoading,
    String? error,
  }) {
    return WatchlistState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// 관심종목 상태 관리 Notifier
///
/// 시세 데이터는 stockQuoteProvider에서 관리하므로
/// 이 Notifier는 관심종목 목록(Hive 저장소)만 관리합니다.
class WatchlistNotifier extends StateNotifier<WatchlistState> {
  final WatchlistRepository _repository;
  final Ref _ref;

  WatchlistNotifier(this._repository, this._ref)
      : super(const WatchlistState());

  /// 초기 로드 (repository 초기화 포함)
  Future<void> load() async {
    if (!mounted) return;
    state = state.copyWith(isLoading: true);

    try {
      await _repository.init();
      final items = _repository.getAll();
      if (!mounted) return;
      state = state.copyWith(items: items, isLoading: false);

      // 시세 로드 및 WebSocket 구독 (stockQuoteProvider 사용)
      _subscribeToQuotes();

      // exchange가 "US"인 종목 거래소 정보 갱신
      _refreshExchanges(items);
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        error: '관심종목 로드 실패: ${e.toString()}',
      );
    }
  }

  /// exchange가 "US"인 종목들의 거래소 정보를 백그라운드 갱신
  Future<void> _refreshExchanges(List<WatchlistItem> items) async {
    final needsUpdate = items.where((i) => i.exchange == 'US' || i.exchange.isEmpty).toList();
    if (needsUpdate.isEmpty) return;

    final finnhub = _ref.read(finnhubServiceProvider);
    bool updated = false;
    for (final item in needsUpdate) {
      try {
        final exchange = await finnhub.getExchange(item.ticker);
        if (exchange != 'US' && exchange != item.exchange) {
          item.exchange = exchange;
          await item.save();
          updated = true;
        }
      } catch (_) {}
    }
    if (updated && mounted) {
      final refreshed = _repository.getAll();
      state = state.copyWith(items: refreshed);
    }
  }

  /// 시세 로드 및 WebSocket 구독
  void _subscribeToQuotes() {
    if (state.tickers.isEmpty) return;

    // stockQuoteProvider를 통해 시세 조회 및 WebSocket 자동 구독
    _ref.read(stockQuoteProvider.notifier).fetchQuotes(state.tickers);
  }

  /// WebSocket 구독 해제 (화면 이탈 시)
  void unsubscribeQuotes() {
    if (state.tickers.isEmpty) return;
    final wsService = _ref.read(finnhubWebSocketProvider);
    for (final ticker in state.tickers) {
      wsService.unsubscribe(ticker);
    }
  }

  /// 시세 새로고침 (캐시 무효화 후 재조회)
  Future<void> refreshQuotes() async {
    if (state.tickers.isEmpty) return;

    await _ref.read(stockQuoteProvider.notifier).refreshQuotes(state.tickers);
  }

  /// 관심종목 추가
  Future<void> add(WatchlistItem item) async {
    await _repository.add(item);
    final items = _repository.getAll();
    if (!mounted) return;
    state = state.copyWith(items: items);

    // 새 종목 시세 조회 및 WebSocket 구독
    _ref.read(stockQuoteProvider.notifier).fetchQuote(item.ticker);
  }

  /// 관심종목 삭제
  Future<void> remove(String ticker) async {
    await _repository.remove(ticker);
    final items = _repository.getAll();
    state = state.copyWith(items: items);

    // WebSocket 구독 해제
    _ref.read(finnhubWebSocketProvider).unsubscribe(ticker);
  }

  /// 관심종목인지 확인
  bool isInWatchlist(String ticker) {
    return state.items.any((item) => item.ticker == ticker);
  }

  /// 메모 업데이트
  Future<void> updateNote(String ticker, String? note) async {
    await _repository.updateNote(ticker, note);
    final items = _repository.getAll();
    state = state.copyWith(items: items);
  }

  /// 목표가 알림 설정
  Future<void> setTargetAlert({
    required String ticker,
    required double alertPrice,
    int alertTargetDirection = 0,
  }) async {
    await _repository.setTargetAlert(
      ticker: ticker,
      alertPrice: alertPrice,
      alertTargetDirection: alertTargetDirection,
    );
    final items = _repository.getAll();
    if (!mounted) return;
    state = state.copyWith(items: items);
  }

  /// 변동률 알림 설정
  Future<void> setPercentAlert({
    required String ticker,
    required double alertBasePrice,
    required double alertPercent,
    required int alertDirection,
  }) async {
    await _repository.setPercentAlert(
      ticker: ticker,
      alertBasePrice: alertBasePrice,
      alertPercent: alertPercent,
      alertDirection: alertDirection,
    );
    final items = _repository.getAll();
    if (!mounted) return;
    state = state.copyWith(items: items);
  }

  /// 목표가 알림 해제
  Future<void> clearTargetAlert(String ticker) async {
    await _repository.clearTargetAlert(ticker);
    final items = _repository.getAll();
    if (!mounted) return;
    state = state.copyWith(items: items);
  }

  /// 변동률 알림 해제
  Future<void> clearPercentAlert(String ticker) async {
    await _repository.clearPercentAlert(ticker);
    final items = _repository.getAll();
    if (!mounted) return;
    state = state.copyWith(items: items);
  }

  /// 전체 알림 해제
  Future<void> clearAllAlerts(String ticker) async {
    await _repository.clearAllAlerts(ticker);
    final items = _repository.getAll();
    if (!mounted) return;
    state = state.copyWith(items: items);
  }

  /// 순서 변경 (드래그 앤 드롭)
  Future<void> reorder(int oldIndex, int newIndex) async {
    // ReorderableListView에서 oldIndex < newIndex일 때 newIndex가 1 더 큼
    int actualNewIndex = newIndex;
    if (oldIndex < newIndex) {
      actualNewIndex = newIndex - 1;
    }

    await _repository.reorder(oldIndex, actualNewIndex);
    final items = _repository.getAll();
    state = state.copyWith(items: items);
  }
}

/// 관심종목 Provider
final watchlistProvider =
    StateNotifierProvider<WatchlistNotifier, WatchlistState>((ref) {
  final repository = ref.watch(watchlistRepositoryProvider);
  return WatchlistNotifier(repository, ref);
});

/// 검색 결과 상태
class SearchState {
  final List<SearchResult> results;
  final bool isLoading;
  final String query;

  const SearchState({
    this.results = const [],
    this.isLoading = false,
    this.query = '',
  });

  SearchState copyWith({
    List<SearchResult>? results,
    bool? isLoading,
    String? query,
  }) {
    return SearchState(
      results: results ?? this.results,
      isLoading: isLoading ?? this.isLoading,
      query: query ?? this.query,
    );
  }
}

/// 검색 상태 관리 Notifier
class SearchNotifier extends StateNotifier<SearchState> {
  final FinnhubService _finnhubService;

  SearchNotifier(this._finnhubService) : super(const SearchState());

  /// 종목 검색
  Future<void> search(String query) async {
    if (query.isEmpty) {
      if (!mounted) return;
      state = const SearchState();
      return;
    }

    if (!mounted) return;
    state = state.copyWith(isLoading: true, query: query);

    try {
      final results = await _finnhubService.searchStocks(query);
      if (!mounted) return;
      state = state.copyWith(results: results, isLoading: false);
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(results: [], isLoading: false);
    }
  }

  /// 검색 초기화
  void clear() {
    if (!mounted) return;
    state = const SearchState();
  }
}

/// 검색 Provider
final searchProvider = StateNotifierProvider<SearchNotifier, SearchState>((ref) {
  final finnhubService = ref.watch(finnhubServiceProvider);
  return SearchNotifier(finnhubService);
});
