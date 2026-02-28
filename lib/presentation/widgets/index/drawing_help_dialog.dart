import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// 드로잉 도구 도움말 다이얼로그
void showDrawingHelpDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: context.appSurface,
      title: Text(
        '드로잉 도구 안내',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: context.appTextPrimary,
        ),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildToolSection(
                context,
                icon: Icons.horizontal_rule,
                title: '수평선',
                usage: '차트를 탭하거나 드래그하여 특정 가격에 수평선을 배치합니다.',
                tip: '주요 지지/저항 가격대를 표시하는 데 사용합니다. '
                    '과거 고점/저점, 심리적 가격대(정수), 이전 돌파 레벨 등에 활용하세요.',
              ),
              _buildDivider(context),
              _buildToolSection(
                context,
                icon: Icons.trending_up,
                title: '추세선',
                usage: '시작점과 끝점을 순서대로 탭하여 추세선을 그립니다. '
                    '선택 후 앵커를 드래그하면 기울기를 조정할 수 있습니다.',
                tip: '상승/하락 추세의 방향과 강도를 파악합니다. '
                    '저점을 연결하면 상승 추세선, 고점을 연결하면 하락 추세선입니다. '
                    '추세선 이탈 시 추세 전환 신호로 해석합니다.',
              ),
              _buildDivider(context),
              _buildToolSection(
                context,
                icon: Icons.stacked_line_chart,
                title: '피보나치 되돌림',
                usage: '고점(100%)과 저점(0%)을 순서대로 탭합니다. '
                    '7개 피보나치 레벨(0%, 23.6%, 38.2%, 50%, 61.8%, 78.6%, 100%)이 표시됩니다.',
                tip: '가격 조정 시 되돌림 수준을 예측합니다. '
                    '38.2%와 61.8%가 가장 중요한 되돌림 레벨이며, '
                    '50%는 심리적 중간 지점으로 활용됩니다. '
                    '되돌림 레벨에서의 반등/하락이 진입/청산 타이밍이 될 수 있습니다.',
              ),
              _buildDivider(context),
              _buildToolSection(
                context,
                icon: Icons.view_stream,
                title: '지지/저항 영역',
                usage: '차트를 위아래로 드래그하여 가격 영역을 설정합니다. '
                    '선택 후 상/하변을 개별 드래그하거나 영역 내부를 드래그하여 이동할 수 있습니다.',
                tip: '가격이 반복적으로 반등하거나 저항받는 구간을 영역으로 표시합니다. '
                    '단일 가격선보다 현실적인 지지/저항 분석이 가능합니다. '
                    '거래량이 집중되는 가격대에 설정하면 효과적입니다.',
              ),
              _buildDivider(context),
              _buildToolSection(
                context,
                icon: Icons.straighten,
                title: '측정 도구',
                usage: '차트를 드래그하여 두 지점 간의 가격 변화와 캔들 수를 측정합니다. '
                    '드래그를 놓으면 측정 결과가 사라지며, 바로 재측정할 수 있습니다.',
                tip: '특정 구간의 수익률이나 기간을 빠르게 확인할 때 유용합니다. '
                    '과거 패턴의 크기를 측정하여 현재 움직임과 비교할 수 있습니다.',
              ),
              const SizedBox(height: 12),
              Text(
                '공통 조작',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: context.appTextPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '- 드로잉 선택: 차트의 선/영역을 탭\n'
                '- 이동: 선택 후 드래그\n'
                '- 설정: 선택 후 좌측 톱니바퀴 버튼\n'
                '- 삭제: 선택 후 좌측 휴지통 버튼\n'
                '- 전체 초기화: 메뉴의 초기화 버튼',
                style: TextStyle(
                  fontSize: 12,
                  color: context.appTextSecondary,
                  height: 1.6,
                ),
              ),
            ],
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

Widget _buildToolSection(
  BuildContext context, {
  required IconData icon,
  required String title,
  required String usage,
  required String tip,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Icon(icon, size: 18, color: context.appAccent),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: context.appTextPrimary,
            ),
          ),
        ],
      ),
      const SizedBox(height: 6),
      Text(
        '사용법: $usage',
        style: TextStyle(fontSize: 12, color: context.appTextSecondary, height: 1.5),
      ),
      const SizedBox(height: 4),
      Text(
        '활용팁: $tip',
        style: TextStyle(fontSize: 12, color: context.appTextHint, height: 1.5),
      ),
    ],
  );
}

Widget _buildDivider(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Divider(height: 1, color: context.appDivider),
  );
}
