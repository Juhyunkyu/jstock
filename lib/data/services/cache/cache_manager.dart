/// 캐시 항목
class CacheEntry<T> {
  final T data;
  final DateTime createdAt;
  final Duration ttl;

  const CacheEntry({
    required this.data,
    required this.createdAt,
    required this.ttl,
  });

  bool get isExpired => DateTime.now().difference(createdAt) > ttl;

  DateTime get expiresAt => createdAt.add(ttl);

  Duration get remainingTime {
    final remaining = expiresAt.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }
}

/// 메모리 기반 캐시 매니저
class CacheManager {
  final Map<String, CacheEntry<dynamic>> _cache = {};

  /// 기본 TTL 설정
  static const Duration defaultStockTtl = Duration(minutes: 15);
  static const Duration defaultExchangeRateTtl = Duration(hours: 1);

  /// 캐시에서 데이터 조회
  T? get<T>(String key) {
    final entry = _cache[key];
    if (entry == null) return null;

    if (entry.isExpired) {
      _cache.remove(key);
      return null;
    }

    return entry.data as T?;
  }

  /// 캐시에 데이터 저장
  void set<T>(String key, T data, {Duration? ttl}) {
    _cache[key] = CacheEntry<T>(
      data: data,
      createdAt: DateTime.now(),
      ttl: ttl ?? defaultStockTtl,
    );
  }

  /// 특정 키 삭제
  void remove(String key) {
    _cache.remove(key);
  }

  /// 패턴과 일치하는 키들 삭제
  void removePattern(String pattern) {
    final regex = RegExp(pattern);
    _cache.removeWhere((key, _) => regex.hasMatch(key));
  }

  /// 전체 캐시 삭제
  void clear() {
    _cache.clear();
  }

  /// 만료된 항목들 정리
  void cleanup() {
    _cache.removeWhere((_, entry) => entry.isExpired);
  }

  /// 캐시 키 존재 여부
  bool containsKey(String key) {
    final entry = _cache[key];
    if (entry == null) return false;

    if (entry.isExpired) {
      _cache.remove(key);
      return false;
    }

    return true;
  }

  /// 캐시 상태 조회
  CacheStats get stats {
    cleanup();
    return CacheStats(
      itemCount: _cache.length,
      keys: _cache.keys.toList(),
    );
  }
}

/// 캐시 통계
class CacheStats {
  final int itemCount;
  final List<String> keys;

  const CacheStats({
    required this.itemCount,
    required this.keys,
  });
}

/// 주가 캐시 키 생성
String stockCacheKey(String symbol) => 'stock:${symbol.toUpperCase()}';

/// 환율 캐시 키 생성
String exchangeRateCacheKey(String from, String to) =>
    'exchange:${from.toUpperCase()}:${to.toUpperCase()}';
