import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import 'watchlist_ticker_editor.dart';
import 'watchlist_group_editor.dart';

/// 관심종목 설정 BottomSheet (종목편집 / 그룹편집 2탭)
class WatchlistSettingsSheet extends ConsumerStatefulWidget {
  const WatchlistSettingsSheet({super.key});

  @override
  ConsumerState<WatchlistSettingsSheet> createState() =>
      _WatchlistSettingsSheetState();
}

class _WatchlistSettingsSheetState extends ConsumerState<WatchlistSettingsSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // 핸들 바
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: context.appBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // 탭 바
          TabBar(
            controller: _tabController,
            indicatorColor: context.appAccent,
            indicatorWeight: 2,
            labelColor: context.appAccent,
            unselectedLabelColor: context.appTextSecondary,
            labelStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w400,
            ),
            tabs: const [
              Tab(text: '종목편집'),
              Tab(text: '그룹편집'),
            ],
          ),
          // 탭 콘텐츠
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                WatchlistTickerEditor(),
                WatchlistGroupEditor(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
