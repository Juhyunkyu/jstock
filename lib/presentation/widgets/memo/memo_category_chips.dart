import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/memo.dart';

/// 메모 카테고리 한글명 매핑
const memoCategoryLabels = <MemoCategory, String>{
  MemoCategory.general: '일반',
  MemoCategory.analysis: '분석',
  MemoCategory.insight: '인사이트',
  MemoCategory.study: '학습',
  MemoCategory.strategy: '전략',
  MemoCategory.diary: '일지',
};

/// 메모 카테고리 필터 칩 (가로 스크롤)
///
/// [selectedCategory] null이면 '전체' 선택 상태.
/// [onSelected] 카테고리 탭 시 콜백 (null = 전체).
class MemoCategoryChips extends StatelessWidget {
  final MemoCategory? selectedCategory;
  final ValueChanged<MemoCategory?> onSelected;

  const MemoCategoryChips({
    super.key,
    required this.selectedCategory,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          // '전체' 칩
          _buildChip(
            context: context,
            label: '전체',
            isSelected: selectedCategory == null,
            color: context.appTextSecondary,
            onTap: () => onSelected(null),
          ),
          const SizedBox(width: 8),
          // 카테고리별 칩
          ...MemoCategory.values.map((cat) {
            final color = context.memoCategoryColor(cat);
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _buildChip(
                context: context,
                label: memoCategoryLabels[cat] ?? cat.name,
                isSelected: selectedCategory == cat,
                color: color,
                onTap: () => onSelected(cat),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildChip({
    required BuildContext context,
    required String label,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Chip(
        label: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected ? Colors.white : context.appTextSecondary,
          ),
        ),
        backgroundColor: isSelected
            ? color
            : context.isDarkMode
                ? color.withValues(alpha: 0.15)
                : color.withValues(alpha: 0.08),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

/// 메모 작성/수정 화면용 카테고리 ChoiceChip 그룹
class MemoCategoryChoiceChips extends StatelessWidget {
  final MemoCategory selected;
  final ValueChanged<MemoCategory> onSelected;

  const MemoCategoryChoiceChips({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: MemoCategory.values.map((cat) {
        final isSelected = selected == cat;
        final color = context.memoCategoryColor(cat);
        return ChoiceChip(
          label: Text(memoCategoryLabels[cat] ?? cat.name),
          selected: isSelected,
          onSelected: (_) => onSelected(cat),
          selectedColor: color,
          backgroundColor: context.isDarkMode
              ? color.withValues(alpha: 0.15)
              : color.withValues(alpha: 0.08),
          labelStyle: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected ? Colors.white : context.appTextSecondary,
          ),
          side: BorderSide.none,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        );
      }).toList(),
    );
  }
}
