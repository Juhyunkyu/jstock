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
  /// [extraFundingAmount] > 0 이면 시드 금액을 해당 금액만큼 증가시킵니다 (추가 자금 투입)
  Future<Trade> recordBuy({
    required String cycleId,
    required TradeSignal signal,
    required double price,
    required double amountKrw,
    required double exchangeRate,
    String? memo,
    double extraFundingAmount = 0,
  }) async {
    if (price <= 0 || exchangeRate <= 0) {
      throw ArgumentError('Invalid price or exchange rate');
    }

    final cycles = _ref.read(cycleListProvider);
    final cycle = cycles.firstWhere((c) => c.id == cycleId);

    // 추가 자금 투입: 시드 및 잔여현금 증가
    if (extraFundingAmount > 0) {
      cycle.seedAmount += extraFundingAmount;
      cycle.remainingCash += extraFundingAmount;
    }

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

    // 사이클 상태 재계산 (VWAP, entryPrice, panicBuyUsed, roundsUsed, remainingCash)
    _ref.invalidate(allTradesProvider);
    state = _repository.getByCycleId(_cycleId);
    await _recalculateCycleState();
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

    // 사이클 상태 재계산 (totalShares, remainingCash 등)
    _ref.invalidate(allTradesProvider);
    state = _repository.getByCycleId(_cycleId);
    await _recalculateCycleState();
    return trade;
  }

  /// 거래 수정 + 사이클 상태 재계산
  Future<void> updateTrade(Trade updatedTrade) async {
    await _repository.save(updatedTrade);
    _ref.invalidate(allTradesProvider);
    state = _repository.getByCycleId(_cycleId);
    await _recalculateCycleState();
  }

  /// 거래 삭제 + 사이클 상태 재계산
  Future<void> deleteTradeAndRecalculate(String tradeId) async {
    await _repository.delete(tradeId);
    _ref.invalidate(allTradesProvider);
    state = _repository.getByCycleId(_cycleId);
    await _recalculateCycleState();
  }

  /// 남은 거래 내역으로 사이클 상태 재계산
  Future<void> _recalculateCycleState() async {
    final cycles = _ref.read(cycleListProvider);
    final cycle = cycles.where((c) => c.id == _cycleId).firstOrNull;
    if (cycle == null) return;

    // 시간순 정렬 (오래된 것 먼저) — entryPrice는 첫 매수 가격이어야 함
    final trades = [...state]..sort((a, b) => a.tradedAt.compareTo(b.tradedAt));

    // 순수 USD VWAP 재계산
    double totalBuyShares = 0;
    double totalSellShares = 0;
    double weightedPriceSum = 0; // shares * price (USD)
    double totalBuyAmountKrw = 0;
    double totalSellAmountKrw = 0;
    bool panicBuyUsed = false;
    int roundsUsed = 0;
    double? entryPrice;

    for (final trade in trades) {
      if (trade.action == TradeAction.buy) {
        totalBuyShares += trade.shares;
        weightedPriceSum += trade.shares * trade.price;
        totalBuyAmountKrw += trade.amountKrw;

        // Strategy A: 첫 매수 entryPrice (시간순 첫 매수)
        if (cycle.strategyType == StrategyType.alphaCycleV3 && entryPrice == null) {
          entryPrice = trade.price;
        }

        // Strategy A: 승부수 플래그
        if (trade.signal == TradeSignal.panicBuy) {
          panicBuyUsed = true;
        }

        // Strategy B: 라운드 카운트
        if (cycle.strategyType == StrategyType.infiniteBuy &&
            (trade.signal == TradeSignal.locAB ||
             trade.signal == TradeSignal.locB ||
             trade.signal == TradeSignal.manual)) {
          roundsUsed += 1;
        }
      } else {
        totalSellShares += trade.shares;
        totalSellAmountKrw += trade.amountKrw;
      }
    }

    final netShares = totalBuyShares - totalSellShares;
    final avgPrice = netShares > 0 ? weightedPriceSum / totalBuyShares : 0.0;

    cycle.totalShares = netShares > 0 ? netShares : 0;
    cycle.averagePrice = avgPrice;
    cycle.remainingCash = cycle.seedAmount - totalBuyAmountKrw + totalSellAmountKrw;
    cycle.entryPrice = entryPrice;
    cycle.panicBuyUsed = panicBuyUsed;
    cycle.roundsUsed = roundsUsed;

    // 평균매입환율(exchangeRateAtEntry)은 사용자가 독립 관리 — 자동 재계산 안 함

    await _ref.read(cycleListProvider.notifier).saveCycle(cycle);
  }
}

// === 전체 거래 내역 (히스토리용) ===

final allTradesProvider = Provider<List<Trade>>((ref) {
  final repo = ref.watch(tradeRepositoryProvider);
  return repo.getAll()..sort((a, b) => b.tradedAt.compareTo(a.tradedAt));
});

/// 사이클별 실현 손익 계산 (실제 매도 합계 - 실제 매수 합계)
final cycleRealizedPnlProvider = Provider.family<
    ({double totalBuyKrw, double totalSellKrw, double pnlKrw, double returnPercent})?,
    String>((ref, cycleId) {
  final allTrades = ref.watch(allTradesProvider);
  final cycleTrades = allTrades.where((t) => t.cycleId == cycleId).toList();
  if (cycleTrades.isEmpty) return null;

  double totalBuyKrw = 0;
  double totalSellKrw = 0;
  for (final trade in cycleTrades) {
    if (trade.action == TradeAction.buy) {
      totalBuyKrw += trade.amountKrw;
    } else {
      totalSellKrw += trade.amountKrw;
    }
  }
  final pnl = totalSellKrw - totalBuyKrw;
  final percent = totalBuyKrw > 0 ? (pnl / totalBuyKrw) * 100 : 0.0;
  return (
    totalBuyKrw: totalBuyKrw,
    totalSellKrw: totalSellKrw,
    pnlKrw: pnl,
    returnPercent: percent,
  );
});
