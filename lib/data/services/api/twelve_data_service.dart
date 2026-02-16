import 'package:dio/dio.dart';
import '../../../core/config/app_config.dart';
import '../../models/ohlc_data.dart';
// api_exception.dart available for future error handling enhancements

/// Twelve Data REST API 서비스
///
/// 차트 데이터 전용 API 서비스
/// Rate Limit: 8 calls/min (무료 티어)
class TwelveDataService {
  final Dio _dio;

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
        ));

  /// 차트 데이터 조회 (OHLC 캔들스틱)
  ///
  /// [symbol] 종목 심볼 (예: AAPL, MSFT)
  /// [interval] 데이터 간격 (1min, 5min, 15min, 30min, 1h, 4h, 1day, 1week, 1month)
  /// [outputsize] 반환할 데이터 개수 (기본값: 30, 최대: 5000)
  ///
  /// Returns 빈 리스트 on errors (graceful degradation)
  Future<List<OHLCData>> getChartData(
    String symbol, {
    String interval = '1day',
    int outputsize = 30,
  }) async {
    try {
      final response = await _dio.get('/time_series', queryParameters: {
        'symbol': symbol.toUpperCase(),
        'interval': interval,
        'outputsize': outputsize,
        'apikey': AppConfig.twelveDataApiKey,
      });

      return _parseTimeSeriesResponse(symbol, response.data);
    } on DioException catch (e) {
      // Rate limit 에러 처리 (429)
      if (e.response?.statusCode == 429) {
        // 빈 리스트 반환 (graceful degradation)
        return [];
      }
      // 다른 네트워크 에러도 빈 리스트 반환
      return [];
    } catch (e) {
      // 파싱 에러 등 모든 예외에서 빈 리스트 반환
      return [];
    }
  }

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
