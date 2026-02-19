import 'package:hive/hive.dart';

part 'notification_record.g.dart';

/// 알림 내역 모델
@HiveType(typeId: 16)
class NotificationRecord extends HiveObject {
  /// 고유 ID
  @HiveField(0)
  String id;

  /// 티커 심볼
  @HiveField(1)
  String ticker;

  /// 알림 제목
  @HiveField(2)
  String title;

  /// 알림 본문
  @HiveField(3)
  String body;

  /// 알림 유형: 'target' (목표가) 또는 'percent' (변동률)
  @HiveField(4)
  String type;

  /// 알림 발생 시각
  @HiveField(5)
  DateTime triggeredAt;

  /// 읽음 여부
  @HiveField(6)
  bool isRead;

  NotificationRecord({
    required this.id,
    required this.ticker,
    required this.title,
    required this.body,
    required this.type,
    required this.triggeredAt,
    this.isRead = false,
  });
}
