import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/holding_transaction.dart';

/// 보유 종목 거래 내역 카드 위젯
///
/// 개별 매수/매도 거래 내역을 표시합니다.
class HoldingTransactionCard extends StatelessWidget {
  /// 거래 내역
  final HoldingTransaction transaction;

  /// 탭 콜백
  final VoidCallback? onTap;

  const HoldingTransactionCard({
    super.key,
    required this.transaction,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isBuy = transaction.type == HoldingTransactionType.buy;
    final typeColor = isBuy ? AppColors.blue600 : AppColors.amber600;
    final typeIcon = isBuy ? Icons.add_circle_outline : Icons.remove_circle_outline;
    final typeLabel = isBuy ? '매수' : '매도';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.appSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: context.appDivider,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // 거래 유형 아이콘
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: typeColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                typeIcon,
                color: typeColor,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),

            // 거래 정보
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        typeLabel,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: typeColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        transaction.ticker,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: context.appTextPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDateTime(transaction.date),
                    style: TextStyle(
                      fontSize: 12,
                      color: context.appTextSecondary,
                    ),
                  ),
                ],
              ),
            ),

            // 거래 금액
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatKrw(transaction.amountKrw),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: context.appTextPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${transaction.shares.toStringAsFixed(2)}주 @ \$${transaction.price.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: context.appTextSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime date) {
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
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

/// 거래 내역 목록 헤더
class TransactionListHeader extends StatelessWidget {
  final String title;
  final int count;
  final VoidCallback? onViewAll;

  const TransactionListHeader({
    super.key,
    required this.title,
    required this.count,
    this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: context.appTextPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: context.appDivider,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count건',
                  style: TextStyle(
                    fontSize: 11,
                    color: context.appTextSecondary,
                  ),
                ),
              ),
            ],
          ),
          if (onViewAll != null)
            GestureDetector(
              onTap: onViewAll,
              child: const Text(
                '전체보기',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
