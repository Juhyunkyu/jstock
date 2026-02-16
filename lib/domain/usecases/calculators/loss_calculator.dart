/// 손실률 계산기
///
/// 손실률은 항상 **초기 진입가** 기준으로 계산합니다.
/// 추가 매수를 해도 초기 진입가는 **절대 변하지 않습니다**.
///
/// 공식: (현재가 - 초기진입가) ÷ 초기진입가 × 100
class LossCalculator {
  const LossCalculator._();

  /// 손실률 계산 (%)
  ///
  /// [currentPrice] 현재 주가 (USD)
  /// [initialEntryPrice] 초기 진입가 (USD) - 고정값
  ///
  /// 반환값:
  /// - 음수: 손실 (예: -20%)
  /// - 양수: 이익 (예: +10%)
  /// - 0: 변동 없음
  ///
  /// 예시:
  /// ```dart
  /// LossCalculator.calculate(80, 100); // -20.0
  /// LossCalculator.calculate(120, 100); // 20.0
  /// LossCalculator.calculate(50, 100); // -50.0
  /// ```
  static double calculate(double currentPrice, double initialEntryPrice) {
    if (initialEntryPrice == 0) return 0;
    return ((currentPrice - initialEntryPrice) / initialEntryPrice) * 100;
  }

  /// 손실률이 특정 임계값 이하인지 확인
  ///
  /// [threshold] 기준 손실률 (예: -20)
  static bool isBelowThreshold(
    double currentPrice,
    double initialEntryPrice,
    double threshold,
  ) {
    return calculate(currentPrice, initialEntryPrice) <= threshold;
  }

  /// 가중 매수 조건 충족 여부 (손실률 <= -20%)
  static bool shouldWeightedBuy(double currentPrice, double initialEntryPrice) {
    return isBelowThreshold(currentPrice, initialEntryPrice, -20);
  }

  /// 승부수 조건 충족 여부 (손실률 <= -50%)
  static bool shouldPanicBuy(double currentPrice, double initialEntryPrice) {
    return isBelowThreshold(currentPrice, initialEntryPrice, -50);
  }
}
