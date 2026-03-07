import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/watchlist_group.dart';
import '../../providers/watchlist_group_providers.dart';
import '../../providers/watchlist_providers.dart';
import '../shared/ticker_logo.dart';
import 'watchlist_helpers.dart';

/// 그룹 내 종목 편집 (추가/삭제/순서변경)
class WatchlistTickerEditor extends ConsumerStatefulWidget {
  const WatchlistTickerEditor({super.key});

  @override
  ConsumerState<WatchlistTickerEditor> createState() =>
      _WatchlistTickerEditorState();
}

class _WatchlistTickerEditorState extends ConsumerState<WatchlistTickerEditor> {
  String? _selectedGroupId;
  bool _isSearching = false;
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final groupState = ref.watch(watchlistGroupProvider);
    final groups = groupState.groups;

    // 그룹이 없으면 안내 메시지
    if (groups.isEmpty) {
      return Center(
        child: Text(
          '그룹을 먼저 만들어주세요',
          style: TextStyle(
            fontSize: 15,
            color: context.appTextSecondary,
          ),
        ),
      );
    }

    // 선택된 그룹 유효성 확인
    final validId = groups.any((g) => g.id == _selectedGroupId);
    if (!validId) {
      _selectedGroupId = groups.first.id;
    }
    final selectedGroup = groups.firstWhere((g) => g.id == _selectedGroupId);

    return Column(
      children: [
        // 그룹 선택 드롭다운 + 카운터/추가 버튼
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildGroupDropdown(groups, selectedGroup),
              const SizedBox(height: 4),
              _buildAddHeader(selectedGroup),
            ],
          ),
        ),
        // 검색 영역 (상단에 표시)
        if (_isSearching) _buildSearchArea(selectedGroup),
        // 종목 리스트
        Expanded(
          child: selectedGroup.tickers.isEmpty
              ? Center(
                  child: Text(
                    '종목이 없습니다',
                    style: TextStyle(
                      fontSize: 14,
                      color: context.appTextHint,
                    ),
                  ),
                )
              : _buildTickerList(selectedGroup),
        ),
      ],
    );
  }

  Widget _buildGroupDropdown(
      List<WatchlistGroup> groups, WatchlistGroup selected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: context.appBorder),
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selected.id,
          isExpanded: true,
          dropdownColor: context.appSurface,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: context.appTextPrimary,
          ),
          icon: Icon(Icons.expand_more, color: context.appTextSecondary),
          items: groups.map((g) {
            return DropdownMenuItem(
              value: g.id,
              child: Text(
                '${g.name} (${g.tickers.length})',
              ),
            );
          }).toList(),
          onChanged: (id) {
            if (id == null) return;
            setState(() {
              _selectedGroupId = id;
              _isSearching = false;
              _searchController.clear();
              ref.read(searchProvider.notifier).clear();
            });
          },
        ),
      ),
    );
  }

  Widget _buildTickerList(WatchlistGroup group) {
    return ReorderableListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: group.tickers.length,
      onReorder: (oldIndex, newIndex) {
        ref
            .read(watchlistGroupProvider.notifier)
            .reorderTickers(group.id, oldIndex, newIndex);
      },
      proxyDecorator: (child, index, animation) {
        return Material(
          elevation: 2,
          color: context.appSurface,
          borderRadius: BorderRadius.circular(8),
          child: child,
        );
      },
      itemBuilder: (context, index) {
        final ticker = group.tickers[index];
        return _TickerRow(
          key: ValueKey(ticker),
          ticker: ticker,
          onDelete: () {
            ref
                .read(watchlistGroupProvider.notifier)
                .removeTicker(group.id, ticker);
          },
        );
      },
    );
  }

  Widget _buildAddHeader(WatchlistGroup group) {
    final tickerCount = group.tickers.length;
    final canAdd = group.canAddTicker;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '$tickerCount / ${WatchlistGroup.maxTickersPerGroup}',
          style: TextStyle(
            fontSize: 13,
            color: context.appTextHint,
          ),
        ),
        if (!_isSearching && canAdd)
          TextButton.icon(
            onPressed: () {
              setState(() => _isSearching = true);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _searchFocusNode.requestFocus();
              });
            },
            icon: Icon(Icons.add, size: 18, color: context.appAccent),
            label: Text(
              '종목 추가',
              style: TextStyle(
                fontSize: 14,
                color: context.appAccent,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSearchArea(WatchlistGroup group) {
    final searchState = ref.watch(searchProvider);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: context.appDivider, width: 0.5),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 검색 입력
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  style: TextStyle(
                    fontSize: 14,
                    color: context.appTextPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: '티커 또는 종목명 검색',
                    hintStyle: TextStyle(
                      fontSize: 14,
                      color: context.appTextHint,
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      size: 20,
                      color: context.appTextHint,
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: context.appBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: context.appBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: context.appAccent),
                    ),
                  ),
                  onChanged: (query) {
                    ref.read(searchProvider.notifier).search(query);
                  },
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () {
                  _searchFocusNode.unfocus();
                  setState(() => _isSearching = false);
                  _searchController.clear();
                  ref.read(searchProvider.notifier).clear();
                },
                child: Text(
                  '취소',
                  style: TextStyle(
                    fontSize: 14,
                    color: context.appTextSecondary,
                  ),
                ),
              ),
            ],
          ),
          // 검색 결과
          if (searchState.isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: context.appAccent,
                ),
              ),
            )
          else if (searchState.results.isNotEmpty)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: searchState.results.length,
                itemBuilder: (context, index) {
                  final result = searchState.results[index];
                  final alreadyAdded = group.containsTicker(result.symbol);
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: TickerLogo(
                      ticker: result.symbol,
                      size: 32,
                      borderRadius: 6,
                    ),
                    title: Text(
                      result.symbol,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: context.appTextPrimary,
                      ),
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
                    trailing: alreadyAdded
                        ? Icon(
                            Icons.check,
                            size: 18,
                            color: context.appAccent,
                          )
                        : !group.canAddTicker
                            ? null
                            : IconButton(
                                icon: Icon(
                                  Icons.add_circle_outline,
                                  size: 20,
                                  color: context.appAccent,
                                ),
                                onPressed: () async {
                                  await ref
                                      .read(watchlistGroupProvider.notifier)
                                      .addTicker(group.id, result.symbol);
                                },
                              ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// 단일 티커 행 (드래그 핸들 + 로고 + 이름 + 삭제)
class _TickerRow extends ConsumerWidget {
  final String ticker;
  final VoidCallback onDelete;

  const _TickerRow({
    super.key,
    required this.ticker,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // watchlist에서 종목 정보 가져오기
    final watchlistState = ref.watch(watchlistProvider);
    final item = watchlistState.items
        .where((i) => i.ticker == ticker)
        .firstOrNull;
    final exchange = item?.exchange ?? '';
    final type = item?.type ?? '';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: context.appDivider, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          // 드래그 핸들
          Icon(
            Icons.drag_handle,
            size: 20,
            color: context.appTextHint,
          ),
          const SizedBox(width: 8),
          // 로고
          TickerLogo(
            ticker: ticker,
            size: 32,
            borderRadius: 6,
          ),
          const SizedBox(width: 10),
          // 티커 + 거래소 배지
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ticker,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: context.appTextPrimary,
                  ),
                ),
                if (exchange.isNotEmpty || type.isNotEmpty)
                  Text(
                    formatBadge(exchange, type),
                    style: TextStyle(
                      fontSize: 12,
                      color: context.appTextSecondary,
                    ),
                  ),
              ],
            ),
          ),
          // 삭제 버튼
          IconButton(
            icon: const Icon(
              Icons.remove_circle_outline,
              size: 20,
              color: AppColors.red500,
            ),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
