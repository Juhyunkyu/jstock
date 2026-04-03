import 'package:dio/dio.dart';

/// 실시간 지수 데이터 모델
class IndexQuote {
  final String symbol;
  final String name;
  final double price;
  final double changePercent;
  final double changeAbs;

  const IndexQuote({
    required this.symbol,
    required this.name,
    required this.price,
    required this.changePercent,
    required this.changeAbs,
  });

  bool get isPositive => changePercent >= 0;
}

/// TradingView Scanner API 서비스
///
/// 실제 시장 지수(NASDAQ 100, S&P 500) 현재가를 조회한다.
/// API 키 불필요, CORS 지원, 무료.
/// 제한: 스냅샷만 제공 (OHLC 차트 없음), NDX 15분 지연.
class TradingViewService {
  final Dio _dio;

  /// 메모리 캐시 (5분 TTL)
  ({List<IndexQuote> data, DateTime cachedAt})? _cache;
  static const _cacheTTL = Duration(minutes: 5);

  TradingViewService()
      : _dio = Dio(BaseOptions(
          baseUrl: 'https://scanner.tradingview.com',
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ));

  /// NASDAQ 100, S&P 500 실제 지수값 조회
  Future<List<IndexQuote>> fetchIndices() async {
    // 캐시 확인
    if (_cache != null &&
        DateTime.now().difference(_cache!.cachedAt) < _cacheTTL) {
      return _cache!.data;
    }

    try {
      final response = await _dio.post(
        '/america/scan',
        data: {
          'symbols': {
            'tickers': ['NASDAQ:NDX', 'SP:SPX'],
            'query': {'types': []},
          },
          'columns': ['close', 'change', 'change_abs', 'description'],
        },
      );

      final results = <IndexQuote>[];
      final data = response.data['data'] as List?;
      if (data == null) return _cache?.data ?? [];

      for (final item in data) {
        final s = item['s'] as String? ?? '';
        final d = item['d'] as List? ?? [];
        if (d.length < 4) continue;

        results.add(IndexQuote(
          symbol: s.split(':').last,
          name: (d[3] as String?) ?? s,
          price: (d[0] as num?)?.toDouble() ?? 0,
          changePercent: (d[1] as num?)?.toDouble() ?? 0,
          changeAbs: (d[2] as num?)?.toDouble() ?? 0,
        ));
      }

      if (results.isNotEmpty) {
        _cache = (data: results, cachedAt: DateTime.now());
      }
      return results;
    } catch (_) {
      return _cache?.data ?? [];
    }
  }
}
