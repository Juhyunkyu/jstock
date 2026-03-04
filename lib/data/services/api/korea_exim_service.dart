import 'package:dio/dio.dart';
import '../../../core/config/app_config.dart';
import 'api_exception.dart';

/// 한국수출입은행 매매기준율 모델
class KoreaEximRate {
  final double dealBaseRate; // 매매기준율
  final double ttsBuyRate; // 전신환(송금) 보내실때 (살때)
  final double ttbSellRate; // 전신환(송금) 받으실때 (팔때)
  final String currencyCode; // 통화코드 (USD)
  final String currencyName; // 통화명 (미국 달러)
  final String date; // 기준일 (YYYYMMDD)

  const KoreaEximRate({
    required this.dealBaseRate,
    required this.ttsBuyRate,
    required this.ttbSellRate,
    required this.currencyCode,
    required this.currencyName,
    required this.date,
  });

  /// 기준일 포맷 (MM/DD)
  String get formattedDate {
    if (date.length == 8) {
      return '${date.substring(4, 6)}/${date.substring(6, 8)}';
    }
    return date;
  }
}

/// 한국수출입은행 환율 서비스
///
/// 엔드포인트: oapi.koreaexim.go.kr/site/program/financial/exchangeJSON
/// CORS 미지원 → corsproxy.io 프록시 경유
/// 공휴일/주말: 빈 배열 반환 → ParseException → provider에서 graceful 처리
class KoreaEximService {
  final Dio _dio;

  static const String _originUrl =
      'https://oapi.koreaexim.go.kr/site/program/financial/exchangeJSON';

  /// CORS 프록시 (Flutter Web에서 직접 호출 불가)
  static const String _corsProxy = 'https://corsproxy.io/?';

  KoreaEximService()
      : _dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
        ));

  /// USD/KRW 매매기준율 조회
  Future<KoreaEximRate> getUsdKrwRate() async {
    return getRate('USD');
  }

  /// 특정 통화 매매기준율 조회
  Future<KoreaEximRate> getRate(String currencyCode) async {
    final today = DateTime.now();
    final searchDate = _formatDate(today);

    try {
      final rate = await _fetchRate(currencyCode, searchDate);
      return rate;
    } catch (e) {
      // 공휴일/주말 → 직전 영업일 재조회 (최대 5일 전까지)
      for (int i = 1; i <= 5; i++) {
        final prevDate = today.subtract(Duration(days: i));
        final prevDateStr = _formatDate(prevDate);
        try {
          return await _fetchRate(currencyCode, prevDateStr);
        } catch (_) {
          continue;
        }
      }
      rethrow;
    }
  }

  Future<KoreaEximRate> _fetchRate(
      String currencyCode, String searchDate) async {
    try {
      // CORS 프록시를 통해 호출 (corsproxy.io는 raw URL 기대)
      final targetUrl =
          '$_originUrl?authkey=${AppConfig.koreaEximApiKey}&searchdate=$searchDate&data=AP01';
      final response = await _dio.get('$_corsProxy$targetUrl');

      final data = response.data;

      // 응답이 리스트가 아니거나 빈 배열이면 해당 날짜에 데이터 없음
      if (data is! List || data.isEmpty) {
        throw ParseException(
          message: '환율 데이터 없음 ($searchDate)',
        );
      }

      // 결과 코드 확인 (result 필드가 있을 경우)
      if (data.first is Map && data.first['result'] == 2) {
        throw const ParseException(message: 'API 키 오류');
      }

      // 원하는 통화 찾기
      for (final item in data) {
        if (item is Map<String, dynamic>) {
          final curUnit = (item['cur_unit'] as String?)?.trim();
          if (curUnit == currencyCode.toUpperCase()) {
            return KoreaEximRate(
              dealBaseRate: _parseCommaNumber(item['deal_bas_r']),
              ttsBuyRate: _parseCommaNumber(item['tts']),
              ttbSellRate: _parseCommaNumber(item['ttb']),
              currencyCode: curUnit ?? currencyCode,
              currencyName: (item['cur_nm'] as String?) ?? '',
              date: searchDate,
            );
          }
        }
      }

      throw NotFoundException(
          message: '통화를 찾을 수 없습니다: $currencyCode');
    } on DioException catch (e) {
      throw NetworkException(
        message: '한국수출입은행 API 호출 실패: ${e.message}',
        originalError: e,
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ParseException(
        message: '한국수출입은행 응답 파싱 실패',
        originalError: e,
      );
    }
  }

  /// 콤마가 포함된 숫자 문자열 파싱 ("1,474.50" → 1474.50)
  double _parseCommaNumber(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    final str = value.toString().replaceAll(',', '').trim();
    return double.tryParse(str) ?? 0.0;
  }

  /// DateTime → YYYYMMDD 포맷
  String _formatDate(DateTime date) {
    final y = date.year.toString();
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y$m$d';
  }
}
