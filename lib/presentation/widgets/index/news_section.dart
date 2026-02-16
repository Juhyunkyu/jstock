import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/services/api/finnhub_service.dart';

/// 최신 뉴스 섹션 (더보기 지원)
class NewsSection extends StatefulWidget {
  final List<NewsItem> news;
  final bool isLoading;
  final String symbol;

  const NewsSection({
    super.key,
    required this.news,
    required this.isLoading,
    required this.symbol,
  });

  @override
  State<NewsSection> createState() => _NewsSectionState();
}

class _NewsSectionState extends State<NewsSection> {
  bool _showAllNews = false;

  @override
  Widget build(BuildContext context) {
    final displayNews = _showAllNews ? widget.news : widget.news.take(3).toList();

    return Container(
      color: context.appSurface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('최신 뉴스', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: context.appTextPrimary)),
              if (widget.isLoading) ...[
                const SizedBox(width: 8),
                const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
              ],
              const Spacer(),
              if (!widget.isLoading && widget.news.length > 3 && !_showAllNews)
                GestureDetector(
                  onTap: () => setState(() => _showAllNews = true),
                  child: Text('더보기 >', style: TextStyle(fontSize: 13, color: context.appTextSecondary)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (widget.isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(child: Text('뉴스를 번역하는 중...', style: TextStyle(color: context.appTextHint, fontSize: 13))),
            )
          else if (widget.news.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(child: Text('뉴스가 없습니다', style: TextStyle(color: context.appTextHint, fontSize: 13))),
            )
          else
            ...List.generate(displayNews.length, (i) => _buildNewsItem(displayNews[i])),
        ],
      ),
    );
  }

  Widget _buildNewsItem(NewsItem news) {
    final timeAgo = _formatTimeAgo(news.publishedAt);

    return GestureDetector(
      onTap: () async {
        final uri = Uri.parse(news.link);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: context.appDivider)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (news.thumbnail != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.network(
                  news.thumbnail!,
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
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: context.appTextPrimary, height: 1.4),
                  ),
                  if (news.translatedTitle != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      news.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: context.appTextHint, height: 1.3),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    '${news.publisher} • $timeAgo',
                    style: TextStyle(fontSize: 11, color: context.appTextHint),
                  ),
                ],
              ),
            ),
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
