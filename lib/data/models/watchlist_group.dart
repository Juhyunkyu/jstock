import 'package:hive/hive.dart';

part 'watchlist_group.g.dart';

/// 관심종목 그룹 모델
@HiveType(typeId: 22)
class WatchlistGroup extends HiveObject {
  /// 고유 ID (UUID 또는 'default')
  @HiveField(0)
  String id;

  /// 그룹 이름
  @HiveField(1)
  String name;

  /// 그룹 내 티커 목록 (순서 유지)
  @HiveField(2)
  List<String> tickers;

  /// 탭 정렬 순서
  @HiveField(3)
  int sortOrder;

  /// 생성 일시
  @HiveField(4)
  DateTime createdAt;

  WatchlistGroup({
    required this.id,
    required this.name,
    List<String>? tickers,
    this.sortOrder = 0,
    DateTime? createdAt,
  })  : tickers = tickers ?? [],
        createdAt = createdAt ?? DateTime.now();

  /// 그룹당 최대 티커 수
  static const int maxTickersPerGroup = 15;

  /// 티커 추가 가능 여부
  bool get canAddTicker => tickers.length < maxTickersPerGroup;

  /// 티커 포함 여부
  bool containsTicker(String ticker) => tickers.contains(ticker);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'tickers': tickers,
        'sortOrder': sortOrder,
        'createdAt': createdAt.toIso8601String(),
      };

  factory WatchlistGroup.fromJson(Map<String, dynamic> json) => WatchlistGroup(
        id: json['id'] as String,
        name: json['name'] as String,
        tickers: (json['tickers'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
        sortOrder: json['sortOrder'] as int? ?? 0,
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : null,
      );
}
