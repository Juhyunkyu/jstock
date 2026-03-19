import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// 사용 가이드 시트
class GuideSheet extends StatelessWidget {
  final ScrollController scrollController;

  const GuideSheet({super.key, required this.scrollController});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // 핸들
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: context.appBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // 제목
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Alpha Cycle 투자 가이드',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: context.appTextPrimary,
              ),
            ),
          ),

          // 내용
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.all(16),
              children: [
                // ═══ 앱 소개 ═══
                const _GuideSection(
                  title: '📱 앱 소개',
                  content:
                      'Alpha Cycle은 레버리지 ETF(TQQQ, SOXL 등) 투자를 돕는 매매 가이드 앱입니다.\n\n'
                      '2가지 전략을 지원합니다:\n'
                      '• Smart Cycle — 가중매수 + 승부수 방어형\n'
                      '• Steady Cycle — 라오어 무한매수법 기반 분할매수형\n\n'
                      '앱은 주문 가격/수량을 계산하여 가이드를 제공하고, '
                      '사용자가 실제 증권사에서 주문 후 결과를 기록합니다.',
                ),

                // ═══ Smart Cycle ═══
                _GuideDivider(context: context, label: 'Smart Cycle', color: AppColors.blue500),
                const _GuideSection(
                  title: '🛡️ Smart Cycle이란',
                  content:
                      '하락장에서도 현금을 보존하며 저점 매수 기회를 포착하는 적응형 전략입니다.\n\n'
                      '• 시드의 20%로 첫 매수 (80% 현금 보존)\n'
                      '• -20% 하락 시 가중매수 시작 (하락폭에 비례)\n'
                      '• -50% 급락 시 승부수 1회 (잔여 현금 50%)\n'
                      '• 연속 익절 시 목표가 자동 하향 (+30% → +10%)\n'
                      '• 익절 시 현금 1/3 확보로 다음 하락 대비',
                ),
                const _GuideSection(
                  title: '추천 대상',
                  content:
                      '• 하락장에서도 안정적으로 운용하고 싶은 분\n'
                      '• 감정적 매매를 줄이고 규칙 기반으로 투자하고 싶은 분\n'
                      '• 한 종목에 장기 집중 투자하는 분',
                ),

                // ═══ Steady Cycle ═══
                _GuideDivider(context: context, label: 'Steady Cycle (무한매수법)', color: AppColors.green500),
                const _GuideSection(
                  title: '∞ Steady Cycle이란',
                  content:
                      '라오어의 무한매수법을 기반으로 한 기계적 분할매수 전략입니다.\n\n'
                      '시드를 N등분하여 매일 LOC(종가조건부) 주문을 걸고, '
                      '목표 수익률 도달 시 매도 후 복리로 재투자합니다.\n\n'
                      '3가지 버전을 지원합니다:',
                ),

                // V1
                const _GuideSection(
                  title: 'V1 Simple — 입문자의 친구',
                  content:
                      '40분할 · 단순 매수 · 전량 익절 (+10%)\n\n'
                      '• 평단 이하: 1회분 전액 매수 (A+B)\n'
                      '• 평단 이상: 1회분의 절반만 매수 (B만)\n'
                      '• +10% 도달 시 전량 매도 → 새 사이클\n\n'
                      '가장 단순하고 상승장에서 최고 효율.\n'
                      '⚠️ 40회 소진 후 하락이 계속되면 자금이 묶일 수 있음.',
                ),

                // V2.2
                const _GuideSection(
                  title: 'V2.2 Original — TQQQ의 수호자',
                  content:
                      '40분할 · T값 LOC · 매일 매수+매도 동시\n\n'
                      '• T값에 따라 LOC 가격이 변동 (오프셋 = 10 - T/2)\n'
                      '• 매일 매수 LOC와 매도 LOC+지정가를 동시에 설정\n'
                      '• 매도 LOC: 보유의 1/4, 지정가: 보유의 3/4 (+10%)\n'
                      '• 하락장에서 LOC 미체결 → 현금 자동 보존\n\n'
                      '🛡️ 핵심 강점: MDD -40% (V1의 -74% 대비 절반)\n'
                      'TQQQ 하락→회복에서 유일하게 플러스 수익 (+13%)',
                ),

                // V3.0
                const _GuideSection(
                  title: 'V3.0 Aggressive — SOXL의 무기',
                  content:
                      '20분할 · 공격적 LOC · 반복리\n\n'
                      '• TQQQ: 오프셋 15-1.5T, 익절 +15%\n'
                      '• SOXL: 오프셋 20-2T, 익절 +20%\n'
                      '• 반복리: 매도 수익의 1/40을 매수금에 추가\n'
                      '• 손해 시 매수금 유지 (줄이지 않음)\n\n'
                      '⚡ 핵심 강점: SOXL 하락장 -24% (V1은 -79%)\n'
                      'SOXL 하락→회복에서 +32% 경이적 수익',
                ),

                // ═══ 버전 선택 가이드 ═══
                _GuideDivider(context: context, label: '버전 선택 가이드', color: context.appAccent),
                _GuideTable(context: context),

                // 전환 타이밍
                const _GuideSection(
                  title: '🔄 버전 전환 타이밍',
                  content:
                      '지금 V1인데 40회 소진, 익절 실패했다면:\n'
                      '→ TQQQ: V2.2로 전환 (현금 보존 모드)\n'
                      '→ SOXL: V3.0으로 전환 (빠른 회전 모드)\n\n'
                      '지금 V2.2인데 미체결이 계속된다면:\n'
                      '→ 정상입니다! 현금 보존 중.\n'
                      '→ 3사이클 연속 완료 시 V1 복귀 고려\n\n'
                      '지금 V3.0인데 반복리가 잘 쌓인다면:\n'
                      '→ V3.0이 잘 맞는 상황, 유지!',
                ),

                // ═══ 공통 주의사항 ═══
                _GuideDivider(context: context, label: '주의사항', color: AppColors.red500),
                const _GuideSection(
                  title: '⚠️ 투자 주의사항',
                  content:
                      '• 레버리지 ETF는 높은 위험을 수반합니다\n'
                      '• 투자 원금 손실 가능성이 있습니다\n'
                      '• 장기 보유 시 음의 복리 효과가 발생할 수 있습니다\n'
                      '• 이 앱은 매매 가이드일 뿐, 투자 결정은 본인의 책임입니다\n'
                      '• 백테스트 결과가 미래 수익을 보장하지 않습니다',
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// 가이드 섹션
// ═══════════════════════════════════════════════════════════════

class _GuideSection extends StatelessWidget {
  final String title;
  final String content;

  const _GuideSection({
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: context.appTextPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              fontSize: 14,
              color: context.appTextSecondary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// 구분선
// ═══════════════════════════════════════════════════════════════

class _GuideDivider extends StatelessWidget {
  final BuildContext context;
  final String label;
  final Color color;

  const _GuideDivider({
    required this.context,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext outerContext) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Divider(color: context.appDivider, height: 1),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// 종목별 추천 테이블
// ═══════════════════════════════════════════════════════════════

class _GuideTable extends StatelessWidget {
  final BuildContext context;

  const _GuideTable({required this.context});

  @override
  Widget build(BuildContext outerContext) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '📊 종목별 추천',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: context.appTextPrimary,
            ),
          ),
          const SizedBox(height: 12),
          _tableRow(context, '', '상승장', '하락/불확실', isHeader: true),
          _tableRow(context, 'TQQQ', 'V1', 'V2.2'),
          _tableRow(context, 'SOXL', 'V1', 'V3.0'),
          _tableRow(context, '기타 중변동성', 'V1', 'V2.2'),
          _tableRow(context, '기타 고변동성', 'V1', 'V3.0'),
          const SizedBox(height: 16),
          Text(
            '💡 모르겠으면?\n'
            '→ 입문자: V1 Simple로 시작\n'
            '→ TQQQ 장기: V2.2 (안정적)\n'
            '→ SOXL 공격: V3.0 (높은 수익 잠재력)',
            style: TextStyle(
              fontSize: 13,
              color: context.appTextSecondary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tableRow(BuildContext ctx, String col1, String col2, String col3,
      {bool isHeader = false}) {
    final style = TextStyle(
      fontSize: 12,
      fontWeight: isHeader ? FontWeight.bold : FontWeight.w500,
      color: isHeader ? ctx.appTextSecondary : ctx.appTextPrimary,
    );

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        color: isHeader
            ? ctx.appBackground
            : Colors.transparent,
        border: Border(
          bottom: BorderSide(color: ctx.appDivider, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text(col1, style: style)),
          Expanded(
            flex: 2,
            child: Text(
              col2,
              style: style.copyWith(
                color: !isHeader ? AppColors.green600 : null,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              col3,
              style: style.copyWith(
                color: !isHeader ? AppColors.blue500 : null,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
