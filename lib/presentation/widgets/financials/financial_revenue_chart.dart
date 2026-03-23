import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/financial_data.dart';

/// 실적 추이 막대 차트 (매출 / 영업이익 / 순이익)
///
/// 연간/분기 토글로 전환 가능한 그룹 막대 차트.
/// FMP 응답은 최신 먼저이므로 reversed 처리하여 오래된 것부터 표시.
class FinancialRevenueChart extends StatefulWidget {
  final List<IncomeStatement> annualStatements;
  final List<IncomeStatement> quarterlyStatements;

  const FinancialRevenueChart({
    super.key,
    required this.annualStatements,
    required this.quarterlyStatements,
  });

  @override
  State<FinancialRevenueChart> createState() => _FinancialRevenueChartState();
}

class _FinancialRevenueChartState extends State<FinancialRevenueChart> {
  bool _isAnnual = true;

  List<IncomeStatement> get _currentData {
    final source = _isAnnual
        ? widget.annualStatements
        : widget.quarterlyStatements;
    return source.reversed.toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final hasAnnual = widget.annualStatements.isNotEmpty;
    final hasQuarterly = widget.quarterlyStatements.isNotEmpty;

    if (!hasAnnual && !hasQuarterly) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 헤더: 타이틀 + 토글
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '실적 추이',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: context.appTextPrimary,
                  ),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () => _showHelpSheet(context),
                  child: Icon(Icons.info_outline, size: 16, color: context.appTextHint),
                ),
              ],
            ),
            if (hasAnnual && hasQuarterly)
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('연간')),
                  ButtonSegment(value: false, label: Text('분기')),
                ],
                selected: {_isAnnual},
                onSelectionChanged: (value) {
                  setState(() => _isAnnual = value.first);
                },
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: WidgetStatePropertyAll(
                    TextStyle(fontSize: 12, color: context.appTextPrimary),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),

        // 차트
        SizedBox(
          height: 220,
          child: _currentData.isEmpty
              ? Center(
                  child: Text(
                    '데이터 없음',
                    style: TextStyle(color: context.appTextHint, fontSize: 13),
                  ),
                )
              : CustomPaint(
                  size: const Size(double.infinity, 220),
                  painter: _RevenueChartPainter(
                    data: _currentData,
                    isDarkMode: isDark,
                    textColor: context.appTextSecondary,
                    isAnnual: _isAnnual,
                  ),
                ),
        ),
        const SizedBox(height: 8),

        // 범례
        _buildLegend(isDark),
      ],
    );
  }

  Widget _buildLegend(bool isDark) {
    final revenueColor = isDark
        ? const Color(0xFF60A5FA)
        : const Color(0xFF3B82F6);
    final operatingColor = isDark
        ? const Color(0xFF34D399)
        : const Color(0xFF10B981);
    final netIncomeColor = isDark
        ? const Color(0xFFFBBF24)
        : const Color(0xFFF59E0B);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _legendItem(revenueColor, '매출'),
        const SizedBox(width: 16),
        _legendItem(operatingColor, '영업이익'),
        const SizedBox(width: 16),
        _legendItem(netIncomeColor, '순이익'),
      ],
    );
  }

  void _showHelpSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.appSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(color: context.appDivider, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Text('실적 추이', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: context.appTextPrimary)),
            const SizedBox(height: 12),
            Text(
              '기업의 매출, 영업이익, 순이익의 연간/분기별 추이를 보여줍니다.\n\n'
              '• 매출: 기업이 벌어들인 전체 수익\n'
              '• 영업이익: 매출에서 운영 비용을 뺀 이익\n'
              '• 순이익: 세금 등 모든 비용을 뺀 최종 이익\n\n'
              '막대가 꾸준히 성장하면 기업이 성장하고 있다는 의미입니다.',
              style: TextStyle(fontSize: 13, color: context.appTextSecondary, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: context.appTextSecondary,
          ),
        ),
      ],
    );
  }
}

/// 매출/영업이익/순이익 그룹 막대 차트 Painter
class _RevenueChartPainter extends CustomPainter {
  final List<IncomeStatement> data;
  final bool isDarkMode;
  final Color textColor;
  final bool isAnnual;

  _RevenueChartPainter({
    required this.data,
    required this.isDarkMode,
    required this.textColor,
    required this.isAnnual,
  });

  Color get revenueColor =>
      isDarkMode ? const Color(0xFF60A5FA) : const Color(0xFF3B82F6);
  Color get operatingColor =>
      isDarkMode ? const Color(0xFF34D399) : const Color(0xFF10B981);
  Color get netIncomeColor =>
      isDarkMode ? const Color(0xFFFBBF24) : const Color(0xFFF59E0B);

  static const double leftPadding = 52;
  static const double rightPadding = 16;
  static const double topPadding = 8;
  static const double bottomPadding = 30;

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final chartWidth = size.width - leftPadding - rightPadding;
    final chartHeight = size.height - topPadding - bottomPadding;

    // Y축 범위 계산
    double maxVal = 0;
    double minVal = 0;
    for (final d in data) {
      for (final v in [d.revenue, d.operatingIncome, d.netIncome]) {
        if (v > maxVal) maxVal = v;
        if (v < minVal) minVal = v;
      }
    }

    // 최소~최대에 여유 추가
    final range = maxVal - minVal;
    if (range == 0) return;
    maxVal += range * 0.1;
    if (minVal < 0) {
      minVal -= range * 0.05;
    } else {
      minVal = 0;
    }

    final yRange = maxVal - minVal;

    double toY(double value) {
      return topPadding + (1 - (value - minVal) / yRange) * chartHeight;
    }

    // 그리드 라인
    final gridColor = isDarkMode
        ? const Color(0xFF2D333B)
        : const Color(0xFFE5E7EB);
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 0.5;

    // Y축 그리드 (5단계)
    const gridCount = 4;
    for (int i = 0; i <= gridCount; i++) {
      final value = minVal + (yRange * i / gridCount);
      final y = toY(value);
      canvas.drawLine(
        Offset(leftPadding, y),
        Offset(size.width - rightPadding, y),
        gridPaint,
      );

      // Y축 라벨
      final label = _formatAmount(value);
      final labelColor = isDarkMode
          ? const Color(0xFFD1D5DB)
          : const Color(0xFF4B5563);
      final textSpan = TextSpan(
        text: label,
        style: TextStyle(
          color: labelColor,
          fontSize: 11,
        ),
      );
      final tp = TextPainter(
        text: textSpan,
        textDirection: ui.TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas, Offset(leftPadding - tp.width - 6, y - tp.height / 2));
    }

    // 0선 강조 (음수가 있을 때)
    if (minVal < 0) {
      final zeroY = toY(0);
      final zeroPaint = Paint()
        ..color = textColor.withValues(alpha: 0.3)
        ..strokeWidth = 1.0;
      canvas.drawLine(
        Offset(leftPadding, zeroY),
        Offset(size.width - rightPadding, zeroY),
        zeroPaint,
      );
    }

    // 막대 그리기
    final groupWidth = chartWidth / data.length;
    const barsPerGroup = 3;
    final barGap = groupWidth * 0.06;
    final totalBarArea = groupWidth * 0.7;
    final barWidth = (totalBarArea - barGap * (barsPerGroup - 1)) / barsPerGroup;
    final groupOffset = (groupWidth - totalBarArea) / 2;

    final zeroY = toY(0);

    for (int i = 0; i < data.length; i++) {
      final d = data[i];
      final groupX = leftPadding + i * groupWidth;
      final values = [d.revenue, d.operatingIncome, d.netIncome];
      final colors = [revenueColor, operatingColor, netIncomeColor];

      for (int j = 0; j < barsPerGroup; j++) {
        final barX = groupX + groupOffset + j * (barWidth + barGap);
        final value = values[j];
        final barY = toY(value);

        final top = value >= 0 ? barY : zeroY;
        final bottom = value >= 0 ? zeroY : barY;

        final rrect = RRect.fromRectAndRadius(
          Rect.fromLTRB(barX, top, barX + barWidth, bottom),
          const Radius.circular(2),
        );
        canvas.drawRRect(rrect, Paint()..color = colors[j]);
      }

      // X축 라벨
      final xLabel = _xLabel(d);
      final xLabelColor = isDarkMode
          ? const Color(0xFFD1D5DB)
          : const Color(0xFF4B5563);
      final textSpan = TextSpan(
        text: xLabel,
        style: TextStyle(
          color: xLabelColor,
          fontSize: 11,
        ),
      );
      final tp = TextPainter(
        text: textSpan,
        textDirection: ui.TextDirection.ltr,
        textAlign: TextAlign.center,
      );
      tp.layout();
      final labelX = groupX + groupWidth / 2 - tp.width / 2;
      tp.paint(canvas, Offset(labelX, size.height - bottomPadding + 6));
    }
  }

  String _xLabel(IncomeStatement d) {
    if (isAnnual) {
      // 연간: 'YY
      final year = d.calendarYear ?? d.date.split('-').first;
      if (year.length >= 4) {
        return "'${year.substring(2)}";
      }
      return year;
    } else {
      // 분기: Q1'YY
      final period = d.period ?? '';
      final year = d.calendarYear ?? d.date.split('-').first;
      final shortYear = year.length >= 4 ? year.substring(2) : year;
      return "$period'$shortYear";
    }
  }

  @override
  bool shouldRepaint(covariant _RevenueChartPainter oldDelegate) =>
      oldDelegate.data != data ||
      oldDelegate.isDarkMode != isDarkMode ||
      oldDelegate.isAnnual != isAnnual;
}

/// 금액 포맷: $1.2T / $123B / $450M / $123K
String _formatAmount(double value) {
  final abs = value.abs();
  final sign = value < 0 ? '-' : '';
  if (abs >= 1e12) return '$sign\$${(abs / 1e12).toStringAsFixed(1)}T';
  if (abs >= 1e9) return '$sign\$${(abs / 1e9).toStringAsFixed(0)}B';
  if (abs >= 1e6) return '$sign\$${(abs / 1e6).toStringAsFixed(0)}M';
  if (abs >= 1e3) return '$sign\$${(abs / 1e3).toStringAsFixed(0)}K';
  return '$sign\$${abs.toStringAsFixed(0)}';
}
