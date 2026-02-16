import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../presentation/providers/holding_providers.dart';
import '../shared/return_badge.dart';
import '../shared/ticker_logo.dart';

/// 일반 보유 종목 카드 위젯
///
/// 알파 사이클 없이 단순 보유하는 종목의 정보를 표시합니다.
class HoldingCard extends StatelessWidget {
  /// 보유 + 현재가 결합 데이터
  final HoldingWithPrice data;

  /// 탭 콜백
  final VoidCallback? onTap;

  /// 삭제 콜백
  final VoidCallback? onDelete;

  /// 아카이브 콜백
  final VoidCallback? onArchive;

  /// 그리드 모드 (margin 제거)
  final bool inGrid;

  const HoldingCard({
    super.key,
    required this.data,
    this.onTap,
    this.onDelete,
    this.onArchive,
    this.inGrid = false,
  });

  @override
  Widget build(BuildContext context) {
    final holding = data.holding;
    final isSoldOut = holding.isEmpty;
    final isProfit = data.profitLoss >= 0;
    // 한국식: 상승=빨간색, 하락=파란색
    final profitColor = isProfit ? AppColors.red500 : AppColors.blue500;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: inGrid
            ? EdgeInsets.zero
            : const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
        child: Column(
          children: [
            // 상단: 종목 정보 + 수익률/매도완료 배지
            Row(
              children: [
                // 종목 로고 + 티커
                TickerLogo(
                  ticker: holding.ticker,
                  size: 32,
                  borderRadius: 8,
                ),
                const SizedBox(width: 8),
                Text(
                  holding.ticker,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: context.appTickerColor,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    holding.name,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.appTextSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // 수익률 배지 또는 매도완료 배지
                if (isSoldOut)
                  ReturnBadge(
                    value: null,
                    size: ReturnBadgeSize.small,
                    nullLabel: '매도 완료',
                  )
                else
                  ReturnBadge(
                    value: data.returnRate,
                    size: ReturnBadgeSize.small,
                    colorScheme: ReturnBadgeColorScheme.redBlue,
                    decimals: 2,
                  ),
              ],
            ),

            if (!isSoldOut) ...[
              const SizedBox(height: 10),

              // 중간: 현재 가치
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '평가금액',
                        style: TextStyle(
                          fontSize: 10,
                          color: context.appTextSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _formatKrw(data.currentValue),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: context.appTextPrimary,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '손익',
                        style: TextStyle(
                          fontSize: 10,
                          color: context.appTextSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${isProfit ? '+' : ''}${_formatKrw(data.profitLoss)}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: profitColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // 하단: 상세 정보
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: context.appBackground,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _InfoColumn(
                        label: '평균단가',
                        value: '\$${holding.averagePrice.toStringAsFixed(2)}',
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 24,
                      color: context.appDivider,
                    ),
                    Expanded(
                      child: _InfoColumn(
                        label: '현재가',
                        value: '\$${data.currentPrice.toStringAsFixed(2)}',
                        valueColor: _getPriceColor(context),
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 24,
                      color: context.appDivider,
                    ),
                    Expanded(
                      child: _InfoColumn(
                        label: '보유수량',
                        value: '${holding.totalShares.toStringAsFixed(2)}주',
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // 전량매도 후 "완료(기록)" 버튼
            if (isSoldOut && onArchive != null) ...[
              const SizedBox(height: 10),
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
    // 한국식: 상승=빨간색, 하락=파란색
    if (data.returnRate > 0) return AppColors.red500;
    if (data.returnRate < 0) return AppColors.blue500;
    return context.appTextPrimary;
  }

  String _formatKrw(double amount) {
    final intAmount = amount.round();
    final absAmount = intAmount.abs();
    // 천단위 쉼표 포맷
    final formatted = absAmount.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
    return '${intAmount < 0 ? '-' : ''}$formatted\u2009원'; // \u2009 = thin space
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
