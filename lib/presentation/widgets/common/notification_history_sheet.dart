import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/notification_record.dart';
import '../../providers/notification_history_provider.dart';

/// 알림 내역 바텀 시트
class NotificationHistorySheet extends ConsumerStatefulWidget {
  const NotificationHistorySheet({super.key});

  @override
  ConsumerState<NotificationHistorySheet> createState() =>
      _NotificationHistorySheetState();
}

class _NotificationHistorySheetState
    extends ConsumerState<NotificationHistorySheet> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationHistoryProvider);
    final sheetHeight = MediaQuery.of(context).size.height * 0.6;

    return SizedBox(
      height: sheetHeight,
      child: Column(
        children: [
          // 핸들바
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: context.appBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // 헤더
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '알림',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: context.appTextPrimary,
                  ),
                ),
                if (state.unreadCount > 0)
                  TextButton(
                    onPressed: () {
                      ref
                          .read(notificationHistoryProvider.notifier)
                          .markAllAsRead();
                    },
                    child: Text(
                      '모두 읽음',
                      style: TextStyle(
                        fontSize: 13,
                        color: context.appAccent,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),

          // 본문
          Expanded(
            child: state.items.isEmpty
                ? _buildEmptyState(context)
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: state.items.length,
                    itemBuilder: (context, index) {
                      final item = state.items[index];
                      return _NotificationTile(
                        record: item,
                        onTap: () {
                          if (!item.isRead) {
                            ref
                                .read(notificationHistoryProvider.notifier)
                                .markAsRead(item.id);
                          }
                        },
                      );
                    },
                  ),
          ),

          // 하단: 전체 삭제
          if (state.items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () {
                    ref
                        .read(notificationHistoryProvider.notifier)
                        .clearAll();
                  },
                  child: Text(
                    '전체 삭제',
                    style: TextStyle(
                      fontSize: 14,
                      color: context.appTextHint,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_off_outlined,
            size: 48,
            color: context.appBorder,
          ),
          const SizedBox(height: 12),
          Text(
            '알림이 없습니다',
            style: TextStyle(
              fontSize: 15,
              color: context.appTextHint,
            ),
          ),
        ],
      ),
    );
  }
}

/// 알림 항목 타일
class _NotificationTile extends StatelessWidget {
  final NotificationRecord record;
  final VoidCallback onTap;

  const _NotificationTile({
    required this.record,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isTarget = record.type == 'target';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: record.isRead ? Colors.transparent : context.appAccent.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 읽지 않은 표시 점
            if (!record.isRead)
              Container(
                margin: const EdgeInsets.only(top: 6, right: 8),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: context.appAccent,
                ),
              )
            else
              const SizedBox(width: 16),

            // 아이콘
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isTarget
                    ? AppColors.stockUp.withValues(alpha: 0.1)
                    : AppColors.amber600.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isTarget ? Icons.gps_fixed_rounded : Icons.trending_up_rounded,
                size: 18,
                color: isTarget ? AppColors.stockUp : AppColors.amber600,
              ),
            ),
            const SizedBox(width: 10),

            // 텍스트
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: record.isRead ? FontWeight.w400 : FontWeight.w600,
                      color: context.appTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    record.body,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.appTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _relativeTime(record.triggeredAt),
                    style: TextStyle(
                      fontSize: 11,
                      color: context.appTextHint,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 상대 시간 표시
  String _relativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inMinutes < 1) return '방금 전';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    return '${dateTime.month}/${dateTime.day}';
  }
}
