import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/services/api/finnhub_service.dart';
import '../../data/services/cache/logo_cache_service.dart';
import 'api_providers.dart';

/// 로고 캐시 서비스 Provider (싱글톤)
final logoCacheServiceProvider = Provider<LogoCacheService>((ref) {
  return LogoCacheService();
});

/// 로고 캐시 초기화 Provider
final logoCacheInitProvider = FutureProvider<void>((ref) async {
  final service = ref.read(logoCacheServiceProvider);
  await service.initialize();
});

/// 티커 로고 URL 상태 관리
class TickerLogoNotifier extends StateNotifier<Map<String, String?>> {
  final FinnhubService _finnhubService;
  final LogoCacheService _cacheService;
  final Set<String> _fetchingTickers = {};

  TickerLogoNotifier(this._finnhubService, this._cacheService)
      : super({});

  /// 단일 티커 로고 URL 가져오기
  Future<String?> fetchLogo(String ticker) async {
    final key = ticker.toUpperCase();

    // 이미 상태에 있으면 반환
    if (state.containsKey(key)) return state[key];

    // 캐시 확인
    final cached = _cacheService.getLogoUrl(key);
    if (cached != null) {
      state = {...state, key: cached};
      return cached;
    }

    // 이미 요청 중이면 스킵
    if (_fetchingTickers.contains(key)) return null;
    _fetchingTickers.add(key);

    try {
      final logoUrl = await _finnhubService.getCompanyLogo(key);
      if (logoUrl != null) {
        await _cacheService.saveLogoUrl(key, logoUrl);
        state = {...state, key: logoUrl};
      } else {
        // 로고 없음을 기록 (빈 문자열)
        state = {...state, key: null};
      }
      return logoUrl;
    } catch (_) {
      return null;
    } finally {
      _fetchingTickers.remove(key);
    }
  }

  /// 여러 티커 로고 일괄 가져오기 (병렬 호출)
  Future<void> fetchLogos(List<String> tickers) async {
    await Future.wait(tickers.map((ticker) => fetchLogo(ticker)));
  }

  /// 특정 티커 로고 URL 조회 (캐시 or 상태)
  String? getLogoUrl(String ticker) {
    final key = ticker.toUpperCase();
    return state[key] ?? _cacheService.getLogoUrl(key);
  }
}

/// 로고 상태 관리 Provider
final tickerLogoProvider =
    StateNotifierProvider<TickerLogoNotifier, Map<String, String?>>((ref) {
  final finnhubService = ref.watch(finnhubServiceProvider);
  final cacheService = ref.watch(logoCacheServiceProvider);
  return TickerLogoNotifier(finnhubService, cacheService);
});

/// 개별 티커 로고 URL Provider (FutureProvider.family)
final tickerLogoUrlProvider = FutureProvider.family<String?, String>((ref, ticker) async {
  final notifier = ref.read(tickerLogoProvider.notifier);
  return notifier.fetchLogo(ticker);
});
