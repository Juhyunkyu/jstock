/// 앱 설정 (API 키 등)
///
/// 프로덕션에서는 --dart-define으로 빌드 시 주입:
/// flutter build web --dart-define=FINNHUB_API_KEY=your_key --dart-define=TWELVE_DATA_API_KEY=your_key
class AppConfig {
  AppConfig._();

  /// Cloudflare Worker 프록시 URL (프로덕션 CORS 우회)
  /// 빌드 시 --dart-define=PROXY_BASE_URL=https://xxx.workers.dev 로 주입
  static const String proxyBaseUrl = String.fromEnvironment(
    'PROXY_BASE_URL',
    defaultValue: '',
  );

  /// 프록시 사용 여부: PROXY_BASE_URL이 설정되어 있으면 프로덕션
  static bool get useProxy => proxyBaseUrl.isNotEmpty;

  /// API 프록시 기본 경로 (로컬: 상대경로, 프로덕션: Worker URL)
  static String get apiProxyBase => useProxy ? proxyBaseUrl : '';

  /// Finnhub API 키 (실시간 시세, WebSocket)
  /// 빌드 시 --dart-define=FINNHUB_API_KEY=xxx 로 주입하거나
  /// 아래 기본값을 수정하세요
  static const String finnhubApiKey = String.fromEnvironment(
    'FINNHUB_API_KEY',
    defaultValue: '',
  );

  /// Finnhub WebSocket URL
  static String get finnhubWebSocketUrl =>
      'wss://ws.finnhub.io?token=$finnhubApiKey';

  /// Finnhub REST API URL
  static const String finnhubBaseUrl = 'https://finnhub.io/api/v1';

  /// Twelve Data API 키 (차트 데이터)
  /// 빌드 시 --dart-define=TWELVE_DATA_API_KEY=xxx 로 주입하거나
  /// 아래 기본값을 수정하세요
  static const String twelveDataApiKey = String.fromEnvironment(
    'TWELVE_DATA_API_KEY',
    defaultValue: '',
  );

  /// Twelve Data REST API URL
  static const String twelveDataBaseUrl = 'https://api.twelvedata.com';

  /// MarketAux API 키 (뉴스)
  static const String marketauxApiKey = String.fromEnvironment(
    'MARKETAUX_API_KEY',
    defaultValue: '',
  );

  /// DeepL API 키 (번역)
  static const String deeplApiKey = String.fromEnvironment(
    'DEEPL_API_KEY',
    defaultValue: '',
  );

  /// DeepL API URL (Free 플랜)
  static const String deeplBaseUrl = 'https://api-free.deepl.com/v2';

  /// FRED API 키 (미국 연준 경제 데이터)
  static const String fredApiKey = String.fromEnvironment(
    'FRED_API_KEY',
    defaultValue: '',
  );

  /// FRED API URL
  static const String fredBaseUrl = 'https://api.stlouisfed.org/fred';
}
