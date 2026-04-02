import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../providers/providers.dart';
import '../common/top_toast.dart';

/// 테마 설정 다이얼로그
void showThemeDialog(BuildContext context, WidgetRef ref) {
  final currentType = ref.read(settingsProvider).themeType;

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: context.appSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('테마 설정', style: TextStyle(color: context.appTextPrimary)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: AppThemeType.values.map((type) {
            final index = type.index;
            final isSelected = currentType == index;
            final colors = type == AppThemeType.system
                ? null
                : AppColors.getThemeColors(type);
            return _ThemeOption(
              title: type.label,
              icon: type.icon,
              isSelected: isSelected,
              previewColors: colors != null
                  ? [colors.background, colors.surface, colors.accent]
                  : null,
              onTap: () {
                ref.read(settingsProvider.notifier).setThemeType(index);
                Navigator.pop(ctx);
              },
            );
          }).toList(),
        ),
      ),
    ),
  );
}

/// 앱 정보 다이얼로그
void showAboutDialog_(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: context.appAccent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.show_chart_rounded,
              color: context.appAccent,
              size: 28,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('알파 사이클', style: TextStyle(color: context.appTextPrimary)),
              Text(
                'v1.0.1',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.normal,
                  color: context.appTextSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '레버리지 ETF 가중 매수 매매법을 위한 투자 관리 앱입니다.',
            style: TextStyle(
              fontSize: 14,
              color: context.appTextSecondary,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '⚠️ 투자 경고',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.red500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '레버리지 ETF는 높은 변동성과 위험을 수반합니다. '
            '투자 손실에 대한 책임은 전적으로 사용자에게 있습니다.',
            style: TextStyle(
              fontSize: 12,
              color: context.appTextHint,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('닫기'),
        ),
      ],
    ),
  );
}

class _ThemeOption extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isSelected;
  final List<Color>? previewColors; // [background, surface, accent]
  final VoidCallback onTap;

  const _ThemeOption({
    required this.title,
    required this.icon,
    required this.isSelected,
    this.previewColors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final selectedColor = context.appAccent;
    return ListTile(
      dense: true,
      visualDensity: const VisualDensity(vertical: -1),
      leading: previewColors != null
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: previewColors!.map((c) => Container(
                width: 14,
                height: 14,
                margin: const EdgeInsets.only(right: 2),
                decoration: BoxDecoration(
                  color: c,
                  shape: BoxShape.circle,
                  border: Border.all(color: context.appBorder, width: 0.5),
                ),
              )).toList(),
            )
          : Icon(icon, color: isSelected ? selectedColor : context.appTextSecondary, size: 20),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          color: isSelected ? selectedColor : context.appTextPrimary,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      trailing: isSelected
          ? Icon(Icons.check, color: selectedColor, size: 20)
          : null,
      onTap: onTap,
    );
  }
}
