import 'package:hive/hive.dart';
import '../models/trade.dart';

/// 거래 기록 데이터 저장소
class TradeRepository {
  static const String _boxName = 'trades_v3';

  Box<Trade>? _box;

  /// Box 열기
  Future<void> init() async {
    _box = await Hive.openBox<Trade>(_boxName);
  }

  /// Box 가져오기
  Box<Trade> get box {
    if (_box == null || !_box!.isOpen) {
      throw StateError('TradeRepository가 초기화되지 않았습니다. init()을 먼저 호출하세요.');
    }
    return _box!;
  }

  // ═══════════════════════════════════════════════════════════════
  // CRUD
  // ═══════════════════════════════════════════════════════════════

  /// 모든 거래 조회
  List<Trade> getAll() {
    return box.values.toList()
      ..sort((a, b) => b.tradedAt.compareTo(a.tradedAt));
  }

  /// 사이클 ID로 거래 조회
  List<Trade> getByCycleId(String cycleId) {
    return box.values
        .where((t) => t.cycleId == cycleId)
        .toList()
      ..sort((a, b) => b.tradedAt.compareTo(a.tradedAt));
  }

  /// 거래 저장
  Future<void> save(Trade trade) async {
    await box.put(trade.id, trade);
  }

  /// 거래 삭제
  Future<void> delete(String id) async {
    await box.delete(id);
  }

  /// 사이클의 모든 거래 삭제
  Future<void> deleteByCycleId(String cycleId) async {
    final trades = getByCycleId(cycleId);
    for (final trade in trades) {
      await box.delete(trade.id);
    }
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
