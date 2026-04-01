import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/krw_formatter.dart';
import '../../../data/models/cycle.dart';
import '../../../data/models/trade.dart';
import '../../../domain/trading/ladder_cycle_service.dart';
import '../../providers/providers.dart';
import '../../widgets/common/notification_bell_button.dart';
import '../../widgets/home/portfolio_allocation_chart.dart';
import '../../widgets/cycle/signal_display.dart';
import '../../widgets/holdings/holding_card.dart';
import '../../widgets/common/top_toast.dart';
import '../../widgets/shared/confirm_dialog.dart';
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
    _tabController = TabController(length: 4, vsync: this);
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
    final ladderColor = settings.ladderCycleChartColor != 0
        ? Color(settings.ladderCycleChartColor)
        : AppColors.amber500;
    final holdingColor = settings.holdingChartColor != 0
        ? Color(settings.holdingChartColor)
        : const Color(0xFFA78BFA);
    return [smartColor, steadyColor, ladderColor, holdingColor];
  }

  Widget _buildFab(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 600;
    final isHoldingTab = _tabController.index == 3;
    final isLadderTab = _tabController.index == 2;
    final isSteadyTab = _tabController.index == 1;
    final label = isHoldingTab ? '종목 추가' : '사이클 생성';

    final onPressed = isHoldingTab
        ? () => context.push('/stocks/search?forHolding=true')
        : () => context.push(
              isLadderTab
                  ? '/stocks/setup?strategy=ladderCycle'
                  : isSteadyTab
                      ? '/stocks/setup?strategy=infiniteBuy'
                      : '/stocks/setup',
            );

    return SizedBox(
      height: isMobile ? 36 : 40,
      child: FloatingActionButton.extended(
        onPressed: onPressed,
        backgroundColor: context.appAccent.withValues(alpha: 0.85),
        foregroundColor: Colors.white,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        elevation: 2,
        icon: Icon(Icons.add, size: isMobile ? 16 : 18),
        label: Text(
          label,
          style: TextStyle(fontSize: isMobile ? 12 : 14, fontWeight: FontWeight.w600),
        ),
        extendedPadding: EdgeInsets.symmetric(horizontal: isMobile ? 14 : 18),
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
    final ladderCycles = ref.watch(ladderCyclesProvider);
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
                ladderCount: ladderCycles.length,
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

              // Tab 2: Ladder Cycle
              _CycleListTab(
                cycles: ladderCycles,
                emptyIcon: Icons.stacked_bar_chart,
                emptyMessage: 'Ladder Cycle로\nMDD 기반 가속 매수를 시작해보세요',
              ),

              // Tab 3: 일반 보유
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
  final int ladderCount;
  final int holdingCount;
  final List<Color> tabColors;

  const _TabBarDelegate({
    required this.tabController,
    required this.alphaCount,
    required this.infiniteBuyCount,
    required this.ladderCount,
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
            label: 'Smart',
            count: alphaCount,
            color: selectedIndex == 0 ? tabColors[0] : hintColor,
            isSelected: selectedIndex == 0,
            strategyIcon: Icons.shield_outlined,
            helpColor: tabColors[0],
            helpContent: _smartCycleHelp,
            helpTitle: 'Smart Cycle',
          ),
          _buildTab(
            context: context,
            label: 'Steady',
            count: infiniteBuyCount,
            color: selectedIndex == 1 ? tabColors[1] : hintColor,
            isSelected: selectedIndex == 1,
            strategyIcon: Icons.all_inclusive,
            helpColor: tabColors[1],
            helpContent: _steadyCycleHelp,
            helpTitle: 'Steady Cycle',
          ),
          _buildTab(
            context: context,
            label: 'Ladder',
            count: ladderCount,
            color: selectedIndex == 2 ? tabColors[2] : hintColor,
            isSelected: selectedIndex == 2,
            strategyIcon: Icons.stacked_bar_chart,
            helpColor: tabColors[2],
            helpContent: _ladderCycleHelp,
            helpTitle: 'Ladder Cycle',
          ),
          _buildTab(
            context: context,
            label: '일반',
            count: holdingCount,
            color: selectedIndex == 3 ? tabColors[3] : hintColor,
            isSelected: selectedIndex == 3,
            strategyIcon: Icons.account_balance_wallet_outlined,
          ),
        ],
      ),
    );
  }

  Tab _buildTab({
    required BuildContext context,
    required String label,
    required int count,
    required Color color,
    required bool isSelected,
    IconData? strategyIcon,
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
          if (strategyIcon != null) ...[
            Icon(
              strategyIcon,
              size: 12,
              color: color,
            ),
            const SizedBox(width: 2),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              color: color,
            ),
          ),
          const SizedBox(width: 3),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: color.withValues(alpha: isSelected ? 0.15 : 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: color,
              ),
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
        ladderCount != oldDelegate.ladderCount ||
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

const _ladderCycleHelp = 'Ladder Cycle — MDD 기반 가속 분할매수\n\n'
    'ATH(역사적 신고가) 대비 하락률에 따라 단계별로 매수 비중을 높여가는 전략입니다. '
    '하락이 깊어질수록 더 많은 금액을 투입하여 평균 매입가를 극적으로 낮춥니다.\n\n'
    '6단계 기본 비중 (1-1-2-3-4-5):\n'
    '• 1단계(-10%): 6.25% — 정찰대\n'
    '• 2단계(-19%): 6.25% — 심리적 완충\n'
    '• 3단계(-28%): 12.5% — 본격 매집\n'
    '• 4단계(-37%): 18.75% — 공포 대응\n'
    '• 5단계(-46%): 25% — 패닉 매집\n'
    '• 6단계(-55%): 31.25% — 항복 전량 투입\n\n'
    '고급 설정에서 단계 수(3~6)와 비율을 변경할 수 있습니다.\n\n'
    '매수 모드:\n\n'
    '── 안정형 ──\n'
    '같은 지수를 추종하는 1배/2배/3배 ETF를 단계별로 나눠 매수합니다. '
    '초반엔 안정적인 1배로 시작하고, 하락이 깊어지면 레버리지를 높여갑니다.\n\n'
    '예시) QQQ 기준:\n'
    '• 1단계: QQQ (1배) 매수\n'
    '• 2단계: QLD (2배) 매수\n'
    '• 3~6단계: TQQQ (3배) 매수\n\n'
    '추천 조합 (기준 → 1배 → 2배 → 3배):\n'
    '• QQQ → QQQ → QLD → TQQQ (나스닥 100)\n'
    '• SPY → SPY → SSO → UPRO (S&P 500)\n'
    '• IWM → IWM → UWM → TNA (러셀 2000)\n'
    '• DIA → DIA → DDM → UDOW (다우존스)\n\n'
    '※ 위 조합은 추천이며, 원하는 티커를 자유롭게 선택할 수 있습니다.\n\n'
    '── 공격형 ──\n'
    '처음부터 3배 레버리지 ETF를 모든 단계에서 매수합니다. '
    '기준 지수의 하락률(MDD)로 매수 시점을 판단하되, '
    '실제 매수는 해당 지수의 3배 레버리지로 집중 투입합니다.\n\n'
    '예시) SOXX 기준:\n'
    '• 1~6단계: SOXL (3배) 매수\n\n'
    '※ 기준 지수와 매수 티커는 자유롭게 선택 가능합니다.\n\n'
    '사이클 종료:\n'
    '지수가 새로운 신고점에 도달하면 사이클 종료를 고려합니다. '
    '매도 시점은 매도 가이드를 참고하여 직접 판단합니다.';

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
    // Ladder 공격형: buyTicker 기준 가격, 그 외: cycle.ticker
    final isLadder = cycle.strategyType == StrategyType.ladderCycle;
    final isLadderAggressive = isLadder && cycle.ladderMode != 0;
    final displayTicker = isLadderAggressive && cycle.buyTicker.isNotEmpty
        ? cycle.buyTicker
        : cycle.ticker;

    final prices = ref.watch(closingPricesProvider);
    final currentPrice = prices[displayTicker] ?? 0.0;
    final liveExchangeRate = ref.watch(currentExchangeRateProvider);
    final signal = ref.watch(cycleSignalProvider(cycle.id));

    // 실제 평가금 계산 (라이브 환율 기준, 잔여현금 미포함)
    // Ladder 안정형: 멀티 티커(QQQ+QLD+TQQQ) 합산 평가금
    final double evalAmount;
    if (isLadder && cycle.ladderMode == 0 && cycle.totalShares > 0) {
      final tradeRepo = ref.read(tradeRepositoryProvider);
      final trades = tradeRepo.getByCycleId(cycle.id);
      final usedTickers = trades.map((t) => t.ticker ?? cycle.ticker).toSet();
      final tickerPrices = <String, double>{};
      for (final ticker in usedTickers) {
        tickerPrices[ticker] = prices[ticker] ?? 0;
      }
      final holdings = buildTickerHoldings(
        trades, cycle.ticker, tickerPrices, liveExchangeRate,
      );
      evalAmount = holdings.fold<double>(0, (sum, h) => sum + h.evalAmount);
    } else {
      evalAmount = cycle.totalShares * currentPrice * liveExchangeRate;
    }
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
      onLongPress: () => _confirmDeleteCycle(context, ref, cycle, displayTicker),
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
                  ticker: displayTicker,
                  size: 32,
                  borderRadius: 8,
                ),
                const SizedBox(width: 8),
                Text(
                  displayTicker,
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
                      if (cycle.strategyType == StrategyType.infiniteBuy) ...[
                        const SizedBox(width: 4),
                        Builder(builder: (context) {
                          final steadyColorVal = ref.watch(settingsProvider.select((s) => s.steadyCycleChartColor));
                          final steadyColor = steadyColorVal != 0 ? Color(steadyColorVal) : AppColors.green500;
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: steadyColor.withValues(alpha: context.isDarkMode ? 0.15 : 0.08),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              cycle.steadyVersion == SteadyVersion.v1 ? 'V1'
                                  : cycle.steadyVersion == SteadyVersion.v2_2 ? 'V2.2' : 'V3.0',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: steadyColor,
                              ),
                            ),
                          );
                        }),
                      ],
                      if (cycle.strategyType == StrategyType.ladderCycle) ...[
                        const SizedBox(width: 4),
                        Builder(builder: (context) {
                          final ladderColorVal = ref.watch(settingsProvider.select((s) => s.ladderCycleChartColor));
                          final ladderColor = ladderColorVal != 0 ? Color(ladderColorVal) : AppColors.amber500;
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: ladderColor.withValues(alpha: context.isDarkMode ? 0.15 : 0.08),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              cycle.ladderMode == 0 ? '안정형' : '공격형',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: ladderColor,
                              ),
                            ),
                          );
                        }),
                        // 안정형: 추가 매수 티커 뱃지 (메인 티커 외)
                        if (cycle.ladderMode == 0) ..._buildExtraTickerBadges(context, ref, cycle, displayTicker),
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
                        ' · ${cycle.strategyType == StrategyType.ladderCycle ? '${cycle.currentStep}/${cycle.ladderSteps}단계' : '${cycle.roundsUsed}회차'}',
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
                            : cycle.strategyType == StrategyType.ladderCycle
                                ? '진행단계'
                                : '진행 회차',
                        value: cycle.strategyType == StrategyType.alphaCycleV3
                            ? '+${cycle.currentSellTarget.toStringAsFixed(0)}%'
                            : cycle.strategyType == StrategyType.ladderCycle
                                ? '${cycle.currentStep}/${cycle.ladderSteps}단계'
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

  /// 안정형 Ladder: 메인 티커 외 추가 매수된 티커를 뱃지로 표시
  List<Widget> _buildExtraTickerBadges(
    BuildContext context, WidgetRef ref, Cycle cycle, String mainTicker,
  ) {
    final trades = ref.watch(tradeListProvider(cycle.id));
    // Trade에서 사용된 티커 중 메인 티커를 제외한 것만
    final extraTickers = trades
        .where((t) => t.action == TradeAction.buy)
        .map((t) => t.ticker ?? cycle.ticker)
        .toSet()
        .where((t) => t != mainTicker)
        .toList();

    if (extraTickers.isEmpty) return [];

    return [
      const SizedBox(width: 4),
      Text(
        '+ ${extraTickers.join(' + ')}',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: context.appTextHint,
        ),
      ),
    ];
  }

  void _confirmDeleteCycle(
    BuildContext context, WidgetRef ref, Cycle cycle, String displayTicker,
  ) async {
    final confirmed = await ConfirmDialog.show(
      context: context,
      title: '사이클 삭제',
      message: '$displayTicker 사이클과 모든 거래 내역을 삭제합니다.\n이 작업은 되돌릴 수 없습니다.',
      confirmText: '삭제',
      isDanger: true,
    );
    if (confirmed && context.mounted) {
      ref.read(cycleListProvider.notifier).deleteCycle(cycle.id);
      showTopToast(context, '$displayTicker 사이클이 삭제되었습니다');
    }
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
          onLongPress: () => _confirmDeleteHolding(context, ref, holding),
          onArchive: holding.isEmpty
              ? () => ref
                  .read(holdingListProvider.notifier)
                  .archiveHolding(holding.id)
              : null,
        );
      },
    );
  }

  void _confirmDeleteHolding(
    BuildContext context, WidgetRef ref, dynamic holding,
  ) async {
    final confirmed = await ConfirmDialog.show(
      context: context,
      title: '보유 종목 삭제',
      message: '${holding.ticker} 보유 종목을 삭제합니다.\n이 작업은 되돌릴 수 없습니다.',
      confirmText: '삭제',
      isDanger: true,
    );
    if (confirmed && context.mounted) {
      ref.read(holdingListProvider.notifier).deleteHolding(holding.id);
      showTopToast(context, '${holding.ticker} 보유 종목이 삭제되었습니다');
    }
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
