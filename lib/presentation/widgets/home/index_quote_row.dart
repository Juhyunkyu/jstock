import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/services/api/tradingview_service.dart';
import '../../providers/api_providers.dart';
import '../shared/return_badge.dart';

/// 실시간 지수 값 표시 행 (NASDAQ 100, S&P 500)
///
/// TradingView Scanner API에서 실제 지수 데이터를 가져와 표시.
/// ETF 차트 카드(MarketIndexCard) 바로 위에 배치.
class IndexQuoteRow extends ConsumerWidget {
  const IndexQuoteRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(indexQuoteProvider);
    final isDesktop = MediaQuery.sizeOf(context).width >= 768;

    // 데이터 없으면 숨김
    if (!state.hasData && !state.isLoading) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // NASDAQ 100
          Expanded(
            child: _IndexChip(
              label: 'NASDAQ 100',
              quote: state.nasdaq,
              isLoading: state.isLoading && state.nasdaq == null,
              isDesktop: isDesktop,
            ),
          ),
          const SizedBox(width: 12),
          // S&P 500
          Expanded(
            child: _IndexChip(
              label: 'S&P 500',
              quote: state.sp500,
              isLoading: state.isLoading && state.sp500 == null,
              isDesktop: isDesktop,
            ),
          ),
        ],
      ),
    );
  }
}

class _IndexChip extends StatelessWidget {
  final String label;
  final IndexQuote? quote;
  final bool isLoading;
  final bool isDesktop;

  const _IndexChip({
    required this.label,
    required this.quote,
    required this.isLoading,
    required this.isDesktop,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 12 : 10,
        vertical: isDesktop ? 8 : 6,
      ),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.appBorder),
      ),
      child: isLoading
          ? _buildLoading(context)
          : quote != null
              ? _buildContent(context)
              : _buildEmpty(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final q = quote!;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: isDesktop ? 11 : 9,
                  fontWeight: FontWeight.w500,
                  color: context.appTextHint,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                _formatPrice(q.price),
                style: TextStyle(
                  fontSize: isDesktop ? 16 : 14,
                  fontWeight: FontWeight.w700,
                  color: context.appTextPrimary,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ),
        ReturnBadge(
          value: q.changePercent,
          size: ReturnBadgeSize.small,
          colorScheme: ReturnBadgeColorScheme.redBlue,
          decimals: 2,
          showIcon: false,
        ),
      ],
    );
  }

  Widget _buildLoading(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isDesktop ? 11 : 9,
            fontWeight: FontWeight.w500,
            color: context.appTextHint,
          ),
        ),
        const Spacer(),
        SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            color: context.appTextHint,
          ),
        ),
      ],
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: isDesktop ? 11 : 9,
        color: context.appTextHint,
      ),
    );
  }

  String _formatPrice(double price) {
    if (price >= 10000) {
      return price.toStringAsFixed(0).replaceAllMapped(
            RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
            (match) => '${match[1]},',
          );
    }
    return price.toStringAsFixed(2).replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (match) => '${match[1]},',
        );
  }
}
