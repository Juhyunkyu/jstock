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

/// 시장 지수 Notifier (Twelve Data 전용 — 실제 지수 데이터)
///
/// NDX(NASDAQ 100), SPX(S&P 500) 등 실제 지수 심볼을 사용하여
/// 차트 데이터를 조회하고, 최신 캔들에서 현재가/변동률을 추출한다.
/// Finnhub 호출 없이 Twelve Data 1회 호출로 가격+차트 모두 해결.
class MarketIndexNotifier extends StateNotifier<MarketIndexState> {
  final TwelveDataService _twelveDataService;
  int _retryCount = 0;
  static const _maxAutoRetry = 3;

  MarketIndexNotifier(
    this._twelveDataService, {
    required String symbol,
    required String name,
  }) : super(MarketIndexState(symbol: symbol, name: name));

  /// 지수 데이터 로드 (차트에서 가격 추출 — API 1회)
  Future<void> loadData() async {
    state = state.copyWith(isLoading: true, error: null);

    List<OHLCData>? chartData;
    try {
      chartData = await _twelveDataService.getChartData(
        state.symbol,
        interval: '1day',
        outputsize: 180, // 약 6개월치
      );
    } catch (_) {}

    // 차트 데이터에서 현재가 및 변동률 추출
    double? price;
    double? changePercent;
    if (chartData != null && chartData.length >= 2) {
      final latest = chartData.last;
      final previous = chartData[chartData.length - 2];
      price = latest.close;
      if (previous.close > 0) {
        changePercent =
            ((latest.close - previous.close) / previous.close) * 100;
      }
    } else if (chartData != null && chartData.length == 1) {
      price = chartData.first.close;
    }

    state = state.copyWith(
      price: price ?? state.price,
      changePercent: changePercent ?? state.changePercent,
      chartData: (chartData != null && chartData.isNotEmpty)
          ? chartData
          : state.chartData,
      isLoading: false,
      lastUpdated:
          chartData != null ? DateTime.now() : state.lastUpdated,
      marketState: FinnhubService.calculateMarketState(),
      error: (chartData == null && !state.hasData && !state.hasChart)
          ? '데이터 로드 실패'
          : null,
    );

    // 차트가 비어있으면 자동 재시도 (10초 후, 최대 3번)
    if (!state.hasChart && _retryCount < _maxAutoRetry && mounted) {
      _retryCount++;
      Future.delayed(Duration(seconds: 10 * _retryCount), () {
        if (mounted && !state.hasChart) loadData();
      });
    } else if (state.hasChart) {
      _retryCount = 0;
    }
  }

  /// 차트 데이터만 로드 (기간 지정)
  Future<void> loadChartData({
    String range = '1mo',
    String interval = '1day',
  }) async {
    try {
      final outputsize = _rangeToOutputsize(range);
      final chartData = await _twelveDataService.getChartData(
        state.symbol,
        interval: interval,
        outputsize: outputsize,
      );

      if (chartData.isNotEmpty) {
        state = state.copyWith(chartData: chartData);
      }
    } catch (_) {
      // 차트 로드 실패 시 기존 차트 유지
    }
  }
}

/// NASDAQ 100 지수 Provider (심볼: NDX)
final marketIndexProvider =
    StateNotifierProvider<MarketIndexNotifier, MarketIndexState>((ref) {
  final twelveDataService = ref.watch(twelveDataServiceProvider);
  return MarketIndexNotifier(
    twelveDataService,
    symbol: 'NDX',
    name: 'NASDAQ 100',
  );
});

/// S&P 500 지수 Provider (심볼: SPX)
final sp500IndexProvider =
    StateNotifierProvider<MarketIndexNotifier, MarketIndexState>((ref) {
  final twelveDataService = ref.watch(twelveDataServiceProvider);
  return MarketIndexNotifier(
    twelveDataService,
    symbol: 'SPX',
    name: 'S&P 500',
  );
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
