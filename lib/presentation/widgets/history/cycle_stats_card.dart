import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/cycle.dart';
import '../shared/return_badge.dart';

/// 완료된 사이클 통계 카드 위젯
class CycleStatsCard extends StatelessWidget {
  final Cycle cycle;
  final double finalPrice;
  final int tradeCount;
  final VoidCallback? onTap;
  final bool inGrid;

  const CycleStatsCard({
    super.key,
    required this.cycle,
    required this.finalPrice,
    this.tradeCount = 0,
    this.onTap,
    this.inGrid = false,
  });

  @override
  Widget build(BuildContext context) {
    final totalReturn = _calculateTotalReturn();
    final isProfit = totalReturn >= 0;
    final duration = cycle.endDate != null
        ? cycle.endDate!.difference(cycle.startDate).inDays
        : 0;

    return Container(
      margin: inGrid
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: context.isDarkMode
                ? Colors.white.withValues(alpha: 0.03)
                : Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 헤더: 종목 + 사이클 번호 + 상태
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: context.appTickerColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        cycle.ticker,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: context.appTickerColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '#${cycle.cycleNumber}',
                      style: TextStyle(
                        fontSize: 14,
                        color: context.appTextSecondary,
                      ),
                    ),
                    const Spacer(),
                    ReturnBadge(
                      value: totalReturn,
                      colorScheme: ReturnBadgeColorScheme.redBlue,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 통계 그리드
                Row(
                  children: [
                    _StatItem(
                      icon: Icons.calendar_today_outlined,
                      label: '운용 기간',
                      value: '$duration일',
                    ),
                    _StatItem(
                      icon: Icons.repeat_rounded,
                      label: '거래 횟수',
                      value: '${tradeCount}회',
                    ),
                    _StatItem(
                      icon: Icons.account_balance_wallet_outlined,
                      label: '시드',
                      value: _formatKrw(cycle.seedAmount),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 최종 자산
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isProfit
                        ? context.appStockChangePlusBg
                        : context.appStockChangeMinusBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '최종 자산',
                        style: TextStyle(
                          fontSize: 13,
                          color: context.appTextSecondary,
                        ),
                      ),
                      Text(
                        _formatKrw(cycle.totalAsset(finalPrice)),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isProfit
                              ? context.appStockChangePlusFg
                              : context.appStockChangeMinusFg,
                        ),
                      ),
                    ],
                  ),
                ),

                // 기간
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _formatDate(cycle.startDate),
                      style: TextStyle(
                        fontSize: 12,
                        color: context.appTextHint,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(
                        Icons.arrow_forward,
                        size: 14,
                        color: context.appTextHint,
                      ),
                    ),
                    Text(
                      cycle.endDate != null
                          ? _formatDate(cycle.endDate!)
                          : '진행중',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.appTextHint,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  double _calculateTotalReturn() {
    final finalAsset = cycle.totalAsset(finalPrice);
    return ((finalAsset - cycle.seedAmount) / cycle.seedAmount) * 100;
  }

  String _formatKrw(double amount) {
    final intAmount = amount.round();
    final absAmount = intAmount.abs();
    final formatted = absAmount.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
    return intAmount < 0 ? '-$formatted' : formatted;
  }

  String _formatDate(DateTime date) {
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(
            icon,
            size: 20,
            color: context.appTextSecondary,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: context.appTextHint,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: context.appTextPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
