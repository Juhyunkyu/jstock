import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/services/data/web_file_service.dart';
import '../../providers/providers.dart';
import '../../widgets/settings/settings_section.dart';
import '../../widgets/settings/settings_dialogs.dart';
import '../../widgets/settings/backup_restore.dart';
import '../../widgets/settings/guide_sheet.dart';
import '../../widgets/common/app_title_logo.dart';

/// 설정 화면
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 0,
        elevation: 0,
      ),
      body: ListView(
        children: [
          // 일반 설정
          SettingsSection(
            title: '일반',
            items: [
              SettingsItem(
                icon: Icons.palette_outlined,
                title: '테마',
                subtitle: AppThemeType.values[settings.themeType.clamp(0, AppThemeType.values.length - 1)].label,
                onTap: () => showThemeDialog(context, ref),
              ),
              SettingsItem(
                icon: Icons.language_outlined,
                title: '언어',
                subtitle: '한국어',
                onTap: () => showLanguageDialog(context),
              ),
            ],
          ),

          // 알림 설정
          _buildNotificationSection(context, ref, settings),

          // 데이터 관리
          BackupRestoreSection(
            lastBackupDate: settings.lastBackupDate,
            onBackup: () => _handleBackup(context, ref),
            onRestore: () => _handleRestore(context, ref),
            onExport: () => _handleExport(context, ref),
            onReset: () => _handleReset(context, ref),
          ),

          // 앱 정보
          SettingsSection(
            title: '정보',
            items: [
              SettingsItem(
                icon: Icons.help_outline_rounded,
                title: '사용 가이드',
                onTap: () => _showGuide(context),
              ),
              SettingsItem(
                icon: Icons.info_outlined,
                title: '앱 정보',
                subtitle: 'v1.0.1',
                onTap: () => showAboutDialog_(context),
              ),
              SettingsItem(
                icon: Icons.description_outlined,
                title: '개인정보 처리방침',
                onTap: () => _showComingSoon(context, '개인정보 처리방침 페이지 준비 중'),
              ),
              SettingsItem(
                icon: Icons.article_outlined,
                title: '이용약관',
                onTap: () => _showComingSoon(context, '이용약관 페이지 준비 중'),
              ),
            ],
          ),

          SizedBox(height: MediaQuery.sizeOf(context).width >= 768 ? 24 : 16),

          // 앱 정보 푸터
          Center(
            child: Column(
              children: [
                AppTitleLogo(
                  fontSize: 16,
                  textColor: context.appTextSecondary,
                ),
                const SizedBox(height: 8),
                Text(
                  '레버리지 ETF 가중 매수 매매법',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.appTextHint,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildNotificationSection(BuildContext context, WidgetRef ref, dynamic settings) {
    final muted = settings.notificationMuted as bool;
    final isDesktop = MediaQuery.sizeOf(context).width >= 768;
    final iconBoxSize = isDesktop ? 40.0 : 34.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(16, isDesktop ? 24 : 16, 16, isDesktop ? 8 : 4),
          child: Text(
            '알림',
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
          child: SwitchListTile(
            dense: !isDesktop,
            secondary: Container(
              width: iconBoxSize,
              height: iconBoxSize,
              decoration: BoxDecoration(
                color: context.appIconBg,
                borderRadius: BorderRadius.circular(isDesktop ? 10 : 8),
              ),
              child: Icon(
                muted ? Icons.notifications_off_outlined : Icons.notifications_outlined,
                color: context.appTextSecondary,
                size: isDesktop ? 22 : 18,
              ),
            ),
            title: Text(
              '알림',
              style: TextStyle(fontSize: isDesktop ? 15 : 14, color: context.appTextPrimary),
            ),
            subtitle: Text(
              muted ? '꺼짐' : '켜짐',
              style: TextStyle(fontSize: isDesktop ? 13 : 12, color: context.appTextHint),
            ),
            value: !muted,
            onChanged: (value) {
              ref.read(settingsProvider.notifier).toggleNotificationMuted(!value);
            },
          ),
        ),
      ],
    );
  }

  Future<void> _handleBackup(BuildContext context, WidgetRef ref) async {
    try {
      final service = ref.read(dataManagementServiceProvider);
      final backup = service.createBackup();
      WebFileService.downloadJson(backup, WebFileService.backupFilename());
      await ref.read(settingsProvider.notifier).updateLastBackupDate();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('백업 파일이 다운로드되었습니다'),
            backgroundColor: AppColors.green500,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('백업 실패: $e')),
        );
      }
    }
  }

  Future<void> _handleRestore(BuildContext context, WidgetRef ref) async {
    try {
      final json = await WebFileService.pickAndReadJsonFile();
      if (json == null) return; // 취소됨

      if (!context.mounted) return;

      // 버전 확인
      if (json['version'] == null || json['data'] == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('올바른 백업 파일이 아닙니다')),
        );
        return;
      }

      final service = ref.read(dataManagementServiceProvider);
      await service.restoreFromBackup(json);
      _refreshAllProviders(ref);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('데이터가 복원되었습니다'),
            backgroundColor: AppColors.green500,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('복원 실패: $e')),
        );
      }
    }
  }

  Future<void> _handleExport(BuildContext context, WidgetRef ref) async {
    try {
      final service = ref.read(dataManagementServiceProvider);
      final csv = service.exportToCsv();
      WebFileService.downloadCsv(csv, WebFileService.csvFilename());
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('CSV 파일이 다운로드되었습니다'),
            backgroundColor: AppColors.green500,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('내보내기 실패: $e')),
        );
      }
    }
  }

  Future<void> _handleReset(BuildContext context, WidgetRef ref) async {
    try {
      final service = ref.read(dataManagementServiceProvider);
      await service.resetAllData();
      _refreshAllProviders(ref);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('모든 데이터가 삭제되었습니다'),
            backgroundColor: AppColors.red500,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('초기화 실패: $e')),
        );
      }
    }
  }

  void _refreshAllProviders(WidgetRef ref) {
    // 생성자에서 자동 로드하는 프로바이더 (invalidate만으로 충분)
    ref.invalidate(settingsProvider);
    ref.invalidate(holdingListProvider);

    // 수동 load()가 필요한 프로바이더 (MainShell.initState에서만 호출됨)
    ref.invalidate(watchlistProvider);
    ref.invalidate(notificationHistoryProvider);
    ref.invalidate(memoListProvider);
    ref.read(watchlistProvider.notifier).load();
    ref.read(notificationHistoryProvider.notifier).load();
    ref.read(memoListProvider.notifier).load();
  }

  void _showComingSoon(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _showGuide(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => GuideSheet(
          scrollController: scrollController,
        ),
      ),
    );
  }
}
