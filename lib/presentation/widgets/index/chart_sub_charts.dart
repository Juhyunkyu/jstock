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
  final ChartSizes? chartSizes;

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
    this.chartSizes,
    this.rsiDrawingKey,
    this.rsiDrawingLines,
    this.onRsiDrawingLinesChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = context.appTextSecondary;
    final sizes = chartSizes ?? ChartSizes.fromWidth(MediaQuery.sizeOf(context).width);

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
              height: sizes.vol,
              child: CustomPaint(
                size: Size(chartWidth, sizes.vol),
                painter: VolumePainter(
                  data: displayData,
                  isDarkMode: isDarkMode,
                  textColor: textColor,
                ),
              ),
            ),
            sizes.vol,
          ),
        ],
        // RSI (with drawing overlay)
        if (activeIndicators.contains('RSI') && indicators.displayRSI != null) ...[
          RsiDrawingOverlay(
            key: rsiDrawingKey,
            chartWidth: chartWidth,
            chartHeight: sizes.rsi,
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
              height: sizes.macd,
              child: CustomPaint(
                size: Size(chartWidth, sizes.macd),
                painter: MACDPainter(
                  macdValues: indicators.displayMACD!,
                  isDarkMode: isDarkMode,
                  textColor: textColor,
                ),
              ),
            ),
            sizes.macd,
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
              height: sizes.stoch,
              child: CustomPaint(
                size: Size(chartWidth, sizes.stoch),
                painter: StochasticPainter(
                  stochValues: indicators.displayStoch!,
                  isDarkMode: isDarkMode,
                  textColor: textColor,
                ),
              ),
            ),
            sizes.stoch,
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
              height: sizes.obv,
              child: CustomPaint(
                size: Size(chartWidth, sizes.obv),
                painter: OBVPainter(
                  obvValues: indicators.displayOBV!,
                  isDarkMode: isDarkMode,
                  textColor: textColor,
                ),
              ),
            ),
            sizes.obv,
          ),
        ],
        // MFI
        if (activeIndicators.contains('MFI') && indicators.displayMFI != null) ...[
          SubChartHeader(
            label: indicators.mfiLabel ?? 'MFI(14)',
            labelColor: isDarkMode
                ? const Color(0xFF81D4FA)
                : const Color(0xFF0277BD),
            signal: indicators.mfiSignal,
          ),
          wrapWithCrosshair(
            SizedBox(
              height: sizes.mfi,
              child: CustomPaint(
                size: Size(chartWidth, sizes.mfi),
                painter: MFIPainter(
                  mfiValues: indicators.displayMFI!,
                  isDarkMode: isDarkMode,
                  textColor: textColor,
                ),
              ),
            ),
            sizes.mfi,
          ),
        ],
      ],
    );
  }
}
