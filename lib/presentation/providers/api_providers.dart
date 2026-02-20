import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/services/api/finnhub_service.dart';
import '../../data/services/api/finnhub_websocket_service.dart';
import '../../data/services/api/exchange_rate_service.dart';
import '../../data/services/api/twelve_data_service.dart';
import '../../data/services/api/news_service.dart';
import '../../data/services/api/api_exception.dart';
import '../../data/services/cache/cache_manager.dart';

/// 캐시 매니저 Provider (싱글톤)
final cacheManagerProvider = Provider<CacheManager>((ref) {
  return CacheManager();
});

/// Finnhub REST 서비스 Provider
final finnhubServiceProvider = Provider<FinnhubService>((ref) {
  return FinnhubService();
});

/// Twelve Data 서비스 Provider (차트 데이터용)
final twelveDataServiceProvider = Provider<TwelveDataService>((ref) {
  return TwelveDataService();
});

/// 뉴스 서비스 Provider (MarketAux + MyMemory 번역)
final newsServiceProvider = Provider<NewsService>((ref) {
  return NewsService();
});

/// Finnhub WebSocket 서비스 Provider (싱글톤)
final finnhubWebSocketProvider = Provider<FinnhubWebSocketService>((ref) {
  final service = FinnhubWebSocketService();

  // Provider가 dispose될 때 리소스 정리
  ref.onDispose(() {
    service.dispose();
  });

  return service;
});

/// 환율 서비스 Provider
final exchangeRateServiceProvider = Provider<ExchangeRateService>((ref) {
  return ExchangeRateService();
});

/// 주가 조회 결과 상태
class StockQuoteState {
  final Map<String, StockQuote> quotes;
  final bool isLoading;
  final String? error;
  final DateTime? lastUpdated;

  const StockQuoteState({
    this.quotes = const {},
    this.isLoading = false,
    this.error,
    this.lastUpdated,
  });

  StockQuoteState copyWith({
    Map<String, StockQuote>? quotes,
    bool? isLoading,
    String? error,
    DateTime? lastUpdated,
  }) {
    return StockQuoteState(
      quotes: quotes ?? this.quotes,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}

/// 주가 조회 Notifier
class StockQuoteNotifier extends StateNotifier<StockQuoteState> {
  final FinnhubService _service;
  final FinnhubWebSocketService _wsService;
  final CacheManager _cache;
  StreamSubscription<RealtimePrice>? _subscription;

  StockQuoteNotifier(this._service, this._wsService, this._cache)
      : super(const StockQuoteState()) {
    // WebSocket 실시간 업데이트 구독
    _startRealtimeUpdates();
  }

  /// 실시간 업데이트 시작
  void _startRealtimeUpdates() {
    _subscription?.cancel();
    _subscription = _wsService.priceStream.listen((price) {
      final existingQuote = state.quotes[price.symbol];

      if (existingQuote == null) {
        // REST보다 WebSocket이 먼저 도착한 경우 — 최소 데이터로 생성
        final newQuote = StockQuote(
          symbol: price.symbol,
          currentPrice: price.price,
          previousClose: price.price, // 전일종가 없으므로 현재가로 대체
          changePercent: 0.0,
          dayHigh: price.price,
          dayLow: price.price,
          volume: price.volume,
          timestamp: price.timestamp,
          marketState: 'REGULAR',
        );
        state = state.copyWith(
          quotes: {...state.quotes, price.symbol: newQuote},
          lastUpdated: DateTime.now(),
        );
        return;
      }

      // 장 마감 시간(CLOSED)에는 WebSocket 업데이트 무시
      // REST API가 제공하는 공식 종가를 유지
      if (existingQuote.marketState == 'CLOSED') {
        return;
      }

      // 가격 변동이 너무 큰 경우 (5% 이상) 무시 - 비정상 데이터 필터링
      final priceDiff = (price.price - existingQuote.currentPrice).abs();
      final priceChangeRatio = priceDiff / existingQuote.currentPrice;
      if (priceChangeRatio > 0.05) {
        return;
      }

      final changePercent = existingQuote.previousClose > 0
          ? ((price.price - existingQuote.previousClose) /
                  existingQuote.previousClose) *
              100
          : 0.0;

      final updatedQuote = StockQuote(
        symbol: price.symbol,
        currentPrice: price.price,
        previousClose: existingQuote.previousClose,
        changePercent: changePercent,
        dayHigh: price.price > existingQuote.dayHigh
            ? price.price
            : existingQuote.dayHigh,
        dayLow: price.price < existingQuote.dayLow
            ? price.price
            : existingQuote.dayLow,
        volume: existingQuote.volume + price.volume,
        timestamp: price.timestamp,
        marketState: existingQuote.marketState,
      );

      state = state.copyWith(
        quotes: {...state.quotes, price.symbol: updatedQuote},
        lastUpdated: DateTime.now(),
      );

      // 캐시 업데이트
      _cache.set(
        stockCacheKey(price.symbol),
        updatedQuote,
        ttl: CacheManager.defaultStockTtl,
      );
    }, onError: (error) {
      // WebSocket 에러 시 구독 종료 방지 — 자동 재연결에 의존
      print('[StockQuoteNotifier] WebSocket stream error: $error');
    });
  }

  /// 단일 종목 시세 조회
  Future<StockQuote?> fetchQuote(String symbol) async {
    final cacheKey = stockCacheKey(symbol);

    // 캐시 확인
    final cached = _cache.get<StockQuote>(cacheKey);
    if (cached != null) {
      state = state.copyWith(
        quotes: {...state.quotes, symbol: cached},
      );
      // WebSocket 구독 추가
      _wsService.subscribe(symbol);
      return cached;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      final quote = await _service.getQuote(symbol);

      // 캐시 저장
      _cache.set(cacheKey, quote, ttl: CacheManager.defaultStockTtl);

      state = state.copyWith(
        quotes: {...state.quotes, symbol: quote},
        isLoading: false,
        lastUpdated: DateTime.now(),
      );

      // WebSocket 구독 추가
      _wsService.subscribe(symbol);

      return quote;
    } on ApiException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.message,
      );
      return null;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: '주가 조회 실패: $e',
      );
      return null;
    }
  }

  /// 여러 종목 시세 일괄 조회
  Future<void> fetchQuotes(List<String> symbols) async {
    if (symbols.isEmpty) return;

    final uncachedSymbols = <String>[];
    final cachedQuotes = <String, StockQuote>{};

    // 캐시된 데이터 먼저 확인
    for (final symbol in symbols) {
      final cacheKey = stockCacheKey(symbol);
      final cached = _cache.get<StockQuote>(cacheKey);
      if (cached != null) {
        cachedQuotes[symbol] = cached;
      } else {
        uncachedSymbols.add(symbol);
      }
    }

    // 캐시된 데이터 상태 업데이트 + 즉시 WebSocket 구독
    if (cachedQuotes.isNotEmpty) {
      state = state.copyWith(
        quotes: {...state.quotes, ...cachedQuotes},
      );
      _wsService.subscribeAll(cachedQuotes.keys.toList());
    }

    // 캐시되지 않은 데이터만 API 호출
    if (uncachedSymbols.isEmpty) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final quotes = await _service.getQuotes(uncachedSymbols);

      // 캐시 저장
      for (final entry in quotes.entries) {
        _cache.set(
          stockCacheKey(entry.key),
          entry.value,
          ttl: CacheManager.defaultStockTtl,
        );
      }

      state = state.copyWith(
        quotes: {...state.quotes, ...quotes},
        isLoading: false,
        lastUpdated: DateTime.now(),
      );

      // REST 응답 후 미캐시 심볼도 WebSocket 구독
      _wsService.subscribeAll(uncachedSymbols);
    } on ApiException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.message,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: '주가 조회 실패: $e',
      );
    }
  }

  /// 캐시 강제 새로고침 (REST API 사용)
  Future<void> refreshQuotes(List<String> symbols) async {
    if (symbols.isEmpty) return;

    // 캐시 무효화
    for (final symbol in symbols) {
      _cache.remove(stockCacheKey(symbol));
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      final quotes = await _service.getQuotes(symbols);

      // 캐시 저장
      for (final entry in quotes.entries) {
        _cache.set(
          stockCacheKey(entry.key),
          entry.value,
          ttl: CacheManager.defaultStockTtl,
        );
      }

      state = state.copyWith(
        quotes: {...state.quotes, ...quotes},
        isLoading: false,
        lastUpdated: DateTime.now(),
      );
    } on ApiException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.message,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: '주가 새로고침 실패: $e',
      );
    }
  }

  /// 단일 종목 REST API 강제 새로고침
  Future<StockQuote?> refreshQuote(String symbol) async {
    _cache.remove(stockCacheKey(symbol));

    try {
      final quote = await _service.getQuote(symbol);

      _cache.set(stockCacheKey(symbol), quote, ttl: CacheManager.defaultStockTtl);

      state = state.copyWith(
        quotes: {...state.quotes, symbol: quote},
        lastUpdated: DateTime.now(),
      );

      _wsService.subscribe(symbol);

      return quote;
    } catch (e) {
      return null;
    }
  }

  /// 특정 종목 시세 조회 (캐시된 데이터)
  StockQuote? getQuote(String symbol) {
    return state.quotes[symbol];
  }

  /// 캐시 정리
  void cleanup() {
    _cache.cleanup();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

/// 주가 조회 Provider
final stockQuoteProvider =
    StateNotifierProvider<StockQuoteNotifier, StockQuoteState>((ref) {
  final service = ref.watch(finnhubServiceProvider);
  final wsService = ref.watch(finnhubWebSocketProvider);
  final cache = ref.watch(cacheManagerProvider);
  return StockQuoteNotifier(service, wsService, cache);
});

/// 환율 상태
class ExchangeRateState {
  final ExchangeRate? usdKrw;
  final bool isLoading;
  final String? error;
  final DateTime? lastUpdated;

  const ExchangeRateState({
    this.usdKrw,
    this.isLoading = false,
    this.error,
    this.lastUpdated,
  });

  ExchangeRateState copyWith({
    ExchangeRate? usdKrw,
    bool? isLoading,
    String? error,
    DateTime? lastUpdated,
  }) {
    return ExchangeRateState(
      usdKrw: usdKrw ?? this.usdKrw,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}

/// 환율 Notifier
class ExchangeRateNotifier extends StateNotifier<ExchangeRateState> {
  final ExchangeRateService _service;
  final CacheManager _cache;

  ExchangeRateNotifier(this._service, this._cache)
      : super(const ExchangeRateState());

  /// USD/KRW 환율 조회
  Future<ExchangeRate?> fetchUsdKrwRate() async {
    final cacheKey = exchangeRateCacheKey('USD', 'KRW');

    // 캐시 확인 (1분간 유효 - 더 자주 업데이트)
    final cached = _cache.get<ExchangeRate>(cacheKey);
    if (cached != null) {
      state = state.copyWith(usdKrw: cached);
      return cached;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      final rate = await _service.getUsdKrwRate();

      // 캐시 저장 (1분 - 더 빠른 환율 업데이트)
      _cache.set(cacheKey, rate, ttl: const Duration(minutes: 1));

      state = state.copyWith(
        usdKrw: rate,
        isLoading: false,
        lastUpdated: DateTime.now(),
      );

      return rate;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: '환율 조회 실패',
      );
      return null;
    }
  }

  /// 환율 강제 새로고침
  Future<void> refreshRate() async {
    _cache.remove(exchangeRateCacheKey('USD', 'KRW'));
    await fetchUsdKrwRate();
  }

  /// 현재 환율 (기본값 1400)
  double get currentRate => state.usdKrw?.rate ?? 1400.0;
}

/// 환율 Provider
final exchangeRateProvider =
    StateNotifierProvider<ExchangeRateNotifier, ExchangeRateState>((ref) {
  final service = ref.watch(exchangeRateServiceProvider);
  final cache = ref.watch(cacheManagerProvider);
  return ExchangeRateNotifier(service, cache);
});

/// 현재 USD/KRW 환율 Provider (숫자만)
final currentExchangeRateProvider = Provider<double>((ref) {
  final state = ref.watch(exchangeRateProvider);
  return state.usdKrw?.rate ?? 1400.0;
});

/// API 초기화 Provider
final apiInitializationProvider = FutureProvider<void>((ref) async {
  final exchangeRateNotifier = ref.read(exchangeRateProvider.notifier);

  // 환율만 조회 (종목 시세는 stockPriceInitProvider에서 동적으로 로드)
  await exchangeRateNotifier.fetchUsdKrwRate();
});
