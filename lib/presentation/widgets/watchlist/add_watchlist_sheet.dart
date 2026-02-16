import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/watchlist_item.dart';
import '../../../data/services/api/finnhub_service.dart';
import '../../providers/api_providers.dart';
import '../../providers/watchlist_providers.dart';
import '../shared/ticker_logo.dart';
import 'watchlist_helpers.dart';

/// 관심종목 추가 시트
class AddWatchlistSheet extends ConsumerStatefulWidget {
  const AddWatchlistSheet({super.key});

  @override
  ConsumerState<AddWatchlistSheet> createState() => _AddWatchlistSheetState();
}

class _AddWatchlistSheetState extends ConsumerState<AddWatchlistSheet> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(searchProvider);
    final watchlistState = ref.watch(watchlistProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // 핸들
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: context.appBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // 헤더
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '종목 검색',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: context.appTextPrimary,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // 검색바
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              onChanged: (value) {
                if (value.isNotEmpty) {
                  ref.read(searchProvider.notifier).search(value);
                } else {
                  ref.read(searchProvider.notifier).clear();
                }
              },
              decoration: InputDecoration(
                hintText: '티커/종목명 검색 (예: AAPL, 애플, 테슬라)',
                prefixIcon: Icon(Icons.search, color: context.appTextHint),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, color: context.appTextHint),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(searchProvider.notifier).clear();
                        },
                      )
                    : null,
                filled: true,
                fillColor: context.appBackground,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 검색 결과
          Expanded(
            child: searchState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : searchState.results.isEmpty
                    ? _buildEmptySearch(searchState.query)
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: searchState.results.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final result = searchState.results[index];
                          final isAdded = watchlistState.items
                              .any((item) => item.ticker == result.symbol);

                          return _SearchResultTile(
                            result: result,
                            isAdded: isAdded,
                            onAdd: () => _addToWatchlist(result),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptySearch(String query) {
    if (query.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 48, color: context.appBorder),
            const SizedBox(height: 16),
            Text(
              '티커 또는 종목명을 검색해주세요',
              style: TextStyle(
                fontSize: 14,
                color: context.appTextHint,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '예: AAPL, 애플, 테슬라, 엔비디아',
              style: TextStyle(
                fontSize: 12,
                color: context.appTextHint,
              ),
            ),
          ],
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 48, color: context.appBorder),
          const SizedBox(height: 16),
          Text(
            '"$query" 검색 결과가 없습니다',
            style: TextStyle(
              fontSize: 14,
              color: context.appTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addToWatchlist(SearchResult result) async {
    final item = WatchlistItem(
      ticker: result.symbol,
      name: result.name,
      exchange: result.exchange,
      type: result.type,
    );

    ref.read(watchlistProvider.notifier).add(item);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${result.symbol} 관심종목에 추가됨'),
          duration: const Duration(seconds: 2),
        ),
      );
    }

    // 백그라운드로 거래소 정보 조회 후 갱신
    final exchange = await ref.read(finnhubServiceProvider).getExchange(result.symbol);
    if (exchange != result.exchange) {
      final repo = ref.read(watchlistRepositoryProvider);
      final saved = repo.getByTicker(result.symbol);
      if (saved != null) {
        saved.exchange = exchange;
        await saved.save();
        ref.read(watchlistProvider.notifier).load();
      }
    }
  }
}

/// 검색 결과 타일
class _SearchResultTile extends StatelessWidget {
  final SearchResult result;
  final bool isAdded;
  final VoidCallback onAdd;

  const _SearchResultTile({
    required this.result,
    required this.isAdded,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: TickerLogo(
        ticker: result.symbol,
        size: 40,
        borderRadius: 8,
        backgroundColor: getTypeColor(result.type).withValues(alpha: 0.1),
        textColor: getTypeColor(result.type),
      ),
      title: Row(
        children: [
          Text(
            result.symbol,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: context.appTickerColor,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: context.appIconBg,
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
        ],
      ),
      subtitle: Text(
        result.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          color: context.appTextSecondary,
        ),
      ),
      trailing: isAdded
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: context.appIconBg,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '추가됨',
                style: TextStyle(
                  fontSize: 12,
                  color: context.appTextHint,
                ),
              ),
            )
          : ElevatedButton(
              onPressed: onAdd,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: Size.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: const Text('추가', style: TextStyle(fontSize: 12)),
            ),
    );
  }
}
