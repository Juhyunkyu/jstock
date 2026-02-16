import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'cycle_providers.dart';
import 'holding_providers.dart';

/// 통합 포트폴리오 요약 데이터
class UnifiedPortfolioSummary {
  /// 알파 사이클 총 자산
  final double alphaCycleValue;

  /// 알파 사이클 총 투자금
  final double alphaCycleInvested;

  /// 알파 사이클 손익
  final double alphaCycleProfit;

  /// 알파 사이클 수익률
  final double alphaCycleReturnRate;

  /// 알파 사이클 수
  final int alphaCycleCount;

  /// 일반 보유 총 자산
  final double holdingValue;

  /// 일반 보유 총 투자금
  final double holdingInvested;

  /// 일반 보유 손익
  final double holdingProfit;

  /// 일반 보유 수익률
  final double holdingReturnRate;

  /// 일반 보유 종목 수
  final int holdingCount;

  const UnifiedPortfolioSummary({
    this.alphaCycleValue = 0,
    this.alphaCycleInvested = 0,
    this.alphaCycleProfit = 0,
    this.alphaCycleReturnRate = 0,
    this.alphaCycleCount = 0,
    this.holdingValue = 0,
    this.holdingInvested = 0,
    this.holdingProfit = 0,
    this.holdingReturnRate = 0,
    this.holdingCount = 0,
  });

  /// 전체 자산
  double get totalValue => alphaCycleValue + holdingValue;

  /// 전체 투자금
  double get totalInvested => alphaCycleInvested + holdingInvested;

  /// 전체 손익
  double get totalProfit => alphaCycleProfit + holdingProfit;

  /// 전체 수익률
  double get totalReturnRate {
    if (totalInvested == 0) return 0;
    return (totalProfit / totalInvested) * 100;
  }

  /// 알파 사이클 비율 (%)
  double get alphaCycleRatio {
    if (totalValue == 0) return 0;
    return (alphaCycleValue / totalValue) * 100;
  }

  /// 일반 보유 비율 (%)
  double get holdingRatio {
    if (totalValue == 0) return 0;
    return (holdingValue / totalValue) * 100;
  }

  /// 전체 종목/사이클 수
  int get totalPositionCount => alphaCycleCount + holdingCount;

  /// 데이터 존재 여부
  bool get hasData => alphaCycleCount > 0 || holdingCount > 0;
}

/// 통합 포트폴리오 Provider
final unifiedPortfolioProvider =
    Provider.family<UnifiedPortfolioSummary, Map<String, double>>((ref, prices) {
  // 알파 사이클 데이터
  final activeCycles = ref.watch(activeCyclesProvider);
  final cyclePortfolio = ref.watch(portfolioSummaryProvider(prices));

  // 일반 보유 데이터
  final activeHoldings = ref.watch(activeHoldingsProvider);
  final holdingTotalValue = ref.watch(holdingTotalValueProvider(prices));
  final holdingTotalInvested = ref.watch(holdingTotalInvestedProvider);
  final holdingTotalProfit = ref.watch(holdingTotalProfitProvider(prices));

  // 일반 보유 수익률 계산
  double holdingReturnRate = 0;
  if (holdingTotalInvested > 0) {
    holdingReturnRate = (holdingTotalProfit / holdingTotalInvested) * 100;
  }

  return UnifiedPortfolioSummary(
    // 알파 사이클
    alphaCycleValue: cyclePortfolio.totalValue,
    alphaCycleInvested: cyclePortfolio.totalInvested,
    alphaCycleProfit: cyclePortfolio.totalProfit,
    alphaCycleReturnRate: cyclePortfolio.profitRate,
    alphaCycleCount: activeCycles.length,
    // 일반 보유
    holdingValue: holdingTotalValue,
    holdingInvested: holdingTotalInvested,
    holdingProfit: holdingTotalProfit,
    holdingReturnRate: holdingReturnRate,
    holdingCount: activeHoldings.length,
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

/// 알파 사이클 비율 Provider
final alphaCycleRatioProvider = Provider.family<double, Map<String, double>>((ref, prices) {
  return ref.watch(unifiedPortfolioProvider(prices)).alphaCycleRatio;
});

/// 일반 보유 비율 Provider
final holdingRatioProvider = Provider.family<double, Map<String, double>>((ref, prices) {
  return ref.watch(unifiedPortfolioProvider(prices)).holdingRatio;
});
