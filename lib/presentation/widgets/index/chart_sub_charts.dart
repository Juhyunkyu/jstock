import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/ohlc_data.dart';
import 'chart_controls.dart';
import 'chart_indicator_calculator.dart';
import 'indicator_help_dialog.dart';
import 'rsi_drawing_overlay.dart';
import 'sub_chart_painters.dart';

/// Sub chart list (VOL, RSI, MACD, STOCH, OBV)
class SubChartList extends StatelessWidget {
  final List<String> activeIndicators;
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

    // 각 지표의 위젯 빌더 맵
    Widget? buildSubChart(String key) {
      switch (key) {
        case 'VOL':
          return Column(children: [
            SubChartHeader(
              label: indicators.volCurrentValue != null
                  ? 'VOL: ${indicators.volCurrentValue}'
                  : 'VOL',
              labelColor: textColor,
              indicatorKey: 'VOL',
              onHelpTap: (k) => showIndicatorHelpDialog(context, k),
            ),
            wrapWithCrosshair(
              SizedBox(
                height: sizes.vol,
                child: CustomPaint(
                  size: Size(chartWidth, sizes.vol),
                  painter: VolumePainter(data: displayData, isDarkMode: isDarkMode, textColor: textColor),
                ),
              ),
              sizes.vol,
            ),
          ]);
        case 'RSI':
          if (indicators.displayRSI == null) return null;
          return RsiDrawingOverlay(
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
            rsiLabelColor: isDarkMode ? const Color(0xFFCE93D8) : const Color(0xFF7B1FA2),
            rsiSignal: indicators.rsiSignal,
            crosshairX: crosshairX,
            externalLines: rsiDrawingLines,
            onLinesChanged: onRsiDrawingLinesChanged,
            onHelpTap: () => showIndicatorHelpDialog(context, 'RSI'),
          );
        case 'MACD':
          if (indicators.displayMACD == null) return null;
          return Column(children: [
            SubChartHeader(
              label: indicators.macdLabel ?? 'MACD(12,26,9)',
              labelColor: const Color(0xFF2196F3),
              signal: indicators.macdSignal,
              indicatorKey: 'MACD',
              onHelpTap: (k) => showIndicatorHelpDialog(context, k),
            ),
            wrapWithCrosshair(
              SizedBox(
                height: sizes.macd,
                child: CustomPaint(
                  size: Size(chartWidth, sizes.macd),
                  painter: MACDPainter(macdValues: indicators.displayMACD!, isDarkMode: isDarkMode, textColor: textColor),
                ),
              ),
              sizes.macd,
            ),
          ]);
        case 'STOCH':
          if (indicators.displayStoch == null) return null;
          return Column(children: [
            SubChartHeader(
              label: indicators.stochLabel ?? 'STOCH(14,3)',
              labelColor: const Color(0xFF2196F3),
              signal: indicators.stochSignal,
              indicatorKey: 'STOCH',
              onHelpTap: (k) => showIndicatorHelpDialog(context, k),
            ),
            wrapWithCrosshair(
              SizedBox(
                height: sizes.stoch,
                child: CustomPaint(
                  size: Size(chartWidth, sizes.stoch),
                  painter: StochasticPainter(stochValues: indicators.displayStoch!, isDarkMode: isDarkMode, textColor: textColor),
                ),
              ),
              sizes.stoch,
            ),
          ]);
        case 'OBV':
          if (indicators.displayOBV == null) return null;
          return Column(children: [
            SubChartHeader(
              label: indicators.obvLabel ?? 'OBV',
              labelColor: const Color(0xFF10B981),
              signal: indicators.obvSignal,
              indicatorKey: 'OBV',
              onHelpTap: (k) => showIndicatorHelpDialog(context, k),
            ),
            wrapWithCrosshair(
              SizedBox(
                height: sizes.obv,
                child: CustomPaint(
                  size: Size(chartWidth, sizes.obv),
                  painter: OBVPainter(obvValues: indicators.displayOBV!, isDarkMode: isDarkMode, textColor: textColor),
                ),
              ),
              sizes.obv,
            ),
          ]);
        case 'PVT':
          if (indicators.displayPVT == null) return null;
          return Column(children: [
            SubChartHeader(
              label: indicators.pvtLabel ?? 'PVT',
              labelColor: const Color(0xFFFF9800),
              signal: indicators.pvtSignal,
              indicatorKey: 'PVT',
              onHelpTap: (k) => showIndicatorHelpDialog(context, k),
            ),
            wrapWithCrosshair(
              SizedBox(
                height: sizes.pvt,
                child: CustomPaint(
                  size: Size(chartWidth, sizes.pvt),
                  painter: PVTPainter(pvtValues: indicators.displayPVT!, isDarkMode: isDarkMode, textColor: textColor),
                ),
              ),
              sizes.pvt,
            ),
          ]);
        case 'MFI':
          if (indicators.displayMFI == null) return null;
          return Column(children: [
            SubChartHeader(
              label: indicators.mfiLabel ?? 'MFI(14)',
              labelColor: isDarkMode ? const Color(0xFF81D4FA) : const Color(0xFF0277BD),
              signal: indicators.mfiSignal,
              indicatorKey: 'MFI',
              onHelpTap: (k) => showIndicatorHelpDialog(context, k),
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
          ]);
        default:
          return null;
      }
    }

    // activeIndicators 순서대로 서브차트 렌더링
    return Column(
      children: [
        for (final key in activeIndicators)
          if (buildSubChart(key) case final widget?) widget,
      ],
    );
  }
}
