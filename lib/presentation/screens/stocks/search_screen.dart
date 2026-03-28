import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/recent_view_item.dart';
import '../../../data/services/api/finnhub_service.dart';
import '../../widgets/stocks/popular_etf_list.dart';
import '../../widgets/stocks/search_result_tile.dart';
import '../../widgets/stocks/watchlist_suggestion_tile.dart';
import '../../providers/providers.dart';

/// 종목 검색 화면
class SearchScreen extends ConsumerStatefulWidget {
  /// 보유 종목 검색 여부
  final bool forHolding;

  /// 상세 페이지 이동 모드 (관심종목 검색 바에서 진입 시)
  final bool forDetail;

  const SearchScreen({super.key, this.forHolding = false, this.forDetail = false});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchController = TextEditingController();
  final Map<String, StockQuote> _searchQuotes = {};
  final Set<String> _fetchingQuotes = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// 검색 결과의 시세를 가져오기 (상위 5개만)
  void _fetchQuotesForResults(List<SearchResult> results) {
    final finnhub = ref.read(finnhubServiceProvider);
    final toFetch = results
        .take(5)
        .where((r) => !_searchQuotes.containsKey(r.symbol) && !_fetchingQuotes.contains(r.symbol))
        .toList();

    for (final result in toFetch) {
      _fetchingQuotes.add(result.symbol);
      finnhub.getQuote(result.symbol).then((quote) {
        if (mounted) {
          setState(() {
            _searchQuotes[result.symbol] = quote;
            _fetchingQuotes.remove(result.symbol);
          });
        }
      }).catchError((_) {
        if (mounted) {
          setState(() => _fetchingQuotes.remove(result.symbol));
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 활성 보유 종목의 티커 목록 (중복 추가 방지)
    final activeHoldings = ref.watch(activeHoldingsProvider);
    final activeTickers = activeHoldings.map((h) => h.ticker).toSet();
    final searchState = ref.watch(searchProvider);
    // 최근 조회 종목
    final recentItems = ref.watch(recentViewProvider);
    // 여러 ticker 사용 — select 적용 불가
    final stockQuoteState = ref.watch(stockQuoteProvider);

    return Scaffold(
      backgroundColor: context.appBackground,
      appBar: AppBar(
        backgroundColor: context.appBackground,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        title: Text(widget.forHolding ? '종목검색' : widget.forDetail ? '종목 검색' : '종목 추가'),
      ),
      body: Column(
        children: [
          // 검색바
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                if (value.isNotEmpty) {
                  ref.read(searchProvider.notifier).search(value);
                } else {
                  ref.read(searchProvider.notifier).clear();
                }
              },
              decoration: InputDecoration(
                hintText: '티커/종목명 검색 (예: AAPL, 애플, 테슬라)',
                prefixIcon: const Icon(Icons.search, color: AppColors.gray400),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: AppColors.gray400),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(searchProvider.notifier).clear();
                          setState(() {});
                        },
                      )
                    : null,
                filled: true,
                fillColor: context.appSurface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
          ),

          // 검색 결과 또는 기본 목록
          Expanded(
            child: searchState.query.isEmpty
                ? _buildDefaultList(activeTickers, recentItems, stockQuoteState)
                : searchState.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _buildSearchResults(searchState.results, activeTickers),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultList(
    Set<String> activeTickers,
    List<RecentViewItem> recentItems,
    StockQuoteState stockQuoteState,
  ) {
    if (recentItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 48, color: context.appTextHint),
            const SizedBox(height: 16),
            Text(
              '최근 조회한 종목이 없습니다',
              style: TextStyle(fontSize: 14, color: context.appTextSecondary),
            ),
            const SizedBox(height: 8),
            Text(
              '티커 또는 종목명을 검색해주세요',
              style: TextStyle(fontSize: 12, color: context.appTextHint),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              '최근 조회',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: context.appTextPrimary,
              ),
            ),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: recentItems.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = recentItems[index];
              final isDisabled = activeTickers.contains(item.ticker);
              final quote = stockQuoteState.quotes[item.ticker];

              return WatchlistSuggestionTile(
                ticker: item.ticker,
                name: item.name,
                quote: quote,
                isDisabled: isDisabled,
                onTap: isDisabled ? null : () => _onRecentItemSelected(item),
              );
            },
          ),
        ],
      ),
    );
  }

  void _onRecentItemSelected(RecentViewItem item) {
    if (widget.forDetail) {
      context.push('/index/${Uri.encodeComponent(item.ticker)}?from=watchlist');
      return;
    }
    final etf = PopularEtf(
      ticker: item.ticker,
      name: item.name,
      description: item.name,
      category: item.type.isNotEmpty ? item.type : 'RECENT',
    );
    context.push('/holdings/setup/${item.ticker}', extra: etf);
  }

  Widget _buildSearchResults(List<SearchResult> results, Set<String> activeTickers) {
    // 검색 결과가 있으면 시세 조회 트리거
    if (results.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _fetchQuotesForResults(results);
      });
    }

    if (results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 48,
              color: AppColors.gray400,
            ),
            const SizedBox(height: 16),
            Text(
              '"${ref.read(searchProvider).query}" 검색 결과가 없습니다',
              style: TextStyle(
                fontSize: 14,
                color: context.appTextSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '영문 티커 또는 기업명으로 검색해주세요\n예: AAPL, NVDA, IONQ, Tesla',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: context.appTextHint,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: results.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final result = results[index];
        final isDisabled = activeTickers.contains(result.symbol);

        return SearchResultTile(
          result: result,
          isDisabled: isDisabled,
          quote: _searchQuotes[result.symbol],
          onTap: isDisabled ? null : () => _onSearchResultSelected(result),
        );
      },
    );
  }

  void _onSearchResultSelected(SearchResult result) {
    if (widget.forDetail) {
      context.push('/index/${Uri.encodeComponent(result.symbol)}?from=watchlist');
      return;
    }
    // PopularEtf 형식으로 변환하여 전달
    final etf = PopularEtf(
      ticker: result.symbol,
      name: result.name,
      description: result.name,
      category: result.type,
    );
    context.push('/holdings/setup/${result.symbol}', extra: etf);
  }
}
