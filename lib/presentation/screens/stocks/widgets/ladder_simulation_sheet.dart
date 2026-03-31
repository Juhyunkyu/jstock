import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/krw_formatter.dart';
import '../../../../data/models/cycle.dart';
import '../../../../domain/trading/ladder_simulation.dart';
import '../../../providers/providers.dart';

/// Ladder 단계별 투입 시뮬레이션 BottomSheet
class LadderSimulationSheet extends ConsumerWidget {
  final Cycle cycle;

  const LadderSimulationSheet({super.key, required this.cycle});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMobile = MediaQuery.sizeOf(context).width < 600;
    final isStable = cycle.ladderMode == 0;

    // 기준 티커 현재가
    final basePrice = ref.watch(
      closingPricesProvider.select((prices) => prices[cycle.ticker] ?? 0.0),
    );
    final exchangeRate = ref.watch(currentExchangeRateProvider);

    // 매수 티커들의 현재가 수집
    final buyPrices = <String, double>{};
    if (isStable) {
      for (final t in _stableTickers(cycle)) {
        buyPrices[t] = ref.watch(
          closingPricesProvider.select((prices) => prices[t] ?? 0.0),
        );
      }
    } else {
      final bt = cycle.buyTicker.isNotEmpty ? cycle.buyTicker : cycle.ticker;
      buyPrices[bt] = ref.watch(
        closingPricesProvider.select((prices) => prices[bt] ?? 0.0),
      );
    }

    // 시뮬레이션 실행
    final steps = simulateLadder(
      cycle: cycle,
      currentBasePrice: basePrice,
      currentBuyPrices: buyPrices,
      exchangeRate: exchangeRate,
    );

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      builder: (context, scrollController) {
        return Column(
          children: [
            // 핸들 바
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: context.appDivider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // 헤더
            _buildHeader(context, isMobile, isStable, exchangeRate),

            const SizedBox(height: 8),

            // 테이블
            Expanded(
              child: steps.isEmpty
                  ? Center(
                      child: Text(
                        '시뮬레이션 데이터를 생성할 수 없습니다.\nATH, 현재가, 환율을 확인해 주세요.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: context.appTextHint,
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      controller: scrollController,
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 10 : 16,
                      ),
                      child: isStable
                          ? _buildStableTable(context, steps, isMobile)
                          : _buildAggressiveTable(context, steps, isMobile),
                    ),
            ),

            // 하단 요약 + 면책
            if (steps.isNotEmpty)
              _buildFooter(context, steps, isStable, isMobile),
          ],
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 헤더
  // ═══════════════════════════════════════════════════════════════

  Widget _buildHeader(
    BuildContext context,
    bool isMobile,
    bool isStable,
    double exchangeRate,
  ) {
    final subTitle = isStable
        ? '${cycle.ticker} 기준 (${_stableTickers(cycle).join('/')})'
        : _aggressiveSubTitle();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 타이틀 행
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.analytics_outlined, size: 16, color: context.appTextPrimary),
                  const SizedBox(width: 6),
                  Text(
                    '단계별 투입 시뮬레이션',
                    style: TextStyle(
                      fontSize: isMobile ? 15 : 17,
                      fontWeight: FontWeight.bold,
                      color: context.appTextPrimary,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Icon(Icons.close, size: 20, color: context.appTextHint),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // 서브타이틀
          Text(
            subTitle,
            style: TextStyle(
              fontSize: isMobile ? 12 : 13,
              color: context.appTextSecondary,
            ),
          ),
          const SizedBox(height: 2),
          // 정보 행
          Text(
            'ATH \$${cycle.athPrice.toStringAsFixed(2)}  '
            '시드 ${formatCashShort(cycle.seedAmount)}  '
            '환율 \u20a9${exchangeRate.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: isMobile ? 10 : 11,
              color: context.appTextHint,
            ),
          ),
        ],
      ),
    );
  }

  String _aggressiveSubTitle() {
    final bt = cycle.buyTicker.isNotEmpty ? cycle.buyTicker : cycle.ticker;
    if (bt == cycle.ticker) return '$bt 단일 매수';
    return '${cycle.ticker} \u2192 $bt (3x)';
  }

  // ═══════════════════════════════════════════════════════════════
  // 공격형 테이블
  // ═══════════════════════════════════════════════════════════════

  Widget _buildAggressiveTable(
    BuildContext context,
    List<LadderSimulationStep> steps,
    bool isMobile,
  ) {
    final headerStyle = TextStyle(
      fontSize: isMobile ? 10 : 11,
      fontWeight: FontWeight.w700,
      color: context.appTextSecondary,
    );
    final bt = cycle.buyTicker.isNotEmpty ? cycle.buyTicker : cycle.ticker;

    return Column(
      children: [
        // 헤더 행
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              SizedBox(width: 36, child: Text('', style: headerStyle)),
              Expanded(flex: 3, child: Text(bt, style: headerStyle, textAlign: TextAlign.right)),
              Expanded(flex: 2, child: Text('투입금', style: headerStyle, textAlign: TextAlign.right)),
              Expanded(flex: 2, child: Text('누적', style: headerStyle, textAlign: TextAlign.right)),
              Expanded(flex: 4, child: Text('평단가(%)', style: headerStyle, textAlign: TextAlign.right)),
              Expanded(flex: 2, child: Text('평가금', style: headerStyle, textAlign: TextAlign.right)),
            ],
          ),
        ),
        Divider(height: 1, color: context.appDivider),
        // 데이터 행
        ...steps.map((s) => _buildAggressiveRow(context, s, isMobile)),
      ],
    );
  }

  Widget _buildAggressiveRow(
    BuildContext context,
    LadderSimulationStep step,
    bool isMobile,
  ) {
    final cellStyle = TextStyle(
      fontSize: isMobile ? 10 : 11,
      color: step.isCompleted
          ? context.appTextHint
          : step.isCurrent
              ? context.appTextPrimary
              : context.appTextSecondary,
      fontWeight: step.isCurrent ? FontWeight.w700 : FontWeight.w400,
    );

    // 평단가(%) + 본주 회복
    final vwapPnlStr = step.pnlPercent >= 0
        ? '${step.pnlPercent.toStringAsFixed(0)}%'
        : '${step.pnlPercent.toStringAsFixed(0)}%';
    final recoveryStr = step.recoveryPercent > 0
        ? ' 본주+${step.recoveryPercent.toStringAsFixed(0)}%'
        : '';

    final pnlColor = step.pnlPercent >= 0 ? AppColors.red500 : AppColors.blue500;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 5),
      decoration: step.isCurrent
          ? BoxDecoration(
              color: (context.isDarkMode ? AppColors.amber400 : AppColors.amber500)
                  .withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(4),
            )
          : null,
      child: Row(
        children: [
          // 단계 아이콘
          SizedBox(
            width: 36,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (step.isCompleted)
                  Icon(Icons.check_circle, size: 12, color: AppColors.green500)
                else if (step.isCurrent)
                  Icon(
                    Icons.play_arrow,
                    size: 12,
                    color: context.isDarkMode ? AppColors.amber400 : AppColors.amber500,
                  )
                else
                  const SizedBox(width: 12),
                const SizedBox(width: 2),
                Text('${step.step}', style: cellStyle),
              ],
            ),
          ),
          // 매수 티커 예상가
          Expanded(
            flex: 3,
            child: Text(
              '\$${step.buyTickerEstPrice.toStringAsFixed(2)}',
              style: cellStyle,
              textAlign: TextAlign.right,
            ),
          ),
          // 투입금
          Expanded(
            flex: 2,
            child: Text(
              formatCashShort(step.investAmountKrw),
              style: cellStyle,
              textAlign: TextAlign.right,
            ),
          ),
          // 누적
          Expanded(
            flex: 2,
            child: Text(
              formatCashShort(step.cumulativeInvestKrw),
              style: cellStyle,
              textAlign: TextAlign.right,
            ),
          ),
          // 평단가(%) + 본주 회복
          Expanded(
            flex: 4,
            child: RichText(
              textAlign: TextAlign.right,
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '\$${step.vwap.toStringAsFixed(2)}',
                    style: cellStyle,
                  ),
                  TextSpan(
                    text: '($vwapPnlStr',
                    style: cellStyle.copyWith(
                      color: pnlColor,
                      fontSize: (isMobile ? 10 : 11) - 1,
                    ),
                  ),
                  if (recoveryStr.isNotEmpty)
                    TextSpan(
                      text: recoveryStr,
                      style: cellStyle.copyWith(
                        color: context.appTextHint,
                        fontSize: (isMobile ? 10 : 11) - 2,
                      ),
                    ),
                  TextSpan(
                    text: ')',
                    style: cellStyle.copyWith(
                      color: pnlColor,
                      fontSize: (isMobile ? 10 : 11) - 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 평가금
          Expanded(
            flex: 2,
            child: Text(
              formatCashShort(step.cumulativeEvalKrw),
              style: cellStyle,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 안정형 테이블
  // ═══════════════════════════════════════════════════════════════

  Widget _buildStableTable(
    BuildContext context,
    List<LadderSimulationStep> steps,
    bool isMobile,
  ) {
    final headerStyle = TextStyle(
      fontSize: isMobile ? 10 : 11,
      fontWeight: FontWeight.w700,
      color: context.appTextSecondary,
    );

    return Column(
      children: [
        // 헤더 행
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              SizedBox(width: 36, child: Text('', style: headerStyle)),
              Expanded(flex: 2, child: Text('매수', style: headerStyle, textAlign: TextAlign.right)),
              Expanded(flex: 3, child: Text('예상가', style: headerStyle, textAlign: TextAlign.right)),
              Expanded(flex: 2, child: Text('투입금', style: headerStyle, textAlign: TextAlign.right)),
              Expanded(flex: 2, child: Text('누적', style: headerStyle, textAlign: TextAlign.right)),
              Expanded(flex: 2, child: Text('손익', style: headerStyle, textAlign: TextAlign.right)),
            ],
          ),
        ),
        Divider(height: 1, color: context.appDivider),
        // 데이터 행
        ...steps.map((s) => _buildStableRow(context, s, isMobile)),
      ],
    );
  }

  Widget _buildStableRow(
    BuildContext context,
    LadderSimulationStep step,
    bool isMobile,
  ) {
    final cellStyle = TextStyle(
      fontSize: isMobile ? 10 : 11,
      color: step.isCompleted
          ? context.appTextHint
          : step.isCurrent
              ? context.appTextPrimary
              : context.appTextSecondary,
      fontWeight: step.isCurrent ? FontWeight.w700 : FontWeight.w400,
    );

    final pnlColor = step.pnlPercent >= 0 ? AppColors.red500 : AppColors.blue500;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 5),
      decoration: step.isCurrent
          ? BoxDecoration(
              color: (context.isDarkMode ? AppColors.amber400 : AppColors.amber500)
                  .withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(4),
            )
          : null,
      child: Row(
        children: [
          // 단계 아이콘
          SizedBox(
            width: 36,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (step.isCompleted)
                  Icon(Icons.check_circle, size: 12, color: AppColors.green500)
                else if (step.isCurrent)
                  Icon(
                    Icons.play_arrow,
                    size: 12,
                    color: context.isDarkMode ? AppColors.amber400 : AppColors.amber500,
                  )
                else
                  const SizedBox(width: 12),
                const SizedBox(width: 2),
                Text('${step.step}', style: cellStyle),
              ],
            ),
          ),
          // 매수 티커
          Expanded(
            flex: 2,
            child: Text(
              step.buyTicker,
              style: cellStyle.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.right,
            ),
          ),
          // 예상가
          Expanded(
            flex: 3,
            child: Text(
              '\$${step.buyTickerEstPrice.toStringAsFixed(1)}',
              style: cellStyle,
              textAlign: TextAlign.right,
            ),
          ),
          // 투입금
          Expanded(
            flex: 2,
            child: Text(
              formatCashShort(step.investAmountKrw),
              style: cellStyle,
              textAlign: TextAlign.right,
            ),
          ),
          // 누적
          Expanded(
            flex: 2,
            child: Text(
              formatCashShort(step.cumulativeInvestKrw),
              style: cellStyle,
              textAlign: TextAlign.right,
            ),
          ),
          // 손익
          Expanded(
            flex: 2,
            child: Text(
              '${step.pnlPercent >= 0 ? '+' : ''}${step.pnlPercent.toStringAsFixed(1)}%',
              style: cellStyle.copyWith(color: pnlColor),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 하단 요약 + 면책
  // ═══════════════════════════════════════════════════════════════

  Widget _buildFooter(
    BuildContext context,
    List<LadderSimulationStep> steps,
    bool isStable,
    bool isMobile,
  ) {
    final last = steps.last;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
        child: Column(
          children: [
            Divider(height: 1, color: context.appDivider),
            const SizedBox(height: 8),
            // 요약
            if (isStable)
              _buildStableSummary(context, steps, isMobile)
            else
              _buildAggressiveSummary(context, steps, last, isMobile),
            const SizedBox(height: 6),
            // 면책
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '\u26a0 ',
                  style: TextStyle(fontSize: 10, color: context.appTextHint),
                ),
                Expanded(
                  child: Text(
                    '레버리지 근사값입니다. 변동성 감쇄로 실제 손실이 더 클 수 있습니다.',
                    style: TextStyle(fontSize: 10, color: context.appTextHint),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAggressiveSummary(
    BuildContext context,
    List<LadderSimulationStep> steps,
    LadderSimulationStep last,
    bool isMobile,
  ) {
    final totalShares = steps.fold<double>(0, (s, step) => s + step.shares);
    return Text(
      '${last.step}단계 완료 시 VWAP \$${last.vwap.toStringAsFixed(2)} / '
      '총 ${totalShares.toInt()}주',
      style: TextStyle(
        fontSize: isMobile ? 11 : 12,
        fontWeight: FontWeight.w600,
        color: context.appTextPrimary,
      ),
    );
  }

  Widget _buildStableSummary(
    BuildContext context,
    List<LadderSimulationStep> steps,
    bool isMobile,
  ) {
    // 티커별 수량 합산
    final tickerShares = <String, double>{};
    for (final step in steps) {
      tickerShares[step.buyTicker] =
          (tickerShares[step.buyTicker] ?? 0) + step.shares;
    }

    final parts = tickerShares.entries
        .map((e) => '${e.key} ${e.value.toInt()}주')
        .join(' / ');

    return Text(
      parts,
      style: TextStyle(
        fontSize: isMobile ? 11 : 12,
        fontWeight: FontWeight.w600,
        color: context.appTextPrimary,
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 유틸
  // ═══════════════════════════════════════════════════════════════

  /// 안정형에서 사용되는 고유 티커 목록
  Set<String> _stableTickers(Cycle cycle) {
    final tickers = <String>{};
    if (cycle.buyTicker1x.isNotEmpty) tickers.add(cycle.buyTicker1x);
    if (cycle.buyTicker2x.isNotEmpty) tickers.add(cycle.buyTicker2x);
    if (cycle.buyTicker3x.isNotEmpty) tickers.add(cycle.buyTicker3x);
    if (tickers.isEmpty) tickers.add(cycle.ticker);
    return tickers;
  }
}
