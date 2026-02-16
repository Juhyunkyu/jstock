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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
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
  final VoidCallback onTap;

  const SettingsItem({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: context.appIconBg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: context.appTextSecondary, size: 22),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          color: context.appTextPrimary,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: TextStyle(
                fontSize: 13,
                color: context.appTextHint,
              ),
            )
          : null,
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: context.appTextHint,
      ),
      onTap: onTap,
    );
  }
}
