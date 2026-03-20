import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/memo.dart';
import 'memo_category_chips.dart';

/// 메모 목록 카드 위젯
///
/// 구성: 제목(1줄) + 카테고리 뱃지/날짜(1줄) + 본문 미리보기(2줄) + 이미지 수.
/// 고정 메모는 좌측 상단에 핀 아이콘 표시.
class MemoCard extends StatelessWidget {
  final Memo memo;
  final VoidCallback onTap;

  const MemoCard({
    super.key,
    required this.memo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final categoryColor = memoCategoryColor(context, memo.category);
    final dateStr = DateFormat('yyyy.MM.dd').format(memo.displayDate);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.appCardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.appDivider, width: 0.5),
          boxShadow: context.appCardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 제목 + 핀 아이콘
            Row(
              children: [
                if (memo.isPinned) ...[
                  Icon(
                    Icons.push_pin_rounded,
                    size: 16,
                    color: memoPinColor(context),
                  ),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Text(
                    memo.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: context.appTextPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // 카테고리 뱃지 + 날짜
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: context.isDarkMode
                        ? categoryColor.withValues(alpha: 0.2)
                        : categoryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    memoCategoryLabels[memo.category] ?? memo.category.name,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: categoryColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  dateStr,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.appTextHint,
                  ),
                ),
              ],
            ),

            // 본문 미리보기 (있을 때만)
            if (memo.content.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                memo.contentPreview,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: context.appTextSecondary,
                  height: 1.4,
                ),
              ),
            ],

            // 이미지 수 (마커 기준)
            if (memo.imageCount > 0) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.image_outlined,
                    size: 14,
                    color: context.appTextHint,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${memo.imageCount}',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.appTextHint,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
