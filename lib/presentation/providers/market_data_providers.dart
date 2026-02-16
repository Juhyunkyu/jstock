import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/ohlc_data.dart';
import '../../data/services/api/finnhub_service.dart';
import '../../data/services/api/twelve_data_service.dart';
import 'api_providers.dart';

/// range 문자열을 outputsize로 변환
int _rangeToOutputsize(String range) {
  switch (range) {
    case '1d':
      return 1;
    case '5d':
      return 5;
    case '1mo':
      return 30;
    case '3mo':
      return 90;
    case '6mo':
      return 180;
    case '1y':
      return 365;
    case '2y':
      return 104; // 약 2년치 주봉
    case '10y':
      return 120; // 약 10년치 월봉
    default:
      return 30;
  }
}

/// 시장 지수 데이터 상태
class MarketIndexState {
  final String symbol;
  final String name;
  final double price;
  final double changePercent;
  final List<OHLCData> chartData;
  final bool isLoading;
  final String? error;
  final DateTime? lastUpdated;
  final String marketState; // REGULAR, CLOSED, PRE, POST

  const MarketIndexState({
    required this.symbol,
    required this.name,
    this.price = 0,
    this.changePercent = 0,
    this.chartData = const [],
    this.isLoading = false,
    this.error,
    this.lastUpdated,
    this.marketState = 'CLOSED',
  });

  bool get isPositive => changePercent >= 0;
  bool get hasData => price > 0;
  bool get hasChart => chartData.isNotEmpty;

  /// 정규장 개장 중인지
  bool get isMarketOpen => marketState == 'REGULAR';

  /// 시장 상태 한글 표시
  String get marketStateKorean {
    switch (marketState) {
      case 'REGULAR':
        return '개장중';
      case 'PRE':
      case 'PREPRE':
        return '프리마켓';
      case 'POST':
      case 'POSTPOST':
        return '애프터마켓';
      case 'CLOSED':
      default:
        return '휴장';
    }
  }

  MarketIndexState copyWith({
    String? symbol,
    String? name,
    double? price,
    double? changePercent,
    List<OHLCData>? chartData,
    bool? isLoading,
    String? error,
    DateTime? lastUpdated,
    String? marketState,
  }) {
    return MarketIndexState(
      symbol: symbol ?? this.symbol,
      name: name ?? this.name,
      price: price ?? this.price,
      changePercent: changePercent ?? this.changePercent,
      chartData: chartData ?? this.chartData,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      marketState: marketState ?? this.marketState,
    );
  }
}

/// 시장 지수 관리 Notifier
class MarketIndexNotifier extends StateNotifier<MarketIndexState> {
  final FinnhubService _finnhubService;
  final TwelveDataService _twelveDataService;

  MarketIndexNotifier(this._finnhubService, this._twelveDataService)
      : super(const MarketIndexState(
          symbol: 'QQQ',
          name: 'NASDAQ 100 (QQQ)',
        ));

  /// 나스닥 100 지수 데이터 로드 (QQQ ETF 사용)
  Future<void> loadNasdaqData() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // 현재가(Finnhub)와 차트 데이터(Twelve Data)를 병렬로 조회 (속도 개선)
      final results = await Future.wait([
        _finnhubService.getQuote(FinnhubService.nasdaqSymbol),
        _twelveDataService.getChartData(
          FinnhubService.nasdaqSymbol,
          interval: '1day',
          outputsize: 180, // 약 6개월치
        ),
      ]);

      final quote = results[0] as StockQuote;
      final chartData = results[1] as List<OHLCData>;

      state = state.copyWith(
        price: quote.currentPrice,
        changePercent: quote.changePercent,
        chartData: chartData,
        isLoading: false,
        lastUpdated: DateTime.now(),
        marketState: quote.marketState,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: '나스닥 100 데이터 로드 실패: ${e.toString()}',
      );
    }
  }

  /// 차트 데이터만 로드 (기간 지정)
  Future<void> loadChartData({String range = '1mo', String interval = '1day'}) async {
    try {
      final outputsize = _rangeToOutputsize(range);
      final chartData = await _twelveDataService.getChartData(
        state.symbol,
        interval: interval,
        outputsize: outputsize,
      );

      state = state.copyWith(chartData: chartData);
    } catch (e) {
      state = state.copyWith(
        error: '차트 데이터 로드 실패: ${e.toString()}',
      );
    }
  }

  /// 현재가만 새로고침 (Finnhub 사용)
  Future<void> refreshPrice() async {
    try {
      final quote = await _finnhubService.getQuote(state.symbol);
      state = state.copyWith(
        price: quote.currentPrice,
        changePercent: quote.changePercent,
        lastUpdated: DateTime.now(),
        marketState: quote.marketState,
      );
    } catch (e) {
      // 가격 새로고침 실패는 무시 (기존 데이터 유지)
    }
  }
}

/// 시장 지수 Provider (나스닥)
final marketIndexProvider =
    StateNotifierProvider<MarketIndexNotifier, MarketIndexState>((ref) {
  final finnhubService = ref.watch(finnhubServiceProvider);
  final twelveDataService = ref.watch(twelveDataServiceProvider);
  return MarketIndexNotifier(finnhubService, twelveDataService);
});

/// S&P 500 지수 관리 Notifier
class SP500IndexNotifier extends StateNotifier<MarketIndexState> {
  final FinnhubService _finnhubService;
  final TwelveDataService _twelveDataService;

  SP500IndexNotifier(this._finnhubService, this._twelveDataService)
      : super(const MarketIndexState(
          symbol: 'SPY',
          name: 'S&P 500 (SPY)',
        ));

  /// S&P 500 지수 데이터 로드 (SPY ETF 사용)
  Future<void> loadSp500Data() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // 현재가(Finnhub)와 차트 데이터(Twelve Data)를 병렬로 조회 (속도 개선)
      final results = await Future.wait([
        _finnhubService.getQuote(FinnhubService.sp500Symbol),
        _twelveDataService.getChartData(
          FinnhubService.sp500Symbol,
          interval: '1day',
          outputsize: 180, // 약 6개월치
        ),
      ]);

      final quote = results[0] as StockQuote;
      final chartData = results[1] as List<OHLCData>;

      state = state.copyWith(
        price: quote.currentPrice,
        changePercent: quote.changePercent,
        chartData: chartData,
        isLoading: false,
        lastUpdated: DateTime.now(),
        marketState: quote.marketState,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'S&P 500 데이터 로드 실패: ${e.toString()}',
      );
    }
  }

  /// 차트 데이터만 로드 (기간 지정)
  Future<void> loadChartData({String range = '1mo', String interval = '1day'}) async {
    try {
      final outputsize = _rangeToOutputsize(range);
      final chartData = await _twelveDataService.getChartData(
        state.symbol,
        interval: interval,
        outputsize: outputsize,
      );

      state = state.copyWith(chartData: chartData);
    } catch (e) {
      state = state.copyWith(
        error: '차트 데이터 로드 실패: ${e.toString()}',
      );
    }
  }
}

/// S&P 500 지수 Provider
final sp500IndexProvider =
    StateNotifierProvider<SP500IndexNotifier, MarketIndexState>((ref) {
  final finnhubService = ref.watch(finnhubServiceProvider);
  final twelveDataService = ref.watch(twelveDataServiceProvider);
  return SP500IndexNotifier(finnhubService, twelveDataService);
});

/// 시장 지수 초기화 Provider
final marketIndexInitProvider = FutureProvider<void>((ref) async {
  final nasdaqNotifier = ref.read(marketIndexProvider.notifier);
  final sp500Notifier = ref.read(sp500IndexProvider.notifier);
  await Future.wait([
    nasdaqNotifier.loadNasdaqData(),
    sp500Notifier.loadSp500Data(),
  ]);
});

/// 나스닥 현재가 Provider
final nasdaqPriceProvider = Provider<double>((ref) {
  return ref.watch(marketIndexProvider).price;
});

/// 나스닥 변동률 Provider
final nasdaqChangeProvider = Provider<double>((ref) {
  return ref.watch(marketIndexProvider).changePercent;
});

/// 나스닥 차트 데이터 Provider
final nasdaqChartProvider = Provider<List<OHLCData>>((ref) {
  return ref.watch(marketIndexProvider).chartData;
});

/// 시장 데이터 로딩 상태 Provider
final marketDataLoadingProvider = Provider<bool>((ref) {
  return ref.watch(marketIndexProvider).isLoading;
});

/// 시장 데이터 에러 Provider
final marketDataErrorProvider = Provider<String?>((ref) {
  return ref.watch(marketIndexProvider).error;
});

/// 시장 개장 상태 Provider
final marketStateProvider = Provider<String>((ref) {
  return ref.watch(marketIndexProvider).marketState;
});

/// 시장 개장 여부 Provider
final isMarketOpenProvider = Provider<bool>((ref) {
  return ref.watch(marketIndexProvider).isMarketOpen;
});

/// 시장 상태 한글 Provider
final marketStateKoreanProvider = Provider<String>((ref) {
  return ref.watch(marketIndexProvider).marketStateKorean;
});
