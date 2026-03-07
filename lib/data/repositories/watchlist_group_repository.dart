import 'package:hive_flutter/hive_flutter.dart';
import '../models/watchlist_group.dart';

/// 관심종목 그룹 저장소
class WatchlistGroupRepository {
  static const String _boxName = 'watchlist_groups';
  late Box<WatchlistGroup> _box;

  /// 저장소 초기화
  Future<void> init() async {
    if (!Hive.isAdapterRegistered(22)) {
      Hive.registerAdapter(WatchlistGroupAdapter());
    }
    _box = await Hive.openBox<WatchlistGroup>(_boxName);
  }

  /// 모든 그룹 가져오기 (sortOrder 기준 정렬)
  List<WatchlistGroup> getAll() {
    final groups = _box.values.toList();
    groups.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return groups;
  }

  /// ID로 그룹 찾기
  WatchlistGroup? getById(String id) {
    try {
      return _box.values.firstWhere((g) => g.id == id);
    } catch (_) {
      return null;
    }
  }

  /// 그룹 저장 (추가 또는 업데이트)
  Future<void> save(WatchlistGroup group) async {
    await _box.put(group.id, group);
  }

  /// 그룹 삭제
  Future<void> delete(String id) async {
    await _box.delete(id);
  }

  /// 그룹에 티커 추가
  Future<bool> addTickerToGroup(String groupId, String ticker) async {
    final group = getById(groupId);
    if (group == null) return false;
    if (group.tickers.length >= WatchlistGroup.maxTickersPerGroup) return false;
    if (group.tickers.contains(ticker)) return false;

    group.tickers.add(ticker);
    await group.save();
    return true;
  }

  /// 그룹에서 티커 제거
  Future<void> removeTickerFromGroup(String groupId, String ticker) async {
    final group = getById(groupId);
    if (group == null) return;
    group.tickers.remove(ticker);
    await group.save();
  }

  /// 그룹 탭 순서 변경
  Future<void> reorderGroups(int oldIndex, int newIndex) async {
    final groups = getAll();
    if (oldIndex < 0 || oldIndex >= groups.length) return;
    if (newIndex < 0 || newIndex >= groups.length) return;

    final group = groups.removeAt(oldIndex);
    groups.insert(newIndex, group);

    for (int i = 0; i < groups.length; i++) {
      groups[i].sortOrder = i;
      await groups[i].save();
    }
  }

  /// 그룹 내 티커 순서 변경
  Future<void> reorderTickersInGroup(
      String groupId, int oldIndex, int newIndex) async {
    final group = getById(groupId);
    if (group == null) return;
    if (oldIndex < 0 || oldIndex >= group.tickers.length) return;
    if (newIndex < 0 || newIndex >= group.tickers.length) return;

    final ticker = group.tickers.removeAt(oldIndex);
    group.tickers.insert(newIndex, ticker);
    await group.save();
  }

  /// 전체 삭제
  Future<void> clear() async {
    await _box.clear();
  }

  /// 그룹 수
  int get count => _box.length;
}
