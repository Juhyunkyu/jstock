import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/stock.dart';
import '../../data/services/api/finnhub_service.dart';
import 'api_providers.dart';
import 'cycle_providers.dart';
import 'holding_providers.dart';

/// 주식 가격 데이터 클래스
class StockPrice {
  final String ticker;
  final double price;
  final double changePercent;
  final DateTime lastUpdated;

  const StockPrice({
    required this.ticker,
    required this.price,
    required this.changePercent,
    required this.lastUpdated,
  });

  bool get isPositive => changePercent >= 0;
  bool get isStale => DateTime.now().difference(lastUpdated).inMinutes > 15;

  /// StockQuote에서 변환
  factory StockPrice.fromQuote(StockQuote quote) {
    return StockPrice(
      ticker: quote.symbol,
      price: quote.currentPrice,
      changePercent: quote.changePercent,
      lastUpdated: quote.timestamp,
    );
  }

  StockPrice copyWith({
    String? ticker,
    double? price,
    double? changePercent,
    DateTime? lastUpdated,
  }) {
    return StockPrice(
      ticker: ticker ?? this.ticker,
      price: price ?? this.price,
      changePercent: changePercent ?? this.changePercent,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}

/// 주식 가격 상태 관리 (API 연동)
class StockPriceNotifier extends StateNotifier<Map<String, StockPrice>> {
  final StockQuoteNotifier _quoteNotifier;

  StockPriceNotifier(this._quoteNotifier) : super({});

  /// API에서 가격 조회 및 업데이트
  Future<void> fetchPrice(String ticker) async {
    final quote = await _quoteNotifier.fetchQuote(ticker);
    if (quote != null) {
      state = {
        ...state,
        ticker: StockPrice.fromQuote(quote),
      };
    }
  }

  /// 여러 종목 API에서 가격 조회
  Future<void> fetchPrices(List<String> tickers) async {
    await _quoteNotifier.fetchQuotes(tickers);
    _syncFromQuotes();
  }

  /// 캐시에서 새로고침
  Future<void> refreshPrices(List<String> tickers) async {
    await _quoteNotifier.refreshQuotes(tickers);
    _syncFromQuotes();
  }

  /// QuoteNotifier 상태와 동기화
  void _syncFromQuotes() {
    final quotes = _quoteNotifier.state.quotes;
    final newState = <String, StockPrice>{};

    for (final entry in quotes.entries) {
      newState[entry.key] = StockPrice.fromQuote(entry.value);
    }

    state = {...state, ...newState};
  }

  /// 가격 수동 업데이트 (로컬)
  void updatePrice(String ticker, double price, double changePercent) {
    state = {
      ...state,
      ticker: StockPrice(
        ticker: ticker,
        price: price,
        changePercent: changePercent,
        lastUpdated: DateTime.now(),
      ),
    };
  }

  /// 여러 가격 일괄 업데이트
  void updatePrices(Map<String, StockPrice> prices) {
    state = {...state, ...prices};
  }

  /// 가격 조회
  StockPrice? getPrice(String ticker) => state[ticker];

  /// 가격 초기화
  void reset() {
    state = {};
  }

  /// 지정된 종목 시세 로드
  Future<void> loadSymbols(List<String> symbols) async {
    if (symbols.isEmpty) return;
    await fetchPrices(symbols);
  }

  /// Mock 데이터로 초기화 (더 이상 사용하지 않음)
  void initWithMockData() {
    // 동적 로드로 전환 - Mock 데이터 제거
  }
}

/// 주식 가격 Provider
final stockPriceProvider = StateNotifierProvider<StockPriceNotifier, Map<String, StockPrice>>((ref) {
  final quoteNotifier = ref.watch(stockQuoteProvider.notifier);
  final notifier = StockPriceNotifier(quoteNotifier);
  return notifier;
});

/// 사용자 등록 종목 (활성 사이클 + 보유 종목) 티커 목록 Provider
final userTickersProvider = Provider<List<String>>((ref) {
  final activeCycles = ref.watch(activeCyclesProvider);
  final activeHoldings = ref.watch(activeHoldingsProvider);

  final tickers = <String>{};

  // 활성 사이클의 티커들 추가
  for (final cycle in activeCycles) {
    tickers.add(cycle.ticker);
  }

  // 활성 보유 종목의 티커들 추가
  for (final holding in activeHoldings) {
    tickers.add(holding.ticker);
  }

  return tickers.toList();
});

/// 주식 가격 초기화 Provider
final stockPriceInitProvider = FutureProvider<void>((ref) async {
  final notifier = ref.read(stockPriceProvider.notifier);
  final userTickers = ref.read(userTickersProvider);

  if (userTickers.isEmpty) return;

  try {
    // 사용자 등록 종목 시세 로드
    await notifier.loadSymbols(userTickers);
  } catch (e) {
    // API 실패 시 빈 상태 유지
  }
});

/// 특정 종목 가격 Provider (Family)
final priceForTickerProvider = Provider.family<StockPrice?, String>((ref, ticker) {
  final prices = ref.watch(stockPriceProvider);
  return prices[ticker];
});

/// 모든 종목의 현재가 맵 Provider (WebSocket 실시간 반영)
///
/// stockQuoteProvider를 직접 watch하여 WebSocket 업데이트 자동 반영
final currentPricesProvider = Provider<Map<String, double>>((ref) {
  final quoteState = ref.watch(stockQuoteProvider);
  return quoteState.quotes.map((key, value) => MapEntry(key, value.currentPrice));
});

/// 사용자 종목 목록 Provider (가격 정보 포함)
final userStocksProvider = Provider<List<Stock>>((ref) {
  final prices = ref.watch(stockPriceProvider);
  final activeCycles = ref.watch(activeCyclesProvider);
  final activeHoldings = ref.watch(activeHoldingsProvider);

  final stockMap = <String, Stock>{};

  // 활성 사이클의 종목들 추가
  for (final cycle in activeCycles) {
    final priceData = prices[cycle.ticker];
    stockMap[cycle.ticker] = Stock(
      ticker: cycle.ticker,
      name: cycle.ticker, // 이름은 티커로 대체
      currentPrice: priceData?.price ?? 0.0,
      changePercent: priceData?.changePercent ?? 0.0,
      lastUpdated: priceData?.lastUpdated,
    );
  }

  // 활성 보유 종목들 추가 (중복 시 덮어쓰기)
  for (final holding in activeHoldings) {
    final priceData = prices[holding.ticker];
    stockMap[holding.ticker] = Stock(
      ticker: holding.ticker,
      name: holding.name,
      currentPrice: priceData?.price ?? 0.0,
      changePercent: priceData?.changePercent ?? 0.0,
      lastUpdated: priceData?.lastUpdated,
    );
  }

  return stockMap.values.toList();
});

/// 주가 로딩 상태 Provider
final stockPriceLoadingProvider = Provider<bool>((ref) {
  return ref.watch(stockQuoteProvider).isLoading;
});

/// 주가 에러 상태 Provider
final stockPriceErrorProvider = Provider<String?>((ref) {
  return ref.watch(stockQuoteProvider).error;
});

/// 검색된 종목 Provider
final stockSearchProvider = StateProvider<String>((ref) => '');

/// 검색 결과 Provider (사용자 등록 종목에서 검색)
final searchResultsProvider = Provider<List<Stock>>((ref) {
  final query = ref.watch(stockSearchProvider).toLowerCase();
  if (query.isEmpty) return [];

  final userStocks = ref.watch(userStocksProvider);

  return userStocks.where((stock) {
    return stock.ticker.toLowerCase().contains(query) ||
        stock.name.toLowerCase().contains(query);
  }).toList();
});

/// 시세 새로고침 Provider
final refreshStockPricesProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    final notifier = ref.read(stockPriceProvider.notifier);
    final userTickers = ref.read(userTickersProvider);
    if (userTickers.isEmpty) return;
    await notifier.refreshPrices(userTickers);
  };
});
