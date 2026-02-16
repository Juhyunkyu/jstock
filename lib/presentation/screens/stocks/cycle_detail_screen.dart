import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/cycle.dart';
import '../../../data/models/trade.dart';
import '../../../domain/usecases/signal_detector.dart';
import '../../../domain/usecases/calculators/calculators.dart';
import '../../providers/api_providers.dart';
import '../../providers/cycle_providers.dart';
import '../../providers/trade_providers.dart';
import '../../widgets/stocks/profit_loss_gauge.dart';
import '../../widgets/stocks/buy_amount_display.dart';
import '../../widgets/shared/buy_signal_badge.dart';
import '../../widgets/shared/confirm_dialog.dart';

/// 사이클 상세 화면
class CycleDetailScreen extends ConsumerWidget {
  final String cycleId;

  const CycleDetailScreen({
    super.key,
    required this.cycleId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Provider에서 실제 데이터 가져오기
    final cycle = ref.watch(cycleByIdProvider(cycleId));

    if (cycle == null) {
      return Scaffold(
        backgroundColor: context.appBackground,
        appBar: AppBar(
          backgroundColor: AppColors.primary,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => context.pop(),
          ),
          title: const Text('사이클 상세', style: TextStyle(color: Colors.white)),
        ),
        body: const Center(
          child: Text('사이클을 찾을 수 없습니다.'),
        ),
      );
    }

    // stockQuoteProvider에서 실시간 시세 구독 (WebSocket 연동)
    final quoteState = ref.watch(stockQuoteProvider);
    final currentPrice = quoteState.quotes[cycle.ticker]?.currentPrice ?? cycle.averagePrice;
    final recommendation = SignalDetector.getRecommendation(cycle, currentPrice);
    final lossRate = LossCalculator.calculate(currentPrice, cycle.initialEntryPrice);
    final returnRate = ReturnCalculator.calculate(currentPrice, cycle.averagePrice);
    final trades = ref.watch(tradesForCycleProvider(cycleId));

    return Scaffold(
      backgroundColor: context.appBackground,
      body: CustomScrollView(
        slivers: [
          // 앱바
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: AppColors.primary,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => context.pop(),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.more_vert, color: Colors.white),
                onPressed: () => _showOptions(context, ref),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: _buildHeader(cycle, currentPrice, recommendation),
            ),
          ),

          // 컨텐츠
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 손익 게이지
                  _buildGaugeSection(context, cycle, lossRate, returnRate),
                  const SizedBox(height: 24),

                  // 매수 금액 표시
                  _buildBuyAmountSection(cycle, recommendation),
                  const SizedBox(height: 24),

                  // 포지션 정보
                  _buildPositionInfo(context, cycle, currentPrice),
                  const SizedBox(height: 24),

                  // 거래 내역
                  _buildTradeHistory(trades, context),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(
    Cycle cycle,
    double currentPrice,
    TradingRecommendation recommendation,
  ) {
    final priceChange = currentPrice - cycle.initialEntryPrice;
    final priceChangePercent = (priceChange / cycle.initialEntryPrice) * 100;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.primary,
            AppColors.primaryDark,
          ],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 60, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 종목 정보
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      cycle.ticker,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '#${cycle.cycleNumber}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                  const Spacer(),
                  BuySignalBadge(signal: recommendation.signal),
                ],
              ),
              const Spacer(),

              // 현재가
              Text(
                '\$${currentPrice.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    priceChange >= 0 ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                    color: priceChange >= 0 ? AppColors.green400 : AppColors.red400,
                    size: 24,
                  ),
                  Text(
                    '${priceChange >= 0 ? '+' : ''}\$${priceChange.toStringAsFixed(2)} '
                    '(${priceChangePercent >= 0 ? '+' : ''}${priceChangePercent.toStringAsFixed(2)}%)',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGaugeSection(BuildContext context, Cycle cycle, double lossRate, double returnRate) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '손익 현황',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: context.appTextPrimary,
            ),
          ),
          const SizedBox(height: 16),
          ProfitLossGauge(
            lossRate: lossRate,
            returnRate: returnRate,
            buyTrigger: cycle.buyTrigger,
            sellTrigger: cycle.sellTrigger,
            panicTrigger: cycle.panicTrigger,
            panicUsed: cycle.panicUsed,
          ),
        ],
      ),
    );
  }

  Widget _buildBuyAmountSection(Cycle cycle, TradingRecommendation recommendation) {
    final weightedAmount = WeightedBuyCalculator.calculate(
      cycle.initialEntryAmount,
      recommendation.lossRate,
    );
    final panicAmount = PanicBuyCalculator.calculate(cycle.initialEntryAmount);

    return BuyAmountDisplay(
      recommendation: recommendation,
      weightedBuyAmount: weightedAmount,
      panicBuyAmount: recommendation.signal == TradingSignal.panicBuy ? panicAmount : null,
      onRecordBuy: recommendation.needsAction
          ? () {
              // TODO: 매수/매도 기록 다이얼로그
            }
          : null,
    );
  }

  Widget _buildPositionInfo(BuildContext context, Cycle cycle, double currentPrice) {
    final stockValue = cycle.stockValue(currentPrice);
    final totalAsset = cycle.totalAsset(currentPrice);
    final profit = totalAsset - cycle.seedAmount;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '포지션 정보',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: context.appTextPrimary,
            ),
          ),
          const SizedBox(height: 16),
          _InfoRow(label: '평균 단가', value: '\$${cycle.averagePrice.toStringAsFixed(2)}'),
          _InfoRow(label: '보유 수량', value: '${cycle.totalShares.toStringAsFixed(2)}주'),
          _InfoRow(label: '주식 평가금', value: _formatKrw(stockValue)),
          _InfoRow(label: '잔여 현금', value: _formatKrw(cycle.remainingCash)),
          Divider(height: 24, color: context.appDivider),
          _InfoRow(label: '총 자산', value: _formatKrw(totalAsset), isBold: true),
          _InfoRow(
            label: '손익',
            value: '${profit >= 0 ? '+' : ''}${_formatKrw(profit)}',
            valueColor: profit >= 0 ? AppColors.green500 : AppColors.red500,
          ),
        ],
      ),
    );
  }

  Widget _buildTradeHistory(List<Trade> trades, BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '거래 내역',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: context.appTextPrimary,
                ),
              ),
              TextButton(
                onPressed: () {
                  // TODO: 전체 거래 내역으로 이동
                },
                child: const Text('전체보기'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (trades.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  '거래 내역이 없습니다.',
                  style: TextStyle(color: context.appTextSecondary),
                ),
              ),
            )
          else
            ...trades.take(5).map((trade) => _TradeItem(
              date: _formatDate(trade.date),
              action: trade.actionDisplayName,
              price: trade.price,
              shares: trade.shares,
              color: _getTradeColor(trade.action),
            )),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
  }

  Color _getTradeColor(TradeAction action) {
    switch (action) {
      case TradeAction.initialBuy:
        return AppColors.green500;
      case TradeAction.weightedBuy:
        return AppColors.blue500;
      case TradeAction.panicBuy:
        return AppColors.red500;
      case TradeAction.takeProfit:
        return AppColors.amber500;
    }
  }

  void _showOptions(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (bottomSheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('설정 수정'),
              onTap: () {
                Navigator.pop(bottomSheetContext);
                // TODO: 설정 수정
              },
            ),
            ListTile(
              leading: const Icon(Icons.stop_circle_outlined, color: AppColors.red500),
              title: const Text('사이클 종료', style: TextStyle(color: AppColors.red500)),
              onTap: () async {
                Navigator.pop(bottomSheetContext);
                await _confirmEndCycle(context, ref);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 사이클 종료 확인 다이얼로그를 표시하고 종료를 처리합니다.
  Future<void> _confirmEndCycle(BuildContext context, WidgetRef ref) async {
    final confirmed = await ConfirmDialog.show(
      context: context,
      title: '사이클 종료',
      message: '정말 이 사이클을 종료하시겠습니까?\n\n종료된 사이클은 다시 활성화할 수 없습니다.',
      cancelText: '취소',
      confirmText: '종료',
      isDanger: true,
    );

    if (confirmed && context.mounted) {
      // 사이클 종료 처리
      await ref.read(cycleListProvider.notifier).delete(cycleId);

      if (context.mounted) {
        // 상세 화면에서 뒤로 이동
        context.pop();

        // 성공 메시지 표시
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('사이클이 종료되었습니다.'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    }
  }

  String _formatKrw(double amount) {
    final intAmount = amount.round();
    final absAmount = intAmount.abs();
    final formatted = absAmount.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
    return intAmount < 0 ? '-$formatted원' : '$formatted원';
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;
  final Color? valueColor;

  const _InfoRow({
    required this.label,
    required this.value,
    this.isBold = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: context.appTextSecondary,
              fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isBold ? 16 : 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: valueColor ?? context.appTextPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _TradeItem extends StatelessWidget {
  final String date;
  final String action;
  final double price;
  final double shares;
  final Color color;

  const _TradeItem({
    required this.date,
    required this.action,
    required this.price,
    required this.shares,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  action,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: color,
                  ),
                ),
                Text(
                  date,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.appTextHint,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '\$${price.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: context.appTextPrimary,
                ),
              ),
              Text(
                '${shares.toStringAsFixed(2)}주',
                style: TextStyle(
                  fontSize: 12,
                  color: context.appTextSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
