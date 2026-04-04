import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../providers/providers.dart';
import '../../providers/market_data_providers.dart';
import '../../providers/fear_greed_providers.dart';
import '../../widgets/home/index_quote_row.dart';
import '../../widgets/home/market_index_card.dart';
import '../../widgets/home/exchange_rate_card.dart';
import '../../widgets/home/fear_greed_card.dart';
import '../../widgets/common/app_title_logo.dart';
import '../../widgets/common/calculator_button.dart';
import '../../widgets/common/notification_bell_button.dart';
import '../../widgets/home/market_news_section.dart';
import '../../widgets/home/global_indicators_panel.dart';
import '../../providers/market_news_providers.dart';
import '../../providers/global_indicators_provider.dart';

/// 홈 화면
///
/// 대시보드로서 시장 현황을 표시합니다.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // 시장 데이터 로드
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMarketData();
    });
  }

  Future<void> _loadMarketData() async {
    ref.read(indexQuoteProvider.notifier).fetchIndices();
    ref.read(marketIndexProvider.notifier).loadNasdaqData();
    ref.read(sp500IndexProvider.notifier).loadSp500Data();
    ref.read(exchangeRateProvider.notifier).fetchUsdKrwRate();
    ref.read(fearGreedProvider.notifier).fetchIndex();
    ref.read(marketNewsProvider.notifier).fetchNews();
    ref.read(koreaNewsProvider.notifier).fetchNews();
    ref.read(globalIndicatorsProvider.notifier).loadIndicators();
  }

  @override
  Widget build(BuildContext context) {
    final isMarketOpen = ref.watch(isMarketOpenProvider);
    final marketStatusText = ref.watch(marketStateKoreanProvider);

    return Scaffold(
      backgroundColor: context.appBackground,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // 앱바
            SliverAppBar(
              floating: true,
              toolbarHeight: 64,
              backgroundColor: context.appBackground,
              elevation: 0,
              centerTitle: false,
              titleSpacing: 16,
              leadingWidth: 0,
              automaticallyImplyLeading: false,
              title: MediaQuery.sizeOf(context).width >= 1200
                  ? null
                  : const AppTitleLogo(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
              actions: const [
                CalculatorButton(),
                NotificationBellButton(),
              ],
            ),

            // 컨텐츠
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),

                  // 시장 현황 섹션
                  _SectionHeader(
                    title: '시장',
                    trailing: Row(
                      children: [
                        const ExchangeRateChip(),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: context.appIconBg,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Builder(
                                builder: (context) {
                                  final isDesktop = MediaQuery.sizeOf(context).width >= 768;
                                  final dotSize = isDesktop ? 7.0 : 6.0;
                                  return Container(
                                    width: dotSize,
                                    height: dotSize,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isMarketOpen
                                          ? AppColors.green500
                                          : AppColors.red500,
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(width: 4),
                              Text(
                                marketStatusText,
                                style: TextStyle(
                                  fontSize: MediaQuery.sizeOf(context).width >= 768 ? 13 : 11,
                                  fontWeight: FontWeight.w500,
                                  color: context.appTextSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const IndexQuoteRow(),
                  const SizedBox(height: 8),
                  const MarketIndexCard(),
                  const SizedBox(height: 10),
                  // Fear & Greed + 글로벌 지표 (반응형)
                  Builder(builder: (context) {
                    final screenW = MediaQuery.sizeOf(context).width;
                    final isDesktop = screenW >= 600;
                    final fearGreedState = ref.watch(fearGreedProvider);

                    final fearGreedCard = FearGreedCard(
                      value: fearGreedState.value,
                      isLoading: fearGreedState.isLoading,
                      error: fearGreedState.error,
                      onRefresh: () {
                        ref.read(fearGreedProvider.notifier).refresh();
                      },
                    );

                    if (isDesktop) {
                      // 데스크톱: 두 카드 나란히 (2:1), 고정 높이로 동일
                      final fs = 0.92 + ((screenW - 320) / 1080).clamp(0.0, 1.0) * 0.43;
                      final cardHeight = 260.0 * fs;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: SizedBox(
                          height: cardHeight,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                flex: 2,
                                child: FearGreedCard(
                                  value: fearGreedState.value,
                                  isLoading: fearGreedState.isLoading,
                                  error: fearGreedState.error,
                                  onRefresh: () {
                                    ref.read(fearGreedProvider.notifier).refresh();
                                  },
                                  useOuterMargin: false,
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                flex: 1,
                                child: GlobalIndicatorsCard(),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    // 모바일: 세로 배치
                    return Column(
                      children: [
                        fearGreedCard,
                        const SizedBox(height: 8),
                        const GlobalIndicatorsGrid(),
                      ],
                    );
                  }),
                  const SizedBox(height: 10),
                  const MarketNewsSection(),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const _SectionHeader({
    required this.title,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 768;
    // 카드 margin(16) + 카드 내부 padding(10~14)과 정렬
    final leftPad = isDesktop ? 30.0 : 26.0;
    return Padding(
      padding: EdgeInsets.only(left: leftPad, right: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: isDesktop ? 18 : 16,
              fontWeight: FontWeight.bold,
              color: context.appTextPrimary,
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
