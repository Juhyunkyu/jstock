import 'package:hive_flutter/hive_flutter.dart';
import '../models/memo.dart';

/// 메모 저장소
///
/// 자체 등록 패턴: init()에서 어댑터 등록 + Box 오픈
/// MemoListNotifier.load()에서 호출됨
class MemoRepository {
  static const String _boxName = 'memos';
  Box<Memo>? _box;

  bool get isInitialized => _box != null && _box!.isOpen;

  /// 어댑터 자체 등록 + Box 오픈
  Future<void> init() async {
    if (isInitialized) return;
    if (!Hive.isAdapterRegistered(25)) {
      Hive.registerAdapter(MemoAdapter());
    }
    if (!Hive.isAdapterRegistered(26)) {
      Hive.registerAdapter(MemoCategoryAdapter());
    }
    _box ??= await Hive.openBox<Memo>(_boxName);
  }

  /// 전체 메모 (고정 우선 → 수정일 최신순)
  List<Memo> getAll() {
    if (!isInitialized) return [];
    final items = _box!.values.map(_deepCopy).toList();
    _sortMemos(items);
    return items;
  }

  /// 정렬 (고정 우선 → 수정일 최신순)
  void _sortMemos(List<Memo> items) {
    items.sort((a, b) {
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      return b.updatedAt.compareTo(a.updatedAt);
    });
  }

  /// ID로 조회
  Memo? getById(String id) {
    if (!isInitialized) return null;
    final memo = _box!.get(id);
    return memo != null ? _deepCopy(memo) : null;
  }

  /// 저장 (추가 또는 업데이트)
  Future<void> save(Memo memo) async {
    if (!isInitialized) return;
    await _box!.put(memo.id, memo);
  }

  /// 삭제
  Future<void> delete(String id) async {
    if (!isInitialized) return;
    await _box!.delete(id);
  }

  /// 검색 (제목 + 본문, 대소문자 무시) — 필터 후 deep copy + 정렬
  List<Memo> search(String query) {
    if (!isInitialized || query.isEmpty) return getAll();
    final lower = query.toLowerCase();
    final filtered = _box!.values
        .where((m) =>
            m.title.toLowerCase().contains(lower) ||
            m.content.toLowerCase().contains(lower))
        .map(_deepCopy)
        .toList();
    _sortMemos(filtered);
    return filtered;
  }

  /// 카테고리 필터 — 필터 후 deep copy + 정렬
  List<Memo> getByCategory(MemoCategory category) {
    if (!isInitialized) return [];
    final filtered = _box!.values
        .where((m) => m.category == category)
        .map(_deepCopy)
        .toList();
    _sortMemos(filtered);
    return filtered;
  }

  /// 전체 삭제
  Future<void> clear() async {
    if (!isInitialized) return;
    await _box!.clear();
  }

  /// 메모 수
  int get count => isInitialized ? _box!.length : 0;

  /// Deep copy (Riverpod 변경 감지용 — Hive 객체 동일 참조 방지)
  Memo _deepCopy(Memo m) => Memo(
        id: m.id,
        title: m.title,
        content: m.content,
        category: m.category,
        isPinned: m.isPinned,
        customDate: m.customDate,
        imageBase64List: List<String>.from(m.imageBase64List),
        sortOrder: m.sortOrder,
        createdAt: m.createdAt,
        updatedAt: m.updatedAt,
      );
}
