import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/ohlc_data.dart';
import 'chart_controls.dart';
import 'chart_indicator_calculator.dart';
import 'rsi_drawing_overlay.dart';
import 'sub_chart_painters.dart';

/// Sub chart list (VOL, RSI, MACD, STOCH, OBV)
class SubChartList extends StatelessWidget {
  final Set<String> activeIndicators;
  final ChartIndicatorData indicators;
  final List<OHLCData> displayData;
  final double chartWidth;
  final int? selectedCandleDisplayIndex;
  final int scrollOffset;

  // RSI drawing
  final GlobalKey<RsiDrawingOverlayState>? rsiDrawingKey;
  final List<RsiDrawingLine>? rsiDrawingLines;
  final VoidCallback? onRsiDrawingLinesChanged;

  const SubChartList({
    super.key,
    required this.activeIndicators,
    required this.indicators,
    required this.displayData,
    required this.chartWidth,
    this.selectedCandleDisplayIndex,
    this.scrollOffset = 0,
    this.rsiDrawingKey,
    this.rsiDrawingLines,
    this.onRsiDrawingLinesChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = context.appTextSecondary;

    // Crosshair X
    double? crosshairX;
    if (selectedCandleDisplayIndex != null && displayData.isNotEmpty) {
      const leftPadding = 10.0;
      const rightPadding = 50.0;
      final cw = chartWidth - leftPadding - rightPadding;
      final candleW = cw / displayData.length;
      crosshairX = leftPadding + selectedCandleDisplayIndex! * candleW + candleW / 2;
    }

    Widget wrapWithCrosshair(Widget chart, double height) {
      if (crosshairX == null) return chart;
      return SizedBox(
        height: height,
        child: Stack(
          children: [
            chart,
            Positioned(
              left: crosshairX,
              top: 0,
              bottom: 0,
              child: Container(
                width: 0.8,
                color: textColor.withAlpha(80),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Volume
        if (activeIndicators.contains('VOL')) ...[
          SubChartHeader(
            label: indicators.volCurrentValue != null
                ? 'VOL: ${indicators.volCurrentValue}'
                : 'VOL',
            labelColor: textColor,
          ),
          wrapWithCrosshair(
            SizedBox(
              height: 50,
              child: CustomPaint(
                size: Size(chartWidth, 50),
                painter: VolumePainter(
                  data: displayData,
                  isDarkMode: isDarkMode,
                  textColor: textColor,
                ),
              ),
            ),
            50,
          ),
        ],
        // RSI (with drawing overlay)
        if (activeIndicators.contains('RSI') && indicators.displayRSI != null) ...[
          RsiDrawingOverlay(
            key: rsiDrawingKey,
            chartWidth: chartWidth,
            chartHeight: 120,
            rsiValues: indicators.displayRSI!,
            fullRsiValues: indicators.fullRSI ?? indicators.displayRSI!,
            isDarkMode: isDarkMode,
            textColor: textColor,
            displayDataLength: displayData.length,
            scrollOffset: scrollOffset,
            rsiLabel: indicators.rsiLabel ?? 'RSI(14)',
            rsiLabelColor: isDarkMode
                ? const Color(0xFFCE93D8)
                : const Color(0xFF7B1FA2),
            rsiSignal: indicators.rsiSignal,
            crosshairX: crosshairX,
            externalLines: rsiDrawingLines,
            onLinesChanged: onRsiDrawingLinesChanged,
          ),
        ],
        // MACD
        if (activeIndicators.contains('MACD') && indicators.displayMACD != null) ...[
          SubChartHeader(
            label: indicators.macdLabel ?? 'MACD(12,26,9)',
            labelColor: const Color(0xFF2196F3),
            signal: indicators.macdSignal,
          ),
          wrapWithCrosshair(
            SizedBox(
              height: 100,
              child: CustomPaint(
                size: Size(chartWidth, 100),
                painter: MACDPainter(
                  macdValues: indicators.displayMACD!,
                  isDarkMode: isDarkMode,
                  textColor: textColor,
                ),
              ),
            ),
            100,
          ),
        ],
        // Stochastic
        if (activeIndicators.contains('STOCH') && indicators.displayStoch != null) ...[
          SubChartHeader(
            label: indicators.stochLabel ?? 'STOCH(14,3)',
            labelColor: const Color(0xFF2196F3),
            signal: indicators.stochSignal,
          ),
          wrapWithCrosshair(
            SizedBox(
              height: 100,
              child: CustomPaint(
                size: Size(chartWidth, 100),
                painter: StochasticPainter(
                  stochValues: indicators.displayStoch!,
                  isDarkMode: isDarkMode,
                  textColor: textColor,
                ),
              ),
            ),
            100,
          ),
        ],
        // OBV
        if (activeIndicators.contains('OBV') && indicators.displayOBV != null) ...[
          SubChartHeader(
            label: indicators.obvLabel ?? 'OBV',
            labelColor: const Color(0xFF10B981),
            signal: indicators.obvSignal,
          ),
          wrapWithCrosshair(
            SizedBox(
              height: 80,
              child: CustomPaint(
                size: Size(chartWidth, 80),
                painter: OBVPainter(
                  obvValues: indicators.displayOBV!,
                  isDarkMode: isDarkMode,
                  textColor: textColor,
                ),
              ),
            ),
            80,
          ),
        ],
      ],
    );
  }
}
