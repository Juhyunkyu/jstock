import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/utils/krw_formatter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/cycle.dart';
import '../../../data/models/trade.dart';
import '../../../domain/trading/alpha_cycle_service.dart';
import '../../../domain/trading/trading_math.dart';
import '../../providers/providers.dart';
import '../../widgets/cycle/strategy_badge.dart';
import '../../widgets/cycle/signal_display.dart';
import '../../widgets/common/top_toast.dart';
import '../../widgets/shared/confirm_dialog.dart';
import '../holdings/widgets/profit_loss_section.dart';
import 'widgets/cycle_completed_view.dart';
import 'widgets/cycle_info_card.dart';
import 'widgets/cycle_initial_buy_guide.dart';
import 'widgets/steady_order_guide_card.dart';
import 'widgets/cycle_seed_edit_dialog.dart';
import 'widgets/cycle_trade_card.dart';
import 'widgets/cycle_trade_record_sheet.dart';
import 'widgets/ladder_trade_record_sheet.dart';
import 'widgets/steady_combined_trade_sheet.dart';
import 'widgets/cycle_settings_sheet.dart';
import 'widgets/ladder_detail_body.dart';

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
  bool _includeFxPnl = false; // 환차손익 포함 토글

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
    final isPendingCompletion = cycle.isPendingCompletion;
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

    // Smart Cycle: 진입가 기준 lossRate + 다음 신호 트리거
    final isSmartCycle = cycle.strategyType == StrategyType.alphaCycleV3;
    final effectiveEntryPrice = isSmartCycle
        ? ((cycle.entryPrice != null && cycle.entryPrice! > 0)
            ? cycle.entryPrice!
            : cycle.averagePrice)
        : 0.0;
    final hasEntry = isSmartCycle && effectiveEntryPrice > 0;
    final entryLossRate = (hasEntry && hasPosition)
        ? AlphaCycleService.lossRate(currentPrice, effectiveEntryPrice)
        : null;
    String? nextTriggerInfo;
    if (isSmartCycle && hasEntry && signal == TradeSignal.hold) {
      final triggerPrice = effectiveEntryPrice * (1 + cycle.weightedBuyThreshold / 100);
      nextTriggerInfo = '다음 신호: \$${triggerPrice.toStringAsFixed(2)} 이하 시 가중매수';
    }

    // === 완료 사이클은 결과 중심 레이아웃 ===
    if (cycle.status == CycleStatus.completed) {
      return Scaffold(
        backgroundColor: context.appBackground,
        appBar: _buildAppBar(context, cycle, allActive),
        body: CycleCompletedView(cycle: cycle, trades: trades, isMobile: isMobile),
      );
    }

    // (F-2) Ladder Cycle: 별도 body 위젯 사용
    if (cycle.strategyType == StrategyType.ladderCycle &&
        !isPendingCompletion) {
      return Scaffold(
        backgroundColor: context.appBackground,
        appBar: _buildAppBar(context, cycle, allActive),
        body: LadderDetailBody(cycleId: widget.cycleId),
        floatingActionButton: cycle.status == CycleStatus.active
            ? _buildFAB(context, cycle, signal, signalAmount, liveExchangeRate, isMobile)
            : null,
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

                    // === 신호 카드 (Smart/Ladder Cycle) ===
                    if (cycle.status == CycleStatus.active &&
                        cycle.strategyType != StrategyType.infiniteBuy) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: SignalDisplay(
                          signal: signal,
                          size: SignalDisplaySize.large,
                          amount: signalAmount,
                          lossRate: isSmartCycle ? entryLossRate : (hasPosition ? usdReturnRate : null),
                          nextTriggerInfo: nextTriggerInfo,
                          onConvertToHolding: (isSmartCycle && hasPosition)
                              ? () => _handleConvertToHolding(cycle)
                              : null,
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
    // Ladder 공격형: buyTicker를 AppBar에 표시
    final isLadderAggressive = cycle.strategyType == StrategyType.ladderCycle &&
        cycle.ladderMode != 0 &&
        cycle.buyTicker.isNotEmpty;
    final appBarTicker = isLadderAggressive ? cycle.buyTicker : cycle.ticker;

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
                appBarTicker,
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
            ladderMode: cycle.strategyType == StrategyType.ladderCycle
                ? cycle.ladderMode
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
              // (F-13) Ladder 전용: ATH 수정
              if (cycle.strategyType == StrategyType.ladderCycle)
                PopupMenuItem(
                  value: 'editAth',
                  child: Row(
                    children: [
                      Icon(Icons.trending_up, size: 20, color: context.appTextSecondary),
                      const SizedBox(width: 8),
                      Text('ATH 수정', style: TextStyle(color: context.appTextPrimary)),
                    ],
                  ),
                ),
              // (F-13) 익절 처리: Ladder가 아닌 경우에만 표시
              if (cycle.totalShares > 0 &&
                  cycle.strategyType != StrategyType.ladderCycle)
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
    return SizedBox(
      height: isMobile ? 36 : 40,
      child: FloatingActionButton.extended(
        onPressed: () => _showTradeDialog(
          context, cycle, signal, signalAmount, liveExchangeRate,
        ),
        backgroundColor: context.appAccent.withValues(alpha: 0.85),
        foregroundColor: Colors.white,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        elevation: 2,
        icon: Icon(Icons.add, size: isMobile ? 16 : 18),
        label: Text(
          '거래 기록',
          style: TextStyle(fontSize: isMobile ? 12 : 14, fontWeight: FontWeight.w600),
        ),
        extendedPadding: EdgeInsets.symmetric(horizontal: isMobile ? 14 : 18),
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
    // Ladder 공격형: buyTicker(SOXL) 가격 사용, 기타: cycle.ticker
    final isLadderAggressive = cycle.strategyType == StrategyType.ladderCycle &&
        cycle.ladderMode != 0 && cycle.buyTicker.isNotEmpty;
    final priceTicker = isLadderAggressive ? cycle.buyTicker : cycle.ticker;
    final price = prices[priceTicker];
    final quote = ref.read(stockQuoteProvider).quotes[priceTicker];

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

    // Ladder Cycle: LadderTradeRecordSheet (Phase 7)
    if (cycle.strategyType == StrategyType.ladderCycle) {
      showModalBottomSheet(
        context: context,
        useRootNavigator: true,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: context.appSurface,
        shape: const RoundedRectangleBorder(),
        builder: (context) => SizedBox(
          height: MediaQuery.sizeOf(context).height,
          child: LadderTradeRecordSheet(
            cycle: cycle,
            currentExchangeRate: liveExchangeRate,
            currentPrice: price,
            changePercent: quote?.changePercent,
            onSubmit: ({
              required isBuy,
              required signal,
              required price,
              required shares,
              required exchangeRate,
              required date,
              memo,
              ticker,
            }) {
              // 공격형 Ladder: ticker가 null이면 cycle.buyTicker 사용
              final effectiveTicker = ticker ??
                  (cycle.ladderMode != 0 && cycle.buyTicker.isNotEmpty
                      ? cycle.buyTicker
                      : null);
              if (isBuy) {
                final amountKrw = shares * price * exchangeRate;
                ref.read(tradeListProvider(widget.cycleId).notifier).recordBuy(
                      cycleId: widget.cycleId,
                      signal: signal,
                      price: price,
                      amountKrw: amountKrw,
                      exchangeRate: exchangeRate,
                      memo: memo,
                      ticker: effectiveTicker,
                    );
              } else {
                ref.read(tradeListProvider(widget.cycleId).notifier).recordSell(
                      cycleId: widget.cycleId,
                      signal: signal,
                      price: price,
                      shares: shares,
                      exchangeRate: exchangeRate,
                      memo: memo,
                      ticker: effectiveTicker,
                    );
              }
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
          onConvertToHolding: () => _handleConvertToHolding(cycle),
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
    final isProfit = netProfitKrw >= 0;

    // 평균 매수가/매도가 (USD)
    final totalBuyShares = buyTrades.fold<double>(0, (s, t) => s + t.shares);
    final totalBuyUsd = buyTrades.fold<double>(0, (s, t) => s + t.price * t.shares);
    final avgBuyPrice = totalBuyShares > 0 ? totalBuyUsd / totalBuyShares : 0.0;
    final totalSellShares = sellTrades.fold<double>(0, (s, t) => s + t.shares);
    final totalSellUsd = sellTrades.fold<double>(0, (s, t) => s + t.price * t.shares);
    final avgSellPrice = totalSellShares > 0 ? totalSellUsd / totalSellShares : 0.0;

    // 회차 수: Ladder는 currentStep, 나머지는 roundsUsed
    final isLadder = cycle.strategyType == StrategyType.ladderCycle;
    final roundCount = isLadder ? cycle.currentStep : cycle.roundsUsed;

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
            _pendingRow('설정시드', formatKrw(cycle.seedAmount), isMobile),
            const SizedBox(height: 6),
            _pendingRow('총 투자금', '${formatKrw(totalBuyKrw)}  (\$${cycle.totalBuyUsd.toStringAsFixed(2)})', isMobile),
            const SizedBox(height: 6),
            _pendingRow('총 회수금', '${formatKrw(totalSellKrw)}  (\$${cycle.totalSellUsd.toStringAsFixed(2)})', isMobile),
            const SizedBox(height: 6),

            // 외화 손익 (USD — 환율 무관, 고정)
            () {
              final fxProfitUsd = cycle.totalSellUsd - cycle.totalBuyUsd;
              final avgBuyRate = cycle.exchangeRateAtEntry;
              // 환차손익 = 보유달러 × (현재환율 - 매입환율)
              final fxPnl = fxProfitUsd * (liveExchangeRate - avgBuyRate);
              // 수익 (환차 미포함) = 외화손익 × 매입환율
              final profitWithoutFx = fxProfitUsd * avgBuyRate;
              // 수익 (환차 포함) = 외화손익 × 현재환율
              final profitWithFx = fxProfitUsd * liveExchangeRate;
              final displayProfit = _includeFxPnl ? profitWithFx : profitWithoutFx;
              final displayRate = totalBuyKrw > 0 ? (displayProfit / totalBuyKrw * 100) : 0.0;
              final isProfitDisplay = displayProfit >= 0;

              return Column(
                children: [
                  _pendingRow('외화 손익', '${fxProfitUsd >= 0 ? "+" : ""}\$${fxProfitUsd.toStringAsFixed(2)}', isMobile),
                  const SizedBox(height: 6),
                  // 수익 + 환차 체크박스
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('수익', style: TextStyle(fontSize: isMobile ? 12 : 13, color: Colors.white.withAlpha(180))),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${isProfitDisplay ? "+" : ""}${formatKrw(displayProfit)}  (${isProfitDisplay ? "+" : ""}${displayRate.toStringAsFixed(1)}%)',
                            style: TextStyle(
                              fontSize: isMobile ? 13 : 14,
                              fontWeight: FontWeight.w700,
                              color: isProfitDisplay ? AppColors.overlayGreen : AppColors.overlayRed,
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => setState(() => _includeFxPnl = !_includeFxPnl),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _includeFxPnl ? Icons.check_box : Icons.check_box_outline_blank,
                                  size: 16,
                                  color: Colors.white.withAlpha(180),
                                ),
                                const SizedBox(width: 3),
                                Text('환차', style: TextStyle(fontSize: 10, color: Colors.white.withAlpha(180))),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  // 환차 상세 (체크 시만 표시)
                  if (_includeFxPnl) ...[
                    const SizedBox(height: 4),
                    Text(
                      '매입환율 ₩${avgBuyRate.toStringAsFixed(0)} · 현재 ₩${liveExchangeRate.toStringAsFixed(0)} · 환차 ${fxPnl >= 0 ? "+" : ""}${formatKrw(fxPnl)}',
                      style: TextStyle(fontSize: 10, color: Colors.white.withAlpha(140)),
                    ),
                  ],
                ],
              );
            }(),
            SizedBox(height: isMobile ? 10 : 14),

            // 거래 상세 — Ladder 안정형은 멀티 티커이므로 평균가 대신 USD 합산 표시
            if (isLadder && cycle.ladderMode == 0) ...[
              _pendingRow('매수 합계', '\$${totalBuyUsd.toStringAsFixed(2)}', isMobile),
              const SizedBox(height: 6),
              _pendingRow('매도 합계', '\$${totalSellUsd.toStringAsFixed(2)}', isMobile),
              const SizedBox(height: 6),
            ] else ...[
              _pendingRow('평균 매수가', '\$${avgBuyPrice.toStringAsFixed(2)}', isMobile),
              const SizedBox(height: 6),
              _pendingRow('평균 매도가', '\$${avgSellPrice.toStringAsFixed(2)}', isMobile),
              const SizedBox(height: 6),
            ],
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
            _pendingRow(isLadder ? '진행 단계' : '총 회차', isLadder ? '$roundCount / ${cycle.ladderSteps}단계' : '$roundCount회차', isMobile),

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
              '잘못 기록했다면 아래 거래 내역에서 수정 가능합니다.',
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
      case 'editAth':
        _handleEditAth(cycle);
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

  Future<void> _handleConvertToHolding(Cycle cycle) async {
    if (cycle.totalShares <= 0) {
      if (!mounted) return;
      showErrorToast(context, '보유 주식이 없어 전환할 수 없습니다');
      return;
    }

    final holding = await ref.read(holdingListProvider.notifier).addHoldingWithValues(
      ticker: cycle.ticker,
      name: cycle.name,
      purchasePrice: cycle.averagePrice,
      quantity: cycle.totalShares.toInt(),
      purchaseExchangeRate: cycle.exchangeRateAtEntry,
      notes: 'Smart Cycle에서 전환',
      startDate: cycle.firstTradeDate ?? cycle.startDate,
    );

    await ref.read(cycleListProvider.notifier).completeCycle(widget.cycleId);

    if (!mounted) return;
    context.push('/holdings/${holding.id}');
  }

  Future<void> _handleEditSeed(Cycle cycle) async {
    final newSeed = await CycleSeedEditDialog.show(context, cycle);

    if (newSeed != null && mounted) {
      final investedAmount = cycle.seedAmount - cycle.remainingCash;
      cycle.seedAmount = newSeed;
      cycle.originalSeedAmount = newSeed;
      cycle.remainingCash = newSeed - investedAmount;
      await ref.read(cycleListProvider.notifier).saveCycle(cycle);
    }
  }

  Future<void> _handleEditAth(Cycle cycle) async {
    final controller = TextEditingController(
      text: cycle.athPrice > 0 ? cycle.athPrice.toStringAsFixed(2) : '',
    );

    final newAth = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.appSurface,
        title: Text(
          'ATH 가격 수정',
          style: TextStyle(fontSize: 16, color: context.appTextPrimary),
        ),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          style: TextStyle(color: context.appTextPrimary),
          decoration: InputDecoration(
            prefixText: '\$ ',
            prefixStyle: TextStyle(color: context.appTextPrimary),
            hintText: '예: 542.85',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('취소', style: TextStyle(color: context.appTextSecondary)),
          ),
          TextButton(
            onPressed: () {
              final val = double.tryParse(controller.text);
              if (val != null && val > 0) Navigator.pop(ctx, val);
            },
            child: Text('확인', style: TextStyle(color: context.appAccent)),
          ),
        ],
      ),
    );

    if (newAth != null && mounted) {
      cycle.athPrice = newAth;
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
          showErrorToast(context, '익절 처리 실패: $e');
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
