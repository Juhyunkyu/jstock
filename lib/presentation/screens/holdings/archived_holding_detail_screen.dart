import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/holding.dart';
import '../../../data/models/holding_transaction.dart';
import '../../providers/holding_providers.dart';
import '../../providers/providers.dart';
import '../../widgets/shared/info_row.dart';
import '../../../core/utils/krw_formatter.dart';
import '../../../core/utils/number_formatter.dart';
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
              color: context.appAccent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '완료',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: context.appAccent,
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
    final rawDays = (firstDate != null && lastDate != null)
        ? lastDate.difference(firstDate).inDays
        : 0;
    final durationDays = rawDays < 1 ? 1 : rawDays; // 당일 거래 = 최소 1일

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

/// 성과 요약 카드 (다크 컴팩트 — 사이클 완료 카드와 통일)
class _PerformanceSummaryCard extends StatelessWidget {
  final _ArchivedStats stats;

  const _PerformanceSummaryCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final isProfit = stats.realizedPnl >= 0;
    final gradientColors = isProfit
        ? [const Color(0xFF2D1B1B), const Color(0xFF3D1F1F)]
        : [const Color(0xFF1B2230), const Color(0xFF1A2740)];
    final accentColor = isProfit ? AppColors.red500 : AppColors.blue500;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // 헤더 + 금액 한 줄
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '실현손익',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ),
              const Spacer(),
              Text(
                '${isProfit ? '+' : ''}${formatKrwWithComma(stats.realizedPnl.round().toDouble())}원',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${isProfit ? '+' : ''}${stats.returnPercent.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: accentColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 구분선
          Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.08),
          ),
          const SizedBox(height: 10),

          // 총 매수 / 총 매도 / 순 수익
          _buildResultRow('총 매수', formatKrwWithComma(stats.totalBuyKrw.round().toDouble())),
          const SizedBox(height: 4),
          _buildResultRow('총 매도', formatKrwWithComma(stats.totalSellKrw.round().toDouble())),
          const SizedBox(height: 4),
          _buildResultRow(
            '순 수익',
            '${isProfit ? '+' : ''}${formatKrwWithComma(stats.realizedPnl.round().toDouble())}원',
            accentColor: accentColor,
          ),
        ],
      ),
    );
  }

  Widget _buildResultRow(String label, String value, {Color? accentColor}) {
    final isHighlight = accentColor != null;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isHighlight
                ? Colors.white.withValues(alpha: 0.7)
                : Colors.white.withValues(alpha: 0.4),
            fontWeight: isHighlight ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            color: isHighlight ? accentColor : Colors.white.withValues(alpha: 0.6),
            fontWeight: isHighlight ? FontWeight.w600 : FontWeight.normal,
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
            value: '매수 ${formatShares(stats.totalBuyShares)}주 / 매도 ${formatShares(stats.totalSellShares)}주',
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
                ? '${dateFormat.format(stats.firstDate!)} ~ ${dateFormat.format(stats.lastDate!)} (${stats.durationDays}일)'
                : '-',
          ),
        ],
      ),
    );
  }

}
