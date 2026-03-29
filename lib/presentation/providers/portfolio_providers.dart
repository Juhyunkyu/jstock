import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/cycle.dart';
import '../../domain/trading/ladder_cycle_service.dart';
import '../../domain/trading/trading_math.dart';
import 'core/repository_providers.dart';
import 'cycle_providers.dart';
import 'holding_providers.dart';
import 'api_providers.dart';

/// 통합 포트폴리오 요약 데이터
class UnifiedPortfolioSummary {
  /// 보유 총 자산
  final double holdingValue;

  /// 보유 총 투자금
  final double holdingInvested;

  /// 보유 손익
  final double holdingProfit;

  /// 보유 수익률
  final double holdingReturnRate;

  /// 보유 종목 수
  final int holdingCount;

  /// Smart Cycle 총 자산 (평가금 + 잔여현금)
  final double smartCycleValue;

  /// Smart Cycle 총 투자금 (seedAmount 합계)
  final double smartCycleInvested;

  /// Smart Cycle 손익
  final double smartCycleProfit;

  /// Smart Cycle 수
  final int smartCycleCount;

  /// Steady Cycle 총 자산 (평가금 + 잔여현금)
  final double steadyCycleValue;

  /// Steady Cycle 총 투자금 (seedAmount 합계)
  final double steadyCycleInvested;

  /// Steady Cycle 손익
  final double steadyCycleProfit;

  /// Steady Cycle 수
  final int steadyCycleCount;

  /// Smart Cycle 실제 투입금 (seedAmount - remainingCash 합계)
  final double smartCycleActualInvested;

  /// Steady Cycle 실제 투입금
  final double steadyCycleActualInvested;

  /// Smart Cycle 주식 평가금 (shares × price × exchangeRate, 잔여현금 제외)
  final double smartCycleEvalAmount;

  /// Steady Cycle 주식 평가금
  final double steadyCycleEvalAmount;

  /// Ladder Cycle 총 자산 (평가금 + 잔여현금)
  final double ladderCycleValue;

  /// Ladder Cycle 총 투자금 (seedAmount 합계)
  final double ladderCycleInvested;

  /// Ladder Cycle 손익
  final double ladderCycleProfit;

  /// Ladder Cycle 수
  final int ladderCycleCount;

  /// Ladder Cycle 실제 투입금
  final double ladderCycleActualInvested;

  /// Ladder Cycle 주식 평가금
  final double ladderCycleEvalAmount;

  const UnifiedPortfolioSummary({
    this.holdingValue = 0,
    this.holdingInvested = 0,
    this.holdingProfit = 0,
    this.holdingReturnRate = 0,
    this.holdingCount = 0,
    this.smartCycleValue = 0,
    this.smartCycleInvested = 0,
    this.smartCycleProfit = 0,
    this.smartCycleCount = 0,
    this.steadyCycleValue = 0,
    this.steadyCycleInvested = 0,
    this.steadyCycleProfit = 0,
    this.steadyCycleCount = 0,
    this.smartCycleActualInvested = 0,
    this.steadyCycleActualInvested = 0,
    this.smartCycleEvalAmount = 0,
    this.steadyCycleEvalAmount = 0,
    this.ladderCycleValue = 0,
    this.ladderCycleInvested = 0,
    this.ladderCycleProfit = 0,
    this.ladderCycleCount = 0,
    this.ladderCycleActualInvested = 0,
    this.ladderCycleEvalAmount = 0,
  });

  // === 합산 getters (backward compat) ===

  /// 사이클 총 자산 (Smart + Steady + Ladder)
  double get cycleValue => smartCycleValue + steadyCycleValue + ladderCycleValue;

  /// 사이클 총 투자금 (Smart + Steady + Ladder)
  double get cycleInvested => smartCycleInvested + steadyCycleInvested + ladderCycleInvested;

  /// 사이클 총 손익 (Smart + Steady + Ladder)
  double get cycleProfit => smartCycleProfit + steadyCycleProfit + ladderCycleProfit;

  /// 사이클 총 수 (Smart + Steady + Ladder)
  int get cycleCount => smartCycleCount + steadyCycleCount + ladderCycleCount;

  // === 전체 합산 ===

  /// 전체 자산
  double get totalValue => holdingValue + smartCycleValue + steadyCycleValue + ladderCycleValue;

  /// 전체 투자금
  double get totalInvested => holdingInvested + smartCycleInvested + steadyCycleInvested + ladderCycleInvested;

  /// 전체 손익
  double get totalProfit => holdingProfit + smartCycleProfit + steadyCycleProfit + ladderCycleProfit;

  /// 전체 수익률 (실제 투입금 기준)
  double get totalReturnRate {
    if (totalActualInvested == 0) return 0;
    return (totalProfit / totalActualInvested) * 100;
  }

  // === 비율 getters ===

  /// Smart Cycle 비율 (%)
  double get smartCycleRatio {
    if (totalValue == 0) return 0;
    return (smartCycleValue / totalValue) * 100;
  }

  /// Steady Cycle 비율 (%)
  double get steadyCycleRatio {
    if (totalValue == 0) return 0;
    return (steadyCycleValue / totalValue) * 100;
  }

  /// Ladder Cycle 비율 (%)
  double get ladderCycleRatio {
    if (totalValue == 0) return 0;
    return (ladderCycleValue / totalValue) * 100;
  }

  /// 알파 사이클 비율 (%) — backward compat (Smart + Steady + Ladder)
  double get alphaCycleRatio => smartCycleRatio + steadyCycleRatio + ladderCycleRatio;

  /// 보유 비율 (%)
  double get holdingRatio {
    if (totalValue == 0) return 0;
    return (holdingValue / totalValue) * 100;
  }

  // === 실제 투입금 기준 getters ===

  /// 전체 실제 투입금 (사이클 + 보유)
  double get totalActualInvested =>
      smartCycleActualInvested + steadyCycleActualInvested + ladderCycleActualInvested + holdingInvested;

  /// Smart 투입금 비율 (totalActualInvested 기준)
  double get smartCycleInvestedRatio {
    if (totalActualInvested == 0) return 0;
    return (smartCycleActualInvested / totalActualInvested) * 100;
  }

  /// Steady 투입금 비율
  double get steadyCycleInvestedRatio {
    if (totalActualInvested == 0) return 0;
    return (steadyCycleActualInvested / totalActualInvested) * 100;
  }

  /// Ladder 투입금 비율
  double get ladderCycleInvestedRatio {
    if (totalActualInvested == 0) return 0;
    return (ladderCycleActualInvested / totalActualInvested) * 100;
  }

  /// 보유 투입금 비율
  double get holdingInvestedRatio {
    if (totalActualInvested == 0) return 0;
    return (holdingInvested / totalActualInvested) * 100;
  }

  /// 전체 종목 수
  int get totalPositionCount => holdingCount + cycleCount;

  /// 데이터 존재 여부
  bool get hasData => smartCycleCount > 0 || steadyCycleCount > 0 || ladderCycleCount > 0 || holdingCount > 0;

  /// 이상 데이터 감지 (음수 자산, 음수 투자금 등)
  bool get hasAnomalousData =>
      holdingValue < 0 ||
      holdingInvested < 0 ||
      smartCycleValue < 0 ||
      smartCycleInvested < 0 ||
      steadyCycleValue < 0 ||
      steadyCycleInvested < 0 ||
      ladderCycleValue < 0 ||
      ladderCycleInvested < 0 ||
      totalValue.isNaN ||
      totalInvested.isNaN;
}

/// 통합 포트폴리오 Provider
final unifiedPortfolioProvider =
    Provider.family<UnifiedPortfolioSummary, Map<String, double>>((ref, prices) {
  // 보유 데이터
  final activeHoldings = ref.watch(activeHoldingsProvider);
  final holdingTotalValue = ref.watch(holdingTotalValueProvider(prices));
  final holdingTotalInvested = ref.watch(holdingTotalInvestedProvider);
  final holdingTotalProfit = ref.watch(holdingTotalProfitProvider(prices));

  // 보유 수익률 계산
  double holdingReturnRate = 0;
  if (holdingTotalInvested > 0) {
    holdingReturnRate = (holdingTotalProfit / holdingTotalInvested) * 100;
  }

  // 사이클 데이터 (Smart / Steady 분리)
  final activeCycles = ref.watch(activeCyclesProvider);
  final liveExchangeRate = ref.watch(currentExchangeRateProvider);

  double smartValue = 0, smartInvested = 0;
  double steadyValue = 0, steadyInvested = 0;
  double ladderValue = 0, ladderInvested = 0;
  double smartActualInvested = 0, steadyActualInvested = 0, ladderActualInvested = 0;
  double smartEvalAmt = 0, steadyEvalAmt = 0, ladderEvalAmt = 0;
  int smartCount = 0, steadyCount = 0, ladderCount = 0;

  // (F-15) 안정형 Ladder Cycle에서 Trade 기반 평가금 계산을 위해 tradeRepository 참조
  final tradeRepo = ref.read(tradeRepositoryProvider);

  for (final cycle in activeCycles) {
    double evalAmt;

    if (cycle.strategyType == StrategyType.ladderCycle && cycle.ladderMode == 0) {
      // (F-15) 안정형: Trade 기반 buildTickerHoldings()로 티커별 평가금 합산
      final trades = tradeRepo.getByCycleId(cycle.id);
      final currentPrices = <String, double>{};
      final usedTickers = trades.map((t) => t.ticker ?? cycle.ticker).toSet();
      for (final ticker in usedTickers) {
        currentPrices[ticker] = prices[ticker] ?? 0;
      }
      final holdings = buildTickerHoldings(trades, cycle.ticker, currentPrices, liveExchangeRate);
      evalAmt = holdings.fold<double>(0, (sum, h) => sum + h.evalAmount);
    } else {
      // 공격형 Ladder: buyTicker 가격으로 평가 / Smart/Steady: cycle.ticker 가격
      final priceTicker = (cycle.strategyType == StrategyType.ladderCycle && cycle.buyTicker.isNotEmpty)
          ? cycle.buyTicker
          : cycle.ticker;
      final currentPrice = prices[priceTicker] ?? 0;
      evalAmt = TradingMath.evaluatedAmount(
        cycle.totalShares,
        currentPrice,
        liveExchangeRate,
      );
    }

    final actualInvested = cycle.seedAmount - cycle.remainingCash;

    // 전량매도 대기: 매수총액이 투자금, 매도총액이 자산
    // 진행 중: 실제투입이 투자금, 주식평가금이 자산
    final cycleValue = cycle.isPendingCompletion ? cycle.totalSellAmountKrw : evalAmt;
    final cycleInvested = cycle.isPendingCompletion ? cycle.totalBuyAmountKrw : actualInvested;

    if (cycle.strategyType == StrategyType.alphaCycleV3) {
      smartValue += cycleValue;
      smartInvested += cycleInvested;
      smartActualInvested += cycleInvested;
      smartEvalAmt += evalAmt;
      smartCount++;
    } else if (cycle.strategyType == StrategyType.ladderCycle) {
      ladderValue += cycleValue;
      ladderInvested += cycleInvested;
      ladderActualInvested += cycleInvested;
      ladderEvalAmt += evalAmt;
      ladderCount++;
    } else {
      steadyValue += cycleValue;
      steadyInvested += cycleInvested;
      steadyActualInvested += cycleInvested;
      steadyEvalAmt += evalAmt;
      steadyCount++;
    }
  }

  return UnifiedPortfolioSummary(
    holdingValue: holdingTotalValue,
    holdingInvested: holdingTotalInvested,
    holdingProfit: holdingTotalProfit,
    holdingReturnRate: holdingReturnRate,
    holdingCount: activeHoldings.length,
    smartCycleValue: smartValue,
    smartCycleInvested: smartInvested,
    smartCycleProfit: smartValue - smartInvested,
    smartCycleCount: smartCount,
    steadyCycleValue: steadyValue,
    steadyCycleInvested: steadyInvested,
    steadyCycleProfit: steadyValue - steadyInvested,
    steadyCycleCount: steadyCount,
    smartCycleActualInvested: smartActualInvested,
    steadyCycleActualInvested: steadyActualInvested,
    smartCycleEvalAmount: smartEvalAmt,
    steadyCycleEvalAmount: steadyEvalAmt,
    ladderCycleValue: ladderValue,
    ladderCycleInvested: ladderInvested,
    ladderCycleProfit: ladderValue - ladderInvested,
    ladderCycleCount: ladderCount,
    ladderCycleActualInvested: ladderActualInvested,
    ladderCycleEvalAmount: ladderEvalAmt,
  );
});

/// 전체 자산 Provider
final totalAssetProvider = Provider.family<double, Map<String, double>>((ref, prices) {
  return ref.watch(unifiedPortfolioProvider(prices)).totalValue;
});

/// 전체 손익 Provider
final totalProfitProvider = Provider.family<double, Map<String, double>>((ref, prices) {
  return ref.watch(unifiedPortfolioProvider(prices)).totalProfit;
});

/// 전체 수익률 Provider
final totalReturnRateProvider = Provider.family<double, Map<String, double>>((ref, prices) {
  return ref.watch(unifiedPortfolioProvider(prices)).totalReturnRate;
});

/// 보유 비율 Provider
final holdingRatioProvider = Provider.family<double, Map<String, double>>((ref, prices) {
  return ref.watch(unifiedPortfolioProvider(prices)).holdingRatio;
});
