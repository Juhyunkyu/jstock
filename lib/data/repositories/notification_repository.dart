import 'package:hive_flutter/hive_flutter.dart';
import '../models/notification_record.dart';

/// 알림 내역 저장소
class NotificationRepository {
  static const String _boxName = 'notifications';
  Box<NotificationRecord>? _box;

  /// 초기화 여부
  bool get isInitialized => _box != null && _box!.isOpen;

  /// 저장소 초기화
  Future<void> init() async {
    _box = await Hive.openBox<NotificationRecord>(_boxName);
  }

  /// 모든 알림 가져오기 (최신순)
  List<NotificationRecord> getAll() {
    if (!isInitialized) return [];
    final items = _box!.values.toList();
    items.sort((a, b) => b.triggeredAt.compareTo(a.triggeredAt));
    return items;
  }

  /// 알림 추가
  Future<void> add(NotificationRecord record) async {
    if (!isInitialized) return;
    await _box!.put(record.id, record);
  }

  /// 읽음 처리
  Future<void> markAsRead(String id) async {
    if (!isInitialized) return;
    final record = _box!.get(id);
    if (record != null) {
      record.isRead = true;
      await record.save();
    }
  }

  /// 모두 읽음 처리
  Future<void> markAllAsRead() async {
    if (!isInitialized) return;
    for (final record in _box!.values) {
      if (!record.isRead) {
        record.isRead = true;
        await record.save();
      }
    }
  }

  /// 미읽은 알림 수
  int getUnreadCount() {
    if (!isInitialized) return 0;
    return _box!.values.where((r) => !r.isRead).length;
  }

  /// 30일 이전 알림 삭제
  Future<void> deleteOlderThan(Duration duration) async {
    if (!isInitialized) return;
    final cutoff = DateTime.now().subtract(duration);
    final keysToDelete = <dynamic>[];
    for (final entry in _box!.toMap().entries) {
      if (entry.value.triggeredAt.isBefore(cutoff)) {
        keysToDelete.add(entry.key);
      }
    }
    if (keysToDelete.isNotEmpty) {
      await _box!.deleteAll(keysToDelete);
    }
  }

  /// 전체 삭제
  Future<void> clear() async {
    if (!isInitialized) return;
    await _box!.clear();
  }

  /// 알림 수
  int get count => isInitialized ? _box!.length : 0;
}
