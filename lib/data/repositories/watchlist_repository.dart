import 'package:hive_flutter/hive_flutter.dart';
import '../models/watchlist_item.dart';

/// 관심종목 저장소
class WatchlistRepository {
  static const String _boxName = 'watchlist';
  late Box<WatchlistItem> _box;

  /// 저장소 초기화
  Future<void> init() async {
    if (!Hive.isAdapterRegistered(15)) {
      Hive.registerAdapter(WatchlistItemAdapter());
    }
    _box = await Hive.openBox<WatchlistItem>(_boxName);
  }

  /// 모든 관심종목 가져오기 (sortOrder 기준 정렬)
  List<WatchlistItem> getAll() {
    final items = _box.values.toList();
    // sortOrder가 0인 항목들은 addedAt 기준으로 정렬 후 sortOrder 부여
    if (items.every((item) => item.sortOrder == 0) && items.length > 1) {
      items.sort((a, b) => b.addedAt.compareTo(a.addedAt));
      for (int i = 0; i < items.length; i++) {
        items[i].sortOrder = i;
        items[i].save();
      }
    }
    items.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return items;
  }

  /// 티커로 관심종목 찾기
  WatchlistItem? getByTicker(String ticker) {
    try {
      return _box.values.firstWhere((item) => item.ticker == ticker);
    } catch (_) {
      return null;
    }
  }

  /// 관심종목인지 확인
  bool isInWatchlist(String ticker) {
    return _box.values.any((item) => item.ticker == ticker);
  }

  /// 관심종목 추가 (맨 앞에 추가)
  Future<void> add(WatchlistItem item) async {
    if (!isInWatchlist(item.ticker)) {
      // 기존 항목들의 sortOrder를 1씩 증가
      final items = _box.values.toList();
      for (final existing in items) {
        existing.sortOrder += 1;
        await existing.save();
      }
      // 새 항목은 sortOrder 0으로 맨 앞에
      item.sortOrder = 0;
      await _box.put(item.ticker, item);
    }
  }

  /// 관심종목 삭제
  Future<void> remove(String ticker) async {
    await _box.delete(ticker);
  }

  /// 관심종목 업데이트
  Future<void> update(WatchlistItem item) async {
    await _box.put(item.ticker, item);
  }

  /// 메모 업데이트
  Future<void> updateNote(String ticker, String? note) async {
    final item = getByTicker(ticker);
    if (item != null) {
      item.note = note;
      await item.save();
    }
  }

  /// 알림 가격 설정
  Future<void> setAlertPrice(String ticker, double? price) async {
    final item = getByTicker(ticker);
    if (item != null) {
      item.alertPrice = price;
      await item.save();
    }
  }

  /// 목표가 알림 설정
  Future<void> setTargetAlert({
    required String ticker,
    required double alertPrice,
    int alertTargetDirection = 0,
  }) async {
    final item = getByTicker(ticker);
    if (item != null) {
      item.alertPrice = alertPrice;
      item.alertTargetDirection = alertTargetDirection;
      await item.save();
    }
  }

  /// 변동률 알림 설정
  Future<void> setPercentAlert({
    required String ticker,
    required double alertBasePrice,
    required double alertPercent,
    required int alertDirection,
  }) async {
    final item = getByTicker(ticker);
    if (item != null) {
      item.alertBasePrice = alertBasePrice;
      item.alertPercent = alertPercent;
      item.alertDirection = alertDirection;
      await item.save();
    }
  }

  /// 목표가 알림 해제
  Future<void> clearTargetAlert(String ticker) async {
    final item = getByTicker(ticker);
    if (item != null) {
      item.alertPrice = null;
      await item.save();
    }
  }

  /// 변동률 알림 해제
  Future<void> clearPercentAlert(String ticker) async {
    final item = getByTicker(ticker);
    if (item != null) {
      item.alertBasePrice = null;
      item.alertPercent = null;
      item.alertDirection = null;
      await item.save();
    }
  }

  /// 전체 알림 해제
  Future<void> clearAllAlerts(String ticker) async {
    final item = getByTicker(ticker);
    if (item != null) {
      item.alertType = null;
      item.alertPrice = null;
      item.alertBasePrice = null;
      item.alertPercent = null;
      item.alertDirection = null;
      await item.save();
    }
  }

  /// 순서 변경 (드래그 앤 드롭)
  Future<void> reorder(int oldIndex, int newIndex) async {
    final items = getAll();
    if (oldIndex < 0 || oldIndex >= items.length) return;
    if (newIndex < 0 || newIndex >= items.length) return;

    final item = items.removeAt(oldIndex);
    items.insert(newIndex, item);

    // 새 순서 저장
    for (int i = 0; i < items.length; i++) {
      items[i].sortOrder = i;
      await items[i].save();
    }
  }

  /// 전체 삭제
  Future<void> clear() async {
    await _box.clear();
  }

  /// 관심종목 수
  int get count => _box.length;
}
