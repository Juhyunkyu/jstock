import 'package:hive/hive.dart';

part 'holding_transaction.g.dart';

/// 보유 거래 유형
@HiveType(typeId: 14)
enum HoldingTransactionType {
  /// 매수
  @HiveField(0)
  buy,

  /// 매도
  @HiveField(1)
  sell,
}

/// 보유 주식 거래 내역
///
/// 일반 보유 주식의 매수/매도 거래를 기록합니다.
@HiveType(typeId: 13)
class HoldingTransaction extends HiveObject {
  /// 고유 ID
  @HiveField(0)
  final String id;

  /// 보유 ID (Holding.id)
  @HiveField(1)
  final String holdingId;

  /// 종목 코드
  @HiveField(2)
  final String ticker;

  /// 거래 일시
  @HiveField(3)
  final DateTime date;

  /// 거래 유형 (매수/매도)
  @HiveField(4)
  final HoldingTransactionType type;

  /// 거래 가격 (USD)
  @HiveField(5)
  final double price;

  /// 거래 수량
  @HiveField(6)
  final double shares;

  /// 거래 금액 (KRW)
  @HiveField(7)
  final double amountKrw;

  /// 적용 환율
  @HiveField(8)
  final double exchangeRate;

  /// 메모
  @HiveField(9)
  String? note;

  /// 첫 매수 여부 (기존 데이터 호환을 위해 nullable)
  @HiveField(10, defaultValue: false)
  final bool? _isInitialPurchase;

  /// 매도 시 실현손익 (KRW) — 매도 거래에만 값 존재
  @HiveField(11)
  final double? realizedPnlKrw;

  HoldingTransaction({
    required this.id,
    required this.holdingId,
    required this.ticker,
    required this.date,
    required this.type,
    required this.price,
    required this.shares,
    required this.amountKrw,
    required this.exchangeRate,
    this.note,
    bool isInitialPurchase = false,
    this.realizedPnlKrw,
  }) : _isInitialPurchase = isInitialPurchase;

  /// 첫 매수 여부 (null이면 false 반환)
  bool get isInitialPurchase => _isInitialPurchase ?? false;

  /// 매수 거래 여부
  bool get isBuy => type == HoldingTransactionType.buy;

  /// 매도 거래 여부
  bool get isSell => type == HoldingTransactionType.sell;

  /// 거래 금액 (USD)
  double get amountUsd => price * shares;

  @override
  String toString() {
    final typeStr = isBuy ? '매수' : '매도';
    return 'HoldingTransaction($typeStr: $ticker, '
        '${shares.toStringAsFixed(2)}주 @ \$${price.toStringAsFixed(2)})';
  }
}
