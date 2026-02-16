import 'package:hive/hive.dart';
import '../models/trade.dart';

/// 거래 기록 저장소
class TradeRepository {
  static const String _boxName = 'trades';

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

  /// 모든 거래 조회
  List<Trade> getAll() {
    return box.values.toList()..sort((a, b) => b.date.compareTo(a.date));
  }

  /// 특정 사이클의 거래 조회
  List<Trade> getByCycleId(String cycleId) {
    return box.values
        .where((trade) => trade.cycleId == cycleId)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  /// 특정 종목의 거래 조회
  List<Trade> getByTicker(String ticker) {
    return box.values
        .where((trade) => trade.ticker == ticker)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  /// 미체결 거래 조회
  List<Trade> getUnexecuted() {
    return box.values.where((trade) => !trade.isExecuted).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  /// 특정 날짜의 거래 조회
  List<Trade> getByDate(DateTime date) {
    return box.values
        .where((trade) =>
            trade.date.year == date.year &&
            trade.date.month == date.month &&
            trade.date.day == date.day)
        .toList();
  }

  /// 특정 기간의 거래 조회
  List<Trade> getByDateRange(DateTime start, DateTime end) {
    return box.values
        .where((trade) =>
            trade.date.isAfter(start.subtract(const Duration(days: 1))) &&
            trade.date.isBefore(end.add(const Duration(days: 1))))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  /// ID로 거래 조회
  Trade? getById(String id) {
    try {
      return box.values.firstWhere((trade) => trade.id == id);
    } catch (e) {
      return null;
    }
  }

  /// 거래 저장
  Future<void> save(Trade trade) async {
    await box.put(trade.id, trade);
  }

  /// 거래 삭제
  Future<void> delete(String id) async {
    await box.delete(id);
  }

  /// 통계: 권장 금액 총합
  double get totalRecommendedAmount {
    return box.values.fold(0.0, (sum, trade) => sum + trade.recommendedAmount);
  }

  /// 통계: 실투자 금액 총합
  double get totalActualAmount {
    return box.values
        .where((trade) => trade.actualAmount != null)
        .fold(0.0, (sum, trade) => sum + trade.actualAmount!);
  }

  /// 통계: 거래 유형별 카운트
  Map<TradeAction, int> get tradeCountByAction {
    final counts = <TradeAction, int>{};
    for (final trade in box.values) {
      counts[trade.action] = (counts[trade.action] ?? 0) + 1;
    }
    return counts;
  }

  /// Box 닫기
  Future<void> close() async {
    await _box?.close();
  }
}
