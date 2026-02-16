import 'package:hive_flutter/hive_flutter.dart';

/// 티커 로고 URL 캐시 서비스
///
/// Finnhub profile2 API에서 가져온 로고 URL을 로컬에 캐싱합니다.
/// Hive Box를 사용하여 앱 재시작 후에도 유지됩니다.
class LogoCacheService {
  static const String _boxName = 'ticker_logos';
  static const String _timestampPrefix = '_ts_';
  static const Duration _cacheDuration = Duration(days: 30);

  Box<String>? _box;

  /// 캐시 초기화
  Future<void> initialize() async {
    _box = await Hive.openBox<String>(_boxName);
  }

  /// 로고 URL 조회 (캐시)
  String? getLogoUrl(String ticker) {
    if (_box == null) return null;
    final key = ticker.toUpperCase();

    // 만료 확인
    final timestampStr = _box!.get('$_timestampPrefix$key');
    if (timestampStr != null) {
      final timestamp = DateTime.tryParse(timestampStr);
      if (timestamp != null && DateTime.now().difference(timestamp) > _cacheDuration) {
        // 만료됨 - 삭제
        _box!.delete(key);
        _box!.delete('$_timestampPrefix$key');
        return null;
      }
    }

    return _box!.get(key);
  }

  /// 로고 URL 저장
  Future<void> saveLogoUrl(String ticker, String logoUrl) async {
    if (_box == null) return;
    final key = ticker.toUpperCase();
    await _box!.put(key, logoUrl);
    await _box!.put('$_timestampPrefix$key', DateTime.now().toIso8601String());
  }

  /// 특정 티커 캐시 삭제
  Future<void> remove(String ticker) async {
    if (_box == null) return;
    final key = ticker.toUpperCase();
    await _box!.delete(key);
    await _box!.delete('$_timestampPrefix$key');
  }

  /// 전체 캐시 삭제
  Future<void> clear() async {
    await _box?.clear();
  }

  /// 캐시된 티커 수
  int get cachedCount {
    if (_box == null) return 0;
    return _box!.keys.where((k) => !k.toString().startsWith(_timestampPrefix)).length;
  }
}
