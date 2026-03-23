import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/financial_data.dart';

/// 핵심 투자 지표 카드 (섹션 2)
///
/// Finnhub /stock/metric 데이터를 기반으로 PER, PBR, ROE, 배당률,
/// 부채비율, 영업이익률을 프로그레스 바 + 색상 판정으로 시각화한다.
/// (i) 아이콘 탭 시 한글 설명 바텀시트를 표시한다.
class FinancialMetricsCard extends StatelessWidget {
  final FinancialMetrics metrics;

  const FinancialMetricsCard({super.key, required this.metrics});

  @override
  Widget build(BuildContext context) {
    final items = _buildMetricItems();

    return Container(
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.appBorder.withValues(alpha: 0.5)),
        boxShadow: context.appCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 타이틀
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Text(
              '핵심 투자 지표',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: context.appTextPrimary,
              ),
            ),
          ),
          Divider(height: 1, color: context.appDivider),
          // 지표 리스트
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              children: [
                for (int i = 0; i < items.length; i++) ...[
                  if (i > 0) const SizedBox(height: 14),
                  _MetricRow(item: items[i]),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<_MetricItem> _buildMetricItems() {
    return [
      _MetricItem(
        key: 'PER',
        label: 'PER',
        value: metrics.peRatio,
        formatValue: _formatDouble,
        maxRange: 50,
      ),
      _MetricItem(
        key: 'PBR',
        label: 'PBR',
        value: metrics.pbRatio,
        formatValue: _formatDouble,
        maxRange: 10,
      ),
      _MetricItem(
        key: 'ROE',
        label: 'ROE',
        value: metrics.roe,
        formatValue: _formatPercent,
        maxRange: 30,
      ),
      _MetricItem(
        key: 'DIVIDEND',
        label: '배당률',
        value: metrics.dividendYield,
        formatValue: _formatPercent,
        maxRange: 8,
      ),
      _MetricItem(
        key: 'DEBT',
        label: '부채비율',
        value: metrics.debtToEquity,
        formatValue: _formatPercent,
        maxRange: 300,
      ),
      _MetricItem(
        key: 'OPM',
        label: '영업이익률',
        value: metrics.operatingMargin,
        formatValue: _formatPercent,
        maxRange: 50,
      ),
    ];
  }

  static String _formatDouble(double? v) {
    if (v == null) return '-';
    return v.toStringAsFixed(1);
  }

  static String _formatPercent(double? v) {
    if (v == null) return '-';
    return '${v.toStringAsFixed(1)}%';
  }
}

// ─────────────────────────────────────────────────────────────
// 내부 모델
// ─────────────────────────────────────────────────────────────

class _MetricItem {
  final String key;
  final String label;
  final double? value;
  final String Function(double?) formatValue;
  final double maxRange;

  const _MetricItem({
    required this.key,
    required this.label,
    required this.value,
    required this.formatValue,
    required this.maxRange,
  });
}

// ─────────────────────────────────────────────────────────────
// 개별 지표 행
// ─────────────────────────────────────────────────────────────

class _MetricRow extends StatelessWidget {
  final _MetricItem item;

  const _MetricRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final color = _getColor(item.key, item.value, context);
    final ratingLabel = _getRatingLabel(item.key, item.value);
    final progress = _getProgress(item.value, item.maxRange);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 라벨 + 값 + 판정 텍스트 + (i)
        Row(
          children: [
            // 라벨
            SizedBox(
              width: 72,
              child: Text(
                item.label,
                style: TextStyle(
                  fontSize: 13,
                  color: context.appTextSecondary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // 값
            Text(
              item.formatValue(item.value),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: context.appTextPrimary,
              ),
            ),
            const SizedBox(width: 8),
            // 판정 라벨 + 도트
            if (item.value != null) ...[
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                ratingLabel,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ],
            const Spacer(),
            // (i) 아이콘
            GestureDetector(
              onTap: () => _showExplanationSheet(context, item.key),
              child: Icon(
                Icons.info_outline_rounded,
                size: 18,
                color: context.appTextHint,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        // 프로그레스 바
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: SizedBox(
            height: 6,
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: context.appDivider,
              valueColor: AlwaysStoppedAnimation<Color>(
                item.value != null ? color : context.appDivider,
              ),
            ),
          ),
        ),
      ],
    );
  }

  double _getProgress(double? value, double maxRange) {
    if (value == null) return 0;
    return (value.abs() / maxRange).clamp(0.0, 1.0);
  }
}

// ─────────────────────────────────────────────────────────────
// 색상 판정 (설계서 기준)
// ─────────────────────────────────────────────────────────────

Color _getColor(String metric, double? value, BuildContext context) {
  if (value == null) return context.appTextHint;

  switch (metric) {
    case 'PER':
      // 0~15 양호, 15~25 보통, 25+ 주의
      if (value <= 15) return AppColors.green500;
      if (value <= 25) return AppColors.amber500;
      return AppColors.red500;

    case 'PBR':
      // 0~1.5 양호, 1.5~3 보통, 3+ 주의
      if (value <= 1.5) return AppColors.green500;
      if (value <= 3) return AppColors.amber500;
      return AppColors.red500;

    case 'ROE':
      // 15%+ 양호, 5~15% 보통, 0~5% 주의
      if (value >= 15) return AppColors.green500;
      if (value >= 5) return AppColors.amber500;
      return AppColors.red500;

    case 'ROA':
      // 10%+ 양호, 3~10% 보통, 0~3% 주의
      if (value >= 10) return AppColors.green500;
      if (value >= 3) return AppColors.amber500;
      return AppColors.red500;

    case 'DIVIDEND':
      // 3%+ 양호, 1~3% 보통, 0~1% 주의
      if (value >= 3) return AppColors.green500;
      if (value >= 1) return AppColors.amber500;
      return AppColors.red500;

    case 'DEBT':
      // 0~100% 양호, 100~200% 보통, 200%+ 주의
      if (value <= 100) return AppColors.green500;
      if (value <= 200) return AppColors.amber500;
      return AppColors.red500;

    case 'OPM':
      // 20%+ 양호, 10~20% 보통, 0~10% 주의
      if (value >= 20) return AppColors.green500;
      if (value >= 10) return AppColors.amber500;
      return AppColors.red500;

    default:
      return context.appTextHint;
  }
}

// ─────────────────────────────────────────────────────────────
// 판정 라벨
// ─────────────────────────────────────────────────────────────

String _getRatingLabel(String metric, double? value) {
  if (value == null) return '-';

  switch (metric) {
    case 'PER':
      if (value <= 15) return '양호';
      if (value <= 25) return '보통';
      return '주의';

    case 'PBR':
      if (value <= 1.5) return '양호';
      if (value <= 3) return '보통';
      return '주의';

    case 'ROE':
      if (value >= 15) return '양호';
      if (value >= 5) return '보통';
      return '주의';

    case 'ROA':
      if (value >= 10) return '양호';
      if (value >= 3) return '보통';
      return '주의';

    case 'DIVIDEND':
      if (value >= 3) return '양호';
      if (value >= 1) return '보통';
      return '낮음';

    case 'DEBT':
      if (value <= 100) return '양호';
      if (value <= 200) return '보통';
      return '주의';

    case 'OPM':
      if (value >= 20) return '양호';
      if (value >= 10) return '보통';
      return '주의';

    default:
      return '-';
  }
}

// ─────────────────────────────────────────────────────────────
// (i) 설명 바텀시트
// ─────────────────────────────────────────────────────────────

void _showExplanationSheet(BuildContext context, String metricKey) {
  final data = _explanations[metricKey];
  if (data == null) return;

  showModalBottomSheet(
    context: context,
    backgroundColor: context.appSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 드래그 핸들
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: ctx.appDivider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // 제목
              Text(
                data['title']!,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: ctx.appTextPrimary,
                ),
              ),
              const SizedBox(height: 12),
              // 설명
              Text(
                data['description']!,
                style: TextStyle(
                  fontSize: 13,
                  color: ctx.appTextSecondary,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 16),
              // 판정 기준
              Text(
                '판정 기준',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: ctx.appTextPrimary,
                ),
              ),
              const SizedBox(height: 8),
              _buildRatingRow(ctx, AppColors.green500, data['good']!),
              const SizedBox(height: 6),
              _buildRatingRow(ctx, AppColors.amber500, data['normal']!),
              const SizedBox(height: 6),
              _buildRatingRow(ctx, AppColors.red500, data['bad']!),
            ],
          ),
        ),
      );
    },
  );
}

Widget _buildRatingRow(BuildContext context, Color dotColor, String text) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 8,
        height: 8,
        margin: const EdgeInsets.only(top: 5),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: dotColor,
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: context.appTextSecondary,
            height: 1.5,
          ),
        ),
      ),
    ],
  );
}

// ─────────────────────────────────────────────────────────────
// 지표별 한글 설명
// ─────────────────────────────────────────────────────────────

const Map<String, Map<String, String>> _explanations = {
  'PER': {
    'title': 'PER (주가수익비율)',
    'description':
        '주가를 주당순이익(EPS)으로 나눈 값입니다. '
        '현재 주가가 기업의 이익 대비 몇 배인지를 나타냅니다. '
        '낮을수록 저평가, 높을수록 성장 기대감이 반영된 수준입니다.',
    'good': '0~15: 저평가 가능성 (가치주 영역)',
    'normal': '15~25: 적정 수준',
    'bad': '25 이상: 고평가 (성장주는 예외)',
  },
  'PBR': {
    'title': 'PBR (주가순자산비율)',
    'description':
        '주가를 주당순자산으로 나눈 값입니다. '
        '기업의 순자산 대비 주가가 얼마나 높은지를 나타냅니다. '
        '1 미만이면 청산가치보다 주가가 낮다는 의미입니다.',
    'good': '0~1.5: 자산 대비 저평가',
    'normal': '1.5~3: 적정 수준',
    'bad': '3 이상: 자산 대비 고평가',
  },
  'ROE': {
    'title': 'ROE (자기자본이익률)',
    'description':
        '자기자본 대비 순이익의 비율입니다. '
        '주주가 투자한 자본으로 얼마나 효율적으로 이익을 창출하는지를 나타냅니다. '
        '워런 버핏이 가장 중시하는 지표 중 하나입니다.',
    'good': '15% 이상: 우수한 수익성',
    'normal': '5~15%: 보통 수준',
    'bad': '5% 미만: 수익성 개선 필요',
  },
  'DIVIDEND': {
    'title': '배당률 (배당수익률)',
    'description':
        '현재 주가 대비 연간 배당금의 비율입니다. '
        '주식을 보유하면 얻을 수 있는 현금 수익률을 나타냅니다. '
        '배당 성장 추세와 함께 확인하는 것이 중요합니다.',
    'good': '3% 이상: 높은 배당 (배당주 영역)',
    'normal': '1~3%: 보통 수준',
    'bad': '1% 미만: 낮은 배당 (성장 재투자 가능성)',
  },
  'DEBT': {
    'title': '부채비율 (D/E Ratio)',
    'description':
        '자기자본 대비 총부채의 비율입니다. '
        '기업이 빌린 돈이 자기 돈의 몇 배인지를 나타냅니다. '
        '너무 높으면 재무 위험이 커지지만, 적절한 부채는 성장에 도움이 됩니다.',
    'good': '0~100%: 안정적인 재무 구조',
    'normal': '100~200%: 보통 수준',
    'bad': '200% 이상: 재무 건전성 주의',
  },
  'OPM': {
    'title': '영업이익률 (Operating Margin)',
    'description':
        '매출 대비 영업이익의 비율입니다. '
        '본업에서 얼마나 효율적으로 수익을 창출하는지를 나타냅니다. '
        '높을수록 원가 관리와 사업 경쟁력이 우수합니다.',
    'good': '20% 이상: 우수한 수익성',
    'normal': '10~20%: 보통 수준',
    'bad': '10% 미만: 수익성 개선 필요',
  },
};
