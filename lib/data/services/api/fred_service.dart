import 'package:dio/dio.dart';
import '../../../core/config/app_config.dart';

/// FRED (Federal Reserve Economic Data) API 서비스
///
/// 미국 연준 경제 데이터 조회
/// - WTI 원유 선물 가격 (DCOILWTICO)
/// - 미국 10년 국채 수익률 (DGS10)
/// Rate Limit: 120 calls/min (무료)
/// 웹: CORS 우회를 위해 /api/fred 프록시 사용
class FredService {
  final Dio _dio;

  FredService()
      : _dio = Dio(BaseOptions(
          baseUrl: '${AppConfig.apiProxyBase}/api/fred',
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 20),
        ));

  /// FRED 시계열 최신 값 조회
  ///
  /// [seriesId] FRED 시계열 ID (예: DCOILWTICO, DGS10)
  /// Returns (최신값, 전일값) 또는 null
  Future<FredObservation?> getLatestObservation(String seriesId) async {
    if (AppConfig.fredApiKey.isEmpty) return null;

    try {
      final response = await _dio.get(
        '/series/observations',
        queryParameters: {
          'series_id': seriesId,
          'api_key': AppConfig.fredApiKey,
          'file_type': 'json',
          'sort_order': 'desc',
          'limit': 5, // 최근 5개 (주말/공휴일 대비)
        },
      );

      final observations = response.data['observations'] as List?;
      if (observations == null || observations.isEmpty) return null;

      // "." (데이터 없음) 필터링 후 최신 2개 추출
      final validObs = observations
          .where((o) => o['value'] != '.' && o['value'] != null)
          .toList();

      if (validObs.isEmpty) return null;

      final latestValue = double.tryParse(validObs[0]['value'] as String);
      if (latestValue == null) return null;

      double? previousValue;
      if (validObs.length >= 2) {
        previousValue = double.tryParse(validObs[1]['value'] as String);
      }

      return FredObservation(
        seriesId: seriesId,
        value: latestValue,
        previousValue: previousValue,
        date: validObs[0]['date'] as String?,
      );
    } catch (_) {
      return null;
    }
  }
}

/// FRED 관측값 모델
class FredObservation {
  final String seriesId;
  final double value;
  final double? previousValue;
  final String? date;

  const FredObservation({
    required this.seriesId,
    required this.value,
    this.previousValue,
    this.date,
  });

  /// 전일 대비 변동률 (%)
  double get changePercent {
    if (previousValue == null || previousValue == 0) return 0;
    return ((value - previousValue!) / previousValue!) * 100;
  }

  /// 전일 대비 변동폭 (금리용)
  double get changeAbsolute {
    if (previousValue == null) return 0;
    return value - previousValue!;
  }
}
