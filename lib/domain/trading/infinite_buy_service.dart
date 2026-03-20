import '../../data/models/cycle.dart';
import '../../data/models/trade.dart';
import 'strategy_engine.dart';
import 'trading_math.dart';
import 'steady_order_guide.dart';

/// Strategy B: 순정 무한매수법 V1 Simple 비즈니스 로직 (순수 함수)
class InfiniteBuyService implements StrategyEngine {
  const InfiniteBuyService();

  // ══════════════════════════════════════════
  // V1 주문 가이드 생성
  // ══════════════════════════════════════════

  /// V1 주문 가이드 — SteadyOrderGuide 형태로 반환
  ///
  /// V1 규칙:
  /// - 매수: 현재가 ≤ 평단 → A(0.5unit 평단 LOC) + B(0.5unit +10% LOC)
  ///         현재가 > 평단 → B만(0.5unit +10% LOC)
  /// - 매도: 전량 지정가 매도 (평단+10%)
  static SteadyOrderGuide generateV1Guide({
    required Cycle cycle,
    required double currentPrice,
    required double exchangeRate,
  }) {
    final isFirstBuy = cycle.averagePrice == 0 && cycle.roundsUsed == 0;
    final canBuy = cycle.remainingCash > 0 && cycle.roundsUsed < cycle.totalRounds;
    final sellPrice = cycle.averagePrice * 1.1; // 평단+10%

    // 첫 매수
    if (isFirstBuy) {
      final buyAmountKrw = cycle.unitAmount.clamp(0.0, cycle.remainingCash);
      final shares = (exchangeRate > 0 && currentPrice > 0)
          ? buyAmountKrw / (currentPrice * exchangeRate)
          : 0.0;

      return SteadyOrderGuide(
        tValue: cycle.roundsUsed.toDouble(),
        isFirstHalf: true,
        locOffsetPercent: 0,
        locPrice: currentPrice,
        limitSellPrice: 0,
        canBuy: canBuy,
        isFirstBuy: true,
        isQuarterMode: false,
        adjustedUnitAmount: cycle.unitAmount,
        buySingleOrder: OrderItem(
          label: '첫 매수',
          price: currentPrice,
          shares: shares,
          amountKrw: buyAmountKrw,
          description: '시장가 1unit',
        ),
      );
    }

    // 매수 주문 생성
    OrderItem? buyOrderA;
    OrderItem? buyOrderB;

    if (canBuy) {
      final halfAmount = (cycle.unitAmount * 0.5).clamp(0.0, cycle.remainingCash);
      final locBuyPrice = cycle.averagePrice * 1.1; // +10% 큰수매수

      // A: 평단 LOC (현재가 ≤ 평단일 때만 체결 가능)
      if (currentPrice <= cycle.averagePrice) {
        final sharesA = (exchangeRate > 0 && cycle.averagePrice > 0)
            ? halfAmount / (cycle.averagePrice * exchangeRate)
            : 0.0;
        buyOrderA = OrderItem(
          label: 'LOC A (평단)',
          price: cycle.averagePrice,
          shares: sharesA,
          amountKrw: halfAmount,
          description: '종가 ≤ 평단 시 체결',
        );
      }

      // B: +10% LOC (큰수매수, 거의 항상 체결)
      final remainAfterA = buyOrderA != null
          ? (cycle.remainingCash - halfAmount).clamp(0.0, double.infinity)
          : cycle.remainingCash;
      final halfAmountB = halfAmount.clamp(0.0, remainAfterA);
      final sharesB = (exchangeRate > 0 && locBuyPrice > 0)
          ? halfAmountB / (locBuyPrice * exchangeRate)
          : 0.0;
      buyOrderB = OrderItem(
        label: 'LOC B (+10%)',
        price: locBuyPrice,
        shares: sharesB,
        amountKrw: halfAmountB,
        description: '종가 ≤ +10% 시 체결',
      );
    }

    // 매도 주문 (보유 수량 있을 때)
    OrderItem? sellLimitOrder;
    if (cycle.totalShares > 0 && cycle.averagePrice > 0) {
      final sellAmountKrw = cycle.totalShares * sellPrice * exchangeRate;
      sellLimitOrder = OrderItem(
        label: '지정가 매도 (전량)',
        price: sellPrice,
        shares: cycle.totalShares,
        amountKrw: sellAmountKrw,
        description: '+10% 익절',
      );
    }

    return SteadyOrderGuide(
      tValue: cycle.roundsUsed.toDouble(),
      isFirstHalf: true, // V1은 항상 A+B 구조
      locOffsetPercent: 0,
      locPrice: sellPrice,
      limitSellPrice: sellPrice,
      canBuy: canBuy,
      isFirstBuy: false,
      isQuarterMode: false,
      adjustedUnitAmount: cycle.unitAmount,
      buyOrderA: buyOrderA,
      buyOrderB: buyOrderB,
      sellLimitOrder: sellLimitOrder,
    );
  }

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
