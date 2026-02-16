import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// KRW 금액을 천 단위 콤마와 "원" 접미사로 포맷팅
String formatKrwWithComma(double amount) {
  final intAmount = amount.round();
  final absAmount = intAmount.abs();
  final formatted = absAmount.toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
    (Match m) => '${m[1]},',
  );
  return intAmount < 0 ? '-$formatted원' : '$formatted원';
}

/// 손익 요약 카드
class ProfitLossSummaryCard extends StatelessWidget {
  final double currentPrice;
  final double currentExchangeRate;
  final double usdPL;
  final double usdReturnRate;
  final double krwTotalPL;
  final double krwReturnRate;
  final double currencyPL;
  final int quantity;

  const ProfitLossSummaryCard({
    super.key,
    required this.currentPrice,
    required this.currentExchangeRate,
    required this.usdPL,
    required this.usdReturnRate,
    required this.krwTotalPL,
    required this.krwReturnRate,
    required this.currencyPL,
    required this.quantity,
  });

  @override
  Widget build(BuildContext context) {
    // 순수 원화 손익 (환차 제외) = 외화손익 * 현재환율
    final pureKrwPL = usdPL * currentExchangeRate;
    // 순수 원화 수익률
    final pureKrwReturnRate = usdReturnRate; // 외화 수익률과 동일

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.secondary,
            AppColors.secondaryDark,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.secondary.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 현재 시세 정보
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '현재 시세',
                style: TextStyle(fontSize: 14, color: Colors.white70),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '\$${currentPrice.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    '환율: \u20a9${currentExchangeRate.toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 11, color: Colors.white60),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 10),

          // 1. 외화손익: 순수 주가 변동 (USD)
          SimpleProfitRow(
            label: '외화손익',
            value: usdPL,
            percentage: usdReturnRate,
            isUsd: true,
          ),
          const SizedBox(height: 8),

          // 2. 원화손익: 순수 주가 변동 (KRW, 환차 미포함)
          SimpleProfitRow(
            label: '원화손익',
            value: pureKrwPL,
            percentage: pureKrwReturnRate,
            isUsd: false,
          ),
          const SizedBox(height: 8),

          // 3. 환차손익: 총원화손익(환차손익만)
          CurrencyProfitRow(
            label: '환차손익',
            totalValue: krwTotalPL,
            currencyValue: currencyPL,
            percentage: krwReturnRate,
          ),
        ],
      ),
    );
  }
}

/// 단순 손익 Row (외화손익, 원화손익용)
class SimpleProfitRow extends StatelessWidget {
  final String label;
  final double value;
  final double percentage;
  final bool isUsd;

  const SimpleProfitRow({
    super.key,
    required this.label,
    required this.value,
    required this.percentage,
    required this.isUsd,
  });

  @override
  Widget build(BuildContext context) {
    final isPositive = value >= 0;
    final percentColor = percentage >= 0 ? AppColors.red500 : AppColors.blue500;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: Colors.white70),
        ),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: (isPositive ? AppColors.red500 : AppColors.blue500)
                    .withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                _formatValue(),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${percentage >= 0 ? '+' : ''}${percentage.toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: percentColor,
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _formatValue() {
    final sign = value >= 0 ? '+' : '';
    if (isUsd) {
      return '$sign${value.toStringAsFixed(4)} USD';
    } else {
      return '$sign${_formatKrwWithComma(value)}원';
    }
  }

  String _formatKrwWithComma(double amount) {
    final intAmount = amount.round();
    final absAmount = intAmount.abs();
    final formatted = absAmount.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
    return intAmount < 0 ? '-$formatted' : formatted;
  }
}

/// 환차손익 Row: 총금액(환차손익) 형식
class CurrencyProfitRow extends StatelessWidget {
  final String label;
  final double totalValue;    // 총 원화 손익
  final double currencyValue; // 환차 손익만
  final double percentage;

  const CurrencyProfitRow({
    super.key,
    required this.label,
    required this.totalValue,
    required this.currencyValue,
    required this.percentage,
  });

  @override
  Widget build(BuildContext context) {
    final isPositive = totalValue >= 0;
    final percentColor = percentage >= 0 ? AppColors.red500 : AppColors.blue500;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white70,
          ),
        ),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: (isPositive ? AppColors.red500 : AppColors.blue500)
                    .withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                _formatValue(),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${percentage >= 0 ? '+' : ''}${percentage.toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: percentColor,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 형식: +총금액(환차손익)원
  String _formatValue() {
    final totalSign = totalValue >= 0 ? '+' : '';
    final currSign = currencyValue >= 0 ? '+' : '';
    return '$totalSign${_formatKrwWithComma(totalValue)}($currSign${_formatKrwWithComma(currencyValue)})원';
  }

  String _formatKrwWithComma(double amount) {
    final intAmount = amount.round();
    final absAmount = intAmount.abs();
    final formatted = absAmount.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
    return intAmount < 0 ? '-$formatted' : formatted;
  }
}
