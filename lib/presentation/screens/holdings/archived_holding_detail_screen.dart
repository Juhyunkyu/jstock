import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/holding.dart';
import '../../../data/models/holding_transaction.dart';
import '../../providers/holding_providers.dart';
import '../../providers/providers.dart';
import 'widgets/holding_info_card.dart';
import 'widgets/profit_loss_section.dart';
import 'widgets/transaction_list.dart';

/// 아카이브된 보유 상세 화면 (읽기 전용)
///
/// 전량 매도 후 아카이브 처리된 일반 보유 종목의 확정 실적을 표시합니다.
class ArchivedHoldingDetailScreen extends ConsumerWidget {
  final String holdingId;

  const ArchivedHoldingDetailScreen({super.key, required this.holdingId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final holding = ref.watch(holdingByIdProvider(holdingId));
    final transactions = ref.watch(holdingTransactionsProvider(holdingId));

    if (holding == null) {
      return Scaffold(
        backgroundColor: context.appBackground,
        appBar: AppBar(
          title: const Text('보유 상세'),
          backgroundColor: context.appBackground,
        ),
        body: const Center(
          child: Text('보유 정보를 찾을 수 없습니다'),
        ),
      );
    }

    // 거래 내역에서 통계 계산
    final stats = _calculateStats(holding, transactions);

    return Scaffold(
      backgroundColor: context.appBackground,
      appBar: AppBar(
        backgroundColor: context.appBackground,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          color: context.appTextPrimary,
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              holding.ticker,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: context.appTextPrimary,
              ),
            ),
            Text(
              holding.name,
              style: TextStyle(
                fontSize: 12,
                color: context.appTextSecondary,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: context.isDarkMode
                  ? AppColors.secondary.withValues(alpha: 0.2)
                  : AppColors.secondary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '완료',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.secondary,
              ),
            ),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              children: [
                const SizedBox(height: 10),

                // 성과 요약 카드
                _PerformanceSummaryCard(stats: stats),
                const SizedBox(height: 10),

                // 투자 정보 카드
                _InvestmentInfoCard(holding: holding, stats: stats),
                const SizedBox(height: 16),

                // 거래 내역 헤더
                TransactionListHeader(holdingId: holdingId),
                const SizedBox(height: 6),
              ],
            ),
          ),

          // 거래 내역 리스트 (읽기 전용)
          TransactionListSection(holdingId: holdingId, readOnly: true),

          // 하단 여백
          const SliverToBoxAdapter(
            child: SizedBox(height: 24),
          ),
        ],
      ),
    );
  }

  _ArchivedStats _calculateStats(Holding holding, List<HoldingTransaction> transactions) {
    double totalBuyKrw = 0;
    double totalSellKrw = 0;
    double totalBuyUsd = 0;
    double totalSellUsd = 0;
    double totalBuyShares = 0;
    double totalSellShares = 0;
    double realizedPnl = 0;
    DateTime? firstDate;
    DateTime? lastDate;
    double avgExchangeRate = 0;
    double totalExchangeWeighted = 0;

    for (final tx in transactions) {
      if (tx.isBuy) {
        totalBuyKrw += tx.amountKrw;
        totalBuyUsd += tx.amountUsd;
        totalBuyShares += tx.shares;
        totalExchangeWeighted += tx.exchangeRate * tx.amountUsd;
      } else {
        totalSellKrw += tx.amountKrw;
        totalSellUsd += tx.amountUsd;
        totalSellShares += tx.shares;
        if (tx.realizedPnlKrw != null) {
          realizedPnl += tx.realizedPnlKrw!;
        }
      }

      if (firstDate == null || tx.date.isBefore(firstDate)) {
        firstDate = tx.date;
      }
      if (lastDate == null || tx.date.isAfter(lastDate)) {
        lastDate = tx.date;
      }
    }

    // realizedPnl이 0이면 fallback: totalSellKrw - totalBuyKrw
    if (realizedPnl == 0 && totalSellKrw > 0) {
      realizedPnl = totalSellKrw - totalBuyKrw;
    }

    final returnPercent = totalBuyKrw > 0 ? (realizedPnl / totalBuyKrw) * 100 : 0.0;
    final avgBuyPrice = totalBuyShares > 0 ? totalBuyUsd / totalBuyShares : 0.0;
    final avgSellPrice = totalSellShares > 0 ? totalSellUsd / totalSellShares : 0.0;
    final durationDays = (firstDate != null && lastDate != null)
        ? lastDate.difference(firstDate).inDays
        : 0;

    if (totalBuyUsd > 0) {
      avgExchangeRate = totalExchangeWeighted / totalBuyUsd;
    }

    return _ArchivedStats(
      totalBuyKrw: totalBuyKrw,
      totalSellKrw: totalSellKrw,
      realizedPnl: realizedPnl,
      returnPercent: returnPercent,
      avgBuyPrice: avgBuyPrice,
      avgSellPrice: avgSellPrice,
      totalBuyShares: totalBuyShares,
      totalSellShares: totalSellShares,
      durationDays: durationDays,
      avgExchangeRate: avgExchangeRate,
      firstDate: firstDate,
      lastDate: lastDate,
      totalTransactions: transactions.length,
    );
  }
}

class _ArchivedStats {
  final double totalBuyKrw;
  final double totalSellKrw;
  final double realizedPnl;
  final double returnPercent;
  final double avgBuyPrice;
  final double avgSellPrice;
  final double totalBuyShares;
  final double totalSellShares;
  final int durationDays;
  final double avgExchangeRate;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final int totalTransactions;

  const _ArchivedStats({
    required this.totalBuyKrw,
    required this.totalSellKrw,
    required this.realizedPnl,
    required this.returnPercent,
    required this.avgBuyPrice,
    required this.avgSellPrice,
    required this.totalBuyShares,
    required this.totalSellShares,
    required this.durationDays,
    required this.avgExchangeRate,
    required this.firstDate,
    required this.lastDate,
    required this.totalTransactions,
  });
}

/// 성과 요약 카드 (그라데이션)
class _PerformanceSummaryCard extends StatelessWidget {
  final _ArchivedStats stats;

  const _PerformanceSummaryCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final isProfit = stats.realizedPnl >= 0;
    final pnlColor = isProfit ? AppColors.stockUp : AppColors.stockDown;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: context.isDarkMode
              ? [const Color(0xFF1A1F2E), const Color(0xFF0F1923)]
              : [const Color(0xFF2C3E50), const Color(0xFF1A252F)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: context.isDarkMode
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        children: [
          // 실현손익 (큰 글씨)
          Text(
            '실현손익',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${isProfit ? '+' : ''}${formatKrwWithComma(stats.realizedPnl)}',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: pnlColor,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: pnlColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${isProfit ? '+' : ''}${stats.returnPercent.toStringAsFixed(2)}%',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: pnlColor,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Divider(color: Colors.white.withValues(alpha: 0.15)),
          const SizedBox(height: 12),
          // 총 투자금 / 총 회수금
          Row(
            children: [
              Expanded(
                child: _SummaryItem(
                  label: '총 투자금',
                  value: formatKrwWithComma(stats.totalBuyKrw),
                ),
              ),
              Container(
                width: 1,
                height: 36,
                color: Colors.white.withValues(alpha: 0.15),
              ),
              Expanded(
                child: _SummaryItem(
                  label: '총 회수금',
                  value: formatKrwWithComma(stats.totalSellKrw),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

/// 투자 정보 카드
class _InvestmentInfoCard extends StatelessWidget {
  final Holding holding;
  final _ArchivedStats stats;

  const _InvestmentInfoCard({required this.holding, required this.stats});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy.MM.dd');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: context.isDarkMode
                ? Colors.white.withValues(alpha: 0.03)
                : Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          InfoRow(
            label: '보유기간',
            value: '${stats.durationDays}일',
          ),
          const Divider(height: 16),
          InfoRow(
            label: '평균매수가',
            value: '\$${stats.avgBuyPrice.toStringAsFixed(2)}',
          ),
          const Divider(height: 16),
          InfoRow(
            label: '평균매도가',
            value: '\$${stats.avgSellPrice.toStringAsFixed(2)}',
          ),
          const Divider(height: 16),
          InfoRow(
            label: '총 거래량',
            value: '매수 ${_formatShares(stats.totalBuyShares)} / 매도 ${_formatShares(stats.totalSellShares)}',
          ),
          const Divider(height: 16),
          InfoRow(
            label: '평균 매입환율',
            value: '₩${stats.avgExchangeRate.toStringAsFixed(0)} / \$1',
          ),
          const Divider(height: 16),
          InfoRow(
            label: '투자 기간',
            value: stats.firstDate != null && stats.lastDate != null
                ? '${dateFormat.format(stats.firstDate!)} → ${dateFormat.format(stats.lastDate!)}'
                : '-',
          ),
        ],
      ),
    );
  }

  String _formatShares(double shares) {
    if (shares == shares.roundToDouble()) {
      return '${shares.toInt()}주';
    }
    return '${shares.toStringAsFixed(2)}주';
  }
}
