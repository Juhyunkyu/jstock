import 'package:hive/hive.dart';
import '../models/holding.dart';
import '../models/holding_transaction.dart';

/// 보유 주식 데이터 저장소
class HoldingRepository {
  static const String _holdingBoxName = 'holdings';
  static const String _transactionBoxName = 'holding_transactions';

  Box<Holding>? _holdingBox;
  Box<HoldingTransaction>? _transactionBox;

  /// Box 열기
  Future<void> init() async {
    _holdingBox = await Hive.openBox<Holding>(_holdingBoxName);
    _transactionBox = await Hive.openBox<HoldingTransaction>(_transactionBoxName);
  }

  /// Holding Box 가져오기
  Box<Holding> get holdingBox {
    if (_holdingBox == null || !_holdingBox!.isOpen) {
      throw StateError('HoldingRepository가 초기화되지 않았습니다. init()을 먼저 호출하세요.');
    }
    return _holdingBox!;
  }

  /// Transaction Box 가져오기
  Box<HoldingTransaction> get transactionBox {
    if (_transactionBox == null || !_transactionBox!.isOpen) {
      throw StateError('HoldingRepository가 초기화되지 않았습니다. init()을 먼저 호출하세요.');
    }
    return _transactionBox!;
  }

  // ═══════════════════════════════════════════════════════════════
  // Holding CRUD
  // ═══════════════════════════════════════════════════════════════

  /// 모든 보유 조회
  List<Holding> getAll() {
    return holdingBox.values.toList();
  }

  /// 활성 보유만 조회 (수량 > 0)
  List<Holding> getActiveHoldings() {
    return holdingBox.values.where((h) => h.totalShares > 0).toList();
  }

  /// ID로 보유 조회
  Holding? getById(String id) {
    try {
      return holdingBox.values.firstWhere((h) => h.id == id);
    } catch (e) {
      return null;
    }
  }

  /// 티커로 보유 조회
  Holding? getByTicker(String ticker) {
    try {
      return holdingBox.values.firstWhere((h) => h.ticker == ticker);
    } catch (e) {
      return null;
    }
  }

  /// 보유 저장
  Future<void> save(Holding holding) async {
    await holdingBox.put(holding.id, holding);
  }

  /// 보유 삭제
  Future<void> delete(String id) async {
    await holdingBox.delete(id);
  }

  // ═══════════════════════════════════════════════════════════════
  // Transaction CRUD
  // ═══════════════════════════════════════════════════════════════

  /// 모든 거래 조회
  List<HoldingTransaction> getAllTransactions() {
    return transactionBox.values.toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  /// 특정 보유의 거래 조회
  List<HoldingTransaction> getTransactionsByHoldingId(String holdingId) {
    return transactionBox.values
        .where((t) => t.holdingId == holdingId)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  /// 티커별 거래 조회
  List<HoldingTransaction> getTransactionsByTicker(String ticker) {
    return transactionBox.values
        .where((t) => t.ticker == ticker)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  /// 거래 저장
  Future<void> saveTransaction(HoldingTransaction transaction) async {
    await transactionBox.put(transaction.id, transaction);
  }

  /// 거래 삭제
  Future<void> deleteTransaction(String id) async {
    await transactionBox.delete(id);
  }

  // ═══════════════════════════════════════════════════════════════
  // 통계
  // ═══════════════════════════════════════════════════════════════

  /// 총 보유 종목 수
  int get holdingCount => holdingBox.values.where((h) => h.totalShares > 0).length;

  /// 총 투자 금액 (KRW)
  double get totalInvestedAmount {
    return holdingBox.values.fold(0.0, (sum, h) => sum + h.totalInvestedAmount);
  }

  /// Box 닫기
  Future<void> close() async {
    await _holdingBox?.close();
    await _transactionBox?.close();
  }
}
