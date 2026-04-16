import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/services/notification/web_notification_service.dart';
import '../../../data/services/data/web_file_service.dart';
import '../../providers/providers.dart';
import '../../widgets/settings/settings_section.dart';
import '../../widgets/settings/settings_dialogs.dart';
import '../../widgets/settings/backup_restore.dart';
import '../../widgets/settings/guide_sheet.dart';
import '../../widgets/settings/legal_sheets.dart';
import '../../widgets/common/app_title_logo.dart';
import '../../widgets/common/top_toast.dart';

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
                trailingText: AppThemeType.values[settings.themeType.clamp(0, AppThemeType.values.length - 1)].label,
                onTap: () => showThemeDialog(context, ref),
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
                trailingText: 'v${AppConstants.appVersion}',
                onTap: () => showAboutDialog_(context),
              ),
              SettingsItem(
                icon: Icons.description_outlined,
                title: '개인정보 처리방침',
                onTap: () => showPrivacyPolicySheet(context),
              ),
              SettingsItem(
                icon: Icons.article_outlined,
                title: '이용약관',
                onTap: () => showTermsOfServiceSheet(context),
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
    final permissionDenied = !WebNotificationService.isPermissionGranted && !muted;
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
          child: Column(
            children: [
              SwitchListTile(
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
                value: !muted,
                onChanged: (value) {
                  ref.read(settingsProvider.notifier).toggleNotificationMuted(!value);
                },
              ),
              // 브라우저 알림 권한 차단 경고
              if (permissionDenied)
                InkWell(
                  onTap: () => _showNotificationPermissionGuide(context),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            size: 16, color: AppColors.calendarInflation),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '브라우저 알림이 차단되어 있습니다',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.calendarInflation,
                            ),
                          ),
                        ),
                        Text(
                          '해결 방법',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: context.appAccent,
                          ),
                        ),
                        Icon(Icons.chevron_right,
                            size: 16, color: context.appAccent),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// 브라우저 알림 권한 설정 안내 바텀시트
  void _showNotificationPermissionGuide(BuildContext context) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: context.appCardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: context.appDivider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  '알림 권한 설정 방법',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: context.appTextPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '브라우저에서 알림을 차단한 상태입니다.\n아래 안내에 따라 알림을 허용해주세요.',
                  style: TextStyle(
                    fontSize: 13,
                    color: context.appTextSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                // Android Chrome
                _buildGuideSection(
                  context,
                  icon: Icons.android,
                  title: 'Android (Chrome)',
                  steps: [
                    '주소창 왼쪽의 자물쇠 또는 튜닝 아이콘을 탭합니다',
                    '"권한" 또는 "사이트 설정"을 탭합니다',
                    '"알림"을 찾아 "허용"으로 변경합니다',
                    '페이지를 새로고침하면 알림이 활성화됩니다',
                  ],
                ),
                const SizedBox(height: 20),
                // iPhone Safari
                _buildGuideSection(
                  context,
                  icon: Icons.phone_iphone,
                  title: 'iPhone (Safari)',
                  steps: [
                    '홈 화면에 Alpha Cycle이 추가되어 있어야 합니다',
                    'iPhone 설정 앱을 엽니다',
                    'Safari > 고급 > 웹사이트 데이터에서 알림을 허용합니다',
                    'iOS 16.4 이상이 필요합니다',
                  ],
                ),
                const SizedBox(height: 20),
                // Desktop
                _buildGuideSection(
                  context,
                  icon: Icons.desktop_windows,
                  title: 'PC (Chrome/Edge)',
                  steps: [
                    '주소창 왼쪽의 자물쇠 아이콘을 클릭합니다',
                    '"사이트 설정"을 클릭합니다',
                    '"알림"을 "허용"으로 변경합니다',
                    '페이지를 새로고침합니다',
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('닫기'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGuideSection(
    BuildContext context, {
    required IconData icon,
    required String title,
    required List<String> steps,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: context.appAccent),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: context.appTextPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...steps.asMap().entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.only(left: 28, bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: context.appIconBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      '${entry.key + 1}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: context.appAccent,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    entry.value,
                    style: TextStyle(
                      fontSize: 13,
                      color: context.appTextSecondary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
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
        showSuccessToast(context, '백업 파일이 다운로드되었습니다');
      }
    } catch (e) {
      if (context.mounted) {
        showErrorToast(context, '백업 실패: $e');
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
        showErrorToast(context, '올바른 백업 파일이 아닙니다');
        return;
      }

      final service = ref.read(dataManagementServiceProvider);
      await service.restoreFromBackup(json);
      _refreshAllProviders(ref);

      if (context.mounted) {
        showSuccessToast(context, '데이터가 복원되었습니다');
      }
    } catch (e) {
      if (context.mounted) {
        showErrorToast(context, '복원 실패: $e');
      }
    }
  }

  Future<void> _handleExport(BuildContext context, WidgetRef ref) async {
    try {
      final service = ref.read(dataManagementServiceProvider);
      final csv = service.exportToCsv();
      WebFileService.downloadCsv(csv, WebFileService.csvFilename());
      if (context.mounted) {
        showSuccessToast(context, 'CSV 파일이 다운로드되었습니다');
      }
    } catch (e) {
      if (context.mounted) {
        showErrorToast(context, '내보내기 실패: $e');
      }
    }
  }

  Future<void> _handleReset(BuildContext context, WidgetRef ref) async {
    try {
      final service = ref.read(dataManagementServiceProvider);
      await service.resetAllData();
      _refreshAllProviders(ref);

      if (context.mounted) {
        showSuccessToast(context, '모든 데이터가 삭제되었습니다');
      }
    } catch (e) {
      if (context.mounted) {
        showErrorToast(context, '초기화 실패: $e');
      }
    }
  }

  void _refreshAllProviders(WidgetRef ref) {
    // 생성자에서 자동 로드하는 프로바이더 (invalidate만으로 충분)
    ref.invalidate(settingsProvider);
    ref.invalidate(holdingListProvider);
    ref.invalidate(cycleListProvider);
    ref.invalidate(allTradesProvider);

    // 수동 load()가 필요한 프로바이더 (MainShell.initState에서만 호출됨)
    ref.invalidate(watchlistProvider);
    ref.invalidate(notificationHistoryProvider);
    ref.invalidate(memoListProvider);
    ref.invalidate(chartDrawingProvider);
    ref.invalidate(watchlistGroupProvider);
    ref.invalidate(recentViewProvider);
    ref.read(watchlistProvider.notifier).load();
    ref.read(notificationHistoryProvider.notifier).load();
    ref.read(memoListProvider.notifier).load();
    ref.read(watchlistGroupProvider.notifier).load();
    ref.read(recentViewProvider.notifier).load();
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
