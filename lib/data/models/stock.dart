import 'package:hive/hive.dart';

part 'stock.g.dart';

/// 종목 정보 모델
@HiveType(typeId: 0)
class Stock extends HiveObject {
  /// 종목 코드 (예: TQQQ, SOXL)
  @HiveField(0)
  final String ticker;

  /// 종목명 (예: 나스닥100 3배)
  @HiveField(1)
  final String name;

  /// 현재가 (USD)
  @HiveField(2)
  double currentPrice;

  /// 일간 변동률 (%)
  @HiveField(3)
  double changePercent;

  /// 마지막 업데이트 시간
  @HiveField(4)
  DateTime? lastUpdated;

  Stock({
    required this.ticker,
    required this.name,
    this.currentPrice = 0.0,
    this.changePercent = 0.0,
    this.lastUpdated,
  });

  /// 복사본 생성
  Stock copyWith({
    String? ticker,
    String? name,
    double? currentPrice,
    double? changePercent,
    DateTime? lastUpdated,
  }) {
    return Stock(
      ticker: ticker ?? this.ticker,
      name: name ?? this.name,
      currentPrice: currentPrice ?? this.currentPrice,
      changePercent: changePercent ?? this.changePercent,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  @override
  String toString() {
    return 'Stock(ticker: $ticker, name: $name, price: \$$currentPrice, change: $changePercent%)';
  }
}
