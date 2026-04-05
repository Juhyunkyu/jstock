import '../../../core/config/app_config.dart';

/// 프록시 URL 라우팅 설정
///
/// Cloudflare Worker 프록시 사용 시 API URL과 파라미터를 자동 변환.
/// [AppConfig.useProxy]가 false이면 모든 메서드가 원본(직접 호출) 값을 반환.
class ProxyConfig {
  ProxyConfig._();

  static bool get useProxy => AppConfig.useProxy;
  static String get proxyBase => AppConfig.proxyBaseUrl;

  // ---------------------------------------------------------------------------
  // Finnhub
  // ---------------------------------------------------------------------------

  /// Finnhub REST base URL (프록시 시 Worker 경유)
  static String get finnhubBaseUrl =>
      useProxy ? '$proxyBase/api/finnhub' : AppConfig.finnhubBaseUrl;

  /// Finnhub 경로 변환: /stock/profile2 → /profile2, /stock/metric → /metric 등
  static String finnhubPath(String directPath) {
    if (!useProxy) return directPath;
    return directPath.replaceFirst('/stock/', '/');
  }

  /// Finnhub 쿼리 파라미터 정리: 프록시 시 token·metric 제거
  static Map<String, dynamic> finnhubParams(Map<String, dynamic> params) {
    if (!useProxy) return params;
    final filtered = Map<String, dynamic>.from(params);
    filtered.remove('token');
    filtered.remove('metric');
    return filtered;
  }

  // ---------------------------------------------------------------------------
  // FMP (Financial Modeling Prep)
  // ---------------------------------------------------------------------------

  /// FMP 엔드포인트 URL (프록시 시 Worker 경유)
  static String fmpUrl(String endpoint) =>
      useProxy ? '$proxyBase/api/fmp/$endpoint' : '${AppConfig.fmpBaseUrl}/$endpoint';

  /// FMP 쿼리 파라미터 정리: 프록시 시 apikey 제거
  static Map<String, dynamic> fmpParams(Map<String, dynamic> params) {
    if (!useProxy) return params;
    final filtered = Map<String, dynamic>.from(params);
    filtered.remove('apikey');
    return filtered;
  }

  // ---------------------------------------------------------------------------
  // Exchange Rate
  // ---------------------------------------------------------------------------

  /// Worker 환율 엔드포인트 (프록시 미사용 시 null)
  static String? get exchangeRateUrl =>
      useProxy ? '$proxyBase/api/exchange-rate' : null;
}
