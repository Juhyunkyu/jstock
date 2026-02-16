import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/ohlc_data.dart';

/// 미니 캔들스틱 차트 위젯
///
/// 대시보드용 소형 캔들스틱 차트로 OHLC 데이터를 시각화합니다.
class MiniCandlestickChart extends StatelessWidget {
  final List<OHLCData> data;
  final double height;
  final Color? positiveColor;
  final Color? negativeColor;

  const MiniCandlestickChart({
    super.key,
    required this.data,
    this.height = 80,
    this.positiveColor,
    this.negativeColor,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            '차트 데이터 없음',
            style: TextStyle(
              color: context.appTextSecondary,
              fontSize: 12,
            ),
          ),
        ),
      );
    }

    final upColor = positiveColor ?? AppColors.green500;
    final downColor = negativeColor ?? AppColors.red500;

    // Y축 범위 계산
    double minY = double.infinity;
    double maxY = double.negativeInfinity;
    for (final candle in data) {
      if (candle.low < minY) minY = candle.low;
      if (candle.high > maxY) maxY = candle.high;
    }

    // 여백 추가
    final range = maxY - minY;
    final padding = range * 0.1;
    minY -= padding;
    maxY += padding;

    return SizedBox(
      height: height,
      child: CustomPaint(
        size: Size.infinite,
        painter: _CandlestickPainter(
          data: data,
          minY: minY,
          maxY: maxY,
          upColor: upColor,
          downColor: downColor,
        ),
      ),
    );
  }
}

class _CandlestickPainter extends CustomPainter {
  final List<OHLCData> data;
  final double minY;
  final double maxY;
  final Color upColor;
  final Color downColor;

  _CandlestickPainter({
    required this.data,
    required this.minY,
    required this.maxY,
    required this.upColor,
    required this.downColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final candleWidth = size.width / data.length * 0.6;
    final spacing = size.width / data.length;
    final yRange = maxY - minY;

    for (int i = 0; i < data.length; i++) {
      final candle = data[i];
      final x = spacing * i + spacing / 2;

      final isUp = candle.close >= candle.open;
      final color = isUp ? upColor : downColor;

      // 심지 (high-low)
      final highY = size.height - ((candle.high - minY) / yRange * size.height);
      final lowY = size.height - ((candle.low - minY) / yRange * size.height);

      final wickPaint = Paint()
        ..color = color
        ..strokeWidth = 1;

      canvas.drawLine(
        Offset(x, highY),
        Offset(x, lowY),
        wickPaint,
      );

      // 몸통 (open-close)
      final openY = size.height - ((candle.open - minY) / yRange * size.height);
      final closeY = size.height - ((candle.close - minY) / yRange * size.height);

      final bodyPaint = Paint()
        ..color = color
        ..style = isUp ? PaintingStyle.fill : PaintingStyle.fill;

      final bodyRect = Rect.fromPoints(
        Offset(x - candleWidth / 2, openY),
        Offset(x + candleWidth / 2, closeY),
      );

      // 몸통이 너무 작으면 최소 높이 보장
      if ((openY - closeY).abs() < 1) {
        canvas.drawLine(
          Offset(x - candleWidth / 2, openY),
          Offset(x + candleWidth / 2, openY),
          wickPaint..strokeWidth = 2,
        );
      } else {
        canvas.drawRect(bodyRect, bodyPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CandlestickPainter oldDelegate) {
    return data != oldDelegate.data ||
        minY != oldDelegate.minY ||
        maxY != oldDelegate.maxY;
  }
}

/// 간단한 라인 차트 (대안)
class MiniLineChart extends StatelessWidget {
  final List<OHLCData> data;
  final double height;
  final Color? lineColor;
  final Color? gradientColor;

  const MiniLineChart({
    super.key,
    required this.data,
    this.height = 80,
    this.lineColor,
    this.gradientColor,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            '차트 데이터 없음',
            style: TextStyle(
              color: context.appTextSecondary,
              fontSize: 12,
            ),
          ),
        ),
      );
    }

    // 상승/하락 판별
    final firstClose = data.first.close;
    final lastClose = data.last.close;
    final isPositive = lastClose >= firstClose;
    final color = lineColor ??
        (isPositive ? AppColors.green500 : AppColors.red500);
    final gradient = gradientColor ?? color.withValues(alpha: 0.2);

    // Y축 범위 계산
    double minY = double.infinity;
    double maxY = double.negativeInfinity;
    for (final candle in data) {
      if (candle.close < minY) minY = candle.close;
      if (candle.close > maxY) maxY = candle.close;
    }

    final range = maxY - minY;
    final padding = range * 0.1;
    minY -= padding;
    maxY += padding;

    // 스팟 데이터 생성
    final spots = data.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.close);
    }).toList();

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          minY: minY,
          maxY: maxY,
          lineTouchData: const LineTouchData(enabled: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.3,
              color: color,
              barWidth: 2,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: gradient,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
