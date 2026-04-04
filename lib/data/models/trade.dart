import 'package:hive/hive.dart';

part 'trade.g.dart';

@HiveType(typeId: 21)
enum TradeSignal {
  // Strategy A: Alpha Cycle V3
  @HiveField(0)
  initial,
  @HiveField(1)
  weightedBuy,
  @HiveField(2)
  panicBuy,
  @HiveField(3)
  cashSecure,
  @HiveField(4)
  takeProfit,

  // Strategy B: 순정 무한매수법
  @HiveField(5)
  locA,
  @HiveField(6)
  locB,
  @HiveField(7)
  locAB,

  // 공통
  @HiveField(8)
  manual,
  @HiveField(9)
  hold,

  // Strategy B: Steady V2.2/V3.0 (신규)
  @HiveField(10)
  sellLocQuarter,
  @HiveField(11)
  sellLimitThreeQ,
  @HiveField(12)
  takeProfitFull,
  @HiveField(13)
  buySingle,
  @HiveField(14)
  noFill,

  // Strategy C: Ladder Cycle
  @HiveField(15)
  ladderStep1,
  @HiveField(16)
  ladderStep2,
  @HiveField(17)
  ladderStep3,
  @HiveField(18)
  ladderStep4,
  @HiveField(19)
  ladderStep5,
  @HiveField(20)
  ladderStep6,
}

@HiveType(typeId: 11)
enum TradeAction {
  @HiveField(0)
  buy,
  @HiveField(1)
  sell,
}

@HiveType(typeId: 2)
class Trade extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String cycleId;

  @HiveField(2)
  TradeAction action;

  @HiveField(3)
  TradeSignal signal;

  @HiveField(4)
  double price;

  @HiveField(5)
  double shares;

  @HiveField(6)
  double amountKrw;

  @HiveField(7)
  double exchangeRate;

  @HiveField(8)
  DateTime tradedAt;

  @HiveField(9)
  String? memo;

  /// 같은 세션에서 기록된 거래끼리 묶는 그룹 ID (LOC A+B 통합 표시용)
  @HiveField(10)
  String? groupId;

  /// 거래 티커 (Ladder 안정형 멀티 티커용, null이면 cycle.ticker 사용)
  @HiveField(11)
  String? ticker;

  /// 이 거래와 함께 투입된 추가 자금 (KRW). 삭제 시 시드에서 차감 복원용.
  @HiveField(12, defaultValue: 0.0)
  double extraFundingAmount;

  Trade({
    required this.id,
    required this.cycleId,
    required this.action,
    required this.signal,
    required this.price,
    required this.shares,
    required this.amountKrw,
    required this.exchangeRate,
    DateTime? tradedAt,
    this.memo,
    this.groupId,
    this.ticker,
    this.extraFundingAmount = 0.0,
  }) : tradedAt = tradedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'cycleId': cycleId,
    'action': action.name,
    'signal': signal.name,
    'price': price,
    'shares': shares,
    'amountKrw': amountKrw,
    'exchangeRate': exchangeRate,
    'tradedAt': tradedAt.toIso8601String(),
    'memo': memo,
    'groupId': groupId,
    'ticker': ticker,
    'extraFundingAmount': extraFundingAmount,
  };

  static TradeSignal _parseTradeSignal(String value) {
    try {
      return TradeSignal.values.byName(value);
    } catch (_) {
      return TradeSignal.manual;
    }
  }

  factory Trade.fromJson(Map<String, dynamic> json) => Trade(
    id: json['id'] as String,
    cycleId: json['cycleId'] as String,
    action: TradeAction.values.byName(json['action'] as String),
    signal: _parseTradeSignal(json['signal'] as String),
    price: (json['price'] as num).toDouble(),
    shares: (json['shares'] as num).toDouble(),
    amountKrw: (json['amountKrw'] as num).toDouble(),
    exchangeRate: (json['exchangeRate'] as num).toDouble(),
    tradedAt: DateTime.parse(json['tradedAt'] as String),
    memo: json['memo'] as String?,
    groupId: json['groupId'] as String?,
    ticker: json['ticker'] as String?,
    extraFundingAmount: (json['extraFundingAmount'] as num?)?.toDouble() ?? 0.0,
  );

  @override
  String toString() {
    return 'Trade(id: $id, cycle: $cycleId, ${action.name} ${signal.name}, '
        '${shares.toStringAsFixed(4)} @ \$${price.toStringAsFixed(2)})';
  }
}
