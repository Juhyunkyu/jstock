import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/usecases/signal_detector.dart';
import '../../providers/providers.dart';
import '../../widgets/home/active_cycle_card.dart';
import '../../widgets/home/unified_portfolio_card.dart';
import '../../widgets/home/portfolio_allocation_chart.dart';
import '../../widgets/common/responsive_grid.dart';
import '../../widgets/holdings/holding_card.dart';

/// 종목 관리 화면
class StocksScreen extends ConsumerStatefulWidget {
  const StocksScreen({super.key});

  @override
  ConsumerState<StocksScreen> createState() => _StocksScreenState();
}

class _StocksScreenState extends ConsumerState<StocksScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    // 화면 로드 시 사이클 목록 새로고침
    Future.microtask(() {
      ref.read(cycleListProvider.notifier).refresh();
    });
  }

  void _onTabChanged() {
    // 탭 변경 시 FAB 가시성 업데이트를 위해 setState 호출
    if (_tabController.indexIsChanging == false) {
      setState(() {
        _currentTabIndex = _tabController.index;
      });
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  /// 현재 선택된 탭에 아이템이 있는 경우에만 FAB 표시
  bool _shouldShowFab(int cycleCount, int holdingCount) {
    if (_currentTabIndex == 0) {
      // 알파 사이클 탭: 사이클이 있을 때만 FAB 표시
      return cycleCount > 0;
    } else {
      // 일반 보유 탭: 보유 종목이 있을 때만 FAB 표시
      return holdingCount > 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final prices = ref.watch(currentPricesProvider);
    final portfolio = ref.watch(unifiedPortfolioProvider(prices));
    final activeCycles = ref.watch(activeCyclesProvider);
    final activeHoldings = ref.watch(activeHoldingsProvider);

    return Scaffold(
      backgroundColor: context.appBackground,
      appBar: AppBar(
        title: Text('종목 관리'),
        backgroundColor: context.appBackground,
        elevation: 0,
        toolbarHeight: 64,
        actions: [
          IconButton(
            icon: Icon(Icons.notifications_outlined, color: context.appTextPrimary),
            onPressed: () {
              // TODO: 알림 화면으로 이동
            },
          ),
        ],
      ),
      floatingActionButton: _shouldShowFab(activeCycles.length, activeHoldings.length)
          ? FloatingActionButton.small(
              onPressed: () {
                // 탭 1 = 일반 보유
                final forHolding = _currentTabIndex == 1;
                final route = forHolding ? '/stocks/search?forHolding=true' : '/stocks/search';
                context.push(route);
              },
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
      body: Column(
        children: [
          // 포트폴리오 요약 섹션 (스크롤 가능)
          Expanded(
            child: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) => [
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      // 통합 포트폴리오 요약
                      UnifiedPortfolioCard(summary: portfolio),
                      const SizedBox(height: 10),

                      // 자산 배분 차트
                      if (portfolio.hasData)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: PortfolioAllocationChart(
                            alphaCycleRatio: portfolio.alphaCycleRatio,
                            holdingRatio: portfolio.holdingRatio,
                            alphaCycleValue: portfolio.alphaCycleValue,
                            holdingValue: portfolio.holdingValue,
                          ),
                        ),
                      const SizedBox(height: 14),

                      // 탭 바
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: context.appIconBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: TabBar(
                          controller: _tabController,
                          indicator: BoxDecoration(
                            color: context.appSurface,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: context.isDarkMode
                                    ? Colors.white.withValues(alpha: 0.03)
                                    : Colors.black.withValues(alpha: 0.05),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          indicatorPadding: const EdgeInsets.all(4),
                          dividerColor: Colors.transparent,
                          labelColor: context.appTextPrimary,
                          unselectedLabelColor: context.appTextSecondary,
                          labelStyle: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          unselectedLabelStyle: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          tabs: [
                            Tab(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.loop_rounded, size: 16),
                                  const SizedBox(width: 6),
                                  Text('알파 사이클 (${activeCycles.length})'),
                                ],
                              ),
                            ),
                            Tab(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.account_balance_wallet_outlined, size: 16),
                                  const SizedBox(width: 6),
                                  Text('일반 보유 (${activeHoldings.length})'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ],
              // 탭 콘텐츠
              body: TabBarView(
                controller: _tabController,
                children: [
                  // 알파 사이클 탭
                  _AlphaCyclesTab(),
                  // 일반 보유 탭
                  _HoldingsTab(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 알파 사이클 탭
class _AlphaCyclesTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeCycles = ref.watch(activeCyclesProvider);
    // stockQuoteProvider에서 실시간 시세 구독 (WebSocket 연동)
    final quoteState = ref.watch(stockQuoteProvider);

    if (activeCycles.isEmpty) {
      // 빈 상태: 스크롤 비활성화
      return _buildEmptyState(
        context,
        ref,
        icon: Icons.loop_rounded,
        title: '활성 사이클이 없습니다',
        subtitle: '새로운 알파 사이클을 시작해보세요',
        disableScroll: true,
      );
    }

    // 새로 추가된 사이클 중 시세가 없는 것 확인 및 자동 fetch
    final missingTickers = activeCycles
        .where((c) => !quoteState.quotes.containsKey(c.ticker))
        .map((c) => c.ticker)
        .toList();

    if (missingTickers.isNotEmpty) {
      // Schedule fetch after build to avoid modifying state during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(stockQuoteProvider.notifier).fetchQuotes(missingTickers);
      });
    }

    final useGrid = ResponsiveGrid.shouldUseGrid(context);

    Widget buildCard(int index) {
      final cycle = activeCycles[index];
      final quote = quoteState.quotes[cycle.ticker];
      final price = quote?.currentPrice ?? cycle.averagePrice;
      final recommendation = SignalDetector.getRecommendation(cycle, price);

      return ActiveCycleCard(
        cycle: cycle,
        currentPrice: price,
        recommendation: recommendation,
        inGrid: useGrid,
        onTap: () => context.push('/stocks/${cycle.id}'),
        onEndCycle: () async {
          await ref.read(cycleListProvider.notifier).delete(cycle.id);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${cycle.ticker} #${cycle.cycleNumber} 사이클이 종료되었습니다.'),
                backgroundColor: AppColors.primary,
              ),
            );
          }
        },
        onArchive: cycle.totalShares == 0
            ? () async {
                await ref.read(cycleListProvider.notifier).archiveCycle(cycle.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${cycle.ticker} #${cycle.cycleNumber} 사이클이 거래내역으로 이동되었습니다.'),
                      backgroundColor: AppColors.primary,
                    ),
                  );
                }
              }
            : null,
      );
    }

    if (useGrid) {
      final itemW = ResponsiveGrid.gridItemWidth(context);
      return ListView(
        padding: const EdgeInsets.only(bottom: 80),
        children: [
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: ResponsiveGrid.horizontalPadding,
            ),
            child: Wrap(
              spacing: ResponsiveGrid.spacing,
              runSpacing: ResponsiveGrid.runSpacing,
              children: List.generate(activeCycles.length, (index) {
                return SizedBox(width: itemW, child: buildCard(index));
              }),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: activeCycles.length,
      itemBuilder: (context, index) => buildCard(index),
    );
  }
}

/// 일반 보유 탭
class _HoldingsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final holdings = ref.watch(activeHoldingsProvider);
    // stockQuoteProvider에서 실시간 시세 구독 (WebSocket 연동)
    final quoteState = ref.watch(stockQuoteProvider);
    // 현재 환율 (캐시된 값 또는 기본값 1400)
    final exchangeRate = ref.watch(currentExchangeRateProvider);

    if (holdings.isEmpty) {
      return _buildEmptyState(
        context,
        ref,
        icon: Icons.account_balance_wallet_outlined,
        title: '보유 종목이 없습니다',
        subtitle: '알파 사이클 없이 단순 보유할 종목을 추가하세요',
        disableScroll: true,
        forHolding: true,
      );
    }

    // 새로 추가된 종목 중 시세가 없는 것 확인 및 자동 fetch
    final missingTickers = holdings
        .where((h) => !quoteState.quotes.containsKey(h.ticker))
        .map((h) => h.ticker)
        .toList();

    if (missingTickers.isNotEmpty) {
      // Schedule fetch after build to avoid modifying state during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(stockQuoteProvider.notifier).fetchQuotes(missingTickers);
      });
    }

    // 실시간 데이터로 HoldingWithPrice 생성
    final holdingsWithPrice = holdings.map((h) {
      final quote = quoteState.quotes[h.ticker];
      final price = quote?.currentPrice ?? h.averagePrice;
      return HoldingWithPrice(
        holding: h,
        currentPrice: price,
        currentExchangeRate: exchangeRate,
      );
    }).toList();

    final useGrid = ResponsiveGrid.shouldUseGrid(context);

    Widget buildCard(int index) {
      final data = holdingsWithPrice[index];
      return HoldingCard(
        data: data,
        inGrid: useGrid,
        onTap: () => context.push('/holdings/${data.holding.id}'),
        onArchive: data.holding.isEmpty
            ? () async {
                await ref.read(holdingListProvider.notifier).archiveHolding(data.holding.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${data.holding.ticker} ${data.holding.name}이(가) 거래내역으로 이동되었습니다.'),
                      backgroundColor: AppColors.primary,
                    ),
                  );
                }
              }
            : null,
      );
    }

    if (useGrid) {
      final itemW = ResponsiveGrid.gridItemWidth(context);
      return ListView(
        padding: const EdgeInsets.only(bottom: 80),
        children: [
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: ResponsiveGrid.horizontalPadding,
            ),
            child: Wrap(
              spacing: ResponsiveGrid.spacing,
              runSpacing: ResponsiveGrid.runSpacing,
              children: List.generate(holdingsWithPrice.length, (index) {
                return SizedBox(width: itemW, child: buildCard(index));
              }),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: holdingsWithPrice.length,
      itemBuilder: (context, index) => buildCard(index),
    );
  }
}

Widget _buildEmptyState(
  BuildContext context,
  WidgetRef ref, {
  required IconData icon,
  required String title,
  required String subtitle,
  bool disableScroll = false,
  bool forHolding = false,
}) {
  final searchRoute = forHolding ? '/stocks/search?forHolding=true' : '/stocks/search';
  final content = Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          icon,
          size: 64,
          color: context.appBorder,
        ),
        const SizedBox(height: 16),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: context.appTextSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: context.appTextHint,
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () => context.push(searchRoute),
          icon: const Icon(Icons.add),
          label: const Text('종목 추가하기'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    ),
  );

  // 빈 상태에서 스크롤 비활성화
  if (disableScroll) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.5,
        child: content,
      ),
    );
  }

  return content;
}
