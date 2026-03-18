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
    final isMobile = MediaQuery.sizeOf(context).width < 600;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 16,
        vertical: isMobile ? 10 : 14,
      ),
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
          // 신호 아이콘 + 라벨 + 권장 금액 (같은 행)
          Row(
            children: [
              Icon(config.icon, size: isMobile ? 18 : 20, color: config.color),
              SizedBox(width: isMobile ? 6 : 8),
              Text(
                config.label,
                style: TextStyle(
                  fontSize: isMobile ? 15 : 18,
                  fontWeight: FontWeight.bold,
                  color: config.color,
                ),
              ),
              if (amount != null && amount! > 0) ...[
                const Spacer(),
                Text(
                  '$_actionLabel',
                  style: TextStyle(
                    fontSize: isMobile ? 11 : 13,
                    color: context.appTextSecondary,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${formatKrwWithComma(amount!)}\u2009원',
                  style: TextStyle(
                    fontSize: isMobile ? 14 : 16,
                    fontWeight: FontWeight.w600,
                    color: context.appTextPrimary,
                  ),
                ),
              ],
            ],
          ),

          // 손실률 (오른쪽 정렬)
          if (lossRate != null) ...[
            SizedBox(height: isMobile ? 2 : 4),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '\uC190\uC2E4\uB960 ${lossRate! >= 0 ? '+' : ''}${lossRate!.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: isMobile ? 11 : 13,
                  color: context.appTextSecondary,
                ),
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
      case TradeSignal.sellLocQuarter:
      case TradeSignal.sellLimitThreeQ:
      case TradeSignal.takeProfitFull:
        return '매도 권장';
      case TradeSignal.noFill:
        return '미체결';
      default:
        return '매수 권장';
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
          label: '수동',
          icon: Icons.edit,
          color: context.appTextSecondary,
        );
      case TradeSignal.sellLocQuarter:
        return _SignalConfig(
          label: 'LOC 매도 ¼',
          icon: Icons.sell,
          color: AppColors.green500,
        );
      case TradeSignal.sellLimitThreeQ:
        return _SignalConfig(
          label: '지정가 매도 ¾',
          icon: Icons.sell,
          color: AppColors.green600,
        );
      case TradeSignal.takeProfitFull:
        return _SignalConfig(
          label: '전량 익절!',
          icon: Icons.celebration,
          color: AppColors.green500,
        );
      case TradeSignal.buySingle:
        return _SignalConfig(
          label: '단일 매수',
          icon: Icons.arrow_forward,
          color: AppColors.blue500,
        );
      case TradeSignal.noFill:
        return _SignalConfig(
          label: '미체결',
          icon: Icons.block,
          color: context.appTextHint,
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
