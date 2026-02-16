import 'package:hive/hive.dart';
import '../../core/interfaces/trading_position.dart';

part 'holding.g.dart';

/// 일반 보유 주식 모델
///
/// 알파 사이클 전략 없이 단순 보유하는 주식 정보를 관리합니다.
/// TradingPosition 인터페이스를 구현하여 통합 포트폴리오 관리가 가능합니다.
@HiveType(typeId: 12)
class Holding extends HiveObject implements TradingPosition {
  /// 고유 ID
  @HiveField(0)
  @override
  final String id;

  /// 종목 코드
  @HiveField(1)
  @override
  final String ticker;

  /// 종목명
  @HiveField(2)
  final String name;

  /// 총 보유 수량
  @HiveField(3)
  @override
  double totalShares;

  /// 평균 매수 단가 (USD)
  @HiveField(4)
  @override
  double averagePrice;

  /// 총 투자 금액 (KRW)
  @HiveField(5)
  @override
  double totalInvestedAmount;

  /// 첫 매수일
  @HiveField(6)
  @override
  final DateTime startDate;

  /// 마지막 업데이트 시간
  @HiveField(7)
  DateTime updatedAt;

  /// 적용 환율 (USD/KRW) — 평균 매입환율 (사용자 수정 가능)
  @HiveField(8)
  @override
  double exchangeRate;

  /// 메모
  @HiveField(9)
  String? notes;

  /// 아카이브 여부 (완료 처리된 보유)
  @HiveField(10)
  bool? isArchived;

  Holding({
    required this.id,
    required this.ticker,
    required this.name,
    required this.exchangeRate,
    DateTime? startDate,
    this.notes,
    this.isArchived,
  })  : totalShares = 0,
        averagePrice = 0,
        totalInvestedAmount = 0,
        startDate = startDate ?? DateTime.now(),
        updatedAt = DateTime.now();

  // ═══════════════════════════════════════════════════════════════
  // TradingPosition 인터페이스 구현
  // ═══════════════════════════════════════════════════════════════

  @override
  double currentValue(double currentPrice) {
    return totalShares * currentPrice * exchangeRate;
  }

  @override
  double profitLoss(double currentPrice) {
    return currentValue(currentPrice) - totalInvestedAmount;
  }

  @override
  double returnRate(double currentPrice) {
    if (totalInvestedAmount == 0) return 0;
    return (profitLoss(currentPrice) / totalInvestedAmount) * 100;
  }

  @override
  bool get isEmpty => totalShares == 0;

  @override
  bool get isActive => totalShares > 0;

  // ═══════════════════════════════════════════════════════════════
  // 매수/매도 기록
  // ═══════════════════════════════════════════════════════════════

  /// 매수 기록
  ///
  /// 평균 단가를 가중평균으로 재계산합니다.
  void recordPurchase({
    required double price,
    required double shares,
    required double amountKrw,
  }) {
    final newTotalShares = totalShares + shares;

    // 가중 평균 단가 계산
    if (newTotalShares > 0) {
      final currentValue = totalShares * averagePrice;
      final newValue = shares * price;
      averagePrice = (currentValue + newValue) / newTotalShares;
    }

    totalShares = newTotalShares;
    totalInvestedAmount += amountKrw;
    updatedAt = DateTime.now();
  }

  /// 매도 기록
  ///
  /// 매도 시 투자금액을 비율로 차감합니다.
  void recordSale({
    required double shares,
    required double amountKrw,
  }) {
    if (shares > totalShares) {
      throw StateError('보유 수량보다 많이 매도할 수 없습니다');
    }

    // 투자 금액 비례 차감
    final ratio = shares / totalShares;
    totalInvestedAmount -= totalInvestedAmount * ratio;
    totalShares -= shares;
    updatedAt = DateTime.now();

    // 전량 매도 시 평균 단가 초기화
    if (totalShares == 0) {
      averagePrice = 0;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // 직접 값 설정 (새로운 등록 방식)
  // ═══════════════════════════════════════════════════════════════

  /// 보유 정보 직접 설정
  ///
  /// 매입환율, 매입가, 수량을 직접 설정합니다.
  /// totalInvestedAmount는 purchasePrice * quantity * exchangeRate로 계산됩니다.
  void setHoldingValues({
    required double purchasePrice,
    required int quantity,
    required double purchaseExchangeRate,
  }) {
    averagePrice = purchasePrice;
    totalShares = quantity.toDouble();
    totalInvestedAmount = purchasePrice * quantity * purchaseExchangeRate;
    updatedAt = DateTime.now();
  }

  // ═══════════════════════════════════════════════════════════════
  // 손익 계산 (현재 환율 반영)
  // ═══════════════════════════════════════════════════════════════

  /// 외화 손익 (USD)
  double usdProfitLoss(double currentPrice) {
    return (currentPrice - averagePrice) * totalShares;
  }

  /// 외화 수익률 (%)
  double usdReturnRate(double currentPrice) {
    if (averagePrice == 0) return 0;
    return ((currentPrice - averagePrice) / averagePrice) * 100;
  }

  /// 원화 매입금액
  double krwInvestedAmount() {
    return totalInvestedAmount;
  }

  /// 원화 현재가치 (현재 환율 기준)
  double krwCurrentValue(double currentPrice, double currentExchangeRate) {
    return currentPrice * totalShares * currentExchangeRate;
  }

  /// 원화 총손익
  double krwTotalProfitLoss(double currentPrice, double currentExchangeRate) {
    return krwCurrentValue(currentPrice, currentExchangeRate) - totalInvestedAmount;
  }

  /// 원화 수익률 (%)
  double krwReturnRate(double currentPrice, double currentExchangeRate) {
    if (totalInvestedAmount == 0) return 0;
    return (krwTotalProfitLoss(currentPrice, currentExchangeRate) / totalInvestedAmount) * 100;
  }

  /// 환차 손익 (환율 변동에 의한 손익)
  /// = 평균매입가 × 수량 × 현재환율 - 총투자금액(KRW)
  /// 복수 매수(다른 환율) 및 부분 매도 후에도 정확
  /// 항등식: krwTotalProfitLoss = usdProfitLoss × currentRate + currencyProfitLoss
  double currencyProfitLoss(double currentExchangeRate) {
    return averagePrice * totalShares * currentExchangeRate - totalInvestedAmount;
  }

  /// 아카이브 여부 확인
  bool get isArchivedItem => isArchived == true;

  /// 보유 아카이브 (완료 처리)
  void archive() {
    isArchived = true;
    updatedAt = DateTime.now();
  }

  /// 매입 환율 (기존 exchangeRate 필드 사용)
  double get purchaseExchangeRate => exchangeRate;

  /// 수량 (정수로 반환)
  int get quantity => totalShares.toInt();

  @override
  String toString() {
    return 'Holding(id: $id, ticker: $ticker, name: $name, '
        'shares: ${totalShares.toStringAsFixed(2)}, '
        'avg: \$${averagePrice.toStringAsFixed(2)})';
  }
}
