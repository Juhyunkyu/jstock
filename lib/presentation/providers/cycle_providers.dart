import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../data/models/cycle.dart';
import '../../data/models/trade.dart';
import '../../data/repositories/cycle_repository.dart';
import '../../data/repositories/trade_repository.dart';
import '../../domain/trading/alpha_cycle_service.dart';
import '../../domain/trading/infinite_buy_service.dart';
import '../../domain/trading/steady_service.dart';
import '../../domain/trading/strategy_engine.dart';
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
    _migrateWeightedBuyParam();
    _migrateAggregateFields();
    // 기존 사이클의 잘못된 entryPrice 교정 (비동기 → 완료 후 state 갱신)
    _fixEntryPrices();
  }

  /// 집계 필드 마이그레이션: totalBuyAmountKrw==0이지만 거래 있는 사이클 재계산
  void _migrateAggregateFields() {
    for (final cycle in state) {
      if (cycle.totalBuyAmountKrw == 0 && cycle.seedAmount != cycle.remainingCash) {
        final trades = _tradeRepository.getByCycleId(cycle.id);
        if (trades.isNotEmpty) {
          final sorted = [...trades]..sort((a, b) => a.tradedAt.compareTo(b.tradedAt));
          double totalBuyKrw = 0, totalSellKrw = 0;
          double totalBuyUsd = 0, totalSellUsd = 0;
          for (final t in sorted) {
            if (t.action == TradeAction.buy) {
              totalBuyKrw += t.amountKrw;
              totalBuyUsd += t.shares * t.price;
            } else {
              totalSellKrw += t.amountKrw;
              totalSellUsd += t.shares * t.price;
            }
          }
          cycle.totalBuyAmountKrw = totalBuyKrw;
          cycle.totalSellAmountKrw = totalSellKrw;
          cycle.totalBuyUsd = totalBuyUsd;
          cycle.totalSellUsd = totalSellUsd;
          cycle.firstTradeDate = sorted.first.tradedAt;
          cycle.lastTradeDate = sorted.last.tradedAt;
          _repository.save(cycle);
        }
      }
    }
  }

  /// v7.0 마이그레이션: 기존 weightedBuyDivisor 값(500~2000) → 0.0 리셋
  void _migrateWeightedBuyParam() {
    // 구 슬라이더: min=500, max=2000, divisions=6 → 가능값
    final legacyValues = {500.0, 750.0, 1000.0, 1250.0, 1500.0, 1750.0, 2000.0};
    bool changed = false;
    for (final cycle in state) {
      if (cycle.strategyType != StrategyType.alphaCycleV3) continue;
      if (legacyValues.contains(cycle.weightedBuyPerPercent)) {
        cycle.weightedBuyPerPercent = 0.0; // auto-calc 트리거
        _repository.save(cycle);
        changed = true;
      }
    }
    if (changed) state = _repository.getAll();
  }

  /// 기존 Smart 사이클의 entryPrice를 시간순 첫 매수 가격으로 교정
  /// (getByCycleId가 역순 정렬이어서 잘못된 값이 저장된 버그 수정)
  Future<void> _fixEntryPrices() async {
    bool changed = false;
    for (final cycle in state) {
      if (cycle.strategyType != StrategyType.alphaCycleV3) continue;
      if (cycle.status != CycleStatus.active) continue;

      final trades = _tradeRepository.getByCycleId(cycle.id);
      if (trades.isEmpty) continue;

      // 시간순 정렬 (오래된 것 먼저)
      trades.sort((a, b) => a.tradedAt.compareTo(b.tradedAt));
      final firstBuy = trades
          .where((t) => t.action == TradeAction.buy)
          .firstOrNull;
      if (firstBuy == null) continue;

      if (cycle.entryPrice != firstBuy.price) {
        cycle.entryPrice = firstBuy.price;
        await _repository.save(cycle);
        changed = true;
      }
    }
    if (changed) {
      state = _repository.getAll();
    }
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
    String nickname = '',
    // Strategy A 커스텀 파라미터
    double initialEntryRatio = 0.20,
    double weightedBuyThreshold = -20.0,
    double weightedBuyPerPercent = 0.0,
    double panicBuyThreshold = -50.0,
    double panicBuyMultiplier = 0.50,
    double firstProfitTarget = 30.0,
    double profitTargetStep = 5.0,
    double minProfitTarget = 10.0,
    double cashSecureRatio = 0.3333,
    // Strategy B 커스텀 파라미터
    double takeProfitPercent = 10.0,
    int totalRounds = 40,
    // Strategy B V2.2/V3.0 커스텀 파라미터
    SteadyVersion steadyVersion = SteadyVersion.v1,
    double sellQuarterPercent = 0.25,
    bool compoundEnabled = false,
    double offsetA = 15.0,
    double offsetB = 1.5,
    double quarterModeOffset = -15.0,
  }) async {
    final cycle = Cycle(
      id: const Uuid().v4(),
      ticker: ticker,
      name: name,
      seedAmount: seedAmount,
      exchangeRateAtEntry: exchangeRate,
      strategyType: strategyType,
      nickname: nickname,
      initialEntryRatio: initialEntryRatio,
      weightedBuyThreshold: weightedBuyThreshold,
      weightedBuyPerPercent: weightedBuyPerPercent,
      panicBuyThreshold: panicBuyThreshold,
      panicBuyMultiplier: panicBuyMultiplier,
      firstProfitTarget: firstProfitTarget,
      profitTargetStep: profitTargetStep,
      minProfitTarget: minProfitTarget,
      cashSecureRatio: cashSecureRatio,
      takeProfitPercent: takeProfitPercent,
      totalRounds: totalRounds,
      steadyVersion: steadyVersion,
      sellQuarterPercent: sellQuarterPercent,
      compoundEnabled: compoundEnabled,
      offsetA: offsetA,
      offsetB: offsetB,
      quarterModeOffset: quarterModeOffset,
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
      nickname: cycle.nickname,
      consecutiveProfitCount: carryOverCount,
      initialEntryRatio: cycle.initialEntryRatio,
      weightedBuyThreshold: cycle.weightedBuyThreshold,
      weightedBuyPerPercent: cycle.weightedBuyPerPercent,
      panicBuyThreshold: cycle.panicBuyThreshold,
      panicBuyMultiplier: cycle.panicBuyMultiplier,
      firstProfitTarget: cycle.firstProfitTarget,
      profitTargetStep: cycle.profitTargetStep,
      minProfitTarget: cycle.minProfitTarget,
      cashSecureRatio: cycle.cashSecureRatio,
      takeProfitPercent: cycle.takeProfitPercent,
      totalRounds: cycle.totalRounds,
      // Steady V2.2/V3.0 필드 이월
      steadyVersion: cycle.steadyVersion,
      sellQuarterPercent: cycle.sellQuarterPercent,
      compoundEnabled: cycle.compoundEnabled,
      offsetA: cycle.offsetA,
      offsetB: cycle.offsetB,
      quarterModeOffset: cycle.quarterModeOffset,
      // isQuarterStopLossMode/quarterStopLossRoundsUsed → 새 사이클에서 리셋 (기본값 0/false)
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

  final prices = ref.watch(closingPricesProvider);
  final currentPrice = prices[cycle.ticker] ?? 0;
  final liveExchangeRate = ref.watch(currentExchangeRateProvider);

  if (currentPrice == 0) return TradeSignal.hold;

  final StrategyEngine service;
  if (cycle.strategyType == StrategyType.alphaCycleV3) {
    service = const AlphaCycleService();
  } else if (cycle.steadyVersion != SteadyVersion.v1) {
    service = const SteadyService();
  } else {
    service = const InfiniteBuyService();
  }

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

  final prices = ref.watch(closingPricesProvider);
  final currentPrice = prices[cycle.ticker] ?? 0;
  final liveExchangeRate = ref.watch(currentExchangeRateProvider);

  if (currentPrice == 0) return null;

  final StrategyEngine service;
  if (cycle.strategyType == StrategyType.alphaCycleV3) {
    service = const AlphaCycleService();
  } else if (cycle.steadyVersion != SteadyVersion.v1) {
    service = const SteadyService();
  } else {
    service = const InfiniteBuyService();
  }

  return service.calculateAmount(
    cycle: cycle,
    signal: signal,
    currentPrice: currentPrice,
    liveExchangeRate: liveExchangeRate,
  );
});
