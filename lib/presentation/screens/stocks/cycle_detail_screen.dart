import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/krw_formatter.dart';
import '../../../core/utils/number_formatter.dart';
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
import '../../widgets/stocks/trade_record_sheet.dart';

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
    final cycle = ref.watch(cycleListProvider.select(
      (cycles) => cycles.where((c) => c.id == widget.cycleId).firstOrNull,
    ));

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

    final currentPrice = ref.watch(
      currentPricesProvider.select((prices) => prices[cycle.ticker] ?? 0.0),
    );
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

    final hasPosition = cycle.totalShares > 0 && cycle.averagePrice > 0;
    final lossRate = hasPosition
        ? TradingMath.returnRate(currentPrice, cycle.averagePrice)
        : null;
    final returnRate = lossRate ?? 0.0;

    // trades는 repository에서 이미 날짜 내림차순 정렬됨
    final sortedTrades = trades;

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
            _buildTradeHistorySection(context, sortedTrades, cycle),
            const SizedBox(height: 20),

            // === 액션 버튼 (active 사이클만) ===
            if (cycle.status == CycleStatus.active)
              _buildActionButtons(
                context,
                cycle,
                signal,
                signalAmount,
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
                value: 'editSeed',
                child: Row(
                  children: [
                    Icon(
                      Icons.edit_outlined,
                      size: 20,
                      color: context.appTextSecondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '시드 수정',
                      style: TextStyle(color: context.appTextPrimary),
                    ),
                  ],
                ),
              ),
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
  // 헤더 섹션 (1A: 리디자인)
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
        boxShadow: context.appCardShadow,
      ),
      child: Row(
        children: [
          // 왼쪽: 로고 + 티커/사이클명
          TickerLogo(
            ticker: cycle.ticker,
            size: 44,
            borderRadius: 12,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cycle.ticker,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: context.appTickerColor,
                  ),
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
          const SizedBox(width: 12),
          // 오른쪽: 현재가 + 수익률 배지
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (currentPrice > 0)
                Text(
                  '\$${currentPrice.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: context.appTextPrimary,
                  ),
                ),
              const SizedBox(height: 4),
              if (cycle.totalShares > 0)
                ReturnBadge(
                  value: returnRate,
                  colorScheme: ReturnBadgeColorScheme.greenRed,
                  size: ReturnBadgeSize.small,
                )
              else if (cycle.status == CycleStatus.completed)
                ReturnBadge(
                  value: cycle.completedReturnRate,
                  nullLabel: '완료',
                  colorScheme: ReturnBadgeColorScheme.greenRed,
                  size: ReturnBadgeSize.small,
                )
              else
                ReturnBadge(
                  value: null,
                  nullLabel: '대기',
                  size: ReturnBadgeSize.small,
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
        boxShadow: context.appCardShadow,
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

  Widget _buildTradeHistorySection(BuildContext context, List<Trade> trades, Cycle cycle) {
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
          ...trades.map((trade) => _buildTradeCard(context, trade, cycle)),
      ],
    );
  }

  Widget _buildTradeCard(BuildContext context, Trade trade, Cycle cycle) {
    final isBuy = trade.action == TradeAction.buy;
    final actionColor = isBuy ? AppColors.red500 : AppColors.blue500;
    final actionLabel = isBuy ? '매수' : '매도';
    final signalConfig = SignalBadgeConfig.fromSignal(trade.signal);
    final dateStr = formatDateDot(trade.tradedAt);
    final exchangeRateStr = '환율 ₩${_formatExchangeRate(trade.exchangeRate)}';

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
          // 상단: 액션 + 신호 배지 + 날짜 + 편집/삭제
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
              const SizedBox(width: 4),
              // 편집 버튼
              SizedBox(
                width: 28,
                height: 28,
                child: IconButton(
                  onPressed: () => _showEditTradeSheet(context, trade, cycle),
                  icon: Icon(
                    Icons.edit_outlined,
                    size: 16,
                    color: context.appTextHint,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  splashRadius: 16,
                  tooltip: '수정',
                ),
              ),
              // 삭제 버튼
              SizedBox(
                width: 28,
                height: 28,
                child: IconButton(
                  onPressed: () => _handleDeleteTrade(context, trade),
                  icon: Icon(
                    Icons.delete_outline,
                    size: 16,
                    color: context.appTextHint,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  splashRadius: 16,
                  tooltip: '삭제',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 가격 x 수량 = 금액
          Text(
            '\$${trade.price.toStringAsFixed(2)} x ${formatShares(trade.shares)}주 = ${formatKrwWithComma(trade.amountKrw)}\u2009원',
            style: TextStyle(
              fontSize: 13,
              color: context.appTextPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          // 환율 표시
          Text(
            exchangeRateStr,
            style: TextStyle(
              fontSize: 11,
              color: context.appTextHint,
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
  // 거래 편집/삭제 핸들러
  // ═══════════════════════════════════════════════════════════════

  void _showEditTradeSheet(BuildContext context, Trade trade, Cycle cycle) {
    final isBuy = trade.action == TradeAction.buy;
    final signals = isBuy
        ? _buySignalsFor(cycle.strategyType)
        : _sellSignalsFor(cycle.strategyType);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.appCardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => TradeRecordSheet(
        title: isBuy ? '매수 기록 수정' : '매도 기록 수정',
        action: trade.action,
        cycleId: widget.cycleId,
        signals: signals,
        exchangeRate: trade.exchangeRate,
        maxCash: isBuy ? cycle.remainingCash + trade.amountKrw : null,
        maxShares: isBuy ? null : cycle.totalShares + trade.shares,
        editingTrade: trade,
        onSubmit: (signal, price, amount, shares, exchangeRate, memo,
            {double extraFundingAmount = 0}) {
          // 기존 Trade 객체의 필드를 업데이트
          trade.signal = signal;
          trade.price = price;
          trade.exchangeRate = exchangeRate;
          trade.memo = memo;

          if (isBuy) {
            final newShares = amount! / (price * exchangeRate);
            trade.amountKrw = amount;
            trade.shares = newShares;
          } else {
            trade.shares = shares!;
            trade.amountKrw = shares * price * exchangeRate;
          }

          ref
              .read(tradeListProvider(widget.cycleId).notifier)
              .updateTrade(trade);
        },
      ),
    );
  }

  Future<void> _handleDeleteTrade(BuildContext context, Trade trade) async {
    final isBuy = trade.action == TradeAction.buy;
    final actionLabel = isBuy ? '매수' : '매도';

    final confirmed = await ConfirmDialog.show(
      context: context,
      title: '거래 기록 삭제',
      message:
          '$actionLabel 기록을 삭제하시겠습니까?\n(\$${trade.price.toStringAsFixed(2)} x ${formatShares(trade.shares)}주)\n\n삭제 후 사이클 상태가 재계산됩니다.',
      confirmText: '삭제',
      isDanger: true,
    );

    if (confirmed && mounted) {
      await ref
          .read(tradeListProvider(widget.cycleId).notifier)
          .deleteTradeAndRecalculate(trade.id);
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // 액션 버튼 (1B: 조건부 매수 버튼)
  // ═══════════════════════════════════════════════════════════════

  Widget _buildActionButtons(
    BuildContext context,
    Cycle cycle,
    TradeSignal signal,
    double? signalAmount,
    double currentPrice,
    double liveExchangeRate,
    double returnRate,
  ) {
    return Column(
      children: [
        // === 매수 버튼 영역 ===
        _buildBuyButtons(context, cycle, signal, signalAmount, liveExchangeRate),
        const SizedBox(height: 10),

        // === 매도 + 익절/완료 영역 ===
        Row(
          children: [
            // 매도 기록
            Expanded(
              child: OutlinedButton.icon(
                onPressed: cycle.totalShares > 0
                    ? () => _showSellSheet(context, cycle, liveExchangeRate)
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
            const SizedBox(width: 10),
            // 익절 또는 사이클 완료
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
              )
            else
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

  /// 전략 및 상태별 매수 버튼 빌드
  Widget _buildBuyButtons(
    BuildContext context,
    Cycle cycle,
    TradeSignal signal,
    double? signalAmount,
    double liveExchangeRate,
  ) {
    final isStrategyA = cycle.strategyType == StrategyType.alphaCycleV3;

    if (isStrategyA) {
      return _buildStrategyABuyButtons(
          context, cycle, signal, signalAmount, liveExchangeRate);
    } else {
      return _buildStrategyBBuyButtons(
          context, cycle, signal, signalAmount, liveExchangeRate);
    }
  }

  /// Strategy A (Alpha Cycle V3) 매수 버튼
  Widget _buildStrategyABuyButtons(
    BuildContext context,
    Cycle cycle,
    TradeSignal signal,
    double? signalAmount,
    double liveExchangeRate,
  ) {
    // 첫 매수 전 (totalShares == 0)
    if (cycle.totalShares == 0) {
      final initialAmount = cycle.initialEntryAmount;
      return SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: () => _showBuySheet(
            context,
            cycle,
            liveExchangeRate,
            preSelectedSignal: TradeSignal.initial,
            preFilledAmount: initialAmount,
          ),
          icon: const Icon(Icons.play_arrow, size: 18),
          label: Text('초기진입 ${formatKrwWithComma(initialAmount)}원'),
          style: _buyButtonStyle(AppColors.green600),
        ),
      );
    }

    // 첫 매수 후 — 신호별 버튼 + 수동 매수
    final buttons = <Widget>[];

    // 가중매수 신호
    if (signal == TradeSignal.weightedBuy && signalAmount != null) {
      buttons.add(
        Expanded(
          child: FilledButton.icon(
            onPressed: () => _showBuySheet(
              context,
              cycle,
              liveExchangeRate,
              preSelectedSignal: TradeSignal.weightedBuy,
              preFilledAmount: signalAmount,
            ),
            icon: const Icon(Icons.add_chart, size: 18),
            label: Text(
              '가중매수 ${formatKrwWithComma(signalAmount)}원',
              overflow: TextOverflow.ellipsis,
            ),
            style: _buyButtonStyle(AppColors.amber500),
          ),
        ),
      );
    }

    // 승부수 신호
    if (signal == TradeSignal.panicBuy && signalAmount != null) {
      buttons.add(
        Expanded(
          child: FilledButton.icon(
            onPressed: () => _showBuySheet(
              context,
              cycle,
              liveExchangeRate,
              preSelectedSignal: TradeSignal.panicBuy,
              preFilledAmount: signalAmount,
            ),
            icon: const Icon(Icons.local_fire_department, size: 18),
            label: Text(
              '승부수 ${formatKrwWithComma(signalAmount)}원',
              overflow: TextOverflow.ellipsis,
            ),
            style: _buyButtonStyle(AppColors.red500),
          ),
        ),
      );
    }

    // 수동 매수 (항상 표시)
    if (buttons.isNotEmpty) {
      buttons.add(const SizedBox(width: 10));
    }
    buttons.add(
      Expanded(
        child: OutlinedButton.icon(
          onPressed: () => _showBuySheet(context, cycle, liveExchangeRate),
          icon: const Icon(Icons.edit, size: 18),
          label: const Text('수동 매수'),
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
    );

    return Row(children: buttons);
  }

  /// Strategy B (Steady Cycle) 매수 버튼
  Widget _buildStrategyBBuyButtons(
    BuildContext context,
    Cycle cycle,
    TradeSignal signal,
    double? signalAmount,
    double liveExchangeRate,
  ) {
    // 첫 매수 전
    if (cycle.totalShares == 0) {
      final unitAmount = cycle.unitAmount;
      return SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: () => _showBuySheet(
            context,
            cycle,
            liveExchangeRate,
            preSelectedSignal: TradeSignal.locAB,
            preFilledAmount: unitAmount,
          ),
          icon: const Icon(Icons.play_arrow, size: 18),
          label: Text('첫 매수 ${formatKrwWithComma(unitAmount)}원'),
          style: _buyButtonStyle(AppColors.green600),
        ),
      );
    }

    // 첫 매수 후 — 신호별 버튼 + 수동 매수
    final buttons = <Widget>[];

    // LOC A+B 신호
    if (signal == TradeSignal.locAB && signalAmount != null) {
      buttons.add(
        Expanded(
          child: FilledButton.icon(
            onPressed: () => _showBuySheet(
              context,
              cycle,
              liveExchangeRate,
              preSelectedSignal: TradeSignal.locAB,
              preFilledAmount: signalAmount,
            ),
            icon: const Icon(Icons.double_arrow, size: 18),
            label: Text(
              '매수 ${formatKrwWithComma(signalAmount)}원',
              overflow: TextOverflow.ellipsis,
            ),
            style: _buyButtonStyle(AppColors.amber500),
          ),
        ),
      );
    }

    // LOC B 신호
    if (signal == TradeSignal.locB && signalAmount != null) {
      buttons.add(
        Expanded(
          child: FilledButton.icon(
            onPressed: () => _showBuySheet(
              context,
              cycle,
              liveExchangeRate,
              preSelectedSignal: TradeSignal.locB,
              preFilledAmount: signalAmount,
            ),
            icon: const Icon(Icons.arrow_forward, size: 18),
            label: Text(
              '매수 ${formatKrwWithComma(signalAmount)}원',
              overflow: TextOverflow.ellipsis,
            ),
            style: _buyButtonStyle(AppColors.blue500),
          ),
        ),
      );
    }

    // 수동 매수 (항상 표시)
    if (buttons.isNotEmpty) {
      buttons.add(const SizedBox(width: 10));
    }
    buttons.add(
      Expanded(
        child: OutlinedButton.icon(
          onPressed: () => _showBuySheet(context, cycle, liveExchangeRate),
          icon: const Icon(Icons.edit, size: 18),
          label: const Text('수동 매수'),
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
    );

    return Row(children: buttons);
  }

  // ═══════════════════════════════════════════════════════════════
  // 매수 기록 BottomSheet
  // ═══════════════════════════════════════════════════════════════

  void _showBuySheet(
    BuildContext context,
    Cycle cycle,
    double liveExchangeRate, {
    TradeSignal? preSelectedSignal,
    double? preFilledAmount,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.appCardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => TradeRecordSheet(
        title: '매수 기록',
        action: TradeAction.buy,
        cycleId: widget.cycleId,
        signals: _buySignalsFor(cycle.strategyType),
        exchangeRate: liveExchangeRate,
        maxCash: cycle.remainingCash,
        maxShares: null,
        preSelectedSignal: preSelectedSignal,
        preFilledAmount: preFilledAmount,
        onSubmit: (signal, price, amount, shares, exchangeRate, memo,
            {double extraFundingAmount = 0}) {
          ref.read(tradeListProvider(widget.cycleId).notifier).recordBuy(
                cycleId: widget.cycleId,
                signal: signal,
                price: price,
                amountKrw: amount!,
                exchangeRate: exchangeRate,
                memo: memo,
                extraFundingAmount: extraFundingAmount,
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.appCardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => TradeRecordSheet(
        title: '매도 기록',
        action: TradeAction.sell,
        cycleId: widget.cycleId,
        signals: _sellSignalsFor(cycle.strategyType),
        exchangeRate: liveExchangeRate,
        maxCash: null,
        maxShares: cycle.totalShares,
        onSubmit: (signal, price, amount, shares, exchangeRate, memo,
            {double extraFundingAmount = 0}) {
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
      case 'editSeed':
        _handleEditSeed(cycle);
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

  // ═══════════════════════════════════════════════════════════════
  // 전략별 신호 리스트 (중앙 정의)
  // ═══════════════════════════════════════════════════════════════

  static List<TradeSignal> _buySignalsFor(StrategyType type) =>
      type == StrategyType.alphaCycleV3
          ? [TradeSignal.initial, TradeSignal.weightedBuy, TradeSignal.panicBuy, TradeSignal.manual]
          : [TradeSignal.locAB, TradeSignal.locB, TradeSignal.manual];

  static List<TradeSignal> _sellSignalsFor(StrategyType type) =>
      type == StrategyType.alphaCycleV3
          ? [TradeSignal.cashSecure, TradeSignal.takeProfit, TradeSignal.manual]
          : [TradeSignal.takeProfit, TradeSignal.manual];

  // ═══════════════════════════════════════════════════════════════
  // 유틸
  // ═══════════════════════════════════════════════════════════════

  /// 매수 버튼 공통 스타일
  static ButtonStyle _buyButtonStyle(Color color) => FilledButton.styleFrom(
    backgroundColor: color,
    foregroundColor: Colors.white,
    padding: const EdgeInsets.symmetric(vertical: 14),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
  );

  String _formatExchangeRate(double rate) {
    // 천 단위 구분자 포함 소수점 2자리
    final parts = rate.toStringAsFixed(2).split('.');
    final intPart = parts[0];
    final decPart = parts[1];
    final buffer = StringBuffer();
    for (int i = 0; i < intPart.length; i++) {
      if (i > 0 && (intPart.length - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(intPart[i]);
    }
    return '$buffer.$decPart';
  }
}
