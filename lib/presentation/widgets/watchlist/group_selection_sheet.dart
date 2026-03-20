import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../providers/providers.dart';

/// 별표 아이콘 클릭 시 그룹 선택 바텀시트
///
/// 사용자 그룹 목록을 체크박스로 표시하고,
/// 토글하여 티커를 그룹에 추가/제거합니다.
class GroupSelectionSheet extends ConsumerStatefulWidget {
  final String ticker;

  const GroupSelectionSheet({super.key, required this.ticker});

  @override
  ConsumerState<GroupSelectionSheet> createState() =>
      _GroupSelectionSheetState();
}

class _GroupSelectionSheetState extends ConsumerState<GroupSelectionSheet> {
  final _nameController = TextEditingController();
  bool _isCreating = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final groupState = ref.watch(watchlistGroupProvider);
    final groups = groupState.groups;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 핸들바
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: context.appBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // 헤더
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.star, size: 20, color: AppColors.amber500),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${widget.ticker} — 그룹 선택',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: context.appTextPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Divider(height: 1, color: context.appDivider),

            // 그룹 목록
            if (groups.isEmpty && !_isCreating)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(
                      Icons.folder_outlined,
                      size: 40,
                      color: context.appBorder,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '그룹이 없습니다',
                      style: TextStyle(
                        fontSize: 14,
                        color: context.appTextHint,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextButton.icon(
                      onPressed: () => setState(() => _isCreating = true),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('새 그룹 만들기'),
                    ),
                  ],
                ),
              )
            else ...[
              ...groups.map((group) {
                final contains = group.containsTicker(widget.ticker);
                final isFull = !group.canAddTicker && !contains;

                return ListTile(
                  dense: true,
                  leading: Icon(
                    contains
                        ? Icons.check_box
                        : Icons.check_box_outline_blank,
                    color: contains
                        ? AppColors.amber500
                        : context.appTextHint,
                    size: 22,
                  ),
                  title: Text(
                    group.name,
                    style: TextStyle(
                      fontSize: 14,
                      color: isFull
                          ? context.appTextHint
                          : context.appTextPrimary,
                    ),
                  ),
                  trailing: Text(
                    '${group.tickers.length}/15',
                    style: TextStyle(
                      fontSize: 12,
                      color: isFull
                          ? AppColors.red500
                          : context.appTextHint,
                    ),
                  ),
                  enabled: !isFull,
                  onTap: () async {
                    final notifier =
                        ref.read(watchlistGroupProvider.notifier);
                    if (contains) {
                      await notifier.removeTicker(group.id, widget.ticker);
                    } else {
                      await notifier.addTicker(group.id, widget.ticker);
                    }
                  },
                );
              }),

              // 새 그룹 만들기 버튼
              if (!_isCreating)
                ListTile(
                  dense: true,
                  leading: Icon(
                    Icons.add_circle_outline,
                    size: 22,
                    color: context.appAccent,
                  ),
                  title: Text(
                    '새 그룹 만들기',
                    style: TextStyle(
                      fontSize: 14,
                      color: context.appAccent,
                    ),
                  ),
                  onTap: () => setState(() => _isCreating = true),
                ),
            ],

            // 인라인 그룹 생성
            if (_isCreating)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _nameController,
                        autofocus: true,
                        style: TextStyle(
                          fontSize: 14,
                          color: context.appTextPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: '그룹 이름',
                          hintStyle: TextStyle(color: context.appTextHint),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: context.appBorder),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: context.appBorder),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: context.appAccent),
                          ),
                        ),
                        onSubmitted: (_) => _createGroup(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(Icons.check, color: context.appAccent),
                      onPressed: _createGroup,
                      iconSize: 20,
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: context.appTextHint),
                      onPressed: () => setState(() {
                        _isCreating = false;
                        _nameController.clear();
                      }),
                      iconSize: 20,
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _createGroup() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    await ref.read(watchlistGroupProvider.notifier).createGroup(name);
    if (!mounted) return;
    setState(() {
      _isCreating = false;
      _nameController.clear();
    });
  }
}
