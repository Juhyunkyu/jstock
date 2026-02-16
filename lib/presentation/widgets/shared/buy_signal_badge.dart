import 'package:flutter/material.dart';
import '../../../domain/usecases/signal_detector.dart';
import '../../../core/theme/app_colors.dart';

/// 매수 신호 배지 위젯
///
/// 현재 매매 신호 상태를 시각적으로 표시합니다.
class BuySignalBadge extends StatelessWidget {
  final TradingSignal signal;
  final bool showLabel;
  final double? size;

  const BuySignalBadge({
    super.key,
    required this.signal,
    this.showLabel = true,
    this.size,
  });

  @override
  Widget build(BuildContext context) {
    final config = _getSignalConfig();
    final badgeSize = size ?? 32.0;

    return Container(
      padding: showLabel
          ? const EdgeInsets.symmetric(horizontal: 12, vertical: 6)
          : EdgeInsets.all(badgeSize * 0.2),
      decoration: BoxDecoration(
        color: config.backgroundColor,
        borderRadius: BorderRadius.circular(showLabel ? 16 : badgeSize / 2),
        border: Border.all(
          color: config.borderColor,
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            config.icon,
            color: config.iconColor,
            size: showLabel ? 16 : badgeSize * 0.5,
          ),
          if (showLabel) ...[
            const SizedBox(width: 6),
            Text(
              config.label,
              style: TextStyle(
                color: config.textColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  _SignalConfig _getSignalConfig() {
    switch (signal) {
      case TradingSignal.hold:
        return _SignalConfig(
          label: '보유',
          icon: Icons.pause_circle_outline,
          backgroundColor: AppColors.gray100,
          borderColor: AppColors.gray300,
          iconColor: AppColors.gray600,
          textColor: AppColors.gray700,
        );

      case TradingSignal.weightedBuy:
        return _SignalConfig(
          label: '매수',
          icon: Icons.arrow_downward_rounded,
          backgroundColor: AppColors.blue50,
          borderColor: AppColors.blue400,
          iconColor: AppColors.blue600,
          textColor: AppColors.blue700,
        );

      case TradingSignal.panicBuy:
        return _SignalConfig(
          label: '승부수',
          icon: Icons.local_fire_department_rounded,
          backgroundColor: AppColors.red50,
          borderColor: AppColors.red400,
          iconColor: AppColors.red600,
          textColor: AppColors.red700,
        );

      case TradingSignal.takeProfit:
        return _SignalConfig(
          label: '익절',
          icon: Icons.emoji_events_rounded,
          backgroundColor: AppColors.amber50,
          borderColor: AppColors.amber400,
          iconColor: AppColors.amber600,
          textColor: AppColors.amber700,
        );
    }
  }
}

class _SignalConfig {
  final String label;
  final IconData icon;
  final Color backgroundColor;
  final Color borderColor;
  final Color iconColor;
  final Color textColor;

  const _SignalConfig({
    required this.label,
    required this.icon,
    required this.backgroundColor,
    required this.borderColor,
    required this.iconColor,
    required this.textColor,
  });
}

/// 신호별 간단한 점 표시 위젯
class SignalDot extends StatelessWidget {
  final TradingSignal signal;
  final double size;

  const SignalDot({
    super.key,
    required this.signal,
    this.size = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _getColor(),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: _getColor().withValues(alpha: 0.4),
            blurRadius: 4,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }

  Color _getColor() {
    switch (signal) {
      case TradingSignal.hold:
        return AppColors.gray400;
      case TradingSignal.weightedBuy:
        return AppColors.blue500;
      case TradingSignal.panicBuy:
        return AppColors.red500;
      case TradingSignal.takeProfit:
        return AppColors.amber500;
    }
  }
}
