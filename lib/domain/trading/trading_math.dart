/// 두 전략에서 중복되는 계산을 하나로 중앙화
class TradingMath {
  TradingMath._();

  /// 수익률 계산 (두 전략 공통)
  /// Zero-guard: averagePrice가 0이면 0.0 반환
  static double returnRate(double currentPrice, double averagePrice) {
    if (averagePrice == 0) return 0.0;
    return (currentPrice - averagePrice) / averagePrice * 100;
  }

  /// 평가금액 (KRW)
  static double evaluatedAmount(
    double totalShares,
    double currentPrice,
    double exchangeRate,
  ) =>
      totalShares * currentPrice * exchangeRate;

  /// 평균단가 재계산 (매수 후)
  /// Zero-guard: newBuyPrice, exchangeRate, totalShares가 0이면 0.0 반환
  static double recalcAveragePrice({
    required double prevTotalCostKrw,
    required double prevTotalShares,
    required double newBuyAmountKrw,
    required double newBuyPrice,
    required double exchangeRate,
  }) {
    if (newBuyPrice == 0 || exchangeRate == 0) return 0.0;
    final newShares = newBuyAmountKrw / (newBuyPrice * exchangeRate);
    final totalShares = prevTotalShares + newShares;
    if (totalShares == 0) return 0.0;
    final totalCostKrw = prevTotalCostKrw + newBuyAmountKrw;
    return totalCostKrw / (totalShares * exchangeRate);
  }
}
