import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/krw_formatter.dart';
import '../../../../data/models/cycle.dart';
import '../../../../data/models/trade.dart';
import '../../../../domain/trading/ladder_cycle_service.dart';
import '../../../../domain/trading/trading_math.dart';
import '../../../providers/providers.dart';
import '../../../widgets/shared/info_row.dart';
import '../../holdings/widgets/profit_loss_section.dart';
import 'cycle_info_card.dart';
import 'cycle_trade_card.dart';
import 'ladder_progress_bar.dart';
import 'ladder_buy_guide_card.dart';
import 'ladder_ticker_holdings.dart';
import 'ladder_exchange_rate_editor.dart';

/// Ladder Cycle 상세 화면 body
///
/// cycle_detail_screen에서 Ladder일 때 이 위젯을 사용.
/// 안정형(멀티 티커)과 공격형/초공격형(단일 티커) 분기 포함.
class LadderDetailBody extends ConsumerWidget {
  final String cycleId;

  const LadderDetailBody({super.key, required this.cycleId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cycles = ref.watch(cycleListProvider);
    final cycle = cycles.where((c) => c.id == cycleId).firstOrNull;
    if (cycle == null) return const SizedBox.shrink();

    final isMobile = MediaQuery.sizeOf(context).width < 600;
    final isStable = cycle.ladderMode == 0; // 안정형

    final trades = ref.watch(tradeListProvider(cycleId));
    final signal = ref.watch(cycleSignalProvider(cycleId));
    final signalAmount = ref.watch(cycleSignalAmountProvider(cycleId));
    final liveExchangeRate = ref.watch(currentExchangeRateProvider);

    // 기준 티커(QQQ) 현재가 — MDD 계산용
    final basePrice = ref.watch(
      closingPricesProvider.select((prices) => prices[cycle.ticker] ?? 0.0),
    );
    final currentMdd = cycle.athPrice > 0
        ? calculateMDD(cycle.athPrice, basePrice)
        : 0.0;

    // 안정형: Trade 기반 lazy 구독
    if (isStable) {
      final usedTickers = trades
          .map((t) => t.ticker ?? cycle.ticker)
          .toSet()
          .where((t) => t != cycle.ticker)
          .toList();
      if (usedTickers.isNotEmpty) {
        ref.read(stockPriceProvider.notifier).loadSymbols(usedTickers);
      }
    }

    // PnL 계산
    final hasPosition = cycle.totalShares > 0;
    final investedAmount = cycle.totalInvestedAmount;
    final weightedAvgExchangeRate = cycle.exchangeRateAtEntry;

    // 안정형 vs 공격형 PnL/보유 분기
    double totalEvalKrw;
    double usdPL;
    double usdReturnRate;
    double currencyPL;
    List<TickerHolding> tickerHoldings = [];
    Map<String, double> currentPrices = {};

    if (isStable && hasPosition) {
      // 안정형: buildTickerHoldings 사용
      final allUsedTickers = trades
          .map((t) => t.ticker ?? cycle.ticker)
          .toSet();
      for (final ticker in allUsedTickers) {
        currentPrices[ticker] = ref.watch(
          closingPricesProvider.select((prices) => prices[ticker] ?? 0.0),
        );
      }
      tickerHoldings = buildTickerHoldings(
        trades, cycle.ticker, currentPrices, liveExchangeRate,
      );
      totalEvalKrw = tickerHoldings.fold<double>(0, (s, h) => s + h.evalAmount);

      // 합산 USD PnL — 티커별 (shares * (currentPrice - vwap))
      final totalUsdPL = tickerHoldings.fold<double>(0, (s, h) {
        final cp = currentPrices[h.ticker] ?? 0.0;
        return s + (cp - h.vwap) * h.shares;
      });
      usdPL = totalUsdPL;
      // 합산 투자금 USD
      final totalInvestedUsd = tickerHoldings.fold<double>(0, (s, h) {
        return s + h.vwap * h.shares;
      });
      usdReturnRate = totalInvestedUsd > 0 ? (totalUsdPL / totalInvestedUsd) * 100 : 0.0;

      // 합산 환차손익
      currencyPL = tickerHoldings.fold<double>(0, (s, h) {
        final cp = currentPrices[h.ticker] ?? 0.0;
        return s + h.exchangePnl(cp, liveExchangeRate);
      });
    } else {
      // 공격형: buyTicker에서 읽기 (하위호환: 빈 문자열이면 ticker 사용)
      final buyTicker = isStable ? cycle.ticker : (cycle.buyTicker.isNotEmpty ? cycle.buyTicker : cycle.ticker);
      final buyTickerPrice = ref.watch(
        closingPricesProvider.select((prices) => prices[buyTicker] ?? 0.0),
      );
      totalEvalKrw = TradingMath.evaluatedAmount(
        cycle.totalShares, buyTickerPrice, liveExchangeRate,
      );
      usdPL = hasPosition
          ? (buyTickerPrice - cycle.averagePrice) * cycle.totalShares
          : 0.0;
      usdReturnRate = hasPosition && cycle.averagePrice > 0
          ? TradingMath.returnRate(buyTickerPrice, cycle.averagePrice)
          : 0.0;
      currencyPL = hasPosition
          ? (liveExchangeRate - weightedAvgExchangeRate) * buyTickerPrice * cycle.totalShares
          : 0.0;
      currentPrices[buyTicker] = buyTickerPrice;
    }

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: isMobile ? 8 : 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. PnL 그라데이션 카드
                _buildPnLCard(
                  context, ref, cycle, basePrice, currentMdd,
                  liveExchangeRate, usdPL, usdReturnRate, currencyPL,
                  investedAmount, isStable, currentPrices, hasPosition, isMobile,
                ),
                SizedBox(height: isMobile ? 10 : 16),

                // 2. 진행도 바
                LadderProgressBar(
                  currentStep: cycle.currentStep,
                  totalSteps: cycle.ladderSteps,
                  ladderTriggers: cycle.ladderTriggers,
                  cycle: cycle,
                ),
                SizedBox(height: isMobile ? 10 : 16),

                // 3. 매수 가이드 카드 (신호 있거나 대기 중)
                if (cycle.status == CycleStatus.active)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: LadderBuyGuideCard(
                      cycle: cycle,
                      signal: signal,
                      signalAmount: signalAmount,
                    ),
                  ),
                if (cycle.status == CycleStatus.active)
                  SizedBox(height: isMobile ? 10 : 16),

                // 4. 보유 현황
                if (hasPosition) ...[
                  if (isStable)
                    // 안정형: 멀티 티커 테이블
                    LadderTickerHoldings(
                      holdings: tickerHoldings,
                      currentPrices: currentPrices,
                      liveExchangeRate: liveExchangeRate,
                    )
                  else
                    // 공격형/초공격형: 기존 CycleInfoCard 패턴 (보유 정보만)
                    _buildSingleTickerInfo(
                      context, ref, cycle, totalEvalKrw,
                      weightedAvgExchangeRate, liveExchangeRate,
                      currentPrices, isMobile,
                    ),
                  SizedBox(height: isMobile ? 10 : 16),
                ],

                // 5. 매입환율 (안정형: 멀티 편집, 공격형: 기본 편집)
                if (hasPosition && isStable && tickerHoldings.isNotEmpty)
                  _buildStableExchangeRateEditor(
                    context, ref, cycle, tickerHoldings, liveExchangeRate,
                  )
                else if (hasPosition && !isStable)
                  _buildSingleExchangeRate(context, ref, cycle, weightedAvgExchangeRate),
                if (hasPosition) SizedBox(height: isMobile ? 10 : 16),

                // 6. 거래 내역
                _buildTradeHistorySection(context, trades, cycle, isMobile),
                SizedBox(height: isMobile ? 14 : 20),

                // 8. 사이클 완료 버튼
                if (cycle.status == CycleStatus.active)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildCompleteButton(context, ref, cycle),
                  ),

                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 안정형 보유 합산 라벨 생성 (buyTicker1x+2x+3x)
  String _stableTickerLabel(Cycle cycle) {
    final tickers = <String>{};
    if (cycle.buyTicker1x.isNotEmpty) tickers.add(cycle.buyTicker1x);
    if (cycle.buyTicker2x.isNotEmpty) tickers.add(cycle.buyTicker2x);
    if (cycle.buyTicker3x.isNotEmpty) tickers.add(cycle.buyTicker3x);
    if (tickers.isEmpty) return cycle.ticker;
    return tickers.join('+');
  }

  // ═══════════════════════════════════════════════════════════════
  // PnL 그라데이션 카드
  // ═══════════════════════════════════════════════════════════════

  Widget _buildPnLCard(
    BuildContext context,
    WidgetRef ref,
    Cycle cycle,
    double basePrice,
    double currentMdd,
    double liveExchangeRate,
    double usdPL,
    double usdReturnRate,
    double currencyPL,
    double investedAmount,
    bool isStable,
    Map<String, double> currentPrices,
    bool hasPosition,
    bool isMobile,
  ) {
    final buyTicker = isStable ? null : (cycle.buyTicker.isNotEmpty ? cycle.buyTicker : cycle.ticker);
    final buyTickerPrice = buyTicker != null ? (currentPrices[buyTicker] ?? 0.0) : 0.0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.secondary, AppColors.secondaryDark],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.secondary.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 기준 시세 (QQQ) + ATH
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '기준 시세 (${cycle.ticker})',
                style: const TextStyle(fontSize: 11, color: Colors.white70),
              ),
              Text(
                'ATH \$${cycle.athPrice.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 11, color: Colors.white60),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // 현재 시세 + MDD + 환율
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '현재 시세',
                style: TextStyle(fontSize: 11, color: Colors.white70),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Text(
                        '\$${basePrice.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.blue500.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'MDD ${currentMdd.toStringAsFixed(1)}%',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '환율: \u20a9${liveExchangeRate.toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 10, color: Colors.white60),
                  ),
                ],
              ),
            ],
          ),

          // 공격형: 매수 티커 현재 시세 추가 줄
          if (buyTicker != null) ...[
            const SizedBox(height: 4),
            const Divider(color: Colors.white24, height: 1),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$buyTicker 현재 시세',
                  style: const TextStyle(fontSize: 11, color: Colors.white70),
                ),
                Text(
                  '\$${buyTickerPrice.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ],

          if (hasPosition) ...[
            const SizedBox(height: 6),
            const Divider(color: Colors.white24, height: 1),
            const SizedBox(height: 6),

            // 외화손익
            SimpleProfitRow(
              label: '외화손익',
              value: usdPL,
              percentage: usdReturnRate,
              isUsd: true,
            ),
            const SizedBox(height: 5),

            // 원화손익
            SimpleProfitRow(
              label: '원화손익',
              value: usdPL * liveExchangeRate,
              percentage: usdReturnRate,
              isUsd: false,
            ),
            const SizedBox(height: 5),

            // 환차손익
            () {
              final pureKrwPL = usdPL * liveExchangeRate;
              final totalKrwPL = pureKrwPL + currencyPL;
              final totalKrwReturnRate = investedAmount > 0
                  ? (totalKrwPL / investedAmount) * 100
                  : 0.0;
              return CurrencyProfitRow(
                label: '환차손익',
                totalValue: totalKrwPL,
                currencyValue: currencyPL,
                percentage: totalKrwReturnRate,
              );
            }(),

            // 안정형: 합산 표시
            if (isStable) ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '※ ${_stableTickerLabel(cycle)} 보유 합산',
                  style: const TextStyle(fontSize: 9, color: Colors.white54),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 공격형/초공격형: 단일 티커 보유 정보
  // ═══════════════════════════════════════════════════════════════

  Widget _buildSingleTickerInfo(
    BuildContext context,
    WidgetRef ref,
    Cycle cycle,
    double evaluatedAmountKrw,
    double weightedAvgExchangeRate,
    double liveExchangeRate,
    Map<String, double> currentPrices,
    bool isMobile,
  ) {
    final buyTicker = cycle.buyTicker.isNotEmpty ? cycle.buyTicker : cycle.ticker;
    final buyTickerPrice = currentPrices[buyTicker] ?? 0.0;

    return CycleInfoCard(
      cycle: cycle,
      currentPrice: buyTickerPrice,
      liveExchangeRate: liveExchangeRate,
      evaluatedAmountKrw: evaluatedAmountKrw,
      weightedAvgExchangeRate: weightedAvgExchangeRate,
      onExchangeRateChanged: (newRate) async {
        cycle.exchangeRateAtEntry = newRate;
        await ref.read(cycleListProvider.notifier).saveCycle(cycle);
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 안정형: 멀티 티커 환율 편집
  // ═══════════════════════════════════════════════════════════════

  Widget _buildStableExchangeRateEditor(
    BuildContext context,
    WidgetRef ref,
    Cycle cycle,
    List<TickerHolding> holdings,
    double liveExchangeRate,
  ) {
    // 전체 평균 매입환율 계산
    final totalInvestedKrw = holdings.fold<double>(0, (s, h) {
      return s + h.shares * h.vwap * h.avgExRate;
    });
    final totalInvestedUsd = holdings.fold<double>(0, (s, h) {
      return s + h.shares * h.vwap;
    });
    final overallAvgExRate = totalInvestedUsd > 0
        ? totalInvestedKrw / totalInvestedUsd
        : liveExchangeRate;

    return LadderExchangeRateEditor(
      holdings: holdings,
      overallAvgExRate: overallAvgExRate,
      onSave: (rates) async {
        // 안정형 환율 편집은 개별 Trade 수정 아닌 Cycle 전체 환율 업데이트
        // 가중평균으로 단일 exchangeRateAtEntry 갱신
        if (rates.isNotEmpty) {
          double totalWeightedRate = 0;
          double totalWeight = 0;
          for (final h in holdings) {
            final newRate = rates[h.ticker] ?? h.avgExRate;
            final weight = h.shares * h.vwap;
            totalWeightedRate += newRate * weight;
            totalWeight += weight;
          }
          if (totalWeight > 0) {
            cycle.exchangeRateAtEntry = totalWeightedRate / totalWeight;
            await ref.read(cycleListProvider.notifier).saveCycle(cycle);
          }
        }
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 공격형: 단일 환율 표시 (CycleInfoCard 내에 포함되므로 별도 불필요)
  // ═══════════════════════════════════════════════════════════════

  Widget _buildSingleExchangeRate(
    BuildContext context,
    WidgetRef ref,
    Cycle cycle,
    double weightedAvgExchangeRate,
  ) {
    // 공격형/초공격형은 CycleInfoCard에서 환율 편집이 포함되므로
    // 별도 위젯 불필요 — 빈 위젯 반환
    return const SizedBox.shrink();
  }

  // ═══════════════════════════════════════════════════════════════
  // Ladder Cycle 정보 카드
  // ═══════════════════════════════════════════════════════════════

  Widget _buildLadderInfoCard(
    BuildContext context,
    Cycle cycle,
    double investedAmount,
    double totalEvalKrw,
    bool isMobile,
  ) {
    final cashRatio = cycle.seedAmount > 0
        ? (cycle.remainingCash / cycle.seedAmount * 100)
        : 0.0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: context.isDarkMode
                ? Colors.white.withValues(alpha: 0.03)
                : Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Ladder Cycle 섹션 헤더
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: context.appBackground,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                InfoRow(fontSize: 12, label: '설정 시드', value: formatCashShort(cycle.seedAmount)),
                const SizedBox(height: 6),
                InfoRow(fontSize: 12, label: '잔여현금', value: formatCashShort(cycle.remainingCash)),
                const SizedBox(height: 6),
                InfoRow(fontSize: 12, label: '현금비율', value: '${cashRatio.toStringAsFixed(1)}%'),
                const SizedBox(height: 6),
                InfoRow(
                  fontSize: 12,
                  label: '총 매입금액',
                  value: formatCashShort(investedAmount),
                ),
                const SizedBox(height: 6),
                InfoRow(
                  fontSize: 12,
                  label: '총 평가금',
                  value: formatCashShort(totalEvalKrw),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // 매도 가이드 섹션
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: context.appBackground,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '매도 가이드',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: context.appTextPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                _buildGuideItem(context, '+50% 시 원금 30% 현금화 고려'),
                _buildGuideItem(context, 'RSI > 80 시 단계적 익절 고려'),
                _buildGuideItem(context, '20MA 하향돌파 시 포지션 축소 고려'),
                _buildGuideItem(context, '신고점 도달 시 사이클 종료 고려'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuideItem(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '\u2022 ',
            style: TextStyle(fontSize: 11, color: context.appTextHint),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 11, color: context.appTextSecondary),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 사이클 완료 버튼
  // ═══════════════════════════════════════════════════════════════

  Widget _buildCompleteButton(BuildContext context, WidgetRef ref, Cycle cycle) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _handleCompleteCycle(context, ref, cycle),
        icon: Icon(
          Icons.check_circle_outline,
          size: 18,
          color: context.appTextSecondary,
        ),
        label: Text(
          '사이클 완료',
          style: TextStyle(color: context.appTextSecondary),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: context.appBorder, width: 1),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 거래 내역 섹션 (cycle_detail_screen 패턴 재사용)
  // ═══════════════════════════════════════════════════════════════

  Widget _buildTradeHistorySection(
    BuildContext context, List<Trade> trades, Cycle cycle, bool isMobile,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            '거래 내역 (${trades.length}건)',
            style: TextStyle(
              fontSize: isMobile ? 13 : 16,
              fontWeight: FontWeight.bold,
              color: context.appTextPrimary,
            ),
          ),
        ),
        SizedBox(height: isMobile ? 6 : 10),
        if (trades.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: isMobile ? 24 : 32),
              decoration: BoxDecoration(
                color: context.appSurface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  '아직 거래 내역이 없습니다',
                  style: TextStyle(
                    fontSize: isMobile ? 12 : 14,
                    color: context.appTextHint,
                  ),
                ),
              ),
            ),
          )
        else
          ...() {
            final grouped = <String, List<Trade>>{};
            final ungrouped = <Trade>[];
            for (final t in trades) {
              if (t.groupId != null) {
                grouped.putIfAbsent(t.groupId!, () => []).add(t);
              } else {
                ungrouped.add(t);
              }
            }
            final allEntries = <List<Trade>>[];
            final processedGroups = <String>{};
            for (final t in trades) {
              if (t.groupId != null) {
                if (processedGroups.add(t.groupId!)) {
                  allEntries.add(grouped[t.groupId!]!);
                }
              } else {
                allEntries.add([t]);
              }
            }
            final totalRounds = allEntries.length;
            return allEntries.asMap().entries.map((entry) {
              final roundNum = totalRounds - entry.key;
              final firstTrade = entry.value.first;
              final dateStr = DateFormat('yyyy.MM.dd').format(firstTrade.tradedAt);
              return _LadderTradeRoundSection(
                roundNumber: roundNum,
                dateStr: dateStr,
                child: CycleTradeCard(
                  trade: firstTrade,
                  groupedTrades: entry.value.length > 1 ? entry.value : null,
                  cycle: cycle,
                  isFirst: true,
                  isLast: true,
                  readOnly: cycle.status != CycleStatus.active,
                ),
              );
            });
          }(),
      ],
    );
  }

  Future<void> _handleCompleteCycle(
    BuildContext context,
    WidgetRef ref,
    Cycle cycle,
  ) async {
    final prices = ref.read(closingPricesProvider);
    final currentPrice = prices[cycle.ticker] ?? 0.0;
    final returnRate = cycle.totalShares > 0 && cycle.averagePrice > 0
        ? TradingMath.returnRate(currentPrice, cycle.averagePrice)
        : 0.0;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.appSurface,
        title: Text(
          '사이클 완료',
          style: TextStyle(color: ctx.appTextPrimary),
        ),
        content: Text(
          '이 사이클을 완료 처리하시겠습니까?\n완료 후 거래내역 탭에서 확인할 수 있습니다.',
          style: TextStyle(color: ctx.appTextSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('취소', style: TextStyle(color: ctx.appTextSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('완료', style: TextStyle(color: ctx.appAccent)),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      cycle.status = CycleStatus.completed;
      cycle.completedReturnRate = returnRate;
      await ref.read(cycleListProvider.notifier).saveCycle(cycle);
    }
  }
}

/// 회차별 테두리 섹션 (N회차 · 날짜 라벨 + 둥근 카드)
/// cycle_detail_screen의 _TradeRoundSection과 동일한 패턴
class _LadderTradeRoundSection extends StatelessWidget {
  final int roundNumber;
  final String dateStr;
  final Widget child;

  const _LadderTradeRoundSection({
    required this.roundNumber,
    required this.dateStr,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 10),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: context.appBorder),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: child,
              ),
            ),
          ),
          Positioned(
            left: 14,
            top: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: context.appSurface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: context.appBorder, width: 0.5),
              ),
              child: Text(
                '$roundNumber회차 · $dateStr',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: context.appTextSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
