/// 수익률 계산기
///
/// 수익률은 항상 **평균 단가** 기준으로 계산합니다.
/// 추가 매수를 하면 평균 단가가 낮아져서 익절이 빨라집니다.
///
/// 공식: (현재가 - 평균단가) ÷ 평균단가 × 100
class ReturnCalculator {
  const ReturnCalculator._();

  /// 수익률 계산 (%)
  ///
  /// [currentPrice] 현재 주가 (USD)
  /// [averagePrice] 평균 단가 (USD) - 변동값
  ///
  /// 반환값:
  /// - 양수: 수익 (예: +20%)
  /// - 음수: 손실 (예: -10%)
  /// - 0: 변동 없음
  ///
  /// 예시:
  /// ```dart
  /// ReturnCalculator.calculate(90, 75); // 20.0
  /// ReturnCalculator.calculate(60, 75); // -20.0
  /// ```
  static double calculate(double currentPrice, double averagePrice) {
    if (averagePrice == 0) return 0;
    return ((currentPrice - averagePrice) / averagePrice) * 100;
  }

  /// 수익률이 특정 임계값 이상인지 확인
  ///
  /// [threshold] 기준 수익률 (예: 20)
  static bool isAboveThreshold(
    double currentPrice,
    double averagePrice,
    double threshold,
  ) {
    return calculate(currentPrice, averagePrice) >= threshold;
  }

  /// 익절 조건 충족 여부 (수익률 >= +20%)
  static bool shouldTakeProfit(double currentPrice, double averagePrice) {
    return isAboveThreshold(currentPrice, averagePrice, 20);
  }

  /// 목표 익절가 계산
  ///
  /// [averagePrice] 평균 단가 (USD)
  /// [targetReturnRate] 목표 수익률 (기본: 20%)
  ///
  /// 예시:
  /// ```dart
  /// ReturnCalculator.calculateTargetPrice(75, 20); // 90.0
  /// ```
  static double calculateTargetPrice(
    double averagePrice, [
    double targetReturnRate = 20,
  ]) {
    return averagePrice * (1 + targetReturnRate / 100);
  }
}
