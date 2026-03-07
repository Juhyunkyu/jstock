import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/trading/trading_math.dart';
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

  /// 사이클 총 자산 (평가금 + 잔여현금)
  final double cycleValue;

  /// 사이클 총 투자금 (seedAmount 합계)
  final double cycleInvested;

  /// 사이클 손익
  final double cycleProfit;

  /// 사이클 수
  final int cycleCount;

  const UnifiedPortfolioSummary({
    this.holdingValue = 0,
    this.holdingInvested = 0,
    this.holdingProfit = 0,
    this.holdingReturnRate = 0,
    this.holdingCount = 0,
    this.cycleValue = 0,
    this.cycleInvested = 0,
    this.cycleProfit = 0,
    this.cycleCount = 0,
  });

  /// 전체 자산
  double get totalValue => holdingValue + cycleValue;

  /// 전체 투자금
  double get totalInvested => holdingInvested + cycleInvested;

  /// 전체 손익
  double get totalProfit => holdingProfit + cycleProfit;

  /// 전체 수익률
  double get totalReturnRate {
    if (totalInvested == 0) return 0;
    return (totalProfit / totalInvested) * 100;
  }

  /// 알파 사이클 비율 (%)
  double get alphaCycleRatio {
    if (totalValue == 0) return 0;
    return (cycleValue / totalValue) * 100;
  }

  /// 보유 비율 (%)
  double get holdingRatio {
    if (totalValue == 0) return 0;
    return (holdingValue / totalValue) * 100;
  }

  /// 전체 종목 수
  int get totalPositionCount => holdingCount + cycleCount;

  /// 데이터 존재 여부
  bool get hasData => holdingCount > 0 || cycleCount > 0;

  /// 이상 데이터 감지 (음수 자산, 음수 투자금 등)
  bool get hasAnomalousData =>
      holdingValue < 0 ||
      holdingInvested < 0 ||
      cycleValue < 0 ||
      cycleInvested < 0 ||
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

  // 사이클 데이터
  final activeCycles = ref.watch(activeCyclesProvider);
  final liveExchangeRate = ref.watch(currentExchangeRateProvider);

  double cycleValueTotal = 0;
  double cycleInvestedTotal = 0;
  for (final cycle in activeCycles) {
    final currentPrice = prices[cycle.ticker] ?? 0;
    final evalAmt = TradingMath.evaluatedAmount(
      cycle.totalShares,
      currentPrice,
      liveExchangeRate,
    );
    cycleValueTotal += evalAmt + cycle.remainingCash;
    cycleInvestedTotal += cycle.seedAmount;
  }
  final cycleProfitTotal = cycleValueTotal - cycleInvestedTotal;

  return UnifiedPortfolioSummary(
    holdingValue: holdingTotalValue,
    holdingInvested: holdingTotalInvested,
    holdingProfit: holdingTotalProfit,
    holdingReturnRate: holdingReturnRate,
    holdingCount: activeHoldings.length,
    cycleValue: cycleValueTotal,
    cycleInvested: cycleInvestedTotal,
    cycleProfit: cycleProfitTotal,
    cycleCount: activeCycles.length,
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
