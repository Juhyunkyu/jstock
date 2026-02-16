import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// 알림 설정 위젯
class NotificationSettings extends StatefulWidget {
  final bool buySignalEnabled;
  final bool takeProfitEnabled;
  final bool panicBuyEnabled;
  final bool dailySummaryEnabled;
  final Function(bool) onBuySignalChanged;
  final Function(bool) onTakeProfitChanged;
  final Function(bool) onPanicBuyChanged;
  final Function(bool) onDailySummaryChanged;

  const NotificationSettings({
    super.key,
    required this.buySignalEnabled,
    required this.takeProfitEnabled,
    required this.panicBuyEnabled,
    required this.dailySummaryEnabled,
    required this.onBuySignalChanged,
    required this.onTakeProfitChanged,
    required this.onPanicBuyChanged,
    required this.onDailySummaryChanged,
  });

  @override
  State<NotificationSettings> createState() => _NotificationSettingsState();
}

class _NotificationSettingsState extends State<NotificationSettings> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text(
            '알림 설정',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: context.appTextPrimary,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            '매매 신호 발생 시 알림을 받을 수 있습니다',
            style: TextStyle(
              fontSize: 13,
              color: context.appTextSecondary,
            ),
          ),
        ),
        const SizedBox(height: 16),

        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: context.appSurface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              _NotificationToggle(
                icon: Icons.add_circle_outline_rounded,
                iconColor: AppColors.weightedBuy,
                title: '매수 신호',
                subtitle: '손실률 -20% 도달 시 알림',
                value: widget.buySignalEnabled,
                onChanged: widget.onBuySignalChanged,
              ),
              const Divider(height: 1, indent: 56),
              _NotificationToggle(
                icon: Icons.monetization_on_outlined,
                iconColor: AppColors.takeProfit,
                title: '익절 신호',
                subtitle: '수익률 +20% 도달 시 알림',
                value: widget.takeProfitEnabled,
                onChanged: widget.onTakeProfitChanged,
              ),
              const Divider(height: 1, indent: 56),
              _NotificationToggle(
                icon: Icons.warning_amber_rounded,
                iconColor: AppColors.panicBuy,
                title: '승부수 신호',
                subtitle: '손실률 -50% 도달 시 알림',
                value: widget.panicBuyEnabled,
                onChanged: widget.onPanicBuyChanged,
              ),
              const Divider(height: 1, indent: 56),
              _NotificationToggle(
                icon: Icons.summarize_outlined,
                iconColor: AppColors.primary,
                title: '일일 요약',
                subtitle: '매일 저녁 포트폴리오 요약 알림',
                value: widget.dailySummaryEnabled,
                onChanged: widget.onDailySummaryChanged,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NotificationToggle extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final Function(bool) onChanged;

  const _NotificationToggle({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
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
          color: context.appTextPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: context.appTextHint,
        ),
      ),
      trailing: Switch.adaptive(
        value: value,
        onChanged: onChanged,
        activeColor: AppColors.primary,
      ),
    );
  }
}

/// 알림 설정 바텀 시트
class NotificationSettingsSheet extends StatefulWidget {
  const NotificationSettingsSheet({super.key});

  @override
  State<NotificationSettingsSheet> createState() =>
      _NotificationSettingsSheetState();
}

class _NotificationSettingsSheetState extends State<NotificationSettingsSheet> {
  // TODO: Provider에서 실제 값 가져오기
  bool _buySignalEnabled = true;
  bool _takeProfitEnabled = true;
  bool _panicBuyEnabled = true;
  bool _dailySummaryEnabled = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 핸들
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: context.appBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          NotificationSettings(
            buySignalEnabled: _buySignalEnabled,
            takeProfitEnabled: _takeProfitEnabled,
            panicBuyEnabled: _panicBuyEnabled,
            dailySummaryEnabled: _dailySummaryEnabled,
            onBuySignalChanged: (v) => setState(() => _buySignalEnabled = v),
            onTakeProfitChanged: (v) => setState(() => _takeProfitEnabled = v),
            onPanicBuyChanged: (v) => setState(() => _panicBuyEnabled = v),
            onDailySummaryChanged: (v) =>
                setState(() => _dailySummaryEnabled = v),
          ),

          const SizedBox(height: 24),

          // 저장 버튼
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // TODO: 설정 저장
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('알림 설정이 저장되었습니다'),
                      backgroundColor: AppColors.green500,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  '저장',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
