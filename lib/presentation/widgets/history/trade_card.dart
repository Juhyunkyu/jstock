import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/trade.dart';

/// 거래 카드 위젯
class TradeCard extends StatelessWidget {
  final Trade trade;
  final VoidCallback? onTap;

  const TradeCard({
    super.key,
    required this.trade,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: context.isDarkMode
                ? Colors.white.withValues(alpha: 0.03)
                : Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // 거래 유형 아이콘
                _buildActionIcon(),
                const SizedBox(width: 12),

                // 거래 정보
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 상단: 거래 유형 + 종목
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: _getActionColor().withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              trade.actionDisplayName,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _getActionColor(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            trade.ticker,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: context.appTickerColor,
                            ),
                          ),
                          if (!trade.isExecuted) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.amber100,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                '미체결',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppColors.amber700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),

                      // 하단: 날짜 + 손실률/수익률
                      Row(
                        children: [
                          Text(
                            _formatDate(trade.date),
                            style: TextStyle(
                              fontSize: 12,
                              color: context.appTextHint,
                            ),
                          ),
                          const SizedBox(width: 12),
                          if (trade.isBuy)
                            Text(
                              '손실률 ${trade.lossRate.toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontSize: 12,
                                color: trade.lossRate < 0
                                    ? AppColors.red500
                                    : AppColors.textSecondary,
                              ),
                            )
                          else
                            Text(
                              '수익률 +${trade.returnRate.toStringAsFixed(1)}%',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.green500,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                // 거래 금액/수량
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '\$${trade.price.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: context.appTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${trade.shares.toStringAsFixed(2)}주',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.appTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatKrw(trade.amount),
                      style: TextStyle(
                        fontSize: 11,
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

  Widget _buildActionIcon() {
    IconData iconData;
    switch (trade.action) {
      case TradeAction.initialBuy:
        iconData = Icons.play_circle_outline_rounded;
        break;
      case TradeAction.weightedBuy:
        iconData = Icons.add_circle_outline_rounded;
        break;
      case TradeAction.panicBuy:
        iconData = Icons.warning_amber_rounded;
        break;
      case TradeAction.takeProfit:
        iconData = Icons.monetization_on_outlined;
        break;
    }

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: _getActionColor().withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        iconData,
        color: _getActionColor(),
        size: 24,
      ),
    );
  }

  Color _getActionColor() {
    switch (trade.action) {
      case TradeAction.initialBuy:
        return AppColors.initialBuy;
      case TradeAction.weightedBuy:
        return AppColors.weightedBuy;
      case TradeAction.panicBuy:
        return AppColors.panicBuy;
      case TradeAction.takeProfit:
        return AppColors.takeProfit;
    }
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
    return intAmount < 0 ? '-$formatted원' : '$formatted원';
  }
}

/// 거래 카드 컴팩트 버전 (목록용)
class TradeCardCompact extends StatelessWidget {
  final Trade trade;
  final VoidCallback? onTap;

  const TradeCardCompact({
    super.key,
    required this.trade,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: _getActionColor().withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            trade.actionEmoji,
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ),
      title: Row(
        children: [
          Text(
            trade.actionDisplayName,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _getActionColor(),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            trade.ticker,
            style: TextStyle(
              fontSize: 14,
              color: context.appTickerColor,
            ),
          ),
        ],
      ),
      subtitle: Text(
        _formatDate(trade.date),
        style: TextStyle(
          fontSize: 12,
          color: context.appTextHint,
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '\$${trade.price.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: context.appTextPrimary,
            ),
          ),
          Text(
            '${trade.shares.toStringAsFixed(2)}주',
            style: TextStyle(
              fontSize: 12,
              color: context.appTextHint,
            ),
          ),
        ],
      ),
    );
  }

  Color _getActionColor() {
    switch (trade.action) {
      case TradeAction.initialBuy:
        return AppColors.initialBuy;
      case TradeAction.weightedBuy:
        return AppColors.weightedBuy;
      case TradeAction.panicBuy:
        return AppColors.panicBuy;
      case TradeAction.takeProfit:
        return AppColors.takeProfit;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}';
  }
}
