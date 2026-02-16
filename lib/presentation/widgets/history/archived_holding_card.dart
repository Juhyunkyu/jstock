import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/holding.dart';
import '../shared/return_badge.dart';
import '../shared/ticker_logo.dart';

/// 아카이브된 일반 보유 카드 위젯
///
/// CycleStatsCard와 동일한 비주얼 스타일로 완료된 보유를 표시합니다.
class ArchivedHoldingCard extends StatelessWidget {
  final Holding holding;
  final double? realizedReturnPercent;
  final double? realizedPnlKrw;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final bool inGrid;

  const ArchivedHoldingCard({
    super.key,
    required this.holding,
    this.realizedReturnPercent,
    this.realizedPnlKrw,
    this.onTap,
    this.onDelete,
    this.inGrid = false,
  });

  @override
  Widget build(BuildContext context) {
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
                // 헤더: 로고 + 티커 + 이름
                Row(
                  children: [
                    TickerLogo(
                      ticker: holding.ticker,
                      size: 32,
                      borderRadius: 8,
                    ),
                    const SizedBox(width: 8),
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
                        holding.ticker,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: context.appTickerColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        holding.name,
                        style: TextStyle(
                          fontSize: 13,
                          color: context.appTextSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (onDelete != null)
                      GestureDetector(
                        onTap: onDelete,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Icon(
                            Icons.delete_outline,
                            size: 20,
                            color: context.appTextHint,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),

                // 실현손익 + 등락률 배지
                _buildRealizedPnl(context),
                const SizedBox(height: 12),

                // 기간
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _formatDate(holding.startDate),
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
                      _formatDate(holding.updatedAt),
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

  Widget _buildRealizedPnl(BuildContext context) {
    if (realizedPnlKrw == null) {
      return Column(
        children: [
          Text(
            '실현손익',
            style: TextStyle(
              fontSize: 12,
              color: context.appTextHint,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '-',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: context.appTextHint,
            ),
          ),
        ],
      );
    }

    final isProfit = realizedPnlKrw! >= 0;
    final fgColor = isProfit
        ? context.appStockChangePlusFg
        : context.appStockChangeMinusFg;

    return Column(
      children: [
        Text(
          '실현손익',
          style: TextStyle(
            fontSize: 12,
            color: context.appTextHint,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${isProfit ? '+' : ''}${_formatKrw(realizedPnlKrw!)}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: fgColor,
              ),
            ),
            const SizedBox(width: 8),
            ReturnBadge(
              value: realizedReturnPercent,
              size: ReturnBadgeSize.small,
              colorScheme: ReturnBadgeColorScheme.redBlue,
            ),
          ],
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
  }

  String _formatKrw(double amount) {
    final intAmount = amount.round();
    final absAmount = intAmount.abs();
    final formatted = absAmount.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
    return '${intAmount < 0 ? '-' : ''}$formatted\u2009원';
  }
}
