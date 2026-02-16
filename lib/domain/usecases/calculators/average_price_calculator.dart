/// 평균 단가 계산기
///
/// 평균 단가는 추가 매수할 때마다 변동합니다.
/// 추가 매수를 하면 평균 단가가 낮아져서 익절이 빨라집니다.
///
/// 공식: 총 매수 금액 (USD) ÷ 총 보유 수량
class AveragePriceCalculator {
  const AveragePriceCalculator._();

  /// 평균 단가 계산 (USD)
  ///
  /// [totalInvestedAmountUsd] 총 매수 금액 (USD)
  /// [totalShares] 총 보유 수량
  ///
  /// 예시:
  /// ```dart
  /// // 1차: $100에 100주 매수 = $10,000
  /// AveragePriceCalculator.calculate(10000, 100); // $100
  ///
  /// // 2차: $80에 50주 추가 = $4,000 추가
  /// AveragePriceCalculator.calculate(14000, 150); // $93.33
  /// ```
  static double calculate(double totalInvestedAmountUsd, double totalShares) {
    if (totalShares == 0) return 0;
    return totalInvestedAmountUsd / totalShares;
  }

  /// 원화 기준 평균 단가 계산
  ///
  /// [totalInvestedAmountKrw] 총 매수 금액 (원화)
  /// [totalShares] 총 보유 수량
  /// [exchangeRate] 환율 (원/달러)
  static double calculateFromKrw(
    double totalInvestedAmountKrw,
    double totalShares,
    double exchangeRate,
  ) {
    if (exchangeRate == 0) return 0;
    final totalInvestedUsd = totalInvestedAmountKrw / exchangeRate;
    return calculate(totalInvestedUsd, totalShares);
  }

  /// 추가 매수 후 새 평균 단가 계산
  ///
  /// [currentAvgPrice] 현재 평균 단가 (USD)
  /// [currentShares] 현재 보유 수량
  /// [newBuyPrice] 추가 매수 단가 (USD)
  /// [newBuyShares] 추가 매수 수량
  static double calculateAfterBuy(
    double currentAvgPrice,
    double currentShares,
    double newBuyPrice,
    double newBuyShares,
  ) {
    final currentTotalValue = currentAvgPrice * currentShares;
    final newBuyValue = newBuyPrice * newBuyShares;
    final totalShares = currentShares + newBuyShares;

    if (totalShares == 0) return 0;
    return (currentTotalValue + newBuyValue) / totalShares;
  }

  /// 목표 평균가 달성을 위한 필요 매수 수량 계산
  ///
  /// [currentAvgPrice] 현재 평균 단가 (USD)
  /// [currentShares] 현재 보유 수량
  /// [targetAvgPrice] 목표 평균 단가 (USD)
  /// [buyPrice] 매수 단가 (USD)
  ///
  /// 예시:
  /// 현재 평균 $100, 100주 보유
  /// $80에서 평균을 $90으로 낮추려면?
  /// → (100*100 - 90*100) / (90 - 80) = 100주 필요
  static double calculateRequiredShares(
    double currentAvgPrice,
    double currentShares,
    double targetAvgPrice,
    double buyPrice,
  ) {
    // 공식 유도:
    // (currentAvgPrice * currentShares + buyPrice * x) / (currentShares + x) = targetAvgPrice
    // currentAvgPrice * currentShares + buyPrice * x = targetAvgPrice * currentShares + targetAvgPrice * x
    // x * (buyPrice - targetAvgPrice) = targetAvgPrice * currentShares - currentAvgPrice * currentShares
    // x = (targetAvgPrice - currentAvgPrice) * currentShares / (buyPrice - targetAvgPrice)

    final denominator = buyPrice - targetAvgPrice;
    if (denominator == 0 || denominator >= 0) {
      // 매수가가 목표 평균가보다 높거나 같으면 불가능
      return double.infinity;
    }

    return (targetAvgPrice - currentAvgPrice) * currentShares / denominator;
  }
}
