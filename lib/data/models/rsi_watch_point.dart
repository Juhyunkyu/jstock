import 'package:hive/hive.dart';

part 'rsi_watch_point.g.dart';

/// RSI 감시 모드 상수
abstract class RsiWatchMode {
  static const int bearish = 0; // 고점 감시 (하락 다이버전스)
  static const int bullish = 1; // 저점 감시 (상승 다이버전스)

  static String label(int mode) =>
      mode == bearish ? '하락 다이버전스' : '상승 다이버전스';

  static String shortLabel(int mode) =>
      mode == bearish ? '고점 감시' : '저점 감시';
}

/// RSI 다이버전스 감시점 모델
@HiveType(typeId: 27)
class RsiWatchPoint extends HiveObject {
  /// 고유 ID (UUID v4)
  @HiveField(0)
  String id;

  /// 티커 심볼 (예: AAPL, TQQQ)
  @HiveField(1)
  String ticker;

  /// 감시 모드: 0 = bearish (고점 감시), 1 = bullish (저점 감시)
  @HiveField(2)
  int mode;

  /// 감시점 설정 시 가격 (P1)
  @HiveField(3)
  double watchPrice;

  /// 감시점 설정 시 RSI 값 (R1, 0~100)
  @HiveField(4)
  double watchRsi;

  /// 감시점 설정 시 날짜 (차트 캔들의 날짜)
  @HiveField(5)
  DateTime watchDate;

  /// 감시점 설정 시 차트 interval (예: '1day', '1week')
  @HiveField(6)
  String interval;

  /// 감시점 생성 시각 (사용자가 설정한 시각)
  @HiveField(7)
  DateTime createdAt;

  /// 활성 여부 (false = 이미 트리거됨 또는 사용자가 비활성화)
  @HiveField(8, defaultValue: true)
  bool isActive;

  /// 트리거 시 감지된 RSI 값 (R2) — null이면 미트리거
  @HiveField(9)
  double? triggeredRsi;

  /// 트리거 시 감지된 가격 (P2) — null이면 미트리거
  @HiveField(10)
  double? triggeredPrice;

  /// 트리거 시각 — null이면 미트리거
  @HiveField(11)
  DateTime? triggeredAt;

  /// RSI 기간 (기본 14)
  @HiveField(12, defaultValue: 14)
  int rsiPeriod;

  RsiWatchPoint({
    required this.id,
    required this.ticker,
    required this.mode,
    required this.watchPrice,
    required this.watchRsi,
    required this.watchDate,
    required this.interval,
    DateTime? createdAt,
    this.isActive = true,
    this.triggeredRsi,
    this.triggeredPrice,
    this.triggeredAt,
    this.rsiPeriod = 14,
  }) : createdAt = createdAt ?? DateTime.now();

  /// 트리거 완료 여부
  bool get isTriggered => triggeredAt != null;

  Map<String, dynamic> toJson() => {
        'id': id,
        'ticker': ticker,
        'mode': mode,
        'watchPrice': watchPrice,
        'watchRsi': watchRsi,
        'watchDate': watchDate.toIso8601String(),
        'interval': interval,
        'createdAt': createdAt.toIso8601String(),
        'isActive': isActive,
        'triggeredRsi': triggeredRsi,
        'triggeredPrice': triggeredPrice,
        'triggeredAt': triggeredAt?.toIso8601String(),
        'rsiPeriod': rsiPeriod,
      };

  factory RsiWatchPoint.fromJson(Map<String, dynamic> json) => RsiWatchPoint(
        id: json['id'] as String,
        ticker: json['ticker'] as String,
        mode: json['mode'] as int,
        watchPrice: (json['watchPrice'] as num).toDouble(),
        watchRsi: (json['watchRsi'] as num).toDouble(),
        watchDate: DateTime.parse(json['watchDate'] as String),
        interval: json['interval'] as String,
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : null,
        isActive: json['isActive'] as bool? ?? true,
        triggeredRsi: (json['triggeredRsi'] as num?)?.toDouble(),
        triggeredPrice: (json['triggeredPrice'] as num?)?.toDouble(),
        triggeredAt: json['triggeredAt'] != null
            ? DateTime.parse(json['triggeredAt'] as String)
            : null,
        rsiPeriod: json['rsiPeriod'] as int? ?? 14,
      );
}
