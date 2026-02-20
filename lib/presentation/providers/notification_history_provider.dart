import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/notification_record.dart';
import '../../data/repositories/notification_repository.dart';
import 'watchlist_alert_provider.dart';

/// 알림 내역 저장소 Provider
final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository();
});

/// 알림 내역 상태
class NotificationHistoryState {
  final List<NotificationRecord> items;
  final int unreadCount;
  final bool isLoading;

  const NotificationHistoryState({
    this.items = const [],
    this.unreadCount = 0,
    this.isLoading = false,
  });

  NotificationHistoryState copyWith({
    List<NotificationRecord>? items,
    int? unreadCount,
    bool? isLoading,
  }) {
    return NotificationHistoryState(
      items: items ?? this.items,
      unreadCount: unreadCount ?? this.unreadCount,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// 알림 내역 Notifier
class NotificationHistoryNotifier extends StateNotifier<NotificationHistoryState> {
  final NotificationRepository _repository;

  NotificationHistoryNotifier(this._repository)
      : super(const NotificationHistoryState());

  /// 초기 로드
  Future<void> load() async {
    if (!mounted) return;
    state = state.copyWith(isLoading: true);

    try {
      await _repository.init();
      // 30일 이전 알림 자동 정리
      await _repository.deleteOlderThan(const Duration(days: 30));

      final items = _repository.getAll();
      final unread = _repository.getUnreadCount();
      if (!mounted) return;
      state = state.copyWith(
        items: items,
        unreadCount: unread,
        isLoading: false,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false);
    }
  }

  /// AlertNotification에서 알림 레코드 추가
  Future<void> addFromAlert(AlertNotification alert) async {
    final record = NotificationRecord(
      id: '${alert.ticker}_${alert.type}_${DateTime.now().millisecondsSinceEpoch}',
      ticker: alert.ticker,
      title: alert.title,
      body: alert.body,
      type: alert.type,
      triggeredAt: DateTime.now(),
    );

    await _repository.add(record);

    if (!mounted) return;
    final items = _repository.getAll();
    final unread = _repository.getUnreadCount();
    state = state.copyWith(items: items, unreadCount: unread);
  }

  /// NotificationRecord 직접 추가 (Fear & Greed 등)
  Future<void> addRecord(NotificationRecord record) async {
    await _repository.add(record);

    if (!mounted) return;
    final items = _repository.getAll();
    final unread = _repository.getUnreadCount();
    state = state.copyWith(items: items, unreadCount: unread);
  }

  /// 읽음 처리
  Future<void> markAsRead(String id) async {
    await _repository.markAsRead(id);
    if (!mounted) return;
    final unread = _repository.getUnreadCount();
    state = state.copyWith(
      items: _repository.getAll(),
      unreadCount: unread,
    );
  }

  /// 모두 읽음 처리
  Future<void> markAllAsRead() async {
    await _repository.markAllAsRead();
    if (!mounted) return;
    state = state.copyWith(
      items: _repository.getAll(),
      unreadCount: 0,
    );
  }

  /// 전체 삭제
  Future<void> clearAll() async {
    await _repository.clear();
    if (!mounted) return;
    state = const NotificationHistoryState();
  }
}

/// 알림 내역 Provider
final notificationHistoryProvider =
    StateNotifierProvider<NotificationHistoryNotifier, NotificationHistoryState>((ref) {
  final repository = ref.watch(notificationRepositoryProvider);
  return NotificationHistoryNotifier(repository);
});

/// 미읽은 알림 수 Provider (배지용 경량)
final unreadNotificationCountProvider = Provider<int>((ref) {
  return ref.watch(notificationHistoryProvider).unreadCount;
});
