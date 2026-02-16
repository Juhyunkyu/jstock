import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../data/models/holding.dart';
import '../../data/models/holding_transaction.dart';
import '../../data/repositories/holding_repository.dart';
import 'core/repository_providers.dart';
import 'settings_providers.dart';
import 'stock_providers.dart';

/// 보유 목록 상태 관리
class HoldingListNotifier extends StateNotifier<List<Holding>> {
  final HoldingRepository _repository;

  HoldingListNotifier(this._repository) : super([]) {
    _loadHoldings();
  }

  /// 보유 목록 로드
  Future<void> _loadHoldings() async {
    state = _repository.getAll();
  }

  /// 새로고침
  Future<void> refresh() async {
    state = _repository.getAll();
  }

  /// 새 보유 추가
  Future<Holding> addHolding({
    required String ticker,
    required String name,
    required double exchangeRate,
  }) async {
    final holding = Holding(
      id: const Uuid().v4(),
      ticker: ticker,
      name: name,
      exchangeRate: exchangeRate,
    );

    await _repository.save(holding);
    state = [...state, holding];
    return holding;
  }

  /// 새 보유 추가 (직접 값 설정)
  Future<Holding> addHoldingWithValues({
    required String ticker,
    required String name,
    required double purchasePrice,
    required int quantity,
    required double purchaseExchangeRate,
    String? notes,
    DateTime? startDate,
  }) async {
    final holdingId = const Uuid().v4();
    final actualStartDate = startDate ?? DateTime.now();

    final holding = Holding(
      id: holdingId,
      ticker: ticker,
      name: name,
      exchangeRate: purchaseExchangeRate,
      startDate: actualStartDate,
      notes: notes,
    );

    holding.setHoldingValues(
      purchasePrice: purchasePrice,
      quantity: quantity,
      purchaseExchangeRate: purchaseExchangeRate,
    );

    await _repository.save(holding);

    // 첫 매수 거래 내역 자동 생성
    final initialTransaction = HoldingTransaction(
      id: const Uuid().v4(),
      holdingId: holdingId,
      ticker: ticker,
      date: actualStartDate,
      type: HoldingTransactionType.buy,
      price: purchasePrice,
      shares: quantity.toDouble(),
      amountKrw: purchasePrice * quantity * purchaseExchangeRate,
      exchangeRate: purchaseExchangeRate,
      note: '첫 매수',
      isInitialPurchase: true,
    );
    await _repository.saveTransaction(initialTransaction);

    state = [...state, holding];
    return holding;
  }

  /// 보유 정보 수정 (직접 값 설정)
  Future<void> updateHoldingValues({
    required String holdingId,
    required double purchasePrice,
    required int quantity,
    required double purchaseExchangeRate,
    DateTime? startDate,
  }) async {
    final holdingIndex = state.indexWhere((h) => h.id == holdingId);
    if (holdingIndex == -1) {
      throw StateError('Holding not found: $holdingId');
    }

    // startDate를 변경하려면 새 Holding 객체 생성 필요 (final 필드)
    Holding holding;
    if (startDate != null) {
      final oldHolding = state[holdingIndex];
      holding = Holding(
        id: oldHolding.id,
        ticker: oldHolding.ticker,
        name: oldHolding.name,
        exchangeRate: purchaseExchangeRate,
        startDate: startDate,
        notes: oldHolding.notes,
        isArchived: oldHolding.isArchived,
      );
    } else {
      holding = state[holdingIndex];
    }

    holding.setHoldingValues(
      purchasePrice: purchasePrice,
      quantity: quantity,
      purchaseExchangeRate: purchaseExchangeRate,
    );

    await _repository.save(holding);
    state = [
      for (int i = 0; i < state.length; i++)
        if (i == holdingIndex) holding else state[i]
    ];
  }

  /// 평균 매입환율 수정
  Future<void> updateExchangeRate({
    required String holdingId,
    required double newExchangeRate,
  }) async {
    final holdingIndex = state.indexWhere((h) => h.id == holdingId);
    if (holdingIndex == -1) return;

    final current = state[holdingIndex];
    final updated = Holding(
      id: current.id,
      ticker: current.ticker,
      name: current.name,
      exchangeRate: newExchangeRate,
      startDate: current.startDate,
      notes: current.notes,
      isArchived: current.isArchived,
    );
    updated.totalShares = current.totalShares;
    updated.averagePrice = current.averagePrice;
    updated.totalInvestedAmount = current.averagePrice * current.totalShares * newExchangeRate;
    updated.updatedAt = DateTime.now();

    await _repository.save(updated);
    state = [
      for (int i = 0; i < state.length; i++)
        if (i == holdingIndex) updated else state[i]
    ];
  }

  /// 보유 아카이브 (완료 처리)
  Future<void> archiveHolding(String id) async {
    final holdingIndex = state.indexWhere((h) => h.id == id);
    if (holdingIndex == -1) return;
    final holding = state[holdingIndex];
    holding.archive();
    await _repository.save(holding);
    state = [...state]; // 리빌드 트리거
  }

  /// 보유 삭제
  Future<void> deleteHolding(String id) async {
    await _repository.delete(id);
    state = state.where((h) => h.id != id).toList();
  }

  /// 보유 업데이트
  Future<void> updateHolding(Holding holding) async {
    await _repository.save(holding);
    state = state.map((h) => h.id == holding.id ? holding : h).toList();
  }

  /// 매수 기록
  Future<void> recordPurchase({
    required String holdingId,
    required double price,
    required double shares,
    required DateTime date,
    String? note,
  }) async {
    final holding = state.firstWhere((h) => h.id == holdingId);
    final amountKrw = price * shares * holding.exchangeRate;

    // 거래 내역 저장
    final transaction = HoldingTransaction(
      id: const Uuid().v4(),
      holdingId: holdingId,
      ticker: holding.ticker,
      date: date,
      type: HoldingTransactionType.buy,
      price: price,
      shares: shares,
      amountKrw: amountKrw,
      exchangeRate: holding.exchangeRate,
      note: note,
    );
    await _repository.saveTransaction(transaction);

    // 거래 내역 기반으로 보유 정보 재계산 (새 객체 생성)
    await recalculateHoldingFromTransactions(holdingId);
  }

  /// 매도 기록
  Future<void> recordSale({
    required String holdingId,
    required double price,
    required double shares,
    required DateTime date,
    double? sellExchangeRate,
    double? realizedPnlKrw,
    String? note,
  }) async {
    final holding = state.firstWhere((h) => h.id == holdingId);
    final effectiveRate = sellExchangeRate ?? holding.exchangeRate;
    final amountKrw = price * shares * effectiveRate;

    // 실현손익: 사용자 입력값 우선, 없으면 자동계산
    final pnl = realizedPnlKrw ?? (price - holding.averagePrice) * shares * effectiveRate;

    // 거래 내역 저장
    final transaction = HoldingTransaction(
      id: const Uuid().v4(),
      holdingId: holdingId,
      ticker: holding.ticker,
      date: date,
      type: HoldingTransactionType.sell,
      price: price,
      shares: shares,
      amountKrw: amountKrw,
      exchangeRate: effectiveRate,
      note: note,
      realizedPnlKrw: pnl,
    );
    await _repository.saveTransaction(transaction);

    // 거래 내역 기반으로 보유 정보 재계산 (새 객체 생성)
    await recalculateHoldingFromTransactions(holdingId);
  }

  /// 거래 내역 수정
  Future<void> updateTransaction(String transactionId, {
    DateTime? date,
    double? price,
    double? shares,
    double? exchangeRate,
    double? realizedPnlKrw,
    String? note,
  }) async {
    final transactions = _repository.getAllTransactions();
    final oldTransaction = transactions.firstWhere(
      (t) => t.id == transactionId,
      orElse: () => throw StateError('Transaction not found: $transactionId'),
    );

    // 변경된 값들 계산
    final newPrice = price ?? oldTransaction.price;
    final newShares = shares ?? oldTransaction.shares;

    // holding 정보
    final holding = state.firstWhere((h) => h.id == oldTransaction.holdingId);

    // 매도 시 사용자 지정 환율 우선, 아니면 기존 환율
    final effectiveRate = oldTransaction.isSell && exchangeRate != null
        ? exchangeRate
        : (exchangeRate ?? holding.exchangeRate);
    final newAmountKrw = newPrice * newShares * effectiveRate;

    // 매도 거래인 경우 실현손익: 사용자 입력값 우선, 없으면 자동계산
    double? pnl;
    if (oldTransaction.isSell) {
      pnl = realizedPnlKrw ?? (newPrice - holding.averagePrice) * newShares * effectiveRate;
    }

    // HoldingTransaction은 final 필드이므로 새 객체 생성
    final updatedTransaction = HoldingTransaction(
      id: oldTransaction.id,
      holdingId: oldTransaction.holdingId,
      ticker: oldTransaction.ticker,
      date: date ?? oldTransaction.date,
      type: oldTransaction.type,
      price: newPrice,
      shares: newShares,
      amountKrw: newAmountKrw,
      exchangeRate: effectiveRate,
      note: note ?? oldTransaction.note,
      isInitialPurchase: oldTransaction.isInitialPurchase,
      realizedPnlKrw: pnl,
    );

    await _repository.saveTransaction(updatedTransaction);

    // 거래 내역 변경 후 보유 정보 재계산
    await recalculateHoldingFromTransactions(oldTransaction.holdingId);
  }

  /// 거래 내역에서 보유 정보 재계산
  /// 모든 거래를 기반으로 totalShares, averagePrice, totalInvestedAmount를 재계산
  Future<void> recalculateHoldingFromTransactions(String holdingId) async {
    final transactions = _repository.getTransactionsByHoldingId(holdingId);

    if (transactions.isEmpty) {
      // 거래 내역이 없으면 보유 정보를 0으로 초기화
      final holdingIndex = state.indexWhere((h) => h.id == holdingId);
      if (holdingIndex == -1) return;

      final currentHolding = state[holdingIndex];
      final updatedHolding = Holding(
        id: currentHolding.id,
        ticker: currentHolding.ticker,
        name: currentHolding.name,
        exchangeRate: currentHolding.exchangeRate,
        startDate: currentHolding.startDate,
        notes: currentHolding.notes,
        isArchived: currentHolding.isArchived,
      );
      // Holding 생성자에서 totalShares=0, averagePrice=0, totalInvestedAmount=0 초기화
      updatedHolding.updatedAt = DateTime.now();

      await _repository.save(updatedHolding);
      state = [
        for (int i = 0; i < state.length; i++)
          if (i == holdingIndex) updatedHolding else state[i]
      ];
      return;
    }

    // 거래 내역에서 값 계산
    double totalShares = 0;
    DateTime? earliestDate;

    for (final tx in transactions) {
      if (tx.isBuy) {
        totalShares += tx.shares;
      } else {
        totalShares -= tx.shares;
      }

      // 가장 빠른 날짜 추적
      if (earliestDate == null || tx.date.isBefore(earliestDate)) {
        earliestDate = tx.date;
      }
    }

    // 평균 매입가 계산 (매수 거래만 기준)
    final buyTransactions = transactions.where((tx) => tx.isBuy).toList();
    double avgPrice = 0;
    if (buyTransactions.isNotEmpty) {
      double totalBuyShares = 0;
      double weightedSum = 0;
      for (final tx in buyTransactions) {
        totalBuyShares += tx.shares;
        weightedSum += tx.price * tx.shares;
      }
      if (totalBuyShares > 0) {
        avgPrice = weightedSum / totalBuyShares;
      }
    }

    // 보유 정보 업데이트
    final holdingIndex = state.indexWhere((h) => h.id == holdingId);
    if (holdingIndex == -1) return;

    final currentHolding = state[holdingIndex];

    // startDate도 함께 업데이트
    final updatedHolding = Holding(
      id: currentHolding.id,
      ticker: currentHolding.ticker,
      name: currentHolding.name,
      exchangeRate: currentHolding.exchangeRate,
      startDate: earliestDate ?? currentHolding.startDate,
      notes: currentHolding.notes,
      isArchived: currentHolding.isArchived,
    );

    // 계산된 값 설정 — totalInvestedAmount는 holding.exchangeRate로 일괄 계산
    updatedHolding.totalShares = totalShares;
    updatedHolding.averagePrice = avgPrice;
    updatedHolding.totalInvestedAmount = avgPrice * totalShares * currentHolding.exchangeRate;
    updatedHolding.updatedAt = DateTime.now();

    await _repository.save(updatedHolding);
    state = [
      for (int i = 0; i < state.length; i++)
        if (i == holdingIndex) updatedHolding else state[i]
    ];
  }

  /// 거래 내역 삭제
  ///
  /// 삭제 후 해당 보유의 totalShares, averagePrice, totalInvestedAmount를
  /// 남은 거래 내역 기준으로 재계산합니다.
  Future<void> deleteTransaction(String transactionId) async {
    // 삭제 전에 holdingId를 조회 (삭제 후에는 조회 불가)
    final transactions = _repository.getAllTransactions();
    final transaction = transactions.firstWhere(
      (t) => t.id == transactionId,
      orElse: () => throw StateError('Transaction not found: $transactionId'),
    );
    final holdingId = transaction.holdingId;

    // 거래 내역 삭제
    await _repository.deleteTransaction(transactionId);

    // 남은 거래 내역으로 보유 정보 재계산
    await recalculateHoldingFromTransactions(holdingId);
  }
}

/// 보유 목록 Provider
final holdingListProvider =
    StateNotifierProvider<HoldingListNotifier, List<Holding>>((ref) {
  final repository = ref.watch(holdingRepositoryProvider);
  return HoldingListNotifier(repository);
});

/// 활성 보유만 (아카이브 안 된 항목 — 0주 포함)
final activeHoldingsProvider = Provider<List<Holding>>((ref) {
  final holdings = ref.watch(holdingListProvider);
  return holdings.where((h) => h.isArchived != true).toList();
});

/// 아카이브된 보유 목록
final archivedHoldingsProvider = Provider<List<Holding>>((ref) {
  final holdings = ref.watch(holdingListProvider);
  return holdings.where((h) => h.isArchived == true).toList()
    ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
});

/// ID로 보유 조회
final holdingByIdProvider = Provider.family<Holding?, String>((ref, id) {
  final holdings = ref.watch(holdingListProvider);
  try {
    return holdings.firstWhere((h) => h.id == id);
  } catch (e) {
    return null;
  }
});

/// 티커로 보유 조회
final holdingByTickerProvider = Provider.family<Holding?, String>((ref, ticker) {
  final holdings = ref.watch(holdingListProvider);
  try {
    return holdings.firstWhere((h) => h.ticker == ticker);
  } catch (e) {
    return null;
  }
});

/// 보유 종목 수
final holdingCountProvider = Provider<int>((ref) {
  return ref.watch(activeHoldingsProvider).length;
});

/// 보유 총 투자금액 (KRW)
final holdingTotalInvestedProvider = Provider<double>((ref) {
  final holdings = ref.watch(activeHoldingsProvider);
  return holdings.fold(0.0, (sum, h) => sum + h.totalInvestedAmount);
});

/// 보유 총 현재가치 (KRW) - 현재가 필요
final holdingTotalValueProvider = Provider.family<double, Map<String, double>>((ref, prices) {
  final holdings = ref.watch(activeHoldingsProvider);
  return holdings.fold(0.0, (sum, h) {
    final price = prices[h.ticker] ?? h.averagePrice;
    return sum + h.currentValue(price);
  });
});

/// 보유 총 손익 (KRW)
final holdingTotalProfitProvider = Provider.family<double, Map<String, double>>((ref, prices) {
  final holdings = ref.watch(activeHoldingsProvider);
  return holdings.fold(0.0, (sum, h) {
    final price = prices[h.ticker] ?? h.averagePrice;
    return sum + h.profitLoss(price);
  });
});

/// 보유와 현재가 결합 데이터
class HoldingWithPrice {
  final Holding holding;
  final double currentPrice;
  final double currentExchangeRate;

  HoldingWithPrice({
    required this.holding,
    required this.currentPrice,
    required this.currentExchangeRate,
  });

  /// 현재 평가금액 (KRW, 현재환율 기준)
  double get currentValue => holding.totalShares * currentPrice * currentExchangeRate;

  /// 순수 손익 (USD, 환차 미포함)
  double get usdProfitLoss => holding.usdProfitLoss(currentPrice);

  /// 순수 손익 (KRW, 환차 미포함) = USD 손익 * 현재환율
  double get profitLoss => usdProfitLoss * currentExchangeRate;

  /// 순수 수익률 (%, 환차 미포함)
  double get returnRate => holding.usdReturnRate(currentPrice);
}

/// 보유 + 현재가 Provider
final holdingsWithPriceProvider = Provider<List<HoldingWithPrice>>((ref) {
  final holdings = ref.watch(activeHoldingsProvider);
  final prices = ref.watch(currentPricesProvider);
  final settings = ref.watch(settingsProvider);
  final exchangeRate = settings.exchangeRate;

  return holdings.map((h) {
    final price = prices[h.ticker] ?? h.averagePrice;
    return HoldingWithPrice(
      holding: h,
      currentPrice: price,
      currentExchangeRate: exchangeRate,
    );
  }).toList();
});

/// 거래 내역 리프레시 트리거
/// 이 값이 변경되면 holdingTransactionsProvider가 다시 로드됨
final transactionRefreshProvider = StateProvider<int>((ref) => 0);

/// 거래 내역 리프레시 함수
void refreshTransactions(WidgetRef ref) {
  ref.read(transactionRefreshProvider.notifier).state++;
}

/// 특정 보유의 거래 내역 조회
final holdingTransactionsProvider = Provider.family<List<HoldingTransaction>, String>((ref, holdingId) {
  // refresh 트리거 watch - 이 값이 변경되면 provider가 다시 실행됨
  ref.watch(transactionRefreshProvider);

  final repository = ref.watch(holdingRepositoryProvider);
  return repository.getTransactionsByHoldingId(holdingId);
});

