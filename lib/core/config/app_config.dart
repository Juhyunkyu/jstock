/// 앱 설정 (API 키 등)
///
/// 프로덕션에서는 --dart-define으로 빌드 시 주입:
/// flutter build web --dart-define=FINNHUB_API_KEY=your_key --dart-define=TWELVE_DATA_API_KEY=your_key
class AppConfig {
  AppConfig._();

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
}
