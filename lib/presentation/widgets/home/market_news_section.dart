import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/services/api/finnhub_service.dart';
import '../../providers/market_news_providers.dart';

/// 홈 화면 시장 뉴스 섹션
///
/// Finnhub general-news를 표시하며, 탭하면 summary를 펼칩니다.
/// 초기 5건 표시 + "더보기"로 전체 10건까지 확장.
class MarketNewsSection extends ConsumerStatefulWidget {
  const MarketNewsSection({super.key});

  @override
  ConsumerState<MarketNewsSection> createState() => _MarketNewsSectionState();
}

class _MarketNewsSectionState extends ConsumerState<MarketNewsSection> {
  bool _showAllNews = false;
  final Set<int> _expandedIndices = {};

  @override
  Widget build(BuildContext context) {
    final newsState = ref.watch(marketNewsProvider);

    // 빈 상태: 섹션 자체를 숨김
    if (!newsState.isLoading && newsState.news.isEmpty) {
      return const SizedBox.shrink();
    }

    final allNews = newsState.news;
    final displayNews = _showAllNews ? allNews : allNews.take(5).toList();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: context.appCardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.appBorder),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Row(
            children: [
              Text(
                '시장 뉴스',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: context.appTextPrimary,
                ),
              ),
              if (newsState.isLoading) ...[
                const SizedBox(width: 8),
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ],
              const Spacer(),
              if (!newsState.isLoading && allNews.length > 5 && !_showAllNews)
                GestureDetector(
                  onTap: () => setState(() => _showAllNews = true),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      '더보기 >',
                      style: TextStyle(
                        fontSize: 13,
                        color: context.appTextSecondary,
                      ),
                    ),
                  ),
                ),
              if (!newsState.isLoading)
                GestureDetector(
                  onTap: () {
                    ref.read(marketNewsProvider.notifier).refresh();
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Icon(
                      Icons.refresh,
                      size: 18,
                      color: context.appTextSecondary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          // 컨텐츠
          if (newsState.isLoading && allNews.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  '뉴스를 불러오는 중...',
                  style: TextStyle(
                    color: context.appTextHint,
                    fontSize: 13,
                  ),
                ),
              ),
            )
          else
            ...List.generate(
              displayNews.length,
              (i) => _buildNewsItem(displayNews[i], i),
            ),
        ],
      ),
    );
  }

  Widget _buildNewsItem(NewsItem news, int index) {
    final timeAgo = _formatTimeAgo(news.publishedAt);
    final isExpanded = _expandedIndices.contains(index);
    final thumbnailUrl = news.thumbnail != null
        ? 'https://wsrv.nl/?url=${Uri.encodeComponent(news.thumbnail!)}&w=144&h=144&fit=cover'
        : null;

    return GestureDetector(
      onTap: () {
        setState(() {
          if (isExpanded) {
            _expandedIndices.remove(index);
          } else {
            _expandedIndices.add(index);
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: context.appDivider)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 기본 뉴스 행
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (thumbnailUrl != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.network(
                      thumbnailUrl,
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        news.displayTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: context.appTextPrimary,
                          height: 1.4,
                        ),
                      ),
                      if (news.translatedTitle != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          news.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: context.appTextHint,
                            height: 1.3,
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Text(
                        '${news.publisher} \u2022 $timeAgo',
                        style: TextStyle(
                          fontSize: 11,
                          color: context.appTextHint,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // 펼친 상태: summary + 원문 보기
            if (isExpanded && news.summary != null && news.summary!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                news.summary!,
                style: TextStyle(
                  fontSize: 13,
                  color: context.appTextSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: () async {
                    final uri = Uri.parse(news.link);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                  child: Text(
                    '원문 보기 \u2192',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: context.appAccent,
                    ),
                  ),
                ),
              ),
            ],
            // summary가 없는 경우에도 펼치면 원문 보기 링크 제공
            if (isExpanded && (news.summary == null || news.summary!.isEmpty)) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: () async {
                    final uri = Uri.parse(news.link);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                  child: Text(
                    '원문 보기 \u2192',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: context.appAccent,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatTimeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    return DateFormat('MM/dd').format(date);
  }
}
