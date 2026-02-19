import 'package:hive_flutter/hive_flutter.dart';
import '../models/notification_record.dart';

/// 알림 내역 저장소
class NotificationRepository {
  static const String _boxName = 'notifications';
  late Box<NotificationRecord> _box;

  /// 저장소 초기화
  Future<void> init() async {
    _box = await Hive.openBox<NotificationRecord>(_boxName);
  }

  /// 모든 알림 가져오기 (최신순)
  List<NotificationRecord> getAll() {
    final items = _box.values.toList();
    items.sort((a, b) => b.triggeredAt.compareTo(a.triggeredAt));
    return items;
  }

  /// 알림 추가
  Future<void> add(NotificationRecord record) async {
    await _box.put(record.id, record);
  }

  /// 읽음 처리
  Future<void> markAsRead(String id) async {
    final record = _box.get(id);
    if (record != null) {
      record.isRead = true;
      await record.save();
    }
  }

  /// 모두 읽음 처리
  Future<void> markAllAsRead() async {
    for (final record in _box.values) {
      if (!record.isRead) {
        record.isRead = true;
        await record.save();
      }
    }
  }

  /// 미읽은 알림 수
  int getUnreadCount() {
    return _box.values.where((r) => !r.isRead).length;
  }

  /// 30일 이전 알림 삭제
  Future<void> deleteOlderThan(Duration duration) async {
    final cutoff = DateTime.now().subtract(duration);
    final keysToDelete = <dynamic>[];
    for (final entry in _box.toMap().entries) {
      if (entry.value.triggeredAt.isBefore(cutoff)) {
        keysToDelete.add(entry.key);
      }
    }
    if (keysToDelete.isNotEmpty) {
      await _box.deleteAll(keysToDelete);
    }
  }

  /// 전체 삭제
  Future<void> clear() async {
    await _box.clear();
  }

  /// 알림 수
  int get count => _box.length;
}
