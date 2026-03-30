import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/krw_formatter.dart';
import '../../../../data/models/cycle.dart';
import '../../../../data/models/trade.dart';
import '../../../providers/providers.dart';
import '../../../widgets/shared/info_row.dart';
import 'cycle_trade_card.dart';

/// 완료 사이클 전용 레이아웃
///
/// 결과 카드(그라데이션) + 정보 카드 + 거래 내역 (읽기전용)
class CycleCompletedView extends ConsumerWidget {
  final Cycle cycle;
  final List<Trade> trades;
  final bool isMobile;

  const CycleCompletedView({
    super.key,
    required this.cycle,
    required this.trades,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final realizedResult = ref.watch(cycleRealizedPnlProvider(cycle.id));
    final pnl = realizedResult?.pnlKrw ?? 0.0;
    final returnPercent = realizedResult?.returnPercent ?? 0.0;
    final totalBuyKrw = realizedResult?.totalBuyKrw ?? 0.0;
    final totalSellKrw = realizedResult?.totalSellKrw ?? 0.0;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: isMobile ? 8 : 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // === 사이클 결과 카드 (그라데이션) ===
                _buildCompletedResultCard(
                  context, pnl, returnPercent, totalBuyKrw, totalSellKrw,
                ),
                SizedBox(height: isMobile ? 10 : 16),

                // === 사이클 정보 ===
                _buildCompletedInfoCard(context, ref),
                SizedBox(height: isMobile ? 14 : 20),

                // === 거래 내역 ===
                _buildTradeHistorySection(context),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 결과 카드 (그라데이션)
  // ═══════════════════════════════════════════════════════════════

  Widget _buildCompletedResultCard(
    BuildContext context,
    double pnl,
    double returnPercent,
    double totalBuyKrw,
    double totalSellKrw,
  ) {
    final isProfit = pnl >= 0;
    // 다크 톤 그라데이션 — 고급스럽게
    final gradientColors = isProfit
        ? [const Color(0xFF2D1B1B), const Color(0xFF3D1F1F)]
        : [const Color(0xFF1B2230), const Color(0xFF1A2740)];
    final accentColor = isProfit ? AppColors.red500 : AppColors.blue500;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // 헤더 + 금액 한 줄
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '사이클 결과',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ),
              const Spacer(),
              Text(
                '${isProfit ? '+' : ''}${formatKrwWithComma(pnl.round().toDouble())}원',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${isProfit ? '+' : ''}${returnPercent.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: accentColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 구분선
          Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.08),
          ),
          const SizedBox(height: 10),

          // 총 매수 / 총 매도 / 순 수익
          _buildResultRow('총 매수', formatKrwWithComma(totalBuyKrw.round().toDouble())),
          const SizedBox(height: 4),
          _buildResultRow('총 매도', formatKrwWithComma(totalSellKrw.round().toDouble())),
          const SizedBox(height: 4),
          _buildResultRow(
            '순 수익',
            '${isProfit ? '+' : ''}${formatKrwWithComma(pnl.round().toDouble())}원',
            accentColor: accentColor,
          ),
        ],
      ),
    );
  }

  Widget _buildResultRow(String label, String value, {Color? accentColor}) {
    final isHighlight = accentColor != null;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isHighlight
                ? Colors.white.withValues(alpha: 0.7)
                : Colors.white.withValues(alpha: 0.4),
            fontWeight: isHighlight ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            color: isHighlight ? accentColor : Colors.white.withValues(alpha: 0.6),
            fontWeight: isHighlight ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 완료 사이클 정보 카드
  // ═══════════════════════════════════════════════════════════════

  Widget _buildCompletedInfoCard(BuildContext context, WidgetRef ref) {
    final isAlpha = cycle.strategyType == StrategyType.alphaCycleV3;

    // 운용 기간 포맷
    final startStr = '${cycle.startDate.year}.${cycle.startDate.month.toString().padLeft(2, '0')}.${cycle.startDate.day.toString().padLeft(2, '0')}';
    final endStr = '${cycle.updatedAt.year}.${cycle.updatedAt.month.toString().padLeft(2, '0')}.${cycle.updatedAt.day.toString().padLeft(2, '0')}';
    final rawDays = cycle.updatedAt.difference(cycle.startDate).inDays;
    final durationDays = rawDays < 1 ? 1 : rawDays; // 당일 거래 = 최소 1일
    final periodStr = '$startStr ~ $endStr ($durationDays일)';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: context.isDarkMode
                ? Colors.white.withValues(alpha: 0.03)
                : Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          InfoRow(label: '설정 시드', value: formatCashShort(cycle.seedAmount)),
          const Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '평균 매입환율',
                style: TextStyle(fontSize: 13, color: context.appTextSecondary),
              ),
              GestureDetector(
                onTap: () => _showExchangeRateEditDialog(context, ref, cycle),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '₩${cycle.exchangeRateAtEntry.toStringAsFixed(2)} / \$1',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: context.appTextPrimary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.edit_outlined, size: 14, color: context.appTextHint),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 16),
          InfoRow(label: '운용 기간', value: periodStr),
          const Divider(height: 16),

          // 전략별 섹션
          if (isAlpha) ...[
            InfoRow(
              label: '익절목표',
              value: '+${cycle.currentSellTarget.toStringAsFixed(0)}%',
              valueColor: AppColors.green600,
            ),
            const Divider(height: 16),
            InfoRow(
              label: '연속익절',
              value: '${cycle.consecutiveProfitCount}회',
              valueColor: cycle.consecutiveProfitCount > 0 ? AppColors.green600 : null,
            ),
            const Divider(height: 16),
            InfoRow(
              label: '승부수',
              value: cycle.panicBuyUsed ? '사용' : '미사용',
              valueColor: cycle.panicBuyUsed ? AppColors.red500 : null,
            ),
          ] else ...[
            InfoRow(
              label: '회차',
              value: '${cycle.roundsUsed}/${cycle.totalRounds}',
            ),
            const Divider(height: 16),
            InfoRow(
              label: '익절목표',
              value: '+${cycle.takeProfitPercent.toStringAsFixed(0)}%',
              valueColor: AppColors.green600,
            ),
          ],
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 거래 내역 (읽기전용)
  // ═══════════════════════════════════════════════════════════════

  Widget _buildTradeHistorySection(BuildContext context) {
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
            readOnly: false,
            allowDelete: false,
          )),
      ],
    );
  }

  void _showExchangeRateEditDialog(BuildContext context, WidgetRef ref, Cycle cycle) {
    final controller = TextEditingController(
      text: cycle.exchangeRateAtEntry.toStringAsFixed(2),
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('평균 매입환율 수정'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: '환율 (원/달러)',
            hintText: '예: 1350.00',
            prefixText: '₩ ',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              final newRate = double.tryParse(controller.text);
              if (newRate != null && newRate > 0) {
                cycle.exchangeRateAtEntry = newRate;
                ref.read(cycleListProvider.notifier).saveCycle(cycle);
                Navigator.pop(ctx);
              }
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
    // controller는 dialog가 닫힐 때 GC됨
  }
}
