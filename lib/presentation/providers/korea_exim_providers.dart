import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/services/api/korea_exim_service.dart';
import '../../data/services/cache/cache_manager.dart';
import 'api_providers.dart';

/// 한국수출입은행 캐시 키
String koreaEximCacheKey() => 'korea_exim:USD:KRW';

/// 한국수출입은행 서비스 Provider (싱글톤)
final koreaEximServiceProvider = Provider<KoreaEximService>((ref) {
  return KoreaEximService();
});

/// 한국수출입은행 상태
class KoreaEximState {
  final KoreaEximRate? rate;
  final bool isLoading;
  final String? error;
  final DateTime? lastUpdated;

  const KoreaEximState({
    this.rate,
    this.isLoading = false,
    this.error,
    this.lastUpdated,
  });

  KoreaEximState copyWith({
    KoreaEximRate? rate,
    bool? isLoading,
    String? error,
    DateTime? lastUpdated,
  }) {
    return KoreaEximState(
      rate: rate ?? this.rate,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  bool get hasData => rate != null;
}

/// 한국수출입은행 Notifier
class KoreaEximNotifier extends StateNotifier<KoreaEximState> {
  final KoreaEximService _service;
  final CacheManager _cache;

  /// 12시간 캐시 TTL (매매기준율은 하루 1회 갱신)
  static const Duration _cacheTtl = Duration(hours: 12);

  KoreaEximNotifier(this._service, this._cache)
      : super(const KoreaEximState());

  /// USD/KRW 매매기준율 조회
  Future<KoreaEximRate?> fetchRate() async {
    final cacheKey = koreaEximCacheKey();

    // 캐시 확인
    final cached = _cache.get<KoreaEximRate>(cacheKey);
    if (cached != null) {
      state = state.copyWith(
        rate: cached,
        lastUpdated: DateTime.now(),
      );
      return cached;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      final rate = await _service.getUsdKrwRate();

      // 캐시 저장
      _cache.set(cacheKey, rate, ttl: _cacheTtl);

      state = state.copyWith(
        rate: rate,
        isLoading: false,
        lastUpdated: DateTime.now(),
      );

      return rate;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: '매매기준율 조회 실패',
      );
      return null;
    }
  }

  /// 강제 새로고침
  Future<void> refresh() async {
    _cache.remove(koreaEximCacheKey());
    await fetchRate();
  }
}

/// 한국수출입은행 Provider
final koreaEximProvider =
    StateNotifierProvider<KoreaEximNotifier, KoreaEximState>((ref) {
  final service = ref.watch(koreaEximServiceProvider);
  final cache = ref.watch(cacheManagerProvider);
  return KoreaEximNotifier(service, cache);
});
