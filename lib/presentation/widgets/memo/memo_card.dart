import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/memo.dart';
import 'memo_category_chips.dart';

/// 메모 목록 카드 위젯
///
/// 1줄: 핀 + 제목 ... 카테고리 뱃지 + 날짜
/// 2줄: 내용 미리보기(Expanded) ... 이미지 수(고정, 절대 밀리지 않음)
/// [showDragHandle] true면 오른쪽에 드래그 핸들 영역 표시 (데스크톱/태블릿)
class MemoCard extends StatelessWidget {
  final Memo memo;
  final VoidCallback onTap;
  final bool showDragHandle;

  const MemoCard({
    super.key,
    required this.memo,
    required this.onTap,
    this.showDragHandle = false,
  });

  @override
  Widget build(BuildContext context) {
    final categoryColor = memoCategoryColor(context, memo.category);
    final dateStr = DateFormat('MM.dd').format(memo.displayDate);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.only(
          left: 14,
          top: 10,
          bottom: 10,
          right: showDragHandle ? 0 : 14,
        ),
        decoration: BoxDecoration(
          color: context.appCardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.appDivider, width: 0.5),
          boxShadow: context.appCardShadow,
        ),
        child: Row(
          children: [
            // 콘텐츠 영역
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1줄: 핀 + 제목 ... 카테고리 + 날짜
                  Row(
                    children: [
                      if (memo.isPinned) ...[
                        Icon(
                          Icons.push_pin_rounded,
                          size: 14,
                          color: memoPinColor(context),
                        ),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: Text(
                          memo.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: context.appTextPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: context.isDarkMode
                              ? categoryColor.withValues(alpha: 0.2)
                              : categoryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          memoCategoryLabels[memo.category] ??
                              memo.category.name,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: categoryColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        dateStr,
                        style: TextStyle(
                          fontSize: 11,
                          color: context.appTextHint,
                        ),
                      ),
                    ],
                  ),

                  // 2줄: 내용(Expanded) ... 이미지 수(고정)
                  if (memo.content.isNotEmpty || memo.imageCount > 0) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: memo.content.isNotEmpty
                              ? Text(
                                  memo.contentPreview,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: context.appTextSecondary,
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                        if (memo.imageCount > 0) ...[
                          const SizedBox(width: 8),
                          Icon(
                            Icons.image_outlined,
                            size: 13,
                            color: context.appTextHint,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '${memo.imageCount}',
                            style: TextStyle(
                              fontSize: 11,
                              color: context.appTextHint,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // 드래그 핸들 영역 (데스크톱/태블릿만)
            if (showDragHandle)
              Container(
                width: 32,
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Icon(
                  Icons.drag_indicator_rounded,
                  size: 18,
                  color: context.appTextHint,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
