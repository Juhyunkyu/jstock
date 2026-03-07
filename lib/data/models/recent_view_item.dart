import 'package:hive/hive.dart';

part 'recent_view_item.g.dart';

/// 최근 조회 종목 모델
@HiveType(typeId: 23)
class RecentViewItem extends HiveObject {
  /// 티커 심볼
  @HiveField(0)
  String ticker;

  /// 종목명
  @HiveField(1)
  String name;

  /// 거래소
  @HiveField(2)
  String exchange;

  /// 종목 유형 (EQUITY, ETF, INDEX)
  @HiveField(3)
  String type;

  /// 마지막 조회 시각
  @HiveField(4)
  DateTime viewedAt;

  RecentViewItem({
    required this.ticker,
    required this.name,
    this.exchange = '',
    this.type = '',
    DateTime? viewedAt,
  }) : viewedAt = viewedAt ?? DateTime.now();

  /// 최대 최근 조회 수
  static const int maxRecentItems = 15;

  Map<String, dynamic> toJson() => {
        'ticker': ticker,
        'name': name,
        'exchange': exchange,
        'type': type,
        'viewedAt': viewedAt.toIso8601String(),
      };

  factory RecentViewItem.fromJson(Map<String, dynamic> json) =>
      RecentViewItem(
        ticker: json['ticker'] as String,
        name: json['name'] as String,
        exchange: json['exchange'] as String? ?? '',
        type: json['type'] as String? ?? '',
        viewedAt: json['viewedAt'] != null
            ? DateTime.parse(json['viewedAt'] as String)
            : null,
      );
}
