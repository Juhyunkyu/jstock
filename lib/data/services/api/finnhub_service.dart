import 'package:dio/dio.dart';
import '../../../core/config/app_config.dart';
import 'api_exception.dart';

/// 검색 결과 모델
class SearchResult {
  final String symbol;
  final String name;
  final String exchange;
  final String type;

  const SearchResult({
    required this.symbol,
    required this.name,
    required this.exchange,
    required this.type,
  });

  bool get isEquity => type == 'Common Stock';
  bool get isETF => type == 'ETF';
}

/// 뉴스 아이템 모델
class NewsItem {
  final String title;
  final String? translatedTitle;
  final String publisher;
  final String link;
  final DateTime publishedAt;
  final String? thumbnail;

  const NewsItem({
    required this.title,
    this.translatedTitle,
    required this.publisher,
    required this.link,
    required this.publishedAt,
    this.thumbnail,
  });

  /// 표시용 제목 (번역된 제목 우선)
  String get displayTitle => translatedTitle ?? title;

  NewsItem copyWith({String? translatedTitle}) {
    return NewsItem(
      title: title,
      translatedTitle: translatedTitle ?? this.translatedTitle,
      publisher: publisher,
      link: link,
      publishedAt: publishedAt,
      thumbnail: thumbnail,
    );
  }
}

/// 주가 데이터 모델
class StockQuote {
  final String symbol;
  final double currentPrice;
  final double previousClose;
  final double changePercent;
  final double dayHigh;
  final double dayLow;
  final double volume;
  final DateTime timestamp;
  final String marketState;
  final double? preMarketPrice;
  final double? preMarketChange;
  final double? postMarketPrice;
  final double? postMarketChange;

  const StockQuote({
    required this.symbol,
    required this.currentPrice,
    required this.previousClose,
    required this.changePercent,
    required this.dayHigh,
    required this.dayLow,
    required this.volume,
    required this.timestamp,
    this.marketState = 'CLOSED',
    this.preMarketPrice,
    this.preMarketChange,
    this.postMarketPrice,
    this.postMarketChange,
  });

  bool get isPositive => changePercent >= 0;
  bool get isMarketOpen => marketState == 'REGULAR';
  bool get hasPreMarketData => preMarketPrice != null && preMarketPrice! > 0;
  bool get hasPostMarketData => postMarketPrice != null && postMarketPrice! > 0;

  double get relevantPrice {
    switch (marketState) {
      case 'PRE':
      case 'PREPRE':
        return preMarketPrice ?? currentPrice;
      case 'POST':
      case 'POSTPOST':
        return postMarketPrice ?? currentPrice;
      default:
        return currentPrice;
    }
  }

  String get marketStateKorean {
    switch (marketState) {
      case 'REGULAR':
        return '개장중';
      case 'PRE':
      case 'PREPRE':
        return '프리마켓';
      case 'POST':
      case 'POSTPOST':
        return '애프터마켓';
      case 'CLOSED':
      default:
        return '휴장';
    }
  }

  @override
  String toString() =>
      'StockQuote($symbol: \$$currentPrice, ${changePercent.toStringAsFixed(2)}%, state: $marketState)';
}

/// Finnhub REST API 서비스
class FinnhubService {
  final Dio _dio;

  /// 나스닥 100 지수 심볼 (Finnhub은 ^NDX 대신 QQQ ETF 사용 권장)
  static const String nasdaqSymbol = 'QQQ';

  /// S&P 500 지수 심볼 (Finnhub은 ^GSPC 대신 SPY ETF 사용 권장)
  static const String sp500Symbol = 'SPY';

  FinnhubService()
      : _dio = Dio(BaseOptions(
          baseUrl: AppConfig.finnhubBaseUrl,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 20),
          queryParameters: {
            'token': AppConfig.finnhubApiKey,
          },
        ));

  /// 단일 종목 시세 조회
  Future<StockQuote> getQuote(String symbol) async {
    try {
      final response = await _dio.get('/quote', queryParameters: {
        'symbol': symbol.toUpperCase(),
      });

      return _parseQuoteResponse(symbol, response.data);
    } on DioException catch (e) {
      throw NetworkException(
        message: '네트워크 연결에 실패했습니다: ${e.message}',
        originalError: e,
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ParseException(
        message: '주가 데이터 파싱 실패: $symbol',
        originalError: e,
      );
    }
  }

  StockQuote _parseQuoteResponse(String symbol, dynamic data) {
    final currentPrice = (data['c'] as num?)?.toDouble() ?? 0;
    final previousClose = (data['pc'] as num?)?.toDouble() ?? currentPrice;
    final dayHigh = (data['h'] as num?)?.toDouble() ?? currentPrice;
    final dayLow = (data['l'] as num?)?.toDouble() ?? currentPrice;

    if (currentPrice == 0) {
      throw NotFoundException(message: '종목을 찾을 수 없습니다: $symbol');
    }

    // 변동률 계산
    double changePercent = 0;
    if (previousClose > 0) {
      changePercent = ((currentPrice - previousClose) / previousClose) * 100;
    }

    // 시장 상태 계산 (미국 동부시간 기준)
    final marketState = _calculateMarketState();

    return StockQuote(
      symbol: symbol.toUpperCase(),
      currentPrice: currentPrice,
      previousClose: previousClose,
      changePercent: changePercent,
      dayHigh: dayHigh,
      dayLow: dayLow,
      volume: 0, // Finnhub quote API는 볼륨 미제공
      timestamp: DateTime.now(),
      marketState: marketState,
    );
  }

  /// 시장 상태 계산 (미국 동부시간 기준)
  String _calculateMarketState() {
    final now = DateTime.now().toUtc();
    // EDT: UTC-4, EST: UTC-5 (DST 적용 여부에 따라)
    // 간단히 UTC-5로 계산 (EST)
    final eastern = now.subtract(const Duration(hours: 5));
    final hour = eastern.hour;
    final minute = eastern.minute;
    final weekday = eastern.weekday;

    // 주말 체크
    if (weekday == DateTime.saturday || weekday == DateTime.sunday) {
      return 'CLOSED';
    }

    final timeInMinutes = hour * 60 + minute;
    const preMarketStart = 4 * 60; // 04:00
    const marketOpen = 9 * 60 + 30; // 09:30
    const marketClose = 16 * 60; // 16:00
    const afterHoursEnd = 20 * 60; // 20:00

    if (timeInMinutes >= marketOpen && timeInMinutes < marketClose) {
      return 'REGULAR';
    } else if (timeInMinutes >= preMarketStart && timeInMinutes < marketOpen) {
      return 'PRE';
    } else if (timeInMinutes >= marketClose && timeInMinutes < afterHoursEnd) {
      return 'POST';
    }

    return 'CLOSED';
  }

  /// 여러 종목 시세 일괄 조회
  Future<Map<String, StockQuote>> getQuotes(List<String> symbols) async {
    final results = <String, StockQuote>{};
    final errors = <String, ApiException>{};

    // 병렬 요청
    final futures = symbols.map((symbol) async {
      try {
        final quote = await getQuote(symbol);
        results[symbol] = quote;
      } on ApiException catch (e) {
        errors[symbol] = e;
      }
    });

    await Future.wait(futures);

    if (results.isEmpty && errors.isNotEmpty) {
      throw errors.values.first;
    }

    return results;
  }

  /// 한국어 검색어를 영어로 변환
  static const Map<String, String> _koreanToEnglish = {
    '애플': 'AAPL',
    '아이폰': 'AAPL',
    '마이크로소프트': 'MSFT',
    '구글': 'GOOGL',
    '알파벳': 'GOOGL',
    '아마존': 'AMZN',
    '메타': 'META',
    '페이스북': 'META',
    '테슬라': 'TSLA',
    '엔비디아': 'NVDA',
    '넷플릭스': 'NFLX',
    '인텔': 'INTC',
    '퀄컴': 'QCOM',
    '브로드컴': 'AVGO',
    '마이크론': 'MU',
    '버크셔': 'BRK.B',
    '코카콜라': 'KO',
    '맥도날드': 'MCD',
    '스타벅스': 'SBUX',
    '나이키': 'NKE',
    '월마트': 'WMT',
    '코스트코': 'COST',
    '디즈니': 'DIS',
    '비자': 'V',
    '마스터카드': 'MA',
    '페이팔': 'PYPL',
    '나스닥': 'QQQ',
    '나스닥3배': 'TQQQ',
    '에스앤피': 'SPY',
    '에스엔피': 'SPY',
    '반도체3배': 'SOXL',
  };

  String _convertKoreanQuery(String query) {
    final lowerQuery = query.toLowerCase().replaceAll(' ', '');
    for (final entry in _koreanToEnglish.entries) {
      if (lowerQuery.contains(entry.key.toLowerCase())) {
        return entry.value;
      }
    }
    return query;
  }

  bool _containsKorean(String text) {
    return RegExp(r'[\uAC00-\uD7AF\u3130-\u318F\u1100-\u11FF]').hasMatch(text);
  }

  /// 종목 검색
  Future<List<SearchResult>> searchStocks(String query) async {
    if (query.isEmpty) return [];

    try {
      String searchQuery = query;
      if (_containsKorean(query)) {
        searchQuery = _convertKoreanQuery(query);
        if (_containsKorean(searchQuery)) {
          return [];
        }
      }

      final response = await _dio.get('/search', queryParameters: {
        'q': searchQuery,
        'exchange': 'US', // 미국 거래소만
      });

      return _parseSearchResponse(response.data);
    } catch (e) {
      return [];
    }
  }

  List<SearchResult> _parseSearchResponse(dynamic data) {
    final results = <SearchResult>[];
    try {
      final items = data['result'] as List?;
      if (items == null) return [];

      for (final item in items) {
        // 미국 거래소 티커만 필터링
        final symbol = item['symbol'] as String? ?? '';
        if (symbol.contains('.') || symbol.contains(':')) continue;

        results.add(SearchResult(
          symbol: symbol,
          name: item['description'] ?? '',
          exchange: item['primaryExchange'] ?? 'US',
          type: item['type'] ?? 'Common Stock',
        ));
      }
    } catch (_) {}
    return results.take(20).toList();
  }

  /// 종목 거래소 조회 (profile2)
  Future<String> getExchange(String symbol) async {
    try {
      final response = await _dio.get('/stock/profile2', queryParameters: {
        'symbol': symbol,
      });
      final exchange = response.data['exchange'] as String? ?? '';
      if (exchange.contains('NASDAQ')) return 'NASDAQ';
      if (exchange.contains('NYSE')) return 'NYSE';
      if (exchange.contains('AMEX')) return 'AMEX';
      if (exchange.isNotEmpty) return exchange;
    } catch (_) {}
    return 'US';
  }

  /// 종목 로고 URL 조회 (profile2)
  Future<String?> getCompanyLogo(String symbol) async {
    try {
      final response = await _dio.get('/stock/profile2', queryParameters: {
        'symbol': symbol,
      });
      final logo = response.data['logo'] as String?;
      if (logo != null && logo.isNotEmpty) return logo;
    } catch (_) {}
    return null;
  }

  /// 뉴스 가져오기
  Future<List<NewsItem>> getNews(String symbol) async {
    try {
      final now = DateTime.now();
      final from = now.subtract(const Duration(days: 7));

      final response = await _dio.get('/company-news', queryParameters: {
        'symbol': symbol.toUpperCase(),
        'from': '${from.year}-${from.month.toString().padLeft(2, '0')}-${from.day.toString().padLeft(2, '0')}',
        'to': '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
      });

      return _parseNewsResponse(response.data);
    } catch (e) {
      return [];
    }
  }

  List<NewsItem> _parseNewsResponse(dynamic data) {
    final newsList = <NewsItem>[];
    try {
      final items = data as List?;
      if (items == null) return [];

      for (final item in items.take(5)) {
        newsList.add(NewsItem(
          title: item['headline'] ?? '',
          publisher: item['source'] ?? '',
          link: item['url'] ?? '',
          publishedAt: DateTime.fromMillisecondsSinceEpoch(
            ((item['datetime'] as int?) ?? 0) * 1000,
          ),
          thumbnail: item['image'],
        ));
      }
    } catch (_) {}
    return newsList;
  }

}
