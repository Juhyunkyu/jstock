import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../providers/watchlist_group_providers.dart';
import '../shared/confirm_dialog.dart';

/// 그룹 CRUD + 순서 변경 편집기
class WatchlistGroupEditor extends ConsumerWidget {
  const WatchlistGroupEditor({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupState = ref.watch(watchlistGroupProvider);
    final groups = groupState.groups;

    return Column(
      children: [
        // 그룹 리스트
        Expanded(
          child: groups.isEmpty
              ? Center(
                  child: Text(
                    '그룹이 없습니다. 새 그룹을 만들어보세요',
                    style: TextStyle(
                      fontSize: 15,
                      color: context.appTextSecondary,
                    ),
                  ),
                )
              : ReorderableListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  itemCount: groups.length,
                  onReorder: (oldIndex, newIndex) {
                    ref
                        .read(watchlistGroupProvider.notifier)
                        .reorderGroups(oldIndex, newIndex);
                  },
                  proxyDecorator: (child, index, animation) {
                    return Material(
                      elevation: 2,
                      color: context.appSurface,
                      borderRadius: BorderRadius.circular(8),
                      child: child,
                    );
                  },
                  itemBuilder: (context, index) {
                    final group = groups[index];
                    return _GroupRow(
                      key: ValueKey(group.id),
                      groupId: group.id,
                      name: group.name,
                      tickerCount: group.tickers.length,
                    );
                  },
                ),
        ),
        // 하단: 새 그룹 추가
        _AddGroupButton(),
      ],
    );
  }
}

/// 단일 그룹 행 (드래그 핸들 + 이름 + 개수 배지 + 삭제)
class _GroupRow extends ConsumerStatefulWidget {
  final String groupId;
  final String name;
  final int tickerCount;

  const _GroupRow({
    super.key,
    required this.groupId,
    required this.name,
    required this.tickerCount,
  });

  @override
  ConsumerState<_GroupRow> createState() => _GroupRowState();
}

class _GroupRowState extends ConsumerState<_GroupRow> {
  bool _isEditing = false;
  late final TextEditingController _nameController;
  final _renameFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.name);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _renameFocusNode.dispose();
    super.dispose();
  }

  void _startEditing() {
    _nameController.text = widget.name;
    setState(() => _isEditing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _renameFocusNode.requestFocus();
    });
  }

  void _submitRename() {
    final newName = _nameController.text.trim();
    if (newName.isNotEmpty && newName != widget.name) {
      ref
          .read(watchlistGroupProvider.notifier)
          .renameGroup(widget.groupId, newName);
    }
    _renameFocusNode.unfocus();
    setState(() => _isEditing = false);
  }

  Future<void> _confirmDelete() async {
    final confirmed = await ConfirmDialog.show(
      context: context,
      title: '그룹 삭제',
      message: '"${widget.name}" 그룹을 삭제하시겠습니까?',
      confirmText: '삭제',
      isDanger: true,
    );
    if (confirmed) {
      ref.read(watchlistGroupProvider.notifier).deleteGroup(widget.groupId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: context.appDivider, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          // 드래그 핸들
          Icon(
            Icons.drag_handle,
            size: 20,
            color: context.appTextHint,
          ),
          const SizedBox(width: 10),
          // 그룹 이름 (탭하면 인라인 편집)
          Expanded(
            child: _isEditing
                ? TextField(
                    controller: _nameController,
                    focusNode: _renameFocusNode,
                    style: TextStyle(
                      fontSize: 15,
                      color: context.appTextPrimary,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: context.appBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: context.appAccent),
                      ),
                    ),
                    onSubmitted: (_) => _submitRename(),
                  )
                : GestureDetector(
                    onTap: _startEditing,
                    behavior: HitTestBehavior.opaque,
                    child: Text(
                      widget.name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: context.appTextPrimary,
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: 8),
          // 티커 개수 배지
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: context.appAccent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${widget.tickerCount}개',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: context.appAccent,
              ),
            ),
          ),
          const SizedBox(width: 4),
          // 삭제 버튼
          IconButton(
            icon: Icon(
              Icons.delete_outline,
              size: 20,
              color: context.appTextHint,
            ),
            onPressed: _confirmDelete,
          ),
        ],
      ),
    );
  }
}

/// 새 그룹 추가 버튼 (탭 시 인라인 TextField)
class _AddGroupButton extends ConsumerStatefulWidget {
  @override
  ConsumerState<_AddGroupButton> createState() => _AddGroupButtonState();
}

class _AddGroupButtonState extends ConsumerState<_AddGroupButton> {
  bool _isCreating = false;
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _startCreating() {
    setState(() => _isCreating = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isNotEmpty) {
      ref.read(watchlistGroupProvider.notifier).createGroup(name);
    }
    _controller.clear();
    _focusNode.unfocus();
    setState(() => _isCreating = false);
  }

  void _cancel() {
    _controller.clear();
    _focusNode.unfocus();
    setState(() => _isCreating = false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        MediaQuery.of(context).viewInsets.bottom + 12,
      ),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: context.appDivider, width: 1),
        ),
      ),
      child: _isCreating
          ? Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    style: TextStyle(
                      fontSize: 15,
                      color: context.appTextPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: '그룹 이름 입력',
                      hintStyle: TextStyle(
                        fontSize: 15,
                        color: context.appTextHint,
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: context.appBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: context.appAccent),
                      ),
                    ),
                    onSubmitted: (_) => _submit(),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: _submit,
                  child: Text(
                    '확인',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: context.appAccent,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _cancel,
                  child: Text(
                    '취소',
                    style: TextStyle(
                      fontSize: 14,
                      color: context.appTextSecondary,
                    ),
                  ),
                ),
              ],
            )
          : SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: _startCreating,
                icon: Icon(Icons.add, size: 20, color: context.appAccent),
                label: Text(
                  '새 그룹',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: context.appAccent,
                  ),
                ),
              ),
            ),
    );
  }
}
