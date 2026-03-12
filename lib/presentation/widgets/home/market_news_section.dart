import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/services/api/finnhub_service.dart';
import '../../providers/market_news_providers.dart';

/// 홈 화면 시장 뉴스 섹션
///
/// Finnhub general-news를 카드 형태로 표시.
/// 초기 5건 + "더보기"로 전체 20건까지 확장.
class MarketNewsSection extends ConsumerStatefulWidget {
  const MarketNewsSection({super.key});

  @override
  ConsumerState<MarketNewsSection> createState() => _MarketNewsSectionState();
}

class _MarketNewsSectionState extends ConsumerState<MarketNewsSection> {
  bool _showAllNews = false;

  /// 제목 끝의 "- Reuters", "- CNBC" 등 소스명 제거
  static final RegExp _trailingSourcePattern =
      RegExp(r'\s*[-–—]\s*(Reuters|CNBC|Bloomberg|AP|AFP)\s*$');

  /// 한국어 번역에서도 "- 로이터", "- CNBC" 등 제거
  static final RegExp _trailingSourceKoPattern =
      RegExp(r'\s*[-–—]\s*(로이터|Reuters|CNBC|Bloomberg|AP|AFP)[.]*\s*$');

  String _cleanTitle(String title) {
    return title
        .replaceAll(_trailingSourcePattern, '')
        .replaceAll(_trailingSourceKoPattern, '')
        .trim();
  }

  @override
  Widget build(BuildContext context) {
    final newsState = ref.watch(marketNewsProvider);

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Row(
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
                        '더보기 (${allNews.length}건) >',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.appTextSecondary,
                        ),
                      ),
                    ),
                  ),
                if (!newsState.isLoading && _showAllNews)
                  GestureDetector(
                    onTap: () => setState(() => _showAllNews = false),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        '접기',
                        style: TextStyle(
                          fontSize: 12,
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
                      padding: const EdgeInsets.only(left: 10),
                      child: Icon(
                        Icons.refresh,
                        size: 18,
                        color: context.appTextSecondary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          // 로딩 상태
          if (newsState.isLoading && allNews.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
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
              (i) => _buildNewsItem(
                displayNews[i],
                isLast: i == displayNews.length - 1,
              ),
            ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildNewsItem(NewsItem news, {bool isLast = false}) {
    final timeAgo = _formatTimeAgo(news.publishedAt);
    final publisherColor = _getPublisherColor(news.publisher);
    final cleanedTitle = _cleanTitle(news.displayTitle);
    final isMobile = MediaQuery.sizeOf(context).width < 600;
    final titleFontSize = isMobile ? 13.0 : 13.5;

    return GestureDetector(
      onTap: () async {
        final uri = Uri.parse(news.link);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: isLast
            ? null
            : BoxDecoration(
                border: Border(bottom: BorderSide(color: context.appDivider)),
              ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 뱃지 + 시간 + 제목 한 줄 흐름
            Text.rich(
              TextSpan(
                children: [
                  // 소스 뱃지
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: publisherColor.withAlpha(30),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        news.publisher,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: publisherColor,
                          height: 1.0,
                        ),
                      ),
                    ),
                  ),
                  // 시간
                  TextSpan(
                    text: '$timeAgo  ',
                    style: TextStyle(
                      fontSize: 11,
                      color: context.appTextHint,
                      height: 1.5,
                    ),
                  ),
                  // 제목 + ↗ 아이콘
                  TextSpan(
                    text: cleanedTitle,
                    style: TextStyle(
                      fontSize: titleFontSize,
                      fontWeight: FontWeight.w500,
                      color: context.appTextPrimary,
                      height: 1.5,
                    ),
                  ),
                  TextSpan(
                    text: ' \u2197',
                    style: TextStyle(
                      fontSize: titleFontSize - 2,
                      color: context.appTextHint,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getPublisherColor(String publisher) {
    switch (publisher) {
      case 'Reuters':
        return const Color(0xFFFF8800);
      case 'CNBC':
        return const Color(0xFF2980B9);
      case 'Bloomberg':
        return const Color(0xFF7B2D8E);
      default:
        return AppColors.gray500;
    }
  }

  String _formatTimeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    return DateFormat('MM/dd').format(date);
  }
}
