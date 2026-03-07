import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../data/models/cycle.dart';
import '../../data/models/trade.dart';
import '../../data/repositories/cycle_repository.dart';
import '../../data/repositories/trade_repository.dart';
import '../../domain/trading/alpha_cycle_service.dart';
import '../../domain/trading/infinite_buy_service.dart';
import '../../domain/trading/trading_math.dart';
import 'core/repository_providers.dart';
import 'stock_providers.dart';
import 'api_providers.dart';

// === 사이클 목록 ===

final cycleListProvider =
    StateNotifierProvider<CycleListNotifier, List<Cycle>>((ref) {
  final repo = ref.watch(cycleRepositoryProvider);
  final tradeRepo = ref.watch(tradeRepositoryProvider);
  return CycleListNotifier(ref, repo, tradeRepo);
});

/// HoldingListNotifier 패턴: 생성자에서 자동 로드, invalidate만으로 갱신 가능
class CycleListNotifier extends StateNotifier<List<Cycle>> {
  final Ref _ref;
  final CycleRepository _repository;
  final TradeRepository _tradeRepository;

  CycleListNotifier(this._ref, this._repository, this._tradeRepository)
      : super([]) {
    _loadCycles();
  }

  void _loadCycles() {
    state = _repository.getAll();
  }

  Future<void> refresh() async {
    state = _repository.getAll();
  }

  Cycle? getCycle(String id) {
    try {
      return state.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  /// 새 사이클 추가
  Future<Cycle> addCycle({
    required String ticker,
    required String name,
    required double seedAmount,
    required double exchangeRate,
    required StrategyType strategyType,
    // Strategy A 커스텀 파라미터
    double initialEntryRatio = 0.20,
    double weightedBuyThreshold = -20.0,
    double weightedBuyDivisor = 1000.0,
    double panicBuyThreshold = -50.0,
    double panicBuyMultiplier = 0.50,
    double firstProfitTarget = 30.0,
    double profitTargetStep = 5.0,
    double minProfitTarget = 10.0,
    double cashSecureRatio = 0.3333,
    // Strategy B 커스텀 파라미터
    double takeProfitPercent = 10.0,
    int totalRounds = 40,
  }) async {
    final cycle = Cycle(
      id: const Uuid().v4(),
      ticker: ticker,
      name: name,
      seedAmount: seedAmount,
      exchangeRateAtEntry: exchangeRate,
      strategyType: strategyType,
      initialEntryRatio: initialEntryRatio,
      weightedBuyThreshold: weightedBuyThreshold,
      weightedBuyDivisor: weightedBuyDivisor,
      panicBuyThreshold: panicBuyThreshold,
      panicBuyMultiplier: panicBuyMultiplier,
      firstProfitTarget: firstProfitTarget,
      profitTargetStep: profitTargetStep,
      minProfitTarget: minProfitTarget,
      cashSecureRatio: cashSecureRatio,
      takeProfitPercent: takeProfitPercent,
      totalRounds: totalRounds,
    );

    await _repository.save(cycle);
    state = [...state, cycle];

    // WebSocket 티커 등록
    try {
      _ref.read(stockPriceProvider.notifier).loadSymbols([ticker]);
    } catch (_) {}

    return cycle;
  }

  /// 사이클 저장 (수정 후)
  Future<void> saveCycle(Cycle cycle) async {
    cycle.updatedAt = DateTime.now();
    await _repository.save(cycle);
    state = _repository.getAll();
  }

  /// 사이클 삭제
  Future<void> deleteCycle(String id) async {
    await _repository.delete(id);
    state = state.where((c) => c.id != id).toList();
  }

  /// 익절 처리 — 매도 Trade 기록 + 기존 사이클 완료 + 새 사이클 생성
  Future<Cycle> completeTakeProfit({
    required String cycleId,
    required double currentPrice,
    required double exchangeRate,
  }) async {
    final cycle = getCycle(cycleId);
    if (cycle == null) throw StateError('Cycle not found: $cycleId');

    // 매도 Trade 기록 (전량 매도)
    final sellAmountKrw = cycle.totalShares * currentPrice * exchangeRate;
    final sellTrade = Trade(
      id: const Uuid().v4(),
      cycleId: cycleId,
      action: TradeAction.sell,
      signal: TradeSignal.takeProfit,
      price: currentPrice,
      shares: cycle.totalShares,
      amountKrw: sellAmountKrw,
      exchangeRate: exchangeRate,
    );
    await _tradeRepository.save(sellTrade);

    final newSeed = sellAmountKrw + cycle.remainingCash;
    final carryOverCount = cycle.consecutiveProfitCount + 1;

    // 기존 사이클 완료 처리
    cycle.status = CycleStatus.completed;
    cycle.completedReturnRate =
        TradingMath.returnRate(currentPrice, cycle.averagePrice);
    cycle.totalShares = 0;
    cycle.remainingCash += sellAmountKrw;
    cycle.updatedAt = DateTime.now();
    await _repository.save(cycle);

    // 새 사이클 생성 (연속 익절 횟수 이월 + 커스텀 파라미터 복사)
    final newCycle = Cycle(
      id: const Uuid().v4(),
      ticker: cycle.ticker,
      name: cycle.name,
      seedAmount: newSeed,
      exchangeRateAtEntry: exchangeRate,
      strategyType: cycle.strategyType,
      consecutiveProfitCount: carryOverCount,
      initialEntryRatio: cycle.initialEntryRatio,
      weightedBuyThreshold: cycle.weightedBuyThreshold,
      weightedBuyDivisor: cycle.weightedBuyDivisor,
      panicBuyThreshold: cycle.panicBuyThreshold,
      panicBuyMultiplier: cycle.panicBuyMultiplier,
      firstProfitTarget: cycle.firstProfitTarget,
      profitTargetStep: cycle.profitTargetStep,
      minProfitTarget: cycle.minProfitTarget,
      cashSecureRatio: cycle.cashSecureRatio,
      takeProfitPercent: cycle.takeProfitPercent,
      totalRounds: cycle.totalRounds,
    );

    await _repository.save(newCycle);
    state = _repository.getAll();
    return newCycle;
  }

  /// 사이클 수동 완료 (손절/종료) — consecutiveProfitCount 리셋
  Future<void> completeCycle(String cycleId, {double? completedReturnRate}) async {
    final cycle = getCycle(cycleId);
    if (cycle == null) return;

    cycle.status = CycleStatus.completed;
    cycle.completedReturnRate = completedReturnRate;
    cycle.updatedAt = DateTime.now();
    await _repository.save(cycle);
    state = _repository.getAll();
  }
}

// === 전략별 필터 ===

final activeCyclesProvider = Provider<List<Cycle>>((ref) {
  return ref
      .watch(cycleListProvider)
      .where((c) => c.status == CycleStatus.active)
      .toList();
});

final alphaCyclesProvider = Provider<List<Cycle>>((ref) {
  return ref
      .watch(activeCyclesProvider)
      .where((c) => c.strategyType == StrategyType.alphaCycleV3)
      .toList();
});

final infiniteBuyCyclesProvider = Provider<List<Cycle>>((ref) {
  return ref
      .watch(activeCyclesProvider)
      .where((c) => c.strategyType == StrategyType.infiniteBuy)
      .toList();
});

final completedCyclesProvider = Provider<List<Cycle>>((ref) {
  return ref
      .watch(cycleListProvider)
      .where((c) => c.status == CycleStatus.completed)
      .toList()
    ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
});

// === 신호 감지 (실시간 가격 연동) ===

final cycleSignalProvider =
    Provider.family<TradeSignal, String>((ref, cycleId) {
  final cycles = ref.watch(cycleListProvider);
  final cycle = cycles.where((c) => c.id == cycleId).firstOrNull;
  if (cycle == null) return TradeSignal.hold;

  final prices = ref.watch(currentPricesProvider);
  final currentPrice = prices[cycle.ticker] ?? 0;
  final liveExchangeRate = ref.watch(currentExchangeRateProvider);

  if (currentPrice == 0) return TradeSignal.hold;

  final service = cycle.strategyType == StrategyType.alphaCycleV3
      ? const AlphaCycleService()
      : const InfiniteBuyService();

  return service.detectSignal(
    cycle: cycle,
    currentPrice: currentPrice,
    liveExchangeRate: liveExchangeRate,
  );
});

/// 신호별 매수/매도 금액 (KRW)
final cycleSignalAmountProvider =
    Provider.family<double?, String>((ref, cycleId) {
  final cycles = ref.watch(cycleListProvider);
  final cycle = cycles.where((c) => c.id == cycleId).firstOrNull;
  if (cycle == null) return null;

  final signal = ref.watch(cycleSignalProvider(cycleId));
  if (signal == TradeSignal.hold) return null;

  final prices = ref.watch(currentPricesProvider);
  final currentPrice = prices[cycle.ticker] ?? 0;
  final liveExchangeRate = ref.watch(currentExchangeRateProvider);

  if (currentPrice == 0) return null;

  final service = cycle.strategyType == StrategyType.alphaCycleV3
      ? const AlphaCycleService()
      : const InfiniteBuyService();

  return service.calculateAmount(
    cycle: cycle,
    signal: signal,
    currentPrice: currentPrice,
    liveExchangeRate: liveExchangeRate,
  );
});
