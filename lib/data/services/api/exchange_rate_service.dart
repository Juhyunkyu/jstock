import 'package:dio/dio.dart';
import 'api_exception.dart';

/// 환율 데이터 모델
class ExchangeRate {
  final String fromCurrency;
  final String toCurrency;
  final double rate;
  final DateTime timestamp;
  final String? source; // 데이터 출처

  const ExchangeRate({
    required this.fromCurrency,
    required this.toCurrency,
    required this.rate,
    required this.timestamp,
    this.source,
  });

  @override
  String toString() => 'ExchangeRate($fromCurrency/$toCurrency: $rate)';
}

/// 환율 API 서비스
///
/// Primary: open.er-api.com (무료, CORS 지원)
/// Fallback: api.frankfurter.app (무료, CORS 지원)
class ExchangeRateService {
  final Dio _dio;

  // Primary: ExchangeRate-API
  static const String _primaryUrl = 'https://open.er-api.com/v6';

  ExchangeRateService()
      : _dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ));

  /// USD/KRW 환율 조회
  Future<ExchangeRate> getUsdKrwRate() async {
    return getRate(from: 'USD', to: 'KRW');
  }

  /// 특정 통화 쌍 환율 조회
  Future<ExchangeRate> getRate({
    required String from,
    required String to,
  }) async {
    try {
      return await _getOpenErApiRate(from: from, to: to);
    } catch (e) {
      return _frankfurterFallback(from: from, to: to);
    }
  }

  /// Primary API (open.er-api.com)
  Future<ExchangeRate> _getOpenErApiRate({
    required String from,
    required String to,
  }) async {
    try {
      final response = await _dio.get(
        '$_primaryUrl/latest/${from.toUpperCase()}',
      );

      return _parseOpenErApiResponse(from, to, response.data);
    } on DioException catch (e) {
      throw NetworkException(
        message: '환율 조회 실패: ${e.message}',
        originalError: e,
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ParseException(
        message: '환율 데이터 파싱 실패',
        originalError: e,
      );
    }
  }

  /// Fallback API (Frankfurter)
  Future<ExchangeRate> _frankfurterFallback({
    required String from,
    required String to,
  }) async {
    try {
      final response = await _dio.get(
        'https://api.frankfurter.app/latest',
        queryParameters: {
          'from': from.toUpperCase(),
          'to': to.toUpperCase(),
        },
      );

      return _parseFrankfurterResponse(from, to, response.data);
    } on DioException catch (e) {
      throw NetworkException(
        message: '환율 조회 실패: ${e.message}',
        originalError: e,
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ParseException(
        message: '환율 데이터 파싱 실패',
        originalError: e,
      );
    }
  }

  /// open.er-api.com 응답 파싱
  ExchangeRate _parseOpenErApiResponse(String from, String to, dynamic data) {
    try {
      if (data['result'] == 'success') {
        final rates = data['rates'] as Map<String, dynamic>?;
        final rate = rates?[to.toUpperCase()];

        if (rate != null) {
          final timeLastUpdate = data['time_last_update_unix'] as int?;
          final timestamp = timeLastUpdate != null
              ? DateTime.fromMillisecondsSinceEpoch(timeLastUpdate * 1000)
              : DateTime.now();

          return ExchangeRate(
            fromCurrency: from.toUpperCase(),
            toCurrency: to.toUpperCase(),
            rate: (rate as num).toDouble(),
            timestamp: timestamp,
            source: 'ExchangeRate-API',
          );
        }
      }

      throw const ParseException(message: '환율 데이터 없음');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ParseException(
        message: '환율 데이터 파싱 실패',
        originalError: e,
      );
    }
  }

  /// Frankfurter 응답 파싱
  ExchangeRate _parseFrankfurterResponse(String from, String to, dynamic data) {
    try {
      final rates = data['rates'] as Map<String, dynamic>?;
      if (rates == null || rates.isEmpty) {
        throw const ParseException(message: '환율 데이터 없음');
      }

      final rate = rates[to.toUpperCase()];
      if (rate == null) {
        throw NotFoundException(message: '환율을 찾을 수 없습니다: $from/$to');
      }

      final dateStr = data['date'] as String?;
      final timestamp = dateStr != null
          ? DateTime.tryParse(dateStr) ?? DateTime.now()
          : DateTime.now();

      return ExchangeRate(
        fromCurrency: from.toUpperCase(),
        toCurrency: to.toUpperCase(),
        rate: (rate as num).toDouble(),
        timestamp: timestamp,
        source: 'Frankfurter (전일 기준)',
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ParseException(
        message: '환율 데이터 파싱 실패',
        originalError: e,
      );
    }
  }

  /// 여러 통화로의 환율 조회
  Future<Map<String, ExchangeRate>> getRates({
    required String from,
    required List<String> to,
  }) async {
    final result = <String, ExchangeRate>{};

    for (final currency in to) {
      try {
        final rate = await getRate(from: from, to: currency);
        result[currency] = rate;
      } catch (_) {
        // 개별 실패는 무시
      }
    }

    return result;
  }
}
