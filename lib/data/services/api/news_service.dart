import 'package:dio/dio.dart';
import '../../../core/config/app_config.dart';
import 'finnhub_service.dart';

/// MarketAux + Finnhub 뉴스 + MyMemory 번역 서비스
///
/// MarketAux API (키워드 검색, 3개) + Finnhub company-news (제목 필터링, 3개)
/// MyMemory Translation API로 제목을 한국어로 번역합니다.
class NewsService {
  final Dio _dio;

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

  /// 지수 심볼 변환
  String _convertSymbol(String symbol) {
    switch (symbol) {
      case '^NDX':
        return 'QQQ';
      case '^GSPC':
        return 'SPY';
      default:
        return symbol.toUpperCase();
    }
  }

  /// 뉴스 제목들을 한국어로 일괄 번역
  Future<List<NewsItem>> _translateTitles(List<NewsItem> articles) async {
    if (articles.isEmpty) return articles;

    // 병렬로 번역 요청
    final futures = articles.map((article) async {
      try {
        final koreanTitle = await _translateToKorean(article.title);
        return article.copyWith(translatedTitle: koreanTitle);
      } catch (_) {
        return article;
      }
    });

    return await Future.wait(futures);
  }

  /// 영어 텍스트를 한국어로 번역 (MyMemory API)
  Future<String?> _translateToKorean(String text) async {
    if (text.isEmpty) return null;

    try {
      final response = await _dio.get(
        'https://api.mymemory.translated.net/get',
        queryParameters: {
          'q': text,
          'langpair': 'en|ko',
        },
      );

      final translatedText =
          response.data['responseData']?['translatedText'] as String?;

      if (translatedText == null ||
          translatedText.isEmpty ||
          translatedText == text) {
        return null;
      }

      return translatedText;
    } catch (_) {
      return null;
    }
  }
}
