import 'package:dio/dio.dart';
import '../../../core/config/app_config.dart';
import 'api_exception.dart';
import 'proxy_config.dart';

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
  final String? summary;

  const NewsItem({
    required this.title,
    this.translatedTitle,
    required this.publisher,
    required this.link,
    required this.publishedAt,
    this.thumbnail,
    this.summary,
  });

  /// 표시용 제목 (번역된 제목 우선)
  String get displayTitle => translatedTitle ?? title;

  NewsItem copyWith({String? translatedTitle, String? summary}) {
    return NewsItem(
      title: title,
      translatedTitle: translatedTitle ?? this.translatedTitle,
      publisher: publisher,
      link: link,
      publishedAt: publishedAt,
      thumbnail: thumbnail,
      summary: summary ?? this.summary,
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
  });

  bool get isPositive => changePercent >= 0;
  bool get isMarketOpen => marketState == 'REGULAR';

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
          baseUrl: ProxyConfig.finnhubBaseUrl,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 20),
          queryParameters: ProxyConfig.useProxy
              ? {}
              : {'token': AppConfig.finnhubApiKey},
        )) {
    ProxyConfig.addAuthInterceptor(_dio);
  }

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
    final marketState = calculateMarketState();

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

  /// 시장 상태 계산 (미국 동부시간 기준) — 공개 static
  static String calculateMarketState() {
    final now = DateTime.now().toUtc();
    // DST: 3월 둘째 일요일 ~ 11월 첫째 일요일 → EDT(UTC-4), 그 외 EST(UTC-5)
    final isDst = _isDaylightSavingTime(now);
    final eastern = now.subtract(Duration(hours: isDst ? 4 : 5));
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

  /// 미국 서머타임 판별 (3월 둘째 일요일 ~ 11월 첫째 일요일)
  static bool _isDaylightSavingTime(DateTime utcNow) {
    final year = utcNow.year;

    // 3월 둘째 일요일 02:00 EST → UTC 07:00
    final marchFirst = DateTime.utc(year, 3, 1);
    final marchSecondSunday = marchFirst.add(
      Duration(days: (7 - marchFirst.weekday) % 7 + 7),
    );
    final dstStart = marchSecondSunday.add(const Duration(hours: 7));

    // 11월 첫째 일요일 02:00 EDT → UTC 06:00
    final novFirst = DateTime.utc(year, 11, 1);
    final novFirstSunday = novFirst.weekday == DateTime.sunday
        ? novFirst
        : novFirst.add(Duration(days: 7 - novFirst.weekday));
    final dstEnd = novFirstSunday.add(const Duration(hours: 6));

    return utcNow.isAfter(dstStart) && utcNow.isBefore(dstEnd);
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

  /// 한국어 검색어를 영어로 변환 (한국 투자자 인기 종목 ~120개)
  static const Map<String, String> _koreanToEnglish = {
    // 빅테크 / 매그니피센트 7
    '애플': 'AAPL', '아이폰': 'AAPL',
    '마이크로소프트': 'MSFT', '엠에스': 'MSFT',
    '구글': 'GOOGL', '알파벳': 'GOOGL',
    '아마존': 'AMZN',
    '메타': 'META', '페이스북': 'META',
    '테슬라': 'TSLA',
    '엔비디아': 'NVDA', '엔비': 'NVDA',

    // 반도체
    '인텔': 'INTC',
    '퀄컴': 'QCOM',
    '브로드컴': 'AVGO',
    '마이크론': 'MU',
    '에이엠디': 'AMD', '암드': 'AMD',
    '아이온큐': 'IONQ',
    '에이에스엠엘': 'ASML', '아스엠엘': 'ASML',
    '텍사스인스트루먼트': 'TXN',
    '마벨': 'MRVL', '마벨테크': 'MRVL',
    '아날로그디바이스': 'ADI',
    '온세미': 'ON', '온세미컨덕터': 'ON',
    '글로벌파운드리': 'GFS',
    '램리서치': 'LRCX',
    '어플라이드머티리얼즈': 'AMAT', '어플라이드': 'AMAT',
    '케이엘에이': 'KLAC',
    '시놉시스': 'SNPS',
    '케이던스': 'CDNS',
    '암': 'ARM', '에이알엠': 'ARM',

    // 소프트웨어 / 클라우드
    '넷플릭스': 'NFLX',
    '어도비': 'ADBE',
    '세일즈포스': 'CRM',
    '오라클': 'ORCL',
    '시스코': 'CSCO',
    '서비스나우': 'NOW',
    '팔란티어': 'PLTR',
    '스노우플레이크': 'SNOW',
    '데이터독': 'DDOG',
    '크라우드스트라이크': 'CRWD',
    '줌': 'ZM', '줌비디오': 'ZM',
    '유아이패스': 'PATH',
    '몽고디비': 'MDB',
    '클라우드플레어': 'NET',

    // AI / 로봇
    '사운드하운드': 'SOUN',
    '씨쓰리에이아이': 'AI', 'C3AI': 'AI',
    '빅베어': 'BBAI',
    '심볼릭': 'SMBL',
    '로블록스': 'RBLX',

    // 전기차 / 에너지
    '리비안': 'RIVN',
    '루시드': 'LCID',
    '니오': 'NIO',
    '샤오펑': 'XPEV', '소펑': 'XPEV',
    '리': 'LI', '리오토': 'LI',
    '퀀텀스케이프': 'QS',
    '엔페이즈': 'ENPH', '엔페이즈에너지': 'ENPH',
    '솔라엣지': 'SEDG',
    '플러그파워': 'PLUG',
    '넥스트에라': 'NEE',

    // 금융
    '비자': 'V',
    '마스터카드': 'MA',
    '페이팔': 'PYPL',
    '제이피모건': 'JPM', '제이피엠': 'JPM',
    '골드만삭스': 'GS',
    '모건스탠리': 'MS',
    '뱅크오브아메리카': 'BAC',
    '찰스슈왑': 'SCHW',
    '블랙록': 'BLK',
    '소파이': 'SOFI',
    '코인베이스': 'COIN',

    // 소비재 / 유통
    '코카콜라': 'KO',
    '펩시': 'PEP', '펩시코': 'PEP',
    '맥도날드': 'MCD',
    '스타벅스': 'SBUX',
    '나이키': 'NKE',
    '월마트': 'WMT',
    '코스트코': 'COST',
    '타겟': 'TGT',
    '홈디포': 'HD',
    '프록터앤갬블': 'PG', '피앤지': 'PG',
    '존슨앤존슨': 'JNJ',

    // 헬스케어 / 바이오
    '화이자': 'PFE',
    '모더나': 'MRNA',
    '유나이티드헬스': 'UNH',
    '애브비': 'ABBV',
    '일라이릴리': 'LLY', '릴리': 'LLY',
    '노보노디스크': 'NVO',
    '암젠': 'AMGN',
    '길리어드': 'GILD',
    '인튜이티브서지컬': 'ISRG',

    // 통신 / 미디어
    '디즈니': 'DIS',
    '컴캐스트': 'CMCSA',
    '티모바일': 'TMUS',
    '버라이즌': 'VZ',
    '에이티앤티': 'T',
    '스포티파이': 'SPOT',
    '워너브라더스': 'WBD',

    // 산업 / 방산 / 항공
    '보잉': 'BA',
    '록히드마틴': 'LMT',
    '캐터필러': 'CAT',
    '유나이티드파슬': 'UPS',
    '페덱스': 'FDX',
    '디어': 'DE', '존디어': 'DE',
    '레이시온': 'RTX',

    // 버크셔
    '버크셔': 'BRK.B', '버크셔해서웨이': 'BRK.B', '워렌버핏': 'BRK.B',

    // ETF
    '나스닥': 'QQQ',
    '나스닥3배': 'TQQQ',
    '나스닥인버스': 'SQQQ',
    '에스앤피': 'SPY', '에스엔피': 'SPY',
    '에스앤피3배': 'UPRO',
    '반도체': 'SOXX', '반도체3배': 'SOXL', '반도체인버스': 'SOXS',
    '다우': 'DIA', '다우존스': 'DIA',
    '러셀': 'IWM',
    '금': 'GLD', '골드': 'GLD',
    '은': 'SLV', '실버': 'SLV',
    '원유': 'USO', '오일': 'USO',
    '채권': 'TLT', '장기채': 'TLT',
    '비트코인': 'IBIT',
    '아크': 'ARKK', '아크이노베이션': 'ARKK',
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
      final response = await _dio.get(
        ProxyConfig.finnhubPath('/stock/profile2'),
        queryParameters: {'symbol': symbol},
      );
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
      final response = await _dio.get(
        ProxyConfig.finnhubPath('/stock/profile2'),
        queryParameters: {'symbol': symbol},
      );
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
