/// 트레이딩 포지션 기본 인터페이스
///
/// 모든 포트폴리오 포지션(알파 사이클, 일반 보유 등)이 구현해야 하는 기본 인터페이스.
/// 통합 포트폴리오 계산 및 표시에 사용됩니다.
abstract class TradingPosition {
  /// 고유 식별자
  String get id;

  /// 종목 티커 심볼
  String get ticker;

  /// 총 보유 수량
  double get totalShares;

  /// 평균 매수 단가 (USD)
  double get averagePrice;

  /// 총 투자 금액 (KRW)
  double get totalInvestedAmount;

  /// 포지션 시작일
  DateTime get startDate;

  /// 적용 환율 (USD/KRW)
  double get exchangeRate;

  /// 현재 가치 계산 (KRW)
  ///
  /// [currentPrice] - 현재 주가 (USD)
  double currentValue(double currentPrice) {
    return totalShares * currentPrice * exchangeRate;
  }

  /// 손익 계산 (KRW)
  ///
  /// [currentPrice] - 현재 주가 (USD)
  double profitLoss(double currentPrice) {
    return currentValue(currentPrice) - totalInvestedAmount;
  }

  /// 수익률 계산 (%)
  ///
  /// [currentPrice] - 현재 주가 (USD)
  double returnRate(double currentPrice) {
    if (totalInvestedAmount == 0) return 0;
    return (profitLoss(currentPrice) / totalInvestedAmount) * 100;
  }

  /// 포지션이 비어있는지 여부 (보유 수량 0)
  bool get isEmpty => totalShares == 0;

  /// 포지션이 활성 상태인지 여부 (보유 수량 > 0)
  bool get isActive => totalShares > 0;
}
