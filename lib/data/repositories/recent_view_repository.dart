import 'package:hive_flutter/hive_flutter.dart';
import '../models/recent_view_item.dart';

/// 최근 조회 종목 저장소
class RecentViewRepository {
  static const String _boxName = 'recent_views';
  late Box<RecentViewItem> _box;

  /// 저장소 초기화
  Future<void> init() async {
    if (!Hive.isAdapterRegistered(23)) {
      Hive.registerAdapter(RecentViewItemAdapter());
    }
    _box = await Hive.openBox<RecentViewItem>(_boxName);
  }

  /// 모든 최근 조회 가져오기 (최신순, 최대 15개)
  List<RecentViewItem> getAll() {
    final items = _box.values.toList();
    items.sort((a, b) => b.viewedAt.compareTo(a.viewedAt));
    if (items.length > RecentViewItem.maxRecentItems) {
      return items.sublist(0, RecentViewItem.maxRecentItems);
    }
    return items;
  }

  /// 조회 기록 (이미 있으면 시간만 갱신, FIFO 15개 초과 시 가장 오래된 삭제)
  Future<void> recordView(RecentViewItem item) async {
    // 이미 있으면 시간만 갱신
    final existing = _box.get(item.ticker);
    if (existing != null) {
      existing.viewedAt = DateTime.now();
      existing.name = item.name;
      existing.exchange = item.exchange;
      existing.type = item.type;
      await existing.save();
      return;
    }

    // 새로 추가
    await _box.put(item.ticker, item);

    // 15개 초과 시 가장 오래된 삭제
    if (_box.length > RecentViewItem.maxRecentItems) {
      final all = _box.values.toList();
      all.sort((a, b) => a.viewedAt.compareTo(b.viewedAt));
      final toDelete = all.sublist(0, all.length - RecentViewItem.maxRecentItems);
      for (final old in toDelete) {
        await _box.delete(old.ticker);
      }
    }
  }

  /// 특정 종목 삭제
  Future<void> remove(String ticker) async {
    await _box.delete(ticker);
  }

  /// 전체 삭제
  Future<void> clear() async {
    await _box.clear();
  }

  /// 조회 기록 수
  int get count => _box.length;
}
