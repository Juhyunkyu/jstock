import '../../../core/constants/formula_constants.dart';

/// 승부수 금액 계산기
///
/// 조건: 손실률 **-50% 이하**, 사이클당 **1회만**
///
/// 공식: 초기진입금 × 0.50
class PanicBuyCalculator {
  const PanicBuyCalculator._();

  /// 승부수 금액 계산 (원화)
  ///
  /// [initialEntryAmount] 초기 진입금 (원화)
  ///
  /// 예시 (시드 1억, 초기진입금 2,000만원):
  /// ```dart
  /// PanicBuyCalculator.calculate(20000000); // 10,000,000원 (1,000만원)
  /// ```
  static double calculate(double initialEntryAmount) {
    return initialEntryAmount * FormulaConstants.panicBuyRatio;
  }

  /// 승부수 조건 충족 여부
  ///
  /// [lossRate] 현재 손실률 (%)
  /// [panicUsed] 이미 승부수를 사용했는지 여부
  static bool canExecute(double lossRate, bool panicUsed) {
    return lossRate <= FormulaConstants.panicTriggerPercent && !panicUsed;
  }

  /// 승부수로 살 수 있는 주식 수량 계산
  ///
  /// [panicAmount] 승부수 금액 (원화)
  /// [currentPrice] 현재 주가 (USD)
  /// [exchangeRate] 환율 (원/달러)
  static double calculateShares(
    double panicAmount,
    double currentPrice,
    double exchangeRate,
  ) {
    if (currentPrice == 0 || exchangeRate == 0) return 0;
    final panicAmountUsd = panicAmount / exchangeRate;
    return panicAmountUsd / currentPrice;
  }

  /// 승부수 발동 시 총 매수 금액 (승부수 + 가중매수)
  ///
  /// [initialEntryAmount] 초기 진입금 (원화)
  /// [lossRate] 현재 손실률 (%)
  static double calculateTotalWithWeighted(
    double initialEntryAmount,
    double lossRate,
  ) {
    final panicAmount = calculate(initialEntryAmount);
    final weightedAmount =
        initialEntryAmount * lossRate.abs() / FormulaConstants.weightedBuyDivisor;
    return panicAmount + weightedAmount;
  }
}
