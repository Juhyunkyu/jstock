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
    extends ConsumerState<GlobalIndicatorsMarquee>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  /// 1세트(전체 지표 1회)의 렌더링 너비 (layout 후 측정)
  double _singleSetWidth = 0;

  /// 현재 스크롤 오프셋 (px)
  double _offset = 0;

  /// 스크롤 속도 (px/s)
  static const double _speed = 40.0;

  /// 마지막 tick 시간
  Duration _lastElapsed = Duration.zero;

  /// 포인터가 눌린 상태인지 (일시정지용)
  bool _paused = false;

  final GlobalKey _singleSetKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController.unbounded(vsync: this)
      ..addListener(_tick);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 매 프레임 호출 — offset 갱신
  void _tick() {
    final now = _controller.lastElapsedDuration ?? Duration.zero;
    if (_lastElapsed == Duration.zero) {
      _lastElapsed = now;
      return;
    }
    final dt = (now - _lastElapsed).inMicroseconds / 1e6; // seconds
    _lastElapsed = now;

    if (_paused || _singleSetWidth <= 0) return;

    setState(() {
      _offset += _speed * dt;
      // 1세트 너비만큼 이동하면 0으로 리셋 → 무한 루프
      if (_offset >= _singleSetWidth) {
        _offset -= _singleSetWidth;
      }
    });
  }

  void _startScrolling() {
    _lastElapsed = Duration.zero;
    _controller.repeat(); // unbounded repeat triggers vsync ticks
  }

  void _pause() {
    _paused = true;
  }

  void _resume() {
    _paused = false;
  }

  /// 레이아웃 후 1세트 너비 측정
  void _measureSingleSet() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final renderBox =
          _singleSetKey.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox != null && renderBox.hasSize) {
        final newWidth = renderBox.size.width;
        if ((newWidth - _singleSetWidth).abs() > 1) {
          setState(() {
            _singleSetWidth = newWidth;
          });
          // 아직 애니메이션이 시작되지 않았으면 시작
          if (!_controller.isAnimating) {
            _startScrolling();
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(globalIndicatorsProvider);

    // 로딩 중 (데이터 0건) → 스켈레톤 shimmer
    if (state.isLoading && state.indicators.isEmpty) {
      return _buildShimmer(context);
    }

    // 에러 또는 빈 데이터 → 숨김
    if (state.indicators.isEmpty) {
      return const SizedBox.shrink();
    }

    // 지표 아이템 위젯 목록 생성
    final items = _buildIndicatorItems(context, state.indicators);

    // 너비 측정 트리거
    _measureSingleSet();

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
          onPointerDown: (_) => _pause(),
          onPointerUp: (_) => _resume(),
          onPointerCancel: (_) => _resume(),
          child: MouseRegion(
            onEnter: (_) => _pause(),
            onExit: (_) => _resume(),
            child: ClipRect(
              child: Transform.translate(
                offset: Offset(-_offset, 0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 1세트 (측정용 key 부착)
                    Row(
                      key: _singleSetKey,
                      mainAxisSize: MainAxisSize.min,
                      children: items,
                    ),
                    // 2세트 (무한 루프용 복제)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: items,
                    ),
                  ],
                ),
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
            // 이모지 아이콘
            Text(
              indicator.icon,
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(width: 4),
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
              Text(detail.icon, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
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
