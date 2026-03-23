import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/financial_data.dart';

/// EPS Beat/Miss 차트
///
/// 실제 EPS vs 예상 EPS를 그룹 막대로 표시.
/// Beat: 실제 막대 초록 / Miss: 실제 막대 빨강 / 예상 막대: 회색.
/// Finnhub 응답은 최신 먼저이므로 reversed 처리.
class FinancialEpsChart extends StatelessWidget {
  final List<EarningsResult> earnings;

  const FinancialEpsChart({
    super.key,
    required this.earnings,
  });

  @override
  Widget build(BuildContext context) {
    if (earnings.isEmpty) return const SizedBox.shrink();

    final isDark = context.isDarkMode;
    final sortedData = earnings.reversed.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'EPS 실적 vs 예상',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: context.appTextPrimary,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 180,
          child: CustomPaint(
            size: const Size(double.infinity, 180),
            painter: _EpsChartPainter(
              data: sortedData,
              isDarkMode: isDark,
              textColor: context.appTextSecondary,
            ),
          ),
        ),
        const SizedBox(height: 8),
        _buildLegend(isDark, context),
      ],
    );
  }

  Widget _buildLegend(bool isDark, BuildContext context) {
    final beatColor = isDark ? AppColors.green400 : AppColors.green500;
    final missColor = isDark ? AppColors.red400 : AppColors.red500;
    final estimateColor = isDark
        ? const Color(0xFF6E7681)
        : const Color(0xFF9CA3AF);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _legendItem(beatColor, 'Beat', context),
        const SizedBox(width: 12),
        _legendItem(missColor, 'Miss', context),
        const SizedBox(width: 12),
        _legendItem(estimateColor, '예상', context),
      ],
    );
  }

  Widget _legendItem(Color color, String label, BuildContext context) {
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

/// EPS Beat/Miss 그룹 막대 차트 Painter
class _EpsChartPainter extends CustomPainter {
  final List<EarningsResult> data;
  final bool isDarkMode;
  final Color textColor;

  _EpsChartPainter({
    required this.data,
    required this.isDarkMode,
    required this.textColor,
  });

  Color get beatColor =>
      isDarkMode ? AppColors.green400 : AppColors.green500;
  Color get missColor =>
      isDarkMode ? AppColors.red400 : AppColors.red500;
  Color get estimateColor => isDarkMode
      ? const Color(0xFF6E7681).withValues(alpha: 0.7)
      : const Color(0xFF9CA3AF).withValues(alpha: 0.7);

  static const double leftPadding = 40;
  static const double rightPadding = 16;
  static const double topPadding = 20; // 서프라이즈 % 텍스트 공간
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
      for (final v in [d.actual ?? 0.0, d.estimate ?? 0.0]) {
        if (v > maxVal) maxVal = v;
        if (v < minVal) minVal = v;
      }
    }

    final range = maxVal - minVal;
    if (range == 0) return;
    maxVal += range * 0.15;
    if (minVal < 0) {
      minVal -= range * 0.05;
    } else {
      minVal = 0;
    }

    final yRange = maxVal - minVal;

    double toY(double value) {
      return topPadding + (1 - (value - minVal) / yRange) * chartHeight;
    }

    // 그리드
    final gridColor = isDarkMode
        ? const Color(0xFF2D333B)
        : const Color(0xFFE5E7EB);
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 0.5;

    const gridCount = 3;
    for (int i = 0; i <= gridCount; i++) {
      final value = minVal + (yRange * i / gridCount);
      final y = toY(value);
      canvas.drawLine(
        Offset(leftPadding, y),
        Offset(size.width - rightPadding, y),
        gridPaint,
      );

      // Y축 라벨
      final label = '\$${value.toStringAsFixed(2)}';
      final textSpan = TextSpan(
        text: label,
        style: TextStyle(
          color: textColor.withValues(alpha: 0.7),
          fontSize: 9,
        ),
      );
      final tp = TextPainter(
        text: textSpan,
        textDirection: ui.TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas, Offset(leftPadding - tp.width - 4, y - tp.height / 2));
    }

    // 0선 강조
    if (minVal < 0) {
      final zeroY = toY(0);
      canvas.drawLine(
        Offset(leftPadding, zeroY),
        Offset(size.width - rightPadding, zeroY),
        Paint()
          ..color = textColor.withValues(alpha: 0.3)
          ..strokeWidth = 1.0,
      );
    }

    // 막대 그리기
    final groupWidth = chartWidth / data.length;
    const barsPerGroup = 2;
    final barGap = groupWidth * 0.06;
    final totalBarArea = groupWidth * 0.6;
    final barWidth =
        (totalBarArea - barGap * (barsPerGroup - 1)) / barsPerGroup;
    final groupOffset = (groupWidth - totalBarArea) / 2;

    final zeroY = toY(0);

    for (int i = 0; i < data.length; i++) {
      final d = data[i];
      final groupX = leftPadding + i * groupWidth;

      final actual = d.actual ?? 0.0;
      final estimate = d.estimate ?? 0.0;
      final isBeat = d.isBeat;

      // 실제 EPS 막대
      final actualColor = isBeat ? beatColor : missColor;
      final actualBarX = groupX + groupOffset;
      final actualBarY = toY(actual);
      final actualTop = actual >= 0 ? actualBarY : zeroY;
      final actualBottom = actual >= 0 ? zeroY : actualBarY;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(
              actualBarX, actualTop, actualBarX + barWidth, actualBottom),
          const Radius.circular(2),
        ),
        Paint()..color = actualColor,
      );

      // 예상 EPS 막대
      final estBarX = groupX + groupOffset + barWidth + barGap;
      final estBarY = toY(estimate);
      final estTop = estimate >= 0 ? estBarY : zeroY;
      final estBottom = estimate >= 0 ? zeroY : estBarY;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(estBarX, estTop, estBarX + barWidth, estBottom),
          const Radius.circular(2),
        ),
        Paint()..color = estimateColor,
      );

      // 서프라이즈 % 텍스트 (막대 위)
      if (d.surprisePercent != null) {
        final surpriseText = d.surprisePercent! >= 0
            ? '+${d.surprisePercent!.toStringAsFixed(1)}%'
            : '${d.surprisePercent!.toStringAsFixed(1)}%';
        final surpriseColor = isBeat
            ? (isDarkMode ? AppColors.green400 : AppColors.green600)
            : (isDarkMode ? AppColors.red400 : AppColors.red500);

        final textSpan = TextSpan(
          text: surpriseText,
          style: TextStyle(
            color: surpriseColor,
            fontSize: 9,
            fontWeight: FontWeight.w600,
          ),
        );
        final tp = TextPainter(
          text: textSpan,
          textDirection: ui.TextDirection.ltr,
          textAlign: TextAlign.center,
        );
        tp.layout();
        final textX = groupX + groupWidth / 2 - tp.width / 2;
        final barTop = actual >= 0 ? actualBarY : estBarY;
        tp.paint(canvas, Offset(textX, barTop - tp.height - 2));
      }

      // X축 라벨 (Q3'24)
      final xLabel = _xLabel(d);
      final textSpan = TextSpan(
        text: xLabel,
        style: TextStyle(
          color: textColor.withValues(alpha: 0.7),
          fontSize: 10,
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

  String _xLabel(EarningsResult d) {
    final q = d.quarter ?? 0;
    final y = d.year ?? 0;
    final shortYear = y > 0 ? (y % 100).toString().padLeft(2, '0') : '??';
    return "Q$q'$shortYear";
  }

  @override
  bool shouldRepaint(covariant _EpsChartPainter oldDelegate) =>
      oldDelegate.data != data || oldDelegate.isDarkMode != isDarkMode;
}
