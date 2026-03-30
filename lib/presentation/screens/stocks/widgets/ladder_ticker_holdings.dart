import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/krw_formatter.dart';
import '../../../../core/utils/number_formatter.dart';
import '../../../../domain/trading/ladder_cycle_service.dart';

/// 안정형 보유 현황 테이블
///
/// QQQ, QLD, TQQQ 등 멀티 티커 보유 현황을 테이블 형태로 표시.
/// 각 티커의 현재가, 수량, 손익(원화)을 표시하고 합계 행 포함.
class LadderTickerHoldings extends StatelessWidget {
  final List<TickerHolding> holdings;
  final Map<String, double> currentPrices;
  final double liveExchangeRate;

  const LadderTickerHoldings({
    super.key,
    required this.holdings,
    required this.currentPrices,
    required this.liveExchangeRate,
  });

  @override
  Widget build(BuildContext context) {
    if (holdings.isEmpty) return const SizedBox.shrink();

    final isMobile = MediaQuery.sizeOf(context).width < 600;

    // 합계 계산
    final totalShares = holdings.fold<double>(0, (s, h) => s + h.shares);
    final totalEval = holdings.fold<double>(0, (s, h) => s + h.evalAmount);
    final totalInvested = holdings.fold<double>(0, (s, h) {
      return s + (h.shares * h.vwap * h.avgExRate);
    });
    final totalPnl = totalEval - totalInvested;
    final totalReturnRate = totalInvested > 0 ? (totalPnl / totalInvested) * 100 : 0.0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '보유 현황',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: context.appTextPrimary,
            ),
          ),
          const SizedBox(height: 10),

          // 헤더
          _buildHeaderRow(context, isMobile),
          Divider(height: 16, color: context.appDivider),

          // 티커별 행
          ...holdings.map((h) => _buildTickerRow(context, h, isMobile)),

          // 합계
          Divider(height: 16, color: context.appDivider),
          _buildTotalRow(context, totalShares, totalPnl, totalReturnRate, isMobile),

          // 실제 투자금
          const SizedBox(height: 12),
          Divider(height: 1, color: context.appDivider),
          const SizedBox(height: 10),
          _infoRow(context, '실제 투자금', formatKrw(totalInvested), context.appTextPrimary, isMobile),
        ],
      ),
    );
  }

  Widget _buildHeaderRow(BuildContext context, bool isMobile) {
    final headerStyle = TextStyle(
      fontSize: isMobile ? 10 : 11,
      fontWeight: FontWeight.w600,
      color: context.appTextHint,
    );

    return Row(
      children: [
        SizedBox(width: isMobile ? 50 : 60, child: Text('종목', style: headerStyle)),
        Expanded(child: Text('현재가', style: headerStyle, textAlign: TextAlign.right)),
        SizedBox(
          width: isMobile ? 40 : 50,
          child: Text('수량', style: headerStyle, textAlign: TextAlign.right),
        ),
        Expanded(child: Text('손익', style: headerStyle, textAlign: TextAlign.right)),
      ],
    );
  }

  Widget _buildTickerRow(BuildContext context, TickerHolding holding, bool isMobile) {
    final currentPrice = currentPrices[holding.ticker] ?? 0.0;
    final investedKrw = holding.shares * holding.vwap * holding.avgExRate;
    final pnl = holding.evalAmount - investedKrw;
    final returnRate = investedKrw > 0 ? (pnl / investedKrw) * 100 : 0.0;
    final isPositive = pnl >= 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: isMobile ? 50 : 60,
            child: Text(
              holding.ticker,
              style: TextStyle(
                fontSize: isMobile ? 12 : 13,
                fontWeight: FontWeight.w700,
                color: context.appTickerColor,
              ),
            ),
          ),
          Expanded(
            child: Text(
              '\$${currentPrice.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: isMobile ? 12 : 13,
                color: context.appTextPrimary,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          SizedBox(
            width: isMobile ? 40 : 50,
            child: Text(
              '${formatShares(holding.shares)}주',
              style: TextStyle(
                fontSize: isMobile ? 12 : 13,
                color: context.appTextPrimary,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${isPositive ? '+' : ''}${formatKrwWithComma(pnl)}',
                  style: TextStyle(
                    fontSize: isMobile ? 11 : 12,
                    fontWeight: FontWeight.w600,
                    color: isPositive ? AppColors.red500 : AppColors.blue500,
                  ),
                ),
                Text(
                  '(${isPositive ? '+' : ''}${returnRate.toStringAsFixed(1)}%)',
                  style: TextStyle(
                    fontSize: isMobile ? 9 : 10,
                    color: isPositive ? AppColors.red500 : AppColors.blue500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(BuildContext context, String label, String value, Color valueColor, bool isMobile) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isMobile ? 12 : 13,
            color: context.appTextSecondary,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isMobile ? 12 : 13,
            fontWeight: FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  Widget _buildTotalRow(
    BuildContext context,
    double totalShares,
    double totalPnl,
    double totalReturnRate,
    bool isMobile,
  ) {
    final isPositive = totalPnl >= 0;

    return Row(
      children: [
        SizedBox(
          width: isMobile ? 50 : 60,
          child: Text(
            '합계',
            style: TextStyle(
              fontSize: isMobile ? 12 : 13,
              fontWeight: FontWeight.w700,
              color: context.appTextPrimary,
            ),
          ),
        ),
        const Expanded(child: SizedBox()),
        SizedBox(
          width: isMobile ? 40 : 50,
          child: Text(
            '${formatShares(totalShares)}주',
            style: TextStyle(
              fontSize: isMobile ? 12 : 13,
              fontWeight: FontWeight.w700,
              color: context.appTextPrimary,
            ),
            textAlign: TextAlign.right,
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isPositive ? '+' : ''}${formatKrwWithComma(totalPnl)}',
                style: TextStyle(
                  fontSize: isMobile ? 11 : 12,
                  fontWeight: FontWeight.w700,
                  color: isPositive ? AppColors.red500 : AppColors.blue500,
                ),
              ),
              Text(
                '(${isPositive ? '+' : ''}${totalReturnRate.toStringAsFixed(1)}%)',
                style: TextStyle(
                  fontSize: isMobile ? 9 : 10,
                  fontWeight: FontWeight.w600,
                  color: isPositive ? AppColors.red500 : AppColors.blue500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
