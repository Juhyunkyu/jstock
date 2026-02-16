import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../shared/return_badge.dart';

/// 시장 현황 카드 위젯
///
/// 주요 지수나 ETF의 현재가와 변동률을 표시합니다.
class MarketOverviewCard extends StatelessWidget {
  final String ticker;
  final String name;
  final double price;
  final double changePercent;
  final VoidCallback? onTap;

  const MarketOverviewCard({
    super.key,
    required this.ticker,
    required this.name,
    required this.price,
    required this.changePercent,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 140,
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
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 티커 배지
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: context.appIconBg,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                ticker,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: context.appTextPrimary,
                ),
              ),
            ),
            const SizedBox(height: 8),

            // 종목명
            Text(
              name,
              style: TextStyle(
                fontSize: 11,
                color: context.appTextSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),

            // 가격
            Text(
              '\$${price.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: context.appTextPrimary,
              ),
            ),
            const SizedBox(height: 4),

            // 변동률
            ReturnBadge(
              value: changePercent,
              size: ReturnBadgeSize.small,
              colorScheme: ReturnBadgeColorScheme.redBlue,
              decimals: 2,
            ),
          ],
        ),
      ),
    );
  }
}

/// 시장 현황 카드 리스트 (횡스크롤)
class MarketOverviewList extends StatelessWidget {
  final List<MarketOverviewCard> cards;

  const MarketOverviewList({
    super.key,
    required this.cards,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 140,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: cards.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) => cards[index],
      ),
    );
  }
}
