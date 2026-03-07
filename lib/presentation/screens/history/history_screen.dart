import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/cycle.dart';
import '../../../data/models/holding.dart';
import '../../../data/models/holding_transaction.dart';
import '../../providers/providers.dart';
import '../../../core/utils/krw_formatter.dart';
import '../../widgets/common/responsive_grid.dart';
import '../../widgets/cycle/strategy_badge.dart';
import '../../widgets/history/archived_holding_card.dart';
import '../../widgets/shared/ticker_logo.dart';
import '../../widgets/shared/return_badge.dart';

/// 거래내역 화면 — 과거 거래기록 (아카이브된 일반보유)
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final archivedHoldings = ref.watch(archivedHoldingsProvider);
    final completedCycles = ref.watch(completedCyclesProvider);

    final hasData = archivedHoldings.isNotEmpty || completedCycles.isNotEmpty;

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

                      // 완료된 사이클
                      if (completedCycles.isNotEmpty) ...[
                        _SectionHeader(
                          title: '완료된 사이클',
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
                              return SizedBox(
                                width: itemW,
                                child: _CompletedCycleCard(
                                  cycle: cycle,
                                  inGrid: true,
                                  onTap: () => context.push('/stocks/detail/${cycle.id}'),
                                  onDelete: () => _confirmDeleteCycle(context, ref, cycle),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],

                      // 완료된 일반 보유
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

                    // 완료된 사이클
                    if (completedCycles.isNotEmpty) ...[
                      _SectionHeader(
                        title: '완료된 사이클',
                        count: completedCycles.length,
                      ),
                      ...completedCycles.map((cycle) => _CompletedCycleCard(
                        cycle: cycle,
                        onTap: () => context.push('/stocks/detail/${cycle.id}'),
                        onDelete: () => _confirmDeleteCycle(context, ref, cycle),
                      )),
                    ],

                    // 완료된 일반 보유
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
    final archivedHoldings = ref.watch(archivedHoldingsProvider);
    final completedCycles = ref.watch(completedCyclesProvider);

    double totalInvested = 0;
    double totalRecovered = 0;

    // 완료된 사이클: seedAmount=투자, remainingCash=회수 (완료 시 주식=0)
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

  void _confirmDeleteCycle(BuildContext context, WidgetRef ref, Cycle cycle) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('사이클 기록 삭제'),
        content: Text('${cycle.ticker} (${cycle.name}) 사이클 기록을 삭제하시겠습니까?\n\n이 작업은 되돌릴 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(cycleListProvider.notifier).deleteCycle(cycle.id);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${cycle.ticker} 사이클 기록이 삭제되었습니다')),
              );
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.red500),
            child: const Text('삭제'),
          ),
        ],
      ),
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

class _CompletedCycleCard extends StatelessWidget {
  final Cycle cycle;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final bool inGrid;

  const _CompletedCycleCard({
    required this.cycle,
    this.onTap,
    this.onDelete,
    this.inGrid = false,
  });

  @override
  Widget build(BuildContext context) {
    final pnl = cycle.remainingCash - cycle.seedAmount;
    final returnRate = cycle.seedAmount > 0
        ? (pnl / cycle.seedAmount) * 100
        : 0.0;
    final isProfit = pnl >= 0;
    final fgColor = isProfit
        ? context.appStockChangePlusFg
        : context.appStockChangeMinusFg;

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
                // 헤더: 로고 + 티커 + 이름 + 전략 배지
                Row(
                  children: [
                    TickerLogo(
                      ticker: cycle.ticker,
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
                        cycle.ticker,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: context.appTickerColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    StrategyBadge(strategyType: cycle.strategyType),
                    const Spacer(),
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${isProfit ? '+' : ''}${formatKrw(pnl)}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: fgColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ReturnBadge(
                      value: returnRate,
                      size: ReturnBadgeSize.small,
                      colorScheme: ReturnBadgeColorScheme.redBlue,
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // 시드 금액
                Center(
                  child: Text(
                    '시드 ${formatKrw(cycle.seedAmount)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.appTextHint,
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // 기간
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
                      _formatDate(cycle.updatedAt),
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

  String _formatDate(DateTime date) {
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
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
