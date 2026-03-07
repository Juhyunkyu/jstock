import '../../data/models/cycle.dart';
import '../../data/models/trade.dart';
import 'strategy_engine.dart';
import 'trading_math.dart';

/// Strategy B: 순정 무한매수법 V2.1 비즈니스 로직 (순수 함수)
class InfiniteBuyService implements StrategyEngine {
  const InfiniteBuyService();

  /// LOC 주문 타입 결정
  static TradeSignal locOrderType({
    required double currentPrice,
    required double averagePrice,
    required int roundsUsed,
  }) {
    if (roundsUsed == 0) return TradeSignal.locAB; // 첫 매수
    if (averagePrice <= 0) return TradeSignal.locAB; // zero-guard
    return currentPrice <= averagePrice
        ? TradeSignal.locAB // A+B = 1.0 unit
        : TradeSignal.locB; // B만 = 0.5 unit
  }

  /// 매수 금액 (KRW) -- remainingCash 초과 방지
  static double buyAmount({
    required double unitAmount,
    required double remainingCash,
    required TradeSignal locType,
  }) {
    final raw = switch (locType) {
      TradeSignal.locAB => unitAmount, // 1.0 unit
      TradeSignal.locB => unitAmount * 0.5, // 0.5 unit
      _ => 0.0,
    };
    return raw > 0 ? raw.clamp(0.0, remainingCash) : 0.0;
  }

  @override
  TradeSignal detectSignal({
    required Cycle cycle,
    required double currentPrice,
    required double liveExchangeRate,
  }) {
    if (cycle.averagePrice == 0 && cycle.roundsUsed == 0) {
      // 첫 매수 전 -- LOC_AB (현금 있을 때만)
      return cycle.remainingCash > 0 ? TradeSignal.locAB : TradeSignal.hold;
    }

    final ret = TradingMath.returnRate(currentPrice, cycle.averagePrice);

    // 1. 익절 조건
    if (cycle.totalShares > 0 && ret >= cycle.takeProfitPercent) {
      return TradeSignal.takeProfit;
    }

    // 2. LOC 매수 조건: 라운드 남음 + 현금 있음
    if (cycle.roundsUsed < cycle.totalRounds && cycle.remainingCash > 0) {
      return locOrderType(
        currentPrice: currentPrice,
        averagePrice: cycle.averagePrice,
        roundsUsed: cycle.roundsUsed,
      );
    }

    // 3. 대기
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
      case TradeSignal.locAB:
      case TradeSignal.locB:
        final amount = buyAmount(
          unitAmount: cycle.unitAmount,
          remainingCash: cycle.remainingCash,
          locType: signal,
        );
        return amount > 0 ? amount : null;

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
