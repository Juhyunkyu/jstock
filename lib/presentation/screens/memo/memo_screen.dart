import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/memo.dart';
import '../../providers/providers.dart';
import '../../widgets/memo/memo_card.dart';
import '../../widgets/memo/memo_category_chips.dart';
import '../../widgets/shared/confirm_dialog.dart';

/// 메모 목록 화면
///
/// AppBar: "메모" + 검색 아이콘 + 정렬 토글
/// 카테고리 필터 칩 (가로 스크롤)
/// 메모 카드 목록 (드래그 정렬, 250ms 딜레이)
/// FAB: + 새 메모
/// 반응형: 모바일 리스트 / 데스크톱 2열 그리드 (>=768px)
class MemoScreen extends ConsumerStatefulWidget {
  const MemoScreen({super.key});

  @override
  ConsumerState<MemoScreen> createState() => _MemoScreenState();
}

class _MemoScreenState extends ConsumerState<MemoScreen> {
  bool _isSearchMode = false;
  final _searchController = TextEditingController();
  Timer? _searchDebounce;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isLoaded) {
        ref.read(memoListProvider.notifier).load();
        _isLoaded = true;
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      ref.read(memoListProvider.notifier).setSearchQuery(query);
    });
  }

  void _toggleSearch() {
    setState(() {
      _isSearchMode = !_isSearchMode;
      if (!_isSearchMode) {
        _searchController.clear();
        ref.read(memoListProvider.notifier).setSearchQuery('');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final memoState = ref.watch(memoListProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 768;

    return Scaffold(
      backgroundColor: context.appBackground,
      appBar: _isSearchMode ? _buildSearchAppBar() : _buildNormalAppBar(memoState),
      body: memoState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 카테고리 필터 칩 (검색 모드가 아닐 때만)
                if (!_isSearchMode)
                  MemoCategoryChips(
                    selectedCategory: memoState.filterCategory,
                    onSelected: (cat) =>
                        ref.read(memoListProvider.notifier).setFilterCategory(cat),
                  ),
                // 메모 목록
                Expanded(
                  child: memoState.memos.isEmpty
                      ? _buildEmptyState(memoState)
                      : isDesktop
                          ? _buildDesktopGrid(memoState)
                          : _buildMobileList(memoState),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.small(
        onPressed: () => context.go('/memo/create'),
        backgroundColor: context.appAccent,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  PreferredSizeWidget _buildNormalAppBar(MemoListState memoState) {
    return AppBar(
      backgroundColor: context.appSurface,
      elevation: 0,
      toolbarHeight: 64,
      title: Text(
        '메모',
        style: TextStyle(color: context.appTextPrimary),
      ),
      actions: [
        // 정렬 토글
        IconButton(
          icon: Icon(
            memoState.sortOrder == MemoSortOrder.newest
                ? Icons.arrow_downward_rounded
                : Icons.arrow_upward_rounded,
            color: context.appTextSecondary,
            size: 20,
          ),
          tooltip: memoState.sortOrder == MemoSortOrder.newest ? '오래된순' : '최신순',
          onPressed: () => ref.read(memoListProvider.notifier).toggleSortOrder(),
        ),
        // 검색
        IconButton(
          icon: Icon(Icons.search, color: context.appTextSecondary),
          onPressed: _toggleSearch,
        ),
      ],
    );
  }

  PreferredSizeWidget _buildSearchAppBar() {
    return AppBar(
      backgroundColor: context.appSurface,
      elevation: 0,
      toolbarHeight: 64,
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: context.appTextPrimary),
        onPressed: _toggleSearch,
      ),
      title: TextField(
        controller: _searchController,
        autofocus: true,
        onChanged: _onSearchChanged,
        style: TextStyle(
          fontSize: 16,
          color: context.appTextPrimary,
        ),
        decoration: InputDecoration(
          hintText: '검색어 입력...',
          hintStyle: TextStyle(color: context.appTextHint),
          border: InputBorder.none,
        ),
      ),
      actions: [
        TextButton(
          onPressed: _toggleSearch,
          child: Text(
            '취소',
            style: TextStyle(color: context.appAccent),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(MemoListState memoState) {
    // 검색 결과가 없는 경우
    if (memoState.searchQuery.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded, size: 48, color: context.appTextHint),
            const SizedBox(height: 16),
            Text(
              '"${memoState.searchQuery}" 검색 결과가 없습니다',
              style: TextStyle(fontSize: 14, color: context.appTextSecondary),
            ),
          ],
        ),
      );
    }

    // 카테고리 필터 결과가 없는 경우
    if (memoState.filterCategory != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.filter_list_off_rounded, size: 48, color: context.appTextHint),
            const SizedBox(height: 16),
            Text(
              '해당 카테고리에 메모가 없습니다',
              style: TextStyle(fontSize: 14, color: context.appTextSecondary),
            ),
          ],
        ),
      );
    }

    // 완전한 빈 상태
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.edit_note_rounded, size: 64, color: context.appTextHint),
          const SizedBox(height: 16),
          Text(
            '주식 공부 메모를 작성하세요',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: context.appTextPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '종목 분석, 시장 인사이트, 매매 일지',
            style: TextStyle(fontSize: 14, color: context.appTextHint),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileList(MemoListState memoState) {
    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
      buildDefaultDragHandles: false,
      proxyDecorator: (child, index, animation) {
        return Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(12),
          color: Colors.transparent,
          child: child,
        );
      },
      onReorder: (oldIndex, newIndex) {
        ref.read(memoListProvider.notifier).reorder(oldIndex, newIndex);
      },
      itemCount: memoState.memos.length,
      itemBuilder: (context, index) {
        final memo = memoState.memos[index];
        return _DismissibleMemoCard(
          key: ValueKey(memo.id),
          memo: memo,
          onTap: () => context.go('/memo/detail/${memo.id}'),
          onDismissed: () {
            ref.read(memoListProvider.notifier).delete(memo.id);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('"${memo.title}" 삭제됨'),
                duration: const Duration(seconds: 2),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDesktopGrid(MemoListState memoState) {
    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
      buildDefaultDragHandles: false,
      proxyDecorator: (child, index, animation) {
        return Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(12),
          color: Colors.transparent,
          child: child,
        );
      },
      onReorder: (oldIndex, newIndex) {
        ref.read(memoListProvider.notifier).reorder(oldIndex, newIndex);
      },
      itemCount: memoState.memos.length,
      itemBuilder: (context, index) {
        final memo = memoState.memos[index];
        return Padding(
          key: ValueKey(memo.id),
          padding: const EdgeInsets.only(bottom: 8),
          child: ReorderableDragStartListener(
            index: index,
            child: MemoCard(
              memo: memo,
              showDragHandle: true,
              onTap: () => context.go('/memo/detail/${memo.id}'),
            ),
          ),
        );
      },
    );
  }

}

/// 스와이프 삭제를 지원하는 메모 카드 래퍼
class _DismissibleMemoCard extends StatelessWidget {
  final Memo memo;
  final VoidCallback onTap;
  final VoidCallback onDismissed;

  const _DismissibleMemoCard({
    super.key,
    required this.memo,
    required this.onTap,
    required this.onDismissed,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey('dismiss_${memo.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        final confirmed = await ConfirmDialog.show(
          context: context,
          title: '메모 삭제',
          message: '"${memo.title}" 메모를 삭제하시겠습니까?',
          confirmText: '삭제',
          isDanger: true,
        );
        return confirmed;
      },
      onDismissed: (_) => onDismissed(),
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.red500,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: MemoCard(
          memo: memo,
          onTap: onTap,
        ),
      ),
    );
  }
}
