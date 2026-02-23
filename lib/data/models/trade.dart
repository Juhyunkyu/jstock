import 'package:hive/hive.dart';

part 'trade.g.dart';

/// 거래 유형
@HiveType(typeId: 11)
enum TradeAction {
  /// 초기 진입 (시드 20%)
  @HiveField(0)
  initialBuy,
  /// 가중 매수 (-20% 이하)
  @HiveField(1)
  weightedBuy,
  /// 승부수 (-50% 이하, 1회)
  @HiveField(2)
  panicBuy,
  /// 익절 매도 (+20% 이상)
  @HiveField(3)
  takeProfit,
}

/// 거래 기록 모델
@HiveType(typeId: 2)
class Trade extends HiveObject {
  /// 고유 ID
  @HiveField(0)
  final String id;

  /// 사이클 ID
  @HiveField(1)
  final String cycleId;

  /// 종목 코드
  @HiveField(2)
  final String ticker;

  /// 거래일
  @HiveField(3)
  final DateTime date;

  /// 거래 유형
  @HiveField(4)
  final TradeAction action;

  /// 거래 단가 (USD)
  @HiveField(5)
  final double price;

  /// 거래 수량
  @HiveField(6)
  final double shares;

  /// 권장 금액 (원화) - 알파사이클 공식에 따른 금액
  @HiveField(7)
  final double recommendedAmount;

  /// 실제 투자 금액 (원화) - 사용자가 입력한 실제 금액
  @HiveField(8)
  double? actualAmount;

  /// 체결 여부 - 실제로 거래를 완료했는지
  @HiveField(9)
  bool isExecuted;

  /// 손실률 (%) - 거래 시점의 손실률 (초기진입가 기준)
  @HiveField(10)
  final double lossRate;

  /// 수익률 (%) - 거래 시점의 수익률 (평균단가 기준)
  @HiveField(11)
  final double returnRate;

  /// 메모
  @HiveField(12)
  String? note;

  Trade({
    required this.id,
    required this.cycleId,
    required this.ticker,
    required this.date,
    required this.action,
    required this.price,
    required this.shares,
    required this.recommendedAmount,
    this.actualAmount,
    this.isExecuted = false,
    this.lossRate = 0.0,
    this.returnRate = 0.0,
    this.note,
  });

  /// 거래 유형 표시 이름
  String get actionDisplayName {
    switch (action) {
      case TradeAction.initialBuy:
        return '초기 진입';
      case TradeAction.weightedBuy:
        return '가중 매수';
      case TradeAction.panicBuy:
        return '승부수';
      case TradeAction.takeProfit:
        return '익절';
    }
  }

  /// 거래 유형 이모지
  String get actionEmoji {
    switch (action) {
      case TradeAction.initialBuy:
        return '🟢';
      case TradeAction.weightedBuy:
        return '🔵';
      case TradeAction.panicBuy:
        return '🔴';
      case TradeAction.takeProfit:
        return '💰';
    }
  }

  /// 매수 거래인지 여부
  bool get isBuy =>
      action == TradeAction.initialBuy ||
      action == TradeAction.weightedBuy ||
      action == TradeAction.panicBuy;

  /// 매도 거래인지 여부
  bool get isSell => action == TradeAction.takeProfit;

  /// 거래 금액 (원화)
  /// 실제 투자 금액이 있으면 그것을, 없으면 권장 금액을 반환
  double get amount => actualAmount ?? recommendedAmount;

  /// 권장 금액 대비 실제 투자 비율 (%)
  double? get actualToRecommendedRatio {
    if (actualAmount == null || recommendedAmount == 0) return null;
    return (actualAmount! / recommendedAmount) * 100;
  }

  /// 체결 완료 처리
  void markAsExecuted(double executedAmount) {
    isExecuted = true;
    actualAmount = executedAmount;
  }

  /// 복사본 생성
  Trade copyWith({
    String? id,
    String? cycleId,
    String? ticker,
    DateTime? date,
    TradeAction? action,
    double? price,
    double? shares,
    double? recommendedAmount,
    double? actualAmount,
    bool? isExecuted,
    double? lossRate,
    double? returnRate,
    String? note,
  }) {
    return Trade(
      id: id ?? this.id,
      cycleId: cycleId ?? this.cycleId,
      ticker: ticker ?? this.ticker,
      date: date ?? this.date,
      action: action ?? this.action,
      price: price ?? this.price,
      shares: shares ?? this.shares,
      recommendedAmount: recommendedAmount ?? this.recommendedAmount,
      actualAmount: actualAmount ?? this.actualAmount,
      isExecuted: isExecuted ?? this.isExecuted,
      lossRate: lossRate ?? this.lossRate,
      returnRate: returnRate ?? this.returnRate,
      note: note ?? this.note,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'cycleId': cycleId,
        'ticker': ticker,
        'date': date.toIso8601String(),
        'action': action.name,
        'price': price,
        'shares': shares,
        'recommendedAmount': recommendedAmount,
        'actualAmount': actualAmount,
        'isExecuted': isExecuted,
        'lossRate': lossRate,
        'returnRate': returnRate,
        'note': note,
      };

  factory Trade.fromJson(Map<String, dynamic> json) => Trade(
        id: json['id'] as String,
        cycleId: json['cycleId'] as String,
        ticker: json['ticker'] as String,
        date: DateTime.parse(json['date'] as String),
        action: TradeAction.values.firstWhere(
          (e) => e.name == json['action'],
          orElse: () => TradeAction.initialBuy,
        ),
        price: (json['price'] as num).toDouble(),
        shares: (json['shares'] as num).toDouble(),
        recommendedAmount: (json['recommendedAmount'] as num).toDouble(),
        actualAmount: (json['actualAmount'] as num?)?.toDouble(),
        isExecuted: json['isExecuted'] as bool? ?? false,
        lossRate: (json['lossRate'] as num?)?.toDouble() ?? 0.0,
        returnRate: (json['returnRate'] as num?)?.toDouble() ?? 0.0,
        note: json['note'] as String?,
      );

  @override
  String toString() {
    return 'Trade($actionEmoji $actionDisplayName, $ticker @ \$$price × $shares, '
        '${isExecuted ? "체결" : "미체결"})';
  }
}
