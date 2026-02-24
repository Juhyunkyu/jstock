import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/ohlc_data.dart';
import '../../../data/services/technical_indicator_service.dart';

/// 메인 캔들스틱 + MA + 피봇 + 볼린저밴드 + 일목균형표
class DetailCandlestickPainter extends CustomPainter {
  final List<OHLCData> data;
  final List<double> ma5;
  final List<double> ma20;
  final List<double> ma60;
  final List<double> ma120;
  final String selectedPeriod;
  final bool showPivotLines;
  final Map<String, double>? pivotLevels;
  final List<BBResult>? bollingerBands;
  final List<IchimokuResult>? ichimoku;
  final String? bbSummary;
  final String? ichSummary;
  final IndicatorSignal? bbSignal;
  final IndicatorSignal? ichSignal;
  final bool isDarkMode;
  final Color textColor;
  final Color cardBgColor;
  final double? currentPrice;
  final double? previousClose;

  DetailCandlestickPainter({
    required this.data,
    required this.ma5,
    required this.ma20,
    required this.ma60,
    required this.ma120,
    required this.selectedPeriod,
    this.showPivotLines = false,
    this.pivotLevels,
    this.bollingerBands,
    this.ichimoku,
    this.bbSummary,
    this.ichSummary,
    this.bbSignal,
    this.ichSignal,
    required this.isDarkMode,
    required this.textColor,
    required this.cardBgColor,
    this.currentPrice,
    this.previousClose,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    // 오버레이(BB/일목) 개수에 따라 상단 여백 동적 확장
    final int overlayCount = (bbSummary != null ? 1 : 0) + (ichSummary != null ? 1 : 0);
    final double topPadding = 30.0 + overlayCount * 16.0;
    const double bottomPadding = 25;
    const double rightPadding = 50;
    const double leftPadding = 10;

    final chartWidth = size.width - leftPadding - rightPadding;
    final chartHeight = size.height - topPadding - bottomPadding;

    double minY = double.infinity;
    double maxY = double.negativeInfinity;

    int highIdx = 0;
    int lowIdx = 0;
    for (int i = 0; i < data.length; i++) {
      final candle = data[i];
      if (candle.low < minY) { minY = candle.low; lowIdx = i; }
      if (candle.high > maxY) { maxY = candle.high; highIdx = i; }
    }

    for (final ma in [ma5, ma20, ma60, ma120]) {
      for (final v in ma) {
        if (!v.isNaN) {
          if (v < minY) minY = v;
          if (v > maxY) maxY = v;
        }
      }
    }

    // BB 범위 포함
    if (bollingerBands != null) {
      for (final bb in bollingerBands!) {
        if (bb.upper != null && bb.upper! > maxY) maxY = bb.upper!;
        if (bb.lower != null && bb.lower! < minY) minY = bb.lower!;
      }
    }

    // 일목균형표 범위 포함
    if (ichimoku != null) {
      for (final ich in ichimoku!) {
        for (final v in [ich.tenkan, ich.kijun, ich.senkouA, ich.senkouB, ich.chikou]) {
          if (v != null) {
            if (v > maxY) maxY = v;
            if (v < minY) minY = v;
          }
        }
      }
    }

    if (showPivotLines && pivotLevels != null) {
      for (final v in pivotLevels!.values) {
        if (v < minY) minY = v;
        if (v > maxY) maxY = v;
      }
    }

    if (currentPrice != null) {
      if (currentPrice! < minY) minY = currentPrice!;
      if (currentPrice! > maxY) maxY = currentPrice!;
    }

    final range = maxY - minY;
    final padding = range * 0.05;
    minY -= padding;
    maxY += padding;

    final candleWidth = chartWidth / data.length;
    final bodyWidth = candleWidth * 0.7;

    double toY(double value) => topPadding + (1 - (value - minY) / (maxY - minY)) * chartHeight;
    double toX(int i) => leftPadding + i * candleWidth + candleWidth / 2;

    // 일목균형표 구름 (캔들 뒤에 그리기)
    if (ichimoku != null) {
      _drawIchimoku(canvas, ichimoku!, toX, toY, data.length);
    }

    // 볼린저밴드 채움 (캔들 뒤에 그리기)
    if (bollingerBands != null) {
      _drawBollingerBands(canvas, bollingerBands!, toX, toY, data.length);
    }

    // 캔들스틱
    for (int i = 0; i < data.length; i++) {
      final candle = data[i];
      final x = toX(i);

      final openY = toY(candle.open);
      final closeY = toY(candle.close);
      final highY = toY(candle.high);
      final lowY = toY(candle.low);

      final isUp = candle.close >= candle.open;
      final color = isUp ? AppColors.stockUp : AppColors.stockDown;

      canvas.drawLine(Offset(x, highY), Offset(x, lowY), Paint()..color = color..strokeWidth = 1);

      final bodyPaint = Paint()
        ..color = color
        ..style = isUp ? PaintingStyle.stroke : PaintingStyle.fill
        ..strokeWidth = 1;

      final bodyTop = isUp ? closeY : openY;
      final bodyBottom = isUp ? openY : closeY;
      final bodyH = (bodyBottom - bodyTop).abs();

      canvas.drawRect(
        Rect.fromLTWH(x - bodyWidth / 2, bodyTop, bodyWidth, bodyH < 1 ? 1 : bodyH),
        bodyPaint,
      );
    }

    // MA 선
    _drawMA(canvas, ma5, const Color(0xFFFF6B6B), chartWidth, chartHeight, minY, maxY, leftPadding, topPadding);
    _drawMA(canvas, ma20, const Color(0xFFFFD93D), chartWidth, chartHeight, minY, maxY, leftPadding, topPadding);
    _drawMA(canvas, ma60, const Color(0xFF6BCB77), chartWidth, chartHeight, minY, maxY, leftPadding, topPadding);
    _drawMA(canvas, ma120, const Color(0xFF4D96FF), chartWidth, chartHeight, minY, maxY, leftPadding, topPadding);

    // 피봇 포인트
    if (showPivotLines && pivotLevels != null) {
      _drawPivotLines(canvas, size, pivotLevels!, chartWidth, chartHeight, minY, maxY, leftPadding, topPadding, rightPadding);
    }

    // BB/Ichimoku summary overlay (캔버스 상단 고정 위치, topPadding이 공간 확보)
    double overlayY = 2;
    if (bbSummary != null) {
      overlayY = _paintOverlaySummary(canvas, bbSummary!, leftPadding + 2, overlayY, size.width - leftPadding - rightPadding, bbSignal);
    }
    if (ichSummary != null) {
      overlayY = _paintOverlaySummary(canvas, ichSummary!, leftPadding + 2, overlayY, size.width - leftPadding - rightPadding, ichSignal);
    }

    _drawYAxisLabels(canvas, size, minY, maxY, topPadding, chartHeight, rightPadding);
    _drawHighLowMarkers(canvas, size, toX, toY, leftPadding, rightPadding, highIdx, lowIdx);
    _drawCurrentPriceLabel(canvas, size, toY, topPadding, chartHeight, rightPadding);
    _drawXAxisLabels(canvas, size, leftPadding, chartWidth, topPadding, chartHeight, bottomPadding);
  }

  /// Paint overlay summary at fixed position (동적 topPadding이 공간 확보).
  double _paintOverlaySummary(Canvas canvas, String text, double x, double y, double maxWidth, IndicatorSignal? signal) {
    final textSpan = TextSpan(
      text: text,
      style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.w600),
    );
    final textPainter = TextPainter(text: textSpan, textDirection: ui.TextDirection.ltr);
    textPainter.layout(maxWidth: maxWidth);

    final bgRect = Rect.fromLTWH(x - 2, y - 1, textPainter.width + 4, textPainter.height + 2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(bgRect, const Radius.circular(2)),
      Paint()..color = cardBgColor.withValues(alpha: 0.9),
    );
    textPainter.paint(canvas, Offset(x, y));

    return y + textPainter.height + 4;
  }

  void _drawBollingerBands(Canvas canvas, List<BBResult> bb, double Function(int) toX, double Function(double) toY, int len) {
    // Fill between upper and lower
    final fillPath = Path();
    final upperPath = Path();
    final lowerPath = Path();
    final middlePath = Path();
    bool fillStarted = false;
    bool upperStarted = false;
    bool lowerStarted = false;
    bool middleStarted = false;

    final lowerPoints = <Offset>[];

    for (int i = 0; i < bb.length && i < len; i++) {
      if (bb[i].upper == null) continue;
      final x = toX(i);
      final uy = toY(bb[i].upper!);
      final ly = toY(bb[i].lower!);
      final my = toY(bb[i].middle!);

      if (!fillStarted) {
        fillPath.moveTo(x, uy);
        fillStarted = true;
      } else {
        fillPath.lineTo(x, uy);
      }
      lowerPoints.add(Offset(x, ly));

      if (!upperStarted) { upperPath.moveTo(x, uy); upperStarted = true; } else { upperPath.lineTo(x, uy); }
      if (!lowerStarted) { lowerPath.moveTo(x, ly); lowerStarted = true; } else { lowerPath.lineTo(x, ly); }
      if (!middleStarted) { middlePath.moveTo(x, my); middleStarted = true; } else { middlePath.lineTo(x, my); }
    }

    // Close fill path
    if (fillStarted && lowerPoints.isNotEmpty) {
      for (int i = lowerPoints.length - 1; i >= 0; i--) {
        fillPath.lineTo(lowerPoints[i].dx, lowerPoints[i].dy);
      }
      fillPath.close();
      canvas.drawPath(fillPath, Paint()..color = const Color(0xFF2196F3).withAlpha(13)..style = PaintingStyle.fill);
    }

    // Lines
    final linePaint = Paint()..color = const Color(0xFF2196F3).withAlpha(128)..strokeWidth = 1..style = PaintingStyle.stroke;
    if (upperStarted) canvas.drawPath(upperPath, linePaint);
    if (lowerStarted) canvas.drawPath(lowerPath, linePaint);

    // Middle line (dashed)
    if (middleStarted) {
      final dashPaint = Paint()..color = const Color(0xFF2196F3).withAlpha(80)..strokeWidth = 1..style = PaintingStyle.stroke;
      canvas.drawPath(middlePath, dashPaint);
    }
  }

  void _drawIchimoku(Canvas canvas, List<IchimokuResult> ich, double Function(int) toX, double Function(double) toY, int len) {
    // Tenkan (red)
    _drawIchimokuLine(canvas, ich, len, (r) => r.tenkan, toX, toY, AppColors.stockUp);
    // Kijun (blue)
    _drawIchimokuLine(canvas, ich, len, (r) => r.kijun, toX, toY, const Color(0xFF2196F3));
    // Chikou (green)
    _drawIchimokuLine(canvas, ich, len, (r) => r.chikou, toX, toY, const Color(0xFF4CAF50).withAlpha(178));

    // Cloud fill between senkouA and senkouB
    for (int i = 0; i < ich.length - 1 && i < len - 1; i++) {
      final a1 = ich[i].senkouA;
      final b1 = ich[i].senkouB;
      final a2 = ich[i + 1].senkouA;
      final b2 = ich[i + 1].senkouB;
      if (a1 == null || b1 == null || a2 == null || b2 == null) continue;

      final x1 = toX(i);
      final x2 = toX(i + 1);
      final isUp = a1 >= b1;
      final color = isUp
          ? AppColors.stockUp.withAlpha(26)
          : AppColors.stockDown.withAlpha(26);

      final path = Path()
        ..moveTo(x1, toY(a1))
        ..lineTo(x2, toY(a2))
        ..lineTo(x2, toY(b2))
        ..lineTo(x1, toY(b1))
        ..close();
      canvas.drawPath(path, Paint()..color = color..style = PaintingStyle.fill);
    }

    // SenkouA line
    _drawIchimokuLine(canvas, ich, len, (r) => r.senkouA, toX, toY, AppColors.stockUp.withAlpha(128));
    // SenkouB line
    _drawIchimokuLine(canvas, ich, len, (r) => r.senkouB, toX, toY, AppColors.stockDown.withAlpha(128));
  }

  void _drawIchimokuLine(Canvas canvas, List<IchimokuResult> ich, int len, double? Function(IchimokuResult) getValue, double Function(int) toX, double Function(double) toY, Color color) {
    final path = Path();
    bool started = false;
    for (int i = 0; i < ich.length && i < len; i++) {
      final v = getValue(ich[i]);
      if (v == null) continue;
      final x = toX(i);
      final y = toY(v);
      if (!started) { path.moveTo(x, y); started = true; } else { path.lineTo(x, y); }
    }
    if (started) {
      canvas.drawPath(path, Paint()..color = color..strokeWidth = 1..style = PaintingStyle.stroke);
    }
  }

  void _drawMA(Canvas canvas, List<double> ma, Color color, double chartWidth, double chartHeight, double minY, double maxY, double leftPadding, double topPadding) {
    if (ma.isEmpty) return;
    final paint = Paint()..color = color..strokeWidth = 1.5..style = PaintingStyle.stroke;
    final path = Path();
    bool started = false;
    final candleWidth = chartWidth / data.length;

    for (int i = 0; i < ma.length && i < data.length; i++) {
      if (ma[i].isNaN) continue;
      final x = leftPadding + i * candleWidth + candleWidth / 2;
      final y = topPadding + (1 - (ma[i] - minY) / (maxY - minY)) * chartHeight;
      if (!started) { path.moveTo(x, y); started = true; } else { path.lineTo(x, y); }
    }
    canvas.drawPath(path, paint);
  }

  void _drawPivotLines(Canvas canvas, Size size, Map<String, double> levels, double chartWidth, double chartHeight, double minY, double maxY, double leftPadding, double topPadding, double rightPadding) {
    final colorMap = {
      'R2': AppColors.stockUp.withAlpha(178),
      'R1': AppColors.stockUp.withAlpha(178),
      'P': const Color(0xFF6B7280),
      'S1': AppColors.stockDown.withAlpha(178),
      'S2': AppColors.stockDown.withAlpha(178),
    };

    for (final entry in levels.entries) {
      final key = entry.key;
      final value = entry.value;
      final y = topPadding + (1 - (value - minY) / (maxY - minY)) * chartHeight;
      if (y < topPadding || y > topPadding + chartHeight) continue;

      final color = colorMap[key] ?? const Color(0xFF9CA3AF);
      final paint = Paint()..color = color..strokeWidth = 1.5..style = PaintingStyle.stroke;

      const dashWidth = 4.0;
      const dashSpace = 3.0;
      double startX = leftPadding;
      final endX = leftPadding + chartWidth;
      while (startX < endX) {
        canvas.drawLine(Offset(startX, y), Offset((startX + dashWidth).clamp(0, endX), y), paint);
        startX += dashWidth + dashSpace;
      }

      final textSpan = TextSpan(text: key, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700));
      final textPainter = TextPainter(text: textSpan, textDirection: ui.TextDirection.ltr);
      textPainter.layout();
      textPainter.paint(canvas, Offset(leftPadding + 2, y - textPainter.height - 1));
    }
  }

  void _drawYAxisLabels(Canvas canvas, Size size, double minY, double maxY, double topPadding, double chartHeight, double rightPadding) {
    final values = [maxY, (maxY * 2 + minY) / 3, (maxY + minY * 2) / 3, minY];
    final yPositions = [topPadding, topPadding + chartHeight / 3, topPadding + chartHeight * 2 / 3, topPadding + chartHeight];

    for (int i = 0; i < values.length; i++) {
      final textSpan = TextSpan(text: _formatAxisPrice(values[i]), style: TextStyle(color: textColor, fontSize: 10));
      final textPainter = TextPainter(text: textSpan, textDirection: ui.TextDirection.ltr);
      textPainter.layout();
      textPainter.paint(canvas, Offset(size.width - rightPadding + 8, yPositions[i] - textPainter.height / 2));
    }
  }

  void _drawXAxisLabels(Canvas canvas, Size size, double leftPadding, double chartWidth, double topPadding, double chartHeight, double bottomPadding) {
    if (data.isEmpty) return;
    const labelCount = 5;
    final step = (data.length / labelCount).floor();

    for (int i = 0; i < labelCount; i++) {
      final idx = (i * step).clamp(0, data.length - 1);
      final date = data[idx].date;
      final x = leftPadding + idx * (chartWidth / data.length) + (chartWidth / data.length) / 2;

      String label;
      switch (selectedPeriod) {
        case '일봉': label = DateFormat('MM/dd').format(date); break;
        case '주봉': label = DateFormat('yy/MM').format(date); break;
        case '월봉': label = DateFormat('yyyy').format(date); break;
        default: label = DateFormat('MM/dd').format(date);
      }

      final textSpan = TextSpan(text: label, style: TextStyle(color: textColor, fontSize: 10));
      final textPainter = TextPainter(text: textSpan, textDirection: ui.TextDirection.ltr);
      textPainter.layout();
      textPainter.paint(canvas, Offset(x - textPainter.width / 2, topPadding + chartHeight + 6));
    }
  }

  /// 마커 라벨 텍스트 생성 (가격 + %변동 + 날짜)
  String _buildMarkerLabel(double price, DateTime date) {
    final p = _formatMarkerPrice(price);
    String pct = '';
    if (currentPrice != null && currentPrice! > 0) {
      final v = ((price - currentPrice!) / currentPrice!) * 100;
      pct = ' (${v >= 0 ? '+' : ''}${v.toStringAsFixed(1)}%)';
    }
    return '$p$pct ${DateFormat('MM/dd').format(date)}';
  }

  void _drawHighLowMarkers(Canvas canvas, Size size, double Function(int) toX, double Function(double) toY, double leftPadding, double rightPadding, int highIdx, int lowIdx) {
    if (data.isEmpty) return;

    final highCandle = data[highIdx];
    final lowCandle = data[lowIdx];

    // --- 최고가 마커 ---
    final highX = toX(highIdx);
    final highY = toY(highCandle.high);

    // ▽ triangle
    final highTriPath = Path()
      ..moveTo(highX - 3, highY - 6)
      ..lineTo(highX + 3, highY - 6)
      ..lineTo(highX, highY - 2)
      ..close();
    canvas.drawPath(highTriPath, Paint()..color = AppColors.stockUp..style = PaintingStyle.fill);

    final highLabel = _buildMarkerLabel(highCandle.high, highCandle.date);
    final highSpan = TextSpan(
      text: highLabel,
      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600),
    );
    final highPainter = TextPainter(text: highSpan, textDirection: ui.TextDirection.ltr);
    highPainter.layout();

    final highLabelX = (highX - highPainter.width / 2).clamp(leftPadding, size.width - rightPadding - highPainter.width);
    final highLabelY = highY - 8 - highPainter.height;

    final highBgRect = Rect.fromLTWH(highLabelX - 3, highLabelY - 2, highPainter.width + 6, highPainter.height + 4);
    canvas.drawRRect(
      RRect.fromRectAndRadius(highBgRect, const Radius.circular(3)),
      Paint()..color = AppColors.stockUp.withAlpha(204),
    );
    highPainter.paint(canvas, Offset(highLabelX, highLabelY));

    // --- 최저가 마커 ---
    final lowX = toX(lowIdx);
    final lowY = toY(lowCandle.low);

    // △ triangle
    final lowTriPath = Path()
      ..moveTo(lowX - 3, lowY + 6)
      ..lineTo(lowX + 3, lowY + 6)
      ..lineTo(lowX, lowY + 2)
      ..close();
    canvas.drawPath(lowTriPath, Paint()..color = AppColors.stockDown..style = PaintingStyle.fill);

    final lowLabel = _buildMarkerLabel(lowCandle.low, lowCandle.date);
    final lowSpan = TextSpan(
      text: lowLabel,
      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600),
    );
    final lowPainter = TextPainter(text: lowSpan, textDirection: ui.TextDirection.ltr);
    lowPainter.layout();

    final lowLabelX = (lowX - lowPainter.width / 2).clamp(leftPadding, size.width - rightPadding - lowPainter.width);
    final lowLabelY = lowY + 8;

    final lowBgRect = Rect.fromLTWH(lowLabelX - 3, lowLabelY - 2, lowPainter.width + 6, lowPainter.height + 4);
    canvas.drawRRect(
      RRect.fromRectAndRadius(lowBgRect, const Radius.circular(3)),
      Paint()..color = AppColors.stockDown.withAlpha(204),
    );
    lowPainter.paint(canvas, Offset(lowLabelX, lowLabelY));
  }

  void _drawCurrentPriceLabel(Canvas canvas, Size size, double Function(double) toY, double topPadding, double chartHeight, double rightPadding) {
    if (currentPrice == null) return;

    final priceY = toY(currentPrice!);
    if (priceY < topPadding - 5 || priceY > topPadding + chartHeight + 5) return;

    final isUp = previousClose == null || currentPrice! >= previousClose!;
    final badgeColor = isUp ? AppColors.stockUp : AppColors.stockDown;

    final priceText = _formatMarkerPrice(currentPrice!);
    final textSpan = TextSpan(
      text: priceText,
      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
    );
    final textPainter = TextPainter(text: textSpan, textDirection: ui.TextDirection.ltr);
    textPainter.layout();

    final badgeWidth = textPainter.width + 8;
    final badgeHeight = textPainter.height + 4;
    final badgeX = size.width - rightPadding + 4;
    final badgeY = priceY - badgeHeight / 2;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(badgeX, badgeY, badgeWidth, badgeHeight),
        const Radius.circular(3),
      ),
      Paint()..color = badgeColor,
    );
    textPainter.paint(canvas, Offset(badgeX + 4, badgeY + 2));
  }

  String _formatMarkerPrice(double price) {
    String formatted;
    if (price >= 10000) {
      formatted = price.toStringAsFixed(0);
    } else if (price >= 100) {
      formatted = price.toStringAsFixed(1);
    } else {
      formatted = price.toStringAsFixed(2);
    }
    return formatted.replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]},',
    );
  }

  String _formatAxisPrice(double price) {
    if (price >= 10000) return '${(price / 1000).toStringAsFixed(1)}K';
    if (price >= 1000) return '${(price / 1000).toStringAsFixed(2)}K';
    return price.toStringAsFixed(0);
  }

  @override
  bool shouldRepaint(covariant DetailCandlestickPainter oldDelegate) => true;
}
