import 'package:hive/hive.dart';
import '../models/cycle.dart';

/// 사이클 데이터 저장소
class CycleRepository {
  static const String _boxName = 'cycles_v3';

  Box<Cycle>? _box;

  /// Box 열기
  Future<void> init() async {
    _box = await Hive.openBox<Cycle>(_boxName);
  }

  /// Box 가져오기
  Box<Cycle> get box {
    if (_box == null || !_box!.isOpen) {
      throw StateError('CycleRepository가 초기화되지 않았습니다. init()을 먼저 호출하세요.');
    }
    return _box!;
  }

  // ═══════════════════════════════════════════════════════════════
  // CRUD
  // ═══════════════════════════════════════════════════════════════

  /// 모든 사이클 조회
  List<Cycle> getAll() {
    return box.values.toList();
  }

  /// 활성 사이클만 조회
  List<Cycle> getActiveCycles() {
    return box.values.where((c) => c.status == CycleStatus.active).toList();
  }

  /// 완료된 사이클 조회
  List<Cycle> getCompletedCycles() {
    return box.values.where((c) => c.status == CycleStatus.completed).toList();
  }

  /// ID로 사이클 조회
  Cycle? getById(String id) {
    try {
      return box.values.firstWhere((c) => c.id == id);
    } catch (e) {
      return null;
    }
  }

  /// 티커로 활성 사이클 조회
  List<Cycle> getByTicker(String ticker) {
    return box.values.where((c) => c.ticker == ticker).toList();
  }

  /// 사이클 저장
  Future<void> save(Cycle cycle) async {
    await box.put(cycle.id, cycle);
  }

  /// 사이클 삭제
  Future<void> delete(String id) async {
    await box.delete(id);
  }

  /// 전체 삭제
  Future<void> clearAll() async {
    await box.clear();
  }

  /// Box 닫기
  Future<void> close() async {
    await _box?.close();
  }
}
