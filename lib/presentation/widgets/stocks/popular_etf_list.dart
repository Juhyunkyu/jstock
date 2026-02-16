import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../providers/stock_providers.dart';
import '../shared/return_badge.dart';
import '../shared/ticker_logo.dart';

/// 인기 ETF 데이터
class PopularEtf {
  final String ticker;
  final String name;
  final String description;
  final String category;

  const PopularEtf({
    required this.ticker,
    required this.name,
    required this.description,
    required this.category,
  });

  /// 인기 3배 레버리지 ETF 목록
  static const List<PopularEtf> leveraged3x = [
    PopularEtf(
      ticker: 'TQQQ',
      name: '나스닥100 3배',
      description: 'ProShares UltraPro QQQ',
      category: '나스닥',
    ),
    PopularEtf(
      ticker: 'SOXL',
      name: '반도체 3배',
      description: 'Direxion Daily Semiconductor Bull 3X',
      category: '반도체',
    ),
    PopularEtf(
      ticker: 'UPRO',
      name: 'S&P500 3배',
      description: 'ProShares UltraPro S&P500',
      category: 'S&P500',
    ),
    PopularEtf(
      ticker: 'TECL',
      name: '기술주 3배',
      description: 'Direxion Daily Technology Bull 3X',
      category: '기술',
    ),
    PopularEtf(
      ticker: 'FNGU',
      name: 'FANG+ 3배',
      description: 'MicroSectors FANG+ Index 3X',
      category: 'FANG+',
    ),
    PopularEtf(
      ticker: 'LABU',
      name: '바이오 3배',
      description: 'Direxion Daily S&P Biotech Bull 3X',
      category: '바이오',
    ),
    PopularEtf(
      ticker: 'TNA',
      name: '러셀2000 3배',
      description: 'Direxion Daily Small Cap Bull 3X',
      category: '소형주',
    ),
    PopularEtf(
      ticker: 'CURE',
      name: '헬스케어 3배',
      description: 'Direxion Daily Healthcare Bull 3X',
      category: '헬스케어',
    ),
  ];
}

/// 인기 ETF 목록 위젯
class PopularEtfList extends StatelessWidget {
  final Function(PopularEtf) onEtfSelected;
  final Set<String>? disabledTickers;
  final Map<String, StockPrice?>? quotes;

  const PopularEtfList({
    super.key,
    required this.onEtfSelected,
    this.disabledTickers,
    this.quotes,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Text(
            '인기 3배 레버리지 ETF',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: context.appTextPrimary,
            ),
          ),
        ),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: PopularEtf.leveraged3x.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final etf = PopularEtf.leveraged3x[index];
            final isDisabled = disabledTickers?.contains(etf.ticker) ?? false;
            final quote = quotes?[etf.ticker];

            return PopularEtfTile(
              etf: etf,
              quote: quote,
              onTap: isDisabled ? null : () => onEtfSelected(etf),
              isDisabled: isDisabled,
            );
          },
        ),
      ],
    );
  }
}

/// 인기 ETF 타일 위젯
class PopularEtfTile extends StatelessWidget {
  final PopularEtf etf;
  final StockPrice? quote;
  final VoidCallback? onTap;
  final bool isDisabled;

  const PopularEtfTile({
    super.key,
    required this.etf,
    this.quote,
    this.onTap,
    this.isDisabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final changePercent = quote?.changePercent ?? 0;

    return ListTile(
      onTap: onTap,
      enabled: !isDisabled,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: TickerLogo(
        ticker: etf.ticker,
        size: 48,
        borderRadius: 12,
        backgroundColor: isDisabled
            ? context.appDivider
            : _getCategoryColor().withValues(alpha: 0.1),
        textColor: isDisabled ? AppColors.gray400 : _getCategoryColor(),
      ),
      title: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      etf.ticker,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isDisabled ? AppColors.gray400 : context.appTextPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDisabled
                            ? context.appDivider
                            : _getCategoryColor().withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        etf.category,
                        style: TextStyle(
                          fontSize: 10,
                          color: isDisabled ? AppColors.gray400 : _getCategoryColor(),
                        ),
                      ),
                    ),
                    if (isDisabled) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: context.appDivider,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          '진행중',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.gray500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  etf.name,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDisabled ? AppColors.gray400 : context.appTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (quote != null && !isDisabled) ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '\$${quote!.price.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: context.appTextPrimary,
                  ),
                ),
                ReturnBadge(
                  value: changePercent,
                  size: ReturnBadgeSize.small,
                  colorScheme: ReturnBadgeColorScheme.redBlue,
                  decimals: 2,
                  showIcon: false,
                ),
              ],
            ),
          ],
        ],
      ),
      trailing: isDisabled
          ? null
          : const Icon(
              Icons.chevron_right,
              color: AppColors.gray400,
            ),
    );
  }

  Color _getCategoryColor() {
    switch (etf.category) {
      case '나스닥':
        return AppColors.nasdaq;
      case 'S&P500':
        return AppColors.sp500;
      case '반도체':
        return const Color(0xFF00BCD4);
      case '기술':
        return const Color(0xFF9C27B0);
      case 'FANG+':
        return const Color(0xFFFF5722);
      case '바이오':
        return const Color(0xFF4CAF50);
      case '소형주':
        return const Color(0xFF795548);
      case '헬스케어':
        return const Color(0xFFE91E63);
      default:
        return AppColors.primary;
    }
  }
}
