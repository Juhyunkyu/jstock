import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/cycle.dart';
import 'core/repository_providers.dart';

/// 사이클 목록 StateNotifier
class CycleListNotifier extends StateNotifier<List<Cycle>> {
  final Ref _ref;

  CycleListNotifier(this._ref) : super([]) {
    refresh();
  }

  /// 목록 새로고침
  void refresh() {
    try {
      final repo = _ref.read(cycleRepositoryProvider);
      state = repo.getAll()..sort((a, b) => b.startDate.compareTo(a.startDate));
    } catch (e) {
      // Repository 초기화 전
    }
  }

  /// 사이클 저장
  Future<void> save(Cycle cycle) async {
    final repo = _ref.read(cycleRepositoryProvider);
    await repo.save(cycle);
    refresh();
  }

  /// 사이클 삭제
  Future<void> delete(String id) async {
    final repo = _ref.read(cycleRepositoryProvider);
    await repo.delete(id);
    refresh();
  }

  /// 사이클 아카이브 (완료 처리)
  Future<void> archiveCycle(String id) async {
    final repo = _ref.read(cycleRepositoryProvider);
    final cycle = repo.getById(id);
    if (cycle != null) {
      cycle.archive();
      await repo.save(cycle);
      refresh();
    }
  }
}

/// 전체 사이클 목록 Provider
final cycleListProvider = StateNotifierProvider<CycleListNotifier, List<Cycle>>((ref) {
  return CycleListNotifier(ref);
});

/// 활성 사이클 목록 Provider
final activeCyclesProvider = Provider<List<Cycle>>((ref) {
  final cycles = ref.watch(cycleListProvider);
  return cycles.where((c) => c.status == CycleStatus.active).toList();
});

/// 완료된 사이클 목록 Provider
final completedCyclesProvider = Provider<List<Cycle>>((ref) {
  final cycles = ref.watch(cycleListProvider);
  return cycles
      .where((c) => c.status == CycleStatus.completed)
      .toList()
    ..sort((a, b) => (b.endDate ?? DateTime.now()).compareTo(a.endDate ?? DateTime.now()));
});

/// 취소된 사이클 목록 Provider
final cancelledCyclesProvider = Provider<List<Cycle>>((ref) {
  final cycles = ref.watch(cycleListProvider);
  return cycles.where((c) => c.status == CycleStatus.cancelled).toList();
});

/// 특정 ID의 사이클 Provider (Family)
final cycleByIdProvider = Provider.family<Cycle?, String>((ref, id) {
  final cycles = ref.watch(cycleListProvider);
  try {
    return cycles.firstWhere((c) => c.id == id);
  } catch (e) {
    return null;
  }
});

/// 특정 종목의 활성 사이클 Provider (Family)
final activeCycleByTickerProvider = Provider.family<Cycle?, String>((ref, ticker) {
  final activeCycles = ref.watch(activeCyclesProvider);
  try {
    return activeCycles.firstWhere((c) => c.ticker == ticker);
  } catch (e) {
    return null;
  }
});

/// 특정 종목의 모든 사이클 Provider (Family)
final cyclesByTickerProvider = Provider.family<List<Cycle>, String>((ref, ticker) {
  final cycles = ref.watch(cycleListProvider);
  return cycles.where((c) => c.ticker == ticker).toList()
    ..sort((a, b) => b.cycleNumber.compareTo(a.cycleNumber));
});

/// 다음 사이클 번호 Provider (Family)
final nextCycleNumberProvider = Provider.family<int, String>((ref, ticker) {
  final tickerCycles = ref.watch(cyclesByTickerProvider(ticker));
  if (tickerCycles.isEmpty) return 1;
  return tickerCycles.first.cycleNumber + 1;
});

/// 활성 사이클 수 Provider
final activeCycleCountProvider = Provider<int>((ref) {
  return ref.watch(activeCyclesProvider).length;
});

/// 완료된 사이클 수 Provider
final completedCycleCountProvider = Provider<int>((ref) {
  return ref.watch(completedCyclesProvider).length;
});

/// 포트폴리오 요약 Provider
final portfolioSummaryProvider = Provider.family<PortfolioSummary, Map<String, double>>((ref, prices) {
  final activeCycles = ref.watch(activeCyclesProvider);

  double totalInvested = 0;
  double totalValue = 0;
  double totalCash = 0;

  for (final cycle in activeCycles) {
    final price = prices[cycle.ticker] ?? cycle.averagePrice;
    totalInvested += cycle.seedAmount;
    totalValue += cycle.totalAsset(price);
    totalCash += cycle.remainingCash;
  }

  return PortfolioSummary(
    totalInvested: totalInvested,
    totalValue: totalValue,
    totalCash: totalCash,
    cycleCount: activeCycles.length,
    profitRate: totalInvested > 0 ? ((totalValue - totalInvested) / totalInvested) * 100 : 0,
  );
});

/// 포트폴리오 요약 데이터 클래스
class PortfolioSummary {
  final double totalInvested;
  final double totalValue;
  final double totalCash;
  final int cycleCount;
  final double profitRate;

  const PortfolioSummary({
    required this.totalInvested,
    required this.totalValue,
    required this.totalCash,
    required this.cycleCount,
    required this.profitRate,
  });

  double get totalProfit => totalValue - totalInvested;
  double get stockValue => totalValue - totalCash;
}
