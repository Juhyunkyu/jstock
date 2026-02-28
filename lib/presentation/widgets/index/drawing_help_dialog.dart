import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// 개별 드로잉 도구 도움말 다이얼로그 (보조지표 ? 패턴)
void showDrawingToolHelp(BuildContext context, String toolKey) {
  String title;
  String description;

  switch (toolKey) {
    case 'horizontalLine':
      title = '수평선';
      description = '특정 가격 수준에 수평선을 그려 주요 지지/저항 가격대를 표시합니다.\n\n'
          '사용법:\n'
          '• 차트를 탭하거나 드래그하여 수평선을 배치합니다\n'
          '• 선을 탭하여 선택 → 드래그로 위치를 조정합니다\n'
          '• 선택 후 ⚙ 버튼으로 색상/굵기/잠금을 설정합니다\n\n'
          '활용법:\n'
          '• 과거 고점/저점에 배치하여 지지/저항 레벨 확인\n'
          '• 심리적 가격대(정수, 예: 600, 620)에 표시\n'
          '• 이전 돌파 후 지지로 전환된 레벨 추적\n'
          '• 여러 수평선으로 주요 가격 구간을 한눈에 파악';
      break;
    case 'trendLine':
      title = '추세선';
      description = '두 점을 연결하여 가격의 추세 방향과 강도를 시각화합니다.\n\n'
          '사용법:\n'
          '• 시작점과 끝점을 순서대로 탭하여 추세선을 그립니다\n'
          '• 선택 후 앵커(●)를 드래그하면 기울기를 조정합니다\n'
          '• 선 자체를 드래그하면 평행 이동합니다\n\n'
          '활용법:\n'
          '• 상승 추세: 연속된 저점(바닥)을 연결\n'
          '• 하락 추세: 연속된 고점(꼭대기)을 연결\n'
          '• 추세선 이탈(브레이크아웃)은 추세 전환 신호\n'
          '• 추세선에 닿을 때의 반등 → 매수/매도 타이밍';
      break;
    case 'fibonacci':
      title = '피보나치 되돌림';
      description = '가격 조정 시 되돌림 수준을 예측하는 7개 피보나치 레벨을 표시합니다.\n\n'
          '사용법:\n'
          '• 고점(100%)을 먼저 탭 → 저점(0%)을 탭합니다\n'
          '• 0%, 23.6%, 38.2%, 50%, 61.8%, 78.6%, 100% 레벨이 표시됩니다\n'
          '• 앵커(●)를 드래그하여 범위를 조정합니다\n\n'
          '활용법:\n'
          '• 38.2%와 61.8%가 가장 중요한 되돌림 레벨\n'
          '• 50%는 심리적 중간 지점으로 빈번하게 반응\n'
          '• 상승 후 조정 시: 되돌림 레벨에서의 반등 → 매수 기회\n'
          '• 하락 후 반등 시: 되돌림 레벨에서의 저항 → 매도 기회\n'
          '• 여러 피보나치 레벨이 겹치는 구간은 강한 지지/저항';
      break;
    case 'supportResistanceZone':
      title = '지지/저항 영역';
      description = '가격이 반복적으로 반등하거나 저항받는 구간을 영역으로 표시합니다.\n\n'
          '사용법:\n'
          '• 차트를 위아래로 드래그하여 가격 영역을 설정합니다\n'
          '• 선택 후 상/하 경계선을 개별 드래그하여 범위를 조정합니다\n'
          '• 영역 내부를 드래그하면 전체가 평행 이동합니다\n\n'
          '활용법:\n'
          '• 단일 수평선보다 현실적인 지지/저항 분석 가능\n'
          '• 거래량이 집중된 가격대에 설정하면 효과적\n'
          '• 과거에 여러 번 반등/저항이 일어난 구간을 커버\n'
          '• 영역 돌파 시 강한 추세 전환 신호로 해석';
      break;
    case 'measure':
      title = '측정 도구';
      description = '두 지점 간의 가격 변화, 변동률, 캔들 수를 실시간으로 측정합니다.\n\n'
          '사용법:\n'
          '• 차트를 드래그하여 시작점→끝점을 지정합니다\n'
          '• 드래그 중 가격 차이, 변동률(%), 캔들 수가 표시됩니다\n'
          '• 드래그를 놓으면 측정이 사라지고 바로 재측정 가능합니다\n\n'
          '활용법:\n'
          '• 특정 구간의 수익률이나 기간을 빠르게 확인\n'
          '• 과거 상승/하락 패턴의 크기(폭, 기간)를 측정\n'
          '• 현재 움직임과 과거 패턴을 비교하여 목표가 산정\n'
          '• 캔들 수로 시간 경과를 직관적으로 파악';
      break;
    default:
      title = '드로잉 도구';
      description = '차트 위에 다양한 분석 도구를 그릴 수 있습니다.';
  }

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: context.appSurface,
      title: Row(
        children: [
          Icon(_getToolIcon(toolKey), size: 20, color: context.appAccent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: context.appTextPrimary,
              ),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Text(
            description,
            style: TextStyle(
              fontSize: 13,
              color: context.appTextSecondary,
              height: 1.6,
            ),
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

IconData _getToolIcon(String key) {
  switch (key) {
    case 'horizontalLine':
      return Icons.horizontal_rule;
    case 'trendLine':
      return Icons.trending_up;
    case 'fibonacci':
      return Icons.stacked_line_chart;
    case 'supportResistanceZone':
      return Icons.view_stream;
    case 'measure':
      return Icons.straighten;
    default:
      return Icons.edit;
  }
}
