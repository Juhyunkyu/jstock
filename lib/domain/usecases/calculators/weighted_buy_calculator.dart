import '../../../core/constants/formula_constants.dart';

/// 가중 매수 금액 계산기
///
/// 조건: 손실률이 **-20% 이하**일 때 **매일** 매수
///
/// 공식: 초기진입금 × |손실률| ÷ 1000
class WeightedBuyCalculator {
  const WeightedBuyCalculator._();

  /// 가중 매수 금액 계산 (원화)
  ///
  /// [initialEntryAmount] 초기 진입금 (원화)
  /// [lossRate] 손실률 (%, 음수값)
  ///
  /// 예시 (시드 1억, 초기진입금 2,000만원):
  /// ```dart
  /// WeightedBuyCalculator.calculate(20000000, -20); // 400,000원
  /// WeightedBuyCalculator.calculate(20000000, -25); // 500,000원
  /// WeightedBuyCalculator.calculate(20000000, -50); // 1,000,000원
  /// ```
  static double calculate(double initialEntryAmount, double lossRate) {
    final absLossRate = lossRate.abs();
    return initialEntryAmount * absLossRate / FormulaConstants.weightedBuyDivisor;
  }

  /// 현재가 기반 가중 매수 금액 계산
  ///
  /// [initialEntryAmount] 초기 진입금 (원화)
  /// [currentPrice] 현재 주가 (USD)
  /// [initialEntryPrice] 초기 진입가 (USD)
  static double calculateFromPrice(
    double initialEntryAmount,
    double currentPrice,
    double initialEntryPrice,
  ) {
    if (initialEntryPrice == 0) return 0;
    final lossRate = ((currentPrice - initialEntryPrice) / initialEntryPrice) * 100;
    return calculate(initialEntryAmount, lossRate);
  }

  /// 가중 매수로 살 수 있는 주식 수량 계산
  ///
  /// [buyAmount] 매수 금액 (원화)
  /// [currentPrice] 현재 주가 (USD)
  /// [exchangeRate] 환율 (원/달러)
  static double calculateShares(
    double buyAmount,
    double currentPrice,
    double exchangeRate,
  ) {
    if (currentPrice == 0 || exchangeRate == 0) return 0;
    final buyAmountUsd = buyAmount / exchangeRate;
    return buyAmountUsd / currentPrice;
  }

  /// 손실률별 매수 금액 테이블 생성
  ///
  /// [initialEntryAmount] 초기 진입금 (원화)
  ///
  /// 반환: Map<손실률, 매수금액>
  static Map<int, double> generateBuyTable(double initialEntryAmount) {
    final table = <int, double>{};
    for (int loss = -20; loss >= -80; loss -= 2) {
      table[loss] = calculate(initialEntryAmount, loss.toDouble());
    }
    return table;
  }
}
