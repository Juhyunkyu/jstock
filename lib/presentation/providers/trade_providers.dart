import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/trade.dart';
import 'core/repository_providers.dart';

/// 거래 목록 StateNotifier
class TradeListNotifier extends StateNotifier<List<Trade>> {
  final Ref _ref;

  TradeListNotifier(this._ref) : super([]) {
    refresh();
  }

  /// 목록 새로고침
  void refresh() {
    try {
      final repo = _ref.read(tradeRepositoryProvider);
      state = repo.getAll();
    } catch (e) {
      // Repository 초기화 전
    }
  }

  /// 거래 저장
  Future<void> save(Trade trade) async {
    final repo = _ref.read(tradeRepositoryProvider);
    await repo.save(trade);
    refresh();
  }

  /// 거래 체결 처리
  Future<void> markAsExecuted(String tradeId, double actualAmount) async {
    final repo = _ref.read(tradeRepositoryProvider);
    final trade = repo.getById(tradeId);
    if (trade != null) {
      trade.markAsExecuted(actualAmount);
      await repo.save(trade);
      refresh();
    }
  }

  /// 거래 삭제
  Future<void> delete(String id) async {
    final repo = _ref.read(tradeRepositoryProvider);
    await repo.delete(id);
    refresh();
  }
}

/// 전체 거래 목록 Provider
final tradeListProvider = StateNotifierProvider<TradeListNotifier, List<Trade>>((ref) {
  return TradeListNotifier(ref);
});

/// 특정 사이클의 거래 Provider (Family)
final tradesForCycleProvider = Provider.family<List<Trade>, String>((ref, cycleId) {
  final trades = ref.watch(tradeListProvider);
  return trades.where((t) => t.cycleId == cycleId).toList()
    ..sort((a, b) => b.date.compareTo(a.date));
});

/// 특정 종목의 거래 Provider (Family)
final tradesForTickerProvider = Provider.family<List<Trade>, String>((ref, ticker) {
  final trades = ref.watch(tradeListProvider);
  return trades.where((t) => t.ticker == ticker).toList()
    ..sort((a, b) => b.date.compareTo(a.date));
});

/// 미체결 거래 Provider
final unexecutedTradesProvider = Provider<List<Trade>>((ref) {
  final trades = ref.watch(tradeListProvider);
  return trades.where((t) => !t.isExecuted).toList()
    ..sort((a, b) => b.date.compareTo(a.date));
});

/// 거래 유형별 필터 Provider (Family)
final tradesByActionProvider = Provider.family<List<Trade>, TradeAction?>((ref, action) {
  final trades = ref.watch(tradeListProvider);
  if (action == null) return trades;
  return trades.where((t) => t.action == action).toList();
});

/// 날짜별 그룹화된 거래 Provider
final groupedTradesProvider = Provider<Map<DateTime, List<Trade>>>((ref) {
  final trades = ref.watch(tradeListProvider);
  final grouped = <DateTime, List<Trade>>{};

  for (final trade in trades) {
    final dateKey = DateTime(trade.date.year, trade.date.month, trade.date.day);
    grouped.putIfAbsent(dateKey, () => []).add(trade);
  }

  // 각 그룹 내 정렬
  for (final entry in grouped.entries) {
    entry.value.sort((a, b) => b.date.compareTo(a.date));
  }

  return grouped;
});

/// 날짜별 그룹화된 거래 (필터 적용) Provider (Family)
final filteredGroupedTradesProvider = Provider.family<Map<DateTime, List<Trade>>, TradeAction?>((ref, action) {
  final trades = ref.watch(tradesByActionProvider(action));
  final grouped = <DateTime, List<Trade>>{};

  for (final trade in trades) {
    final dateKey = DateTime(trade.date.year, trade.date.month, trade.date.day);
    grouped.putIfAbsent(dateKey, () => []).add(trade);
  }

  // 각 그룹 내 정렬
  for (final entry in grouped.entries) {
    entry.value.sort((a, b) => b.date.compareTo(a.date));
  }

  return grouped;
});

/// 특정 기간의 거래 Provider
final tradesInRangeProvider = Provider.family<List<Trade>, DateRange>((ref, range) {
  final trades = ref.watch(tradeListProvider);
  return trades
      .where((t) =>
          t.date.isAfter(range.start.subtract(const Duration(days: 1))) &&
          t.date.isBefore(range.end.add(const Duration(days: 1))))
      .toList()
    ..sort((a, b) => b.date.compareTo(a.date));
});

/// 거래 통계 Provider
final tradeStatisticsProvider = Provider<TradeStatistics>((ref) {
  final trades = ref.watch(tradeListProvider);

  double totalRecommended = 0;
  double totalActual = 0;
  final countByAction = <TradeAction, int>{};

  for (final trade in trades) {
    totalRecommended += trade.recommendedAmount;
    if (trade.actualAmount != null) {
      totalActual += trade.actualAmount!;
    }
    countByAction[trade.action] = (countByAction[trade.action] ?? 0) + 1;
  }

  return TradeStatistics(
    totalCount: trades.length,
    totalRecommendedAmount: totalRecommended,
    totalActualAmount: totalActual,
    countByAction: countByAction,
    executedCount: trades.where((t) => t.isExecuted).length,
    pendingCount: trades.where((t) => !t.isExecuted).length,
  );
});

/// 특정 사이클의 거래 수 Provider (Family)
final tradeCountForCycleProvider = Provider.family<int, String>((ref, cycleId) {
  return ref.watch(tradesForCycleProvider(cycleId)).length;
});

/// 날짜 범위 데이터 클래스
class DateRange {
  final DateTime start;
  final DateTime end;

  const DateRange({required this.start, required this.end});
}

/// 거래 통계 데이터 클래스
class TradeStatistics {
  final int totalCount;
  final double totalRecommendedAmount;
  final double totalActualAmount;
  final Map<TradeAction, int> countByAction;
  final int executedCount;
  final int pendingCount;

  const TradeStatistics({
    required this.totalCount,
    required this.totalRecommendedAmount,
    required this.totalActualAmount,
    required this.countByAction,
    required this.executedCount,
    required this.pendingCount,
  });

  int get initialBuyCount => countByAction[TradeAction.initialBuy] ?? 0;
  int get weightedBuyCount => countByAction[TradeAction.weightedBuy] ?? 0;
  int get panicBuyCount => countByAction[TradeAction.panicBuy] ?? 0;
  int get takeProfitCount => countByAction[TradeAction.takeProfit] ?? 0;

  double get executionRate => totalCount > 0 ? (executedCount / totalCount) * 100 : 0;
}
