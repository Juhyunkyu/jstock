import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/krw_formatter.dart';
import '../../../data/models/cycle.dart';
import '../../../domain/trading/trading_math.dart';
import '../../../presentation/providers/cycle_providers.dart';
import '../../../presentation/providers/holding_providers.dart';
import '../../../presentation/providers/portfolio_providers.dart';
import '../../../presentation/providers/settings_providers.dart';
import '../../../presentation/providers/api_providers.dart';
import '../../../presentation/providers/stock_providers.dart';

/// 종목별 도넛 세그먼트 데이터
typedef _TickerSegment = ({String ticker, String label, double value});

/// 내 포트폴리오 차트 위젯
///
/// Smart Cycle + Steady Cycle + 일반 보유의 자산을 도넛 차트로 표시하고,
/// 하단에 총 시드 대비 손익을 보여줍니다.
/// 범례의 색상 네모를 탭하면 색상을 변경할 수 있습니다.
class PortfolioAllocationChart extends ConsumerStatefulWidget {
  /// 통합 포트폴리오 요약 데이터
  final UnifiedPortfolioSummary summary;

  /// 차트 크기
  final double size;

  const PortfolioAllocationChart({
    super.key,
    required this.summary,
    this.size = 130,
  });

  @override
  ConsumerState<PortfolioAllocationChart> createState() =>
      _PortfolioAllocationChartState();
}

class _PortfolioAllocationChartState extends ConsumerState<PortfolioAllocationChart> {
  /// 사용자 선택 색상 (null이면 기본값 사용)
  Color? _smartCycleColor;
  Color? _steadyCycleColor;
  Color? _ladderCycleColor;
  Color? _holdingColor;

  /// 현재 편집 중인 범례 인덱스 (0=Smart, 1=Steady, 2=Ladder, 3=일반 보유, null=없음)
  int? _editingIndex;

  /// 종목별 모드 토글
  bool _showTickerView = false;

  /// 기본 세그먼트 색상 (밝고 선명, 라이트/다크 모두에서 잘 보임)
  static const Color _defaultSmartColor = Color(0xFF58A6FF);  // bright blue
  static const Color _defaultSteadyColor = Color(0xFF4ADE80); // bright green
  static const Color _defaultLadderColor = Color(0xFFFBBF24); // amber
  static const Color _defaultHoldingColor = Color(0xFFA78BFA); // purple

  /// 선택 가능한 색상 팔레트
  static const List<Color> _colorPalette = [
    Color(0xFF58A6FF), // blue
    Color(0xFF4ADE80), // green
    Color(0xFFF97316), // orange
    Color(0xFFA78BFA), // purple
    Color(0xFFF472B6), // pink
    Color(0xFF22D3EE), // cyan
    Color(0xFFFBBF24), // yellow
    Color(0xFFEF4444), // red
    Color(0xFF6366F1), // indigo
    Color(0xFF14B8A6), // teal
    Color(0xFF9CA3AF), // gray-400
    Color(0xFF6B7280), // gray-500
    Color(0xFF4B5563), // gray-600
    Color(0xFFD1D5DB), // gray-300
  ];

  @override
  void initState() {
    super.initState();
    // 저장된 색상 로드 (0이면 기본색 사용)
    final settings = ref.read(settingsProvider);
    if (settings.alphaCycleChartColor != 0) {
      _smartCycleColor = Color(settings.alphaCycleChartColor);
    }
    if (settings.steadyCycleChartColor != 0) {
      _steadyCycleColor = Color(settings.steadyCycleChartColor);
    }
    if (settings.ladderCycleChartColor != 0) {
      _ladderCycleColor = Color(settings.ladderCycleChartColor);
    }
    if (settings.holdingChartColor != 0) {
      _holdingColor = Color(settings.holdingChartColor);
    }
  }

  Color _getSmartColor() => _smartCycleColor ?? _defaultSmartColor;
  Color _getSteadyColor() => _steadyCycleColor ?? _defaultSteadyColor;
  Color _getLadderColor() => _ladderCycleColor ?? _defaultLadderColor;
  Color _getHoldingColor() => _holdingColor ?? _defaultHoldingColor;

  @override
  Widget build(BuildContext context) {
    final summary = widget.summary;
    final hasData = summary.smartCycleCount > 0 ||
        summary.steadyCycleCount > 0 ||
        summary.ladderCycleCount > 0 ||
        summary.holdingCount > 0;
    final smartColor = _getSmartColor();
    final steadyColor = _getSteadyColor();
    final ladderColor = _getLadderColor();
    final holdingColor = _getHoldingColor();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.appCardBackground,
        borderRadius: BorderRadius.circular(12),
        boxShadow: context.isDarkMode
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더 + 색상 팔레트
          Row(
            children: [
              Text(
                '내 포트폴리오',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: context.appTextPrimary,
                ),
              ),
              if (_editingIndex == null) ...[
                const Spacer(),
                GestureDetector(
                  onTap: () => setState(() => _showTickerView = !_showTickerView),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: context.appTextSecondary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _showTickerView ? '종목별' : '전략별',
                          style: TextStyle(fontSize: 11, color: context.appTextSecondary),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.swap_horiz_rounded, size: 14, color: context.appTextSecondary),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 24,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _colorPalette.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 6),
                      itemBuilder: (context, i) {
                        final color = _colorPalette[i];
                        final isSelected = (_editingIndex == 0 &&
                                color.value == smartColor.value) ||
                            (_editingIndex == 1 &&
                                color.value == steadyColor.value) ||
                            (_editingIndex == 2 &&
                                color.value == ladderColor.value) ||
                            (_editingIndex == 3 &&
                                color.value == holdingColor.value);
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              if (_editingIndex == 0) {
                                _smartCycleColor = color;
                              } else if (_editingIndex == 1) {
                                _steadyCycleColor = color;
                              } else if (_editingIndex == 2) {
                                _ladderCycleColor = color;
                              } else if (_editingIndex == 3) {
                                _holdingColor = color;
                              }
                              _editingIndex = null;
                            });
                            // Hive에 색상 영속화
                            ref.read(settingsProvider.notifier).updateChartColors(
                              alphaColor: (_smartCycleColor?.value) ?? 0,
                              steadyColor: (_steadyCycleColor?.value) ?? 0,
                              ladderColor: (_ladderCycleColor?.value) ?? 0,
                              holdingColor: (_holdingColor?.value) ?? 0,
                            );
                          },
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(5),
                              border: isSelected
                                  ? Border.all(
                                      color: context.appTextPrimary, width: 2)
                                  : null,
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: color.withValues(alpha: 0.5),
                                        blurRadius: 4,
                                      )
                                    ]
                                  : null,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),

          // 데이터 이상 감지 경고 배너
          if (summary.hasAnomalousData)
            Container(
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '데이터 이상이 감지되었습니다. 해당 종목의 거래 내역을 확인해 주세요.',
                      style: TextStyle(fontSize: 12, color: AppColors.warning),
                    ),
                  ),
                ],
              ),
            ),

          // 차트 + 범례 + 시드 요약 (반응형)
          LayoutBuilder(
            builder: (context, constraints) {
              final availableWidth = constraints.maxWidth;
              final isWide = availableWidth > 500;
              final chartSize = isWide
                  ? (widget.size * 1.1).clamp(120.0, 160.0)
                  : widget.size;

              List<Widget> legendItems;
              List<PieChartSectionData>? tickerSections;

              if (_showTickerView) {
                final rawSegments = _buildTickerSegments();
                rawSegments.sort((a, b) => b.value.compareTo(a.value));
                legendItems = _buildTickerLegendItems(
                  context: context,
                  sorted: rawSegments,
                  totalValue: summary.totalValue,
                );
                tickerSections = _buildTickerSections(context, rawSegments);
              } else {
                legendItems = _buildLegendItems(
                  context: context,
                  summary: summary,
                  smartColor: smartColor,
                  steadyColor: steadyColor,
                  ladderColor: ladderColor,
                  holdingColor: holdingColor,
                );
              }

              // 모바일: 2열 균등 수직 정렬 (좌: 도넛+총투자, 우: 범례+총손익)
              if (!isWide) {
                final isProfit = summary.totalProfit >= 0;
                final profitColor = isProfit ? AppColors.red500 : AppColors.blue500;
                final sign = isProfit ? '+' : '';

                return Column(
                  children: [
                    // 상단: 도넛(좌) + 범례(우) 균등 2열
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: _buildDonutChart(context, summary, chartSize,
                              smartColor, steadyColor, ladderColor, holdingColor, hasData, false,
                              overrideSections: tickerSections),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: legendItems,
                          ),
                        ),
                      ],
                    ),
                    // 하단: 총 투자 · 총 손익 — 한 줄 수평, 좌우 여백 균등
                    if (hasData) ...[
                      const SizedBox(height: 14),
                      Divider(color: context.appDivider, height: 1),
                      const SizedBox(height: 10),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('총 투자', style: TextStyle(fontSize: 11, color: context.appTextHint)),
                            const SizedBox(width: 6),
                            Text(
                              formatKrw(summary.totalActualInvested),
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: context.appTextPrimary),
                            ),
                            const SizedBox(width: 20),
                            Text('총 손익', style: TextStyle(fontSize: 11, color: context.appTextHint)),
                            const SizedBox(width: 6),
                            Text(
                              '$sign${formatKrw(summary.totalProfit)}($sign${summary.totalReturnRate.toStringAsFixed(2)}%)',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: profitColor),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                );
              }

              // 데스크톱: 좌70% (차트+범례) | 우30% (총투자+총손익)
              return Row(
                children: [
                  // 좌측 70%: 차트 + 범례 (중앙정렬)
                  Expanded(
                    flex: 7,
                    child: Align(
                      alignment: Alignment.center,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: chartSize + 16 + 220),
                        child: Row(
                          children: [
                            _buildDonutChart(context, summary, chartSize,
                                smartColor, steadyColor, ladderColor, holdingColor, hasData, true,
                                overrideSections: tickerSections),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: legendItems,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // 우측 30%: 구분선 + 총투자/총손익 (중앙정렬)
                  if (hasData)
                    Expanded(
                      flex: 3,
                      child: Align(
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 1,
                              height: 60,
                              color: context.appDivider,
                            ),
                            const SizedBox(width: 24),
                            _buildSeedColumn(context, summary),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  /// 범례 아이템 목록 생성 (Smart + Steady + Ladder + 일반 보유)
  /// 평가금(value) 기준으로 표시, 투자금 0이면 "대기중"
  List<Widget> _buildLegendItems({
    required BuildContext context,
    required UnifiedPortfolioSummary summary,
    required Color smartColor,
    required Color steadyColor,
    required Color ladderColor,
    required Color holdingColor,
  }) {
    final items = <Widget>[];

    if (summary.smartCycleCount > 0) {
      final isWaiting = summary.smartCycleActualInvested == 0;
      items.add(_buildLegendItem(
        context: context,
        color: isWaiting ? context.appTextHint : smartColor,
        icon: Icons.shield_outlined,
        label: 'Smart (${summary.smartCycleCount}개)',
        value: isWaiting ? '대기중' : formatKrw(summary.smartCycleValue),
        ratio: isWaiting ? 0 : summary.smartCycleRatio,
        index: 0,
        isWaiting: isWaiting,
      ));
    }

    if (summary.steadyCycleCount > 0) {
      if (items.isNotEmpty) {
        items.add(const SizedBox(height: 8));
      }
      final isWaiting = summary.steadyCycleActualInvested == 0;
      items.add(_buildLegendItem(
        context: context,
        color: isWaiting ? context.appTextHint : steadyColor,
        icon: Icons.all_inclusive,
        label: 'Steady (${summary.steadyCycleCount}개)',
        value: isWaiting ? '대기중' : formatKrw(summary.steadyCycleValue),
        ratio: isWaiting ? 0 : summary.steadyCycleRatio,
        index: 1,
        isWaiting: isWaiting,
      ));
    }

    if (summary.ladderCycleCount > 0) {
      if (items.isNotEmpty) {
        items.add(const SizedBox(height: 8));
      }
      final isWaiting = summary.ladderCycleActualInvested == 0;
      items.add(_buildLegendItem(
        context: context,
        color: isWaiting ? context.appTextHint : ladderColor,
        icon: Icons.stacked_bar_chart,
        label: 'Ladder (${summary.ladderCycleCount}개)',
        value: isWaiting ? '대기중' : formatKrw(summary.ladderCycleValue),
        ratio: isWaiting ? 0 : summary.ladderCycleRatio,
        index: 2,
        isWaiting: isWaiting,
      ));
    }

    if (summary.holdingCount > 0) {
      if (items.isNotEmpty) {
        items.add(const SizedBox(height: 8));
      }
      final isWaiting = summary.holdingInvested == 0;
      items.add(_buildLegendItem(
        context: context,
        color: isWaiting ? context.appTextHint : holdingColor,
        icon: Icons.account_balance_wallet_outlined,
        label: '일반 보유 (${summary.holdingCount}개)',
        value: isWaiting ? '대기중' : formatKrw(summary.holdingValue),
        ratio: isWaiting ? 0 : summary.holdingRatio,
        index: 3,
        isWaiting: isWaiting,
      ));
    }

    return items;
  }

  /// 도넛 차트 위젯
  Widget _buildDonutChart(
    BuildContext context,
    UnifiedPortfolioSummary summary,
    double chartSize,
    Color smartColor,
    Color steadyColor,
    Color ladderColor,
    Color holdingColor,
    bool hasData,
    bool isWide, {
    List<PieChartSectionData>? overrideSections,
  }) {
    final returnRate = summary.totalReturnRate;
    final isProfit = returnRate >= 0;
    final profitColor = isProfit ? AppColors.red500 : AppColors.blue500;
    final sign = isProfit ? '+' : '';

    return SizedBox(
      width: chartSize,
      height: chartSize,
      child: hasData
          ? Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sectionsSpace: 3,
                    centerSpaceRadius: chartSize * 0.38,
                    sections: overrideSections ?? _buildSections(
                        context, summary, smartColor, steadyColor, ladderColor, holdingColor),
                    pieTouchData: PieTouchData(enabled: false),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '총 자산',
                        style: TextStyle(
                          fontSize: isWide ? 10 : 9,
                          color: context.appTextSecondary,
                        ),
                      ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          formatKrw(summary.totalValue),
                          style: TextStyle(
                            fontSize: isWide ? 12 : 11,
                            fontWeight: FontWeight.bold,
                            color: context.appTextPrimary,
                          ),
                        ),
                      ),
                      if (summary.totalActualInvested > 0)
                        Text(
                          '$sign${returnRate.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: isWide ? 10 : 9,
                            fontWeight: FontWeight.w600,
                            color: profitColor,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            )
          : Center(
              child: Text(
                '데이터 없음',
                style: TextStyle(
                  fontSize: 12,
                  color: context.appTextSecondary,
                ),
              ),
            ),
    );
  }

  /// 총 투자 / 총 손익 — 세로 (데스크톱 3열용)
  Widget _buildSeedColumn(BuildContext context, UnifiedPortfolioSummary summary) {
    final isProfit = summary.totalProfit >= 0;
    final profitColor = isProfit ? AppColors.red500 : AppColors.blue500;
    final sign = isProfit ? '+' : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('총 투자', style: TextStyle(fontSize: 11, color: context.appTextHint)),
        const SizedBox(height: 2),
        Text(
          formatKrw(summary.totalActualInvested),
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.appTextPrimary),
        ),
        const SizedBox(height: 10),
        Text('총 손익', style: TextStyle(fontSize: 11, color: context.appTextHint)),
        const SizedBox(height: 2),
        Text(
          '$sign${formatKrw(summary.totalProfit)}',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: profitColor),
        ),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          decoration: BoxDecoration(
            color: profitColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '$sign${summary.totalReturnRate.toStringAsFixed(2)}%',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: profitColor),
          ),
        ),
      ],
    );
  }


  Widget _buildLegendItem({
    required BuildContext context,
    required Color color,
    required IconData icon,
    required String label,
    required String value,
    required double ratio,
    required int index,
    bool isWaiting = false,
  }) {
    final isEditing = _editingIndex == index;

    return Row(
      children: [
        // 색상 네모 (대기중이면 회색, 탭 불가)
        if (isWaiting)
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: context.appTextHint,
              borderRadius: BorderRadius.circular(4),
            ),
          )
        else
          GestureDetector(
            onTap: () {
              setState(() {
                _editingIndex = isEditing ? null : index;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
                border: isEditing
                    ? Border.all(color: context.appTextPrimary, width: 2)
                    : null,
              ),
            ),
          ),
        const SizedBox(width: 6),
        // 아이콘 + 라벨 + 금액 + 퍼센테이지 (컴팩트)
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 13,
                    color: isWaiting ? context.appTextHint : color,
                  ),
                  const SizedBox(width: 3),
                  Flexible(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.appTextSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              if (isWaiting)
                Text(
                  '대기중',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.appTextHint,
                  ),
                )
              else
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: value,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: context.appTextPrimary,
                        ),
                      ),
                      TextSpan(
                        text: '  ${ratio.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: context.appTextSecondary,
                        ),
                      ),
                    ],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 종목별 모드
  // ═══════════════════════════════════════════════════════════════

  String _strategyLabel(Cycle cycle) {
    return switch (cycle.strategyType) {
      StrategyType.alphaCycleV3 => 'Smart',
      StrategyType.ladderCycle => 'Ladder',
      _ => 'Steady',
    };
  }

  List<_TickerSegment> _buildTickerSegments() {
    final prices = ref.watch(closingPricesProvider);
    final exchangeRate = ref.watch(currentExchangeRateProvider);
    final activeCycles = ref.watch(activeCyclesProvider);
    final holdingsWithPrice = ref.watch(holdingsWithPriceProvider);

    final raw = <({String ticker, String label, double value, String strategy})>[];

    // 일반보유
    for (final hwp in holdingsWithPrice) {
      if (hwp.holding.totalShares <= 0) continue;
      final value = hwp.currentValue;
      if (value <= 0) continue;
      raw.add((ticker: hwp.holding.ticker, label: hwp.holding.ticker, value: value, strategy: '보유'));
    }

    // 사이클
    for (final cycle in activeCycles) {
      final strategyLabel = _strategyLabel(cycle);

      if (cycle.isPendingCompletion) {
        final value = cycle.totalSellAmountKrw;
        if (value <= 0) continue;
        raw.add((ticker: cycle.ticker, label: cycle.ticker, value: value, strategy: strategyLabel));
        continue;
      }

      // Ladder 안정형: averagePrice=0이고 멀티티커라 단순 evaluatedAmount 불가 → seedAmount 기반 근사
      if (cycle.strategyType == StrategyType.ladderCycle && cycle.ladderMode == 0) {
        final actualInvested = cycle.seedAmount - cycle.remainingCash;
        final value = actualInvested > 0 ? actualInvested : 0.0;
        if (value <= 0) continue;
        raw.add((ticker: cycle.ticker, label: cycle.ticker, value: value, strategy: strategyLabel));
        continue;
      }

      final evalTicker = (cycle.strategyType == StrategyType.ladderCycle &&
              cycle.buyTicker.isNotEmpty)
          ? cycle.buyTicker
          : cycle.ticker;
      final price = prices[evalTicker] ?? 0.0;
      final value = TradingMath.evaluatedAmount(cycle.totalShares, price, exchangeRate);
      if (value <= 0) continue;

      raw.add((ticker: evalTicker, label: evalTicker, value: value, strategy: strategyLabel));
    }

    // 같은 티커 중복 감지 → 접미사 추가
    final tickerCount = <String, int>{};
    for (final s in raw) {
      tickerCount[s.ticker] = (tickerCount[s.ticker] ?? 0) + 1;
    }

    return raw.map((s) {
      final needsSuffix = (tickerCount[s.ticker] ?? 0) > 1;
      final label = needsSuffix ? '${s.ticker} (${s.strategy})' : s.ticker;
      return (ticker: s.ticker, label: label, value: s.value);
    }).toList();
  }

  List<PieChartSectionData> _buildTickerSections(
    BuildContext context,
    List<_TickerSegment> sorted,
  ) {
    if (sorted.isEmpty) {
      return [PieChartSectionData(color: context.appDivider, value: 100, title: '', radius: 15)];
    }

    final top = sorted.take(6).toList();
    final rest = sorted.skip(6).toList();
    final otherValue = rest.fold(0.0, (sum, s) => sum + s.value);

    final sections = <PieChartSectionData>[];
    for (int i = 0; i < top.length; i++) {
      sections.add(PieChartSectionData(
        color: _colorPalette[i % _colorPalette.length],
        value: top[i].value,
        title: '',
        radius: 15,
      ));
    }

    if (otherValue > 0) {
      sections.add(PieChartSectionData(
        color: _colorPalette[6 % _colorPalette.length],
        value: otherValue,
        title: '',
        radius: 15,
      ));
    }

    return sections;
  }

  List<Widget> _buildTickerLegendItems({
    required BuildContext context,
    required List<_TickerSegment> sorted,
    required double totalValue,
  }) {
    final top = sorted.take(6).toList();
    final rest = sorted.skip(6).toList();
    final otherCount = rest.length;
    final otherValue = rest.fold(0.0, (sum, s) => sum + s.value);

    final items = <Widget>[];

    for (int i = 0; i < top.length; i++) {
      final seg = top[i];
      final ratio = totalValue > 0 ? (seg.value / totalValue) * 100 : 0.0;
      final color = _colorPalette[i % _colorPalette.length];

      if (items.isNotEmpty) items.add(const SizedBox(height: 6));
      items.add(Row(
        children: [
          Container(
            width: 12, height: 12,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              '${seg.label}  ${ratio.toStringAsFixed(1)}%',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: context.appTextSecondary),
            ),
          ),
        ],
      ));
    }

    if (otherCount > 0) {
      final otherRatio = totalValue > 0 ? (otherValue / totalValue) * 100 : 0.0;
      if (items.isNotEmpty) items.add(const SizedBox(height: 6));
      items.add(Row(
        children: [
          Container(
            width: 12, height: 12,
            decoration: BoxDecoration(
              color: _colorPalette[6 % _colorPalette.length],
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              '기타 (${otherCount}종)  ${otherRatio.toStringAsFixed(1)}%',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: context.appTextSecondary),
            ),
          ),
        ],
      ));
    }

    return items;
  }

  // ═══════════════════════════════════════════════════════════════
  // 전략별 모드 (기존)
  // ═══════════════════════════════════════════════════════════════

  List<PieChartSectionData> _buildSections(
    BuildContext context,
    UnifiedPortfolioSummary summary,
    Color smartColor,
    Color steadyColor,
    Color ladderColor,
    Color holdingColor,
  ) {
    final sections = <PieChartSectionData>[];

    // 평가금(value)이 있는 세그먼트만 도넛에 포함 (대기중은 범례에서만 표시)
    if (summary.smartCycleCount > 0 && summary.smartCycleValue > 0) {
      sections.add(PieChartSectionData(
        color: smartColor,
        value: summary.smartCycleValue,
        title: '',
        radius: 15,
      ));
    }

    if (summary.steadyCycleCount > 0 && summary.steadyCycleValue > 0) {
      sections.add(PieChartSectionData(
        color: steadyColor,
        value: summary.steadyCycleValue,
        title: '',
        radius: 15,
      ));
    }

    if (summary.ladderCycleCount > 0 && summary.ladderCycleValue > 0) {
      sections.add(PieChartSectionData(
        color: ladderColor,
        value: summary.ladderCycleValue,
        title: '',
        radius: 15,
      ));
    }

    if (summary.holdingCount > 0 && summary.holdingValue > 0) {
      sections.add(PieChartSectionData(
        color: holdingColor,
        value: summary.holdingValue,
        title: '',
        radius: 15,
      ));
    }

    // 모든 세그먼트가 대기중이면 회색 플레이스홀더
    if (sections.isEmpty) {
      sections.add(PieChartSectionData(
        color: context.appDivider,
        value: 100,
        title: '',
        radius: 15,
      ));
    }

    return sections;
  }
}
