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
import '../../widgets/shared/confirm_dialog.dart';
import '../holdings/widgets/profit_loss_section.dart';
import 'widgets/cycle_info_card.dart';
import 'widgets/cycle_trade_card.dart';
import 'widgets/cycle_trade_record_sheet.dart';

/// 사이클 상세 화면
///
/// 보유 상세 화면과 동일한 형식의 그라데이션 PnL 카드 + 정보 카드 +
/// 간소화된 액션 버튼 (거래 기록 FAB + 사이클 완료)
class CycleDetailScreen extends ConsumerStatefulWidget {
  final String cycleId;

  const CycleDetailScreen({super.key, required this.cycleId});

  @override
  ConsumerState<CycleDetailScreen> createState() => _CycleDetailScreenState();
}

class _CycleDetailScreenState extends ConsumerState<CycleDetailScreen> {
  @override
  Widget build(BuildContext context) {
    // cycleListProvider를 직접 watch — Hive 객체는 같은 참조를 반환하므로
    // .select()나 Provider.family 사용 시 변경 감지 불가. 리스트 직접 감시로 해결.
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
              Icon(Icons.search_off, size: 48, color: context.appTextHint),
              const SizedBox(height: 16),
              Text(
                '사이클을 찾을 수 없습니다',
                style: TextStyle(fontSize: 16, color: context.appTextSecondary),
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

    final currentPrice = ref.watch(
      closingPricesProvider.select((prices) => prices[cycle.ticker] ?? 0.0),
    );
    final liveExchangeRate = ref.watch(currentExchangeRateProvider);
    final signal = ref.watch(cycleSignalProvider(widget.cycleId));
    final signalAmount = ref.watch(cycleSignalAmountProvider(widget.cycleId));
    final trades = ref.watch(tradeListProvider(widget.cycleId));

    // === PnL 계산 (보유 상세와 동일한 분리 방식) ===
    final hasPosition = cycle.totalShares > 0 && cycle.averagePrice > 0;
    final evaluatedAmountKrw = TradingMath.evaluatedAmount(
      cycle.totalShares, currentPrice, liveExchangeRate,
    );
    final investedAmount = cycle.totalInvestedAmount; // seedAmount - remainingCash

    // 평균 매입환율 — exchangeRateAtEntry를 직접 사용 (사용자 수정 가능)
    final weightedAvgExchangeRate = cycle.exchangeRateAtEntry;

    // USD 손익
    final usdPL = hasPosition
        ? (currentPrice - cycle.averagePrice) * cycle.totalShares
        : 0.0;
    final usdReturnRate = hasPosition
        ? TradingMath.returnRate(currentPrice, cycle.averagePrice)
        : 0.0;

    // 환차 손익
    final currencyPL = hasPosition
        ? (liveExchangeRate - weightedAvgExchangeRate) * currentPrice * cycle.totalShares
        : 0.0;

    final isMobile = MediaQuery.sizeOf(context).width < 600;

    return Scaffold(
      backgroundColor: context.appBackground,
      appBar: _buildAppBar(context, cycle),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(
                vertical: isMobile ? 8 : 12,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // === 신호 카드 (active 사이클만) ===
                  if (cycle.status == CycleStatus.active) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SignalDisplay(
                        signal: signal,
                        size: SignalDisplaySize.large,
                        amount: signalAmount,
                        lossRate: hasPosition ? usdReturnRate : null,
                      ),
                    ),
                    SizedBox(height: isMobile ? 10 : 16),
                  ],

                  // === 그라데이션 PnL 카드 (보유 상세와 동일) ===
                  if (hasPosition)
                    ProfitLossSummaryCard(
                      currentPrice: currentPrice,
                      currentExchangeRate: liveExchangeRate,
                      usdPL: usdPL,
                      usdReturnRate: usdReturnRate,
                      investedAmount: investedAmount,
                      currencyPL: currencyPL,
                      quantity: cycle.totalShares.round(),
                    )
                  else
                    _buildEmptyPnLCard(context),
                  SizedBox(height: isMobile ? 10 : 16),

                  // === 정보 카드 (보유 상세 스타일 + 사이클 전용) ===
                  CycleInfoCard(
                    cycle: cycle,
                    currentPrice: currentPrice,
                    liveExchangeRate: liveExchangeRate,
                    evaluatedAmountKrw: evaluatedAmountKrw,
                    weightedAvgExchangeRate: weightedAvgExchangeRate,
                    onExchangeRateChanged: (newRate) async {
                      cycle.exchangeRateAtEntry = newRate;
                      await ref.read(cycleListProvider.notifier).saveCycle(cycle);
                    },
                  ),
                  SizedBox(height: isMobile ? 14 : 20),

                  // === 거래 내역 ===
                  _buildTradeHistorySection(
                    context, trades, cycle, isMobile,
                  ),
                  SizedBox(height: isMobile ? 14 : 20),

                  // === 사이클 완료 버튼 (active 사이클만) ===
                  if (cycle.status == CycleStatus.active)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _buildCompleteButton(
                        context, cycle, currentPrice, usdReturnRate,
                      ),
                    ),

                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
      // === FAB: 거래 기록 (보유 상세와 동일 패턴) ===
      floatingActionButton: cycle.status == CycleStatus.active
          ? _buildFAB(context, cycle, signal, signalAmount, liveExchangeRate, isMobile)
          : null,
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // AppBar
  // ═══════════════════════════════════════════════════════════════

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    Cycle cycle,
  ) {
    return AppBar(
      backgroundColor: context.appSurface,
      foregroundColor: context.appTextPrimary,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      toolbarHeight: 56,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, size: 22),
        onPressed: () => context.pop(),
      ),
      titleSpacing: 0,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            cycle.ticker,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: context.appTextPrimary,
            ),
          ),
          Text(
            cycle.name,
            style: TextStyle(
              fontSize: 12,
              color: context.appTextSecondary,
            ),
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: StrategyBadge(strategyType: cycle.strategyType),
        ),
        if (cycle.status == CycleStatus.active)
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: context.appTextSecondary),
            color: context.appCardBackground,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onSelected: (value) => _handleMenuAction(value, cycle),
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'editSeed',
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined, size: 20, color: context.appTextSecondary),
                    const SizedBox(width: 8),
                    Text('시드 수정', style: TextStyle(color: context.appTextPrimary)),
                  ],
                ),
              ),
              if (cycle.totalShares > 0)
                PopupMenuItem(
                  value: 'takeProfit',
                  child: Row(
                    children: [
                      const Icon(Icons.celebration, size: 20, color: AppColors.green600),
                      const SizedBox(width: 8),
                      const Text('익절 처리', style: TextStyle(color: AppColors.green600)),
                    ],
                  ),
                ),
              PopupMenuItem(
                value: 'complete',
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline, size: 20, color: context.appTextSecondary),
                    const SizedBox(width: 8),
                    Text('사이클 완료', style: TextStyle(color: context.appTextPrimary)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    const Icon(Icons.delete_outline, size: 20, color: AppColors.red500),
                    const SizedBox(width: 8),
                    const Text('삭제', style: TextStyle(color: AppColors.red500)),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 포지션 없을 때 PnL 카드
  // ═══════════════════════════════════════════════════════════════

  Widget _buildEmptyPnLCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.secondary, AppColors.secondaryDark],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.secondary.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: const Center(
        child: Text(
          '첫 매수 후 손익이 표시됩니다',
          style: TextStyle(fontSize: 14, color: Colors.white70),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 사이클 완료 버튼
  // ═══════════════════════════════════════════════════════════════

  Widget _buildCompleteButton(
    BuildContext context,
    Cycle cycle,
    double currentPrice,
    double returnRate,
  ) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _handleCompleteCycle(cycle, currentPrice, returnRate),
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
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // FAB: 거래 기록 (보유 상세 패턴 — 풀스크린 시트)
  // ═══════════════════════════════════════════════════════════════

  Widget _buildFAB(
    BuildContext context,
    Cycle cycle,
    TradeSignal signal,
    double? signalAmount,
    double liveExchangeRate,
    bool isMobile,
  ) {
    if (isMobile) {
      return FloatingActionButton.small(
        onPressed: () => _showTradeDialog(
          context, cycle, signal, signalAmount, liveExchangeRate,
        ),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white, size: 20),
      );
    }
    return FloatingActionButton.extended(
      onPressed: () => _showTradeDialog(
        context, cycle, signal, signalAmount, liveExchangeRate,
      ),
      backgroundColor: AppColors.primary,
      icon: const Icon(Icons.add, color: Colors.white),
      label: const Text(
        '거래 기록',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 풀스크린 거래 기록 시트 (보유 상세와 동일한 패턴)
  // ═══════════════════════════════════════════════════════════════

  void _showTradeDialog(
    BuildContext context,
    Cycle cycle,
    TradeSignal signal,
    double? signalAmount,
    double liveExchangeRate,
  ) {
    final prices = ref.read(closingPricesProvider);
    final price = prices[cycle.ticker];
    final quote = ref.read(stockQuoteProvider).quotes[cycle.ticker];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: context.appSurface,
      shape: const RoundedRectangleBorder(),
      builder: (context) => SizedBox(
        height: MediaQuery.sizeOf(context).height,
        child: CycleTradeRecordSheet(
          cycle: cycle,
          currentExchangeRate: liveExchangeRate,
          currentPrice: price,
          changePercent: quote?.changePercent,
          currentSignal: signal,
          signalAmount: signalAmount,
          onSubmit: ({
            required isBuy,
            required signal,
            required price,
            required shares,
            required exchangeRate,
            required date,
            memo,
            extraFundingAmount = 0,
          }) {
            if (isBuy) {
              final amountKrw = shares * price * exchangeRate;
              ref.read(tradeListProvider(widget.cycleId).notifier).recordBuy(
                    cycleId: widget.cycleId,
                    signal: signal,
                    price: price,
                    amountKrw: amountKrw,
                    exchangeRate: exchangeRate,
                    memo: memo,
                    extraFundingAmount: extraFundingAmount,
                  );
            } else {
              ref.read(tradeListProvider(widget.cycleId).notifier).recordSell(
                    cycleId: widget.cycleId,
                    signal: signal,
                    price: price,
                    shares: shares,
                    exchangeRate: exchangeRate,
                    memo: memo,
                  );
            }
          },
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 거래 내역
  // ═══════════════════════════════════════════════════════════════

  Widget _buildTradeHistorySection(
    BuildContext context, List<Trade> trades, Cycle cycle, bool isMobile,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            '거래 내역 (${trades.length}건)',
            style: TextStyle(
              fontSize: isMobile ? 13 : 16,
              fontWeight: FontWeight.bold,
              color: context.appTextPrimary,
            ),
          ),
        ),
        SizedBox(height: isMobile ? 6 : 10),
        if (trades.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: isMobile ? 24 : 32),
              decoration: BoxDecoration(
                color: context.appSurface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  '아직 거래 내역이 없습니다',
                  style: TextStyle(
                    fontSize: isMobile ? 12 : 14,
                    color: context.appTextHint,
                  ),
                ),
              ),
            ),
          )
        else
          ...trades.asMap().entries.map((entry) => CycleTradeCard(
            trade: entry.value,
            cycle: cycle,
            isFirst: entry.key == 0,
            isLast: entry.key == trades.length - 1,
            readOnly: cycle.status != CycleStatus.active,
          )),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 액션 핸들러
  // ═══════════════════════════════════════════════════════════════

  void _handleMenuAction(String action, Cycle cycle) {
    switch (action) {
      case 'editSeed':
        _handleEditSeed(cycle);
      case 'takeProfit':
        final prices = ref.read(closingPricesProvider);
        final price = prices[cycle.ticker] ?? 0.0;
        final liveExchangeRate = ref.read(currentExchangeRateProvider);
        _handleTakeProfit(cycle, price, liveExchangeRate);
      case 'delete':
        _handleDelete(cycle);
      case 'complete':
        final prices = ref.read(closingPricesProvider);
        final currentPrice = prices[cycle.ticker] ?? 0.0;
        final returnRate = cycle.totalShares > 0 && cycle.averagePrice > 0
            ? TradingMath.returnRate(currentPrice, cycle.averagePrice)
            : 0.0;
        _handleCompleteCycle(cycle, currentPrice, returnRate);
    }
  }

  Future<void> _handleEditSeed(Cycle cycle) async {
    final investedAmount = cycle.seedAmount - cycle.remainingCash;
    final controller = TextEditingController(
      text: cycle.seedAmount.round().toString(),
    );

    final newSeed = await showDialog<double>(
      context: context,
      builder: (dialogContext) {
        String? errorText;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: context.appCardBackground,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                '시드 수정',
                style: TextStyle(color: context.appTextPrimary),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '현재 투자금: ${formatKrwWithComma(investedAmount)}원',
                    style: TextStyle(
                      fontSize: 13,
                      color: context.appTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '새 시드는 투자금 이상이어야 합니다.',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.appTextHint,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    style: TextStyle(color: context.appTextPrimary),
                    decoration: InputDecoration(
                      labelText: '시드 금액 (원)',
                      labelStyle: TextStyle(color: context.appTextSecondary),
                      errorText: errorText,
                      suffixText: '원',
                      suffixStyle: TextStyle(color: context.appTextSecondary),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: context.appBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: context.appAccent),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.red500),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.red500),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(
                    '취소',
                    style: TextStyle(color: context.appTextSecondary),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.appAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () {
                    final value = double.tryParse(controller.text);
                    if (value == null || value <= 0) {
                      setDialogState(() {
                        errorText = '유효한 금액을 입력하세요';
                      });
                      return;
                    }
                    if (value < investedAmount) {
                      setDialogState(() {
                        errorText =
                            '투자금(${formatKrwWithComma(investedAmount)}원) 이상이어야 합니다';
                      });
                      return;
                    }
                    Navigator.of(dialogContext).pop(value);
                  },
                  child: const Text('저장'),
                ),
              ],
            );
          },
        );
      },
    );

    if (newSeed != null && mounted) {
      cycle.seedAmount = newSeed;
      cycle.remainingCash = newSeed - investedAmount;
      await ref.read(cycleListProvider.notifier).saveCycle(cycle);
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

}
