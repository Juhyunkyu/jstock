import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/krw_formatter.dart';
import '../../../data/models/holding.dart';
import '../shared/ticker_logo.dart';

/// 아카이브된 일반 보유 카드 위젯 — 2줄 컴팩트
///
/// 1줄: TickerLogo + 티커 + 종목명 + 날짜 + 삭제
/// 2줄: 투자(축약) + 회수(축약) + 손익(금액+%) + 환전 배지
class ArchivedHoldingCard extends StatelessWidget {
  final Holding holding;
  final double? realizedReturnPercent;
  final double? realizedPnlKrw;
  final double? totalBuyKrw;
  final double? totalSellKrw;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onSettleExchange;
  final VoidCallback? onUnsettleExchange;
  final bool inGrid;

  const ArchivedHoldingCard({
    super.key,
    required this.holding,
    this.realizedReturnPercent,
    this.realizedPnlKrw,
    this.totalBuyKrw,
    this.totalSellKrw,
    this.onTap,
    this.onDelete,
    this.onSettleExchange,
    this.onUnsettleExchange,
    this.inGrid = false,
  });

  @override
  Widget build(BuildContext context) {
    final buyKrw = totalBuyKrw ?? 0;
    final sellKrw = totalSellKrw ?? 0;

    // 환전 확정 시 확정환율 기준 회수금 재계산은 history_screen에서 처리
    // 여기서는 전달받은 값 사용
    final pnl = realizedPnlKrw ?? 0;
    final returnPct = realizedReturnPercent ?? 0;
    final isProfit = pnl >= 0;
    final profitColor = isProfit ? AppColors.red500 : AppColors.blue500;
    final sign = isProfit ? '+' : '';

    return Container(
      margin: inGrid
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: context.isDarkMode
                ? Colors.white.withValues(alpha: 0.03)
                : Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(
              children: [
                // 1줄: TickerLogo + 티커 + 종목명 + 날짜 + 삭제
                Row(
                  children: [
                    TickerLogo(ticker: holding.ticker, size: 24, borderRadius: 6),
                    const SizedBox(width: 6),
                    Text(
                      holding.ticker,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: context.appTickerColor,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        holding.name,
                        style: TextStyle(fontSize: 12, color: context.appTextSecondary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${formatDateShort(holding.startDate)}~${formatDateShort(holding.updatedAt)}',
                      style: TextStyle(fontSize: 11, color: context.appTextHint),
                    ),
                    if (onDelete != null) ...[
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: onDelete,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 2),
                          child: Icon(Icons.delete_outline, size: 18, color: context.appTextHint),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                // 2줄: 투자(축약) + 회수(축약) + 손익(금액+%) + 환전 배지
                Row(
                  children: [
                    Text(
                      '투자 ${formatCashShort(buyKrw)}',
                      style: TextStyle(fontSize: 12, color: context.appTextSecondary),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '회수 ${formatCashShort(sellKrw)}',
                      style: TextStyle(fontSize: 12, color: context.appTextSecondary),
                    ),
                    const Spacer(),
                    if (realizedPnlKrw != null)
                      Text(
                        '$sign${formatKrw(pnl)}($sign${returnPct.toStringAsFixed(1)}%)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: profitColor,
                        ),
                      )
                    else
                      Text(
                        '-',
                        style: TextStyle(fontSize: 12, color: context.appTextHint),
                      ),
                    const SizedBox(width: 6),
                    _buildExchangeBadge(context),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExchangeBadge(BuildContext context) {
    if (holding.isExchangeSettled) {
      return GestureDetector(
        onTap: onUnsettleExchange,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.green600.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '\u2705완료',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.green600),
          ),
        ),
      );
    }
    return GestureDetector(
      onTap: onSettleExchange,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.amber500.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          '\uD83D\uDCB1환전',
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.amber500),
        ),
      ),
    );
  }
}
