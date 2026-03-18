import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/krw_formatter.dart';
import '../../../../core/utils/number_formatter.dart';
import '../../../../data/models/cycle.dart';
import '../../../widgets/shared/exchange_rate_edit_dialog.dart';
import '../../../widgets/shared/info_row.dart';

/// 사이클 정보 카드 (보유 상세 스타일)
///
/// 상단: 공통 보유 정보 (수량, 매입가, 투자금, 평가금, 환율)
/// 하단: 전략별 사이클 정보 (시드, 잔여현금 등)
class CycleInfoCard extends StatefulWidget {
  final Cycle cycle;
  final double currentPrice;
  final double liveExchangeRate;
  final double evaluatedAmountKrw;
  final double weightedAvgExchangeRate;
  final ValueChanged<double>? onExchangeRateChanged;
  final VoidCallback? onEditSettings;
  final double? steadyTValue;

  const CycleInfoCard({
    super.key,
    required this.cycle,
    required this.currentPrice,
    required this.liveExchangeRate,
    required this.evaluatedAmountKrw,
    required this.weightedAvgExchangeRate,
    this.onExchangeRateChanged,
    this.onEditSettings,
    this.steadyTValue,
  });

  @override
  State<CycleInfoCard> createState() => _CycleInfoCardState();
}

class _CycleInfoCardState extends State<CycleInfoCard> {
  bool _showCurrencyPL = false;

  @override
  Widget build(BuildContext context) {
    final cycle = widget.cycle;
    final currentPrice = widget.currentPrice;
    final liveExchangeRate = widget.liveExchangeRate;
    final avgExRate = widget.weightedAvgExchangeRate;

    // 환차 관련 계산
    final evalAtPurchaseRate = currentPrice * cycle.totalShares * avgExRate;
    final currencyPL = (liveExchangeRate - avgExRate) * currentPrice * cycle.totalShares;

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
          // === 공통 보유 정보 ===
          InfoRow(
            label: '보유 수량',
            value: cycle.totalShares > 0
                ? '${formatShares(cycle.totalShares)}주'
                : '-',
          ),
          const Divider(height: 16),
          InfoRow(
            label: '매입가 (VWAP)',
            value: cycle.averagePrice > 0
                ? '\$${cycle.averagePrice.toStringAsFixed(2)}'
                : '-',
          ),
          const Divider(height: 16),
          InfoRow(
            label: '실제 투자금',
            value: formatKrw(cycle.totalInvestedAmount),
          ),
          const Divider(height: 16),

          // 평가금 + 환차 토글
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    _showCurrencyPL ? '평가금 (매입환율)' : '평가금 (원)',
                    style: TextStyle(
                      fontSize: 13,
                      color: context.appTextSecondary,
                    ),
                  ),
                  if (cycle.totalShares > 0) ...[
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => setState(() => _showCurrencyPL = !_showCurrencyPL),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _showCurrencyPL
                              ? AppColors.secondary.withValues(alpha: 0.15)
                              : context.appBorder,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '환차',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: _showCurrencyPL
                                ? AppColors.secondary
                                : context.appTextSecondary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              Text(
                cycle.totalShares > 0
                    ? (_showCurrencyPL
                        ? formatKrw(evalAtPurchaseRate)
                        : formatKrw(widget.evaluatedAmountKrw))
                    : '-',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: context.appTextPrimary,
                ),
              ),
            ],
          ),

          // 환차 상세
          if (_showCurrencyPL && cycle.totalShares > 0) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (currencyPL >= 0 ? AppColors.red500 : AppColors.blue500)
                    .withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '환차손익',
                        style: TextStyle(fontSize: 12, color: context.appTextSecondary),
                      ),
                      Text(
                        '${currencyPL >= 0 ? '+' : ''}${formatKrw(currencyPL)}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: currencyPL >= 0 ? AppColors.red500 : AppColors.blue500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '매입환율 → 현재환율',
                        style: TextStyle(fontSize: 11, color: context.appTextHint),
                      ),
                      Text(
                        '₩${avgExRate.toStringAsFixed(0)} → ₩${liveExchangeRate.toStringAsFixed(0)}',
                        style: TextStyle(fontSize: 11, color: context.appTextHint),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],

          const Divider(height: 16),
          // 평균 매입환율 — 편집 가능
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '평균 매입환율',
                style: TextStyle(
                  fontSize: 13,
                  color: context.appTextSecondary,
                ),
              ),
              Row(
                children: [
                  Text(
                    '₩${avgExRate.toStringAsFixed(2)} / \$1',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: context.appTextPrimary,
                    ),
                  ),
                  if (widget.onExchangeRateChanged != null) ...[
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () async {
                        final newRate = await showExchangeRateEditDialog(
                          context,
                          currentRate: widget.weightedAvgExchangeRate,
                        );
                        if (newRate != null) {
                          widget.onExchangeRateChanged?.call(newRate);
                        }
                      },
                      child: Icon(
                        Icons.edit_outlined,
                        size: 14,
                        color: context.appTextHint,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),

          // === 구분선 + 사이클 전용 정보 ===
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: context.appBackground,
              borderRadius: BorderRadius.circular(8),
            ),
            child: cycle.strategyType == StrategyType.alphaCycleV3
                ? _buildAlphaCycleSection(context, cycle)
                : _buildSteadyCycleSection(context, cycle),
          ),

          // === 설정 변경 버튼 (대기중일 때만) ===
          if (widget.onEditSettings != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: widget.onEditSettings,
                icon: Icon(Icons.tune, size: 16, color: context.appAccent),
                label: Text(
                  '설정 변경',
                  style: TextStyle(fontSize: 13, color: context.appAccent),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: context.appAccent.withValues(alpha: 0.4)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Smart Cycle 전용 섹션
  Widget _buildAlphaCycleSection(BuildContext context, Cycle cycle) {
    final cashRatio = cycle.seedAmount > 0
        ? (cycle.remainingCash / cycle.seedAmount * 100)
        : 0.0;

    return Column(
      children: [
        InfoRow(fontSize: 12,label: '설정 시드', value: formatCashShort(cycle.seedAmount)),
        const SizedBox(height: 6),
        InfoRow(fontSize: 12,label: '잔여현금', value: formatCashShort(cycle.remainingCash)),
        const SizedBox(height: 6),
        InfoRow(fontSize: 12,label: '현금비율', value: '${cashRatio.toStringAsFixed(1)}%'),
        const SizedBox(height: 6),
        InfoRow(fontSize: 12,
          label: '익절목표',
          value: '+${cycle.currentSellTarget.toStringAsFixed(0)}%',
          valueColor: AppColors.green600,
        ),
        const SizedBox(height: 6),
        InfoRow(fontSize: 12,
          label: '연속익절',
          value: '${cycle.consecutiveProfitCount}회',
          valueColor: cycle.consecutiveProfitCount > 0 ? AppColors.green600 : null,
        ),
        const SizedBox(height: 6),
        InfoRow(fontSize: 12,
          label: '승부수',
          value: cycle.panicBuyUsed ? '사용' : '미사용',
          valueColor: cycle.panicBuyUsed ? AppColors.red500 : null,
        ),
      ],
    );
  }

  /// Steady Cycle 전용 섹션
  Widget _buildSteadyCycleSection(BuildContext context, Cycle cycle) {
    final isV1 = cycle.steadyVersion == SteadyVersion.v1;

    return Column(
      children: [
        InfoRow(fontSize: 12, label: '설정 시드', value: formatCashShort(cycle.seedAmount)),
        const SizedBox(height: 6),
        InfoRow(fontSize: 12, label: '잔여현금', value: formatCashShort(cycle.remainingCash)),
        const SizedBox(height: 6),
        if (isV1)
          InfoRow(fontSize: 12, label: '회차', value: '${cycle.roundsUsed}/${cycle.totalRounds}')
        else ...[
          // V2.2/V3.0: T값 (Provider에서 정확한 값 전달)
          Builder(builder: (context) {
            final tValue = widget.steadyTValue ?? _calcSimpleTValue(cycle);
            return Column(
              children: [
                InfoRow(fontSize: 12, label: 'T값', value: '${tValue.toStringAsFixed(1)} / ${cycle.totalRounds}'),
                const SizedBox(height: 6),
                InfoRow(
                  fontSize: 12,
                  label: '구간',
                  value: cycle.isFirstHalfWith(tValue) ? '전반전' : '후반전',
                  valueColor: cycle.isFirstHalfWith(tValue) ? AppColors.blue500 : AppColors.amber500,
                ),
                const SizedBox(height: 6),
                InfoRow(
                  fontSize: 12,
                  label: '오프셋',
                  value: '${cycle.locOffsetPercentWith(tValue) >= 0 ? '+' : ''}${cycle.locOffsetPercentWith(tValue).toStringAsFixed(1)}%',
                ),
              ],
            );
          }),
        ],
        const SizedBox(height: 6),
        InfoRow(fontSize: 12, label: '단위금액', value: formatCashShort(cycle.unitAmount)),
        const SizedBox(height: 6),
        InfoRow(fontSize: 12,
          label: '익절목표',
          value: '+${cycle.takeProfitPercent.toStringAsFixed(0)}%',
          valueColor: AppColors.green600,
        ),
        if (!isV1) ...[
          const SizedBox(height: 6),
          InfoRow(fontSize: 12,
            label: '매도비율',
            value: '${(cycle.sellQuarterPercent * 100).toStringAsFixed(0)}% / ${((1 - cycle.sellQuarterPercent) * 100).toStringAsFixed(0)}%',
          ),
        ],
        if (cycle.steadyVersion == SteadyVersion.v3_0 && cycle.compoundEnabled) ...[
          const SizedBox(height: 6),
          InfoRow(fontSize: 12, label: '반복리', value: '활성', valueColor: AppColors.green500),
        ],
      ],
    );
  }

  double _calcSimpleTValue(Cycle cycle) {
    if (cycle.unitAmount <= 0) return 0;
    final invested = cycle.seedAmount - cycle.remainingCash;
    final raw = invested / cycle.unitAmount;
    return ((raw * 10).ceilToDouble() / 10).clamp(0, cycle.totalRounds.toDouble());
  }
}
