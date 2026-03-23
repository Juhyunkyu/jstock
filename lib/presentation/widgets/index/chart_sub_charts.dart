import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/ohlc_data.dart';
import '../../../data/services/technical_indicator_service.dart';
import 'chart_controls.dart';
import 'chart_indicator_calculator.dart';
import 'sub_chart_painters.dart';

/// 서브 차트 목록 (VOL, RSI, MACD, STOCH, OBV)
class SubChartList extends StatelessWidget {
  final Set<String> activeIndicators;
  final ChartIndicatorData indicators;
  final List<OHLCData> displayData;
  final double chartWidth;
  final int? selectedCandleDisplayIndex; // 선택된 캔들의 display 인덱스 (수직선용)

  const SubChartList({
    super.key,
    required this.activeIndicators,
    required this.indicators,
    required this.displayData,
    required this.chartWidth,
    this.selectedCandleDisplayIndex,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = context.appTextSecondary;

    // 수직 십자선 X 좌표 계산 (서브차트 전체에 공유)
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
        // 거래량 서브차트
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
        // RSI 서브차트
        if (activeIndicators.contains('RSI') && indicators.displayRSI != null) ...[
          SubChartHeader(
            label: indicators.rsiLabel ?? 'RSI(14)',
            labelColor: isDarkMode
                ? const Color(0xFFCE93D8)
                : const Color(0xFF7B1FA2),
            signal: indicators.rsiSignal,
          ),
          wrapWithCrosshair(
            SizedBox(
              height: 120,
              child: CustomPaint(
                size: Size(chartWidth, 120),
                painter: RSIPainter(
                  rsiValues: indicators.displayRSI!,
                  isDarkMode: isDarkMode,
                  textColor: textColor,
                ),
              ),
            ),
            120,
          ),
        ],
        // MACD 서브차트
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
        // 스토캐스틱 서브차트
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
        // OBV 서브차트
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
