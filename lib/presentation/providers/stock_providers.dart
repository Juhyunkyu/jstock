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

/// 사용자 등록 종목 (보유 종목 + 활성 사이클) 티커 목록 Provider
///
/// 활성 사이클의 경우:
/// - Ladder 공격형 (ladderMode==1): buyTicker가 있으면 사용, 없으면 기준 티커(ticker) 사용
/// - Ladder 안정형 (ladderMode==0): buyTicker1x/2x/3x 사용, 없으면 기준 티커(ticker) 사용
/// - 기타 전략: 기준 티커(ticker) 사용
final userTickersProvider = Provider<List<String>>((ref) {
  final activeHoldings = ref.watch(activeHoldingsProvider);
  final activeCycles = ref.watch(activeCyclesProvider);

  final tickers = <String>{};

  // 활성 보유 종목의 티커들 추가
  for (final holding in activeHoldings) {
    tickers.add(holding.ticker);
  }

  // 활성 사이클의 티커들 추가 (Ladder는 매수 티커 사용)
  for (final cycle in activeCycles) {
    final isLadder = cycle.strategyType.toString() == 'StrategyType.ladderCycle';
    
    if (isLadder) {
      // Ladder 공격형 (ladderMode == 1)
      if (cycle.ladderMode == 1) {
        if (cycle.buyTicker.isNotEmpty) {
          tickers.add(cycle.buyTicker);
        } else {
          tickers.add(cycle.ticker);
        }
      }
      // Ladder 안정형 (ladderMode == 0)
      else if (cycle.ladderMode == 0) {
        bool hasAnyBuyTicker = false;
        if (cycle.buyTicker1x.isNotEmpty) {
          tickers.add(cycle.buyTicker1x);
          hasAnyBuyTicker = true;
        }
        if (cycle.buyTicker2x.isNotEmpty) {
          tickers.add(cycle.buyTicker2x);
          hasAnyBuyTicker = true;
        }
        if (cycle.buyTicker3x.isNotEmpty) {
          tickers.add(cycle.buyTicker3x);
          hasAnyBuyTicker = true;
        }
        // 매수 티커가 하나도 없으면 기준 티커 사용
        if (!hasAnyBuyTicker) {
          tickers.add(cycle.ticker);
        }
      }
      // Ladder 초공격형 (ladderMode == 2) 등 다른 모드
      else {
        tickers.add(cycle.ticker);
      }
    } else {
      // 기타 전략 (Alpha Cycle, Infinite Buy, Steady): 기준 티커 사용
      tickers.add(cycle.ticker);
    }
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

/// 캐시된 시장 상태 Provider (1분 간격 갱신)
///
/// FinnhubService.calculateMarketState()는 DST 계산 포함 — 매 WS 틱마다
/// 호출하면 낭비. keepAlive + 1분 타이머로 캐시.
final cachedMarketStateProvider = Provider<String>((ref) {
  ref.keepAlive();
  final state = FinnhubService.calculateMarketState();

  // 1분 후 자동 무효화 → 다음 읽기 시 재계산
  final timer = Future.delayed(const Duration(minutes: 1), () {
    ref.invalidateSelf();
  });
  ref.onDispose(() {
    // timer는 자동 GC되지만 명시적으로 무시
    timer.ignore();
  });

  return state;
});

/// 종가 기반 가격 Provider (사이클/보유용)
///
/// Finnhub 무료 플랜은 시간외 거래 데이터를 제공하지 않으므로
/// currentPrice는 항상 정규장 마지막 거래가(= 종가)입니다.
/// 따라서 시장 상태와 관계없이 항상 currentPrice를 사용합니다.
final closingPricesProvider = Provider<Map<String, double>>((ref) {
  final quoteState = ref.watch(stockQuoteProvider);
  return quoteState.quotes.map((key, quote) {
    return MapEntry(key, quote.currentPrice);
  });
});

/// 사용자 종목 목록 Provider (가격 정보 포함)
final userStocksProvider = Provider<List<Stock>>((ref) {
  final prices = ref.watch(stockPriceProvider);
  final activeHoldings = ref.watch(activeHoldingsProvider);

  final stockMap = <String, Stock>{};

  // 보유 종목들 추가
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
