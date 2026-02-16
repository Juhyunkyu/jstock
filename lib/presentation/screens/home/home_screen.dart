import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../providers/providers.dart';
import '../../providers/market_data_providers.dart';
import '../../providers/fear_greed_providers.dart';
import '../../widgets/home/market_index_card.dart';
import '../../widgets/home/exchange_rate_card.dart';
import '../../widgets/home/fear_greed_card.dart';
import '../../widgets/common/app_title_logo.dart';

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
    ref.read(marketIndexProvider.notifier).loadNasdaqData();
    ref.read(sp500IndexProvider.notifier).loadSp500Data();
    ref.read(exchangeRateProvider.notifier).fetchUsdKrwRate();
    ref.read(fearGreedProvider.notifier).fetchIndex();
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
              title: MediaQuery.of(context).size.width >= 1200
                  ? null
                  : const AppTitleLogo(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined),
                  color: context.appTextPrimary,
                  onPressed: () {
                    // TODO: 알림 화면으로 이동
                  },
                ),
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
                                  final isDesktop = MediaQuery.of(context).size.width >= 768;
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
                                  fontSize: MediaQuery.of(context).size.width >= 768 ? 13 : 11,
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
                  const MarketIndexCard(),
                  const SizedBox(height: 10),
                  Consumer(
                    builder: (context, ref, child) {
                      final fearGreedState = ref.watch(fearGreedProvider);
                      return FearGreedCard(
                        value: fearGreedState.value,
                        isLoading: fearGreedState.isLoading,
                        error: fearGreedState.error,
                        onRefresh: () {
                          ref.read(fearGreedProvider.notifier).refresh();
                        },
                      );
                    },
                  ),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: MediaQuery.of(context).size.width >= 768 ? 18 : 16,
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
