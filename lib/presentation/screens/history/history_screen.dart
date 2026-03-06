import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/holding.dart';
import '../../../data/models/holding_transaction.dart';
import '../../../routes/app_router.dart';
import '../../providers/providers.dart';
import '../../../core/utils/krw_formatter.dart';
import '../../widgets/common/responsive_grid.dart';
import '../../widgets/history/cycle_stats_card.dart';
import '../../widgets/history/archived_holding_card.dart';

/// 거래내역 화면 — 과거 거래기록 (완료된 알파사이클 + 아카이브된 일반보유)
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final completedCycles = ref.watch(completedCyclesProvider);
    final archivedHoldings = ref.watch(archivedHoldingsProvider);
    final prices = ref.watch(currentPricesProvider);

    final hasData = completedCycles.isNotEmpty || archivedHoldings.isNotEmpty;

    return Scaffold(
      backgroundColor: context.appBackground,
      appBar: AppBar(
        toolbarHeight: 64,
        title: const Text('과거 거래기록'),
        backgroundColor: context.appBackground,
        elevation: 0,
      ),
      body: !hasData
          ? _buildEmptyState(context)
          : Builder(
              builder: (context) {
                final useGrid = ResponsiveGrid.shouldUseGrid(context);

                if (useGrid) {
                  final itemW = ResponsiveGrid.gridItemWidth(context);
                  return ListView(
                    padding: const EdgeInsets.only(top: 8, bottom: 24),
                    children: [
                      // 합계 요약 카드
                      _buildSummaryCard(context, ref),

                      // 섹션 1: 완료된 알파 사이클
                      if (completedCycles.isNotEmpty) ...[
                        _SectionHeader(
                          title: '완료된 알파 사이클',
                          count: completedCycles.length,
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: ResponsiveGrid.horizontalPadding,
                          ),
                          child: Wrap(
                            spacing: ResponsiveGrid.spacing,
                            runSpacing: ResponsiveGrid.runSpacing,
                            children: completedCycles.map((cycle) {
                              final tradeCount = ref.watch(tradeCountForCycleProvider(cycle.id));
                              final finalPrice = prices[cycle.ticker] ?? cycle.averagePrice;
                              return SizedBox(
                                width: itemW,
                                child: CycleStatsCard(
                                  cycle: cycle,
                                  finalPrice: finalPrice,
                                  tradeCount: tradeCount,
                                  inGrid: true,
                                  onTap: () => context.push('${AppRouter.stocksDetail}/${cycle.id}'),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],

                      // 구분선
                      if (completedCycles.isNotEmpty && archivedHoldings.isNotEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Divider(),
                        ),

                      // 섹션 2: 완료된 일반 보유
                      if (archivedHoldings.isNotEmpty) ...[
                        _SectionHeader(
                          title: '완료된 일반 보유',
                          count: archivedHoldings.length,
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: ResponsiveGrid.horizontalPadding,
                          ),
                          child: Wrap(
                            spacing: ResponsiveGrid.spacing,
                            runSpacing: ResponsiveGrid.runSpacing,
                            children: archivedHoldings.map((holding) {
                              final transactions = ref.watch(holdingTransactionsProvider(holding.id));
                              final result = _calcRealizedResult(transactions);
                              return SizedBox(
                                width: itemW,
                                child: ArchivedHoldingCard(
                                  holding: holding,
                                  realizedReturnPercent: result?.percent,
                                  realizedPnlKrw: result?.pnlKrw,
                                  inGrid: true,
                                  onTap: () => context.push('/holdings/${holding.id}/archived'),
                                  onDelete: () => _confirmDelete(context, ref, holding),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ],
                  );
                }

                // 모바일: 기존 레이아웃
                return ListView(
                  padding: const EdgeInsets.only(top: 8, bottom: 24),
                  children: [
                    // 합계 요약 카드
                    _buildSummaryCard(context, ref),

                    // 섹션 1: 완료된 알파 사이클
                    if (completedCycles.isNotEmpty) ...[
                      _SectionHeader(
                        title: '완료된 알파 사이클',
                        count: completedCycles.length,
                      ),
                      ...completedCycles.map((cycle) {
                        final tradeCount = ref.watch(tradeCountForCycleProvider(cycle.id));
                        final finalPrice = prices[cycle.ticker] ?? cycle.averagePrice;
                        return CycleStatsCard(
                          cycle: cycle,
                          finalPrice: finalPrice,
                          tradeCount: tradeCount,
                          onTap: () => context.push('${AppRouter.stocksDetail}/${cycle.id}'),
                        );
                      }),
                    ],

                    // 구분선
                    if (completedCycles.isNotEmpty && archivedHoldings.isNotEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Divider(),
                      ),

                    // 섹션 2: 완료된 일반 보유
                    if (archivedHoldings.isNotEmpty) ...[
                      _SectionHeader(
                        title: '완료된 일반 보유',
                        count: archivedHoldings.length,
                      ),
                      ...archivedHoldings.map((holding) {
                        final transactions = ref.watch(holdingTransactionsProvider(holding.id));
                        final result = _calcRealizedResult(transactions);
                        return ArchivedHoldingCard(
                          holding: holding,
                          realizedReturnPercent: result?.percent,
                          realizedPnlKrw: result?.pnlKrw,
                          onTap: () => context.push('/holdings/${holding.id}/archived'),
                          onDelete: () => _confirmDelete(context, ref, holding),
                        );
                      }),
                    ],
                  ],
                );
              },
            ),
    );
  }

  ({double percent, double pnlKrw})? _calcRealizedResult(List<HoldingTransaction> transactions) {
    if (transactions.isEmpty) return null;
    double totalBuyKrw = 0;
    double totalSellKrw = 0;
    for (final tx in transactions) {
      if (tx.isBuy) {
        totalBuyKrw += tx.amountKrw;
      } else {
        totalSellKrw += tx.amountKrw;
      }
    }
    if (totalBuyKrw <= 0) return null;
    final pnl = totalSellKrw - totalBuyKrw;
    final percent = (pnl / totalBuyKrw) * 100;
    return (percent: percent, pnlKrw: pnl);
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, Holding holding) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('거래기록 삭제'),
        content: Text('${holding.ticker} (${holding.name})의 거래기록을 삭제하시겠습니까?\n\n이 작업은 되돌릴 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(holdingListProvider.notifier).deleteHolding(holding.id);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${holding.ticker} 거래기록이 삭제되었습니다')),
              );
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.red500),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  /// 합계 요약 카드 (총 투자, 총 회수, 총 손익)
  Widget _buildSummaryCard(BuildContext context, WidgetRef ref) {
    final completedCycles = ref.watch(completedCyclesProvider);
    final archivedHoldings = ref.watch(archivedHoldingsProvider);

    double totalInvested = 0;
    double totalRecovered = 0;

    // 완료된 알파 사이클: seedAmount=투자, remainingCash=회수
    for (final cycle in completedCycles) {
      totalInvested += cycle.seedAmount;
      totalRecovered += cycle.remainingCash;
    }

    // 완료된 일반 보유: totalBuyKrw=투자, totalSellKrw=회수
    for (final holding in archivedHoldings) {
      final transactions = ref.watch(holdingTransactionsProvider(holding.id));
      double buyKrw = 0;
      double sellKrw = 0;
      for (final tx in transactions) {
        if (tx.isBuy) {
          buyKrw += tx.amountKrw;
        } else {
          sellKrw += tx.amountKrw;
        }
      }
      totalInvested += buyKrw;
      totalRecovered += sellKrw;
    }

    if (totalInvested <= 0) return const SizedBox.shrink();

    final totalPnl = totalRecovered - totalInvested;
    final returnRate = (totalPnl / totalInvested) * 100;
    final isProfit = totalPnl >= 0;
    final profitColor = isProfit ? AppColors.green500 : AppColors.red500;
    final sign = isProfit ? '+' : '';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.appCardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.appBorder),
        ),
        child: Column(
          children: [
            _summaryRow(context, '총 투자', formatKrw(totalInvested), context.appTextPrimary),
            const SizedBox(height: 8),
            _summaryRow(context, '총 회수', formatKrw(totalRecovered), context.appTextPrimary),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Divider(color: context.appDivider, height: 1),
            ),
            _summaryRow(
              context,
              '총 손익',
              '$sign${formatKrw(totalPnl)}($sign${returnRate.toStringAsFixed(2)}%)',
              profitColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(BuildContext context, String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: context.appTextSecondary,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.archive_outlined,
            size: 64,
            color: context.appBorder,
          ),
          const SizedBox(height: 16),
          Text(
            '과거 거래기록이 없습니다',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: context.appTextSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '전량 매도 후 "완료(기록)" 버튼을 누르면\n여기에 표시됩니다',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: context.appTextHint,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;

  const _SectionHeader({
    required this.title,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: context.appTextPrimary,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: context.appTickerColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: context.appTickerColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
