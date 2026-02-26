import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../providers/market_data_providers.dart';
import '../shared/return_badge.dart';
import 'compact_candlestick_chart.dart';
import 'compact_chart_controls.dart';

/// 시장 지수 카드 - 나스닥 100 & S&P 500 나란히 표시
class MarketIndexCard extends ConsumerWidget {
  const MarketIndexCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    final nasdaqCard = _CompactIndexSection(
      title: 'NASDAQ 100',
      symbol: '^NDX',
      stateProvider: marketIndexProvider,
      onRefresh: () => ref.read(marketIndexProvider.notifier).loadNasdaqData(),
      onPeriodChanged: (range, interval) {
        ref.read(marketIndexProvider.notifier).loadChartData(
          range: range,
          interval: interval,
        );
      },
    );

    final sp500Card = _CompactIndexSection(
      title: 'S&P 500',
      symbol: '^GSPC',
      stateProvider: sp500IndexProvider,
      onRefresh: () => ref.read(sp500IndexProvider.notifier).loadSp500Data(),
      onPeriodChanged: (range, interval) {
        ref.read(sp500IndexProvider.notifier).loadChartData(
          range: range,
          interval: interval,
        );
      },
    );

    if (isMobile) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            nasdaqCard,
            const SizedBox(height: 8),
            sp500Card,
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: nasdaqCard),
          const SizedBox(width: 12),
          Expanded(child: sp500Card),
        ],
      ),
    );
  }
}

/// 컴팩트 지수 섹션 (캔들차트 + 이동평균선)
class _CompactIndexSection extends ConsumerStatefulWidget {
  final String title;
  final String symbol;
  final StateNotifierProvider<dynamic, MarketIndexState> stateProvider;
  final VoidCallback onRefresh;
  final void Function(String range, String interval) onPeriodChanged;

  const _CompactIndexSection({
    required this.title,
    required this.symbol,
    required this.stateProvider,
    required this.onRefresh,
    required this.onPeriodChanged,
  });

  @override
  ConsumerState<_CompactIndexSection> createState() => _CompactIndexSectionState();
}

class _CompactIndexSectionState extends ConsumerState<_CompactIndexSection> {
  String _selectedPeriod = '일';

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(widget.stateProvider);
    final isDesktop = MediaQuery.of(context).size.width >= 768;

    return Container(
      padding: EdgeInsets.fromLTRB(
        isDesktop ? 14 : 10, isDesktop ? 12 : 8,
        isDesktop ? 14 : 10, isDesktop ? 14 : 10,
      ),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.appBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 헤더: 지수명 + 가격 + 등락률 + 새로고침 (한 줄)
          GestureDetector(
            onTap: () {
              context.go(
                '/index/${Uri.encodeComponent(widget.symbol)}?from=home',
              );
            },
            child: Row(
              children: [
                Text(
                  widget.title,
                  style: TextStyle(
                    fontSize: isDesktop ? 15 : 13,
                    fontWeight: FontWeight.w600,
                    color: context.appTextPrimary,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.arrow_forward_ios,
                  size: isDesktop ? 12 : 10,
                  color: context.appTextHint,
                ),
                const Spacer(),
                if (state.hasData) ...[
                  Text(
                    _formatPrice(state.price),
                    style: TextStyle(
                      fontSize: isDesktop ? 16 : 14,
                      fontWeight: FontWeight.w700,
                      color: context.appTextPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(width: 5),
                  ReturnBadge(
                    value: state.changePercent,
                    size: ReturnBadgeSize.small,
                    colorScheme: ReturnBadgeColorScheme.redBlue,
                    decimals: 2,
                    showIcon: false,
                  ),
                ] else
                  Text(
                    '-',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: context.appTextHint,
                    ),
                  ),
                const SizedBox(width: 8),
                if (state.isLoading)
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: context.appTextHint,
                    ),
                  )
                else
                  GestureDetector(
                    onTap: widget.onRefresh,
                    behavior: HitTestBehavior.opaque,
                    child: Icon(
                      Icons.refresh_rounded,
                      size: isDesktop ? 16 : 14,
                      color: context.appTextHint,
                    ),
                  ),
              ],
            ),
          ),

          // 기간 선택 + 이동평균선 범례 (한 줄)
          const SizedBox(height: 6),
          Row(
            children: [
              CompactPeriodSelector(
                selectedPeriod: _selectedPeriod,
                onPeriodChanged: (period) {
                  setState(() => _selectedPeriod = period);
                  _loadChartData(period);
                },
              ),
              const Spacer(),
              const MALegend(),
            ],
          ),

          // 캔들스틱 차트
          const SizedBox(height: 6),
          SizedBox(
            height: isDesktop ? 280.0 : 140.0,
            child: state.hasChart
                ? CompactCandlestickChart(
                    data: state.chartData,
                    selectedPeriod: _selectedPeriod,
                  )
                : Center(
                    child: state.isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            '차트 없음',
                            style: const TextStyle(
                              color: AppColors.textHint,
                              fontSize: 10,
                            ),
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  void _loadChartData(String period) {
    String range;
    String interval;

    switch (period) {
      case '일':
        range = '6mo';  // 120일 이평선 위해 충분한 데이터
        interval = '1day';
        break;
      case '주':
        range = '2y';
        interval = '1week';
        break;
      case '월':
        range = '10y';
        interval = '1month';
        break;
      default:
        range = '6mo';
        interval = '1day';
    }

    widget.onPeriodChanged(range, interval);
  }

  String _formatPrice(double price) {
    return price.toStringAsFixed(2).replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (match) => '${match[1]},',
        );
  }
}
