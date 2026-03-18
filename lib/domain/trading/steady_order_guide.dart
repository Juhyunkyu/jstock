/// V2.2/V3.0 복합 주문 가이드 (오늘 걸어야 할 주문 전체)
class SteadyOrderGuide {
  final double tValue;
  final bool isFirstHalf;
  final double locOffsetPercent;
  final double locPrice; // LOC 주문가 (USD)
  final double limitSellPrice; // 지정가 매도가 (USD)
  final bool canBuy; // 매수 가능 여부
  final bool isFirstBuy; // 첫 매수 여부 (averagePrice == 0)
  final bool isQuarterMode; // 쿼터모드 여부
  final double adjustedUnitAmount; // 반복리 적용된 1회 매수금 (KRW)

  final OrderItem? buyOrderA; // 전반전 A주문 (V2.2: 평단, V3.0: 오프셋)
  final OrderItem? buyOrderB; // 전반전 B주문 (V2.2: 오프셋, V3.0: 평단)
  final OrderItem? buySingleOrder; // 후반전 단일주문

  final OrderItem? sellLocOrder; // LOC 매도 (1/4)
  final OrderItem? sellLimitOrder; // 지정가 매도 (3/4)

  const SteadyOrderGuide({
    required this.tValue,
    required this.isFirstHalf,
    required this.locOffsetPercent,
    required this.locPrice,
    required this.limitSellPrice,
    required this.canBuy,
    required this.isFirstBuy,
    required this.isQuarterMode,
    required this.adjustedUnitAmount,
    this.buyOrderA,
    this.buyOrderB,
    this.buySingleOrder,
    this.sellLocOrder,
    this.sellLimitOrder,
  });
}

/// 개별 주문 항목 (매수/매도)
class OrderItem {
  final String label;
  final double price; // USD
  final double shares; // 주문 수량
  final double amountKrw; // 주문 금액 (KRW)
  final String description; // "+4.0%" 등

  const OrderItem({
    required this.label,
    required this.price,
    required this.shares,
    required this.amountKrw,
    required this.description,
  });
}
