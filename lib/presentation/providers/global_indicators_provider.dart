import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/services/api/fred_service.dart';
import '../../data/services/api/twelve_data_service.dart';
import 'api_providers.dart';

/// 글로벌 지표 데이터 모델
class GlobalIndicator {
  final String symbol;
  final String label;
  final String icon;
  final double price;
  final double changePercent;
  final bool isRate; // 금리는 % 표시, 변동은 절대값
  final bool isIndex; // VIX 등 지수 — 단위 없이 숫자만

  const GlobalIndicator({
    required this.symbol,
    required this.label,
    required this.icon,
    required this.price,
    required this.changePercent,
    this.isRate = false,
    this.isIndex = false,
  });

  String get formattedPrice {
    if (isRate) return '${price.toStringAsFixed(2)}%';
    if (isIndex) return price.toStringAsFixed(2);
    if (price >= 10000) {
      return '\$${price.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]},',
      )}';
    }
    return '\$${price.toStringAsFixed(2).replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    )}';
  }

  String get formattedChange {
    final sign = changePercent >= 0 ? '+' : '';
    if (isRate || isIndex) {
      return '$sign${changePercent.toStringAsFixed(2)}';
    }
    return '$sign${changePercent.toStringAsFixed(2)}%';
  }

  bool get isPositive => changePercent >= 0;
}

/// 글로벌 지표 상태
class GlobalIndicatorsState {
  final List<GlobalIndicator> indicators;
  final bool isLoading;
  final String? error;

  const GlobalIndicatorsState({
    this.indicators = const [],
    this.isLoading = false,
    this.error,
  });

  GlobalIndicatorsState copyWith({
    List<GlobalIndicator>? indicators,
    bool? isLoading,
    String? error,
  }) {
    return GlobalIndicatorsState(
      indicators: indicators ?? this.indicators,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// FRED 서비스 Provider
final fredServiceProvider = Provider<FredService>((ref) {
  return FredService();
});

/// 글로벌 지표 Notifier
class GlobalIndicatorsNotifier extends StateNotifier<GlobalIndicatorsState> {
  final FredService _fredService;
  final TwelveDataService _twelveDataService;

  GlobalIndicatorsNotifier(this._fredService, this._twelveDataService)
      : super(const GlobalIndicatorsState());

  /// 모든 지표 순차 로드
  Future<void> loadIndicators() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final indicators = <GlobalIndicator>[];

      // 1. WTI 원유 선물 가격 (FRED)
      final wti = await _fetchFred('DCOILWTICO', 'WTI', '🛢️');
      if (wti != null) {
        indicators.add(wti);
        state = state.copyWith(indicators: List.from(indicators));
      }

      // 2. 금 현물 가격 (Twelve Data)
      final gold = await _fetchTwelveData('XAU/USD', '금', '🥇');
      if (gold != null) {
        indicators.add(gold);
        state = state.copyWith(indicators: List.from(indicators));
      }

      // 3. 비트코인 (Twelve Data)
      final btc = await _fetchTwelveData('BTC/USD', 'BTC', '₿');
      if (btc != null) {
        indicators.add(btc);
        state = state.copyWith(indicators: List.from(indicators));
      }

      // 4. 미국 10년 국채 수익률 (FRED)
      final tenY = await _fetchFredRate('DGS10', '10Y', '📈');
      if (tenY != null) {
        indicators.add(tenY);
        state = state.copyWith(indicators: List.from(indicators));
      }

      // 5. VIX 변동성 지수 (FRED)
      final vix = await _fetchFredIndex('VIXCLS', 'VIX', '⚡');
      if (vix != null) {
        indicators.add(vix);
        state = state.copyWith(indicators: List.from(indicators));
      }

      // 6. DXY 달러 인덱스 (FRED — 무역가중 달러지수)
      final dxy = await _fetchFredIndex('DTWEXBGS', 'DXY', '💵');
      if (dxy != null) {
        indicators.add(dxy);
        state = state.copyWith(indicators: List.from(indicators));
      }

      // 7. 구리 (Twelve Data)
      final copper = await _fetchTwelveData('XCU/USD', '구리', '🔶');
      if (copper != null) {
        indicators.add(copper);
        state = state.copyWith(indicators: List.from(indicators));
      }

      // 8. 천연가스 (FRED — Henry Hub 현물)
      final natgas = await _fetchFred('DHHNGSP', '천연가스', '🔥');
      if (natgas != null) {
        indicators.add(natgas);
        state = state.copyWith(indicators: List.from(indicators));
      }

      // 9. 은 (Twelve Data)
      final silver = await _fetchTwelveData('XAG/USD', '은', '🥈');
      if (silver != null) {
        indicators.add(silver);
        state = state.copyWith(indicators: List.from(indicators));
      }

      // 10. NASDAQ 선물 (Twelve Data — E-mini NQ)
      final nqFutures = await _fetchTwelveData('NQ', 'NQ선물', '📊');
      if (nqFutures != null) {
        indicators.add(nqFutures);
        state = state.copyWith(indicators: List.from(indicators));
      }

      state = state.copyWith(
        indicators: indicators,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: '지표 로드 실패',
      );
    }
  }

  /// FRED에서 가격 데이터 조회 (WTI 등 — 변동률 % 표시)
  Future<GlobalIndicator?> _fetchFred(
      String seriesId, String label, String icon) async {
    try {
      final obs = await _fredService.getLatestObservation(seriesId);
      if (obs == null) return null;

      return GlobalIndicator(
        symbol: seriesId,
        label: label,
        icon: icon,
        price: obs.value,
        changePercent: obs.changePercent,
      );
    } catch (_) {
      return null;
    }
  }

  /// FRED에서 금리 데이터 조회 (10Y 등 — 변동폭 표시)
  Future<GlobalIndicator?> _fetchFredRate(
      String seriesId, String label, String icon) async {
    try {
      final obs = await _fredService.getLatestObservation(seriesId);
      if (obs == null) return null;

      return GlobalIndicator(
        symbol: seriesId,
        label: label,
        icon: icon,
        price: obs.value,
        changePercent: obs.changeAbsolute, // 금리는 절대값 변동
        isRate: true,
      );
    } catch (_) {
      return null;
    }
  }

  /// FRED에서 지수 데이터 조회 (VIX 등 — 단위 없이 포인트, 변동폭 표시)
  Future<GlobalIndicator?> _fetchFredIndex(
      String seriesId, String label, String icon) async {
    try {
      final obs = await _fredService.getLatestObservation(seriesId);
      if (obs == null) return null;

      return GlobalIndicator(
        symbol: seriesId,
        label: label,
        icon: icon,
        price: obs.value,
        changePercent: obs.changeAbsolute, // 변동폭
        isIndex: true,
      );
    } catch (_) {
      return null;
    }
  }

  /// Twelve Data에서 forex/crypto 조회
  Future<GlobalIndicator?> _fetchTwelveData(
      String symbol, String label, String icon) async {
    try {
      final chartData = await _twelveDataService.getChartData(
        symbol,
        interval: '1day',
        outputsize: 2,
      );

      if (chartData.isEmpty) return null;

      final latest = chartData.last;
      double changePercent = 0;

      if (chartData.length >= 2) {
        final previous = chartData[chartData.length - 2];
        if (previous.close > 0) {
          changePercent =
              ((latest.close - previous.close) / previous.close) * 100;
        }
      }

      return GlobalIndicator(
        symbol: symbol,
        label: label,
        icon: icon,
        price: latest.close,
        changePercent: changePercent,
      );
    } catch (_) {
      return null;
    }
  }

  /// 새로고침
  Future<void> refresh() async {
    await loadIndicators();
  }
}

/// 글로벌 지표 Provider
final globalIndicatorsProvider =
    StateNotifierProvider<GlobalIndicatorsNotifier, GlobalIndicatorsState>(
        (ref) {
  final fredService = ref.watch(fredServiceProvider);
  final twelveDataService = ref.watch(twelveDataServiceProvider);
  return GlobalIndicatorsNotifier(fredService, twelveDataService);
});
