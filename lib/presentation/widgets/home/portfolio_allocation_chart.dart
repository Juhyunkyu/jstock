import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/krw_formatter.dart';
import '../../../presentation/providers/portfolio_providers.dart';
import '../../../presentation/providers/settings_providers.dart';

/// 내 포트폴리오 차트 위젯
///
/// 일반 보유의 자산을 도넛 차트로 표시하고,
/// 하단에 총 시드 대비 손익을 보여줍니다.
/// 범례의 색상 네모를 탭하면 색상을 변경할 수 있습니다.
class PortfolioAllocationChart extends ConsumerStatefulWidget {
  /// 통합 포트폴리오 요약 데이터
  final UnifiedPortfolioSummary summary;

  /// 차트 크기
  final double size;

  const PortfolioAllocationChart({
    super.key,
    required this.summary,
    this.size = 130,
  });

  @override
  ConsumerState<PortfolioAllocationChart> createState() =>
      _PortfolioAllocationChartState();
}

class _PortfolioAllocationChartState extends ConsumerState<PortfolioAllocationChart> {
  /// 사용자 선택 색상 (null이면 기본값 사용)
  Color? _holdingColor;

  /// 현재 편집 중인 범례 인덱스 (0=일반 보유, null=없음)
  int? _editingIndex;

  /// 선택 가능한 색상 팔레트
  static const List<Color> _colorPalette = [
    Color(0xFF58A6FF), // blue
    Color(0xFF4ADE80), // green
    Color(0xFFF97316), // orange
    Color(0xFFA78BFA), // purple
    Color(0xFFF472B6), // pink
    Color(0xFF22D3EE), // cyan
    Color(0xFFFBBF24), // yellow
    Color(0xFFEF4444), // red
    Color(0xFF6366F1), // indigo
    Color(0xFF14B8A6), // teal
    Color(0xFF9CA3AF), // gray-400
    Color(0xFF6B7280), // gray-500
    Color(0xFF4B5563), // gray-600
    Color(0xFFD1D5DB), // gray-300
  ];

  @override
  void initState() {
    super.initState();
    // 저장된 색상 로드 (0이면 기본색 사용)
    final settings = ref.read(settingsProvider);
    if (settings.holdingChartColor != 0) {
      _holdingColor = Color(settings.holdingChartColor);
    }
  }

  Color _getHoldingColor(BuildContext context) =>
      _holdingColor ?? AppColors.secondary;

  @override
  Widget build(BuildContext context) {
    final summary = widget.summary;
    final hasData = summary.holdingCount > 0;
    final holdingColor = _getHoldingColor(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.appCardBackground,
        borderRadius: BorderRadius.circular(12),
        boxShadow: context.isDarkMode
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더 + 색상 팔레트
          Row(
            children: [
              Text(
                '내 포트폴리오',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: context.appTextPrimary,
                ),
              ),
              if (_editingIndex != null) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 24,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _colorPalette.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 6),
                      itemBuilder: (context, i) {
                        final color = _colorPalette[i];
                        final isSelected = _editingIndex == 0 &&
                                color.value == holdingColor.value;
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _holdingColor = color;
                              _editingIndex = null;
                            });
                            // Hive에 색상 영속화
                            ref.read(settingsProvider.notifier).updateChartColors(
                              alphaColor: 0,
                              holdingColor: (_holdingColor?.value) ?? 0,
                            );
                          },
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(5),
                              border: isSelected
                                  ? Border.all(
                                      color: context.appTextPrimary, width: 2)
                                  : null,
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: color.withValues(alpha: 0.5),
                                        blurRadius: 4,
                                      )
                                    ]
                                  : null,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),

          // 데이터 이상 감지 경고 배너
          if (summary.hasAnomalousData)
            Container(
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '데이터 이상이 감지되었습니다. 해당 종목의 거래 내역을 확인해 주세요.',
                      style: TextStyle(fontSize: 12, color: AppColors.warning),
                    ),
                  ),
                ],
              ),
            ),

          // 차트 + 범례 + 시드 요약 (3열 반응형)
          LayoutBuilder(
            builder: (context, constraints) {
              final availableWidth = constraints.maxWidth;
              final isWide = availableWidth > 500;
              final chartSize = isWide
                  ? (widget.size * 1.1).clamp(120.0, 160.0)
                  : widget.size;

              // 모바일: 차트+범례 위, 총투자/총손익 아래
              if (!isWide) {
                return Column(
                  children: [
                    Row(
                      children: [
                        _buildDonutChart(context, summary, chartSize, holdingColor, hasData, false),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _buildLegendItem(
                            context: context,
                            color: holdingColor,
                            label: '일반 보유 (${summary.holdingCount}개)',
                            value: formatKrw(summary.holdingValue),
                            ratio: 100,
                            index: 0,
                          ),
                        ),
                      ],
                    ),
                    if (hasData) ...[
                      const SizedBox(height: 10),
                      Divider(color: context.appDivider, height: 1),
                      const SizedBox(height: 10),
                      _buildSeedRow(context, summary),
                    ],
                  ],
                );
              }

              // 데스크톱: 좌70% (차트+범례) | 우30% (총투자+총손익)
              return Row(
                children: [
                  // 좌측 70%: 차트 + 범례 (중앙정렬)
                  Expanded(
                    flex: 7,
                    child: Align(
                      alignment: Alignment.center,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: chartSize + 16 + 220),
                        child: Row(
                          children: [
                            _buildDonutChart(context, summary, chartSize, holdingColor, hasData, true),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildLegendItem(
                                context: context,
                                color: holdingColor,
                                label: '일반 보유 (${summary.holdingCount}개)',
                                value: formatKrw(summary.holdingValue),
                                ratio: 100,
                                index: 0,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // 우측 30%: 구분선 + 총투자/총손익 (중앙정렬)
                  if (hasData)
                    Expanded(
                      flex: 3,
                      child: Align(
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 1,
                              height: 60,
                              color: context.appDivider,
                            ),
                            const SizedBox(width: 24),
                            _buildSeedColumn(context, summary),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  /// 도넛 차트 위젯
  Widget _buildDonutChart(
    BuildContext context,
    UnifiedPortfolioSummary summary,
    double chartSize,
    Color holdingColor,
    bool hasData,
    bool isWide,
  ) {
    return SizedBox(
      width: chartSize,
      height: chartSize,
      child: hasData
          ? Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sectionsSpace: 3,
                    centerSpaceRadius: chartSize * 0.38,
                    sections: _buildSections(context, holdingColor),
                    pieTouchData: PieTouchData(enabled: false),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '총 자산',
                        style: TextStyle(
                          fontSize: isWide ? 10 : 9,
                          color: context.appTextSecondary,
                        ),
                      ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          formatKrw(summary.totalValue),
                          style: TextStyle(
                            fontSize: isWide ? 12 : 11,
                            fontWeight: FontWeight.bold,
                            color: context.appTextPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )
          : Center(
              child: Text(
                '데이터 없음',
                style: TextStyle(
                  fontSize: 12,
                  color: context.appTextSecondary,
                ),
              ),
            ),
    );
  }

  /// 총 투자 / 총 손익 — 세로 (데스크톱 3열용)
  Widget _buildSeedColumn(BuildContext context, UnifiedPortfolioSummary summary) {
    final isProfit = summary.totalProfit >= 0;
    final profitColor = isProfit ? AppColors.red500 : AppColors.blue500;
    final sign = isProfit ? '+' : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('총 투자', style: TextStyle(fontSize: 11, color: context.appTextHint)),
        const SizedBox(height: 2),
        Text(
          formatKrw(summary.totalInvested),
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.appTextPrimary),
        ),
        const SizedBox(height: 10),
        Text('총 손익', style: TextStyle(fontSize: 11, color: context.appTextHint)),
        const SizedBox(height: 2),
        Text(
          '$sign${formatKrw(summary.totalProfit)}',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: profitColor),
        ),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          decoration: BoxDecoration(
            color: profitColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '$sign${summary.totalReturnRate.toStringAsFixed(2)}%',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: profitColor),
          ),
        ),
      ],
    );
  }

  /// 총 투자 / 총 손익 — 한 줄 50:50 중앙정렬 (모바일용)
  Widget _buildSeedRow(BuildContext context, UnifiedPortfolioSummary summary) {
    final isProfit = summary.totalProfit >= 0;
    final profitColor = isProfit ? AppColors.red500 : AppColors.blue500;
    final sign = isProfit ? '+' : '';

    return Row(
      children: [
        Expanded(
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('총 투자 ', style: TextStyle(fontSize: 11, color: context.appTextHint)),
                  Text(
                    formatKrw(summary.totalInvested),
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: context.appTextPrimary),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('총 손익 ', style: TextStyle(fontSize: 11, color: context.appTextHint)),
                  Text(
                    '$sign${formatKrw(summary.totalProfit)}($sign${summary.totalReturnRate.toStringAsFixed(2)}%)',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: profitColor),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem({
    required BuildContext context,
    required Color color,
    required String label,
    required String value,
    required double ratio,
    required int index,
  }) {
    final isEditing = _editingIndex == index;

    return Row(
      children: [
        // 색상 네모 (탭하면 팔레트 열림)
        GestureDetector(
          onTap: () {
            setState(() {
              _editingIndex = isEditing ? null : index;
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
              border: isEditing
                  ? Border.all(color: context.appTextPrimary, width: 2)
                  : null,
            ),
          ),
        ),
        const SizedBox(width: 8),
        // 라벨 + 금액 + 퍼센테이지 (컴팩트)
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: context.appTextSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: value,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: context.appTextPrimary,
                      ),
                    ),
                    TextSpan(
                      text: '  ${ratio.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: context.appTextSecondary,
                      ),
                    ),
                  ],
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<PieChartSectionData> _buildSections(
      BuildContext context, Color holdingColor) {
    final summary = widget.summary;

    if (summary.holdingCount <= 0) {
      return [
        PieChartSectionData(
          color: AppColors.gray200,
          value: 100,
          title: '',
          radius: 15,
        ),
      ];
    }

    return [
      PieChartSectionData(
        color: holdingColor,
        value: 100,
        title: '',
        radius: 15,
      ),
    ];
  }
}
