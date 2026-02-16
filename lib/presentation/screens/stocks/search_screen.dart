import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/watchlist_item.dart';
import '../../../data/services/api/finnhub_service.dart';
import '../../providers/api_providers.dart';
import '../../providers/cycle_providers.dart';
import '../../providers/stock_providers.dart';
import '../../providers/watchlist_providers.dart';
import '../../widgets/shared/return_badge.dart';
import '../../widgets/stocks/popular_etf_list.dart';

/// 종목 검색 화면
class SearchScreen extends ConsumerStatefulWidget {
  /// true면 일반 보유용, false면 알파 사이클용
  final bool forHolding;

  const SearchScreen({super.key, this.forHolding = false});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchController = TextEditingController();
  final Map<String, StockQuote> _searchQuotes = {};
  final Set<String> _fetchingQuotes = {};

  @override
  void initState() {
    super.initState();

    // 관심종목 로드 (아직 로드되지 않은 경우)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final watchlistState = ref.read(watchlistProvider);
      if (watchlistState.items.isEmpty && !watchlistState.isLoading) {
        ref.read(watchlistProvider.notifier).load();
      }
    });
  }

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
    // 실제 활성 사이클의 티커 목록 가져오기
    final activeCycles = ref.watch(activeCyclesProvider);
    final activeTickers = activeCycles.map((c) => c.ticker).toSet();
    final searchState = ref.watch(searchProvider);
    // 관심종목 상태 - 직접 watch (단순화)
    final watchlistState = ref.watch(watchlistProvider);
    // 실시간 시세 (WebSocket)
    final stockQuoteState = ref.watch(stockQuoteProvider);
    // 인기 ETF 가격 정보
    final stockPriceState = ref.watch(stockPriceProvider);

    return Scaffold(
      backgroundColor: context.appBackground,
      appBar: AppBar(
        backgroundColor: context.appBackground,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        title: Text(widget.forHolding ? '종목검색' : '종목 추가'),
      ),
      body: Column(
        children: [
          // 검색바
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                if (value.length >= 1) {
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
                ? _buildDefaultList(activeTickers, watchlistState, stockQuoteState, stockPriceState)
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
    WatchlistState watchlistState,
    StockQuoteState stockQuoteState,
    Map<String, StockPrice> stockPrices,
  ) {
    final watchlistItems = watchlistState.items;
    // 인기 ETF 가격 정보를 Map으로 변환
    final etfQuotes = <String, StockPrice?>{};
    for (final etf in PopularEtf.leveraged3x) {
      etfQuotes[etf.ticker] = stockPrices[etf.ticker];
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 관심종목 섹션 (있을 때만 표시)
          if (watchlistItems.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                '내 관심종목',
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
              itemCount: watchlistItems.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = watchlistItems[index];
                final isDisabled = activeTickers.contains(item.ticker);
                // stockQuoteProvider에서 실시간 시세 조회
                final quote = stockQuoteState.quotes[item.ticker];

                return _WatchlistSuggestionTile(
                  ticker: item.ticker,
                  name: item.name,
                  quote: quote,
                  isDisabled: isDisabled,
                  onTap: isDisabled ? null : () => _onWatchlistItemSelected(item),
                );
              },
            ),
            const SizedBox(height: 24),
          ],
          // 인기 ETF 섹션
          PopularEtfList(
            onEtfSelected: _onEtfSelected,
            disabledTickers: activeTickers,
            quotes: etfQuotes,
          ),
        ],
      ),
    );
  }

  void _onWatchlistItemSelected(WatchlistItem item) {
    final etf = PopularEtf(
      ticker: item.ticker,
      name: item.name,
      description: item.name,
      category: 'WATCHLIST',
    );
    final route = widget.forHolding
        ? '/holdings/setup/${item.ticker}'
        : '/stocks/setup/${item.ticker}';
    context.push(route, extra: etf);
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
              '다른 검색어를 입력하거나\n인기 ETF에서 선택해주세요',
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

        return _SearchResultTile(
          result: result,
          isDisabled: isDisabled,
          quote: _searchQuotes[result.symbol],
          onTap: isDisabled ? null : () => _onSearchResultSelected(result),
        );
      },
    );
  }

  void _onEtfSelected(PopularEtf etf) {
    final route = widget.forHolding
        ? '/holdings/setup/${etf.ticker}'
        : '/stocks/setup/${etf.ticker}';
    context.push(route, extra: etf);
  }

  void _onSearchResultSelected(SearchResult result) {
    // PopularEtf 형식으로 변환하여 전달
    final etf = PopularEtf(
      ticker: result.symbol,
      name: result.name,
      description: result.name,
      category: result.type,
    );
    final route = widget.forHolding
        ? '/holdings/setup/${result.symbol}'
        : '/stocks/setup/${result.symbol}';
    context.push(route, extra: etf);
  }
}

/// 검색 결과 타일
class _SearchResultTile extends StatelessWidget {
  final SearchResult result;
  final bool isDisabled;
  final StockQuote? quote;
  final VoidCallback? onTap;

  const _SearchResultTile({
    required this.result,
    required this.isDisabled,
    this.quote,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      enabled: !isDisabled,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isDisabled
              ? AppColors.gray100
              : _getTypeColor(result.type).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            result.symbol.substring(0, result.symbol.length > 2 ? 2 : result.symbol.length),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isDisabled ? context.appTextHint : _getTypeColor(result.type),
            ),
          ),
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      result.symbol,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isDisabled ? context.appTextHint : context.appTextPrimary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.gray100,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        result.type,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                          color: context.appTextHint,
                        ),
                      ),
                    ),
                    if (isDisabled) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.gray200,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          '추가됨',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w500,
                            color: context.appTextHint,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  result.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDisabled ? context.appTextHint : context.appTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      trailing: isDisabled
          ? null
          : quote != null
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '\$${quote!.currentPrice.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: context.appTextPrimary,
                      ),
                    ),
                    ReturnBadge(
                      value: quote!.changePercent,
                      size: ReturnBadgeSize.small,
                      colorScheme: ReturnBadgeColorScheme.redBlue,
                      decimals: 2,
                      showIcon: false,
                    ),
                  ],
                )
              : const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
    );
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'ETF':
        return AppColors.blue500;
      case 'INDEX':
        return AppColors.amber500;
      default:
        return AppColors.green500;
    }
  }
}

/// 관심종목 추천 타일
class _WatchlistSuggestionTile extends StatelessWidget {
  final String ticker;
  final String name;
  final StockQuote? quote;
  final bool isDisabled;
  final VoidCallback? onTap;

  const _WatchlistSuggestionTile({
    required this.ticker,
    required this.name,
    required this.quote,
    required this.isDisabled,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final changePercent = quote?.changePercent ?? 0;

    return ListTile(
      onTap: onTap,
      enabled: !isDisabled,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isDisabled
              ? AppColors.gray100
              : AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            ticker.substring(0, ticker.length > 2 ? 2 : ticker.length),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isDisabled ? context.appTextHint : AppColors.primary,
            ),
          ),
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      ticker,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isDisabled ? context.appTextHint : context.appTextPrimary,
                      ),
                    ),
                    if (isDisabled) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.gray200,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          '추가됨',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w500,
                            color: context.appTextHint,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDisabled ? context.appTextHint : context.appTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (quote != null && !isDisabled) ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '\$${quote!.currentPrice.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: context.appTextPrimary,
                  ),
                ),
                ReturnBadge(
                  value: changePercent,
                  size: ReturnBadgeSize.small,
                  colorScheme: ReturnBadgeColorScheme.redBlue,
                  decimals: 2,
                  showIcon: false,
                ),
              ],
            ),
          ],
        ],
      ),
      trailing: isDisabled
          ? null
          : Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: context.appTextHint,
            ),
    );
  }
}
