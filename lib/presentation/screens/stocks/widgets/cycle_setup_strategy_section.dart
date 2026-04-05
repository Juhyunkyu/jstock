import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/cycle.dart';

/// 전략 선택 SegmentedButton (Smart / Steady / Ladder)
class CycleStrategySelector extends StatelessWidget {
  final StrategyType selectedStrategy;
  final ValueChanged<StrategyType> onChanged;

  const CycleStrategySelector({
    super.key,
    required this.selectedStrategy,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<StrategyType>(
        segments: [
          ButtonSegment<StrategyType>(
            value: StrategyType.alphaCycleV3,
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.shield_outlined,
                  size: 16,
                  color: selectedStrategy == StrategyType.alphaCycleV3
                      ? Colors.white
                      : context.appTextSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  'Smart',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selectedStrategy == StrategyType.alphaCycleV3
                        ? Colors.white
                        : context.appTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          ButtonSegment<StrategyType>(
            value: StrategyType.infiniteBuy,
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.all_inclusive,
                  size: 16,
                  color: selectedStrategy == StrategyType.infiniteBuy
                      ? Colors.white
                      : context.appTextSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  'Steady',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selectedStrategy == StrategyType.infiniteBuy
                        ? Colors.white
                        : context.appTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          ButtonSegment<StrategyType>(
            value: StrategyType.ladderCycle,
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.stacked_bar_chart,
                  size: 16,
                  color: selectedStrategy == StrategyType.ladderCycle
                      ? Colors.white
                      : context.appTextSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  'Ladder',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selectedStrategy == StrategyType.ladderCycle
                        ? Colors.white
                        : context.appTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
        selected: {selectedStrategy},
        onSelectionChanged: (selected) => onChanged(selected.first),
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return context.appAccent;
            }
            return context.appSurface;
          }),
          side: WidgetStateProperty.all(
            BorderSide(color: context.appBorder, width: 0.5),
          ),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ),
    );
  }
}

/// 전략 설명 카드 (아이콘 + 제목 + 설명 + 도움말 버튼)
class CycleStrategyDescription extends StatelessWidget {
  final StrategyType selectedStrategy;
  final SteadyVersion steadyVersion;

  const CycleStrategyDescription({
    super.key,
    required this.selectedStrategy,
    required this.steadyVersion,
  });

  @override
  Widget build(BuildContext context) {
    final isAlpha = selectedStrategy == StrategyType.alphaCycleV3;
    final isLadder = selectedStrategy == StrategyType.ladderCycle;
    final color = isAlpha
        ? AppColors.blue500
        : isLadder
            ? AppColors.amber500
            : AppColors.green500;

    final (title, desc, icon) = isAlpha
        ? (
            '스마트 방어형',
            '하락장에서도 현금을 보존하며\n가중매수와 승부수로 저점 매수 기회를 포착합니다.\n연속 익절 시 목표가 자동 조절됩니다.',
            Icons.shield_outlined,
          )
        : isLadder
            ? (
                'MDD 기반 가속 분할매수형',
                'ATH 대비 하락률에 따라 단계별로 비중을 높여\n하락할수록 공격적으로 매집합니다.\n고급 설정에서 단계 수, 비율을 커스텀할 수 있습니다.\n\n'
                '추천 조합 (기준 → 1배 → 2배 → 3배):\n'
                '• QQQ → QQQ → QLD → TQQQ (나스닥 100)\n'
                '• SPY → SPY → SSO → UPRO (S&P 500)\n'
                '• IWM → IWM → UWM → TNA (러셀 2000)\n'
                '• DIA → DIA → DDM → UDOW (다우존스)',
                Icons.stacked_bar_chart,
              )
            : (
                steadyVersion == SteadyVersion.v1
                    ? '꾸준한 분할매수형'
                    : steadyVersion == SteadyVersion.v2_2
                        ? '정통 LOC형 (V2.2)'
                        : '공격적 복리형',
                steadyVersion == SteadyVersion.v1
                    ? '40회 분할 매수로\n기계적으로 평균단가를 낮추며\n+10% 익절 시 복리 효과를 극대화합니다.'
                    : steadyVersion == SteadyVersion.v2_2
                        ? 'T값 기반 LOC 주문으로\n매일 매수+매도를 동시에 걸며\n하락장에서 현금을 보존합니다.'
                        : '20분할 공격적 LOC와\n사이클 내 반복리로\n고변동성 종목에서 빠른 사이클 회전.',
                Icons.all_inclusive,
              );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: context.isDarkMode ? 0.10 : 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: context.isDarkMode ? 0.20 : 0.12),
          width: 0.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.appTextSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => showStrategyHelpDialog(context, isAlpha, isLadder: isLadder),
            child: Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Icon(
                Icons.help_outline,
                size: 18,
                color: context.appTextHint,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Steady 버전 선택 (V1 / V2.2 / V3.0)
class SteadyVersionSelector extends StatelessWidget {
  final SteadyVersion steadyVersion;
  final ValueChanged<SteadyVersion> onChanged;

  const SteadyVersionSelector({
    super.key,
    required this.steadyVersion,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '버전 선택',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: context.appTextPrimary,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<SteadyVersion>(
            segments: [
              ButtonSegment<SteadyVersion>(
                value: SteadyVersion.v1,
                label: Text(
                  'V1 Simple',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: steadyVersion == SteadyVersion.v1
                        ? Colors.white
                        : context.appTextSecondary,
                  ),
                ),
              ),
              ButtonSegment<SteadyVersion>(
                value: SteadyVersion.v2_2,
                label: Text(
                  'V2.2 Original',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: steadyVersion == SteadyVersion.v2_2
                        ? Colors.white
                        : context.appTextSecondary,
                  ),
                ),
              ),
              ButtonSegment<SteadyVersion>(
                value: SteadyVersion.v3_0,
                label: Text(
                  'V3.0 Aggr',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: steadyVersion == SteadyVersion.v3_0
                        ? Colors.white
                        : context.appTextSecondary,
                  ),
                ),
              ),
            ],
            selected: {steadyVersion},
            onSelectionChanged: (selected) => onChanged(selected.first),
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return AppColors.green600;
                }
                return context.appSurface;
              }),
              side: WidgetStateProperty.all(
                BorderSide(color: context.appBorder, width: 0.5),
              ),
              shape: WidgetStateProperty.all(
                RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        _SteadyVersionCard(steadyVersion: steadyVersion),
      ],
    );
  }
}

class _SteadyVersionCard extends StatelessWidget {
  final SteadyVersion steadyVersion;

  const _SteadyVersionCard({required this.steadyVersion});

  @override
  Widget build(BuildContext context) {
    final (title, desc, icon) = switch (steadyVersion) {
      SteadyVersion.v1 => (
        'V1 Simple',
        '40분할 · 단순 매수 · 전량 익절\n입문자 추천 · 상승장 최고 효율',
        Icons.sentiment_satisfied_alt,
      ),
      SteadyVersion.v2_2 => (
        'V2.2 Original',
        '40분할 · T값 LOC · 매일 매수+매도\n하락장 방어 우수 (MDD -40%)',
        Icons.shield_outlined,
      ),
      SteadyVersion.v3_0 => (
        'V3.0 Aggressive',
        '20분할 · 공격적 LOC · 사이클 내 복리\n고변동성(SOXL) 시너지',
        Icons.bolt,
      ),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.green500.withValues(
          alpha: context.isDarkMode ? 0.08 : 0.04,
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.green500.withValues(
            alpha: context.isDarkMode ? 0.15 : 0.10,
          ),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.green500),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.green500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: TextStyle(
                    fontSize: 11,
                    color: context.appTextSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 전략 도움말 다이얼로그
void showStrategyHelpDialog(BuildContext context, bool isAlpha, {bool isLadder = false}) {
  final title = isLadder ? 'Ladder Cycle' : isAlpha ? 'Smart Cycle' : 'Steady Cycle';
  final description = isLadder
      ? 'Ladder Cycle — MDD 기반 가속 분할매수\n\n'
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
        '매도 시점은 매도 가이드를 참고하여 직접 판단합니다.'
      : isAlpha
      ? '시장 하락 시 가중매수로 저점을 잡고, 연속 익절하면 목표가를 높이는 적응형 전략입니다.\n\n'
        '— 작동 방식\n\n'
        '1. 시드의 20%로 첫 매수\n'
        '나머지 80%는 현금으로 보존합니다.\n\n'
        '2. 가격이 떨어지면 자동으로 더 매수\n'
        '하락폭이 클수록 매수 금액이 커지는 가중매수 방식입니다.\n'
        '평균 단가 대비 -20% 이하일 때 가중매수가 시작됩니다.\n\n'
        '3. 급락 시 승부수 (패닉바이)\n'
        '평균 단가 대비 -50% 이하의 급락이면\n'
        '잔여 현금의 50%를 과감하게 투입합니다.\n\n'
        '4. 익절 목표 자동 조절\n'
        '첫 익절 목표는 +30%입니다.\n'
        '연속 익절에 성공하면 목표가 5%씩 낮아져\n'
        '최소 +10%까지 내려갑니다.\n'
        '손실 사이클이 발생하면 다시 +30%로 리셋됩니다.\n\n'
        '5. 익절 시 현금 확보\n'
        '수익의 1/3은 현금으로 확보하여\n'
        '다음 하락에 대비합니다.\n\n'
        '— 추천 대상\n'
        '• 하락장에서도 안정적으로 운용하고 싶은 분\n'
        '• 감정적 매매를 줄이고 규칙 기반으로 투자하고 싶은 분\n'
        '• 한 종목에 장기 집중 투자하는 분'
      : '시드를 40회로 나눠 매회 동일 금액을 매수하고, +10% 수익 시 전량 익절하는 기계적 전략입니다.\n\n'
        '— 작동 방식\n\n'
        '1. 시드를 40등분\n'
        '예: 시드 1,000만원 → 1회당 25만원씩 매수합니다.\n\n'
        '2. 매수 타이밍\n'
        '• 현재가 ≤ 평균단가: 1회분 전액 매수 (LOC A+B)\n'
        '• 현재가 > 평균단가: 1회분의 절반만 매수 (LOC B)\n'
        '이미 수익 중이면 절반만 사서 리스크를 줄입니다.\n\n'
        '3. 익절 조건\n'
        '평가 수익률이 +10%에 도달하면\n'
        '보유 주식 전량을 매도합니다.\n\n'
        '4. 사이클 반복\n'
        '익절 후 수익금 포함하여 다시 1회차부터 시작합니다.\n'
        '복리 효과로 시드가 점점 커집니다.\n\n'
        '5. 40회 소진 시\n'
        '40회차를 모두 매수했으면\n'
        '목표 수익률에 도달할 때까지 보유합니다.\n\n'
        '— 추천 대상\n'
        '• 복잡한 판단 없이 기계적으로 투자하고 싶은 분\n'
        '• 변동성이 큰 레버리지 ETF (TQQQ, SOXL 등)에 투자하는 분\n'
        '• 꾸준한 복리 수익을 원하는 분';

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: context.appSurface,
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: context.appTextPrimary,
        ),
      ),
      content: SingleChildScrollView(
        child: Text(
          description,
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
          child: const Text('확인'),
        ),
      ],
    ),
  );
}
