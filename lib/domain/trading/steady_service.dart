import '../../data/models/cycle.dart';
import '../../data/models/trade.dart';
import 'strategy_engine.dart';
import 'trading_math.dart';
import 'steady_order_guide.dart';

/// Strategy B V2.2/V3.0: 무한매수법 통합 서비스
/// V1은 InfiniteBuyService를 계속 사용. 이 서비스는 V2.2/V3.0 전용.
class SteadyService implements StrategyEngine {
  const SteadyService();

  // ══════════════════════════════════════════
  // Static 비즈니스 로직 (Provider에서도 호출 가능)
  // ══════════════════════════════════════════

  /// T값 계산 — 소수점 둘째 자리에서 올림
  /// V3.0 복리: 매도 수익금도 투자금에 포함
  static double calcTValue(Cycle cycle, double totalSellKrw) {
    if (cycle.unitAmount <= 0) return 0;
    final invested = cycle.seedAmount - cycle.remainingCash;
    double raw;
    if (cycle.compoundEnabled && cycle.steadyVersion == SteadyVersion.v3_0) {
      raw = (invested + totalSellKrw) / cycle.unitAmount;
    } else {
      raw = invested / cycle.unitAmount;
    }
    return ((raw * 10).ceilToDouble() / 10)
        .clamp(0, cycle.totalRounds.toDouble());
  }

  /// 반복리 매수금 (V3.0 전용)
  /// 매도 순수익을 40분할하여 기본 단위금액에 추가
  static double calcAdjustedUnitAmount(Cycle cycle, double sellProfit) {
    if (!cycle.compoundEnabled || cycle.steadyVersion != SteadyVersion.v3_0) {
      return cycle.unitAmount;
    }
    if (sellProfit > 0) {
      return cycle.unitAmount + (sellProfit / 40);
    }
    return cycle.unitAmount; // 손해 시 유지
  }

  /// 매도 순수익 계산 (거래 이력 기반)
  static double calcSellProfit(
    List<Trade> trades,
    double averagePrice,
  ) {
    double profit = 0;
    for (final t in trades) {
      if (t.action != TradeAction.sell) continue;
      final costKrw = t.shares * averagePrice * t.exchangeRate;
      profit += t.amountKrw - costKrw;
    }
    return profit;
  }

  /// 주문 가이드 생성 — UI에서 호출하는 메인 메서드
  static SteadyOrderGuide generateGuide({
    required Cycle cycle,
    required double currentPrice,
    required double exchangeRate,
    required double totalSellKrw,
    required double sellProfit,
  }) {
    final tValue = calcTValue(cycle, totalSellKrw);
    final adjustedUnit = calcAdjustedUnitAmount(cycle, sellProfit);
    final isFirstBuy = cycle.averagePrice == 0;
    final isFirstHalf = cycle.isFirstHalfWith(tValue);
    final isQuarterMode = cycle.isQuarterModeWith(tValue);
    final locOffsetPercent = cycle.locOffsetPercentWith(tValue);
    final locPrice = cycle.locPriceWith(tValue);
    final locBuyPrice = cycle.locBuyPriceWith(tValue);
    final limitSellPrice = cycle.limitSellPrice;
    final canBuy = cycle.remainingCash > 0 && tValue < cycle.totalRounds;

    // 쿼터모드 분기
    if (isQuarterMode) {
      if (cycle.steadyVersion == SteadyVersion.v2_2) {
        return _v22QuarterGuide(
          cycle: cycle,
          tValue: tValue,
          currentPrice: currentPrice,
          exchangeRate: exchangeRate,
          adjustedUnit: adjustedUnit,
          locOffsetPercent: locOffsetPercent,
          locPrice: locPrice,
          limitSellPrice: limitSellPrice,
        );
      } else {
        return _v30QuarterGuide(
          cycle: cycle,
          tValue: tValue,
          currentPrice: currentPrice,
          exchangeRate: exchangeRate,
          adjustedUnit: adjustedUnit,
          locOffsetPercent: locOffsetPercent,
          locPrice: locPrice,
          limitSellPrice: limitSellPrice,
        );
      }
    }

    // 첫 매수 (T=0, averagePrice == 0)
    if (isFirstBuy) {
      final buyAmountKrw = adjustedUnit.clamp(0.0, cycle.remainingCash);
      final shares = (exchangeRate > 0 && currentPrice > 0)
          ? buyAmountKrw / (currentPrice * exchangeRate)
          : 0.0;

      return SteadyOrderGuide(
        tValue: tValue,
        isFirstHalf: isFirstHalf,
        locOffsetPercent: 0,
        locPrice: currentPrice,
        limitSellPrice: 0,
        canBuy: canBuy,
        isFirstBuy: true,
        isQuarterMode: false,
        adjustedUnitAmount: adjustedUnit,
        buySingleOrder: OrderItem(
          label: '첫 매수',
          price: currentPrice,
          shares: shares,
          amountKrw: buyAmountKrw,
          description: 'T=0 시장가',
        ),
      );
    }

    // 일반 주문 가이드 빌드
    OrderItem? buyOrderA;
    OrderItem? buyOrderB;
    OrderItem? buySingleOrder;

    if (canBuy) {
      if (isFirstHalf) {
        // 전반전: A + B 주문 (각 0.5 unit)
        final halfAmount =
            (adjustedUnit * 0.5).clamp(0.0, cycle.remainingCash);

        if (cycle.steadyVersion == SteadyVersion.v2_2) {
          // V2.2: A = 평단 LOC (half), B = 오프셋 LOC (half)
          final sharesA = (exchangeRate > 0 && cycle.averagePrice > 0)
              ? halfAmount / (cycle.averagePrice * exchangeRate)
              : 0.0;
          buyOrderA = OrderItem(
            label: 'LOC A (평단)',
            price: cycle.averagePrice,
            shares: sharesA,
            amountKrw: halfAmount,
            description: '평단 \$${cycle.averagePrice.toStringAsFixed(2)}',
          );

          final remainAfterA =
              (cycle.remainingCash - halfAmount).clamp(0.0, double.infinity);
          final halfAmountB = halfAmount.clamp(0.0, remainAfterA);
          final sharesB = (exchangeRate > 0 && locBuyPrice > 0)
              ? halfAmountB / (locBuyPrice * exchangeRate)
              : 0.0;
          buyOrderB = OrderItem(
            label: 'LOC B (오프셋)',
            price: locBuyPrice,
            shares: sharesB,
            amountKrw: halfAmountB,
            description: '${locOffsetPercent >= 0 ? '+' : ''}${locOffsetPercent.toStringAsFixed(1)}%',
          );
        } else {
          // V3.0: A = 오프셋 LOC (half), B = 평단 LOC (half)
          final sharesA = (exchangeRate > 0 && locBuyPrice > 0)
              ? halfAmount / (locBuyPrice * exchangeRate)
              : 0.0;
          buyOrderA = OrderItem(
            label: 'LOC A (오프셋)',
            price: locBuyPrice,
            shares: sharesA,
            amountKrw: halfAmount,
            description: '${locOffsetPercent >= 0 ? '+' : ''}${locOffsetPercent.toStringAsFixed(1)}%',
          );

          final remainAfterA =
              (cycle.remainingCash - halfAmount).clamp(0.0, double.infinity);
          final halfAmountB = halfAmount.clamp(0.0, remainAfterA);
          final sharesB = (exchangeRate > 0 && cycle.averagePrice > 0)
              ? halfAmountB / (cycle.averagePrice * exchangeRate)
              : 0.0;
          buyOrderB = OrderItem(
            label: 'LOC B (평단)',
            price: cycle.averagePrice,
            shares: sharesB,
            amountKrw: halfAmountB,
            description: '평단 \$${cycle.averagePrice.toStringAsFixed(2)}',
          );
        }
      } else {
        // 후반전: 단일 LOC 주문
        final buyAmountKrw = adjustedUnit.clamp(0.0, cycle.remainingCash);
        final shares = (exchangeRate > 0 && locBuyPrice > 0)
            ? buyAmountKrw / (locBuyPrice * exchangeRate)
            : 0.0;
        buySingleOrder = OrderItem(
          label: 'LOC 매수',
          price: locBuyPrice,
          shares: shares,
          amountKrw: buyAmountKrw,
          description: '${locOffsetPercent >= 0 ? '+' : ''}${locOffsetPercent.toStringAsFixed(1)}%',
        );
      }
    }

    // 매도 주문 (보유 수량 있을 때만)
    OrderItem? sellLocOrder;
    OrderItem? sellLimitOrder;

    if (cycle.totalShares > 0) {
      // LOC 매도: 1/4 at locPrice
      final sellLocShares =
          (cycle.totalShares * cycle.sellQuarterPercent).clamp(
        0.0,
        cycle.totalShares,
      );
      final sellLocAmountKrw = sellLocShares * locPrice * exchangeRate;
      sellLocOrder = OrderItem(
        label: 'LOC 매도 (1/4)',
        price: locPrice,
        shares: sellLocShares,
        amountKrw: sellLocAmountKrw,
        description: '${locOffsetPercent >= 0 ? '+' : ''}${locOffsetPercent.toStringAsFixed(1)}%',
      );

      // 지정가 매도: 3/4 at limitSellPrice
      final sellLimitShares =
          (cycle.totalShares * (1 - cycle.sellQuarterPercent)).clamp(
        0.0,
        cycle.totalShares,
      );
      final sellLimitAmountKrw =
          sellLimitShares * limitSellPrice * exchangeRate;
      sellLimitOrder = OrderItem(
        label: '지정가 매도 (3/4)',
        price: limitSellPrice,
        shares: sellLimitShares,
        amountKrw: sellLimitAmountKrw,
        description: '+${cycle.takeProfitPercent.toStringAsFixed(1)}%',
      );
    }

    return SteadyOrderGuide(
      tValue: tValue,
      isFirstHalf: isFirstHalf,
      locOffsetPercent: locOffsetPercent,
      locPrice: locPrice,
      limitSellPrice: limitSellPrice,
      canBuy: canBuy,
      isFirstBuy: false,
      isQuarterMode: false,
      adjustedUnitAmount: adjustedUnit,
      buyOrderA: buyOrderA,
      buyOrderB: buyOrderB,
      buySingleOrder: buySingleOrder,
      sellLocOrder: sellLocOrder,
      sellLimitOrder: sellLimitOrder,
    );
  }

  // ══════════════════════════════════════════
  // StrategyEngine 구현
  // ══════════════════════════════════════════

  @override
  TradeSignal detectSignal({
    required Cycle cycle,
    required double currentPrice,
    required double liveExchangeRate,
  }) {
    final isFirstBuy = cycle.averagePrice == 0 && cycle.roundsUsed == 0;

    // 1. 첫 매수
    if (isFirstBuy) {
      return cycle.remainingCash > 0 ? TradeSignal.locAB : TradeSignal.hold;
    }

    final ret = TradingMath.returnRate(currentPrice, cycle.averagePrice);

    // 2. 익절 (전량 매도)
    if (cycle.totalShares > 0 && ret >= cycle.takeProfitPercent) {
      return TradeSignal.takeProfit;
    }

    // 3. 간이 T값 (StrategyEngine 인터페이스에 totalSellKrw 없으므로 간이 계산)
    final simpleTValue = cycle.unitAmount > 0
        ? ((((cycle.seedAmount - cycle.remainingCash) / cycle.unitAmount) * 10)
                .ceilToDouble() /
            10)
        : 0.0;

    // 4. 쿼터모드 → hold (UI 가이드에서 처리)
    if (cycle.isQuarterModeWith(simpleTValue)) {
      return TradeSignal.hold;
    }

    // 5. 매수 가능 여부
    if (cycle.remainingCash > 0 && simpleTValue < cycle.totalRounds) {
      final isFirstHalf = cycle.isFirstHalfWith(simpleTValue);
      final locPrice = cycle.locPriceWith(simpleTValue);
      final locBuyPrice = locPrice - 0.01;

      if (isFirstHalf) {
        // 전반전
        if (currentPrice <= cycle.averagePrice) {
          return TradeSignal.locAB; // A+B 둘 다 체결 가능
        }
        if (currentPrice <= locBuyPrice) {
          // V2.2: B만 체결 (오프셋), V3.0: A만 체결 (오프셋)
          return cycle.steadyVersion == SteadyVersion.v2_2
              ? TradeSignal.locB
              : TradeSignal.locA;
        }
        return TradeSignal.noFill;
      } else {
        // 후반전: 단일 LOC
        if (currentPrice <= locBuyPrice) {
          return TradeSignal.buySingle;
        }
        return TradeSignal.noFill;
      }
    }

    // 6. 대기
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
        // 1.0 unit (전반전 A+B 합산 또는 첫 매수)
        final amount = cycle.unitAmount.clamp(0.0, cycle.remainingCash);
        return amount > 0 ? amount : null;

      case TradeSignal.locA:
      case TradeSignal.locB:
        // 0.5 unit (전반전 단일 주문)
        final amount =
            (cycle.unitAmount * 0.5).clamp(0.0, cycle.remainingCash);
        return amount > 0 ? amount : null;

      case TradeSignal.buySingle:
        // 1.0 unit (후반전 단일 주문)
        final amount = cycle.unitAmount.clamp(0.0, cycle.remainingCash);
        return amount > 0 ? amount : null;

      case TradeSignal.takeProfit:
      case TradeSignal.takeProfitFull:
        // 전량 매도 — 평가금액 반환
        return TradingMath.evaluatedAmount(
          cycle.totalShares,
          currentPrice,
          liveExchangeRate,
        );

      case TradeSignal.sellLocQuarter:
        // 1/4 LOC 매도
        final shares = cycle.totalShares * cycle.sellQuarterPercent;
        return shares > 0
            ? TradingMath.evaluatedAmount(
                shares, currentPrice, liveExchangeRate)
            : null;

      case TradeSignal.sellLimitThreeQ:
        // 3/4 지정가 매도
        final shares = cycle.totalShares * (1 - cycle.sellQuarterPercent);
        return shares > 0
            ? TradingMath.evaluatedAmount(
                shares, currentPrice, liveExchangeRate)
            : null;

      default:
        return null;
    }
  }

  // ══════════════════════════════════════════
  // V2.2 쿼터 손절모드 (T >= 39.1)
  // ══════════════════════════════════════════

  static SteadyOrderGuide _v22QuarterGuide({
    required Cycle cycle,
    required double tValue,
    required double currentPrice,
    required double exchangeRate,
    required double adjustedUnit,
    required double locOffsetPercent,
    required double locPrice,
    required double limitSellPrice,
  }) {
    // 매수 없음, 매도만
    OrderItem? sellLocOrder;
    OrderItem? sellLimitOrder;

    if (cycle.totalShares > 0) {
      // MOC 매도: 1/4 (현재가 근사)
      final sellLocShares =
          (cycle.totalShares * cycle.sellQuarterPercent).clamp(
        0.0,
        cycle.totalShares,
      );
      final sellLocAmountKrw = sellLocShares * currentPrice * exchangeRate;
      sellLocOrder = OrderItem(
        label: 'MOC 매도 (1/4)',
        price: currentPrice,
        shares: sellLocShares,
        amountKrw: sellLocAmountKrw,
        description: 'MOC 손절',
      );

      // +10% 지정가 매도: 3/4
      final sellLimitShares =
          (cycle.totalShares * (1 - cycle.sellQuarterPercent)).clamp(
        0.0,
        cycle.totalShares,
      );
      final sellLimitPriceV22 = cycle.averagePrice * 1.10;
      final sellLimitAmountKrw =
          sellLimitShares * sellLimitPriceV22 * exchangeRate;
      sellLimitOrder = OrderItem(
        label: '지정가 매도 (3/4)',
        price: sellLimitPriceV22,
        shares: sellLimitShares,
        amountKrw: sellLimitAmountKrw,
        description: '+10.0%',
      );
    }

    return SteadyOrderGuide(
      tValue: tValue,
      isFirstHalf: false,
      locOffsetPercent: locOffsetPercent,
      locPrice: locPrice,
      limitSellPrice: limitSellPrice,
      canBuy: false,
      isFirstBuy: false,
      isQuarterMode: true,
      adjustedUnitAmount: adjustedUnit,
      sellLocOrder: sellLocOrder,
      sellLimitOrder: sellLimitOrder,
    );
  }

  // ══════════════════════════════════════════
  // V3.0 쿼터모드 (19 < T < 20)
  // ══════════════════════════════════════════

  static SteadyOrderGuide _v30QuarterGuide({
    required Cycle cycle,
    required double tValue,
    required double currentPrice,
    required double exchangeRate,
    required double adjustedUnit,
    required double locOffsetPercent,
    required double locPrice,
    required double limitSellPrice,
  }) {
    OrderItem? sellLocOrder;
    OrderItem? sellLimitOrder;

    if (cycle.totalShares > 0) {
      // MOC 매도: 1/4
      final sellLocShares =
          (cycle.totalShares * cycle.sellQuarterPercent).clamp(
        0.0,
        cycle.totalShares,
      );
      final sellLocAmountKrw = sellLocShares * currentPrice * exchangeRate;
      sellLocOrder = OrderItem(
        label: 'MOC 매도 (1/4)',
        price: currentPrice,
        shares: sellLocShares,
        amountKrw: sellLocAmountKrw,
        description: 'MOC',
      );

      // 익절가 지정가 매도: 3/4
      final sellLimitShares =
          (cycle.totalShares * (1 - cycle.sellQuarterPercent)).clamp(
        0.0,
        cycle.totalShares,
      );
      final sellLimitAmountKrw =
          sellLimitShares * limitSellPrice * exchangeRate;
      sellLimitOrder = OrderItem(
        label: '지정가 매도 (3/4)',
        price: limitSellPrice,
        shares: sellLimitShares,
        amountKrw: sellLimitAmountKrw,
        description: '+${cycle.takeProfitPercent.toStringAsFixed(1)}%',
      );
    }

    // V3.0 쿼터모드: 5번 추가매수 가능 (quarterModeOffset 고정 오프셋)
    OrderItem? buySingleOrder;
    final canBuy = cycle.remainingCash > 0;
    if (canBuy) {
      final offsetPrice =
          cycle.averagePrice * (1 + cycle.quarterModeOffset / 100);
      final buyAmountKrw = adjustedUnit.clamp(0.0, cycle.remainingCash);
      final shares = (exchangeRate > 0 && offsetPrice > 0)
          ? buyAmountKrw / (offsetPrice * exchangeRate)
          : 0.0;
      buySingleOrder = OrderItem(
        label: 'LOC 추가매수',
        price: offsetPrice,
        shares: shares,
        amountKrw: buyAmountKrw,
        description: '${cycle.quarterModeOffset.toStringAsFixed(1)}%',
      );
    }

    return SteadyOrderGuide(
      tValue: tValue,
      isFirstHalf: false,
      locOffsetPercent: locOffsetPercent,
      locPrice: locPrice,
      limitSellPrice: limitSellPrice,
      canBuy: canBuy,
      isFirstBuy: false,
      isQuarterMode: true,
      adjustedUnitAmount: adjustedUnit,
      buySingleOrder: buySingleOrder,
      sellLocOrder: sellLocOrder,
      sellLimitOrder: sellLimitOrder,
    );
  }
}
