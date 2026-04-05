import 'package:dio/dio.dart';
import '../../../core/config/app_config.dart';
import '../../models/financial_data.dart';
import 'proxy_config.dart';

/// 재무제표 API 서비스
///
/// FMP (Financial Modeling Prep) + Finnhub 조합
/// - FMP: 기업 프로필, 손익계산서 (프록시 우선, 직접 호출 폴백)
/// - Finnhub: 재무 비율, EPS 실적 (직접 호출)
/// Rate Limit: FMP 250회/일(무료), Finnhub 60회/분(무료)
/// 캐시: 메모리 30분 → Cloudflare KV 24시간 → API 원본
class FinancialService {
  final Dio _dio;

  /// 메모리 캐시 (30분)
  final Map<String, (dynamic data, DateTime timestamp)> _cache = {};
  static const Duration _cacheTtl = Duration(minutes: 30);

  FinancialService()
      : _dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 20),
        ));

  // ---------------------------------------------------------------------------
  // 캐시 헬퍼
  // ---------------------------------------------------------------------------

  T? _getCache<T>(String key) {
    final entry = _cache[key];
    if (entry == null) return null;
    if (DateTime.now().difference(entry.$2) > _cacheTtl) {
      _cache.remove(key);
      return null;
    }
    return entry.$1 as T;
  }

  void _setCache(String key, dynamic data) {
    _cache[key] = (data, DateTime.now());
  }

  // ---------------------------------------------------------------------------
  // 1. 기업 프로필 (FMP)
  // ---------------------------------------------------------------------------

  /// 기업 프로필 조회
  ///
  /// FMP `/profile/{symbol}` — 시가총액, 섹터, CEO, 로고, 설명 등
  /// 프록시 우선, 직접 호출 폴백
  Future<CompanyProfile?> getProfile(String symbol) async {
    final cacheKey = 'profile_$symbol';
    final cached = _getCache<CompanyProfile>(cacheKey);
    if (cached != null) return cached;

    try {
      final url = ProxyConfig.fmpUrl('profile');
      final queryParams = ProxyConfig.fmpParams({
        'symbol': symbol,
        'apikey': AppConfig.fmpApiKey,
      });

      final response = await _dio.get(url, queryParameters: queryParams);
      final data = response.data;

      // FMP /profile 응답은 배열 [{...}]
      if (data is List && data.isNotEmpty) {
        final profile = CompanyProfile.fromJson(data[0] as Map<String, dynamic>);
        _setCache(cacheKey, profile);
        return profile;
      }

      return null;
    } catch (e) {
      // 프록시 실패 시 직접 호출 폴백
      if (ProxyConfig.useProxy) {
        return _getProfileDirect(symbol);
      }
      return null;
    }
  }

  /// 프록시 실패 시 FMP 직접 호출 폴백
  Future<CompanyProfile?> _getProfileDirect(String symbol) async {
    if (AppConfig.fmpApiKey.isEmpty) return null;

    try {
      final url = '${AppConfig.fmpBaseUrl}/profile';
      final response = await _dio.get(url, queryParameters: {
        'symbol': symbol,
        'apikey': AppConfig.fmpApiKey,
      });

      final data = response.data;
      if (data is List && data.isNotEmpty) {
        final profile = CompanyProfile.fromJson(data[0] as Map<String, dynamic>);
        _setCache('profile_$symbol', profile);
        return profile;
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // 2. 재무 비율 (Finnhub)
  // ---------------------------------------------------------------------------

  /// 핵심 투자 지표 조회
  ///
  /// Finnhub `/stock/metric?metric=all` — PER, PBR, ROE, ROA, 배당률, 부채비율 등
  /// Finnhub은 프록시를 거치지 않음 (기존 패턴)
  Future<FinancialMetrics?> getMetrics(String symbol) async {
    if (!ProxyConfig.useProxy && AppConfig.finnhubApiKey.isEmpty) return null;

    final cacheKey = 'metrics_$symbol';
    final cached = _getCache<FinancialMetrics>(cacheKey);
    if (cached != null) return cached;

    try {
      final response = await _dio.get(
        '${ProxyConfig.finnhubBaseUrl}${ProxyConfig.finnhubPath('/stock/metric')}',
        queryParameters: ProxyConfig.finnhubParams({
          'symbol': symbol.toUpperCase(),
          'metric': 'all',
          'token': AppConfig.finnhubApiKey,
        }),
      );

      final data = response.data;
      if (data == null || data['metric'] == null) return null;

      final metrics = FinancialMetrics.fromFinnhubJson(data as Map<String, dynamic>);
      _setCache(cacheKey, metrics);
      return metrics;
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // 3. 손익계산서 (FMP)
  // ---------------------------------------------------------------------------

  /// 손익계산서 조회
  ///
  /// FMP `/income-statement/{symbol}` — 매출, 영업이익, 순이익
  /// [period]: 'annual' (연간, 기본) 또는 'quarter' (분기)
  /// [limit]: 조회 수 (연간 5, 분기 8)
  /// 프록시 우선, 직접 호출 폴백
  Future<List<IncomeStatement>> getIncomeStatements(
    String symbol, {
    String period = 'annual',
    int limit = 5,
  }) async {
    final cacheKey = 'income_${symbol}_${period}_$limit';
    final cached = _getCache<List<IncomeStatement>>(cacheKey);
    if (cached != null) return cached;

    try {
      final url = ProxyConfig.fmpUrl('income-statement');
      final queryParams = ProxyConfig.fmpParams({
        'symbol': symbol,
        'period': period,
        'limit': limit,
        'apikey': AppConfig.fmpApiKey,
      });

      final response = await _dio.get(url, queryParameters: queryParams);
      final data = response.data;

      if (data is List) {
        final statements = data
            .map((e) => IncomeStatement.fromJson(e as Map<String, dynamic>))
            .toList();
        _setCache(cacheKey, statements);
        return statements;
      }

      return [];
    } catch (e) {
      // 프록시 실패 시 직접 호출 폴백
      if (ProxyConfig.useProxy) {
        return _getIncomeStatementsDirect(symbol, period: period, limit: limit);
      }
      return [];
    }
  }

  /// 프록시 실패 시 FMP 직접 호출 폴백
  Future<List<IncomeStatement>> _getIncomeStatementsDirect(
    String symbol, {
    String period = 'annual',
    int limit = 5,
  }) async {
    if (AppConfig.fmpApiKey.isEmpty) return [];

    try {
      final url = '${AppConfig.fmpBaseUrl}/income-statement';
      final response = await _dio.get(url, queryParameters: {
        'symbol': symbol,
        'period': period,
        'limit': limit,
        'apikey': AppConfig.fmpApiKey,
      });

      final data = response.data;
      if (data is List) {
        final statements = data
            .map((e) => IncomeStatement.fromJson(e as Map<String, dynamic>))
            .toList();
        _setCache('income_${symbol}_${period}_$limit', statements);
        return statements;
      }

      return [];
    } catch (_) {
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // 4. EPS 실적 (Finnhub)
  // ---------------------------------------------------------------------------

  /// EPS 실적 조회
  ///
  /// Finnhub `/stock/earnings` — 실제/예상 EPS, 서프라이즈 %
  /// Finnhub은 프록시를 거치지 않음 (기존 패턴)
  Future<List<EarningsResult>> getEarnings(String symbol, {int limit = 8}) async {
    if (!ProxyConfig.useProxy && AppConfig.finnhubApiKey.isEmpty) return [];

    final cacheKey = 'earnings_${symbol}_$limit';
    final cached = _getCache<List<EarningsResult>>(cacheKey);
    if (cached != null) return cached;

    try {
      final response = await _dio.get(
        '${ProxyConfig.finnhubBaseUrl}${ProxyConfig.finnhubPath('/stock/earnings')}',
        queryParameters: ProxyConfig.finnhubParams({
          'symbol': symbol.toUpperCase(),
          'limit': limit,
          'token': AppConfig.finnhubApiKey,
        }),
      );

      final data = response.data;
      if (data is List) {
        final earnings = data
            .map((e) => EarningsResult.fromJson(e as Map<String, dynamic>))
            .toList();
        _setCache(cacheKey, earnings);
        return earnings;
      }

      return [];
    } catch (_) {
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // 5. 통합 조회 (병렬)
  // ---------------------------------------------------------------------------

  /// 종목의 전체 재무 데이터를 병렬로 조회
  ///
  /// 4개 API를 `Future.wait`으로 동시 호출
  /// 개별 실패 시 null/빈 리스트로 graceful degradation
  /// 연간 + 분기 손익계산서를 모두 가져옴
  Future<FinancialData> getFinancialData(String symbol) async {
    final results = await Future.wait([
      // 0: 기업 프로필
      getProfile(symbol).catchError((_) => null),
      // 1: 재무 비율
      getMetrics(symbol).catchError((_) => null),
      // 2: 손익계산서 (연간 5년)
      getIncomeStatements(symbol, period: 'annual', limit: 5)
          .catchError((_) => <IncomeStatement>[]),
      // 3: 손익계산서 (분기 8개)
      getIncomeStatements(symbol, period: 'quarter', limit: 8)
          .catchError((_) => <IncomeStatement>[]),
      // 4: EPS 실적
      getEarnings(symbol, limit: 8).catchError((_) => <EarningsResult>[]),
    ]);

    return FinancialData(
      profile: results[0] as CompanyProfile?,
      metrics: results[1] as FinancialMetrics?,
      annualStatements: results[2] as List<IncomeStatement>,
      quarterlyStatements: results[3] as List<IncomeStatement>,
      earnings: results[4] as List<EarningsResult>,
    );
  }

  /// 캐시 전체 초기화
  void clearCache() {
    _cache.clear();
  }

  /// 특정 종목 캐시 초기화
  void clearCacheForSymbol(String symbol) {
    _cache.removeWhere((key, _) => key.contains(symbol));
  }
}
