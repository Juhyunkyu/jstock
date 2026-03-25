import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// 보조지표 설명 다이얼로그 표시
void showIndicatorHelpDialog(BuildContext context, String key) {
  String title;
  String description;

  switch (key) {
    case 'VOL':
      title = '거래량 (Volume)';
      description = '거래량은 일정 기간 동안 거래된 주식의 수량입니다.\n\n'
          '• 양봉(상승): 빨간색 바\n'
          '• 음봉(하락): 파란색 바\n'
          '• 거래량 급증: 큰 관심 또는 추세 전환 신호\n'
          '• 상승 + 거래량 증가: 강한 상승 추세\n'
          '• 상승 + 거래량 감소: 상승 피로, 반전 가능';
      break;
    case 'RSI':
      title = 'RSI (14)';
      description = 'RSI(Relative Strength Index)는 주가의 상승/하락 강도를 0~100으로 나타내는 지표입니다.\n\n'
          '• 공식: RSI = 100 - (100 / (1 + RS))\n'
          '  RS = 14일간 평균 상승폭 / 평균 하락폭\n\n'
          '• 70 이상: 과매수 구간 (매도 검토)\n'
          '• 30 이하: 과매도 구간 (매수 검토)\n'
          '• 50 위: 상승 추세, 50 아래: 하락 추세\n\n'
          '다이버전스:\n'
          '• 가격 신고가 + RSI 하락 → 하락 반전 신호\n'
          '• 가격 신저가 + RSI 상승 → 상승 반전 신호\n\n'
          '드로잉 도구:\n'
          '• 추세선 아이콘 탭 → 드로잉 모드 ON\n'
          '• 메인 차트 캔들 길게 누른 후 떼면 RSI에 점 배치\n'
          '• 두 번째 점으로 선 완성, 여러 선 연속 가능\n'
          '• RSI 차트 직접 탭으로도 점 배치 가능';
      break;
    case 'MACD':
      title = 'MACD (12,26,9)';
      description = 'MACD는 두 이동평균선의 차이로 추세와 모멘텀을 분석하는 지표입니다.\n\n'
          '• MACD선 (파랑): 12일 EMA - 26일 EMA\n'
          '• 시그널선 (주황): MACD의 9일 EMA\n'
          '• 히스토그램: MACD선 - 시그널선\n\n'
          '매매 신호:\n'
          '• 골든크로스: MACD선이 시그널선을 상향 돌파 → 매수\n'
          '• 데드크로스: MACD선이 시그널선을 하향 돌파 → 매도\n'
          '• 히스토그램 양전환: 상승 모멘텀 강화\n'
          '• 히스토그램 음전환: 하락 모멘텀 강화';
      break;
    case 'BB':
      title = '볼린저 밴드 (20,2)';
      description = '볼린저 밴드는 이동평균선 위아래로 표준편차 밴드를 그려 변동성을 분석합니다.\n\n'
          '• 상한밴드 (빨강): 20일 SMA + 2σ\n'
          '• 중심밴드 (점선): 20일 SMA\n'
          '• 하한밴드 (파랑): 20일 SMA - 2σ\n\n'
          '매매 신호:\n'
          '• 상한밴드 돌파: 과매수 (매도 검토)\n'
          '• 하한밴드 돌파: 과매도 (매수 검토)\n'
          '• 밴드 수축 (스퀴즈): 변동성 감소 → 큰 움직임 예고\n'
          '• 밴드워크: 밴드를 따라 이동하면 강한 추세';
      break;
    case 'STOCH':
      title = '스토캐스틱 (14,3)';
      description = '스토캐스틱은 현재가가 일정 기간의 고가-저가 범위 중 어디에 위치하는지 보여줍니다.\n\n'
          '• %K (파랑): 현재 위치 (빠른 선)\n'
          '• %D (주황): %K의 3일 이동평균 (느린 선)\n\n'
          '매매 신호:\n'
          '• 80 이상: 과매수 구간 (매도 검토)\n'
          '• 20 이하: 과매도 구간 (매수 검토)\n'
          '• %K가 %D를 상향 돌파 (골든크로스) → 매수\n'
          '• %K가 %D를 하향 돌파 (데드크로스) → 매도\n'
          '• 과매도 구간에서 골든크로스 → 강한 매수 신호';
      break;
    case 'ICH':
      title = '일목균형표';
      description = '일목균형표는 추세, 지지/저항, 모멘텀을 한눈에 보여주는 일본식 기술 지표입니다.\n\n'
          '• 전환선 (빨강): 9일 중간값\n'
          '• 기준선 (파랑): 26일 중간값\n'
          '• 구름 (선행스팬 A+B): 미래 지지/저항 영역\n'
          '• 후행스팬 (초록): 현재가를 26일 전에 표시\n\n'
          '매매 신호:\n'
          '• 가격이 구름 위: 상승 추세\n'
          '• 가격이 구름 아래: 하락 추세\n'
          '• 전환선 > 기준선: 매수 신호\n'
          '• 구름 두께: 지지/저항 강도 표시';
      break;
    case 'OBV':
      title = 'OBV (On-Balance Volume)';
      description = 'OBV는 거래량의 누적 흐름으로 매수/매도 압력을 측정합니다.\n\n'
          '• 계산: 가격 상승일 → OBV + 거래량\n'
          '        가격 하락일 → OBV - 거래량\n\n'
          '매매 신호:\n'
          '• OBV 상승 + 가격 상승: 상승 추세 확인\n'
          '• OBV 하락 + 가격 하락: 하락 추세 확인\n'
          '• OBV 상승 + 가격 하락 (상승 다이버전스): 반등 신호\n'
          '• OBV 하락 + 가격 상승 (하락 다이버전스): 하락 전환 신호';
      break;
    case 'PVT':
      title = 'PVT (Price Volume Trend)';
      description = 'PVT는 OBV의 업그레이드 버전으로, 가격 변동 비율을 거래량에 반영합니다.\n\n'
          '• 공식: PVT = 전일PVT + ((종가-전일종가)/전일종가) × 거래량\n\n'
          'OBV와의 차이:\n'
          '• OBV: 상승일 → 거래량 전체 더함 (과대평가 가능)\n'
          '• PVT: 상승 비율만큼만 반영 (더 정확)\n'
          '• 약한 상승 + 대량 거래 시 OBV는 급등, PVT는 소폭 상승\n\n'
          '매매 신호:\n'
          '• PVT 상승: 세력 매집 (자금 유입)\n'
          '• PVT 하락: 세력 이탈 (자금 유출)\n'
          '• 가격↑ + PVT↓ (하락 다이버전스): 세력 이탈 → 하락 전환\n'
          '• 가격↓ + PVT↑ (상승 다이버전스): 세력 매집 → 반등 신호\n\n'
          '급등락 종목에서 OBV보다 정확도가 높습니다.';
      break;
    case 'MFI':
      title = 'MFI (14)';
      description = 'MFI(Money Flow Index)는 RSI에 거래량을 결합한 지표입니다.\n'
          '가격 변동뿐 아니라 실제 자금 흐름을 반영합니다.\n\n'
          '• 공식: 평균가격 = (고가+저가+종가) ÷ 3\n'
          '  Money Flow = 평균가격 × 거래량\n'
          '  MFI = 100 - (100 / (1 + 긍정MF/부정MF))\n\n'
          '매매 신호:\n'
          '• 80 이상: 과매수 (자금 과열, 매도 검토)\n'
          '• 20 이하: 과매도 (자금 고갈, 매수 검토)\n'
          '• 50 상향돌파: 자금 유입 → 매수 신호\n'
          '• 50 하향돌파: 자금 유출 → 매도 신호\n\n'
          'RSI와의 차이:\n'
          '• RSI: 가격만 반영 ("얼마나 올랐나")\n'
          '• MFI: 가격+거래량 ("돈이 실제로 들어오는가")\n'
          '• 거래량이 실린 상승은 진짜 상승일 가능성 높음\n\n'
          '박스권 장세에서 특히 효과적입니다.';
      break;
    default:
      return;
  }

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: context.appSurface,
      title: Text(
        title,
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: context.appTextPrimary),
      ),
      content: SingleChildScrollView(
        child: Text(
          description,
          style: TextStyle(fontSize: 13, color: context.appTextSecondary, height: 1.6),
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
