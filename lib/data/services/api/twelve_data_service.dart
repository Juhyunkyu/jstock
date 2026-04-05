import 'package:dio/dio.dart';
import '../../../core/config/app_config.dart';
import '../../models/ohlc_data.dart';
import 'proxy_config.dart';
// api_exception.dart available for future error handling enhancements

/// Twelve Data REST API 서비스
///
/// 차트 데이터 전용 API 서비스
/// Rate Limit: 8 calls/min (무료 티어)
class TwelveDataService {
  final Dio _dio;

  /// 프록시용 Dio 인스턴스 (Cloudflare Worker 경유)
  final Dio _proxyDio;

  /// 메모리 캐시: key = "symbol:interval:outputsize", value = (data, timestamp)
  final Map<String, ({List<OHLCData> data, DateTime cachedAt})> _cache = {};

  /// interval별 캐시 유효 시간 (일봉은 자주 안 바뀌므로 길게)
  static Duration _cacheTTLFor(String interval) {
    switch (interval) {
      case '1min':
      case '5min':
      case '15min':
      case '30min':
        return const Duration(minutes: 5);
      case '1h':
      case '4h':
        return const Duration(minutes: 15);
      case '1day':
        return const Duration(minutes: 30);
      case '1week':
        return const Duration(hours: 2);
      case '1month':
        return const Duration(hours: 6);
      default:
        return const Duration(minutes: 5);
    }
  }

  /// Rate limit 추적: 최근 1분 내 호출 시각 리스트
  final List<DateTime> _callTimestamps = [];

  /// 분당 최대 호출 수 (Twelve Data 무료 티어)
  static const _maxCallsPerMinute = 7; // 8이 한도지만 여유분 1 확보

  /// 지원되는 interval 목록
  static const List<String> supportedIntervals = [
    '1min',
    '5min',
    '15min',
    '30min',
    '1h',
    '4h',
    '1day',
    '1week',
    '1month',
  ];

  TwelveDataService()
      : _dio = Dio(BaseOptions(
          baseUrl: AppConfig.twelveDataBaseUrl,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 20),
        )),
        _proxyDio = Dio(BaseOptions(
          baseUrl: AppConfig.useProxy ? AppConfig.proxyBaseUrl : '',
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 20),
        )) {
    ProxyConfig.addAuthInterceptor(_proxyDio);
  }

  /// 차트 데이터 조회 (OHLC 캔들스틱)
  ///
  /// [symbol] 종목 심볼 (예: AAPL, MSFT)
  /// [interval] 데이터 간격 (1min, 5min, 15min, 30min, 1h, 4h, 1day, 1week, 1month)
  /// [outputsize] 반환할 데이터 개수 (기본값: 30, 최대: 5000)
  ///
  /// 캐시(5분 TTL) + Rate limit(7/min) + 자동 재시도(3회) 적용
  /// Returns 빈 리스트 on errors (graceful degradation)
  Future<List<OHLCData>> getChartData(
    String symbol, {
    String interval = '1day',
    int outputsize = 30,
  }) async {
    final cacheKey = '${symbol.toUpperCase()}:$interval:$outputsize';

    // 1. 캐시 확인 (interval별 TTL)
    final cached = _cache[cacheKey];
    final ttl = _cacheTTLFor(interval);
    if (cached != null && DateTime.now().difference(cached.cachedAt) < ttl) {
      return cached.data;
    }

    // 2. Rate limit 체크 (직접 호출 시에만 적용, 프록시 경유 시 서버가 관리)
    if (!AppConfig.useProxy) {
      _cleanOldTimestamps();
      if (_callTimestamps.length >= _maxCallsPerMinute) {
        // Rate limit 근접 — 캐시가 있으면 캐시 반환 (만료여도)
        if (cached != null && cached.data.isNotEmpty) {
          return cached.data;
        }
        // 캐시 없으면 가장 오래된 호출 후 1분까지 대기
        final waitUntil = _callTimestamps.first.add(const Duration(minutes: 1));
        final waitDuration = waitUntil.difference(DateTime.now());
        if (waitDuration.inSeconds > 0 && waitDuration.inSeconds <= 5) {
          await Future.delayed(waitDuration + const Duration(milliseconds: 500));
          _cleanOldTimestamps();
        } else {
          // 5초 이상 대기해야 하면 캐시 반환 또는 빈 리스트
          return cached?.data ?? [];
        }
      }
    }

    // 3. API 호출 (자동 재시도 3회)
    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        _callTimestamps.add(DateTime.now());

        // API 호출 — 프록시 사용 시 Worker 경유, 아니면 직접 호출
        final Response response;
        if (AppConfig.useProxy) {
          // Cloudflare Worker 프록시 경유 (서버 캐시 + API 키 보호)
          response = await _proxyDio.get('/api/twelvedata/chart', queryParameters: {
            'symbol': symbol.toUpperCase(),
            'interval': interval,
            'outputsize': outputsize,
          });
        } else {
          // 직접 호출 (개발 환경)
          response = await _dio.get('/time_series', queryParameters: {
            'symbol': symbol.toUpperCase(),
            'interval': interval,
            'outputsize': outputsize,
            'apikey': AppConfig.twelveDataApiKey,
          });
        }

        final result = _parseTimeSeriesResponse(symbol, response.data);

        // 성공 시 캐시 저장
        if (result.isNotEmpty) {
          _cache[cacheKey] = (data: result, cachedAt: DateTime.now());
        }

        return result;
      } on DioException catch (e) {
        if (e.response?.statusCode == 429) {
          // Rate limit — 캐시 반환 또는 대기 후 재시도
          if (cached != null && cached.data.isNotEmpty) {
            return cached.data;
          }
          if (attempt < 3) {
            await Future.delayed(Duration(seconds: attempt * 3));
            continue;
          }
        }
        // 다른 에러 — 재시도
        if (attempt < 3) {
          await Future.delayed(Duration(seconds: attempt * 2));
          continue;
        }
      } catch (e) {
        if (attempt < 3) {
          await Future.delayed(Duration(seconds: attempt * 2));
          continue;
        }
      }
    }

    // 3번 실패 — 만료 캐시라도 반환
    return cached?.data ?? [];
  }

  /// 1분 이전의 호출 기록 정리
  void _cleanOldTimestamps() {
    final cutoff = DateTime.now().subtract(const Duration(minutes: 1));
    _callTimestamps.removeWhere((t) => t.isBefore(cutoff));
  }

  /// 캐시 초기화 (디버그/설정용)
  void clearCache() => _cache.clear();

  /// Time Series 응답 파싱
  List<OHLCData> _parseTimeSeriesResponse(String symbol, dynamic data) {
    // 에러 응답 체크
    if (data is Map && data.containsKey('code')) {
      // API 에러 응답 (예: {"code": 400, "message": "...", "status": "error"})
      return [];
    }

    final values = data['values'] as List?;
    if (values == null || values.isEmpty) {
      return [];
    }

    final ohlcList = <OHLCData>[];

    for (final item in values) {
      try {
        final datetime = _parseDateTime(item['datetime'] as String?);
        if (datetime == null) continue;

        final open = _parseDouble(item['open']);
        final high = _parseDouble(item['high']);
        final low = _parseDouble(item['low']);
        final close = _parseDouble(item['close']);
        final volume = _parseDouble(item['volume']);

        // 유효한 가격 데이터인지 확인
        if (open == null || close == null) continue;

        ohlcList.add(OHLCData(
          date: datetime,
          open: open,
          high: high ?? open,
          low: low ?? open,
          close: close,
          volume: volume ?? 0,
        ));
      } catch (_) {
        // 개별 항목 파싱 실패 시 건너뜀
        continue;
      }
    }

    // API는 최신 데이터가 먼저 오므로 역순 정렬 (오래된 것부터)
    ohlcList.sort((a, b) => a.date.compareTo(b.date));

    return ohlcList;
  }

  /// datetime 문자열 파싱
  ///
  /// 지원 형식:
  /// - "2024-01-15" (일봉)
  /// - "2024-01-15 09:30:00" (분봉)
  DateTime? _parseDateTime(String? datetime) {
    if (datetime == null || datetime.isEmpty) return null;

    try {
      // "2024-01-15 09:30:00" 형식
      if (datetime.contains(' ')) {
        return DateTime.parse(datetime.replaceFirst(' ', 'T'));
      }
      // "2024-01-15" 형식
      return DateTime.parse(datetime);
    } catch (_) {
      return null;
    }
  }

  /// 문자열 숫자를 double로 파싱
  double? _parseDouble(dynamic value) {
    if (value == null) return null;

    if (value is num) {
      return value.toDouble();
    }

    if (value is String) {
      return double.tryParse(value);
    }

    return null;
  }
}
