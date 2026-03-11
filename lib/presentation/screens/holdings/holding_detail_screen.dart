import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/holding.dart';
import '../../providers/providers.dart';
import 'widgets/profit_loss_section.dart';
import 'widgets/holding_info_card.dart';
import 'widgets/transaction_list.dart';
import 'widgets/edit_holding_sheet.dart';
import 'widgets/trade_record_sheet.dart';

/// 보유 상세 화면
///
/// 개별 보유 종목의 상세 정보와 손익을 표시합니다.
class HoldingDetailScreen extends ConsumerStatefulWidget {
  final String holdingId;

  const HoldingDetailScreen({super.key, required this.holdingId});

  @override
  ConsumerState<HoldingDetailScreen> createState() => _HoldingDetailScreenState();
}

class _HoldingDetailScreenState extends ConsumerState<HoldingDetailScreen> {
  @override
  Widget build(BuildContext context) {
    ref.watch(transactionRefreshProvider); // 거래 기록 후 즉시 리빌드 트리거
    final holding = ref.watch(holdingByIdProvider(widget.holdingId));

    if (holding == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('보유 상세'),
          backgroundColor: context.appBackground,
        ),
        body: const Center(
          child: Text('보유 정보를 찾을 수 없습니다'),
        ),
      );
    }

    // 종가 기반 Provider (프리/애프터에서 previousClose 사용)
    final prices = ref.watch(closingPricesProvider);
    final currentPrice = prices[holding.ticker] ?? holding.averagePrice;
    final currentExchangeRate = ref.watch(currentExchangeRateProvider);
    final quoteState = ref.watch(stockQuoteProvider);
    final changePercent = quoteState.quotes[holding.ticker]?.changePercent;

    // 손익 계산
    final usdPL = holding.usdProfitLoss(currentPrice);
    final usdReturnRate = holding.usdReturnRate(currentPrice);
    final currencyPL = holding.currencyProfitLoss(currentExchangeRate);

    // 누적 실현손익 계산 (매도 거래의 realizedPnlKrw 합산)
    final transactions = ref.watch(holdingTransactionsProvider(widget.holdingId));
    final cumulativeRealizedPnl = transactions
        .where((tx) => tx.isSell && tx.realizedPnlKrw != null)
        .fold(0.0, (sum, tx) => sum + tx.realizedPnlKrw!);

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
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: context.appTextPrimary),
            onSelected: (value) => _handleMenuAction(value, holding),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined, size: 20),
                    SizedBox(width: 12),
                    Text('정보 수정'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'recalculate',
                child: Row(
                  children: [
                    Icon(Icons.refresh_outlined, size: 20, color: AppColors.blue500),
                    SizedBox(width: 12),
                    Text('거래 내역으로 재계산', style: TextStyle(color: AppColors.blue500)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, size: 20, color: AppColors.red500),
                    SizedBox(width: 12),
                    Text('삭제', style: TextStyle(color: AppColors.red500)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              children: [
                const SizedBox(height: 10),

                // 손익 요약 카드
                ProfitLossSummaryCard(
                  currentPrice: currentPrice,
                  currentExchangeRate: currentExchangeRate,
                  usdPL: usdPL,
                  usdReturnRate: usdReturnRate,
                  investedAmount: holding.totalInvestedAmount,
                  currencyPL: currencyPL,
                  quantity: holding.quantity,
                ),
                const SizedBox(height: 10),

                // 보유 정보 카드
                HoldingInfoCard(
                  holding: holding,
                  currentPrice: currentPrice,
                  currentExchangeRate: currentExchangeRate,
                  cumulativeRealizedPnlKrw: cumulativeRealizedPnl,
                ),
                const SizedBox(height: 16),

                // 거래 내역 헤더
                TransactionListHeader(holdingId: widget.holdingId),
                const SizedBox(height: 6),
              ],
            ),
          ),

          // 거래 내역 리스트
          TransactionListSection(holdingId: widget.holdingId),

          // 하단 여백
          const SliverToBoxAdapter(
            child: SizedBox(height: 80),
          ),
        ],
      ),
      floatingActionButton: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = MediaQuery.of(context).size.width < 600;
          if (isCompact) {
            return FloatingActionButton.small(
              onPressed: () => _showTradeDialog(context, holding),
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.add, color: Colors.white, size: 20),
            );
          }
          return FloatingActionButton.extended(
            onPressed: () => _showTradeDialog(context, holding),
            backgroundColor: AppColors.primary,
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text(
              '거래 기록',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          );
        },
      ),
    );
  }

  void _handleMenuAction(String action, Holding holding) {
    switch (action) {
      case 'edit':
        _showEditDialog(holding);
        break;
      case 'recalculate':
        _recalculateFromTransactions(holding);
        break;
      case 'delete':
        _showDeleteConfirmation(holding);
        break;
    }
  }

  Future<void> _recalculateFromTransactions(Holding holding) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('거래 내역으로 재계산'),
        content: Text(
          '${holding.ticker}의 보유 정보를 거래 내역 기준으로 재계산합니다.\n\n'
          '현재 보유 수량, 매입가, 투자금이 거래 내역 합계로 변경됩니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('재계산', style: TextStyle(color: AppColors.blue500)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(holdingListProvider.notifier).recalculateHoldingFromTransactions(holding.id);
      refreshTransactions(ref);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('거래 내역 기준으로 재계산되었습니다'),
            backgroundColor: AppColors.blue500,
          ),
        );
      }
    }
  }

  void _showEditDialog(Holding holding) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: context.appSurface,
      shape: const RoundedRectangleBorder(),
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height,
        child: EditHoldingSheet(holding: holding),
      ),
    );
  }

  Future<void> _showDeleteConfirmation(Holding holding) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('보유 삭제'),
        content: Text('${holding.ticker} 보유를 삭제하시겠습니까?\n모든 거래 내역도 함께 삭제됩니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('삭제', style: TextStyle(color: AppColors.red500)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(holdingListProvider.notifier).deleteHolding(holding.id);
      if (mounted) context.pop();
    }
  }

  void _showTradeDialog(BuildContext context, Holding holding) {
    final prices = ref.read(closingPricesProvider);
    final price = prices[holding.ticker];
    final rate = ref.read(currentExchangeRateProvider);
    final quote = ref.read(stockQuoteProvider).quotes[holding.ticker];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: context.appSurface,
      shape: const RoundedRectangleBorder(),
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height,
        child: TradeRecordSheet(
          holding: holding,
          currentExchangeRate: rate,
          currentPrice: price,
          changePercent: quote?.changePercent,
        ),
      ),
    );
  }
}
