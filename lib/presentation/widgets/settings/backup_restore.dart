import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// 데이터 백업/복원 위젯
class BackupRestoreSection extends StatelessWidget {
  final VoidCallback onBackup;
  final VoidCallback onRestore;
  final VoidCallback onExport;
  final DateTime? lastBackupDate;

  const BackupRestoreSection({
    super.key,
    required this.onBackup,
    required this.onRestore,
    required this.onExport,
    this.lastBackupDate,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text(
            '데이터 관리',
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
              // 백업
              _DataActionTile(
                icon: Icons.backup_outlined,
                iconColor: AppColors.primary,
                title: '데이터 백업',
                subtitle: lastBackupDate != null
                    ? '마지막 백업: ${_formatDate(lastBackupDate!)}'
                    : '백업 기록 없음',
                onTap: () => _showBackupDialog(context),
              ),
              const Divider(height: 1, indent: 56),

              // 복원
              _DataActionTile(
                icon: Icons.restore_outlined,
                iconColor: AppColors.amber600,
                title: '데이터 복원',
                subtitle: '백업 파일에서 데이터 복원',
                onTap: () => _showRestoreDialog(context),
              ),
              const Divider(height: 1, indent: 56),

              // 내보내기
              _DataActionTile(
                icon: Icons.file_download_outlined,
                iconColor: AppColors.green600,
                title: '데이터 내보내기',
                subtitle: 'CSV 파일로 거래 내역 내보내기',
                onTap: () => _showExportDialog(context),
              ),
              const Divider(height: 1, indent: 56),

              // 초기화
              _DataActionTile(
                icon: Icons.delete_forever_outlined,
                iconColor: AppColors.red500,
                title: '데이터 초기화',
                subtitle: '모든 데이터 삭제 (되돌릴 수 없음)',
                onTap: () => _showResetDialog(context),
                isDestructive: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showBackupDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.backup_outlined, color: AppColors.primary),
            const SizedBox(width: 12),
            const Text('데이터 백업'),
          ],
        ),
        content: const Text(
          '현재 모든 사이클과 거래 데이터를 백업합니다.\n\n백업 파일은 기기 내 저장소에 저장됩니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onBackup();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('백업이 완료되었습니다'),
                  backgroundColor: AppColors.green500,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('백업하기'),
          ),
        ],
      ),
    );
  }

  void _showRestoreDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.restore_outlined, color: AppColors.amber600),
            const SizedBox(width: 12),
            const Text('데이터 복원'),
          ],
        ),
        content: const Text(
          '백업 파일에서 데이터를 복원합니다.\n\n⚠️ 현재 데이터가 백업 데이터로 대체됩니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onRestore();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.amber600,
              foregroundColor: Colors.white,
            ),
            child: const Text('복원하기'),
          ),
        ],
      ),
    );
  }

  void _showExportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.file_download_outlined, color: AppColors.green600),
            const SizedBox(width: 12),
            const Text('데이터 내보내기'),
          ],
        ),
        content: const Text(
          '거래 내역을 CSV 파일로 내보냅니다.\n\n내보낸 파일은 스프레드시트에서 열 수 있습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onExport();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('내보내기가 완료되었습니다'),
                  backgroundColor: AppColors.green500,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.green600,
              foregroundColor: Colors.white,
            ),
            child: const Text('내보내기'),
          ),
        ],
      ),
    );
  }

  void _showResetDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_rounded, color: AppColors.red500),
            const SizedBox(width: 12),
            const Text('데이터 초기화'),
          ],
        ),
        content: const Text(
          '정말 모든 데이터를 삭제하시겠습니까?\n\n⚠️ 이 작업은 되돌릴 수 없습니다.\n모든 사이클, 거래 내역, 설정이 삭제됩니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: 데이터 초기화 로직
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('모든 데이터가 삭제되었습니다'),
                  backgroundColor: AppColors.red500,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.red500,
              foregroundColor: Colors.white,
            ),
            child: const Text('삭제하기'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
  }
}

class _DataActionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isDestructive;

  const _DataActionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: iconColor,
          size: 22,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: isDestructive ? AppColors.red500 : context.appTextPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: context.appTextHint,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: isDestructive ? AppColors.red400 : context.appTextHint,
      ),
    );
  }
}
