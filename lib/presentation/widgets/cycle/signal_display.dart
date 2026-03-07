import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/krw_formatter.dart';
import '../../../data/models/trade.dart';

/// 신호 표시 크기
enum SignalDisplaySize {
  /// 카드 리스트용 소형 pill 배지
  compact,

  /// 상세 화면용 대형 카드 (금액 표시 포함)
  large,
}

/// 현재 거래 신호를 시각적으로 표시하는 위젯
///
/// compact: 작은 pill 배지 (리스트 카드에서 사용)
/// large: 금액 + 손실률 표시가 포함된 큰 카드 (상세 화면)
class SignalDisplay extends StatelessWidget {
  final TradeSignal signal;
  final SignalDisplaySize size;

  /// large 모드에서 표시할 매수/매도 권장 금액 (KRW)
  final double? amount;

  /// large 모드에서 표시할 현재 손실률 (%)
  final double? lossRate;

  const SignalDisplay({
    super.key,
    required this.signal,
    this.size = SignalDisplaySize.compact,
    this.amount,
    this.lossRate,
  });

  @override
  Widget build(BuildContext context) {
    final config = _getSignalConfig(context);

    return switch (size) {
      SignalDisplaySize.compact => _buildCompact(context, config),
      SignalDisplaySize.large => _buildLarge(context, config),
    };
  }

  Widget _buildCompact(BuildContext context, _SignalConfig config) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: config.color.withValues(
          alpha: context.isDarkMode ? 0.15 : 0.08,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            config.icon,
            size: 13,
            color: config.color,
          ),
          const SizedBox(width: 4),
          Text(
            config.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: config.color,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLarge(BuildContext context, _SignalConfig config) {
    final bgOpacity = context.isDarkMode ? 0.15 : 0.08;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: config.color.withValues(alpha: bgOpacity),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: config.color.withValues(alpha: bgOpacity * 2),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 신호 아이콘 + 라벨
          Row(
            children: [
              Icon(
                config.icon,
                size: 20,
                color: config.color,
              ),
              const SizedBox(width: 8),
              Text(
                config.label,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: config.color,
                ),
              ),
            ],
          ),

          // 권장 금액
          if (amount != null && amount! > 0) ...[
            const SizedBox(height: 8),
            Text(
              '\u20A9${formatKrwWithComma(amount!)} $_actionLabel',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: context.appTextPrimary,
              ),
            ),
          ],

          // 손실률
          if (lossRate != null) ...[
            const SizedBox(height: 4),
            Text(
              '\uC190\uC2E4\uB960 ${lossRate! >= 0 ? '+' : ''}${lossRate!.toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 13,
                color: context.appTextSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 매수/매도 권장 라벨
  String get _actionLabel {
    switch (signal) {
      case TradeSignal.takeProfit:
      case TradeSignal.cashSecure:
        return '\uB9E4\uB3C4 \uAD8C\uC7A5';
      default:
        return '\uB9E4\uC218 \uAD8C\uC7A5';
    }
  }

  _SignalConfig _getSignalConfig(BuildContext context) {
    switch (signal) {
      case TradeSignal.initial:
        return _SignalConfig(
          label: '\uCD08\uAE30 \uC9C4\uC785',
          icon: Icons.play_arrow,
          color: AppColors.green600,
        );
      case TradeSignal.weightedBuy:
        return _SignalConfig(
          label: '\uAC00\uC911 \uB9E4\uC218',
          icon: Icons.add_chart,
          color: AppColors.blue500,
        );
      case TradeSignal.panicBuy:
        return _SignalConfig(
          label: '\uC2B9\uBD80\uC218!',
          icon: Icons.local_fire_department,
          color: AppColors.red500,
        );
      case TradeSignal.cashSecure:
        return _SignalConfig(
          label: '\uD604\uAE08 \uD655\uBCF4',
          icon: Icons.savings,
          color: AppColors.amber500,
        );
      case TradeSignal.takeProfit:
        return _SignalConfig(
          label: '\uC775\uC808!',
          icon: Icons.celebration,
          color: AppColors.green500,
        );
      case TradeSignal.locAB:
        return _SignalConfig(
          label: 'LOC A+B',
          icon: Icons.double_arrow,
          color: AppColors.blue500,
        );
      case TradeSignal.locA:
        return _SignalConfig(
          label: 'LOC A',
          icon: Icons.arrow_forward,
          color: AppColors.blue500,
        );
      case TradeSignal.locB:
        return _SignalConfig(
          label: 'LOC B',
          icon: Icons.arrow_forward,
          color: AppColors.blue400,
        );
      case TradeSignal.hold:
        return _SignalConfig(
          label: '\uB300\uAE30',
          icon: Icons.hourglass_empty,
          color: context.appTextHint,
        );
      case TradeSignal.manual:
        return _SignalConfig(
          label: '\uC218\uB3D9',
          icon: Icons.edit,
          color: context.appTextSecondary,
        );
    }
  }
}

class _SignalConfig {
  final String label;
  final IconData icon;
  final Color color;

  const _SignalConfig({
    required this.label,
    required this.icon,
    required this.color,
  });
}
