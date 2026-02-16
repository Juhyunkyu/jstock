import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../presentation/providers/portfolio_providers.dart';

/// 통합 포트폴리오 카드 위젯
///
/// 알파 사이클 + 일반 보유를 합산한 전체 포트폴리오 요약을 표시합니다.
class UnifiedPortfolioCard extends StatelessWidget {
  /// 통합 포트폴리오 요약 데이터
  final UnifiedPortfolioSummary summary;

  const UnifiedPortfolioCard({
    super.key,
    required this.summary,
  });

  @override
  Widget build(BuildContext context) {
    final isProfit = summary.totalProfit >= 0;
    final profitColor = isProfit ? AppColors.green500 : AppColors.red500;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary,
            AppColors.primaryDark,
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${summary.totalPositionCount}개 포지션',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 총 자산
          Text(
            _formatKrw(summary.totalValue),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),

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
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${isProfit ? '+' : ''}${_formatKrw(summary.totalProfit)}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '(${isProfit ? '+' : ''}${summary.totalReturnRate.toStringAsFixed(2)}%)',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 자산 배분 바
          _AllocationBar(
            alphaCycleRatio: summary.alphaCycleRatio,
            holdingRatio: summary.holdingRatio,
          ),
          const SizedBox(height: 10),

          // 하단 정보
          Row(
            children: [
              Expanded(
                child: _InfoItem(
                  icon: Icons.loop_rounded,
                  label: '알파 사이클',
                  value: '${summary.alphaCycleCount}개',
                  subValue: '${_formatKrwShort(summary.alphaCycleValue)}원',
                ),
              ),
              Container(
                width: 1,
                height: 36,
                color: Colors.white24,
              ),
              Expanded(
                child: _InfoItem(
                  icon: Icons.account_balance_wallet_outlined,
                  label: '일반 보유',
                  value: '${summary.holdingCount}종목',
                  subValue: '${_formatKrwShort(summary.holdingValue)}원',
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

  String _formatKrwShort(double amount) {
    final intAmount = amount.round();
    final absAmount = intAmount.abs();
    final formatted = absAmount.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
    return intAmount < 0 ? '-$formatted' : formatted;
  }
}

/// 자산 배분 바
class _AllocationBar extends StatelessWidget {
  final double alphaCycleRatio;
  final double holdingRatio;

  const _AllocationBar({
    required this.alphaCycleRatio,
    required this.holdingRatio,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 바
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Row(
            children: [
              if (alphaCycleRatio > 0)
                Expanded(
                  flex: alphaCycleRatio.round(),
                  child: Container(
                    height: 6,
                    color: Colors.white,
                  ),
                ),
              if (holdingRatio > 0)
                Expanded(
                  flex: holdingRatio.round(),
                  child: Container(
                    height: 6,
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                ),
              if (alphaCycleRatio == 0 && holdingRatio == 0)
                Expanded(
                  child: Container(
                    height: 6,
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // 레이블
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '알파 사이클 ${alphaCycleRatio.toStringAsFixed(1)}%',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '일반 보유 ${holdingRatio.toStringAsFixed(1)}%',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String subValue;

  const _InfoItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.subValue,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: Colors.white60, size: 18),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                color: Colors.white60,
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            Text(
              subValue,
              style: const TextStyle(
                fontSize: 10,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
