import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../providers/providers.dart';
import '../../widgets/memo/memo_category_chips.dart';
import '../../widgets/memo/memo_content_renderer.dart';
import '../../widgets/shared/confirm_dialog.dart';

/// 메모 상세 (읽기) 화면
///
/// 메모 목록에서 카드 탭 시 진입.
/// 본문과 인라인 이미지를 렌더링하며,
/// AppBar의 편집 버튼으로 수정 화면으로 이동.
class MemoDetailScreen extends ConsumerWidget {
  final String memoId;

  const MemoDetailScreen({super.key, required this.memoId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memoState = ref.watch(memoListProvider);
    final memo =
        memoState.memos.where((m) => m.id == memoId).firstOrNull;

    // 새로고침 시 memos가 빈 상태 → 자동 로드 트리거
    if (memo == null && memoState.memos.isEmpty && !memoState.isLoading) {
      Future.microtask(
          () => ref.read(memoListProvider.notifier).load());
      return Scaffold(
        backgroundColor: context.appBackground,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (memo == null) {
      return Scaffold(
        backgroundColor: context.appBackground,
        appBar: AppBar(
          backgroundColor: context.appSurface,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: context.appTextPrimary),
            onPressed: () => context.go('/memo'),
          ),
        ),
        body: Center(
          child: Text(
            '메모를 찾을 수 없습니다',
            style: TextStyle(color: context.appTextSecondary),
          ),
        ),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 768;
    final isWideDesktop = screenWidth >= 1024;
    final categoryColor = memoCategoryColor(context, memo.category);
    final categoryLabel =
        memoCategoryLabels[memo.category] ?? memo.category.name;
    final isEdited = memo.isEdited;

    return Scaffold(
      backgroundColor: context.appBackground,
      appBar: AppBar(
        backgroundColor: context.appSurface,
        elevation: 0,
        toolbarHeight: 64,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: context.appTextPrimary),
          onPressed: () => context.go('/memo'),
        ),
        title: const SizedBox.shrink(),
        actions: [
          // 고정 토글
          IconButton(
            icon: Icon(
              memo.isPinned
                  ? Icons.push_pin_rounded
                  : Icons.push_pin_outlined,
              color: memo.isPinned
                  ? memoPinColor(context)
                  : context.appTextSecondary,
              size: 22,
            ),
            tooltip: memo.isPinned ? '고정 해제' : '고정',
            onPressed: () {
              final updated = memo.copyWith(isPinned: !memo.isPinned);
              ref.read(memoListProvider.notifier).save(updated);
            },
          ),
          // 편집 버튼
          IconButton(
            icon: Icon(
              Icons.edit_rounded,
              color: context.appTextSecondary,
              size: 22,
            ),
            tooltip: '편집',
            onPressed: () => context.go('/memo/edit/$memoId'),
          ),
          // 더보기 메뉴
          PopupMenuButton<String>(
            icon: Icon(
              Icons.more_vert,
              color: context.appTextSecondary,
            ),
            color: context.appSurface,
            onSelected: (value) async {
              if (value == 'delete') {
                final confirmed = await ConfirmDialog.show(
                  context: context,
                  title: '메모 삭제',
                  message: '"${memo.title}" 메모를 삭제하시겠습니까?',
                  confirmText: '삭제',
                  isDanger: true,
                );
                if (confirmed && context.mounted) {
                  await ref
                      .read(memoListProvider.notifier)
                      .delete(memo.id);
                  if (context.mounted) {
                    context.go('/memo');
                  }
                }
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(
                      Icons.delete_outline,
                      size: 20,
                      color: AppColors.red500,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '삭제',
                      style: TextStyle(color: AppColors.red500),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: isDesktop ? 24 : 16,
          vertical: 20,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: isWideDesktop ? 800 : 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 제목 (AppBar 대신 본문에 표시 — 잘림 방지)
                Text(
                  memo.title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: context.appTextPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                // 카테고리 뱃지 + 날짜
                Row(
                  children: [
                    // 카테고리 뱃지
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: context.isDarkMode
                            ? categoryColor.withValues(alpha: 0.15)
                            : categoryColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        categoryLabel,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: categoryColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // 날짜
                    Text(
                      _formatDate(memo.displayDate),
                      style: TextStyle(
                        fontSize: 13,
                        color: context.appTextHint,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 구분선
                Divider(color: context.appDivider, height: 1),
                const SizedBox(height: 20),

                // 본문 렌더링
                if (memo.content.isEmpty && memo.imageBase64List.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Text(
                        '내용이 비어있습니다',
                        style: TextStyle(
                          fontSize: 14,
                          color: context.appTextHint,
                        ),
                      ),
                    ),
                  )
                else
                  MemoContentRenderer(
                    content: memo.content,
                    imageBase64List: memo.imageBase64List,
                    memoId: memo.id,
                    linkColor: context.appAccent,
                    textStyle: TextStyle(
                      fontSize: 15,
                      color: context.appTextPrimary,
                      height: 1.7,
                    ),
                  ),

                const SizedBox(height: 32),

                // 작성일 + 수정일
                Divider(color: context.appDivider, height: 1),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '작성 ${_formatDateTime(memo.createdAt)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.appTextHint,
                        ),
                      ),
                      if (isEdited) ...[
                        const SizedBox(height: 2),
                        Text(
                          '수정 ${_formatDateTime(memo.updatedAt)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.appTextHint,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final dateFormat = DateFormat('yyyy.MM.dd');
    return dateFormat.format(date);
  }

  String _formatDateTime(DateTime date) {
    final dateFormat = DateFormat('yyyy.MM.dd HH:mm');
    return dateFormat.format(date);
  }
}
