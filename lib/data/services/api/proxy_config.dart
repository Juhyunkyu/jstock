import 'package:dio/dio.dart';
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

  /// Finnhub 쿼리 파라미터 정리: 프록시 시 token 제거
  /// Worker가 /metric 엔드포인트에 metric=all을 서버사이드 주입하므로 제거
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

  // ---------------------------------------------------------------------------
  // MarketAux
  // ---------------------------------------------------------------------------

  /// Worker MarketAux 엔드포인트 (프록시 미사용 시 null → 직접 호출 폴백)
  static String? get marketAuxUrl =>
      useProxy ? '$proxyBase/api/marketaux/news' : null;

  // ---------------------------------------------------------------------------
  // Shared Auth Interceptor
  // ---------------------------------------------------------------------------

  /// Worker 프록시 호출 시 X-App-Token 헤더를 자동 주입하는 인터셉터.
  /// 각 서비스의 Dio 인스턴스에 추가하면 Worker 요청에만 토큰이 붙음.
  static void addAuthInterceptor(Dio dio) {
    if (!useProxy || AppConfig.appToken.isEmpty) return;
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        final uri = options.uri.toString();
        if (uri.startsWith(proxyBase)) {
          options.headers['X-App-Token'] = AppConfig.appToken;
        }
        handler.next(options);
      },
    ));
  }
}
