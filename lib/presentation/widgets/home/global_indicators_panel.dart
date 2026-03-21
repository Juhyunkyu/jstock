import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../providers/global_indicators_provider.dart';

/// 데스크톱용 글로벌 지표 독립 카드
class GlobalIndicatorsCard extends ConsumerWidget {
  const GlobalIndicatorsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(globalIndicatorsProvider);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final fs = 0.92 + ((screenWidth - 320) / 1080).clamp(0.0, 1.0) * 0.43;

    return Container(
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: context.appCardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.appBorder),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(14 * fs, 12 * fs, 14 * fs, 10 * fs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '글로벌 지표',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: context.appTextPrimary,
                  ),
                ),
                SizedBox(width: 6 * fs),
                GestureDetector(
                  onTap: () => _showIndicatorInfo(context),
                  child: Icon(
                    Icons.info_outline_rounded,
                    size: 14 * fs,
                    color: context.appTextHint,
                  ),
                ),
              ],
            ),
            SizedBox(height: 6 * fs),
            if (state.isLoading && state.indicators.isEmpty)
              Expanded(
                child: Center(
                  child: SizedBox(
                    width: 20 * fs,
                    height: 20 * fs,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: context.appTextHint,
                    ),
                  ),
                ),
              )
            else if (state.indicators.isEmpty)
              Expanded(
                child: Center(
                  child: Text(
                    '지표 없음',
                    style: TextStyle(
                      fontSize: 11 * fs,
                      color: context.appTextHint,
                    ),
                  ),
                ),
              )
            else
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    for (int i = 0; i < state.indicators.length; i++) ...[
                      _IndicatorRow(indicator: state.indicators[i], fs: fs),
                      if (i < state.indicators.length - 1)
                        Divider(
                          height: 1,
                          thickness: 0.5,
                          color: context.appDivider,
                        ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 지표별 상세 설명 데이터
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

final _indicatorDetails = {
  'DCOILWTICO': _IndicatorDetail(
    icon: '🛢️',
    name: 'WTI 원유',
    summary: '서부 텍사스산 원유 선물 가격. 글로벌 원유 벤치마크로, 상승 시 인플레이션 압력과 운송비 증가로 기업 실적 악화 우려.',
    thresholds: [
      (range: '\$40 이하', desc: '수요 급감 신호. 에너지주 타격, 소비자에겐 호재', color: const Color(0xFF22C55E)),
      (range: '\$60~80', desc: '균형 구간. 산유국·소비국 모두 수용 가능', color: const Color(0xFF3B82F6)),
      (range: '\$80~100', desc: '인플레이션 압력 상승. 운송·제조업 마진 압박, 긴축 우려', color: const Color(0xFFEAB308)),
      (range: '\$100 이상', desc: '경기 침체 촉발 가능. 스태그플레이션 리스크', color: const Color(0xFFEF4444)),
    ],
  ),
  'XAU/USD': _IndicatorDetail(
    icon: '🥇',
    name: '금 (XAU)',
    summary: '대표적 안전자산. 경기 불안·인플레이션·달러 약세 시 상승. 금 급등은 시장 불안 신호. 장기 우상향 자산으로 절대 가격보다 변동률이 중요.',
  ),
  'BTC/USD': _IndicatorDetail(
    icon: '₿',
    name: '비트코인 (BTC)',
    summary: '디지털 자산·위험자산. 유동성 풍부할 때 상승, 금리 인상기엔 하락 경향. 시장 위험선호도 바로미터. 장기 우상향 자산으로 절대 가격보다 변동률이 중요.',
  ),
  'DGS10': _IndicatorDetail(
    icon: '📈',
    name: '미국 10년 국채 금리',
    summary: '시장 금리의 기준. 상승 시 주식 밸류에이션 하락 압력, 하락 시 경기 둔화 신호.',
    thresholds: [
      (range: '2% 이하', desc: '초완화. 주식·부동산에 강한 호재', color: const Color(0xFF22C55E)),
      (range: '3~3.75%', desc: '중립 구간. 경기와 물가의 균형점', color: const Color(0xFF3B82F6)),
      (range: '3.75~4.25%', desc: '긴축 초기. 성장주·기술주 밸류에이션 압박', color: const Color(0xFFEAB308)),
      (range: '4.25~5%', desc: '긴축. 모기지·기업대출 부담 심화', color: const Color(0xFFF97316)),
      (range: '5% 이상', desc: '강긴축. 경기 침체 리스크 급증', color: const Color(0xFFEF4444)),
    ],
  ),
  'VIXCLS': _IndicatorDetail(
    icon: '⚡',
    name: 'VIX (변동성 지수)',
    summary: 'S&P 500 옵션 기반 변동성 지수. 시장의 향후 30일 변동성 기대치를 반영.',
    thresholds: [
      (range: '12 이하', desc: '극도의 안정. 역설적으로 급락 직전 나타나기도', color: const Color(0xFF22C55E)),
      (range: '16~20', desc: '장기 평균. 정상적 시장 불확실성', color: const Color(0xFF3B82F6)),
      (range: '20~25', desc: '불안 확대. 헤지 수요 증가, 단기 조정 가능', color: const Color(0xFFEAB308)),
      (range: '25~30', desc: '공포. 급매도 동반 가능, 반등 기회도 존재', color: const Color(0xFFF97316)),
      (range: '40 이상', desc: '금융 위기 수준 (2008년 80, 2020년 82)', color: const Color(0xFFEF4444)),
    ],
  ),
};

/// 전체 지표 요약 BottomSheet (헤더 ⓘ)
void _showIndicatorInfo(BuildContext context) {
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
          Text(
            '글로벌 지표 설명',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: context.appTextPrimary,
            ),
          ),
          const SizedBox(height: 16),
          for (final detail in _indicatorDetails.values) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(detail.icon, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        detail.name,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: context.appTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        detail.summary,
                        style: TextStyle(
                          fontSize: 12,
                          color: context.appTextSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    ),
  );
}

/// 개별 지표 상세 BottomSheet (행별 ⓘ)
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

/// Fear & Greed 카드 오른쪽에 배치되는 글로벌 지표 패널 (레거시)
/// WTI 유가, 금, 비트코인, 미국 10년 금리
class GlobalIndicatorsPanel extends ConsumerWidget {
  const GlobalIndicatorsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(globalIndicatorsProvider);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final fs = 0.92 + ((screenWidth - 320) / 1080).clamp(0.0, 1.0) * 0.43;

    if (state.isLoading && state.indicators.isEmpty) {
      return Center(
        child: SizedBox(
          width: 20 * fs,
          height: 20 * fs,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            color: context.appTextHint,
          ),
        ),
      );
    }

    if (state.indicators.isEmpty) {
      return Center(
        child: Text(
          '지표 없음',
          style: TextStyle(
            fontSize: 11 * fs,
            color: context.appTextHint,
          ),
        ),
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < state.indicators.length; i++) ...[
          _IndicatorRow(indicator: state.indicators[i], fs: fs),
          if (i < state.indicators.length - 1)
            Divider(
              height: 12 * fs,
              thickness: 0.5,
              color: context.appDivider,
            ),
        ],
      ],
    );
  }
}

/// 모바일용 2x2 그리드 글로벌 지표
class GlobalIndicatorsGrid extends ConsumerWidget {
  const GlobalIndicatorsGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(globalIndicatorsProvider);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final fs = 0.92 + ((screenWidth - 320) / 1080).clamp(0.0, 1.0) * 0.43;

    if (state.isLoading && state.indicators.isEmpty) {
      return SizedBox(
        height: 60,
        child: Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: context.appTextHint,
            ),
          ),
        ),
      );
    }

    if (state.indicators.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: EdgeInsets.all(10 * fs),
      decoration: BoxDecoration(
        color: context.appCardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.appBorder),
      ),
      child: Row(
        children: [
          for (int i = 0; i < state.indicators.length; i++) ...[
            Expanded(
              child: _CompactIndicatorTile(
                indicator: state.indicators[i],
                fs: fs,
              ),
            ),
            if (i < state.indicators.length - 1)
              SizedBox(
                height: 32 * fs,
                child: VerticalDivider(
                  width: 1,
                  thickness: 0.5,
                  color: context.appDivider,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// 심볼 → Material Icon 매핑
IconData _iconForSymbol(String symbol) {
  switch (symbol) {
    case 'DCOILWTICO': return Icons.oil_barrel_outlined;
    case 'XAU/USD':    return Icons.hexagon_outlined;
    case 'BTC/USD':    return Icons.currency_bitcoin;
    case 'DGS10':      return Icons.show_chart_rounded;
    case 'VIXCLS':     return Icons.electric_bolt_outlined;
    default:           return Icons.circle_outlined;
  }
}

/// 데스크톱 세로 리스트 행 (아이콘 + 라벨 + 가격 + 변동률)
class _IndicatorRow extends StatelessWidget {
  final GlobalIndicator indicator;
  final double fs;

  const _IndicatorRow({required this.indicator, required this.fs});

  @override
  Widget build(BuildContext context) {
    final changeColor = indicator.isPositive
        ? AppColors.red500
        : AppColors.blue500;

    return GestureDetector(
      onTap: () => _showIndicatorDetail(context, indicator),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 2 * fs),
        child: Row(
          children: [
            SizedBox(
              width: 20 * fs,
              child: Icon(
                _iconForSymbol(indicator.symbol),
                size: 16 * fs,
                color: context.appTextHint,
              ),
            ),
            SizedBox(width: 6 * fs),
            Text(
              indicator.label,
              style: TextStyle(
                fontSize: 12 * fs,
                fontWeight: FontWeight.w500,
                color: context.appTextSecondary,
              ),
            ),
            SizedBox(width: 4 * fs),
            const Spacer(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  indicator.formattedPrice,
                  style: TextStyle(
                    fontSize: 12.5 * fs,
                    fontWeight: FontWeight.w600,
                    color: context.appTextPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  '${indicator.isPositive ? "▲" : "▼"} ${indicator.formattedChange}',
                  style: TextStyle(
                    fontSize: 10 * fs,
                    fontWeight: FontWeight.w500,
                    color: changeColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 모바일 컴팩트 타일 (세로 배치)
class _CompactIndicatorTile extends StatelessWidget {
  final GlobalIndicator indicator;
  final double fs;

  const _CompactIndicatorTile({required this.indicator, required this.fs});

  @override
  Widget build(BuildContext context) {
    final changeColor = indicator.isPositive
        ? AppColors.red500
        : AppColors.blue500;

    return GestureDetector(
      onTap: () => _showIndicatorDetail(context, indicator),
      behavior: HitTestBehavior.opaque,
      child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _iconForSymbol(indicator.symbol),
              size: 12 * fs,
              color: context.appTextHint,
            ),
            SizedBox(width: 3 * fs),
            Text(
              indicator.label,
              style: TextStyle(
                fontSize: 10 * fs,
                fontWeight: FontWeight.w500,
                color: context.appTextHint,
              ),
            ),
          ],
        ),
        SizedBox(height: 2 * fs),
        Text(
          indicator.formattedPrice,
          style: TextStyle(
            fontSize: 11 * fs,
            fontWeight: FontWeight.w600,
            color: context.appTextPrimary,
            letterSpacing: -0.3,
          ),
        ),
        Text(
          '${indicator.isPositive ? "▲" : "▼"}${indicator.formattedChange}',
          style: TextStyle(
            fontSize: 9 * fs,
            fontWeight: FontWeight.w500,
            color: changeColor,
          ),
        ),
      ],
    ),
    );
  }
}
