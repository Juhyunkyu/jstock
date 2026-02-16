import 'package:hive/hive.dart';
import '../models/cycle.dart';

/// 사이클 데이터 저장소
class CycleRepository {
  static const String _boxName = 'cycles';

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

  /// 모든 사이클 조회
  List<Cycle> getAll() {
    return box.values.toList();
  }

  /// 활성 사이클만 조회
  List<Cycle> getActiveCycles() {
    return box.values
        .where((cycle) => cycle.status == CycleStatus.active)
        .toList();
  }

  /// 특정 종목의 활성 사이클 조회
  Cycle? getActiveCycleByTicker(String ticker) {
    try {
      return box.values.firstWhere(
        (cycle) => cycle.ticker == ticker && cycle.status == CycleStatus.active,
      );
    } catch (e) {
      return null;
    }
  }

  /// 특정 종목의 모든 사이클 조회
  List<Cycle> getCyclesByTicker(String ticker) {
    return box.values.where((cycle) => cycle.ticker == ticker).toList()
      ..sort((a, b) => b.cycleNumber.compareTo(a.cycleNumber));
  }

  /// ID로 사이클 조회
  Cycle? getById(String id) {
    try {
      return box.values.firstWhere((cycle) => cycle.id == id);
    } catch (e) {
      return null;
    }
  }

  /// 사이클 저장
  Future<void> save(Cycle cycle) async {
    await box.put(cycle.id, cycle);
  }

  /// 사이클 삭제
  Future<void> delete(String id) async {
    await box.delete(id);
  }

  /// 완료된 사이클 수
  int get completedCycleCount {
    return box.values
        .where((cycle) => cycle.status == CycleStatus.completed)
        .length;
  }

  /// 특정 종목의 다음 사이클 번호
  int getNextCycleNumber(String ticker) {
    final cycles = getCyclesByTicker(ticker);
    if (cycles.isEmpty) return 1;
    return cycles.first.cycleNumber + 1;
  }

  /// Box 닫기
  Future<void> close() async {
    await _box?.close();
  }
}
