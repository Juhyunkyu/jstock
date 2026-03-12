import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/services/api/finnhub_service.dart';
import '../../data/services/api/news_service.dart';
import '../../data/services/cache/cache_manager.dart';
import 'api_providers.dart';

/// 시장 뉴스 캐시 키
String marketNewsCacheKey() => 'market_news:general';

/// 시장 뉴스 상태
class MarketNewsState {
  final List<NewsItem> news;
  final bool isLoading;
  final String? error;
  final DateTime? lastUpdated;

  const MarketNewsState({
    this.news = const [],
    this.isLoading = false,
    this.error,
    this.lastUpdated,
  });

  MarketNewsState copyWith({
    List<NewsItem>? news,
    bool? isLoading,
    String? error,
    DateTime? lastUpdated,
  }) {
    return MarketNewsState(
      news: news ?? this.news,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  bool get hasData => news.isNotEmpty;
}

/// 시장 뉴스 Notifier
class MarketNewsNotifier extends StateNotifier<MarketNewsState> {
  final NewsService _newsService;
  final CacheManager _cache;

  /// 30분 캐시 (뉴스는 실시간 불필요, 번역 API 부하 절감)
  static const Duration _cacheTtl = Duration(minutes: 30);

  MarketNewsNotifier(this._newsService, this._cache)
      : super(const MarketNewsState());

  /// 시장 뉴스 조회
  Future<void> fetchNews() async {
    final cacheKey = marketNewsCacheKey();

    // 캐시 확인
    final cached = _cache.get<List<NewsItem>>(cacheKey);
    if (cached != null) {
      state = state.copyWith(
        news: cached,
        lastUpdated: DateTime.now(),
      );
      return;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      final news = await _newsService.getGeneralNews(limit: 20);

      // 캐시 저장 (30분)
      _cache.set(cacheKey, news, ttl: _cacheTtl);

      state = state.copyWith(
        news: news,
        isLoading: false,
        lastUpdated: DateTime.now(),
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: '시장 뉴스 조회 실패',
      );
    }
  }

  /// 강제 새로고침
  Future<void> refresh() async {
    _cache.remove(marketNewsCacheKey());
    await fetchNews();
  }
}

/// 시장 뉴스 Provider
final marketNewsProvider =
    StateNotifierProvider<MarketNewsNotifier, MarketNewsState>((ref) {
  final newsService = ref.watch(newsServiceProvider);
  final cache = ref.watch(cacheManagerProvider);
  return MarketNewsNotifier(newsService, cache);
});
