import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/usecases/signal_detector.dart';

/// 매수 금액 표시 위젯
///
/// 오늘의 권장 매수 금액과 상세 breakdown을 표시합니다.
class BuyAmountDisplay extends StatelessWidget {
  final TradingRecommendation recommendation;
  final double? weightedBuyAmount;
  final double? panicBuyAmount;
  final VoidCallback? onRecordBuy;

  const BuyAmountDisplay({
    super.key,
    required this.recommendation,
    this.weightedBuyAmount,
    this.panicBuyAmount,
    this.onRecordBuy,
  });

  @override
  Widget build(BuildContext context) {
    if (!recommendation.needsAction) {
      return _HoldDisplay(message: recommendation.message);
    }

    if (recommendation.isSellSignal) {
      return _SellDisplay(
        recommendation: recommendation,
        onRecordSell: onRecordBuy,
      );
    }

    return _BuyDisplay(
      recommendation: recommendation,
      weightedBuyAmount: weightedBuyAmount,
      panicBuyAmount: panicBuyAmount,
      onRecordBuy: onRecordBuy,
    );
  }
}

/// 보유 상태 표시
class _HoldDisplay extends StatelessWidget {
  final String? message;

  const _HoldDisplay({this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appIconBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.appDivider),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: context.appDivider,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.pause_rounded,
              color: AppColors.gray600,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '오늘은 매매 신호가 없습니다',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: context.appTextPrimary,
                  ),
                ),
                if (message != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    message!,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.appTextSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 매수 신호 표시
class _BuyDisplay extends StatelessWidget {
  final TradingRecommendation recommendation;
  final double? weightedBuyAmount;
  final double? panicBuyAmount;
  final VoidCallback? onRecordBuy;

  const _BuyDisplay({
    required this.recommendation,
    this.weightedBuyAmount,
    this.panicBuyAmount,
    this.onRecordBuy,
  });

  @override
  Widget build(BuildContext context) {
    final isPanic = recommendation.signal == TradingSignal.panicBuy;
    final primaryColor = isPanic ? AppColors.red500 : AppColors.blue500;
    final bgColor = isPanic ? AppColors.red50 : AppColors.blue50;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isPanic ? Icons.local_fire_department : Icons.shopping_cart,
                  color: primaryColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isPanic ? '승부수 + 가중 매수' : '가중 매수',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: primaryColor,
                      ),
                    ),
                    Text(
                      recommendation.message ?? '',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.appTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 금액 breakdown
          if (isPanic && panicBuyAmount != null) ...[
            _AmountRow(
              label: '승부수',
              amount: panicBuyAmount!,
              color: AppColors.red600,
            ),
            const SizedBox(height: 8),
          ],
          if (weightedBuyAmount != null)
            _AmountRow(
              label: '가중 매수',
              amount: weightedBuyAmount!,
              color: AppColors.blue600,
            ),

          const Divider(height: 24),

          // 총 금액
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '오늘 총 매수 권장',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: context.appTextPrimary,
                ),
              ),
              Text(
                _formatKrw(recommendation.recommendedAmount),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
            ],
          ),

          // 예상 수량
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                '약 ${recommendation.estimatedShares.toStringAsFixed(2)}주',
                style: TextStyle(
                  fontSize: 12,
                  color: context.appTextSecondary,
                ),
              ),
            ),
          ),

          // 매수 기록 버튼
          if (onRecordBuy != null) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onRecordBuy,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  '매수 기록하기',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatKrw(double amount) {
    final intAmount = amount.round();
    final absAmount = intAmount.abs();
    final formatted = absAmount.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
    return intAmount < 0 ? '-$formatted원' : '$formatted원';
  }
}

/// 익절 신호 표시
class _SellDisplay extends StatelessWidget {
  final TradingRecommendation recommendation;
  final VoidCallback? onRecordSell;

  const _SellDisplay({
    required this.recommendation,
    this.onRecordSell,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.amber50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.amber400),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.amber100,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.emoji_events_rounded,
                  color: AppColors.amber600,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '익절 목표 달성!',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.amber700,
                      ),
                    ),
                    Text(
                      '수익률 +${recommendation.returnRate.toStringAsFixed(1)}%',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.amber600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '예상 매도 금액',
                style: TextStyle(
                  fontSize: 14,
                  color: context.appTextSecondary,
                ),
              ),
              Text(
                _formatKrw(recommendation.recommendedAmount),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.amber700,
                ),
              ),
            ],
          ),
          if (onRecordSell != null) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onRecordSell,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.amber500,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  '익절 기록하기',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatKrw(double amount) {
    final intAmount = amount.round();
    final absAmount = intAmount.abs();
    final formatted = absAmount.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
    return intAmount < 0 ? '-$formatted원' : '$formatted원';
  }
}

class _AmountRow extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;

  const _AmountRow({
    required this.label,
    required this.amount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: context.appTextSecondary,
          ),
        ),
        Text(
          _formatKrw(amount),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }

  String _formatKrw(double amount) {
    final intAmount = amount.round();
    final absAmount = intAmount.abs();
    final formatted = absAmount.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
    return intAmount < 0 ? '-$formatted원' : '$formatted원';
  }
}
