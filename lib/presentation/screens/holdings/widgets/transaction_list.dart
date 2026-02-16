import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/holding.dart';
import '../../../providers/holding_providers.dart';
import 'transaction_card.dart';

/// 거래 내역 리스트 헤더
class TransactionListHeader extends ConsumerWidget {
  final String holdingId;

  const TransactionListHeader({super.key, required this.holdingId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactions = ref.watch(holdingTransactionsProvider(holdingId));
    return _buildHeader(transactions.length, context);
  }

  Widget _buildHeader(int count, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(
                '거래 내역',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: context.appTextPrimary,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: context.appBorder,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: context.appTextSecondary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 거래 내역 리스트 섹션
class TransactionListSection extends ConsumerWidget {
  final String holdingId;
  final bool readOnly;

  const TransactionListSection({super.key, required this.holdingId, this.readOnly = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactions = ref.watch(holdingTransactionsProvider(holdingId));
    final holding = ref.watch(holdingByIdProvider(holdingId));

    if (transactions.isEmpty) {
      return SliverToBoxAdapter(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: context.appSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.appBorder),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.isDarkMode ? context.appSurface : AppColors.gray100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.receipt_long_outlined,
                  size: 32,
                  color: context.appTextHint,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '거래 내역이 없습니다',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: context.appTextSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '아래 버튼을 눌러 매수/매도 거래를 기록해보세요',
                style: TextStyle(fontSize: 13, color: context.appTextHint),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // 날짜 기준 내림차순 정렬
    final sortedTransactions = List.from(transactions)
      ..sort((a, b) => b.date.compareTo(a.date));

    // Find the earliest buy transaction ID
    String? earliestBuyId;
    DateTime? earliestBuyDate;
    for (final tx in sortedTransactions) {
      if (tx.isBuy) {
        if (earliestBuyDate == null || tx.date.isBefore(earliestBuyDate)) {
          earliestBuyDate = tx.date;
          earliestBuyId = tx.id;
        }
      }
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final transaction = sortedTransactions[index];
          return TransactionCard(
            transaction: transaction,
            holding: holding,
            isFirst: index == 0,
            isLast: index == sortedTransactions.length - 1,
            isEarliestBuy: transaction.id == earliestBuyId,
            readOnly: readOnly,
          );
        },
        childCount: sortedTransactions.length,
      ),
    );
  }
}
