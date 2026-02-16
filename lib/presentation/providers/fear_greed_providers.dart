import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/services/api/fear_greed_service.dart';
import '../../data/services/cache/cache_manager.dart';
import 'api_providers.dart';

/// Fear & Greed Index 캐시 키 생성
String fearGreedCacheKey() => 'fear_greed:current';

/// Fear & Greed 서비스 Provider (싱글톤)
final fearGreedServiceProvider = Provider<FearGreedService>((ref) {
  return FearGreedService();
});

/// Fear & Greed Index 상태
class FearGreedState {
  final FearGreedIndex? index;
  final bool isLoading;
  final String? error;
  final DateTime? lastUpdated;

  const FearGreedState({
    this.index,
    this.isLoading = false,
    this.error,
    this.lastUpdated,
  });

  FearGreedState copyWith({
    FearGreedIndex? index,
    bool? isLoading,
    String? error,
    DateTime? lastUpdated,
  }) {
    return FearGreedState(
      index: index ?? this.index,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  /// Fear & Greed 값 (0-100)
  int get value => index?.value ?? 50;

  /// 한글 분류 레이블
  String get classificationKorean => index?.zoneLabel ?? '중립';

  /// 데이터 존재 여부
  bool get hasData => index != null;
}

/// Fear & Greed Index Notifier
class FearGreedNotifier extends StateNotifier<FearGreedState> {
  final FearGreedService _service;
  final CacheManager _cache;

  /// Fear & Greed Index는 하루에 한 번 업데이트되므로 1시간 캐시
  static const Duration _cacheTtl = Duration(hours: 1);

  FearGreedNotifier(this._service, this._cache) : super(const FearGreedState());

  /// Fear & Greed Index 조회
  Future<FearGreedIndex?> fetchIndex() async {
    final cacheKey = fearGreedCacheKey();

    // 캐시 확인
    final cached = _cache.get<FearGreedIndex>(cacheKey);
    if (cached != null) {
      state = state.copyWith(
        index: cached,
        lastUpdated: DateTime.now(),
      );
      return cached;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      final index = await _service.getCurrentIndex();

      // 캐시 저장 (1시간)
      _cache.set(cacheKey, index, ttl: _cacheTtl);

      state = state.copyWith(
        index: index,
        isLoading: false,
        lastUpdated: DateTime.now(),
      );

      return index;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Fear & Greed Index 조회 실패: ${e.toString()}',
      );
      return null;
    }
  }

  /// 강제 새로고침
  Future<void> refresh() async {
    _cache.remove(fearGreedCacheKey());
    await fetchIndex();
  }
}

/// Fear & Greed Index StateNotifier Provider
final fearGreedProvider =
    StateNotifierProvider<FearGreedNotifier, FearGreedState>((ref) {
  final service = ref.watch(fearGreedServiceProvider);
  final cache = ref.watch(cacheManagerProvider);
  return FearGreedNotifier(service, cache);
});

/// Fear & Greed Index FutureProvider (자동 로드)
///
/// 이 Provider를 watch하면 자동으로 데이터를 로드합니다.
/// StateNotifier와 달리 loading/error 상태를 AsyncValue로 처리합니다.
final fearGreedIndexProvider = FutureProvider<FearGreedIndex?>((ref) async {
  final notifier = ref.read(fearGreedProvider.notifier);
  return await notifier.fetchIndex();
});

/// Fear & Greed Index 자동 새로고침 Provider
///
/// 지정된 주기로 자동 새로고침합니다 (기본: 1시간).
/// 앱이 포그라운드일 때만 동작합니다.
final fearGreedAutoRefreshProvider = StreamProvider<FearGreedIndex?>((ref) async* {
  final notifier = ref.read(fearGreedProvider.notifier);

  // 초기 로드
  final initial = await notifier.fetchIndex();
  yield initial;

  // 1시간마다 새로고침
  await for (final _ in Stream.periodic(const Duration(hours: 1))) {
    await notifier.refresh();
    yield ref.read(fearGreedProvider).index;
  }
});

/// 현재 Fear & Greed 값 Provider (숫자만)
final fearGreedValueProvider = Provider<int>((ref) {
  return ref.watch(fearGreedProvider).value;
});

/// Fear & Greed 분류 Provider (한글)
final fearGreedClassificationProvider = Provider<String>((ref) {
  return ref.watch(fearGreedProvider).classificationKorean;
});

/// Fear & Greed 로딩 상태 Provider
final fearGreedLoadingProvider = Provider<bool>((ref) {
  return ref.watch(fearGreedProvider).isLoading;
});

/// Fear & Greed 에러 Provider
final fearGreedErrorProvider = Provider<String?>((ref) {
  return ref.watch(fearGreedProvider).error;
});

/// Fear & Greed 데이터 존재 여부 Provider
final hasFearGreedDataProvider = Provider<bool>((ref) {
  return ref.watch(fearGreedProvider).hasData;
});
