import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// 설정 섹션 컨테이너
class SettingsSection extends StatelessWidget {
  final String title;
  final List<SettingsItem> items;

  const SettingsSection({
    super.key,
    required this.title,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 768;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(16, isDesktop ? 24 : 16, 16, isDesktop ? 8 : 4),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: context.appTextSecondary,
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: context.appSurface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: items
                .asMap()
                .entries
                .map((entry) => Column(
                      children: [
                        entry.value,
                        if (entry.key < items.length - 1)
                          const Divider(height: 1, indent: 56),
                      ],
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }
}

/// 설정 항목 타일
class SettingsItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? trailingText;
  final VoidCallback onTap;

  const SettingsItem({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailingText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 768;
    final iconSize = isDesktop ? 40.0 : 34.0;
    return ListTile(
      dense: !isDesktop,
      visualDensity: isDesktop ? VisualDensity.standard : const VisualDensity(vertical: -2),
      leading: Container(
        width: iconSize,
        height: iconSize,
        decoration: BoxDecoration(
          color: context.appIconBg,
          borderRadius: BorderRadius.circular(isDesktop ? 10 : 8),
        ),
        child: Icon(icon, color: context.appTextSecondary, size: isDesktop ? 22 : 18),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: isDesktop ? 15 : 14,
          color: context.appTextPrimary,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: TextStyle(
                fontSize: isDesktop ? 13 : 12,
                color: context.appTextHint,
              ),
            )
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailingText != null)
            Text(
              trailingText!,
              style: TextStyle(
                fontSize: isDesktop ? 14 : 13,
                color: context.appTextHint,
              ),
            ),
          const SizedBox(width: 4),
          Icon(
            Icons.chevron_right_rounded,
            color: context.appTextHint,
            size: isDesktop ? 24 : 20,
          ),
        ],
      ),
      onTap: onTap,
    );
  }
}
