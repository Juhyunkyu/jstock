import '../../data/models/cycle.dart';
import '../../data/models/trade.dart';
import 'strategy_engine.dart';
import 'trading_math.dart';

/// Strategy A: Alpha Cycle V3 비즈니스 로직 (순수 함수)
class AlphaCycleService implements StrategyEngine {
  const AlphaCycleService();

  /// 손실률 (entryPrice 기준)
  /// Zero-guard: entryPrice가 null이거나 0이면 0.0 반환
  static double lossRate(double currentPrice, double? entryPrice) {
    if (entryPrice == null || entryPrice == 0) return 0.0;
    return (currentPrice - entryPrice) / entryPrice * 100;
  }

  /// 가중 매수 금액 (KRW)
  static double weightedBuyAmount({
    required double initialEntryAmount,
    required double lossRate,
    required double weightedBuyDivisor,
  }) =>
      initialEntryAmount * lossRate.abs() / weightedBuyDivisor;

  /// 승부수 금액 (KRW) -- V3: 평가금액 기준
  static double panicBuyAmount({
    required double evaluatedAmount,
    required double panicBuyMultiplier,
  }) =>
      evaluatedAmount * panicBuyMultiplier;

  /// 현금 확보 매도 금액 (KRW), null = 불필요
  static double? cashSecureAmount({
    required double remainingCash,
    required double totalAssets,
    required double cashSecureRatio,
  }) {
    if (totalAssets <= 0) return null;
    final targetCash = totalAssets * cashSecureRatio;
    if (remainingCash >= targetCash) return null;
    return targetCash - remainingCash;
  }

  @override
  TradeSignal detectSignal({
    required Cycle cycle,
    required double currentPrice,
    required double liveExchangeRate,
  }) {
    if (cycle.entryPrice == null || cycle.entryPrice == 0) {
      return TradeSignal.hold;
    }
    if (cycle.averagePrice == 0) return TradeSignal.hold;

    final loss = lossRate(currentPrice, cycle.entryPrice);
    final ret = TradingMath.returnRate(currentPrice, cycle.averagePrice);
    final evalAmt = TradingMath.evaluatedAmount(
      cycle.totalShares,
      currentPrice,
      liveExchangeRate,
    );
    final totalAssets = evalAmt + cycle.remainingCash;
    final cashRatio = totalAssets > 0 ? cycle.remainingCash / totalAssets : 1.0;

    // 5단계 우선순위
    if (ret >= cycle.currentSellTarget) return TradeSignal.takeProfit;
    if (ret >= 0 &&
        cashRatio < cycle.cashSecureRatio &&
        cycle.totalShares > 0) {
      return TradeSignal.cashSecure;
    }
    if (loss <= cycle.panicBuyThreshold &&
        !cycle.panicBuyUsed &&
        cycle.remainingCash > 0) {
      return TradeSignal.panicBuy;
    }
    if (loss <= cycle.weightedBuyThreshold && cycle.remainingCash > 0) {
      return TradeSignal.weightedBuy;
    }
    return TradeSignal.hold;
  }

  @override
  double? calculateAmount({
    required Cycle cycle,
    required TradeSignal signal,
    required double currentPrice,
    required double liveExchangeRate,
  }) {
    switch (signal) {
      case TradeSignal.panicBuy:
        // 승부수 + 가중매수 합산
        final evalAmt = TradingMath.evaluatedAmount(
          cycle.totalShares,
          currentPrice,
          liveExchangeRate,
        );
        final panic = panicBuyAmount(
          evaluatedAmount: evalAmt,
          panicBuyMultiplier: cycle.panicBuyMultiplier,
        );
        final loss = lossRate(currentPrice, cycle.entryPrice);
        final weighted = weightedBuyAmount(
          initialEntryAmount: cycle.initialEntryAmount,
          lossRate: loss,
          weightedBuyDivisor: cycle.weightedBuyDivisor,
        );
        final total = panic + weighted;
        return total > 0 ? total.clamp(0.0, cycle.remainingCash) : null;

      case TradeSignal.weightedBuy:
        final loss = lossRate(currentPrice, cycle.entryPrice);
        final amount = weightedBuyAmount(
          initialEntryAmount: cycle.initialEntryAmount,
          lossRate: loss,
          weightedBuyDivisor: cycle.weightedBuyDivisor,
        );
        return amount > 0 ? amount.clamp(0.0, cycle.remainingCash) : null;

      case TradeSignal.cashSecure:
        final evalAmt = TradingMath.evaluatedAmount(
          cycle.totalShares,
          currentPrice,
          liveExchangeRate,
        );
        final totalAssets = evalAmt + cycle.remainingCash;
        return cashSecureAmount(
          remainingCash: cycle.remainingCash,
          totalAssets: totalAssets,
          cashSecureRatio: cycle.cashSecureRatio,
        );

      case TradeSignal.takeProfit:
        // 전량 매도 -- 평가금액 반환
        return TradingMath.evaluatedAmount(
          cycle.totalShares,
          currentPrice,
          liveExchangeRate,
        );

      default:
        return null;
    }
  }
}
