import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/cycle.dart';
import '../../../domain/usecases/signal_detector.dart';
import '../shared/buy_signal_badge.dart';
import '../shared/confirm_dialog.dart';
import '../shared/ticker_logo.dart';

/// 활성 사이클 카드 위젯
///
/// 진행 중인 사이클의 상태를 요약해서 표시합니다.
class ActiveCycleCard extends StatelessWidget {
  final Cycle cycle;
  final double currentPrice;
  final TradingRecommendation recommendation;
  final VoidCallback? onTap;
  final VoidCallback? onEndCycle;
  final VoidCallback? onArchive;
  final bool inGrid;

  const ActiveCycleCard({
    super.key,
    required this.cycle,
    required this.currentPrice,
    required this.recommendation,
    this.onTap,
    this.onEndCycle,
    this.onArchive,
    this.inGrid = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: inGrid
            ? EdgeInsets.zero
            : const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.appCardBackground,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // 상단: 종목 정보 + 신호 배지
            Row(
              children: [
                // 종목 로고 + 티커
                TickerLogo(
                  ticker: cycle.ticker,
                  size: 32,
                  borderRadius: 8,
                ),
                const SizedBox(width: 8),
                Text(
                  cycle.ticker,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: context.appTickerColor,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '#${cycle.cycleNumber}',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.appTextSecondary,
                  ),
                ),
                const Spacer(),
                // 삭제 버튼
                GestureDetector(
                  onTap: () => _confirmEndCycle(context),
                  child: Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: context.appTextSecondary,
                  ),
                ),
                const SizedBox(width: 8),
                BuySignalBadge(signal: recommendation.signal),
              ],
            ),
            const SizedBox(height: 16),

            // 중간: 손익 게이지
            _ProfitLossGauge(
              lossRate: recommendation.lossRate,
              returnRate: recommendation.returnRate,
              buyTrigger: cycle.buyTrigger,
              sellTrigger: cycle.sellTrigger,
            ),
            const SizedBox(height: 16),

            // 하단: 상세 정보
            Row(
              children: [
                Expanded(
                  child: _InfoColumn(
                    label: '평균단가',
                    value: '\$${cycle.averagePrice.toStringAsFixed(2)}',
                  ),
                ),
                Expanded(
                  child: _InfoColumn(
                    label: '현재가',
                    value: '\$${currentPrice.toStringAsFixed(2)}',
                    valueColor: _getPriceColor(context),
                  ),
                ),
                Expanded(
                  child: _InfoColumn(
                    label: '보유수량',
                    value: '${cycle.totalShares.toStringAsFixed(2)}주',
                  ),
                ),
              ],
            ),

            // 매수 권장금액 (신호가 있을 때만)
            if (recommendation.needsAction && recommendation.recommendedAmount > 0) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _getRecommendationColor().withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _getRecommendationColor().withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      recommendation.isBuySignal
                          ? Icons.shopping_cart_outlined
                          : Icons.sell_outlined,
                      color: _getRecommendationColor(),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        recommendation.message ?? '',
                        style: TextStyle(
                          fontSize: 12,
                          color: _getRecommendationColor(),
                        ),
                      ),
                    ),
                    Text(
                      _formatKrw(recommendation.recommendedAmount),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: _getRecommendationColor(),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // 전량매도 후 "완료(기록)" 버튼
            if (cycle.totalShares == 0 && onArchive != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onArchive,
                  icon: const Icon(Icons.archive_outlined, size: 18),
                  label: const Text('완료(기록)'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getPriceColor(BuildContext context) {
    if (recommendation.returnRate > 0) return AppColors.green500;
    if (recommendation.returnRate < 0) return AppColors.red500;
    return context.appTextPrimary;
  }

  Color _getRecommendationColor() {
    switch (recommendation.signal) {
      case TradingSignal.weightedBuy:
        return AppColors.blue600;
      case TradingSignal.panicBuy:
        return AppColors.red600;
      case TradingSignal.takeProfit:
        return AppColors.amber600;
      case TradingSignal.hold:
        return AppColors.gray600;
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

  /// 사이클 종료 확인 다이얼로그를 표시합니다.
  Future<void> _confirmEndCycle(BuildContext context) async {
    final confirmed = await ConfirmDialog.show(
      context: context,
      title: '사이클 종료',
      message: '${cycle.ticker} #${cycle.cycleNumber} 사이클을 종료하시겠습니까?\n\n종료된 사이클은 다시 활성화할 수 없습니다.',
      cancelText: '취소',
      confirmText: '종료',
      isDanger: true,
    );

    if (confirmed && context.mounted) {
      onEndCycle?.call();
    }
  }
}

/// 손익 게이지 위젯
class _ProfitLossGauge extends StatelessWidget {
  final double lossRate;
  final double returnRate;
  final double buyTrigger;
  final double sellTrigger;

  const _ProfitLossGauge({
    required this.lossRate,
    required this.returnRate,
    required this.buyTrigger,
    required this.sellTrigger,
  });

  @override
  Widget build(BuildContext context) {
    // 게이지 범위: -60% ~ +40%
    const minValue = -60.0;
    const maxValue = 40.0;
    const range = maxValue - minValue;

    // 현재 위치 계산 (lossRate 기준)
    final currentPosition = ((lossRate - minValue) / range).clamp(0.0, 1.0);
    final buyTriggerPosition = ((buyTrigger - minValue) / range).clamp(0.0, 1.0);
    final sellTriggerPosition = ((sellTrigger - minValue) / range).clamp(0.0, 1.0);
    final zeroPosition = ((0 - minValue) / range).clamp(0.0, 1.0);

    // Dark mode colors
    final redColor = context.isDarkMode ? const Color(0xFFFF6B6B) : AppColors.red500;
    final greenColor = context.isDarkMode ? const Color(0xFF51CF66) : AppColors.green500;

    // 손실률과 수익률이 다른지 확인 (소수점 1자리 기준)
    final showLossRate = lossRate.toStringAsFixed(1) != returnRate.toStringAsFixed(1);

    return Column(
      children: [
        // 현재 수익률 표시 (큰 글씨)
        Text(
          '${returnRate >= 0 ? '+' : ''}${returnRate.toStringAsFixed(1)}%',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: returnRate >= 0 ? greenColor : redColor,
          ),
        ),
        if (showLossRate) ...[
          const SizedBox(height: 4),
          Text(
            '초기진입 대비 ${lossRate.toStringAsFixed(1)}%',
            style: TextStyle(
              fontSize: 11,
              color: context.appTextHint,
            ),
          ),
        ],
        const SizedBox(height: 12),

        // 게이지 바 (clean horizontal bar)
        SizedBox(
          height: 8,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              return Stack(
                children: [
                  // 배경 바 (loss to profit gradient)
                  Container(
                    height: 8,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      gradient: LinearGradient(
                        colors: [
                          redColor.withValues(alpha: 0.2),
                          context.appDivider,
                          greenColor.withValues(alpha: 0.2),
                        ],
                        stops: [0.0, zeroPosition, 1.0],
                      ),
                    ),
                  ),

                  // 매수 구간 하이라이트
                  Positioned(
                    left: 0,
                    child: Container(
                      width: width * buyTriggerPosition,
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppColors.blue500.withValues(alpha: 0.15),
                        borderRadius: const BorderRadius.horizontal(
                          left: Radius.circular(4),
                        ),
                      ),
                    ),
                  ),

                  // 매수 트리거 마커
                  Positioned(
                    left: width * buyTriggerPosition - 1,
                    child: Container(
                      width: 2,
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppColors.blue500,
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),

                  // 익절 트리거 마커
                  Positioned(
                    left: width * sellTriggerPosition - 1,
                    child: Container(
                      width: 2,
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppColors.amber500,
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),

                  // 0% 마커
                  Positioned(
                    left: width * zeroPosition - 1,
                    child: Container(
                      width: 2,
                      height: 8,
                      decoration: BoxDecoration(
                        color: context.appTextSecondary,
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),

                  // 현재 위치 인디케이터 (prominent circle)
                  Positioned(
                    left: width * currentPosition - 8,
                    top: -4,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: _getIndicatorColor(context),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: context.appCardBackground,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _getIndicatorColor(context).withValues(alpha: 0.5),
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 8),

        // 레이블 (simplified)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${buyTrigger.toInt()}%',
              style: TextStyle(fontSize: 10, color: context.appTextHint),
            ),
            Text(
              '0%',
              style: TextStyle(fontSize: 10, color: context.appTextSecondary),
            ),
            Text(
              '+${sellTrigger.toInt()}%',
              style: TextStyle(fontSize: 10, color: context.appTextHint),
            ),
          ],
        ),
      ],
    );
  }

  Color _getIndicatorColor(BuildContext context) {
    if (returnRate >= sellTrigger) return AppColors.amber500;
    if (lossRate <= buyTrigger) return AppColors.blue500;
    if (returnRate >= 0) {
      return context.isDarkMode ? const Color(0xFF51CF66) : AppColors.green500;
    }
    return context.isDarkMode ? const Color(0xFFFF6B6B) : AppColors.red500;
  }
}

class _InfoColumn extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoColumn({
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
            fontSize: 11,
            color: context.appTextSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: valueColor ?? context.appTextPrimary,
          ),
        ),
      ],
    );
  }
}
