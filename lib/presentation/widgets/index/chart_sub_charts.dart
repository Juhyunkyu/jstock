import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/ohlc_data.dart';
import '../../../data/services/technical_indicator_service.dart';
import '../../../domain/trading/rsi_divergence.dart';
import 'chart_controls.dart';
import 'chart_indicator_calculator.dart';
import 'sub_chart_painters.dart';

/// 서브 차트 목록 (VOL, RSI, MACD, STOCH, OBV)
class SubChartList extends StatelessWidget {
  final Set<String> activeIndicators;
  final ChartIndicatorData indicators;
  final List<OHLCData> displayData;
  final double chartWidth;
  final List<Divergence>? rsiDivergences;
  final int scrollOffset;
  final bool showDivergence;
  final VoidCallback? onToggleDivergence;

  const SubChartList({
    super.key,
    required this.activeIndicators,
    required this.indicators,
    required this.displayData,
    required this.chartWidth,
    this.rsiDivergences,
    this.scrollOffset = 0,
    this.showDivergence = false,
    this.onToggleDivergence,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = context.appTextSecondary;

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
        ],
        // RSI 서브차트
        if (activeIndicators.contains('RSI') && indicators.displayRSI != null) ...[
          Row(
            children: [
              Expanded(
                child: SubChartHeader(
                  label: indicators.rsiLabel ?? 'RSI(14)',
                  labelColor: isDarkMode
                      ? const Color(0xFFCE93D8)
                      : const Color(0xFF7B1FA2),
                  signal: indicators.rsiSignal,
                ),
              ),
              if (onToggleDivergence != null)
                GestureDetector(
                  onTap: onToggleDivergence,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    margin: const EdgeInsets.only(right: 50),
                    decoration: BoxDecoration(
                      color: showDivergence
                          ? (isDarkMode ? const Color(0xFF1B5E20) : const Color(0xFFE8F5E9))
                          : context.appIconBg,
                      borderRadius: BorderRadius.circular(4),
                      border: showDivergence
                          ? Border.all(color: const Color(0xFF4CAF50), width: 0.5)
                          : null,
                    ),
                    child: Text(
                      'D',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: showDivergence
                            ? const Color(0xFF4CAF50)
                            : context.appTextHint,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(
            height: 70,
            child: CustomPaint(
              size: Size(chartWidth, 70),
              painter: RSIPainter(
                rsiValues: indicators.displayRSI!,
                isDarkMode: isDarkMode,
                textColor: textColor,
                divergences: showDivergence ? rsiDivergences : null,
                scrollOffset: scrollOffset,
              ),
            ),
          ),
        ],
        // MACD 서브차트
        if (activeIndicators.contains('MACD') && indicators.displayMACD != null) ...[
          SubChartHeader(
            label: indicators.macdLabel ?? 'MACD(12,26,9)',
            labelColor: const Color(0xFF2196F3),
            signal: indicators.macdSignal,
          ),
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
        ],
        // 스토캐스틱 서브차트
        if (activeIndicators.contains('STOCH') && indicators.displayStoch != null) ...[
          SubChartHeader(
            label: indicators.stochLabel ?? 'STOCH(14,3)',
            labelColor: const Color(0xFF2196F3),
            signal: indicators.stochSignal,
          ),
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
        ],
        // OBV 서브차트
        if (activeIndicators.contains('OBV') && indicators.displayOBV != null) ...[
          SubChartHeader(
            label: indicators.obvLabel ?? 'OBV',
            labelColor: const Color(0xFF10B981),
            signal: indicators.obvSignal,
          ),
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
        ],
      ],
    );
  }
}
