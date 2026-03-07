import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class WatchlistTabBar extends StatelessWidget {
  final List<String> tabLabels;
  final int selectedIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onSettingsTap;

  const WatchlistTabBar({
    super.key,
    required this.tabLabels,
    required this.selectedIndex,
    required this.onTap,
    required this.onSettingsTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: context.appDivider,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(left: 12),
              child: Row(
                children: List.generate(tabLabels.length, (index) {
                  final isSelected = index == selectedIndex;
                  return _TabItem(
                    label: tabLabels[index],
                    isSelected: isSelected,
                    onTap: () => onTap(index),
                  );
                }),
              ),
            ),
          ),
          _SettingsButton(onTap: onSettingsTap),
        ],
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabItem({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? context.appAccent : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected
                ? context.appAccent
                : context.appTextSecondary,
          ),
        ),
      ),
    );
  }
}

class _SettingsButton extends StatelessWidget {
  final VoidCallback onTap;

  const _SettingsButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Icon(
          Icons.settings,
          size: 20,
          color: context.appTextHint,
        ),
      ),
    );
  }
}
