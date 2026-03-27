import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/utils/krw_formatter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/cycle.dart';
import '../../../data/models/trade.dart';
import '../../../domain/trading/trading_math.dart';
import '../../providers/providers.dart';
import '../../widgets/cycle/strategy_badge.dart';
import '../../widgets/cycle/signal_display.dart';
import '../../widgets/shared/confirm_dialog.dart';
import '../holdings/widgets/profit_loss_section.dart';
import 'widgets/cycle_completed_view.dart';
import 'widgets/cycle_info_card.dart';
import 'widgets/cycle_initial_buy_guide.dart';
import 'widgets/steady_order_guide_card.dart';
import 'widgets/cycle_seed_edit_dialog.dart';
import 'widgets/cycle_trade_card.dart';
import 'widgets/cycle_trade_record_sheet.dart';
import 'widgets/steady_combined_trade_sheet.dart';
import 'widgets/cycle_settings_sheet.dart';

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
    final allActive = ref.watch(activeCyclesProvider);

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

    // Steady Cycle: 주문 가이드 Provider watch (V1/V2.2/V3.0 통합)
    final steadyGuide = cycle.strategyType == StrategyType.infiniteBuy
        ? ref.watch(steadyOrderGuideProvider(widget.cycleId))
        : null;

    // === PnL 계산 (보유 상세와 동일한 분리 방식) ===
    final hasPosition = cycle.totalShares > 0 && cycle.averagePrice > 0;
    final isPendingCompletion = !hasPosition && trades.isNotEmpty && cycle.status == CycleStatus.active;
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

    // === 완료 사이클은 결과 중심 레이아웃 ===
    if (cycle.status == CycleStatus.completed) {
      return Scaffold(
        backgroundColor: context.appBackground,
        appBar: _buildAppBar(context, cycle, allActive),
        body: CycleCompletedView(cycle: cycle, trades: trades, isMobile: isMobile),
      );
    }

    return Scaffold(
      backgroundColor: context.appBackground,
      appBar: _buildAppBar(context, cycle, allActive),
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
                  // === 완료 대기: 요약 카드만 표시 (나머지 숨김) ===
                  if (isPendingCompletion) ...[
                    _buildPendingCompletionCard(context, ref, cycle, trades, isMobile, liveExchangeRate),
                    SizedBox(height: isMobile ? 14 : 20),
                  ]
                  // === 활성: 포지션 있으면 시세 카드, 없으면 초기 매수 가이드 ===
                  else ...[
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
                      CycleInitialBuyGuide(cycle: cycle, currentPrice: currentPrice, liveExchangeRate: liveExchangeRate),
                    SizedBox(height: isMobile ? 10 : 16),

                    // === 신호 카드 (Smart Cycle만) ===
                    if (cycle.status == CycleStatus.active &&
                        cycle.strategyType != StrategyType.infiniteBuy) ...[
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

                    // === Steady Cycle 주문 가이드 ===
                    if (cycle.strategyType == StrategyType.infiniteBuy &&
                        cycle.status == CycleStatus.active) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: SteadyOrderGuideCard(cycleId: widget.cycleId),
                      ),
                      SizedBox(height: isMobile ? 10 : 16),
                    ],

                    // === 정보 카드 ===
                    CycleInfoCard(
                      cycle: cycle,
                      currentPrice: currentPrice,
                      liveExchangeRate: liveExchangeRate,
                      evaluatedAmountKrw: evaluatedAmountKrw,
                      weightedAvgExchangeRate: weightedAvgExchangeRate,
                      steadyTValue: steadyGuide?.tValue,
                      onExchangeRateChanged: (newRate) async {
                        cycle.exchangeRateAtEntry = newRate;
                        await ref.read(cycleListProvider.notifier).saveCycle(cycle);
                      },
                      onEditSettings: cycle.isEmpty && cycle.status == CycleStatus.active
                          ? () => _showSettingsSheet(cycle)
                          : null,
                    ),
                    SizedBox(height: isMobile ? 14 : 20),
                  ],

                  // === 거래 내역 ===
                  _buildTradeHistorySection(
                    context, trades, cycle, isMobile,
                  ),
                  SizedBox(height: isMobile ? 14 : 20),

                  // === 사이클 완료 버튼 (active + 보유 중인 경우만) ===
                  if (cycle.status == CycleStatus.active && !isPendingCompletion)
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
    List<Cycle> allActive,
  ) {
    final displayLabel = cycleDisplayLabel(cycle, allActive);

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
          Row(
            children: [
              Text(
                cycle.ticker,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: context.appTextPrimary,
                ),
              ),
              if (displayLabel != null) ...[
                const SizedBox(width: 6),
                Text(
                  displayLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: cycle.nickname.isNotEmpty
                        ? context.appAccent
                        : context.appTextHint,
                  ),
                ),
              ],
            ],
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
          child: StrategyBadge(
            strategyType: cycle.strategyType,
            steadyVersion: cycle.strategyType == StrategyType.infiniteBuy
                ? cycle.steadyVersion
                : null,
          ),
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

    // Steady Cycle (V1/V2.2/V3.0): 매수+매도 통합 시트
    if (cycle.strategyType == StrategyType.infiniteBuy) {
      showModalBottomSheet(
        context: context,
        useRootNavigator: true,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: context.appSurface,
        shape: const RoundedRectangleBorder(),
        builder: (context) => SizedBox(
          height: MediaQuery.sizeOf(context).height,
          child: SteadyCombinedTradeSheet(
            cycle: cycle,
            currentExchangeRate: liveExchangeRate,
            currentPrice: price,
            changePercent: quote?.changePercent,
            onRecordBuy: ({
              required signal,
              required price,
              required shares,
              required exchangeRate,
              required date,
              memo,
              groupId,
            }) async {
              final amountKrw = shares * price * exchangeRate;
              await ref.read(tradeListProvider(widget.cycleId).notifier).recordBuy(
                    cycleId: widget.cycleId,
                    signal: signal,
                    price: price,
                    amountKrw: amountKrw,
                    exchangeRate: exchangeRate,
                    memo: memo,
                    groupId: groupId,
                    tradedAt: date,
                  );
            },
            onRecordSell: ({
              required signal,
              required price,
              required shares,
              required exchangeRate,
              required date,
              memo,
              groupId,
            }) async {
              await ref.read(tradeListProvider(widget.cycleId).notifier).recordSell(
                    cycleId: widget.cycleId,
                    signal: signal,
                    price: price,
                    shares: shares,
                    exchangeRate: exchangeRate,
                    memo: memo,
                    groupId: groupId,
                    tradedAt: date,
                  );
            },
          ),
        ),
      );
      return;
    }

    // Smart Cycle: 기존 시트
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
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
  // 전량 매도 완료 대기 카드
  // ═══════════════════════════════════════════════════════════════

  Widget _buildPendingCompletionCard(
    BuildContext context, WidgetRef ref, Cycle cycle, List<Trade> trades, bool isMobile, double liveExchangeRate,
  ) {
    final dateFormat = DateFormat('yyyy.MM.dd');
    final buyTrades = trades.where((t) => t.action == TradeAction.buy).toList();
    final sellTrades = trades.where((t) => t.action == TradeAction.sell).toList();

    // 총 투자금 (매수 총액)
    final totalBuyKrw = buyTrades.fold<double>(0, (s, t) => s + t.amountKrw);
    // 총 회수금 (매도 총액)
    final totalSellKrw = sellTrades.fold<double>(0, (s, t) => s + t.amountKrw);
    // ★ 순수익 = 매도총액 - 매수총액 (이중 계산 버그 수정)
    final netProfitKrw = totalSellKrw - totalBuyKrw;
    final profitRate = totalBuyKrw > 0 ? (netProfitKrw / totalBuyKrw * 100) : 0.0;
    final isProfit = netProfitKrw >= 0;

    // 평균 매수가/매도가 (USD)
    final totalBuyShares = buyTrades.fold<double>(0, (s, t) => s + t.shares);
    final totalBuyUsd = buyTrades.fold<double>(0, (s, t) => s + t.price * t.shares);
    final avgBuyPrice = totalBuyShares > 0 ? totalBuyUsd / totalBuyShares : 0.0;
    final totalSellShares = sellTrades.fold<double>(0, (s, t) => s + t.shares);
    final totalSellUsd = sellTrades.fold<double>(0, (s, t) => s + t.price * t.shares);
    final avgSellPrice = totalSellShares > 0 ? totalSellUsd / totalSellShares : 0.0;

    // 회차 수 (매수 거래만, cycle.roundsUsed 사용)
    final roundCount = cycle.roundsUsed;

    // 운용 기간 (첫 거래 ~ 마지막 거래)
    final firstDate = trades.map((t) => t.tradedAt).reduce((a, b) => a.isBefore(b) ? a : b);
    final lastDate = trades.map((t) => t.tradedAt).reduce((a, b) => a.isAfter(b) ? a : b);
    final durationDays = lastDate.difference(firstDate).inDays + 1;

    // 평균 환율
    final exchangeRate = cycle.exchangeRateAtEntry;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(isMobile ? 16 : 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [context.appGradientCardStart, context.appGradientCardEnd],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 타이틀
            Row(
              children: [
                Icon(Icons.check_circle_outline, size: 22, color: isProfit ? AppColors.overlayGreen : AppColors.overlayRed),
                const SizedBox(width: 8),
                Text('전량 매도 완료', style: TextStyle(fontSize: isMobile ? 16 : 18, fontWeight: FontWeight.w700, color: Colors.white)),
              ],
            ),
            SizedBox(height: isMobile ? 14 : 18),

            // 수익 요약
            _pendingRow('총 투자금', formatKrw(totalBuyKrw), isMobile),
            const SizedBox(height: 6),
            _pendingRow('총 회수금', formatKrw(totalSellKrw), isMobile),
            const SizedBox(height: 6),
            _pendingRow(
              '순수익',
              '${isProfit ? "+" : ""}${formatKrw(netProfitKrw)}  (${isProfit ? "+" : ""}${profitRate.toStringAsFixed(1)}%)',
              isMobile,
              valueColor: isProfit ? AppColors.overlayGreen : AppColors.overlayRed,
            ),
            SizedBox(height: isMobile ? 10 : 14),

            // 거래 상세
            _pendingRow('평균 매수가', '\$${avgBuyPrice.toStringAsFixed(2)}', isMobile),
            const SizedBox(height: 6),
            _pendingRow('평균 매도가', '\$${avgSellPrice.toStringAsFixed(2)}', isMobile),
            const SizedBox(height: 6),
            // 평균 환율 (수정 가능)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('평균 환율', style: TextStyle(fontSize: isMobile ? 12 : 13, color: Colors.white.withAlpha(180))),
                GestureDetector(
                  onTap: () async {
                    final controller = TextEditingController(text: exchangeRate.toStringAsFixed(0));
                    final result = await showDialog<double>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: context.appSurface,
                        title: Text('평균 환율 수정', style: TextStyle(fontSize: 16, color: context.appTextPrimary)),
                        content: TextField(
                          controller: controller,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            hintText: '예: 1380',
                            suffixText: '원',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
                          TextButton(
                            onPressed: () {
                              final val = double.tryParse(controller.text);
                              if (val != null && val > 0) Navigator.pop(ctx, val);
                            },
                            child: const Text('확인'),
                          ),
                        ],
                      ),
                    );
                    if (result != null) {
                      cycle.exchangeRateAtEntry = result;
                      await ref.read(cycleListProvider.notifier).saveCycle(cycle);
                    }
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '₩${exchangeRate.toStringAsFixed(0)}',
                        style: TextStyle(fontSize: isMobile ? 13 : 14, fontWeight: FontWeight.w600, color: Colors.white),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.edit_outlined, size: 14, color: Colors.white.withAlpha(180)),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: isMobile ? 10 : 14),

            // 운용 기간
            _pendingRow('운용 기간', '${dateFormat.format(firstDate)} ~ ${dateFormat.format(lastDate)} ($durationDays일)', isMobile),
            const SizedBox(height: 6),
            _pendingRow('총 회차', '$roundCount회차', isMobile),

            SizedBox(height: isMobile ? 16 : 20),

            // 구분선
            Container(height: 0.5, color: Colors.white.withAlpha(40)),
            SizedBox(height: isMobile ? 12 : 16),

            // 안내 문구
            Text(
              '거래 내역을 확인 후 완료하세요',
              style: TextStyle(fontSize: isMobile ? 13 : 14, fontWeight: FontWeight.w600, color: Colors.white.withAlpha(220)),
            ),
            const SizedBox(height: 3),
            Text(
              '환율이나 거래가 잘못되었다면 아래에서 수정 가능합니다.',
              style: TextStyle(fontSize: isMobile ? 11 : 12, color: Colors.white.withAlpha(150)),
            ),
            SizedBox(height: isMobile ? 14 : 18),

            // 완료 버튼
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _confirmCycleCompletion(context, ref, cycle),
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.appAccent,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: isMobile ? 12 : 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                child: Text(
                  '사이클 완료 및 정산',
                  style: TextStyle(fontSize: isMobile ? 14 : 15, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: Text(
                '완료 시 거래내역 탭으로 이동되며 되돌릴 수 없습니다.',
                style: TextStyle(fontSize: 10, color: Colors.white.withAlpha(120)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pendingRow(String label, String value, bool isMobile, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: isMobile ? 12 : 13, color: Colors.white.withAlpha(180))),
        Flexible(
          child: Text(value, textAlign: TextAlign.right, style: TextStyle(
            fontSize: isMobile ? 13 : 14,
            fontWeight: FontWeight.w600,
            color: valueColor ?? Colors.white,
          )),
        ),
      ],
    );
  }

  Future<void> _confirmCycleCompletion(BuildContext context, WidgetRef ref, Cycle cycle) async {
    final confirmed = await ConfirmDialog.show(
      context: context,
      title: '사이클 완료',
      message: '이 사이클을 완료 처리하시겠습니까?\n거래내역 탭에서 확인할 수 있습니다.',
      confirmText: '완료',
      isDanger: false,
    );
    if (confirmed && context.mounted) {
      cycle.status = CycleStatus.completed;
      await ref.read(cycleListProvider.notifier).saveCycle(cycle);
      if (context.mounted) {
        context.go('/history');
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════
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
          // groupId 기준으로 거래 묶기 (같은 그룹 = 1개 카드)
          ...() {
            final grouped = <String, List<Trade>>{};
            final ungrouped = <Trade>[];
            for (final t in trades) {
              if (t.groupId != null) {
                grouped.putIfAbsent(t.groupId!, () => []).add(t);
              } else {
                ungrouped.add(t);
              }
            }
            // 그룹화된 것은 첫 번째 거래 기준으로 정렬, 미그룹은 그대로
            final allEntries = <List<Trade>>[];
            final processedGroups = <String>{};
            for (final t in trades) {
              if (t.groupId != null) {
                if (processedGroups.add(t.groupId!)) {
                  allEntries.add(grouped[t.groupId!]!);
                }
              } else {
                allEntries.add([t]);
              }
            }
            final totalRounds = allEntries.length;
            return allEntries.asMap().entries.map((entry) {
              final roundNum = totalRounds - entry.key; // 최신=마지막 회차
              final firstTrade = entry.value.first;
              final dateStr = DateFormat('yyyy.MM.dd').format(firstTrade.tradedAt);
              return _TradeRoundSection(
                roundNumber: roundNum,
                dateStr: dateStr,
                child: CycleTradeCard(
                  trade: firstTrade,
                  groupedTrades: entry.value.length > 1 ? entry.value : null,
                  cycle: cycle,
                  isFirst: true,
                  isLast: true,
                  readOnly: cycle.status != CycleStatus.active,
                ),
              );
            });
          }(),
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
    final newSeed = await CycleSeedEditDialog.show(context, cycle);

    if (newSeed != null && mounted) {
      final investedAmount = cycle.seedAmount - cycle.remainingCash;
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
    // 보유 주식이 남아있으면 완료 차단
    if (cycle.totalShares > 0) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('사이클 완료 불가'),
          content: const Text(
            '보유 주식을 먼저 전량 매도해주세요.\n\n매도 완료 후 사이클을 종료할 수 있습니다.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('확인'),
            ),
          ],
        ),
      );
      return;
    }

    final confirmed = await ConfirmDialog.show(
      context: context,
      title: '사이클 완료',
      message: '사이클을 완료하시겠습니까?\n거래내역에 기록됩니다.',
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

  void _showSettingsSheet(Cycle cycle) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: context.appSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => CycleSettingsSheet(
        cycle: cycle,
        onSave: (updatedCycle) async {
          await ref.read(cycleListProvider.notifier).saveCycle(updatedCycle);
        },
      ),
    );
  }

}

/// 회차별 테두리 섹션 (N회차 · 날짜 라벨 + 둥근 카드)
class _TradeRoundSection extends StatelessWidget {
  final int roundNumber;
  final String dateStr;
  final Widget child;

  const _TradeRoundSection({
    required this.roundNumber,
    required this.dateStr,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 10),
      child: Stack(
        children: [
          // 테두리 카드 (상단 여백으로 라벨 공간 확보)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: context.appBorder),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: child,
              ),
            ),
          ),
          // 회차 라벨 (테두리 상단 선 위에 겹침)
          Positioned(
            left: 14,
            top: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: context.appSurface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: context.appBorder, width: 0.5),
              ),
              child: Text(
                '$roundNumber회차 · $dateStr',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: context.appTextSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
