/// 앱 전역 상수 정의
class AppConstants {
  AppConstants._();

  // 앱 정보
  static const String appName = 'Alpha Cycle';
  static const String appVersion = '1.0.0';

  // 기본 매매 조건
  static const double defaultInitialEntryRatio = 0.20; // 초기 진입 비율 (20%)
  static const double defaultBuyTrigger = -20.0; // 매수 시작점 (-20%)
  static const double defaultSellTrigger = 20.0; // 익절 목표 (+20%)
  static const double defaultPanicTrigger = -50.0; // 승부수 발동점 (-50%)
  static const double defaultPanicBuyRatio = 0.50; // 승부수 비율 (초기진입금의 50%)

  // 가중 매수 공식 상수
  static const double weightedBuyDivisor = 1000.0; // 가중 매수 나눗수

  // 기본 환율
  static const double defaultExchangeRate = 1350.0;

  // 알림 체크 간격 (분)
  static const int defaultCheckIntervalMinutes = 5;

  // 인기 레버리지 ETF 목록 (더 이상 사용하지 않음 - 동적 로드로 전환)
  static const List<Map<String, String>> popularEtfs = [];
}
