import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/services/notification/web_notification_service.dart';
import '../../providers/providers.dart';
import '../../widgets/settings/settings_section.dart';
import '../../widgets/settings/settings_dialogs.dart';
import '../../widgets/settings/exchange_rate_dialog.dart';
import '../../widgets/settings/notification_settings.dart';
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
                subtitle: settings.useDarkMode ? '다크 모드' : '라이트 모드',
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

          // 매매 설정
          SettingsSection(
            title: '매매 설정',
            items: [
              SettingsItem(
                icon: Icons.currency_exchange_outlined,
                title: '환율',
                subtitle: '${settings.exchangeRate.toStringAsFixed(0)}원/\$',
                onTap: () => _showExchangeRateDialog(context, ref),
              ),
              SettingsItem(
                icon: Icons.tune_outlined,
                title: '기본 매매 조건',
                subtitle:
                    '매수 ${settings.defaultBuyTrigger.toInt()}%, 익절 +${settings.defaultSellTrigger.toInt()}%',
                onTap: () => _showTradingConditionsDialog(context, ref),
              ),
            ],
          ),

          // 알림 설정
          SettingsSection(
            title: '알림',
            items: [
              SettingsItem(
                icon: Icons.notifications_outlined,
                title: '알림 설정',
                subtitle: _getNotificationSubtitle(settings),
                onTap: () => _showNotificationSettings(context),
              ),
              SettingsItem(
                icon: Icons.notifications_active_outlined,
                title: '브라우저 알림 권한',
                subtitle: WebNotificationService.permissionStatus,
                onTap: () => _handleNotificationPermission(context),
              ),
            ],
          ),

          // 데이터 관리
          BackupRestoreSection(
            lastBackupDate: settings.lastBackupDate,
            onBackup: () => _handleBackup(context, ref),
            onRestore: () => _showComingSoon(context, '복원 기능 준비 중'),
            onExport: () => _showComingSoon(context, '내보내기 기능 준비 중'),
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

          const SizedBox(height: 24),

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

  String _getNotificationSubtitle(dynamic settings) {
    final List<String> enabled = [];
    if (settings.notifyBuySignal) enabled.add('매수 신호');
    if (settings.notifySellSignal) enabled.add('익절 신호');
    if (settings.notifyPanicSignal) enabled.add('승부수');
    if (settings.notifyDailySummary) enabled.add('일일 요약');

    if (enabled.isEmpty) return '알림 없음';
    return enabled.take(2).join(', ') + (enabled.length > 2 ? ' 외' : '');
  }

  void _handleNotificationPermission(BuildContext context) async {
    if (WebNotificationService.isPermissionGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('알림 권한이 이미 허용되어 있습니다'),
          backgroundColor: AppColors.green500,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    if (WebNotificationService.isPermissionDenied) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(
            '알림 권한 차단됨',
            style: TextStyle(color: ctx.appTextPrimary),
          ),
          backgroundColor: ctx.appCardBackground,
          content: Text(
            '브라우저에서 알림이 차단되어 있습니다.\n\n'
            '알림을 받으려면:\n'
            '1. 브라우저 주소창 왼쪽의 자물쇠 아이콘 탭\n'
            '2. "알림" 또는 "Notifications" 찾기\n'
            '3. "허용"으로 변경\n'
            '4. 페이지 새로고침',
            style: TextStyle(color: ctx.appTextSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('확인'),
            ),
          ],
        ),
      );
      return;
    }

    // permission == 'default' → 권한 요청 팝업 표시
    final granted = await WebNotificationService.requestPermission();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(granted ? '알림 권한이 허용되었습니다' : '알림 권한이 거부되었습니다'),
        backgroundColor: granted ? AppColors.green500 : AppColors.red500,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showExchangeRateDialog(BuildContext context, WidgetRef ref) {
    final settings = ref.read(settingsProvider);

    showDialog(
      context: context,
      builder: (context) => ExchangeRateDialog(
        currentRate: settings.exchangeRate,
        onSave: (rate) async {
          await ref.read(settingsProvider.notifier).updateExchangeRate(rate);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('환율이 ${rate.toStringAsFixed(0)}원으로 설정되었습니다'),
                backgroundColor: AppColors.green500,
              ),
            );
          }
        },
      ),
    );
  }

  void _showTradingConditionsDialog(BuildContext context, WidgetRef ref) {
    final settings = ref.read(settingsProvider);

    showDialog(
      context: context,
      builder: (context) => TradingConditionsDialog(
        buyTrigger: settings.defaultBuyTrigger,
        sellTrigger: settings.defaultSellTrigger,
        panicTrigger: settings.defaultPanicTrigger,
        onSave: (buy, sell, panic) async {
          await ref.read(settingsProvider.notifier).updateTradingConditions(
                buyTrigger: buy,
                sellTrigger: sell,
                panicTrigger: panic,
              );
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('매매 조건이 저장되었습니다'),
                backgroundColor: AppColors.green500,
              ),
            );
          }
        },
      ),
    );
  }

  void _showNotificationSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => const NotificationSettingsSheet(),
    );
  }

  Future<void> _handleBackup(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(settingsProvider.notifier).updateLastBackupDate();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('데이터가 백업되었습니다'),
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

  void _showComingSoon(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _showGuide(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
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
