import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/krw_formatter.dart';
import '../../../../core/utils/number_formatter.dart';
import '../../../../data/models/cycle.dart';
import '../../../../data/models/trade.dart';
import '../../../providers/providers.dart';
import '../../../widgets/shared/confirm_dialog.dart';
import '../../../widgets/shared/info_row.dart';
import '../../../widgets/shared/signal_badge_config.dart';
import 'cycle_trade_record_sheet.dart';

/// 사이클 거래 내역 카드
///
/// 보유(Holding)의 TransactionCard와 동일한 레이아웃 패턴:
/// Left(매수/매도 배지) + Center(날짜, 단가×수량, 신호 배지) + Right(USD, KRW, ⋮)
/// - 카드 탭 → 상세 BottomSheet
/// - ⋮ 버튼 → 옵션 BottomSheet (수정/삭제)
class CycleTradeCard extends ConsumerWidget {
  final Trade trade;
  final Cycle cycle;
  final bool isFirst;
  final bool isLast;
  final bool readOnly;

  const CycleTradeCard({
    super.key,
    required this.trade,
    required this.cycle,
    this.isFirst = false,
    this.isLast = false,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isBuy = trade.action == TradeAction.buy;
    final isInitial = isBuy && trade.signal == TradeSignal.initial;
    final amountUsd = trade.price * trade.shares;
    final dateFormat = DateFormat('yyyy.MM.dd');
    final signalConfig = SignalBadgeConfig.fromSignal(trade.signal);

    // 거래 유형별 색상
    final Color typeColor;
    final Color typeBgColor;
    final String typeText;

    if (isInitial) {
      typeColor = AppColors.initialBuy;
      typeBgColor = AppColors.initialBuy50;
      typeText = '첫매수';
    } else if (isBuy) {
      typeColor = AppColors.buyAction;
      typeBgColor = AppColors.buyAction50;
      typeText = '매수';
    } else {
      typeColor = AppColors.sellAction;
      typeBgColor = AppColors.sellAction50;
      typeText = '매도';
    }

    return GestureDetector(
      onTap: () => _showTradeDetail(context, amountUsd),
      child: Container(
        margin: EdgeInsets.only(
          left: 16,
          right: 16,
          top: isFirst ? 0 : 3,
          bottom: isLast ? 0 : 3,
        ),
        decoration: BoxDecoration(
          color: context.appSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: context.appBorder),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              // === 거래 유형 배지 (44x36) ===
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 44,
                    height: 36,
                    decoration: BoxDecoration(
                      color: typeBgColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        typeText,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: typeColor,
                        ),
                      ),
                    ),
                  ),
                  // 초기진입 스파클 아이콘
                  if (isInitial)
                    Positioned(
                      top: -4,
                      right: -4,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: typeColor,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.auto_awesome,
                          size: 10,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 10),

              // === 거래 정보 (날짜, 단가×수량, 신호 배지) ===
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 날짜
                    Text(
                      dateFormat.format(trade.tradedAt),
                      style: TextStyle(
                        fontSize: 13,
                        color: context.appTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // 단가 × 수량
                    Text(
                      '\$${trade.price.toStringAsFixed(2)} x ${formatShares(trade.shares)}주',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: context.appTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // 신호 배지
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: signalConfig.color.withValues(
                          alpha: context.isDarkMode ? 0.15 : 0.08,
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        signalConfig.label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: signalConfig.color,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // === 거래 금액 (USD, KRW) ===
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '\$${amountUsd.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: context.appTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formatKrw(trade.amountKrw),
                    style: TextStyle(
                      fontSize: 12,
                      color: context.appTextSecondary,
                    ),
                  ),
                ],
              ),

              // === ⋮ 옵션 버튼 ===
              if (!readOnly) ...[
                const SizedBox(width: 8),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _showTradeOptions(context, ref),
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        Icons.more_vert_rounded,
                        color: context.appTextHint,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 거래 상세 BottomSheet
  // ═══════════════════════════════════════════════════════════════

  void _showTradeDetail(BuildContext context, double amountUsd) {
    final isBuy = trade.action == TradeAction.buy;
    final typeText = isBuy ? '매수' : '매도';
    final typeColor = isBuy ? AppColors.buyAction : AppColors.sellAction;
    final dateFormat = DateFormat('yyyy.MM.dd (E)', 'ko_KR');
    final signalConfig = SignalBadgeConfig.fromSignal(trade.signal);

    showModalBottomSheet(
      context: context,
      backgroundColor: context.appSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 헤더: 매수/매도 배지 + 날짜 + 닫기
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: typeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        typeText,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: typeColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      dateFormat.format(trade.tradedAt),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: context.appTextPrimary,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),

            // 상세 정보
            InfoRow(flexible: true, fontSize: 14,label: '단가', value: '\$${trade.price.toStringAsFixed(2)}'),
            const SizedBox(height: 10),
            InfoRow(flexible: true, fontSize: 14,
              label: '수량',
              value: '${formatShares(trade.shares)}주',
            ),
            const SizedBox(height: 10),
            InfoRow(flexible: true, fontSize: 14,
              label: '거래금액 (USD)',
              value: '\$${amountUsd.toStringAsFixed(2)}',
            ),
            const SizedBox(height: 10),
            InfoRow(flexible: true, fontSize: 14,
              label: '거래금액 (원)',
              value: formatKrw(trade.amountKrw),
            ),
            const SizedBox(height: 10),
            InfoRow(flexible: true, fontSize: 14,
              label: '평균매입환율',
              value: '₩${cycle.exchangeRateAtEntry.toStringAsFixed(0)} / \$1',
            ),
            const SizedBox(height: 10),
            // 신호
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '신호',
                  style: TextStyle(
                    fontSize: 14,
                    color: context.appTextSecondary,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: signalConfig.color.withValues(
                      alpha: context.isDarkMode ? 0.15 : 0.08,
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    signalConfig.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: signalConfig.color,
                    ),
                  ),
                ),
              ],
            ),
            if (trade.memo != null && trade.memo!.isNotEmpty) ...[
              const SizedBox(height: 10),
              InfoRow(flexible: true, fontSize: 14,label: '메모', value: trade.memo!),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 옵션 BottomSheet (수정/삭제)
  // ═══════════════════════════════════════════════════════════════

  void _showTradeOptions(BuildContext context, WidgetRef ref) {
    final parentContext = context; // 부모 context 캡처 (bottom sheet pop 후에도 유효)
    showModalBottomSheet(
      context: context,
      backgroundColor: context.appSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: sheetContext.appDivider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            // 수정
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.blue50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.edit_outlined, color: AppColors.blue500),
              ),
              title: const Text('수정'),
              subtitle: const Text('거래 정보를 수정합니다'),
              onTap: () {
                Navigator.pop(sheetContext);
                _showEditTradeSheet(parentContext, ref);
              },
            ),
            const SizedBox(height: 8),
            // 삭제
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.red50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.delete_outline, color: AppColors.red500),
              ),
              title: const Text('삭제', style: TextStyle(color: AppColors.red500)),
              subtitle: const Text('거래 내역을 삭제합니다'),
              onTap: () async {
                Navigator.pop(sheetContext);
                await _handleDeleteTrade(parentContext, ref);
              },
            ),
            SizedBox(height: MediaQuery.of(sheetContext).padding.bottom + 8),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 수정 시트
  // ═══════════════════════════════════════════════════════════════

  void _showEditTradeSheet(BuildContext context, WidgetRef ref) {
    final isBuy = trade.action == TradeAction.buy;

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
          currentExchangeRate: trade.exchangeRate,
          currentSignal: TradeSignal.hold,
          editingTrade: trade,
          editTitle: isBuy ? '매수 기록 수정' : '매도 기록 수정',
          onSubmit: ({
            required bool isBuy,
            required TradeSignal signal,
            required double price,
            required double shares,
            required double exchangeRate,
            required DateTime date,
            String? memo,
            double extraFundingAmount = 0,
          }) {
            trade.signal = signal;
            trade.price = price;
            trade.shares = shares;
            trade.exchangeRate = exchangeRate;
            trade.memo = memo;

            trade.amountKrw = price * shares * exchangeRate;

            ref
                .read(tradeListProvider(cycle.id).notifier)
                .updateTrade(trade);
          },
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 삭제 핸들러
  // ═══════════════════════════════════════════════════════════════

  Future<void> _handleDeleteTrade(BuildContext context, WidgetRef ref) async {
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

    if (confirmed && context.mounted) {
      await ref
          .read(tradeListProvider(cycle.id).notifier)
          .deleteTradeAndRecalculate(trade.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('거래 내역이 삭제되었습니다'),
            backgroundColor: AppColors.secondary,
          ),
        );
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // 전략별 신호 리스트
  // ═══════════════════════════════════════════════════════════════

  static List<TradeSignal> buySignalsFor(StrategyType type, {SteadyVersion? steadyVersion}) {
    if (type == StrategyType.alphaCycleV3) {
      return [TradeSignal.initial, TradeSignal.weightedBuy, TradeSignal.panicBuy, TradeSignal.manual];
    }
    // Steady Cycle
    if (steadyVersion == SteadyVersion.v2_2 || steadyVersion == SteadyVersion.v3_0) {
      return [TradeSignal.locAB, TradeSignal.locA, TradeSignal.locB, TradeSignal.buySingle, TradeSignal.manual];
    }
    return [TradeSignal.locAB, TradeSignal.locB, TradeSignal.manual]; // V1
  }

  static List<TradeSignal> sellSignalsFor(StrategyType type, {SteadyVersion? steadyVersion}) {
    if (type == StrategyType.alphaCycleV3) {
      return [TradeSignal.cashSecure, TradeSignal.takeProfit, TradeSignal.manual];
    }
    if (steadyVersion == SteadyVersion.v2_2 || steadyVersion == SteadyVersion.v3_0) {
      return [TradeSignal.sellLocQuarter, TradeSignal.sellLimitThreeQ, TradeSignal.takeProfitFull, TradeSignal.takeProfit, TradeSignal.manual];
    }
    return [TradeSignal.takeProfit, TradeSignal.manual]; // V1
  }
}

