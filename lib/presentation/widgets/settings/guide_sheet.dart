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
              '알파 사이클 사용 가이드',
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
              children: const [
                _GuideSection(
                  title: '1. 기본 개념',
                  content:
                      '알파 사이클은 레버리지 ETF의 가중 매수 전략을 돕는 앱입니다.\n\n'
                      '• 손실률 -20% 이하: 가중 매수 시작\n'
                      '• 손실률 -50% 이하: 승부수 발동 (1회)\n'
                      '• 수익률 +20% 이상: 익절 및 사이클 종료',
                ),
                _GuideSection(
                  title: '2. 가중 매수 공식',
                  content: '가중 매수 금액 = 초기진입금 × |손실률| ÷ 1000\n\n'
                      '예시 (시드 1억, 초기진입금 2천만원):\n'
                      '• -20% → 40만원\n'
                      '• -25% → 50만원\n'
                      '• -30% → 60만원\n'
                      '• -50% → 100만원',
                ),
                _GuideSection(
                  title: '3. 승부수',
                  content: '손실률이 -50% 이하일 때 1회만 발동됩니다.\n\n'
                      '승부수 금액 = 초기진입금 × 50%\n\n'
                      '승부수 발동일에는 가중 매수와 함께 실행됩니다.',
                ),
                _GuideSection(
                  title: '4. 손실률 vs 수익률',
                  content: '• 손실률: 초기 진입가 기준 (고정)\n'
                      '  → 매수 조건 판단에 사용\n\n'
                      '• 수익률: 평균 단가 기준 (변동)\n'
                      '  → 익절 조건 판단에 사용',
                ),
                _GuideSection(
                  title: '5. 주의사항',
                  content: '⚠️ 레버리지 ETF는 높은 위험을 수반합니다.\n\n'
                      '• 투자 원금 손실 가능성이 있습니다\n'
                      '• 장기 보유 시 음의 복리 효과 발생\n'
                      '• 투자 결정은 본인의 책임입니다',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

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
