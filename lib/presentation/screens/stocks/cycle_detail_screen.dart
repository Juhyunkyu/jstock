import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/krw_formatter.dart';
import '../../../data/models/cycle.dart';
import '../../../data/models/trade.dart';
import '../../../domain/trading/trading_math.dart';
import '../../providers/providers.dart';
import '../../widgets/cycle/strategy_badge.dart';
import '../../widgets/cycle/signal_display.dart';
import '../../widgets/cycle/cycle_info_section.dart';
import '../../widgets/shared/ticker_logo.dart';
import '../../widgets/shared/return_badge.dart';
import '../../widgets/shared/confirm_dialog.dart';

/// 사이클 상세 화면
///
/// 사이클 전체 정보, 실시간 신호, 손익 요약, 거래 내역을 표시하고
/// 매수/매도 기록, 익절 처리, 사이클 완료/삭제 액션을 제공합니다.
class CycleDetailScreen extends ConsumerStatefulWidget {
  final String cycleId;

  const CycleDetailScreen({super.key, required this.cycleId});

  @override
  ConsumerState<CycleDetailScreen> createState() => _CycleDetailScreenState();
}

class _CycleDetailScreenState extends ConsumerState<CycleDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final cycles = ref.watch(cycleListProvider);
    final cycle = cycles.where((c) => c.id == widget.cycleId).firstOrNull;

    if (cycle == null) {
      return Scaffold(
        backgroundColor: context.appBackground,
        appBar: AppBar(
          backgroundColor: context.appSurface,
          foregroundColor: context.appTextPrimary,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.search_off,
                size: 48,
                color: context.appTextHint,
              ),
              const SizedBox(height: 16),
              Text(
                '사이클을 찾을 수 없습니다',
                style: TextStyle(
                  fontSize: 16,
                  color: context.appTextSecondary,
                ),
              ),
              const SizedBox(height: 24),
              TextButton.icon(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back),
                label: const Text('돌아가기'),
              ),
            ],
          ),
        ),
      );
    }

    final prices = ref.watch(currentPricesProvider);
    final currentPrice = prices[cycle.ticker] ?? 0.0;
    final liveExchangeRate = ref.watch(currentExchangeRateProvider);
    final signal = ref.watch(cycleSignalProvider(widget.cycleId));
    final signalAmount = ref.watch(cycleSignalAmountProvider(widget.cycleId));
    final trades = ref.watch(tradeListProvider(widget.cycleId));

    final evaluatedAmount = TradingMath.evaluatedAmount(
          cycle.totalShares,
          currentPrice,
          liveExchangeRate,
        ) +
        cycle.remainingCash;
    final investedAmount = cycle.seedAmount;
    final profitLoss = evaluatedAmount - investedAmount;
    final isProfit = profitLoss >= 0;

    final returnRate = cycle.totalShares > 0 && cycle.averagePrice > 0
        ? TradingMath.returnRate(currentPrice, cycle.averagePrice)
        : 0.0;

    final lossRate = cycle.totalShares > 0 && cycle.averagePrice > 0
        ? TradingMath.returnRate(currentPrice, cycle.averagePrice)
        : null;

    // 거래 내역 날짜 내림차순 정렬
    final sortedTrades = List<Trade>.from(trades)
      ..sort((a, b) => b.tradedAt.compareTo(a.tradedAt));

    return Scaffold(
      backgroundColor: context.appBackground,
      appBar: _buildAppBar(context, cycle),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // === 헤더 섹션 ===
            _buildHeaderSection(
              context,
              cycle,
              currentPrice,
              returnRate,
            ),
            const SizedBox(height: 16),

            // === 신호 카드 (active 사이클만) ===
            if (cycle.status == CycleStatus.active) ...[
              SignalDisplay(
                signal: signal,
                size: SignalDisplaySize.large,
                amount: signalAmount,
                lossRate: lossRate,
              ),
              const SizedBox(height: 16),
            ],

            // === 손익 요약 ===
            _buildPnLSummary(
              context,
              evaluatedAmount: evaluatedAmount,
              investedAmount: investedAmount,
              profitLoss: profitLoss,
              isProfit: isProfit,
            ),
            const SizedBox(height: 16),

            // === 사이클 정보 그리드 ===
            CycleInfoSection(
              cycle: cycle,
              currentPrice: currentPrice,
              liveExchangeRate: liveExchangeRate,
            ),
            const SizedBox(height: 20),

            // === 거래 내역 ===
            _buildTradeHistorySection(context, sortedTrades),
            const SizedBox(height: 20),

            // === 액션 버튼 (active 사이클만) ===
            if (cycle.status == CycleStatus.active)
              _buildActionButtons(
                context,
                cycle,
                signal,
                currentPrice,
                liveExchangeRate,
                returnRate,
              ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // AppBar
  // ═══════════════════════════════════════════════════════════════

  PreferredSizeWidget _buildAppBar(BuildContext context, Cycle cycle) {
    return AppBar(
      backgroundColor: context.appSurface,
      foregroundColor: context.appTextPrimary,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => context.pop(),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            cycle.ticker,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: context.appTickerColor,
            ),
          ),
          const SizedBox(width: 8),
          StrategyBadge(strategyType: cycle.strategyType),
        ],
      ),
      actions: [
        if (cycle.status == CycleStatus.active)
          PopupMenuButton<String>(
            icon: Icon(
              Icons.more_vert,
              color: context.appTextSecondary,
            ),
            color: context.appCardBackground,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onSelected: (value) => _handleMenuAction(value, cycle),
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'complete',
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 20,
                      color: context.appTextSecondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '사이클 완료',
                      style: TextStyle(color: context.appTextPrimary),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    const Icon(
                      Icons.delete_outline,
                      size: 20,
                      color: AppColors.red500,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      '삭제',
                      style: TextStyle(color: AppColors.red500),
                    ),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 헤더 섹션
  // ═══════════════════════════════════════════════════════════════

  Widget _buildHeaderSection(
    BuildContext context,
    Cycle cycle,
    double currentPrice,
    double returnRate,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: context.isDarkMode
                ? Colors.white.withValues(alpha: 0.03)
                : Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              TickerLogo(
                ticker: cycle.ticker,
                size: 40,
                borderRadius: 10,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          cycle.ticker,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: context.appTickerColor,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (currentPrice > 0)
                          Text(
                            '\$${currentPrice.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: context.appTextPrimary,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      cycle.name,
                      style: TextStyle(
                        fontSize: 13,
                        color: context.appTextSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (cycle.totalShares > 0)
                ReturnBadge(
                  value: returnRate,
                  colorScheme: ReturnBadgeColorScheme.greenRed,
                )
              else if (cycle.status == CycleStatus.completed)
                ReturnBadge(
                  value: cycle.completedReturnRate,
                  nullLabel: '완료',
                  colorScheme: ReturnBadgeColorScheme.greenRed,
                )
              else
                ReturnBadge(
                  value: null,
                  nullLabel: '대기',
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 손익 요약
  // ═══════════════════════════════════════════════════════════════

  Widget _buildPnLSummary(
    BuildContext context, {
    required double evaluatedAmount,
    required double investedAmount,
    required double profitLoss,
    required bool isProfit,
  }) {
    final profitColor = isProfit ? AppColors.red500 : AppColors.blue500;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: context.isDarkMode
                ? Colors.white.withValues(alpha: 0.03)
                : Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildPnLRow(
            context,
            label: '평가금액',
            value: '${formatKrwWithComma(evaluatedAmount)}\u2009원',
            valueColor: context.appTextPrimary,
            isBold: true,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Divider(height: 1, color: context.appDivider),
          ),
          _buildPnLRow(
            context,
            label: '투자금액',
            value: '${formatKrwWithComma(investedAmount)}\u2009원',
            valueColor: context.appTextSecondary,
          ),
          const SizedBox(height: 8),
          _buildPnLRow(
            context,
            label: '손익',
            value:
                '${isProfit ? '+' : ''}${formatKrwWithComma(profitLoss)}\u2009원',
            valueColor: profitLoss == 0 ? context.appTextSecondary : profitColor,
            isBold: true,
          ),
        ],
      ),
    );
  }

  Widget _buildPnLRow(
    BuildContext context, {
    required String label,
    required String value,
    required Color valueColor,
    bool isBold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: context.appTextSecondary,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 16 : 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 거래 내역
  // ═══════════════════════════════════════════════════════════════

  Widget _buildTradeHistorySection(BuildContext context, List<Trade> trades) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '거래 내역 (${trades.length}건)',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: context.appTextPrimary,
          ),
        ),
        const SizedBox(height: 10),
        if (trades.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 32),
            decoration: BoxDecoration(
              color: context.appSurface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                '아직 거래 내역이 없습니다',
                style: TextStyle(
                  fontSize: 14,
                  color: context.appTextHint,
                ),
              ),
            ),
          )
        else
          ...trades.map((trade) => _buildTradeCard(context, trade)),
      ],
    );
  }

  Widget _buildTradeCard(BuildContext context, Trade trade) {
    final isBuy = trade.action == TradeAction.buy;
    final actionColor = isBuy ? AppColors.red500 : AppColors.blue500;
    final actionLabel = isBuy ? '매수' : '매도';
    final signalConfig = _getSignalBadgeConfig(trade.signal);
    final dateStr = _formatDate(trade.tradedAt);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: context.appBorder.withValues(alpha: 0.5),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 상단: 액션 + 신호 배지 + 날짜
          Row(
            children: [
              // 매수/매도 라벨
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: actionColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  actionLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: actionColor,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // 신호 배지
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: signalConfig.color.withValues(
                    alpha: context.isDarkMode ? 0.15 : 0.08,
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  signalConfig.label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: signalConfig.color,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                dateStr,
                style: TextStyle(
                  fontSize: 12,
                  color: context.appTextHint,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 하단: 가격 x 수량 = 금액
          Text(
            '\$${trade.price.toStringAsFixed(2)} x ${_formatShares(trade.shares)}주 = ${formatKrwWithComma(trade.amountKrw)}\u2009원',
            style: TextStyle(
              fontSize: 13,
              color: context.appTextPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
          // 메모
          if (trade.memo != null && trade.memo!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              trade.memo!,
              style: TextStyle(
                fontSize: 12,
                color: context.appTextHint,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 액션 버튼
  // ═══════════════════════════════════════════════════════════════

  Widget _buildActionButtons(
    BuildContext context,
    Cycle cycle,
    TradeSignal signal,
    double currentPrice,
    double liveExchangeRate,
    double returnRate,
  ) {
    return Column(
      children: [
        // Row 1: 매수 기록 / 매도 기록
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _showBuySheet(context, cycle, liveExchangeRate),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('매수 기록'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.red500,
                  side: const BorderSide(color: AppColors.red500, width: 1),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: cycle.totalShares > 0
                    ? () =>
                        _showSellSheet(context, cycle, liveExchangeRate)
                    : null,
                icon: const Icon(Icons.remove, size: 18),
                label: const Text('매도 기록'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.blue500,
                  side: BorderSide(
                    color: cycle.totalShares > 0
                        ? AppColors.blue500
                        : context.appBorder,
                    width: 1,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Row 2: 익절 처리 (signal이 takeProfit일 때) + 사이클 완료
        Row(
          children: [
            if (signal == TradeSignal.takeProfit && cycle.totalShares > 0)
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _handleTakeProfit(
                    cycle,
                    currentPrice,
                    liveExchangeRate,
                  ),
                  icon: const Icon(Icons.celebration, size: 18),
                  label: const Text('익절 처리'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.green600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            if (signal == TradeSignal.takeProfit && cycle.totalShares > 0)
              const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _handleCompleteCycle(
                  cycle,
                  currentPrice,
                  returnRate,
                ),
                icon: Icon(
                  Icons.check_circle_outline,
                  size: 18,
                  color: context.appTextSecondary,
                ),
                label: Text(
                  '사이클 완료',
                  style: TextStyle(color: context.appTextSecondary),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: context.appBorder, width: 1),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 매수 기록 BottomSheet
  // ═══════════════════════════════════════════════════════════════

  void _showBuySheet(
    BuildContext context,
    Cycle cycle,
    double liveExchangeRate,
  ) {
    final buySignals = cycle.strategyType == StrategyType.alphaCycleV3
        ? [
            TradeSignal.initial,
            TradeSignal.weightedBuy,
            TradeSignal.panicBuy,
            TradeSignal.manual,
          ]
        : [
            TradeSignal.locAB,
            TradeSignal.locB,
            TradeSignal.manual,
          ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.appCardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => _TradeRecordSheet(
        title: '매수 기록',
        action: TradeAction.buy,
        cycleId: widget.cycleId,
        signals: buySignals,
        exchangeRate: liveExchangeRate,
        maxCash: cycle.remainingCash,
        maxShares: null,
        onSubmit: (signal, price, amount, shares, exchangeRate, memo) {
          ref.read(tradeListProvider(widget.cycleId).notifier).recordBuy(
                cycleId: widget.cycleId,
                signal: signal,
                price: price,
                amountKrw: amount!,
                exchangeRate: exchangeRate,
                memo: memo,
              );
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 매도 기록 BottomSheet
  // ═══════════════════════════════════════════════════════════════

  void _showSellSheet(
    BuildContext context,
    Cycle cycle,
    double liveExchangeRate,
  ) {
    final sellSignals = cycle.strategyType == StrategyType.alphaCycleV3
        ? [
            TradeSignal.cashSecure,
            TradeSignal.takeProfit,
            TradeSignal.manual,
          ]
        : [
            TradeSignal.takeProfit,
            TradeSignal.manual,
          ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.appCardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => _TradeRecordSheet(
        title: '매도 기록',
        action: TradeAction.sell,
        cycleId: widget.cycleId,
        signals: sellSignals,
        exchangeRate: liveExchangeRate,
        maxCash: null,
        maxShares: cycle.totalShares,
        onSubmit: (signal, price, amount, shares, exchangeRate, memo) {
          ref.read(tradeListProvider(widget.cycleId).notifier).recordSell(
                cycleId: widget.cycleId,
                signal: signal,
                price: price,
                shares: shares!,
                exchangeRate: exchangeRate,
                memo: memo,
              );
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 액션 핸들러
  // ═══════════════════════════════════════════════════════════════

  void _handleMenuAction(String action, Cycle cycle) {
    switch (action) {
      case 'delete':
        _handleDelete(cycle);
      case 'complete':
        final prices = ref.read(currentPricesProvider);
        final currentPrice = prices[cycle.ticker] ?? 0.0;
        final returnRate = cycle.totalShares > 0 && cycle.averagePrice > 0
            ? TradingMath.returnRate(currentPrice, cycle.averagePrice)
            : 0.0;
        _handleCompleteCycle(cycle, currentPrice, returnRate);
    }
  }

  Future<void> _handleTakeProfit(
    Cycle cycle,
    double currentPrice,
    double liveExchangeRate,
  ) async {
    final confirmed = await ConfirmDialog.show(
      context: context,
      title: '익절 처리',
      message:
          '전량 매도 후 새 사이클이 생성됩니다.\n연속 익절 횟수가 이월되며 시드가 재투자됩니다.\n\n진행하시겠습니까?',
      confirmText: '익절',
    );

    if (confirmed && mounted) {
      try {
        await ref.read(cycleListProvider.notifier).completeTakeProfit(
              cycleId: widget.cycleId,
              currentPrice: currentPrice,
              exchangeRate: liveExchangeRate,
            );
        if (mounted) context.pop();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('익절 처리 실패: $e')),
          );
        }
      }
    }
  }

  Future<void> _handleCompleteCycle(
    Cycle cycle,
    double currentPrice,
    double returnRate,
  ) async {
    final confirmed = await ConfirmDialog.show(
      context: context,
      title: '사이클 완료',
      message: '사이클을 수동으로 완료하시겠습니까?\n연속 익절 횟수가 리셋됩니다.',
      confirmText: '완료',
    );

    if (confirmed && mounted) {
      await ref.read(cycleListProvider.notifier).completeCycle(
            widget.cycleId,
            completedReturnRate: returnRate,
          );
      if (mounted) context.pop();
    }
  }

  Future<void> _handleDelete(Cycle cycle) async {
    final confirmed = await ConfirmDialog.show(
      context: context,
      title: '사이클 삭제',
      message: '${cycle.ticker} 사이클과 모든 거래 내역을 삭제합니다.\n이 작업은 되돌릴 수 없습니다.',
      confirmText: '삭제',
      isDanger: true,
    );

    if (confirmed && mounted) {
      await ref.read(cycleListProvider.notifier).deleteCycle(widget.cycleId);
      if (mounted) context.pop();
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // 유틸
  // ═══════════════════════════════════════════════════════════════

  _SignalBadgeConfig _getSignalBadgeConfig(TradeSignal signal) {
    switch (signal) {
      case TradeSignal.initial:
        return _SignalBadgeConfig(label: '초기진입', color: AppColors.green600);
      case TradeSignal.weightedBuy:
        return _SignalBadgeConfig(label: '가중매수', color: AppColors.blue500);
      case TradeSignal.panicBuy:
        return _SignalBadgeConfig(label: '승부수', color: AppColors.red500);
      case TradeSignal.cashSecure:
        return _SignalBadgeConfig(label: '현금확보', color: AppColors.amber500);
      case TradeSignal.takeProfit:
        return _SignalBadgeConfig(label: '익절', color: AppColors.green500);
      case TradeSignal.locAB:
        return _SignalBadgeConfig(label: 'LOC A+B', color: AppColors.blue500);
      case TradeSignal.locA:
        return _SignalBadgeConfig(label: 'LOC A', color: AppColors.blue500);
      case TradeSignal.locB:
        return _SignalBadgeConfig(label: 'LOC B', color: AppColors.blue400);
      case TradeSignal.manual:
        return _SignalBadgeConfig(label: '수동', color: AppColors.gray500);
      case TradeSignal.hold:
        return _SignalBadgeConfig(label: '대기', color: AppColors.gray400);
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
  }

  String _formatShares(double shares) {
    if (shares == shares.roundToDouble() && shares < 10000) {
      return shares.round().toString();
    }
    return shares.toStringAsFixed(2);
  }
}

// ═══════════════════════════════════════════════════════════════
// 신호 배지 설정
// ═══════════════════════════════════════════════════════════════

class _SignalBadgeConfig {
  final String label;
  final Color color;

  const _SignalBadgeConfig({required this.label, required this.color});
}

// ═══════════════════════════════════════════════════════════════
// 매수/매도 기록 BottomSheet
// ═══════════════════════════════════════════════════════════════

class _TradeRecordSheet extends StatefulWidget {
  final String title;
  final TradeAction action;
  final String cycleId;
  final List<TradeSignal> signals;
  final double exchangeRate;
  final double? maxCash;
  final double? maxShares;
  final void Function(
    TradeSignal signal,
    double price,
    double? amountKrw,
    double? shares,
    double exchangeRate,
    String? memo,
  ) onSubmit;

  const _TradeRecordSheet({
    required this.title,
    required this.action,
    required this.cycleId,
    required this.signals,
    required this.exchangeRate,
    this.maxCash,
    this.maxShares,
    required this.onSubmit,
  });

  @override
  State<_TradeRecordSheet> createState() => _TradeRecordSheetState();
}

class _TradeRecordSheetState extends State<_TradeRecordSheet> {
  late TradeSignal _selectedSignal;
  final _priceController = TextEditingController();
  final _amountController = TextEditingController();
  final _sharesController = TextEditingController();
  final _exchangeRateController = TextEditingController();
  final _memoController = TextEditingController();
  bool _isSubmitting = false;

  bool get _isBuy => widget.action == TradeAction.buy;

  @override
  void initState() {
    super.initState();
    _selectedSignal = widget.signals.first;
    _exchangeRateController.text = widget.exchangeRate.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _priceController.dispose();
    _amountController.dispose();
    _sharesController.dispose();
    _exchangeRateController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 핸들바
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.appDivider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 타이틀
              Text(
                widget.title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: context.appTextPrimary,
                ),
              ),
              const SizedBox(height: 20),

              // 신호 선택
              Text(
                '신호',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: context.appTextSecondary,
                ),
              ),
              const SizedBox(height: 8),
              _buildSignalSelector(context),
              const SizedBox(height: 16),

              // 체결가
              _buildTextField(
                context,
                label: '체결가 (USD)',
                controller: _priceController,
                prefix: '\$',
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                ],
              ),
              const SizedBox(height: 12),

              // 매수: 금액 / 매도: 수량
              if (_isBuy)
                _buildTextField(
                  context,
                  label: '금액 (KRW)',
                  controller: _amountController,
                  suffix: '원',
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  helperText: widget.maxCash != null
                      ? '잔여현금: ${formatKrwWithComma(widget.maxCash!)}\u2009원'
                      : null,
                )
              else
                _buildTextField(
                  context,
                  label: '수량 (주)',
                  controller: _sharesController,
                  suffix: '주',
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                  ],
                  helperText: widget.maxShares != null
                      ? '보유수량: ${_formatSharesHelper(widget.maxShares!)}주'
                      : null,
                ),
              const SizedBox(height: 12),

              // 환율
              _buildTextField(
                context,
                label: '환율 (USD/KRW)',
                controller: _exchangeRateController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                ],
              ),
              const SizedBox(height: 12),

              // 메모
              _buildTextField(
                context,
                label: '메모 (선택)',
                controller: _memoController,
                keyboardType: TextInputType.text,
              ),
              const SizedBox(height: 24),

              // 기록 버튼
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isSubmitting ? null : _onSubmit,
                  style: FilledButton.styleFrom(
                    backgroundColor:
                        _isBuy ? AppColors.red500 : AppColors.blue500,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    _isSubmitting ? '처리 중...' : '기록',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSignalSelector(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: widget.signals.map((signal) {
        final isSelected = _selectedSignal == signal;
        final config = _getSignalChipConfig(signal);

        return ChoiceChip(
          label: Text(config.label),
          selected: isSelected,
          onSelected: (selected) {
            if (selected) setState(() => _selectedSignal = signal);
          },
          selectedColor: config.color.withValues(
            alpha: context.isDarkMode ? 0.25 : 0.15,
          ),
          backgroundColor: context.appBackground,
          side: BorderSide(
            color: isSelected
                ? config.color
                : context.appBorder,
            width: isSelected ? 1.5 : 0.5,
          ),
          labelStyle: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? config.color : context.appTextSecondary,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          showCheckmark: false,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        );
      }).toList(),
    );
  }

  Widget _buildTextField(
    BuildContext context, {
    required String label,
    required TextEditingController controller,
    String? prefix,
    String? suffix,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? helperText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          style: TextStyle(
            fontSize: 16,
            color: context.appTextPrimary,
          ),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(
              fontSize: 14,
              color: context.appTextHint,
            ),
            prefixText: prefix,
            prefixStyle: TextStyle(
              fontSize: 16,
              color: context.appTextPrimary,
            ),
            suffixText: suffix,
            suffixStyle: TextStyle(
              fontSize: 14,
              color: context.appTextHint,
            ),
            filled: true,
            fillColor: context.appBackground,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: context.appBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: context.appBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: context.appAccent, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
          ),
        ),
        if (helperText != null) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              helperText,
              style: TextStyle(
                fontSize: 12,
                color: context.appTextHint,
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _onSubmit() {
    final price = double.tryParse(_priceController.text);
    final exchangeRate = double.tryParse(_exchangeRateController.text);

    if (price == null || price <= 0) {
      _showError('체결가를 올바르게 입력하세요');
      return;
    }

    if (exchangeRate == null || exchangeRate <= 0) {
      _showError('환율을 올바르게 입력하세요');
      return;
    }

    if (_isBuy) {
      final amount = double.tryParse(_amountController.text);
      if (amount == null || amount <= 0) {
        _showError('금액을 올바르게 입력하세요');
        return;
      }
      if (widget.maxCash != null && amount > widget.maxCash!) {
        _showError('잔여현금(${formatKrwWithComma(widget.maxCash!)}\u2009원)을 초과합니다');
        return;
      }

      setState(() => _isSubmitting = true);
      widget.onSubmit(
        _selectedSignal,
        price,
        amount,
        null,
        exchangeRate,
        _memoController.text.isEmpty ? null : _memoController.text,
      );
    } else {
      final shares = double.tryParse(_sharesController.text);
      if (shares == null || shares <= 0) {
        _showError('수량을 올바르게 입력하세요');
        return;
      }
      if (widget.maxShares != null && shares > widget.maxShares!) {
        _showError('보유수량(${_formatSharesHelper(widget.maxShares!)}주)을 초과합니다');
        return;
      }

      setState(() => _isSubmitting = true);
      widget.onSubmit(
        _selectedSignal,
        price,
        null,
        shares,
        exchangeRate,
        _memoController.text.isEmpty ? null : _memoController.text,
      );
    }

    Navigator.of(context).pop();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  _SignalBadgeConfig _getSignalChipConfig(TradeSignal signal) {
    switch (signal) {
      case TradeSignal.initial:
        return _SignalBadgeConfig(label: '초기진입', color: AppColors.green600);
      case TradeSignal.weightedBuy:
        return _SignalBadgeConfig(label: '가중매수', color: AppColors.blue500);
      case TradeSignal.panicBuy:
        return _SignalBadgeConfig(label: '승부수', color: AppColors.red500);
      case TradeSignal.cashSecure:
        return _SignalBadgeConfig(label: '현금확보', color: AppColors.amber500);
      case TradeSignal.takeProfit:
        return _SignalBadgeConfig(label: '익절', color: AppColors.green500);
      case TradeSignal.locAB:
        return _SignalBadgeConfig(label: 'LOC A+B', color: AppColors.blue500);
      case TradeSignal.locA:
        return _SignalBadgeConfig(label: 'LOC A', color: AppColors.blue500);
      case TradeSignal.locB:
        return _SignalBadgeConfig(label: 'LOC B', color: AppColors.blue400);
      case TradeSignal.manual:
        return _SignalBadgeConfig(label: '수동', color: AppColors.gray500);
      case TradeSignal.hold:
        return _SignalBadgeConfig(label: '대기', color: AppColors.gray400);
    }
  }

  String _formatSharesHelper(double shares) {
    if (shares == shares.roundToDouble() && shares < 10000) {
      return shares.round().toString();
    }
    return shares.toStringAsFixed(2);
  }
}
