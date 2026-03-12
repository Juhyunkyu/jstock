import 'package:dio/dio.dart';
import 'api_exception.dart';

/// Fear & Greed 지수 구역
enum FearGreedZone {
  extremeFear, // 0-25
  fear, // 25-45
  neutral, // 45-55
  greed, // 55-75
  extremeGreed, // 75-100
}

/// Fear & Greed 지수 데이터 모델
class FearGreedIndex {
  final int value;
  final DateTime timestamp;
  final FearGreedZone zone;

  const FearGreedIndex({
    required this.value,
    required this.timestamp,
    required this.zone,
  });

  /// 값에 따른 구역 계산
  static FearGreedZone calculateZone(int value) {
    if (value < 25) return FearGreedZone.extremeFear;
    if (value < 45) return FearGreedZone.fear;
    if (value < 55) return FearGreedZone.neutral;
    if (value < 75) return FearGreedZone.greed;
    return FearGreedZone.extremeGreed;
  }

  /// 구역의 한글 라벨 반환
  String get zoneLabel => getZoneLabel(zone);

  /// 구역에 대한 한글 라벨 반환
  static String getZoneLabel(FearGreedZone zone) {
    switch (zone) {
      case FearGreedZone.extremeFear:
        return '극도 공포';
      case FearGreedZone.fear:
        return '공포';
      case FearGreedZone.neutral:
        return '중립';
      case FearGreedZone.greed:
        return '탐욕';
      case FearGreedZone.extremeGreed:
        return '극도 탐욕';
    }
  }

  /// 값과 타임스탬프로 FearGreedIndex 생성 (zone 자동 계산)
  factory FearGreedIndex.fromValue({
    required int value,
    required DateTime timestamp,
  }) {
    return FearGreedIndex(
      value: value.clamp(0, 100),
      timestamp: timestamp,
      zone: calculateZone(value),
    );
  }

  @override
  String toString() => 'FearGreedIndex(value: $value, zone: $zoneLabel)';
}

/// CNN Fear & Greed Index API 서비스
///
/// CNN의 Fear & Greed Index를 조회합니다.
/// 지수는 0-100 사이의 값으로, 시장의 공포/탐욕 수준을 나타냅니다.
class FearGreedService {
  final Dio _dio;

  /// CNN 원본 API URL
  static const String _cnnApiUrl =
      'https://production.dataviz.cnn.io/index/fearandgreed/graphdata/';

  /// CORS 프록시 URL (웹 브라우저에서 CNN API 호출을 위함)
  static const String _corsProxyUrl = 'https://corsproxy.io/?';

  FearGreedService()
      : _dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
        ));

  /// 현재 Fear & Greed Index 조회
  Future<FearGreedIndex> getCurrentIndex() async {
    try {
      // CORS 프록시를 통해 CNN API 호출
      final proxyUrl = '$_corsProxyUrl${Uri.encodeComponent(_cnnApiUrl)}';
      final response = await _dio.get(proxyUrl);
      return _parseResponse(response.data);
    } on DioException catch (e) {
      throw NetworkException(
        message: 'Fear & Greed Index 조회 실패: ${e.message}',
        originalError: e,
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ParseException(
        message: 'Fear & Greed Index 파싱 실패',
        originalError: e,
      );
    }
  }

  /// API 응답 파싱
  ///
  /// 응답 형식:
  /// {"fear_and_greed_historical": {"data": [{"x": timestamp_ms, "y": value}, ...]}}
  FearGreedIndex _parseResponse(dynamic data) {
    try {
      final historical = data['fear_and_greed_historical'];
      if (historical == null) {
        throw const ParseException(message: 'fear_and_greed_historical 데이터 없음');
      }

      final dataList = historical['data'] as List<dynamic>?;
      if (dataList == null || dataList.isEmpty) {
        throw const ParseException(message: 'Fear & Greed 데이터 없음');
      }

      // 마지막 항목이 최신 데이터
      final latestData = dataList.last as Map<String, dynamic>;

      final timestampMs = latestData['x'];
      final value = latestData['y'];

      if (timestampMs == null || value == null) {
        throw const ParseException(message: 'Fear & Greed 데이터 형식 오류');
      }

      final timestamp = DateTime.fromMillisecondsSinceEpoch(
        (timestampMs as num).toInt(),
      );
      final indexValue = (value as num).round();

      return FearGreedIndex.fromValue(
        value: indexValue,
        timestamp: timestamp,
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ParseException(
        message: 'Fear & Greed Index 파싱 실패',
        originalError: e,
      );
    }
  }
}
