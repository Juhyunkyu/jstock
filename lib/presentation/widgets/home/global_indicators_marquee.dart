import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../providers/global_indicators_provider.dart';

/// 글로벌 지표 마키 (전광판) — 수평 무한 스크롤 티커
///
/// WTI, 금, BTC, 10Y, VIX를 좌→우 연속 스크롤로 표시.
/// 터치/호버 시 일시정지, 탭 시 개별 지표 상세 BottomSheet 표시.
class GlobalIndicatorsMarquee extends ConsumerStatefulWidget {
  const GlobalIndicatorsMarquee({super.key});

  @override
  ConsumerState<GlobalIndicatorsMarquee> createState() =>
      _GlobalIndicatorsMarqueeState();
}

class _GlobalIndicatorsMarqueeState
    extends ConsumerState<GlobalIndicatorsMarquee> {
  final ScrollController _scrollController = ScrollController();
  bool _paused = false;
  bool _scrolling = false;
  static const double _speed = 40.0; // px/s

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _startAutoScroll() async {
    if (_scrolling) return;
    _scrolling = true;

    while (mounted && _scrollController.hasClients) {
      if (!_paused) {
        final maxScroll = _scrollController.position.maxScrollExtent;
        final currentScroll = _scrollController.offset;
        // 반절 넘으면 리셋 (무한 루프)
        if (currentScroll >= maxScroll * 0.5) {
          _scrollController.jumpTo(0);
        }
        // 16ms 간격 (≈60fps) 으로 스크롤
        final delta = _speed * 0.016;
        _scrollController.jumpTo(_scrollController.offset + delta);
      }
      await Future.delayed(const Duration(milliseconds: 16));
    }
    _scrolling = false;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(globalIndicatorsProvider);

    if (state.isLoading && state.indicators.isEmpty) {
      return _buildShimmer(context);
    }

    if (state.indicators.isEmpty) {
      return const SizedBox.shrink();
    }

    final items = _buildIndicatorItems(context, state.indicators);

    // 첫 빌드 후 스크롤 시작
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrolling) _startAutoScroll();
    });

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 32,
        decoration: BoxDecoration(
          color: context.appSurface,
          borderRadius: BorderRadius.circular(8),
        ),
        clipBehavior: Clip.hardEdge,
        child: Listener(
          onPointerDown: (_) => _paused = true,
          onPointerUp: (_) => _paused = false,
          onPointerCancel: (_) => _paused = false,
          child: MouseRegion(
            onEnter: (_) => _paused = true,
            onExit: (_) => _paused = false,
            child: SingleChildScrollView(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 3세트 반복 (무한 루프용)
                  ...items, ...items, ...items,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 개별 지표 아이템 위젯 목록 생성
  List<Widget> _buildIndicatorItems(
    BuildContext context,
    List<GlobalIndicator> indicators,
  ) {
    final items = <Widget>[];

    for (int i = 0; i < indicators.length; i++) {
      final ind = indicators[i];
      items.add(_MarqueeItem(
        indicator: ind,
        onTap: () => _showIndicatorDetail(context, ind),
      ));

      // 구분점 (마지막 아이템 뒤에도 추가 — 2세트 연결 시 자연스럽게)
      items.add(Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(
          '\u00B7',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: context.appTextHint,
          ),
        ),
      ));
    }

    return items;
  }

  /// 로딩 스켈레톤 shimmer
  Widget _buildShimmer(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 32,
        decoration: BoxDecoration(
          color: context.appSurface,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const _ShimmerBar(),
      ),
    );
  }
}

/// 마키 내 개별 지표 아이템
class _MarqueeItem extends StatelessWidget {
  final GlobalIndicator indicator;
  final VoidCallback onTap;

  const _MarqueeItem({
    required this.indicator,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final changeColor =
        indicator.isPositive ? AppColors.red500 : AppColors.blue500;
    final arrow = indicator.isPositive ? '\u25B2' : '\u25BC';

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 라벨
            Text(
              indicator.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: context.appTextSecondary,
              ),
            ),
            const SizedBox(width: 6),
            // 가격
            Text(
              indicator.formattedPrice,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: context.appTextPrimary,
              ),
            ),
            const SizedBox(width: 4),
            // 변동률
            Text(
              '$arrow${indicator.formattedChange}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: changeColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 로딩용 shimmer 바 (애니메이션)
class _ShimmerBar extends StatefulWidget {
  const _ShimmerBar();

  @override
  State<_ShimmerBar> createState() => _ShimmerBarState();
}

class _ShimmerBarState extends State<_ShimmerBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _shimmerController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ShimmerPainter(
        progress: _shimmerController.value,
        baseColor: context.appDivider,
        highlightColor: context.appIconBg,
      ),
      size: Size.infinite,
    );
  }
}

/// Shimmer 효과 페인터
class _ShimmerPainter extends CustomPainter {
  final double progress;
  final Color baseColor;
  final Color highlightColor;

  _ShimmerPainter({
    required this.progress,
    required this.baseColor,
    required this.highlightColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    final shimmerWidth = size.width * 0.4;
    final dx = -shimmerWidth + (size.width + shimmerWidth * 2) * progress;

    paint.shader = LinearGradient(
      colors: [baseColor, highlightColor, baseColor],
      stops: const [0.0, 0.5, 1.0],
    ).createShader(Rect.fromLTWH(dx, 0, shimmerWidth, size.height));

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(8),
    );
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(_ShimmerPainter oldDelegate) =>
      progress != oldDelegate.progress;
}

// =====================================================================
// 지표별 상세 BottomSheet
// (global_indicators_panel.dart의 _showIndicatorDetail과 동일 데이터)
// Phase 5에서 공통 함수로 추출하여 중복 제거 예정
// =====================================================================

class _IndicatorDetail {
  final String icon;
  final String name;
  final String summary;
  final List<({String range, String desc, Color color})>? thresholds;

  const _IndicatorDetail({
    required this.icon,
    required this.name,
    required this.summary,
    this.thresholds,
  });
}

final _indicatorDetails = <String, _IndicatorDetail>{
  'DCOILWTICO': const _IndicatorDetail(
    icon: '🛢️',
    name: 'WTI 원유',
    summary: '서부 텍사스산 원유 선물 가격. 글로벌 원유 벤치마크로, 상승 시 인플레이션 압력과 운송비 증가로 기업 실적 악화 우려.',
    thresholds: [
      (range: '\$40 이하', desc: '수요 급감 신호. 에너지주 타격, 소비자에겐 호재', color: Color(0xFF22C55E)),
      (range: '\$60~80', desc: '균형 구간. 산유국·소비국 모두 수용 가능', color: Color(0xFF3B82F6)),
      (range: '\$80~100', desc: '인플레이션 압력 상승. 운송·제조업 마진 압박, 긴축 우려', color: Color(0xFFEAB308)),
      (range: '\$100 이상', desc: '경기 침체 촉발 가능. 스태그플레이션 리스크', color: Color(0xFFEF4444)),
    ],
  ),
  'XAU/USD': const _IndicatorDetail(
    icon: '🥇',
    name: '금 (XAU)',
    summary: '대표적 안전자산. 경기 불안·인플레이션·달러 약세 시 상승. 금 급등은 시장 불안 신호. 장기 우상향 자산으로 절대 가격보다 변동률이 중요.',
  ),
  'BTC/USD': const _IndicatorDetail(
    icon: '₿',
    name: '비트코인 (BTC)',
    summary: '디지털 자산·위험자산. 유동성 풍부할 때 상승, 금리 인상기엔 하락 경향. 시장 위험선호도 바로미터. 장기 우상향 자산으로 절대 가격보다 변동률이 중요.',
  ),
  'DGS10': const _IndicatorDetail(
    icon: '📈',
    name: '미국 10년 국채 금리',
    summary: '시장 금리의 기준. 상승 시 주식 밸류에이션 하락 압력, 하락 시 경기 둔화 신호.',
    thresholds: [
      (range: '2% 이하', desc: '초완화. 주식·부동산에 강한 호재', color: Color(0xFF22C55E)),
      (range: '3~3.75%', desc: '중립 구간. 경기와 물가의 균형점', color: Color(0xFF3B82F6)),
      (range: '3.75~4.25%', desc: '긴축 초기. 성장주·기술주 밸류에이션 압박', color: Color(0xFFEAB308)),
      (range: '4.25~5%', desc: '긴축. 모기지·기업대출 부담 심화', color: Color(0xFFF97316)),
      (range: '5% 이상', desc: '강긴축. 경기 침체 리스크 급증', color: Color(0xFFEF4444)),
    ],
  ),
  'VIXCLS': const _IndicatorDetail(
    icon: '⚡',
    name: 'VIX (변동성 지수)',
    summary: 'S&P 500 옵션 기반 변동성 지수. 시장의 향후 30일 변동성 기대치를 반영.',
    thresholds: [
      (range: '12 이하', desc: '극도의 안정. 역설적으로 급락 직전 나타나기도', color: Color(0xFF22C55E)),
      (range: '16~20', desc: '장기 평균. 정상적 시장 불확실성', color: Color(0xFF3B82F6)),
      (range: '20~25', desc: '불안 확대. 헤지 수요 증가, 단기 조정 가능', color: Color(0xFFEAB308)),
      (range: '25~30', desc: '공포. 급매도 동반 가능, 반등 기회도 존재', color: Color(0xFFF97316)),
      (range: '40 이상', desc: '금융 위기 수준 (2008년 80, 2020년 82)', color: Color(0xFFEF4444)),
    ],
  ),
};

/// 개별 지표 상세 BottomSheet
void _showIndicatorDetail(BuildContext context, GlobalIndicator indicator) {
  final detail = _indicatorDetails[indicator.symbol];
  if (detail == null) return;

  showModalBottomSheet(
    context: context,
    useRootNavigator: true,
    backgroundColor: context.appCardBackground,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Row(
            children: [
              Text(
                detail.name,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: context.appTextPrimary,
                ),
              ),
              const Spacer(),
              Text(
                indicator.formattedPrice,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: context.appTextPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            detail.summary,
            style: TextStyle(
              fontSize: 12.5,
              color: context.appTextSecondary,
              height: 1.4,
            ),
          ),
          if (detail.thresholds != null) ...[
            const SizedBox(height: 14),
            Text(
              '구간별 해석',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.appTextPrimary,
              ),
            ),
            const SizedBox(height: 8),
            for (final t in detail.thresholds!) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(top: 4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: t.color,
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 80,
                      child: Text(
                        t.range,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: context.appTextPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        t.desc,
                        style: TextStyle(
                          fontSize: 12,
                          color: context.appTextSecondary,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    ),
  );
}
