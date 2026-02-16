import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme/app_colors.dart';

/// 포트폴리오 자산 배분 차트 위젯
///
/// 알파 사이클과 일반 보유의 비율을 도넛 차트로 표시합니다.
/// 범례의 색상 네모를 탭하면 색상을 변경할 수 있습니다.
class PortfolioAllocationChart extends StatefulWidget {
  /// 알파 사이클 비율 (0-100)
  final double alphaCycleRatio;

  /// 일반 보유 비율 (0-100)
  final double holdingRatio;

  /// 알파 사이클 금액 (KRW)
  final double alphaCycleValue;

  /// 일반 보유 금액 (KRW)
  final double holdingValue;

  /// 차트 크기
  final double size;

  const PortfolioAllocationChart({
    super.key,
    required this.alphaCycleRatio,
    required this.holdingRatio,
    required this.alphaCycleValue,
    required this.holdingValue,
    this.size = 130,
  });

  @override
  State<PortfolioAllocationChart> createState() =>
      _PortfolioAllocationChartState();
}

class _PortfolioAllocationChartState extends State<PortfolioAllocationChart> {
  /// 사용자 선택 색상 (null이면 기본값 사용)
  Color? _alphaCycleColor;
  Color? _holdingColor;

  /// 현재 편집 중인 범례 인덱스 (0=알파, 1=일반, null=없음)
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

  Color _getAlphaColor(BuildContext context) =>
      _alphaCycleColor ??
      (context.isDarkMode ? const Color(0xFF58A6FF) : AppColors.primary);

  Color _getHoldingColor(BuildContext context) =>
      _holdingColor ?? AppColors.secondary;

  @override
  Widget build(BuildContext context) {
    final hasData = widget.alphaCycleRatio > 0 || widget.holdingRatio > 0;
    final alphaColor = _getAlphaColor(context);
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
                '자산 배분',
                style: TextStyle(
                  fontSize: 14,
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
                        final isSelected = (_editingIndex == 0 &&
                                color.value == alphaColor.value) ||
                            (_editingIndex == 1 &&
                                color.value == holdingColor.value);
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              if (_editingIndex == 0) {
                                _alphaCycleColor = color;
                              } else {
                                _holdingColor = color;
                              }
                              _editingIndex = null;
                            });
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
          const SizedBox(height: 10),

          // 차트 + 범례 (반응형)
          LayoutBuilder(
            builder: (context, constraints) {
              final availableWidth = constraints.maxWidth;
              final isWide = availableWidth > 400;
              final chartSize = isWide
                  ? (widget.size * 1.3).clamp(130.0, 180.0)
                  : widget.size;
              final gap = isWide ? 28.0 : 14.0;

              return Row(
                children: [
                  // 넓은 화면에서 좌측 여백으로 차트를 중앙 쪽으로 이동
                  if (isWide) SizedBox(width: availableWidth * 0.06),
                  // 도넛 차트
                  SizedBox(
                    width: chartSize,
                    height: chartSize,
                    child: hasData
                        ? Stack(
                            alignment: Alignment.center,
                            children: [
                              PieChart(
                                PieChartData(
                                  sectionsSpace: 3,
                                  centerSpaceRadius: chartSize * 0.3,
                                  sections: _buildSections(
                                      context, alphaColor, holdingColor),
                                  pieTouchData:
                                      PieTouchData(enabled: false),
                                ),
                              ),
                              // 중앙 라벨
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '총 자산',
                                    style: TextStyle(
                                      fontSize: isWide ? 11 : 10,
                                      color: context.appTextSecondary,
                                    ),
                                  ),
                                  Text(
                                    _formatKrw(widget.alphaCycleValue +
                                        widget.holdingValue),
                                    style: TextStyle(
                                      fontSize: isWide ? 13 : 12,
                                      fontWeight: FontWeight.bold,
                                      color: context.appTextPrimary,
                                    ),
                                  ),
                                ],
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
                  ),
                  SizedBox(width: gap),

                  // 범례
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLegendItem(
                          context: context,
                          color: alphaColor,
                          label: '알파 사이클',
                          value: _formatKrw(widget.alphaCycleValue),
                          ratio: widget.alphaCycleRatio,
                          index: 0,
                        ),
                        SizedBox(height: isWide ? 16 : 8),
                        _buildLegendItem(
                          context: context,
                          color: holdingColor,
                          label: '일반 보유',
                          value: _formatKrw(widget.holdingValue),
                          ratio: widget.holdingRatio,
                          index: 1,
                        ),
                      ],
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
        Expanded(
          child: Row(
            children: [
              // 라벨 + 금액 (왼쪽)
              Expanded(
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
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: context.appTextPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              // 퍼센테이지 (빈 공간 중앙)
              Expanded(
                child: Center(
                  child: Text(
                    '${ratio.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: context.appTextSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<PieChartSectionData> _buildSections(
      BuildContext context, Color alphaColor, Color holdingColor) {
    final sections = <PieChartSectionData>[];

    if (widget.alphaCycleRatio > 0) {
      sections.add(
        PieChartSectionData(
          color: alphaColor,
          value: widget.alphaCycleRatio,
          title: '',
          radius: 20,
        ),
      );
    }

    if (widget.holdingRatio > 0) {
      sections.add(
        PieChartSectionData(
          color: holdingColor,
          value: widget.holdingRatio,
          title: '',
          radius: 20,
        ),
      );
    }

    if (sections.isEmpty) {
      sections.add(
        PieChartSectionData(
          color: AppColors.gray200,
          value: 100,
          title: '',
          radius: 20,
        ),
      );
    }

    return sections;
  }

  String _formatKrw(double amount) {
    final intAmount = amount.round();
    final absAmount = intAmount.abs();
    final formatted = absAmount.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
    return intAmount < 0 ? '-$formatted원' : '$formatted원';
  }
}
