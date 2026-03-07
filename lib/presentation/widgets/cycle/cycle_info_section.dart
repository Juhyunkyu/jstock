import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/krw_formatter.dart';
import '../../../data/models/cycle.dart';

/// 사이클 상세 화면의 주요 지표 정보 그리드
///
/// Strategy A (Alpha Cycle V3): 시드, 평균단가, 보유수량, 초기진입가, 승부수, 연속익절,
///   잔여현금, 현금비율, 익절목표
/// Strategy B (순정 무한매수법): 시드, 평균단가, 보유수량, 회차, 단위금액, 잔여현금, 익절목표
class CycleInfoSection extends StatelessWidget {
  final Cycle cycle;
  final double currentPrice;
  final double liveExchangeRate;

  const CycleInfoSection({
    super.key,
    required this.cycle,
    required this.currentPrice,
    required this.liveExchangeRate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
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
      child: cycle.strategyType == StrategyType.alphaCycleV3
          ? _buildAlphaCycleInfo(context)
          : _buildInfiniteBuyInfo(context),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // Strategy A: Alpha Cycle V3
  // ═══════════════════════════════════════════════════════════════

  Widget _buildAlphaCycleInfo(BuildContext context) {
    final cashRatio = cycle.seedAmount > 0
        ? (cycle.remainingCash / cycle.seedAmount * 100)
        : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Row 1: 시드 | 평균단가 | 보유수량
        _buildInfoRow(context, [
          _InfoItem(
            label: '\uC2DC\uB4DC',
            value: _formatCashShort(cycle.seedAmount),
          ),
          _InfoItem(
            label: '\uD3C9\uADE0\uB2E8\uAC00',
            value: cycle.averagePrice > 0
                ? '\$${cycle.averagePrice.toStringAsFixed(2)}'
                : '-',
          ),
          _InfoItem(
            label: '\uBCF4\uC720\uC218\uB7C9',
            value: cycle.totalShares > 0
                ? cycle.totalShares.toStringAsFixed(cycle.totalShares == cycle.totalShares.roundToDouble() ? 0 : 2)
                : '-',
          ),
        ]),
        const SizedBox(height: 8),

        // Row 2: 초기진입가 | 승부수 | 연속익절
        _buildInfoRow(context, [
          _InfoItem(
            label: '\uCD08\uAE30\uC9C4\uC785\uAC00',
            value: cycle.entryPrice != null
                ? '\$${cycle.entryPrice!.toStringAsFixed(2)}'
                : '-',
          ),
          _InfoItem(
            label: '\uC2B9\uBD80\uC218',
            value: cycle.panicBuyUsed ? '\uC0AC\uC6A9' : '\uBBF8\uC0AC\uC6A9',
            valueColor: cycle.panicBuyUsed ? AppColors.red500 : context.appTextHint,
          ),
          _InfoItem(
            label: '\uC5F0\uC18D\uC775\uC808',
            value: '${cycle.consecutiveProfitCount}\uD68C',
            valueColor: cycle.consecutiveProfitCount > 0
                ? AppColors.green600
                : null,
          ),
        ]),
        const SizedBox(height: 8),

        // Row 3: 잔여현금 | 현금비율 | 익절목표
        _buildInfoRow(context, [
          _InfoItem(
            label: '\uC794\uC5EC\uD604\uAE08',
            value: _formatCashShort(cycle.remainingCash),
          ),
          _InfoItem(
            label: '\uD604\uAE08\uBE44\uC728',
            value: '${cashRatio.toStringAsFixed(1)}%',
          ),
          _InfoItem(
            label: '\uC775\uC808\uBAA9\uD45C',
            value: '+${cycle.currentSellTarget.toStringAsFixed(0)}%',
            valueColor: AppColors.green600,
          ),
        ]),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // Strategy B: 순정 무한매수법
  // ═══════════════════════════════════════════════════════════════

  Widget _buildInfiniteBuyInfo(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Row 1: 시드 | 평균단가 | 보유수량
        _buildInfoRow(context, [
          _InfoItem(
            label: '\uC2DC\uB4DC',
            value: _formatCashShort(cycle.seedAmount),
          ),
          _InfoItem(
            label: '\uD3C9\uADE0\uB2E8\uAC00',
            value: cycle.averagePrice > 0
                ? '\$${cycle.averagePrice.toStringAsFixed(2)}'
                : '-',
          ),
          _InfoItem(
            label: '\uBCF4\uC720\uC218\uB7C9',
            value: cycle.totalShares > 0
                ? cycle.totalShares.toStringAsFixed(cycle.totalShares == cycle.totalShares.roundToDouble() ? 0 : 2)
                : '-',
          ),
        ]),
        const SizedBox(height: 8),

        // Row 2: 회차 | 단위금액 | 잔여현금
        _buildInfoRow(context, [
          _InfoItem(
            label: '\uD68C\uCC28',
            value: '${cycle.roundsUsed}/${cycle.totalRounds}',
          ),
          _InfoItem(
            label: '\uB2E8\uC704\uAE08\uC561',
            value: _formatCashShort(cycle.unitAmount),
          ),
          _InfoItem(
            label: '\uC794\uC5EC\uD604\uAE08',
            value: _formatCashShort(cycle.remainingCash),
          ),
        ]),
        const SizedBox(height: 8),

        // Row 3: 익절목표
        _buildInfoRow(context, [
          _InfoItem(
            label: '\uC775\uC808\uBAA9\uD45C',
            value: '+${cycle.takeProfitPercent.toStringAsFixed(0)}%',
            valueColor: AppColors.green600,
          ),
          const _InfoItem(label: '', value: ''),
          const _InfoItem(label: '', value: ''),
        ]),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 공통 빌더
  // ═══════════════════════════════════════════════════════════════

  Widget _buildInfoRow(BuildContext context, List<_InfoItem> items) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: context.appBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            Expanded(
              child: items[i].label.isEmpty
                  ? const SizedBox.shrink()
                  : _InfoColumnWidget(
                      label: items[i].label,
                      value: items[i].value,
                      valueColor: items[i].valueColor,
                    ),
            ),
            if (i < items.length - 1 && items[i + 1].label.isNotEmpty)
              Container(
                width: 1,
                height: 24,
                color: context.appDivider,
              )
            else if (i < items.length - 1)
              const SizedBox(width: 1),
          ],
        ],
      ),
    );
  }

  /// 현금 금액 축약 포맷: 1억 이상 → "N억", 10000 이상 → "N만", 이하 → 쉼표
  String _formatCashShort(double amount) {
    if (amount >= 100000000) {
      final eok = amount / 100000000;
      final remainder = (amount % 100000000) / 10000;
      if (remainder >= 1) {
        return '${eok.toStringAsFixed(0)}\uC5B5${remainder.round().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}만';
      }
      return '${eok.toStringAsFixed(0)}\uC5B5';
    }
    if (amount >= 10000) {
      final man = (amount / 10000).round();
      return '${man.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}만';
    }
    return formatKrwWithComma(amount);
  }
}

class _InfoItem {
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoItem({
    required this.label,
    required this.value,
    this.valueColor,
  });
}

class _InfoColumnWidget extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoColumnWidget({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: context.appTextSecondary,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: valueColor ?? context.appTextPrimary,
          ),
        ),
      ],
    );
  }
}
