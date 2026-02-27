import 'package:hive/hive.dart';

part 'chart_drawing.g.dart';

/// 드로잉 도구 유형
@HiveType(typeId: 4)
enum DrawingType {
  @HiveField(0)
  horizontalLine,

  @HiveField(1)
  trendLine,
}

/// 차트 드로잉 모델
///
/// 가격+날짜 기반 저장 (data-space) → 줌/스크롤에 안전
@HiveType(typeId: 5)
class ChartDrawing extends HiveObject {
  /// 고유 ID (UUID)
  @HiveField(0)
  String id;

  /// 차트 심볼 (QQQ, SPY 등)
  @HiveField(1)
  String symbol;

  /// 드로잉 종류
  @HiveField(2)
  DrawingType type;

  /// 수평선 가격
  @HiveField(3)
  double price;

  /// 추세선 시작점 날짜
  @HiveField(4)
  DateTime? startDate;

  /// 추세선 시작점 가격
  @HiveField(5)
  double? startPrice;

  /// 추세선 끝점 날짜
  @HiveField(6)
  DateTime? endDate;

  /// 추세선 끝점 가격
  @HiveField(7)
  double? endPrice;

  /// 선 색상 (Color.value)
  @HiveField(8)
  int colorValue;

  /// 생성 시각
  @HiveField(9)
  DateTime createdAt;

  /// 선 굵기
  @HiveField(10, defaultValue: 1.0)
  double strokeWidth;

  /// 위치 잠금
  @HiveField(11, defaultValue: false)
  bool isLocked;

  ChartDrawing({
    required this.id,
    required this.symbol,
    required this.type,
    required this.price,
    this.startDate,
    this.startPrice,
    this.endDate,
    this.endPrice,
    required this.colorValue,
    DateTime? createdAt,
    this.strokeWidth = 1.0,
    this.isLocked = false,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'symbol': symbol,
        'type': type.name,
        'price': price,
        'startDate': startDate?.toIso8601String(),
        'startPrice': startPrice,
        'endDate': endDate?.toIso8601String(),
        'endPrice': endPrice,
        'colorValue': colorValue,
        'createdAt': createdAt.toIso8601String(),
        'strokeWidth': strokeWidth,
        'isLocked': isLocked,
      };

  factory ChartDrawing.fromJson(Map<String, dynamic> json) => ChartDrawing(
        id: json['id'] as String,
        symbol: json['symbol'] as String,
        type: DrawingType.values.byName(json['type'] as String),
        price: (json['price'] as num).toDouble(),
        startDate: json['startDate'] != null
            ? DateTime.parse(json['startDate'] as String)
            : null,
        startPrice: (json['startPrice'] as num?)?.toDouble(),
        endDate: json['endDate'] != null
            ? DateTime.parse(json['endDate'] as String)
            : null,
        endPrice: (json['endPrice'] as num?)?.toDouble(),
        colorValue: json['colorValue'] as int,
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : null,
        strokeWidth: (json['strokeWidth'] as num?)?.toDouble() ?? 1.0,
        isLocked: json['isLocked'] as bool? ?? false,
      );

  ChartDrawing copyWith({
    String? id,
    String? symbol,
    DrawingType? type,
    double? price,
    DateTime? startDate,
    double? startPrice,
    DateTime? endDate,
    double? endPrice,
    int? colorValue,
    DateTime? createdAt,
    double? strokeWidth,
    bool? isLocked,
  }) {
    return ChartDrawing(
      id: id ?? this.id,
      symbol: symbol ?? this.symbol,
      type: type ?? this.type,
      price: price ?? this.price,
      startDate: startDate ?? this.startDate,
      startPrice: startPrice ?? this.startPrice,
      endDate: endDate ?? this.endDate,
      endPrice: endPrice ?? this.endPrice,
      colorValue: colorValue ?? this.colorValue,
      createdAt: createdAt ?? this.createdAt,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      isLocked: isLocked ?? this.isLocked,
    );
  }
}
