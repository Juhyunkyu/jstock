import 'package:dio/dio.dart';
import '../../models/economic_event.dart';
import 'proxy_config.dart';

/// 경제 캘린더 API 서비스
///
/// Worker `/api/calendar/*` 엔드포인트 호출
/// - economic: FRED + TradingView 병합 경제 이벤트
/// - earnings: Finnhub 실적 일정
/// 메모리 캐시: 30분 TTL
class CalendarService {
  final Dio _dio;

  /// 메모리 캐시 (30분)
  final Map<String, (List<EconomicEvent> data, DateTime timestamp)> _cache = {};
  static const Duration _cacheTtl = Duration(minutes: 30);

  CalendarService()
      : _dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 20),
        )) {
    ProxyConfig.addAuthInterceptor(_dio);
  }

  // ---------------------------------------------------------------------------
  // 캐시 헬퍼
  // ---------------------------------------------------------------------------

  List<EconomicEvent>? _getCache(String key) {
    final entry = _cache[key];
    if (entry == null) return null;
    if (DateTime.now().difference(entry.$2) > _cacheTtl) {
      _cache.remove(key);
      return null;
    }
    return entry.$1;
  }

  void _setCache(String key, List<EconomicEvent> data) {
    _cache[key] = (data, DateTime.now());
  }

  // ---------------------------------------------------------------------------
  // Base URL
  // ---------------------------------------------------------------------------

  String get _baseUrl {
    if (!ProxyConfig.useProxy) {
      throw UnsupportedError('Calendar requires proxy');
    }
    return '${ProxyConfig.proxyBase}/api/calendar';
  }

  // ---------------------------------------------------------------------------
  // 경제 이벤트 조회
  // ---------------------------------------------------------------------------

  /// 경제 이벤트 조회
  ///
  /// Worker `/api/calendar/economic?from=X&to=Y` 호출
  /// FRED release dates + TradingView forecast 병합 데이터 반환
  Future<List<EconomicEvent>> getEconomicEvents({
    required String from,
    required String to,
  }) async {
    final cacheKey = 'economic_${from}_$to';
    final cached = _getCache(cacheKey);
    if (cached != null) return cached;

    try {
      final response = await _dio.get(
        '$_baseUrl/economic',
        queryParameters: {'from': from, 'to': to},
      );

      final data = response.data;
      final List<dynamic> events = data is Map
          ? (data['events'] as List<dynamic>? ?? [])
          : (data is List ? data : []);

      final result =
          events.map((e) => EconomicEvent.fromJson(e as Map<String, dynamic>)).toList();
      _setCache(cacheKey, result);
      return result;
    } catch (e) {
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // 실적 이벤트 조회
  // ---------------------------------------------------------------------------

  /// 실적 이벤트 조회
  ///
  /// Worker `/api/calendar/earnings?from=X&to=Y` 호출
  /// Finnhub earnings calendar 데이터를 EconomicEvent로 변환
  Future<List<EconomicEvent>> getEarningsEvents({
    required String from,
    required String to,
    List<String>? symbols,
  }) async {
    final cacheKey = 'earnings_${from}_${to}_${symbols?.join(',') ?? 'all'}';
    final cached = _getCache(cacheKey);
    if (cached != null) return cached;

    try {
      final queryParams = <String, dynamic>{'from': from, 'to': to};
      if (symbols != null && symbols.isNotEmpty) {
        queryParams['symbols'] = symbols.join(',');
      }

      final response = await _dio.get(
        '$_baseUrl/earnings',
        queryParameters: queryParams,
      );

      final data = response.data;
      final List<dynamic> earnings = data is Map
          ? (data['earningsCalendar'] as List<dynamic>? ?? [])
          : (data is List ? data : []);

      final result = earnings
          .map((e) => _parseEarnings(e as Map<String, dynamic>))
          .toList();
      _setCache(cacheKey, result);
      return result;
    } catch (e) {
      return [];
    }
  }

  /// Finnhub earnings 응답 → EconomicEvent 변환
  EconomicEvent _parseEarnings(Map<String, dynamic> json) {
    return EconomicEvent(
      id: 'earnings-${json['symbol']}-${json['date']}',
      title: '${json['symbol']} 실적발표',
      titleEn: '${json['symbol']} Earnings',
      date: DateTime.parse(json['date'] as String),
      category: EventCategory.earnings,
      forecast: (json['epsEstimate'] as num?)?.toDouble(),
      actual: (json['epsActual'] as num?)?.toDouble(),
      unit: '\$',
      importance: 2,
      ticker: json['symbol'] as String?,
      hour: json['hour'] as String?,
      revenueEstimate: (json['revenueEstimate'] as num?)?.toDouble(),
    );
  }

  // ---------------------------------------------------------------------------
  // 캐시 관리
  // ---------------------------------------------------------------------------

  /// 캐시 전체 초기화
  void clearCache() {
    _cache.clear();
  }
}
