import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
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

  List<Color> _getTabColors(WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final smartColor = settings.alphaCycleChartColor != 0
        ? Color(settings.alphaCycleChartColor)
        : AppColors.darkAccent;
    final steadyColor = settings.steadyCycleChartColor != 0
        ? Color(settings.steadyCycleChartColor)
        : const Color(0xFF4ADE80);
    final holdingColor = settings.holdingChartColor != 0
        ? Color(settings.holdingChartColor)
        : const Color(0xFFA78BFA);
    return [smartColor, steadyColor, holdingColor];
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
                tabColors: _getTabColors(ref),
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
  final List<Color> tabColors;

  const _TabBarDelegate({
    required this.tabController,
    required this.alphaCount,
    required this.infiniteBuyCount,
    required this.holdingCount,
    required this.tabColors,
  });

  @override
  double get minExtent => 48;

  @override
  double get maxExtent => 48;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    final selectedIndex = tabController.index;
    final hintColor = context.appTextHint;

    return Container(
      color: context.appBackground,
      child: TabBar(
        controller: tabController,
        indicatorColor: tabColors[selectedIndex],
        indicatorWeight: 2.5,
        labelPadding: EdgeInsets.zero,
        tabs: [
          _buildTab(
            context: context,
            label: 'Smart ($alphaCount)',
            color: selectedIndex == 0 ? tabColors[0] : hintColor,
            isSelected: selectedIndex == 0,
            helpColor: tabColors[0],
            helpContent: _smartCycleHelp,
            helpTitle: 'Smart Cycle',
          ),
          _buildTab(
            context: context,
            label: 'Steady ($infiniteBuyCount)',
            color: selectedIndex == 1 ? tabColors[1] : hintColor,
            isSelected: selectedIndex == 1,
            helpColor: tabColors[1],
            helpContent: _steadyCycleHelp,
            helpTitle: 'Steady Cycle',
          ),
          _buildTab(
            context: context,
            label: '일반 ($holdingCount)',
            color: selectedIndex == 2 ? tabColors[2] : hintColor,
            isSelected: selectedIndex == 2,
          ),
        ],
      ),
    );
  }

  Tab _buildTab({
    required BuildContext context,
    required String label,
    required Color color,
    required bool isSelected,
    Color? helpColor,
    String? helpContent,
    String? helpTitle,
  }) {
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (helpContent != null) ...[
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _showStrategyHelpDialog(
                context,
                title: helpTitle!,
                titleColor: helpColor!,
                content: helpContent,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                child: Icon(
                  Icons.help_outline,
                  size: 14,
                  color: color,
                ),
              ),
            ),
            const SizedBox(width: 2),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  void _showStrategyHelpDialog(
    BuildContext context, {
    required String title,
    required Color titleColor,
    required String content,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.appSurface,
        title: Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: titleColor,
          ),
        ),
        content: SingleChildScrollView(
          child: Text(
            content,
            style: TextStyle(
              fontSize: 13,
              color: context.appTextSecondary,
              height: 1.6,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _TabBarDelegate oldDelegate) {
    return alphaCount != oldDelegate.alphaCount ||
        infiniteBuyCount != oldDelegate.infiniteBuyCount ||
        holdingCount != oldDelegate.holdingCount ||
        tabColors != oldDelegate.tabColors;
  }
}

// ═══════════════════════════════════════════════════════════════
// 전략 설명 텍스트
// ═══════════════════════════════════════════════════════════════

const _smartCycleHelp = '스마트 방어형 매매법\n\n'
    '핵심 메커니즘:\n'
    '• 초기 매수: 시드머니의 20%로 첫 매수\n'
    '• 가중 매수: 하락 시 점진적으로 비중 확대\n'
    '• 승부수: -50% 하락 시 잔여 현금 전량 투입\n'
    '• 적응형 익절: 연속 익절 시 목표가 자동 상향\n'
    '• 현금 보존: 익절 시 원금 회수로 현금 확보\n\n'
    '추천 대상: 안전지향형 투자자, 규칙기반 매매, 단일 종목 집중';

const _steadyCycleHelp = '라오어의 무한매수법 기반 분할매수 전략\n\n'
    '3가지 버전을 지원하며, 사이클 생성 시 선택합니다.\n\n'
    '── V1 Simple (입문) ──\n'
    '• 40분할 기계적 매수\n'
    '• 평단 이하 1회분, 이상 0.5회분\n'
    '• +10% 도달 시 전량 익절\n'
    '• 가장 단순, 상승장에서 최고 효율\n\n'
    '── V2.2 Original (정통) ──\n'
    '• 40분할 + T값 기반 LOC 주문\n'
    '• 매일 매수+매도 주문을 동시에 설정\n'
    '• 하락장에서 미체결로 현금 보존 (MDD -40%)\n'
    '• 원금 소진 시 쿼터 손절모드로 안전장치\n\n'
    '── V3.0 Aggressive (공격) ──\n'
    '• 20분할 + 공격적 LOC 오프셋\n'
    '• 반복리: 매도 수익의 1/40을 매수금에 추가\n'
    '• TQQQ +15%, SOXL +20% 종목별 익절 목표\n'
    '• 고변동성 종목에서 빠른 사이클 회전\n\n'
    '원본: 라오어 「무한매수법」 V2.2(2022) / V3.0(2024)';

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

    final allActive = ref.watch(activeCyclesProvider);

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: cycles.length,
      itemBuilder: (context, index) {
        final cycle = cycles[index];
        return _ActiveCycleCard(
          cycle: cycle,
          allActiveCycles: allActive,
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
  final List<Cycle> allActiveCycles;
  final VoidCallback? onTap;

  const _ActiveCycleCard({
    required this.cycle,
    required this.allActiveCycles,
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
    // 상태 판별
    final isPendingCompletion = cycle.isPendingCompletion;
    final isWaiting = cycle.totalShares == 0 && !isPendingCompletion;
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
                if (cycleDisplayLabel(cycle, allActiveCycles) != null) ...[
                  const SizedBox(width: 6),
                  Text(
                    cycleDisplayLabel(cycle, allActiveCycles)!,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: cycle.nickname.isNotEmpty
                          ? context.appAccent
                          : context.appTextHint,
                    ),
                  ),
                ],
                const SizedBox(width: 6),
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          cycle.name,
                          style: TextStyle(
                            fontSize: 12,
                            color: context.appTextSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (cycle.strategyType == StrategyType.infiniteBuy &&
                          cycle.steadyVersion != SteadyVersion.v1) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.green500.withValues(alpha: context.isDarkMode ? 0.15 : 0.08),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            cycle.steadyVersion == SteadyVersion.v2_2 ? 'V2.2' : 'V3.0',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: context.isDarkMode ? AppColors.green400 : AppColors.green600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (isPendingCompletion) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.green500.withAlpha(context.isDarkMode ? 30 : 20),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('완료 대기', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.green500)),
                  ),
                ] else if (signal != TradeSignal.hold) ...[
                  const SizedBox(width: 6),
                  SignalDisplay(signal: signal),
                ],
              ],
            ),

            // 중단: 전량매도 완료 / 대기중 / 실제 평가금+손익
            if (isPendingCompletion) ...[
              const SizedBox(height: 10),
              // 1줄: ✅ 전량 매도 + 기간 + 회차
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, size: 14, color: AppColors.green500),
                  const SizedBox(width: 5),
                  Text('전량 매도', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.appTextPrimary, height: 1.0)),
                  const SizedBox(width: 8),
                  if (cycle.firstTradeDate != null && cycle.lastTradeDate != null)
                    Expanded(
                      child: Text(
                        '${DateFormat('MM.dd').format(cycle.firstTradeDate!)}~${DateFormat('MM.dd').format(cycle.lastTradeDate!)}'
                        ' (${cycle.lastTradeDate!.difference(cycle.firstTradeDate!).inDays + 1}일)'
                        ' · ${cycle.roundsUsed}회차',
                        style: TextStyle(fontSize: 11, color: context.appTextSecondary, height: 1.0),
                        textAlign: TextAlign.right,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              // 2줄: 순수익
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('순수익', style: TextStyle(fontSize: 11, color: context.appTextSecondary)),
                  Text(
                    '${cycle.realizedProfitKrw >= 0 ? "+" : ""}${formatKrwWithComma(cycle.realizedProfitKrw)}원'
                    ' (${cycle.realizedProfitKrw >= 0 ? "+" : ""}${cycle.realizedProfitRate.toStringAsFixed(1)}%)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: cycle.realizedProfitKrw >= 0 ? AppColors.red500 : AppColors.blue500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // 3줄: 투자금 → 회수금 (라벨 포함)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('투자 ${formatKrwWithComma(cycle.totalBuyAmountKrw)}원',
                      style: TextStyle(fontSize: 11, color: context.appTextSecondary)),
                  Text('→', style: TextStyle(fontSize: 11, color: context.appTextHint)),
                  Text('회수 ${formatKrwWithComma(cycle.totalSellAmountKrw)}원',
                      style: TextStyle(fontSize: 11, color: context.appTextSecondary)),
                ],
              ),
            ] else if (isWaiting) ...[
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
            // 하단 정보: 전량매도는 위에서 다 표시 → 나머지만 설정시드/잔여현금/회차
            if (!isPendingCompletion)
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
