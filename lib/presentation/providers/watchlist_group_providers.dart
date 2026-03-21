import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../data/models/watchlist_group.dart';
import '../../data/models/recent_view_item.dart';
import '../../data/repositories/watchlist_group_repository.dart';
import '../../data/repositories/recent_view_repository.dart';
import 'core/repository_providers.dart';

// ═══════════════════════════════════════════════════════════════
// 그룹 상태 관리
// ═══════════════════════════════════════════════════════════════

class WatchlistGroupState {
  final List<WatchlistGroup> groups;
  final bool isLoading;

  const WatchlistGroupState({
    this.groups = const [],
    this.isLoading = true,
  });

  WatchlistGroupState copyWith({
    List<WatchlistGroup>? groups,
    bool? isLoading,
  }) {
    return WatchlistGroupState(
      groups: groups ?? this.groups,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class WatchlistGroupNotifier extends StateNotifier<WatchlistGroupState> {
  final WatchlistGroupRepository _repository;

  WatchlistGroupNotifier(this._repository)
      : super(const WatchlistGroupState());

  /// 초기 로드 (Repository는 appInitializationProvider에서 이미 init됨)
  Future<void> load() async {
    if (!mounted) return;
    state = state.copyWith(isLoading: true);
    final groups = _repository.getAll().map((g) => WatchlistGroup(
      id: g.id,
      name: g.name,
      tickers: List<String>.from(g.tickers),
      sortOrder: g.sortOrder,
      createdAt: g.createdAt,
    )).toList();
    if (!mounted) return;
    state = state.copyWith(groups: groups, isLoading: false);
  }

  /// 그룹 생성
  Future<void> createGroup(String name) async {
    final group = WatchlistGroup(
      id: const Uuid().v4(),
      name: name,
      sortOrder: state.groups.length,
    );
    await _repository.save(group);
    _reload();
  }

  /// 그룹 삭제
  Future<void> deleteGroup(String id) async {
    await _repository.delete(id);
    _reload();
  }

  /// 그룹 이름 변경
  Future<void> renameGroup(String id, String name) async {
    final group = _repository.getById(id);
    if (group == null) return;
    group.name = name;
    await group.save();
    _reload();
  }

  /// 그룹에 티커 추가
  Future<bool> addTicker(String groupId, String ticker) async {
    final success = await _repository.addTickerToGroup(groupId, ticker);
    if (success) _reload();
    return success;
  }

  /// 그룹에서 티커 제거
  Future<void> removeTicker(String groupId, String ticker) async {
    await _repository.removeTickerFromGroup(groupId, ticker);
    _reload();
  }

  /// 그룹 탭 순서 변경
  Future<void> reorderGroups(int oldIndex, int newIndex) async {
    int actual = newIndex;
    if (oldIndex < newIndex) actual = newIndex - 1;
    await _repository.reorderGroups(oldIndex, actual);
    _reload();
  }

  /// 그룹 내 티커 순서 변경
  Future<void> reorderTickers(
      String groupId, int oldIndex, int newIndex) async {
    int actual = newIndex;
    if (oldIndex < newIndex) actual = newIndex - 1;
    await _repository.reorderTickersInGroup(groupId, oldIndex, actual);
    _reload();
  }

  void _reload() {
    if (!mounted) return;
    // Deep copy to break Hive object identity — ensures Riverpod detects changes
    final freshGroups = _repository.getAll().map((g) => WatchlistGroup(
      id: g.id,
      name: g.name,
      tickers: List<String>.from(g.tickers),
      sortOrder: g.sortOrder,
      createdAt: g.createdAt,
    )).toList();
    state = state.copyWith(groups: freshGroups);
  }
}

final watchlistGroupProvider =
    StateNotifierProvider<WatchlistGroupNotifier, WatchlistGroupState>((ref) {
  final repository = ref.watch(watchlistGroupRepositoryProvider);
  return WatchlistGroupNotifier(repository);
});

// ═══════════════════════════════════════════════════════════════
// 최근 조회 상태 관리
// ═══════════════════════════════════════════════════════════════

class RecentViewNotifier extends StateNotifier<List<RecentViewItem>> {
  final RecentViewRepository _repository;

  RecentViewNotifier(this._repository) : super([]);

  /// 초기 로드 (Repository는 appInitializationProvider에서 이미 init됨)
  Future<void> load() async {
    if (!mounted) return;
    state = _filteredItems();
  }

  List<RecentViewItem> _filteredItems() =>
      _repository.getAll()
          .where((item) => !item.ticker.startsWith('^'))
          .toList();

  /// 조회 기록 (지수 심볼은 기록하지 않음)
  Future<void> recordView({
    required String ticker,
    required String name,
    String exchange = '',
    String type = '',
  }) async {
    if (ticker.startsWith('^')) return;
    await _repository.recordView(RecentViewItem(
      ticker: ticker,
      name: name,
      exchange: exchange,
      type: type,
    ));
    if (!mounted) return;
    state = _filteredItems();
  }

  /// 삭제
  Future<void> remove(String ticker) async {
    await _repository.remove(ticker);
    if (!mounted) return;
    state = _filteredItems();
  }

  /// 전체 삭제
  Future<void> clearAll() async {
    await _repository.clear();
    if (!mounted) return;
    state = [];
  }
}

final recentViewProvider =
    StateNotifierProvider<RecentViewNotifier, List<RecentViewItem>>((ref) {
  final repository = ref.watch(recentViewRepositoryProvider);
  return RecentViewNotifier(repository);
});

// ═══════════════════════════════════════════════════════════════
// 파생 Provider
// ═══════════════════════════════════════════════════════════════

/// 특정 티커가 사용자 그룹에 포함되어 있는지 확인
final isTickerInAnyGroupProvider = Provider.family<bool, String>((ref, ticker) {
  final groupState = ref.watch(watchlistGroupProvider);
  return groupState.groups.any((g) => g.containsTicker(ticker));
});

// ═══════════════════════════════════════════════════════════════
// 현재 선택된 탭 인덱스
// ═══════════════════════════════════════════════════════════════

final selectedWatchlistTabProvider = StateProvider<int>((ref) => 0);
