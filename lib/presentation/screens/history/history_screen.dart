import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/cycle.dart';
import '../../../data/models/holding.dart';
import '../../../data/models/holding_transaction.dart';
import '../../providers/providers.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/krw_formatter.dart';
import '../../widgets/common/responsive_grid.dart';
import '../../widgets/cycle/strategy_badge.dart';
import '../../widgets/history/archived_holding_card.dart';
import '../../widgets/shared/ticker_logo.dart';
import '../../widgets/common/top_toast.dart';

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
                                  onSettleExchange: () => _showExchangeSettleDialog(context, ref, cycle: cycle),
                                  onUnsettleExchange: () => _unsettleCycleExchange(context, ref, cycle),
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
                                  totalBuyKrw: result?.totalBuyKrw,
                                  totalSellKrw: result?.totalSellKrw,
                                  inGrid: true,
                                  onTap: () => context.push('/holdings/${holding.id}/archived'),
                                  onDelete: () => _confirmDelete(context, ref, holding),
                                  onSettleExchange: () => _showExchangeSettleDialog(context, ref, holding: holding),
                                  onUnsettleExchange: () => _unsettleHoldingExchange(context, ref, holding),
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
                        onSettleExchange: () => _showExchangeSettleDialog(context, ref, cycle: cycle),
                        onUnsettleExchange: () => _unsettleCycleExchange(context, ref, cycle),
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
                          totalBuyKrw: result?.totalBuyKrw,
                          totalSellKrw: result?.totalSellKrw,
                          onTap: () => context.push('/holdings/${holding.id}/archived'),
                          onDelete: () => _confirmDelete(context, ref, holding),
                          onSettleExchange: () => _showExchangeSettleDialog(context, ref, holding: holding),
                          onUnsettleExchange: () => _unsettleHoldingExchange(context, ref, holding),
                        );
                      }),
                    ],
                  ],
                );
              },
            ),
    );
  }

  ({double percent, double pnlKrw, double totalBuyKrw, double totalSellKrw})? _calcRealizedResult(List<HoldingTransaction> transactions) {
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
    return (percent: percent, pnlKrw: pnl, totalBuyKrw: totalBuyKrw, totalSellKrw: totalSellKrw);
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
              showTopToast(context, '${holding.ticker} 거래기록이 삭제되었습니다');
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.red500),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  /// 합계 요약 카드 (2줄 컴팩트: 총 투자 + 총 손익/환율)
  Widget _buildSummaryCard(BuildContext context, WidgetRef ref) {
    final archivedHoldings = ref.watch(archivedHoldingsProvider);
    final completedCycles = ref.watch(completedCyclesProvider);
    final liveExchangeRate = ref.watch(currentExchangeRateProvider);

    double totalInvested = 0;
    double totalRecovered = 0;
    int unsettledCount = 0;

    // 완료된 사이클
    for (final cycle in completedCycles) {
      final result = ref.watch(cycleRealizedPnlProvider(cycle.id));
      if (result != null) {
        totalInvested += result.totalBuyKrw;
        if (cycle.isExchangeSettled) {
          // 확정: 매도 USD x 확정환율
          totalRecovered += cycle.totalSellUsd * cycle.settledExchangeRate;
        } else {
          totalRecovered += result.totalSellKrw;
          unsettledCount++;
        }
      }
    }

    // 완료된 일반 보유
    for (final holding in archivedHoldings) {
      final transactions = ref.watch(holdingTransactionsProvider(holding.id));
      double buyKrw = 0;
      double sellKrw = 0;
      double sellUsd = 0;
      for (final tx in transactions) {
        if (tx.isBuy) {
          buyKrw += tx.amountKrw;
        } else {
          sellKrw += tx.amountKrw;
          sellUsd += tx.price * tx.shares;
        }
      }
      totalInvested += buyKrw;
      if (holding.isExchangeSettled) {
        totalRecovered += sellUsd * holding.settledExchangeRate;
      } else {
        totalRecovered += sellKrw;
        unsettledCount++;
      }
    }

    if (totalInvested <= 0) return const SizedBox.shrink();

    final totalPnl = totalRecovered - totalInvested;
    final returnRate = (totalPnl / totalInvested) * 100;
    final isProfit = totalPnl >= 0;
    final profitColor = isProfit ? AppColors.red500 : AppColors.blue500;
    final sign = isProfit ? '+' : '';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: context.appCardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.appBorder),
        ),
        child: Column(
          children: [
            // 1줄: 총 투자
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '총 투자',
                  style: TextStyle(fontSize: 13, color: context.appTextSecondary),
                ),
                Text(
                  formatKrw(totalInvested),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: context.appTextPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // 2줄: 총 손익 + 환율
            Row(
              children: [
                Text(
                  '총 손익',
                  style: TextStyle(fontSize: 13, color: context.appTextSecondary),
                ),
                const Spacer(),
                Text(
                  '$sign${formatKrw(totalPnl)}($sign${returnRate.toStringAsFixed(2)}%)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: profitColor,
                  ),
                ),
                if (unsettledCount > 0) ...[
                  const SizedBox(width: 8),
                  Text(
                    '\u20A9${liveExchangeRate.toStringAsFixed(0)}',
                    style: TextStyle(fontSize: 11, color: context.appTextHint),
                  ),
                ],
              ],
            ),
            if (unsettledCount > 0) ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '환전 미확정 $unsettledCount건',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.amber500,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
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
              showTopToast(context, '${cycle.ticker} 사이클 기록이 삭제되었습니다');
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.red500),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // Phase 5: 환전 확정 다이얼로그
  // ═══════════════════════════════════════════════════════════════

  void _showExchangeSettleDialog(
    BuildContext context,
    WidgetRef ref, {
    Cycle? cycle,
    Holding? holding,
  }) {
    final liveRate = ref.read(currentExchangeRateProvider);
    showDialog(
      context: context,
      builder: (ctx) => _ExchangeSettleDialog(
        liveExchangeRate: liveRate,
        cycle: cycle,
        holding: holding,
        onConfirm: (settledRate) {
          if (cycle != null) {
            ref.read(cycleListProvider.notifier).settleExchange(cycle.id, settledRate);
            showTopToast(context, '${cycle.ticker} 환전이 확정되었습니다');
          } else if (holding != null) {
            ref.read(holdingListProvider.notifier).settleExchange(holding.id, settledRate);
            showTopToast(context, '${holding.ticker} 환전이 확정되었습니다');
          }
        },
      ),
    );
  }

  void _unsettleCycleExchange(BuildContext context, WidgetRef ref, Cycle cycle) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('환전 확정 취소'),
        content: Text('${cycle.ticker} 환전 확정을 취소하시겠습니까?\n\n손익이 실시간 환율 기준으로 다시 변동됩니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(cycleListProvider.notifier).unsettleExchange(cycle.id);
              showTopToast(context, '${cycle.ticker} 환전 확정이 취소되었습니다');
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.amber500),
            child: const Text('확정 취소'),
          ),
        ],
      ),
    );
  }

  void _unsettleHoldingExchange(BuildContext context, WidgetRef ref, Holding holding) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('환전 확정 취소'),
        content: Text('${holding.ticker} 환전 확정을 취소하시겠습니까?\n\n손익이 실시간 환율 기준으로 다시 변동됩니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(holdingListProvider.notifier).unsettleExchange(holding.id);
              showTopToast(context, '${holding.ticker} 환전 확정이 취소되었습니다');
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.amber500),
            child: const Text('확정 취소'),
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

// ═══════════════════════════════════════════════════════════════
// Phase 3-2: _CompletedCycleCard → 2줄 컴팩트
// ═══════════════════════════════════════════════════════════════

class _CompletedCycleCard extends ConsumerWidget {
  final Cycle cycle;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onSettleExchange;
  final VoidCallback? onUnsettleExchange;
  final bool inGrid;

  const _CompletedCycleCard({
    required this.cycle,
    this.onTap,
    this.onDelete,
    this.onSettleExchange,
    this.onUnsettleExchange,
    this.inGrid = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final realizedResult = ref.watch(cycleRealizedPnlProvider(cycle.id));
    final totalBuyKrw = realizedResult?.totalBuyKrw ?? 0.0;
    final totalSellKrw = realizedResult?.totalSellKrw ?? 0.0;

    // 환전 확정 시 확정환율 기준 회수금 재계산
    final recoveredKrw = cycle.isExchangeSettled
        ? cycle.totalSellUsd * cycle.settledExchangeRate
        : totalSellKrw;

    final pnl = recoveredKrw - totalBuyKrw;
    final returnRate = totalBuyKrw > 0 ? (pnl / totalBuyKrw) * 100 : 0.0;
    final isProfit = pnl >= 0;
    final profitColor = isProfit ? AppColors.red500 : AppColors.blue500;
    final sign = isProfit ? '+' : '';

    // Ladder 공격형: buyTicker 표시
    final displayTicker = (cycle.strategyType == StrategyType.ladderCycle && cycle.buyTicker.isNotEmpty)
        ? cycle.buyTicker
        : cycle.ticker;

    final startDate = cycle.firstTradeDate ?? cycle.startDate;
    final endDate = cycle.lastTradeDate ?? cycle.updatedAt;

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
                // 1줄: TickerLogo + 티커 + StrategyBadge + 날짜 + 삭제
                Row(
                  children: [
                    TickerLogo(ticker: displayTicker, size: 24, borderRadius: 6),
                    const SizedBox(width: 6),
                    Text(
                      displayTicker,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: context.appTickerColor,
                      ),
                    ),
                    const SizedBox(width: 6),
                    StrategyBadge(
                      strategyType: cycle.strategyType,
                      ladderMode: cycle.strategyType == StrategyType.ladderCycle
                          ? cycle.ladderMode
                          : null,
                    ),
                    const Spacer(),
                    Text(
                      '${formatDateShort(startDate)}~${formatDateShort(endDate)}',
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
                // 2줄: 투자금(축약) + 회수금(축약) + 손익 + 환전 배지/버튼
                Row(
                  children: [
                    Text(
                      '투자 ${formatCashShort(totalBuyKrw)}',
                      style: TextStyle(fontSize: 12, color: context.appTextSecondary),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '회수 ${formatCashShort(recoveredKrw)}',
                      style: TextStyle(fontSize: 12, color: context.appTextSecondary),
                    ),
                    const Spacer(),
                    Text(
                      '$sign${formatKrw(pnl)}($sign${returnRate.toStringAsFixed(1)}%)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: profitColor,
                      ),
                    ),
                    const SizedBox(width: 6),
                    _buildExchangeBadge(context, cycle.isExchangeSettled),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExchangeBadge(BuildContext context, bool isSettled) {
    if (isSettled) {
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

// ═══════════════════════════════════════════════════════════════
// _SectionHeader
// ═══════════════════════════════════════════════════════════════

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

// ═══════════════════════════════════════════════════════════════
// Phase 5: 환전 확정 다이얼로그
// ═══════════════════════════════════════════════════════════════

class _ExchangeSettleDialog extends StatefulWidget {
  final double liveExchangeRate;
  final Cycle? cycle;
  final Holding? holding;
  final void Function(double settledRate) onConfirm;

  const _ExchangeSettleDialog({
    required this.liveExchangeRate,
    this.cycle,
    this.holding,
    required this.onConfirm,
  });

  @override
  State<_ExchangeSettleDialog> createState() => _ExchangeSettleDialogState();
}

class _ExchangeSettleDialogState extends State<_ExchangeSettleDialog> {
  late final TextEditingController _rateController;
  double _settledRate = 0;

  // 매도 합계 USD / 매입 평균환율
  double get _totalSellUsd {
    if (widget.cycle != null) return widget.cycle!.totalSellUsd;
    return 0; // holding은 transaction 기반이므로 외부에서 넘겨야 하지만 간략화
  }

  double get _avgBuyExchangeRate {
    if (widget.cycle != null) return widget.cycle!.exchangeRateAtEntry;
    if (widget.holding != null) return widget.holding!.exchangeRate;
    return 0;
  }

  double get _totalBuyKrw {
    if (widget.cycle != null) return widget.cycle!.totalBuyAmountKrw;
    return 0;
  }

  @override
  void initState() {
    super.initState();
    _settledRate = widget.liveExchangeRate;
    _rateController = TextEditingController(text: _settledRate.toStringAsFixed(2));
    _rateController.addListener(_onRateChanged);
  }

  void _onRateChanged() {
    final parsed = double.tryParse(_rateController.text);
    if (parsed != null && parsed > 0) {
      setState(() => _settledRate = parsed);
    }
  }

  @override
  void dispose() {
    _rateController.removeListener(_onRateChanged);
    _rateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sellUsd = _totalSellUsd;
    final settledKrw = sellUsd * _settledRate;
    final investedKrw = _totalBuyKrw;
    final settledPnl = settledKrw - investedKrw;
    final settledReturn = investedKrw > 0 ? (settledPnl / investedKrw) * 100 : 0.0;
    final isProfit = settledPnl >= 0;
    final profitColor = isProfit ? AppColors.red500 : AppColors.blue500;
    final sign = isProfit ? '+' : '';

    return AlertDialog(
      title: Text(
        '환전 확정',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: context.appTextPrimary,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 매입 평균환율
            _infoRow(context, '매입 평균환율', '\u20A9${_avgBuyExchangeRate.toStringAsFixed(2)} / \$1'),
            const SizedBox(height: 16),

            // 환전 환율 입력
            Text(
              '환전 환율',
              style: TextStyle(fontSize: 13, color: context.appTextSecondary),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _rateController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
              ],
              decoration: InputDecoration(
                hintText: '환율 입력',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: context.appTextPrimary,
              ),
            ),
            const SizedBox(height: 16),

            // 매도 합계 USD
            if (sellUsd > 0)
              _infoRow(context, '매도 합계 (USD)', '\$${sellUsd.toStringAsFixed(2)}'),
            if (sellUsd > 0) const SizedBox(height: 8),

            // 환전 금액 KRW
            if (sellUsd > 0)
              _infoRow(context, '환전 금액 (KRW)', '\u20A9${formatKrwWithComma(settledKrw)}'),
            if (sellUsd > 0) const SizedBox(height: 12),

            // 확정 손익
            if (investedKrw > 0) ...[
              Divider(color: context.appDivider),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '확정 손익',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.appTextPrimary),
                  ),
                  Text(
                    '$sign${formatKrw(settledPnl)} ($sign${settledReturn.toStringAsFixed(1)}%)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: profitColor,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),

            // 안내 문구
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: context.appBackground,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '\u203B 확정 후 환율 변동에 따른\n  환차손익이 더 이상 발생하지 않습니다',
                style: TextStyle(fontSize: 12, color: context.appTextHint),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            widget.onConfirm(_settledRate);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.amber500,
            foregroundColor: Colors.white,
          ),
          child: const Text('환전 확정'),
        ),
      ],
    );
  }

  Widget _infoRow(BuildContext context, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: context.appTextSecondary)),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.appTextPrimary)),
      ],
    );
  }
}
