import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// 내 자산 요약 카드 위젯
///
/// 총 자산, 수익/손실, 현금 비율을 표시합니다.
class PortfolioSummaryCard extends StatelessWidget {
  /// 총 자산 (원화)
  final double totalAsset;

  /// 총 수익/손실 금액 (원화)
  final double totalProfit;

  /// 수익률 (%)
  final double returnRate;

  /// 현금 비율 (%)
  final double cashRatio;

  /// 활성 사이클 수
  final int activeCycleCount;

  const PortfolioSummaryCard({
    super.key,
    required this.totalAsset,
    required this.totalProfit,
    required this.returnRate,
    required this.cashRatio,
    required this.activeCycleCount,
  });

  @override
  Widget build(BuildContext context) {
    final isProfit = totalProfit >= 0;
    final profitColor = isProfit ? AppColors.green500 : AppColors.red500;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary,
            AppColors.primaryDark,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '내 포트폴리오',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white70,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '활성 $activeCycleCount개',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 총 자산
          Text(
            _formatKrw(totalAsset),
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),

          // 수익/손실
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: profitColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isProfit ? Icons.trending_up : Icons.trending_down,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${isProfit ? '+' : ''}${_formatKrw(totalProfit)}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '(${isProfit ? '+' : ''}${returnRate.toStringAsFixed(2)}%)',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 하단 정보
          Row(
            children: [
              Expanded(
                child: _InfoItem(
                  icon: Icons.account_balance_wallet_outlined,
                  label: '현금 비율',
                  value: '${cashRatio.toStringAsFixed(1)}%',
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: Colors.white24,
              ),
              Expanded(
                child: _InfoItem(
                  icon: Icons.loop_rounded,
                  label: '진행 중',
                  value: '$activeCycleCount 사이클',
                ),
              ),
            ],
          ),
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

class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: Colors.white60, size: 20),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.white60,
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
