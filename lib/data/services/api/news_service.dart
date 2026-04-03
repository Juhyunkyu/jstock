import 'package:dio/dio.dart';
import 'package:hive/hive.dart';
import '../../../core/config/app_config.dart';
import 'finnhub_service.dart';

/// MarketAux + Finnhub 뉴스 + DeepL 번역 서비스
///
/// MarketAux API (키워드 검색, 3개) + Finnhub company-news (제목 필터링, 3개)
/// DeepL API로 제목을 한국어로 번역합니다.
/// 번역 결과는 Hive에 영속 캐싱하여 DeepL API 사용량을 절약합니다.
class NewsService {
  final Dio _dio;

  /// 번역 캐시 (영문 제목 → 한국어 번역). Hive 기반 영속 저장.
  /// 앱을 꺼도 유지되므로 같은 뉴스 제목은 다시 번역하지 않음.
  static Box<String>? _translationCache;

  /// 캐시 초기화 (앱 시작 시 1회 호출)
  static Future<void> initCache() async {
    _translationCache = await Hive.openBox<String>('translation_cache');
    // 30일 이상 오래된 항목 정리 (박스가 무한히 커지는 것 방지)
    _cleanOldEntries();
  }

  static void _cleanOldEntries() {
    final box = _translationCache;
    if (box == null || box.isEmpty) return;
    // 항목이 5000개 이상이면 앞쪽(오래된) 절반 삭제
    if (box.length > 5000) {
      final keysToDelete = box.keys.take(box.length ~/ 2).toList();
      box.deleteAll(keysToDelete);
    }
  }

  NewsService()
      : _dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 20),
        ));

  /// 심볼 → 회사명 매핑 (검색 키워드용)
  static const Map<String, String> _symbolToName = {
    'NVDA': 'NVIDIA NVDA',
    'AAPL': 'Apple AAPL',
    'MSFT': 'Microsoft MSFT',
    'GOOGL': 'Google Alphabet GOOGL',
    'GOOG': 'Google Alphabet GOOG',
    'AMZN': 'Amazon AMZN',
    'META': 'Meta Facebook META',
    'TSLA': 'Tesla TSLA',
    'NFLX': 'Netflix NFLX',
    'AMD': 'AMD Advanced Micro',
    'INTC': 'Intel INTC',
    'QCOM': 'Qualcomm QCOM',
    'AVGO': 'Broadcom AVGO',
    'MU': 'Micron MU',
    'QQQ': 'QQQ Nasdaq ETF',
    'SPY': 'SPY S&P 500 ETF',
  };

  /// 심볼에서 제목 필터링용 키워드 목록 생성
  static const Map<String, List<String>> _symbolKeywords = {
    'NVDA': ['NVDA', 'NVIDIA', 'Nvidia'],
    'AAPL': ['AAPL', 'Apple'],
    'MSFT': ['MSFT', 'Microsoft'],
    'GOOGL': ['GOOGL', 'Google', 'Alphabet'],
    'GOOG': ['GOOG', 'Google', 'Alphabet'],
    'AMZN': ['AMZN', 'Amazon'],
    'META': ['META', 'Meta ', 'Facebook'],
    'TSLA': ['TSLA', 'Tesla'],
    'NFLX': ['NFLX', 'Netflix'],
    'AMD': ['AMD'],
    'INTC': ['INTC', 'Intel'],
    'QCOM': ['QCOM', 'Qualcomm'],
    'AVGO': ['AVGO', 'Broadcom'],
    'MU': [' MU ', 'Micron'],
    'QQQ': ['QQQ', 'Nasdaq'],
    'SPY': ['SPY', 'S&P 500', 'S&P500'],
  };

  /// 종목 뉴스 가져오기 (MarketAux 3개 + Finnhub 3개 + 한국어 번역)
  Future<List<NewsItem>> getNews(String symbol) async {
    final querySymbol = _convertSymbol(symbol);

    // MarketAux와 Finnhub 병렬 호출
    final results = await Future.wait([
      _fetchMarketAux(querySymbol),
      _fetchFinnhub(querySymbol),
    ]);

    final marketAuxArticles = results[0];
    final finnhubArticles = results[1];

    // MarketAux 기사의 URL 목록 (중복 제거용)
    final marketAuxUrls = marketAuxArticles.map((a) => a.link).toSet();

    // Finnhub 기사 중 MarketAux와 중복되지 않는 것만 추가
    final uniqueFinnhub = finnhubArticles
        .where((a) => !marketAuxUrls.contains(a.link))
        .take(3)
        .toList();

    final allArticles = [...marketAuxArticles, ...uniqueFinnhub];

    // 최신순 정렬
    allArticles.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));

    // 전체 번역
    return await _translateTitles(allArticles);
  }

  /// 시장 종합 뉴스 (Worker RSS 프록시 우선, Finnhub 폴백 + 한국어 번역)
  Future<List<NewsItem>> getGeneralNews({int limit = 20}) async {
    try {
      final baseUrl = AppConfig.proxyBaseUrl;
      if (baseUrl.isEmpty) {
        // 프록시 미설정 (로컬 개발) → Finnhub 폴백
        return _getGeneralNewsFromFinnhub(limit: limit);
      }

      final response = await _dio.get('$baseUrl/api/news/market');
      final data = response.data;
      final articles = data['articles'] as List? ?? [];

      final newsList = <NewsItem>[];
      for (final item in articles) {
        final link = item['link'] as String? ?? '';
        final publisher = item['publisher'] as String? ?? '';
        // 페이월 도메인 + 페이월 퍼블리셔 필터링
        if (_isPaywallUrl(link) || _isPaywallPublisher(publisher)) continue;
        newsList.add(NewsItem(
          title: item['title'] ?? '',
          publisher: publisher,
          link: link,
          publishedAt: DateTime.tryParse(item['publishedAt'] ?? '') ?? DateTime.now(),
          thumbnail: item['thumbnail'] as String?,
          summary: item['summary'] as String?,
        ));
        if (newsList.length >= limit) break;
      }

      return await _translateTitles(newsList);
    } catch (_) {
      // Worker 실패 시 Finnhub 폴백
      return _getGeneralNewsFromFinnhub(limit: limit);
    }
  }


  /// 국내 경제 뉴스 (Worker Korea RSS, 번역 불필요)
  ///
  /// 주의: 이 메서드는 Cloudflare Worker 프록시가 필수입니다.
  /// Worker에서 제공하는 '/api/news/korea' 엔드포인트를 호출합니다.
  ///
  /// 프록시 미설정 시 빈 리스트 반환 (로컬 개발 환경)
  Future<List<NewsItem>> getKoreaNews({int limit = 10}) async {
    try {
      final baseUrl = AppConfig.proxyBaseUrl;
      if (baseUrl.isEmpty) {
        // 프록시 필수: 국내 뉴스는 공개 API가 없음
        // 개발 환경에서는 조용히 빈 리스트 반환
        return [];
      }

      final response = await _dio.get('$baseUrl/api/news/korea');
      
      // 응답 데이터 검증
      final data = response.data;
      if (data == null) return [];
      
      // articles 배열 추출 (필수)
      final articles = data['articles'] as List?;
      if (articles == null) return [];

      // 국내 뉴스는 페이월 필터 + 번역 불필요
      return articles.take(limit).map<NewsItem>((item) {
        return NewsItem(
          title: item['title'] as String? ?? '',
          publisher: item['publisher'] as String? ?? '',
          link: item['link'] as String? ?? '',
          publishedAt: DateTime.tryParse(item['publishedAt'] as String? ?? '') ?? DateTime.now(),
          thumbnail: item['thumbnail'] as String?,
          summary: item['summary'] as String?,
        );
      }).toList();
    } on DioException catch (e) {
      // 네트워크 에러, 타임아웃, HTTP 에러 등
      return [];
    } catch (e) {
      // 기타 파싱 에러 등
      return [];
    }
  }

  /// Finnhub general-news 폴백 (Worker 미사용 또는 장애 시)
  Future<List<NewsItem>> _getGeneralNewsFromFinnhub({int limit = 20}) async {
    try {
      final response = await _dio.get(
        '${AppConfig.finnhubBaseUrl}/news',
        queryParameters: {
          'token': AppConfig.finnhubApiKey,
          'category': 'general',
        },
      );
      final items = response.data as List?;
      if (items == null) return [];

      final newsList = <NewsItem>[];
      for (final item in items) {
        final source = item['source'] as String? ?? '';

        // 페이월 도메인 필터링
        final url = item['url'] as String? ?? '';
        if (_isPaywallUrl(url)) continue;

        newsList.add(NewsItem(
          title: item['headline'] ?? '',
          publisher: source,
          link: item['url'] ?? '',
          publishedAt: DateTime.fromMillisecondsSinceEpoch(
            ((item['datetime'] as int?) ?? 0) * 1000,
          ),
          thumbnail: item['image'],
          summary: item['summary'] as String?,
        ));

        if (newsList.length >= limit) break;
      }
      return await _translateTitles(newsList);
    } catch (_) {
      return [];
    }
  }

  /// MarketAux API에서 뉴스 가져오기 (키워드 검색으로 관련도 높은 기사)
  Future<List<NewsItem>> _fetchMarketAux(String symbol) async {
    try {
      // 심볼에 맞는 검색 키워드 사용
      final searchKeyword = _symbolToName[symbol] ?? symbol;

      // 최근 1주일 기사만, 최신순 정렬
      final afterDate = DateTime.now().subtract(const Duration(days: 7));
      final afterStr =
          '${afterDate.year}-${afterDate.month.toString().padLeft(2, '0')}-${afterDate.day.toString().padLeft(2, '0')}';

      final response = await _dio.get(
        'https://api.marketaux.com/v1/news/all',
        queryParameters: {
          'api_token': AppConfig.marketauxApiKey,
          'search': searchKeyword,
          'language': 'en',
          'limit': '3',
          'sort': 'published_on',
          'sort_order': 'desc',
          'published_after': afterStr,
          'exclude_domains': 'finance.yahoo.com',
        },
      );

      final newsList = <NewsItem>[];
      final articles = response.data['data'] as List?;
      if (articles == null) return [];

      for (final article in articles) {
        final publishedAt = DateTime.tryParse(article['published_at'] ?? '');
        newsList.add(NewsItem(
          title: article['title'] ?? '',
          publisher: article['source'] ?? '',
          link: article['url'] ?? '',
          publishedAt: publishedAt ?? DateTime.now(),
          thumbnail: article['image_url'],
        ));
      }
      return newsList;
    } catch (_) {
      return [];
    }
  }

  /// Finnhub company-news API에서 뉴스 가져오기 (제목에 종목명 포함된 것만)
  Future<List<NewsItem>> _fetchFinnhub(String symbol) async {
    try {
      final now = DateTime.now();
      final from = now.subtract(const Duration(days: 7));

      final response = await _dio.get(
        '${AppConfig.finnhubBaseUrl}/company-news',
        queryParameters: {
          'token': AppConfig.finnhubApiKey,
          'symbol': symbol.toUpperCase(),
          'from':
              '${from.year}-${from.month.toString().padLeft(2, '0')}-${from.day.toString().padLeft(2, '0')}',
          'to':
              '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
        },
      );

      final items = response.data as List?;
      if (items == null) return [];

      // 제목에 종목명/심볼이 포함된 기사만 필터링
      final keywords = _symbolKeywords[symbol] ?? [symbol];
      final newsList = <NewsItem>[];

      for (final item in items) {
        final title = item['headline'] as String? ?? '';
        final isRelevant = keywords.any((kw) => title.contains(kw));
        if (!isRelevant) continue;

        newsList.add(NewsItem(
          title: title,
          publisher: item['source'] ?? '',
          link: item['url'] ?? '',
          publishedAt: DateTime.fromMillisecondsSinceEpoch(
            ((item['datetime'] as int?) ?? 0) * 1000,
          ),
          thumbnail: item['image'],
        ));

        if (newsList.length >= 5) break;
      }
      return newsList;
    } catch (_) {
      return [];
    }
  }

  /// 페이월 도메인 필터링
  static const _paywallDomains = [
    'reuters.com',
    'bloomberg.com',
    'wsj.com',
    'ft.com',
    'barrons.com',
    'marketwatch.com',
    'investing.com',
  ];

  static bool _isPaywallUrl(String url) {
    final lower = url.toLowerCase();
    return _paywallDomains.any((d) => lower.contains(d));
  }

  /// 페이월 퍼블리셔 이름 필터링
  static const _paywallPublishers = [
    'Reuters', 'Bloomberg', 'WSJ', 'Financial Times', 'Barrons', 'MarketWatch',
    'Investing.com',
  ];

  static bool _isPaywallPublisher(String publisher) {
    final lower = publisher.toLowerCase();
    return _paywallPublishers.any((p) => lower.contains(p.toLowerCase()));
  }

  /// 지수 심볼 → 뉴스 검색용 ETF 심볼 변환
  String _convertSymbol(String symbol) {
    switch (symbol) {
      case 'NDX':
        return 'QQQ';
      case 'SPX':
        return 'SPY';
      default:
        return symbol.toUpperCase();
    }
  }

  /// 뉴스 제목들을 한국어로 일괄 번역 (DeepL API + Hive 캐시)
  ///
  /// 1. 캐시에 있는 제목은 캐시에서 가져옴 (DeepL 호출 안 함)
  /// 2. 캐시에 없는 제목만 DeepL에 요청
  /// 3. 번역 결과를 캐시에 저장 (앱 재시작 후에도 유지)
  Future<List<NewsItem>> _translateTitles(List<NewsItem> articles) async {
    if (articles.isEmpty) return articles;
    if (!AppConfig.useProxy && AppConfig.deeplApiKey.isEmpty) return articles;

    final cache = _translationCache;

    // 1단계: 캐시에서 가져올 수 있는 것 먼저 처리
    final uncachedArticles = <int>[]; // 캐시 미스된 기사의 인덱스
    final uncachedTexts = <String>[]; // DeepL에 보낼 텍스트
    final result = List<NewsItem>.from(articles);

    for (int i = 0; i < articles.length; i++) {
      final title = articles[i].title;
      if (title.isEmpty) continue;

      final cached = cache?.get(title);
      if (cached != null) {
        // 캐시 히트 → DeepL 호출 불필요
        result[i] = articles[i].copyWith(translatedTitle: cached);
      } else {
        // 캐시 미스 → DeepL 요청 대상
        uncachedArticles.add(i);
        uncachedTexts.add(title);
      }
    }

    // 2단계: 캐시 미스 항목만 DeepL에 요청
    if (uncachedTexts.isEmpty) return result; // 전부 캐시 히트

    try {
      final response = await _dio.post(
        '${AppConfig.proxyBaseUrl}/api/deepl/translate',
        options: Options(
          headers: {
            if (!AppConfig.useProxy)
              'Authorization': 'DeepL-Auth-Key ${AppConfig.deeplApiKey}',
            'Content-Type': 'application/json',
          },
        ),
        data: {
          'text': uncachedTexts,
          'source_lang': 'EN',
          'target_lang': 'KO',
        },
      );

      final translations = response.data['translations'] as List?;
      if (translations == null) return result;

      // 3단계: 번역 결과 매핑 + 캐시 저장
      for (int j = 0; j < uncachedArticles.length && j < translations.length; j++) {
        final translated = translations[j]['text'] as String?;
        final articleIdx = uncachedArticles[j];
        final originalTitle = articles[articleIdx].title;

        if (translated != null && translated.isNotEmpty && translated != originalTitle) {
          result[articleIdx] = articles[articleIdx].copyWith(translatedTitle: translated);
          // 캐시에 저장 (영속)
          cache?.put(originalTitle, translated);
        }
      }

      return result;
    } catch (_) {
      return result; // 캐시된 것은 유지, DeepL 실패분은 원문
    }
  }
}
