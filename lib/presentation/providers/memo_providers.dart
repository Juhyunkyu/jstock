import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/memo.dart';
import '../../data/repositories/memo_repository.dart';

/// Memo Repository Provider
final memoRepositoryProvider = Provider<MemoRepository>((ref) {
  return MemoRepository();
});

/// 정렬 방식
enum MemoSortOrder { newest, oldest }

/// 메모 목록 상태
class MemoListState {
  final List<Memo> memos;
  final bool isLoading;
  final String searchQuery;
  final MemoCategory? filterCategory;
  final MemoSortOrder sortOrder;

  const MemoListState({
    this.memos = const [],
    this.isLoading = false,
    this.searchQuery = '',
    this.filterCategory,
    this.sortOrder = MemoSortOrder.newest,
  });

  MemoListState copyWith({
    List<Memo>? memos,
    bool? isLoading,
    String? searchQuery,
    MemoCategory? Function()? filterCategory,
    MemoSortOrder? sortOrder,
  }) {
    return MemoListState(
      memos: memos ?? this.memos,
      isLoading: isLoading ?? this.isLoading,
      searchQuery: searchQuery ?? this.searchQuery,
      filterCategory:
          filterCategory != null ? filterCategory() : this.filterCategory,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}

/// 메모 목록 Notifier (수동 load 패턴)
class MemoListNotifier extends StateNotifier<MemoListState> {
  final MemoRepository _repository;

  MemoListNotifier(this._repository) : super(const MemoListState());

  /// 초기 로드 — repository.init() + 데이터 로드
  Future<void> load() async {
    state = state.copyWith(isLoading: true);
    await _repository.init();
    _applyFilters();
    state = state.copyWith(isLoading: false);
  }

  /// 메모 저장 (추가 또는 수정)
  Future<void> save(Memo memo) async {
    await _repository.save(memo);
    _applyFilters();
  }

  /// 메모 삭제
  Future<void> delete(String id) async {
    await _repository.delete(id);
    _applyFilters();
  }

  /// 고정 토글
  Future<void> togglePin(String id) async {
    final memo = _repository.getById(id);
    if (memo == null) return;
    memo.isPinned = !memo.isPinned;
    memo.updatedAt = DateTime.now();
    await _repository.save(memo);
    _applyFilters();
  }

  /// 드래그 정렬 순서 변경
  Future<void> reorder(int oldIndex, int newIndex) async {
    final memos = List<Memo>.from(state.memos);
    if (oldIndex < 0 || oldIndex >= memos.length) return;
    if (newIndex < 0 || newIndex > memos.length) return;
    if (newIndex > oldIndex) newIndex--;

    final item = memos.removeAt(oldIndex);
    memos.insert(newIndex, item);

    // sortOrder 재할당
    for (int i = 0; i < memos.length; i++) {
      final m = _repository.getById(memos[i].id);
      if (m != null && m.sortOrder != i) {
        m.sortOrder = i;
        await _repository.save(m);
      }
    }
    _applyFilters();
  }

  /// 검색어 설정
  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
    _applyFilters();
  }

  /// 카테고리 필터 설정 (null = 전체)
  void setFilterCategory(MemoCategory? category) {
    state = state.copyWith(filterCategory: () => category);
    _applyFilters();
  }

  /// 정렬 순서 토글
  void toggleSortOrder() {
    final next = state.sortOrder == MemoSortOrder.newest
        ? MemoSortOrder.oldest
        : MemoSortOrder.newest;
    state = state.copyWith(sortOrder: next);
    _applyFilters();
  }

  /// 필터/검색/정렬 적용
  void _applyFilters() {
    List<Memo> result;

    if (state.searchQuery.isNotEmpty) {
      result = _repository.search(state.searchQuery);
    } else if (state.filterCategory != null) {
      result = _repository.getByCategory(state.filterCategory!);
    } else {
      result = _repository.getAll();
    }

    // 정렬 방향 적용 (getAll은 기본 newest)
    if (state.sortOrder == MemoSortOrder.oldest) {
      // 고정 그룹 내에서만 역순
      final pinned = result.where((m) => m.isPinned).toList();
      final unpinned = result.where((m) => !m.isPinned).toList().reversed.toList();
      result = [...pinned, ...unpinned];
    }

    state = state.copyWith(memos: result);
  }
}

/// 메모 목록 Provider
final memoListProvider =
    StateNotifierProvider<MemoListNotifier, MemoListState>((ref) {
  final repository = ref.watch(memoRepositoryProvider);
  return MemoListNotifier(repository);
});

/// 총 메모 수 Provider
final memoCountProvider = Provider<int>((ref) {
  return ref.watch(memoRepositoryProvider).count;
});
