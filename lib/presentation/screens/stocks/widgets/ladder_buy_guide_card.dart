import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/krw_formatter.dart';
import '../../../../data/models/cycle.dart';
import '../../../../data/models/trade.dart';
import '../../../../domain/trading/ladder_cycle_service.dart';
import '../../../providers/providers.dart';
import '../../../widgets/common/top_toast.dart';

/// Ladder Cycle 매수 가이드 카드
///
/// - 매수 신호가 있을 때: 단계 매수 정보 + 안정형 티커 선택 + 추천 수량
/// - 대기 중일 때: 다음 단계까지 필요한 MDD 표시
class LadderBuyGuideCard extends ConsumerStatefulWidget {
  final Cycle cycle;
  final TradeSignal signal;
  final double? signalAmount;

  const LadderBuyGuideCard({
    super.key,
    required this.cycle,
    required this.signal,
    this.signalAmount,
  });

  @override
  ConsumerState<LadderBuyGuideCard> createState() => _LadderBuyGuideCardState();
}

class _LadderBuyGuideCardState extends ConsumerState<LadderBuyGuideCard> {
  String? _selectedTicker;

  @override
  void initState() {
    super.initState();
    _initSelectedTicker();
  }

  void _initSelectedTicker() {
    final cycle = widget.cycle;
    if (cycle.ladderMode == 0) {
      // 안정형: 추천 순서 첫 번째 티커 기본 선택
      final nextStep = cycle.currentStep + 1;
      final recommended = recommendedTickers(cycle, nextStep);
      _selectedTicker = recommended.first;
    } else {
      // 공격형: buyTicker에서 읽기 (하위호환: 빈 문자열이면 ticker 사용)
      _selectedTicker = cycle.buyTicker.isNotEmpty ? cycle.buyTicker : cycle.ticker;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cycle = widget.cycle;
    final signal = widget.signal;
    final isMobile = MediaQuery.sizeOf(context).width < 600;

    final isBuySignal = signal.name.startsWith('ladderStep');
    final isHold = !isBuySignal;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.appBorder, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '📊 매수 가이드',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: context.appTextPrimary,
                ),
              ),
              GestureDetector(
                onTap: () => _showHelpDialog(context),
                child: Icon(Icons.help_outline, size: 18, color: context.appTextHint),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (isBuySignal) ...[
            _buildBuyGuide(context, cycle, signal, isMobile),
          ] else if (isHold) ...[
            _buildHoldGuide(context, cycle, isMobile),
          ],
        ],
      ),
    );
  }

  Widget _buildBuyGuide(BuildContext context, Cycle cycle, TradeSignal signal, bool isMobile) {
    final targetStep = int.tryParse(signal.name.replaceAll('ladderStep', '')) ?? 0;
    // 현재 MDD 계산
    final prices = ref.watch(closingPricesProvider);
    final basePrice = prices[cycle.ticker] ?? 0.0;
    final currentMdd = cycle.athPrice > 0
        ? calculateMDD(cycle.athPrice, basePrice)
        : 0.0;

    final buyAmount = widget.signalAmount ?? 0.0;
    final liveExchangeRate = ref.watch(currentExchangeRateProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 단계 매수 정보
        Text(
          '$targetStep단계 매수 (MDD: ${currentMdd.toStringAsFixed(1)}%)',
          style: TextStyle(
            fontSize: isMobile ? 14 : 15,
            fontWeight: FontWeight.w700,
            color: context.isDarkMode ? AppColors.amber400 : AppColors.amber500,
          ),
        ),
        const SizedBox(height: 10),

        // 안정형: 티커 선택 뱃지
        if (cycle.ladderMode == 0) ...[
          _buildTickerSelector(context, cycle, targetStep),
          const SizedBox(height: 10),
        ],

        // 매수 주문 금액
        if (buyAmount > 0) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '매수 주문',
                style: TextStyle(fontSize: 12, color: context.appTextSecondary),
              ),
              Text(
                formatKrw(buyAmount),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: context.appTextPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // 추천 수량
          _buildRecommendedOrder(context, cycle, buyAmount, liveExchangeRate),
        ],
      ],
    );
  }

  Widget _buildTickerSelector(BuildContext context, Cycle cycle, int step) {
    final recommended = recommendedTickers(cycle, step);

    return Wrap(
      spacing: 8,
      children: recommended.map((ticker) {
        final isSelected = ticker == _selectedTicker;
        final tickerPrice = ref.watch(
          closingPricesProvider.select((prices) => prices[ticker] ?? 0.0),
        );

        // 미구독 티커 lazy 로드
        if (tickerPrice == 0.0) {
          ref.read(stockPriceProvider.notifier).loadSymbols([ticker]);
        }

        return GestureDetector(
          onTap: () => setState(() => _selectedTicker = ticker),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected
                  ? (context.isDarkMode ? AppColors.amber400 : AppColors.amber500)
                      .withValues(alpha: 0.15)
                  : context.appBackground,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected
                    ? (context.isDarkMode ? AppColors.amber400 : AppColors.amber500)
                    : context.appBorder,
                width: isSelected ? 1.5 : 0.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  ticker,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isSelected
                        ? (context.isDarkMode ? AppColors.amber400 : AppColors.amber500)
                        : context.appTextPrimary,
                  ),
                ),
                if (isSelected) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.check,
                    size: 14,
                    color: context.isDarkMode ? AppColors.amber400 : AppColors.amber500,
                  ),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRecommendedOrder(
    BuildContext context,
    Cycle cycle,
    double buyAmountKrw,
    double liveExchangeRate,
  ) {
    final ticker = _selectedTicker ?? cycle.ticker;
    final tickerPrice = ref.watch(
      closingPricesProvider.select((prices) => prices[ticker] ?? 0.0),
    );

    if (tickerPrice <= 0 || liveExchangeRate <= 0) {
      return const SizedBox.shrink();
    }

    final buyAmountUsd = buyAmountKrw / liveExchangeRate;
    final recommendedShares = buyAmountUsd / tickerPrice;
    final floorShares = recommendedShares.floor();

    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        children: [
          Container(
            width: 4, height: 4,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: context.isDarkMode ? AppColors.amber400 : AppColors.amber500,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Text(
              '$ticker: \$${tickerPrice.toStringAsFixed(2)} \u00d7 $floorShares주 (${recommendedShares.toStringAsFixed(1)})',
              style: TextStyle(fontSize: 12, color: context.appTextPrimary),
            ),
          ),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(
                text: '\$${tickerPrice.toStringAsFixed(2)} / $floorShares주',
              ));
              showTopToast(context, '복사됨: \$${tickerPrice.toStringAsFixed(2)} / $floorShares주');
            },
            child: Icon(Icons.copy, size: 14, color: context.appTextHint),
          ),
        ],
      ),
    );
  }

  Widget _buildHoldGuide(BuildContext context, Cycle cycle, bool isMobile) {
    final triggers = parseLadderTriggers(cycle.ladderTriggers, steps: cycle.ladderSteps);
    final nextStep = cycle.currentStep + 1;

    if (nextStep > triggers.length) {
      return Text(
        '모든 단계 완료 — 매도 타이밍을 기다리세요',
        style: TextStyle(
          fontSize: 12,
          color: context.appTextSecondary,
        ),
      );
    }

    final nextTrigger = triggers[nextStep - 1];

    // 현재 MDD
    final prices = ref.watch(closingPricesProvider);
    final basePrice = prices[cycle.ticker] ?? 0.0;
    final currentMdd = cycle.athPrice > 0
        ? calculateMDD(cycle.athPrice, basePrice)
        : 0.0;

    final remainingMdd = (nextTrigger - currentMdd).abs();

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: context.appBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.hourglass_empty, size: 16, color: context.appTextHint),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '대기 중 — 다음 $nextStep단계까지 MDD ${remainingMdd.toStringAsFixed(1)}% 추가 하락 필요',
              style: TextStyle(
                fontSize: 12,
                color: context.appTextSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.appSurface,
        title: Row(
          children: [
            Icon(Icons.help_outline, size: 20, color: ctx.appAccent),
            const SizedBox(width: 8),
            Text(
              'Ladder Cycle 가이드',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: ctx.appTextPrimary,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Text(
            'Ladder Cycle — MDD 기반 가속 분할매수\n\n'
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
            '── 공격형 ──\n'
            '처음부터 3배 레버리지 ETF를 모든 단계에서 매수합니다.\n\n'
            '사이클 종료:\n'
            '지수가 새로운 신고점에 도달하면 사이클 종료를 고려합니다. '
            '매도 시점은 매도 가이드를 참고하여 직접 판단합니다.',
            style: TextStyle(
              fontSize: 13,
              color: ctx.appTextSecondary,
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
}
