import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/krw_formatter.dart';
import '../../../data/models/cycle.dart';
import '../../../data/models/trade.dart';
import '../../providers/providers.dart';
import '../../widgets/common/notification_bell_button.dart';
import '../../widgets/home/portfolio_allocation_chart.dart';
import '../../widgets/cycle/signal_display.dart';
import '../../widgets/holdings/holding_card.dart';
import '../../widgets/shared/ticker_logo.dart';

/// My 탭 화면
///
/// 포트폴리오 요약, 자산 배분 차트, 전략별 사이클 및 보유 종목을 표시합니다.
class StocksScreen extends ConsumerStatefulWidget {
  const StocksScreen({super.key});

  @override
  ConsumerState<StocksScreen> createState() => _StocksScreenState();
}

class _StocksScreenState extends ConsumerState<StocksScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Widget _buildFab(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 600;
    final isHoldingTab = _tabController.index == 2;

    final onPressed = isHoldingTab
        ? () => context.push('/stocks/search?forHolding=true')
        : () => context.push(
              _tabController.index == 1
                  ? '/stocks/setup?strategy=infiniteBuy'
                  : '/stocks/setup',
            );

    if (isMobile) {
      return FloatingActionButton.small(
        onPressed: onPressed,
        backgroundColor: context.appAccent,
        child: const Icon(Icons.add, color: Colors.white),
      );
    }

    return FloatingActionButton.extended(
      onPressed: onPressed,
      backgroundColor: context.appAccent,
      foregroundColor: Colors.white,
      icon: const Icon(Icons.add),
      label: Text(
        isHoldingTab ? '종목 추가' : '새 사이클',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 여러 ticker 사용 — select 적용 불가 (unifiedPortfolioProvider + _HoldingListTab에 전체 Map 전달)
    final prices = ref.watch(closingPricesProvider);
    final summary = ref.watch(unifiedPortfolioProvider(prices));
    final alphaCycles = ref.watch(alphaCyclesProvider);
    final infiniteBuyCycles = ref.watch(infiniteBuyCyclesProvider);
    final activeHoldings = ref.watch(activeHoldingsProvider);
    final exchangeRate = ref.watch(currentExchangeRateProvider);

    return Scaffold(
      backgroundColor: context.appBackground,
      body: SafeArea(
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverAppBar(
              floating: true,
              toolbarHeight: 56,
              backgroundColor: context.appBackground,
              elevation: 0,
              centerTitle: false,
              titleSpacing: 16,
              title: Text(
                'My',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: context.appTextPrimary,
                ),
              ),
              actions: [
                IconButton(
                  icon: Icon(
                    Icons.search,
                    color: context.appTextPrimary,
                  ),
                  onPressed: () => context.push('/stocks/search'),
                ),
                const NotificationBellButton(),
                const SizedBox(width: 8),
              ],
            ),
            SliverToBoxAdapter(
              child: Column(
                children: [
                  const SizedBox(height: 8),

                  // 도넛 차트 (총자산/총투자/총손익 포함)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: PortfolioAllocationChart(
                      summary: summary,
                      size: 130,
                    ),
                  ),

                  const SizedBox(height: 8),
                ],
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _TabBarDelegate(
                tabController: _tabController,
                alphaCount: alphaCycles.length,
                infiniteBuyCount: infiniteBuyCycles.length,
                holdingCount: activeHoldings.length,
              ),
            ),
          ],
          body: TabBarView(
            controller: _tabController,
            children: [
              // Tab 0: Smart Cycle
              _CycleListTab(
                cycles: alphaCycles,
                emptyIcon: Icons.shield_outlined,
                emptyMessage: 'Smart Cycle 전략으로\n안정적 수익을 추구해보세요',
              ),

              // Tab 1: Steady Cycle
              _CycleListTab(
                cycles: infiniteBuyCycles,
                emptyIcon: Icons.all_inclusive,
                emptyMessage: 'Steady Cycle로\n꾸준한 복리 수익을 추구해보세요',
              ),

              // Tab 2: 일반 보유
              _HoldingListTab(
                holdings: activeHoldings,
                prices: prices,
                exchangeRate: exchangeRate,
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: _buildFab(context),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// TabBar Delegate
// ═══════════════════════════════════════════════════════════════

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabController tabController;
  final int alphaCount;
  final int infiniteBuyCount;
  final int holdingCount;

  const _TabBarDelegate({
    required this.tabController,
    required this.alphaCount,
    required this.infiniteBuyCount,
    required this.holdingCount,
  });

  @override
  double get minExtent => 48;

  @override
  double get maxExtent => 48;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: context.appBackground,
      child: TabBar(
        controller: tabController,
        indicatorColor: context.appAccent,
        indicatorWeight: 2.5,
        labelColor: context.appAccent,
        unselectedLabelColor: context.appTextHint,
        labelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        tabs: [
          Tab(text: 'Smart ($alphaCount)'),
          Tab(text: 'Steady ($infiniteBuyCount)'),
          Tab(text: '일반 ($holdingCount)'),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _TabBarDelegate oldDelegate) {
    return alphaCount != oldDelegate.alphaCount ||
        infiniteBuyCount != oldDelegate.infiniteBuyCount ||
        holdingCount != oldDelegate.holdingCount;
  }
}

// ═══════════════════════════════════════════════════════════════
// 사이클 목록 탭
// ═══════════════════════════════════════════════════════════════

class _CycleListTab extends ConsumerWidget {
  final List<Cycle> cycles;
  final IconData emptyIcon;
  final String emptyMessage;

  const _CycleListTab({
    required this.cycles,
    required this.emptyIcon,
    required this.emptyMessage,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (cycles.isEmpty) {
      return _EmptyState(
        icon: emptyIcon,
        message: emptyMessage,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: cycles.length,
      itemBuilder: (context, index) {
        final cycle = cycles[index];
        return _ActiveCycleCard(
          cycle: cycle,
          onTap: () => context.push('/stocks/detail/${cycle.id}'),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// 활성 사이클 카드
// ═══════════════════════════════════════════════════════════════

class _ActiveCycleCard extends ConsumerWidget {
  final Cycle cycle;
  final VoidCallback? onTap;

  const _ActiveCycleCard({
    required this.cycle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentPrice = ref.watch(
      closingPricesProvider.select((prices) => prices[cycle.ticker] ?? 0.0),
    );
    final liveExchangeRate = ref.watch(currentExchangeRateProvider);
    final signal = ref.watch(cycleSignalProvider(cycle.id));

    // 실제 평가금 계산 (라이브 환율 기준, 잔여현금 미포함)
    final evalAmount = cycle.totalShares * currentPrice * liveExchangeRate;
    final investedAmount = cycle.seedAmount - cycle.remainingCash; // 실제 투입금
    final profit = evalAmount - investedAmount; // 실제 투입 대비 손익
    final returnRate =
        investedAmount > 0 ? (profit / investedAmount) * 100 : 0.0;
    final isWaiting = cycle.totalShares == 0; // 대기중 여부
    final isProfit = profit >= 0;
    final profitColor = isProfit ? AppColors.red500 : AppColors.blue500;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.appSurface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: context.appCardShadow,
        ),
        child: Column(
          children: [
            // 상단: 종목 정보 + 전략 배지 + 신호
            Row(
              children: [
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
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    cycle.name,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.appTextSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (signal != TradeSignal.hold) ...[
                  const SizedBox(width: 6),
                  SignalDisplay(signal: signal),
                ],
              ],
            ),

            // 중단: 실제 평가금 + 손익 (또는 대기중)
            if (isWaiting) ...[
              const SizedBox(height: 12),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: context.appBackground,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.hourglass_empty,
                          size: 16, color: context.appTextHint),
                      const SizedBox(width: 6),
                      Text(
                        '대기중',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: context.appTextHint,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '실제 평가금',
                          style: TextStyle(
                            fontSize: 10,
                            color: context.appTextSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${formatKrwWithComma(evalAmount)}\u2009원',
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
                        const SizedBox(height: 4),
                        Text(
                          '${isProfit ? '+' : ''}${formatKrwWithComma(profit)}\u2009원'
                          ' (${isProfit ? '+' : ''}${returnRate.toStringAsFixed(1)}%)',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: profit == 0
                                ? context.appTextPrimary
                                : profitColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 10),

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
                    child: _CycleInfoColumn(
                      label: '설정시드',
                      value: '${formatKrwWithComma(cycle.seedAmount)}\u2009원',
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 24,
                    color: context.appDivider,
                  ),
                  Expanded(
                    child: _CycleInfoColumn(
                      label: '잔여현금',
                      value:
                          '${formatKrwWithComma(cycle.remainingCash)}\u2009원',
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 24,
                    color: context.appDivider,
                  ),
                  Expanded(
                    child: _CycleInfoColumn(
                      label: cycle.strategyType == StrategyType.alphaCycleV3
                          ? '익절 목표'
                          : '진행 회차',
                      value: cycle.strategyType == StrategyType.alphaCycleV3
                          ? '+${cycle.currentSellTarget.toStringAsFixed(0)}%'
                          : '${cycle.roundsUsed}/${cycle.totalRounds}회',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CycleInfoColumn extends StatelessWidget {
  final String label;
  final String value;

  const _CycleInfoColumn({
    required this.label,
    required this.value,
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
            color: context.appTextPrimary,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// 보유 종목 탭
// ═══════════════════════════════════════════════════════════════

class _HoldingListTab extends ConsumerWidget {
  final List holdings;
  final Map<String, double> prices;
  final double exchangeRate;

  const _HoldingListTab({
    required this.holdings,
    required this.prices,
    required this.exchangeRate,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (holdings.isEmpty) {
      return const _EmptyState(
        icon: Icons.account_balance_wallet_outlined,
        message: '종목을 추가해보세요',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: holdings.length,
      itemBuilder: (context, index) {
        final holding = holdings[index];
        final currentPrice = prices[holding.ticker] ?? 0.0;
        final data = HoldingWithPrice(
          holding: holding,
          currentPrice: currentPrice,
          currentExchangeRate: exchangeRate,
        );

        return HoldingCard(
          data: data,
          onTap: () => context.push('/holdings/${holding.id}'),
          onArchive: holding.isEmpty
              ? () => ref
                  .read(holdingListProvider.notifier)
                  .archiveHolding(holding.id)
              : null,
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// 빈 상태 위젯
// ═══════════════════════════════════════════════════════════════

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyState({
    required this.icon,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 48,
              color: context.appTextHint,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: context.appTextSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
