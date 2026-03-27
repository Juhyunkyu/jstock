import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

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
import 'steady_combined_trade_sheet.dart';

/// 사이클 거래 내역 카드
///
/// 보유(Holding)의 TransactionCard와 동일한 레이아웃 패턴:
/// Left(매수/매도 배지) + Center(날짜, 단가×수량, 신호 배지) + Right(USD, KRW, ⋮)
/// - 카드 탭 → 상세 BottomSheet
/// - ⋮ 버튼 → 옵션 BottomSheet (수정/삭제)
class CycleTradeCard extends ConsumerWidget {
  final Trade trade;
  final List<Trade>? groupedTrades; // 같은 groupId로 묶인 거래들
  final Cycle cycle;
  final bool isFirst;
  final bool isLast;
  final bool readOnly;

  const CycleTradeCard({
    super.key,
    required this.trade,
    this.groupedTrades,
    required this.cycle,
    this.isFirst = false,
    this.isLast = false,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 그룹화된 거래가 있으면 합쳐서 표시
    if (groupedTrades != null && groupedTrades!.length > 1) {
      return _buildGroupedCard(context, ref);
    }

    // ─── 단일 거래 카드 (그룹 스타일 통일) ───
    final isBuy = trade.action == TradeAction.buy;
    final isInitial = isBuy && trade.signal == TradeSignal.initial;
    final amountUsd = trade.price * trade.shares;
    final dateFormat = DateFormat('yyyy.MM.dd');
    final signalConfig = SignalBadgeConfig.fromSignal(trade.signal);

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

    return Container(
      margin: EdgeInsets.only(
        left: 16, right: 16,
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더: 배지 + 날짜 + 신호 + 금액 + ⋮
            Row(
              children: [
                // 거래 유형 배지
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 44, height: 36,
                      decoration: BoxDecoration(
                        color: typeBgColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(typeText, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: typeColor)),
                      ),
                    ),
                    if (isInitial)
                      Positioned(
                        top: -4, right: -4,
                        child: Container(
                          width: 16, height: 16,
                          decoration: BoxDecoration(color: typeColor, shape: BoxShape.circle),
                          child: const Icon(Icons.auto_awesome, size: 10, color: Colors.white),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(dateFormat.format(trade.tradedAt), style: TextStyle(fontSize: 12, color: context.appTextHint)),
                      const SizedBox(height: 2),
                      Text.rich(TextSpan(children: [
                        TextSpan(
                          text: signalConfig.label,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: context.appAccent),
                        ),
                        TextSpan(
                          text: '  \$${trade.price.toStringAsFixed(2)} × ${formatShares(trade.shares)}주',
                          style: TextStyle(fontSize: 11, color: context.appTextSecondary),
                        ),
                      ])),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('\$${amountUsd.toStringAsFixed(2)}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: context.appTextPrimary)),
                    Text(formatKrw(trade.amountKrw), style: TextStyle(fontSize: 11, color: context.appTextSecondary)),
                  ],
                ),
                // ⋮ 고정 폭 (readOnly면 빈 공간으로 정렬 유지)
                SizedBox(
                  width: 26,
                  child: !readOnly
                      ? GestureDetector(
                          onTap: () => _showTradeOptions(context, ref),
                          child: const Padding(
                            padding: EdgeInsets.only(left: 4),
                            child: Icon(Icons.more_vert_rounded, size: 18),
                          ),
                        )
                      : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 거래 상세 BottomSheet
  // ═══════════════════════════════════════════════════════════════

  Widget _buildGroupedCard(BuildContext context, WidgetRef ref) {
    final trades = groupedTrades!;
    final buyTrades = trades.where((t) => t.action == TradeAction.buy).toList();
    final sellTrades = trades.where((t) => t.action == TradeAction.sell).toList();
    final dateFormat = DateFormat('yyyy.MM.dd');

    // 매수 합계
    final totalBuyShares = buyTrades.fold<double>(0, (s, t) => s + t.shares);
    final totalBuyUsd = buyTrades.fold<double>(0, (s, t) => s + t.price * t.shares);
    final avgBuyPrice = totalBuyShares > 0 ? totalBuyUsd / totalBuyShares : 0.0;
    final totalBuyKrw = buyTrades.fold<double>(0, (s, t) => s + t.amountKrw);
    final buySignals = buyTrades.map((t) => SignalBadgeConfig.fromSignal(t.signal).label).toSet().join(' + ');

    // 매도 합계
    final totalSellShares = sellTrades.fold<double>(0, (s, t) => s + t.shares);
    final totalSellUsd = sellTrades.fold<double>(0, (s, t) => s + t.price * t.shares);
    final avgSellPrice = totalSellShares > 0 ? totalSellUsd / totalSellShares : 0.0;
    final totalSellKrw = sellTrades.fold<double>(0, (s, t) => s + t.amountKrw);
    final sellSignals = sellTrades.map((t) => SignalBadgeConfig.fromSignal(t.signal).label).toSet().join(' + ');

    // 주 헤더 = 매수 있으면 매수, 없으면 매도
    final hasBuy = buyTrades.isNotEmpty;
    final hasSell = sellTrades.isNotEmpty;
    final primaryIsBuy = hasBuy;
    final primaryColor = primaryIsBuy ? AppColors.buyAction : AppColors.sellAction;
    final primaryBg = primaryIsBuy ? AppColors.buyAction50 : AppColors.sellAction50;
    final primaryLabel = primaryIsBuy ? '매수' : '매도';
    final primarySignals = primaryIsBuy ? buySignals : sellSignals;
    final primaryUsd = primaryIsBuy ? totalBuyUsd : totalSellUsd;
    final primaryKrw = primaryIsBuy ? totalBuyKrw : totalSellKrw;

    // 상세 박스 빌더
    Widget buildDetailBox(List<Trade> items, double avgPrice, double totalShares, Color accentColor) {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: context.appBackground,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          children: [
            for (final t in items) ...[
              Row(
                children: [
                  Text(SignalBadgeConfig.fromSignal(t.signal).label,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: accentColor)),
                  const SizedBox(width: 8),
                  Text('\$${t.price.toStringAsFixed(2)} × ${formatShares(t.shares)}주',
                      style: TextStyle(fontSize: 11, color: context.appTextSecondary)),
                  const Spacer(),
                  Text('\$${(t.price * t.shares).toStringAsFixed(2)}',
                      style: TextStyle(fontSize: 11, color: context.appTextPrimary)),
                ],
              ),
              if (t != items.last) const SizedBox(height: 4),
            ],
            if (items.length > 1) ...[
              Divider(height: 12, color: context.appDivider),
              Row(
                children: [
                  Text('합계', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: context.appTextSecondary)),
                  const SizedBox(width: 8),
                  Text('평균 \$${avgPrice.toStringAsFixed(2)} × ${formatShares(totalShares)}주',
                      style: TextStyle(fontSize: 11, color: context.appTextSecondary)),
                ],
              ),
            ],
          ],
        ),
      );
    }

    // 헤더 Row 빌더
    Widget buildHeader({
      required String label, required Color color, required Color bgColor,
      String? dateStr, required String signals, required double usd, required double krw,
      bool showOptions = false,
    }) {
      return Row(
        children: [
          Container(
            width: 44, height: 36,
            decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8)),
            child: Center(child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color))),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (dateStr != null)
                  Text(dateStr, style: TextStyle(fontSize: 12, color: context.appTextHint))
                else
                  const SizedBox(height: 14), // 날짜 자리 빈공간 유지
                const SizedBox(height: 2),
                Text(signals, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: context.appAccent)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('\$${usd.toStringAsFixed(2)}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: context.appTextPrimary)),
              Text(formatKrw(krw), style: TextStyle(fontSize: 11, color: context.appTextSecondary)),
            ],
          ),
          // ⋮ 고정 폭 (showOptions 없어도 빈 공간으로 정렬 유지)
          SizedBox(
            width: 26,
            child: (showOptions && !readOnly)
                ? GestureDetector(
                    onTap: () => _showGroupedTradeOptions(context, ref, trades),
                    child: const Padding(
                      padding: EdgeInsets.only(left: 4),
                      child: Icon(Icons.more_vert_rounded, size: 18),
                    ),
                  )
                : null,
          ),
        ],
      );
    }

    return Container(
      margin: EdgeInsets.only(left: 16, right: 16, top: isFirst ? 0 : 3, bottom: isLast ? 0 : 3),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.appBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 주 헤더 (매수 우선, 없으면 매도)
            buildHeader(
              label: primaryLabel, color: primaryColor, bgColor: primaryBg,
              dateStr: dateFormat.format(trade.tradedAt),
              signals: primarySignals, usd: primaryUsd, krw: primaryKrw,
              showOptions: true,
            ),
            // 매수 상세 박스
            if (hasBuy) ...[
              const SizedBox(height: 8),
              buildDetailBox(buyTrades, avgBuyPrice, totalBuyShares, context.appAccent),
            ],
            // 매도 섹션 (매수+매도 혼합이면 별도 헤더)
            if (hasSell && hasBuy) ...[
              const SizedBox(height: 10),
              buildHeader(
                label: '매도', color: AppColors.sellAction, bgColor: AppColors.sellAction50,
                dateStr: null, // 날짜 중복 제거, 밑줄에 신호
                signals: sellSignals, usd: totalSellUsd, krw: totalSellKrw,
              ),
            ],
            // 매도 상세 박스
            if (hasSell) ...[
              const SizedBox(height: 8),
              buildDetailBox(sellTrades, avgSellPrice, totalSellShares, AppColors.sellAction),
            ],
          ],
        ),
      ),
    );
  }

  void _showGroupedTradeOptions(BuildContext context, WidgetRef ref, List<Trade> trades) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.appSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 전체 수정 (SteadyCombinedTradeSheet 편집 모드)
              ListTile(
                leading: Icon(Icons.edit_outlined, color: context.appAccent),
                title: Text('전체 수정', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.appTextPrimary)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showSteadyEditSheet(context, ref, trades);
                },
              ),
              const Divider(height: 1),
              // 전체 삭제
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppColors.red500),
                title: const Text('전체 삭제', style: TextStyle(fontSize: 14, color: AppColors.red500)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final confirmed = await ConfirmDialog.show(
                    context: context,
                    title: '거래 삭제',
                    message: '이 그룹의 거래 ${trades.length}건을 모두 삭제하시겠습니까?',
                    confirmText: '삭제',
                    isDanger: true,
                  );
                  if (confirmed) {
                    for (final t in trades) {
                      ref.read(tradeListProvider(cycle.id).notifier).deleteTradeAndRecalculate(t.id);
                    }
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Steady Cycle 전용 편집 시트 (단일 거래 + 그룹 거래 공통)
  void _showSteadyEditSheet(BuildContext context, WidgetRef ref, List<Trade> trades) {
    // groupId가 없으면 새로 생성 (단일 거래 → 그룹으로 승격)
    final groupId = trades.first.groupId ?? const Uuid().v4();

    // groupId가 없던 거래에 groupId 할당
    for (final t in trades) {
      if (t.groupId == null) {
        t.groupId = groupId;
        ref.read(tradeListProvider(cycle.id).notifier).updateTrade(t);
      }
    }

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: context.appSurface,
      shape: const RoundedRectangleBorder(),
      builder: (ctx) => SizedBox(
        height: MediaQuery.sizeOf(ctx).height,
        child: SteadyCombinedTradeSheet(
          cycle: cycle,
          currentExchangeRate: trades.first.exchangeRate,
          currentPrice: null,
          editingTrades: trades,
          editGroupId: groupId,
          onRecordBuy: ({required signal, required price, required shares, required exchangeRate, required date, memo, groupId}) async {},
          onRecordSell: ({required signal, required price, required shares, required exchangeRate, required date, memo, groupId}) async {},
          onReplaceTrades: ({required groupId, required newTrades}) async {
            await ref.read(tradeListProvider(cycle.id).notifier).replaceGroupedTrades(
              groupId: groupId,
              newTrades: newTrades,
            );
          },
        ),
      ),
    );
  }

  void _showTradeDetail(BuildContext context, double amountUsd) {
    final isBuy = trade.action == TradeAction.buy;
    final typeText = isBuy ? '매수' : '매도';
    final typeColor = isBuy ? AppColors.buyAction : AppColors.sellAction;
    final dateFormat = DateFormat('yyyy.MM.dd (E)', 'ko_KR');
    final signalConfig = SignalBadgeConfig.fromSignal(trade.signal);

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
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
      useRootNavigator: true,
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
                // Steady Cycle → SteadyCombinedTradeSheet 편집 모드
                if (cycle.strategyType == StrategyType.infiniteBuy) {
                  _showSteadyEditSheet(parentContext, ref, [trade]);
                } else {
                  _showEditTradeSheet(parentContext, ref);
                }
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

  void _showEditTradeSheet(BuildContext context, WidgetRef ref, {Trade? specificTrade}) {
    final editTarget = specificTrade ?? trade;
    final isBuy = editTarget.action == TradeAction.buy;

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
          currentExchangeRate: editTarget.exchangeRate,
          currentSignal: TradeSignal.hold,
          editingTrade: editTarget,
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
            editTarget.signal = signal;
            editTarget.price = price;
            editTarget.shares = shares;
            editTarget.exchangeRate = exchangeRate;
            editTarget.tradedAt = date;
            editTarget.memo = memo;

            editTarget.amountKrw = price * shares * exchangeRate;

            ref
                .read(tradeListProvider(cycle.id).notifier)
                .updateTrade(editTarget);
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

