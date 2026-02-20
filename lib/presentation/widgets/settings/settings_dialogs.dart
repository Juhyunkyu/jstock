import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../providers/providers.dart';

/// 테마 설정 다이얼로그
void showThemeDialog(BuildContext context, WidgetRef ref) {
  final settings = ref.read(settingsProvider);

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('테마 설정'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ThemeOption(
            title: '라이트 모드',
            icon: Icons.light_mode_outlined,
            isSelected: !settings.useDarkMode,
            onTap: () {
              ref.read(settingsProvider.notifier).setDarkMode(false);
              Navigator.pop(context);
            },
          ),
          _ThemeOption(
            title: '다크 모드',
            icon: Icons.dark_mode_outlined,
            isSelected: settings.useDarkMode,
            onTap: () {
              ref.read(settingsProvider.notifier).setDarkMode(true);
              Navigator.pop(context);
            },
          ),
        ],
      ),
    ),
  );
}

/// 언어 설정 다이얼로그
void showLanguageDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('언어 설정'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: const Text('한국어'),
            trailing: Icon(Icons.check, color: context.appAccent),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            title: const Text('English'),
            onTap: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('영어는 준비 중입니다')),
              );
            },
          ),
        ],
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
  final VoidCallback onTap;

  const _ThemeOption({
    required this.title,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final selectedColor = context.appAccent;
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? selectedColor : context.appTextSecondary,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? selectedColor : context.appTextPrimary,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      trailing: isSelected
          ? Icon(Icons.check, color: selectedColor)
          : null,
      onTap: onTap,
    );
  }
}
