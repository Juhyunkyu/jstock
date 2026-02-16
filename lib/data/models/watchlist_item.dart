import 'package:hive/hive.dart';

part 'watchlist_item.g.dart';

/// 관심종목 아이템 모델
@HiveType(typeId: 15)
class WatchlistItem extends HiveObject {
  /// 티커 심볼 (예: AAPL, TQQQ)
  @HiveField(0)
  String ticker;

  /// 종목명
  @HiveField(1)
  String name;

  /// 거래소 (예: NASDAQ, NYSE)
  @HiveField(2)
  String exchange;

  /// 종목 유형 (EQUITY, ETF, INDEX)
  @HiveField(3)
  String type;

  /// 추가 날짜
  @HiveField(4)
  DateTime addedAt;

  /// 메모 (선택)
  @HiveField(5)
  String? note;

  /// 알림 설정 가격 (선택)
  @HiveField(6)
  double? alertPrice;

  /// 정렬 순서 (드래그 앤 드롭용)
  @HiveField(7, defaultValue: 0)
  int sortOrder;

  /// 알림 유형: null=없음, 0=목표가, 1=변동률
  @HiveField(8)
  int? alertType;

  /// 변동률 알림 기준 가격
  @HiveField(9)
  double? alertBasePrice;

  /// 변동률 퍼센트 (예: 5.0 = ±5%)
  @HiveField(10)
  double? alertPercent;

  /// 변동률 방향: 0=± 양방향, 1=▲ 상승만, 2=▼ 하락만
  @HiveField(11)
  int? alertDirection;

  WatchlistItem({
    required this.ticker,
    required this.name,
    required this.exchange,
    required this.type,
    DateTime? addedAt,
    this.note,
    this.alertPrice,
    this.sortOrder = 0,
    this.alertType,
    this.alertBasePrice,
    this.alertPercent,
    this.alertDirection,
  }) : addedAt = addedAt ?? DateTime.now();

  /// 목표가 알림 설정 여부
  bool get hasTargetAlert => alertPrice != null && alertPrice! > 0;

  /// 변동률 알림 설정 여부
  bool get hasPercentAlert =>
      alertBasePrice != null && alertBasePrice! > 0 &&
      alertPercent != null && alertPercent! > 0;

  /// 알림 설정 여부 (하나라도 있으면 true)
  bool get hasAlert => hasTargetAlert || hasPercentAlert;

  /// 방향 기호
  String get _directionSymbol {
    switch (alertDirection ?? 0) {
      case 1: return '▲';
      case 2: return '▼';
      default: return '±';
    }
  }

  /// 알림 요약 텍스트
  String get alertSummary {
    if (!hasAlert) return '알림 없음';
    final parts = <String>[];
    if (hasPercentAlert) {
      parts.add('$_directionSymbol${alertPercent!.toStringAsFixed(1)}%');
    }
    if (hasTargetAlert) {
      parts.add('\$${alertPrice!.toStringAsFixed(2)}');
    }
    return parts.join('  ·  ');
  }

  /// 목표가 알림 조건 충족 여부 (가격이 목표가를 관통했는지)
  ///
  /// [currentPrice] 현재 가격
  /// [previousPrice] 이전 가격 (관통 판정에 필요)
  bool isTargetAlertTriggered(double currentPrice, double? previousPrice) {
    if (!hasTargetAlert || previousPrice == null) return false;
    // 이전 가격과 현재 가격이 목표가를 사이에 두고 있으면 관통
    return (previousPrice < alertPrice! && currentPrice >= alertPrice!) ||
           (previousPrice > alertPrice! && currentPrice <= alertPrice!);
  }

  /// 변동률 알림 조건 충족 여부
  ///
  /// [currentPrice] 현재 가격
  bool isPercentAlertTriggered(double currentPrice) {
    if (!hasPercentAlert) return false;
    final changeRate = (currentPrice - alertBasePrice!) / alertBasePrice!;
    switch (alertDirection ?? 0) {
      case 1: return changeRate >= alertPercent! / 100;    // 상승만
      case 2: return changeRate <= -(alertPercent! / 100); // 하락만
      default: return changeRate.abs() >= alertPercent! / 100; // 양방향
    }
  }

  /// 고유 ID
  String get id => ticker;

  /// ETF 여부
  bool get isETF => type == 'ETF';

  /// 지수 여부
  bool get isIndex => type == 'INDEX';

  /// 복사본 생성
  WatchlistItem copyWith({
    String? ticker,
    String? name,
    String? exchange,
    String? type,
    DateTime? addedAt,
    String? note,
    double? alertPrice,
    int? sortOrder,
    int? alertType,
    double? alertBasePrice,
    double? alertPercent,
    int? alertDirection,
  }) {
    return WatchlistItem(
      ticker: ticker ?? this.ticker,
      name: name ?? this.name,
      exchange: exchange ?? this.exchange,
      type: type ?? this.type,
      addedAt: addedAt ?? this.addedAt,
      note: note ?? this.note,
      alertPrice: alertPrice ?? this.alertPrice,
      sortOrder: sortOrder ?? this.sortOrder,
      alertType: alertType ?? this.alertType,
      alertBasePrice: alertBasePrice ?? this.alertBasePrice,
      alertPercent: alertPercent ?? this.alertPercent,
      alertDirection: alertDirection ?? this.alertDirection,
    );
  }
}
