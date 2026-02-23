import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/alert_direction.dart';
import '../../data/services/api/fear_greed_service.dart';
import '../../data/services/cache/cache_manager.dart';
import 'api_providers.dart';
import 'settings_providers.dart';

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

/// Fear & Greed 알림 모니터 Provider
///
/// MainShell에서 ref.watch()하여 전역 활성화합니다.
/// Fear & Greed 값이 변경될 때마다 설정된 알림 조건을 체크합니다.
/// Fear & Greed 알림 결과
class FearGreedAlertResult {
  final String title;
  final String body;
  const FearGreedAlertResult({required this.title, required this.body});
}

/// Fear & Greed 알림 조건 체크 서비스
///
/// WatchlistAlertChecker 패턴과 동일하게 인스턴스 상태로 쿨다운 관리.
/// Provider 본문에서 cache.set() 사이드이펙트를 제거하여
/// 리빌드마다 쿨다운이 리셋되는 버그를 방지.
class FearGreedAlertChecker {
  DateTime? _lastTriggeredAt;
  static const Duration _cooldown = Duration(hours: 1);

  /// 알림 조건 체크
  FearGreedAlertResult? checkAlert({
    required bool enabled,
    required bool hasData,
    required int currentValue,
    required int alertValue,
    required int direction,
  }) {
    if (!enabled || !hasData) return null;

    // 조건 체크
    final dir = AlertDirection.fromFearGreedInt(direction);
    final triggered = dir == AlertDirection.below
        ? currentValue <= alertValue
        : currentValue >= alertValue;

    if (!triggered) return null;

    // 쿨다운 체크 (1시간)
    if (_lastTriggeredAt != null &&
        DateTime.now().difference(_lastTriggeredAt!) < _cooldown) {
      return null;
    }

    // 쿨다운 기록
    _lastTriggeredAt = DateTime.now();

    final dirLabel = dir.label;
    final zoneName = _getZoneLabel(currentValue);
    final title = '공포탐욕지수 $alertValue $dirLabel 도달!';
    final body = '현재 지수: $currentValue ($zoneName)';

    return FearGreedAlertResult(title: title, body: body);
  }

  /// 쿨다운 리셋 (설정 변경 시 호출)
  void reset() {
    _lastTriggeredAt = null;
  }
}

/// FearGreedAlertChecker 싱글톤 Provider
final fearGreedAlertCheckerProvider = Provider<FearGreedAlertChecker>((ref) {
  return FearGreedAlertChecker();
});

/// Fear & Greed 알림 모니터 Provider
///
/// MainShell에서 ref.watch()하여 전역 활성화합니다.
/// checker.checkAlert() 호출만 수행 (사이드이펙트 제거).
final fearGreedAlertMonitorProvider = Provider<FearGreedAlertResult?>((ref) {
  final settings = ref.watch(settingsProvider);
  final fgState = ref.watch(fearGreedProvider);
  final checker = ref.read(fearGreedAlertCheckerProvider);

  return checker.checkAlert(
    enabled: settings.fearGreedAlertEnabled,
    hasData: fgState.hasData,
    currentValue: fgState.value,
    alertValue: settings.fearGreedAlertValue,
    direction: settings.fearGreedAlertDirection,
  );
});

/// 한글 존 라벨 (알림 메시지용)
String _getZoneLabel(int value) {
  if (value < 25) return '극도의 공포';
  if (value < 44) return '공포';
  if (value < 56) return '중립';
  if (value < 75) return '탐욕';
  return '극도의 탐욕';
}
