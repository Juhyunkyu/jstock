import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../data/models/cycle.dart';
import '../../data/models/trade.dart';
import '../../data/repositories/trade_repository.dart';
import 'core/repository_providers.dart';
import 'cycle_providers.dart';

// === 거래 목록 (사이클별) ===

final tradeListProvider =
    StateNotifierProvider.family<TradeListNotifier, List<Trade>, String>(
        (ref, cycleId) {
  final repo = ref.watch(tradeRepositoryProvider);
  return TradeListNotifier(ref, repo, cycleId);
});

class TradeListNotifier extends StateNotifier<List<Trade>> {
  final Ref _ref;
  final TradeRepository _repository;
  final String _cycleId;

  TradeListNotifier(this._ref, this._repository, this._cycleId) : super([]) {
    _loadTrades();
  }

  void _loadTrades() {
    state = _repository.getByCycleId(_cycleId);
  }

  Future<void> refresh() async {
    state = _repository.getByCycleId(_cycleId);
  }

  /// 매수 거래 기록 + 사이클 상태 업데이트
  Future<Trade> recordBuy({
    required String cycleId,
    required TradeSignal signal,
    required double price,
    required double amountKrw,
    required double exchangeRate,
    String? memo,
  }) async {
    if (price <= 0 || exchangeRate <= 0) {
      throw ArgumentError('Invalid price or exchange rate');
    }

    final cycles = _ref.read(cycleListProvider);
    final cycle = cycles.firstWhere((c) => c.id == cycleId);

    // remainingCash 초과 방지
    final actualAmount = amountKrw.clamp(0.0, cycle.remainingCash);
    if (actualAmount <= 0) {
      throw StateError('No remaining cash for buy');
    }

    final shares = actualAmount / (price * exchangeRate);

    final trade = Trade(
      id: const Uuid().v4(),
      cycleId: cycleId,
      action: TradeAction.buy,
      signal: signal,
      price: price,
      shares: shares,
      amountKrw: actualAmount,
      exchangeRate: exchangeRate,
      memo: memo,
    );

    await _repository.save(trade);

    // 사이클 상태 업데이트 — 순수 USD VWAP (환율 혼합 방지)
    final prevShares = cycle.totalShares;
    final newTotalShares = prevShares + shares;
    if (newTotalShares > 0) {
      cycle.averagePrice =
          (prevShares * cycle.averagePrice + shares * price) / newTotalShares;
    }
    cycle.totalShares = newTotalShares;
    cycle.remainingCash -= actualAmount;

    // Strategy A: 첫 매수 시 entryPrice 설정
    if (cycle.strategyType == StrategyType.alphaCycleV3 &&
        cycle.entryPrice == null) {
      cycle.entryPrice = price;
    }

    // Strategy A: 승부수 사용 플래그
    if (signal == TradeSignal.panicBuy) {
      cycle.panicBuyUsed = true;
    }

    // Strategy B: 라운드 카운트
    if (cycle.strategyType == StrategyType.infiniteBuy &&
        (signal == TradeSignal.locAB ||
         signal == TradeSignal.locB ||
         signal == TradeSignal.manual)) {
      cycle.roundsUsed += 1;
    }

    await _ref.read(cycleListProvider.notifier).saveCycle(cycle);
    _ref.invalidate(allTradesProvider);
    state = _repository.getByCycleId(_cycleId);
    return trade;
  }

  /// 매도 거래 기록 + 사이클 상태 업데이트
  Future<Trade> recordSell({
    required String cycleId,
    required TradeSignal signal,
    required double price,
    required double shares,
    required double exchangeRate,
    String? memo,
  }) async {
    if (price <= 0 || exchangeRate <= 0) {
      throw ArgumentError('Invalid price or exchange rate');
    }

    final cycles = _ref.read(cycleListProvider);
    final cycle = cycles.firstWhere((c) => c.id == cycleId);

    // totalShares 초과 방지
    final actualShares = shares > cycle.totalShares ? cycle.totalShares : shares;
    final amountKrw = actualShares * price * exchangeRate;

    final trade = Trade(
      id: const Uuid().v4(),
      cycleId: cycleId,
      action: TradeAction.sell,
      signal: signal,
      price: price,
      shares: actualShares,
      amountKrw: amountKrw,
      exchangeRate: exchangeRate,
      memo: memo,
    );

    await _repository.save(trade);

    // 사이클 상태 업데이트
    cycle.totalShares -= actualShares;
    cycle.remainingCash += amountKrw;

    await _ref.read(cycleListProvider.notifier).saveCycle(cycle);
    _ref.invalidate(allTradesProvider);
    state = _repository.getByCycleId(_cycleId);
    return trade;
  }

  /// 거래 삭제
  Future<void> deleteTrade(String tradeId) async {
    await _repository.delete(tradeId);
    _ref.invalidate(allTradesProvider);
    state = _repository.getByCycleId(_cycleId);
  }
}

// === 전체 거래 내역 (히스토리용) ===

final allTradesProvider = Provider<List<Trade>>((ref) {
  final repo = ref.watch(tradeRepositoryProvider);
  return repo.getAll()..sort((a, b) => b.tradedAt.compareTo(a.tradedAt));
});
