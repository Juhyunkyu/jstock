import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/ohlc_data.dart';
import '../../../data/services/technical_indicator_service.dart';

/// 거래량 서브차트
class VolumePainter extends CustomPainter {
  final List<OHLCData> data;
  final bool isDarkMode;
  final Color textColor;
  VolumePainter({required this.data, required this.isDarkMode, required this.textColor});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    const double leftPadding = 10;
    const double rightPadding = 50;
    const double topPadding = 2;
    const double bottomPadding = 2;

    final chartWidth = size.width - leftPadding - rightPadding;
    final chartHeight = size.height - topPadding - bottomPadding;
    final candleWidth = chartWidth / data.length;
    final barWidth = candleWidth * 0.7;

    double maxVol = 0;
    for (final d in data) {
      if (d.volume > maxVol) maxVol = d.volume;
    }
    if (maxVol == 0) return;

    // 구분선
    final dividerColor = isDarkMode ? const Color(0xFF2D333B) : const Color(0xFFE5E7EB);
    canvas.drawLine(
      Offset(leftPadding, 0),
      Offset(leftPadding + chartWidth, 0),
      Paint()..color = dividerColor..strokeWidth = 0.5,
    );

    for (int i = 0; i < data.length; i++) {
      final d = data[i];
      final x = leftPadding + i * candleWidth + candleWidth / 2;
      final isUp = d.close >= d.open;
      final color = isUp
          ? AppColors.stockUp.withAlpha(102)
          : AppColors.stockDown.withAlpha(102);

      final barH = (d.volume / maxVol) * chartHeight;
      final top = topPadding + chartHeight - barH;

      canvas.drawRect(
        Rect.fromLTWH(x - barWidth / 2, top, barWidth, barH),
        Paint()..color = color..style = PaintingStyle.fill,
      );
    }

    // Y축 라벨 (최대 거래량)
    String volLabel;
    if (maxVol >= 1e9) {
      volLabel = '${(maxVol / 1e9).toStringAsFixed(1)}B';
    } else if (maxVol >= 1e6) {
      volLabel = '${(maxVol / 1e6).toStringAsFixed(1)}M';
    } else if (maxVol >= 1e3) {
      volLabel = '${(maxVol / 1e3).toStringAsFixed(0)}K';
    } else {
      volLabel = maxVol.toStringAsFixed(0);
    }

    final textSpan = TextSpan(text: volLabel, style: TextStyle(color: textColor.withValues(alpha: 0.7), fontSize: 12));
    final textPainter = TextPainter(text: textSpan, textDirection: ui.TextDirection.ltr);
    textPainter.layout();
    textPainter.paint(canvas, Offset(size.width - rightPadding + 8, topPadding));
  }

  @override
  bool shouldRepaint(covariant VolumePainter oldDelegate) => true;
}

/// RSI 서브차트
class RSIPainter extends CustomPainter {
  final List<double?> rsiValues;
  final bool isDarkMode;
  final Color textColor;
  RSIPainter({required this.rsiValues, this.isDarkMode = false, this.textColor = const Color(0xFF6B7280)});

  @override
  void paint(Canvas canvas, Size size) {
    if (rsiValues.isEmpty) return;

    const double leftPadding = 10;
    const double rightPadding = 50;
    const double topPadding = 4;
    const double bottomPadding = 4;

    final chartWidth = size.width - leftPadding - rightPadding;
    final chartHeight = size.height - topPadding - bottomPadding;
    final candleWidth = chartWidth / rsiValues.length;

    // 구분선
    final dividerColor = isDarkMode ? const Color(0xFF2D333B) : const Color(0xFFE5E7EB);
    canvas.drawLine(
      Offset(leftPadding, 0),
      Offset(leftPadding + chartWidth, 0),
      Paint()..color = dividerColor..strokeWidth = 0.5,
    );

    double toY(double value) => topPadding + (1 - value / 100) * chartHeight;

    // 과매수/과매도 배경
    final overboughtRect = Rect.fromLTRB(leftPadding, toY(100), leftPadding + chartWidth, toY(70));
    canvas.drawRect(overboughtRect, Paint()..color = AppColors.stockUp.withAlpha(20));

    final oversoldRect = Rect.fromLTRB(leftPadding, toY(30), leftPadding + chartWidth, toY(0));
    canvas.drawRect(oversoldRect, Paint()..color = AppColors.stockDown.withAlpha(20));

    // 기준선 (30, 50, 70)
    final gridColor = isDarkMode ? const Color(0xFF374151) : const Color(0xFFD1D5DB);
    for (final level in [30.0, 50.0, 70.0]) {
      final y = toY(level);
      final paint = Paint()..color = gridColor..strokeWidth = 0.5;
      const dashWidth = 3.0;
      const dashSpace = 3.0;
      double startX = leftPadding;
      while (startX < leftPadding + chartWidth) {
        canvas.drawLine(Offset(startX, y), Offset((startX + dashWidth).clamp(0, leftPadding + chartWidth), y), paint);
        startX += dashWidth + dashSpace;
      }
    }

    // RSI 선
    final path = Path();
    bool started = false;
    for (int i = 0; i < rsiValues.length; i++) {
      if (rsiValues[i] == null) continue;
      final x = leftPadding + i * candleWidth + candleWidth / 2;
      final y = toY(rsiValues[i]!);
      if (!started) { path.moveTo(x, y); started = true; } else { path.lineTo(x, y); }
    }
    if (started) {
      final rsiLineColor = isDarkMode ? const Color(0xFFCE93D8) : const Color(0xFF7B1FA2);
      canvas.drawPath(path, Paint()..color = rsiLineColor..strokeWidth = 1.5..style = PaintingStyle.stroke);
    }

    // Y축 라벨
    for (final label in [
      {'value': 70, 'text': '70'},
      {'value': 50, 'text': '50'},
      {'value': 30, 'text': '30'},
    ]) {
      final y = toY((label['value'] as int).toDouble());
      final textSpan = TextSpan(text: label['text'] as String, style: TextStyle(color: textColor.withValues(alpha: 0.7), fontSize: 12));
      final textPainter = TextPainter(text: textSpan, textDirection: ui.TextDirection.ltr);
      textPainter.layout();
      textPainter.paint(canvas, Offset(size.width - rightPadding + 8, y - textPainter.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant RSIPainter oldDelegate) => true;
}

/// MACD 서브차트
class MACDPainter extends CustomPainter {
  final List<MACDResult> macdValues;
  final bool isDarkMode;
  final Color textColor;
  MACDPainter({required this.macdValues, this.isDarkMode = false, this.textColor = const Color(0xFF6B7280)});

  @override
  void paint(Canvas canvas, Size size) {
    if (macdValues.isEmpty) return;

    const double leftPadding = 10;
    const double rightPadding = 50;
    const double topPadding = 4;
    const double bottomPadding = 4;

    final chartWidth = size.width - leftPadding - rightPadding;
    final chartHeight = size.height - topPadding - bottomPadding;
    final candleWidth = chartWidth / macdValues.length;

    // 구분선
    final dividerColor = isDarkMode ? const Color(0xFF2D333B) : const Color(0xFFE5E7EB);
    canvas.drawLine(
      Offset(leftPadding, 0),
      Offset(leftPadding + chartWidth, 0),
      Paint()..color = dividerColor..strokeWidth = 0.5,
    );

    // Y 범위
    double maxVal = 0;
    for (final m in macdValues) {
      if (m.macdLine != null && m.macdLine!.abs() > maxVal) maxVal = m.macdLine!.abs();
      if (m.signalLine != null && m.signalLine!.abs() > maxVal) maxVal = m.signalLine!.abs();
      if (m.histogram != null && m.histogram!.abs() > maxVal) maxVal = m.histogram!.abs();
    }
    if (maxVal == 0) maxVal = 1;
    maxVal *= 1.1;

    double toY(double value) => topPadding + chartHeight / 2 - (value / maxVal) * (chartHeight / 2);
    double toX(int i) => leftPadding + i * candleWidth + candleWidth / 2;

    // 0선
    final gridColor = isDarkMode ? const Color(0xFF374151) : const Color(0xFFD1D5DB);
    final zeroY = toY(0);
    canvas.drawLine(
      Offset(leftPadding, zeroY),
      Offset(leftPadding + chartWidth, zeroY),
      Paint()..color = gridColor..strokeWidth = 0.5,
    );

    // 히스토그램
    final barWidth = candleWidth * 0.6;
    for (int i = 0; i < macdValues.length; i++) {
      final h = macdValues[i].histogram;
      if (h == null) continue;
      final x = toX(i);
      final y = toY(h);
      final isPositive = h >= 0;
      final color = isPositive
          ? AppColors.stockUp.withAlpha(153)
          : AppColors.stockDown.withAlpha(153);

      if (isPositive) {
        canvas.drawRect(Rect.fromLTRB(x - barWidth / 2, y, x + barWidth / 2, zeroY), Paint()..color = color);
      } else {
        canvas.drawRect(Rect.fromLTRB(x - barWidth / 2, zeroY, x + barWidth / 2, y), Paint()..color = color);
      }
    }

    // MACD 선
    _drawLine(canvas, macdValues, (m) => m.macdLine, toX, toY, const Color(0xFF2196F3), 1.5);
    // Signal 선
    _drawLine(canvas, macdValues, (m) => m.signalLine, toX, toY, const Color(0xFFFF9800), 1.5);

    // Y축 라벨
    final labels = [maxVal, 0.0, -maxVal];
    for (final v in labels) {
      final y = toY(v);
      final text = v == 0 ? '0' : v.toStringAsFixed(1);
      final textSpan = TextSpan(text: text, style: TextStyle(color: textColor.withValues(alpha: 0.7), fontSize: 12));
      final textPainter = TextPainter(text: textSpan, textDirection: ui.TextDirection.ltr);
      textPainter.layout();
      textPainter.paint(canvas, Offset(size.width - rightPadding + 8, y - textPainter.height / 2));
    }
  }

  void _drawLine(Canvas canvas, List<MACDResult> values, double? Function(MACDResult) getValue, double Function(int) toX, double Function(double) toY, Color color, double width) {
    final path = Path();
    bool started = false;
    for (int i = 0; i < values.length; i++) {
      final v = getValue(values[i]);
      if (v == null) continue;
      final x = toX(i);
      final y = toY(v);
      if (!started) { path.moveTo(x, y); started = true; } else { path.lineTo(x, y); }
    }
    if (started) {
      canvas.drawPath(path, Paint()..color = color..strokeWidth = width..style = PaintingStyle.stroke);
    }
  }

  @override
  bool shouldRepaint(covariant MACDPainter oldDelegate) => true;
}

/// 스토캐스틱 서브차트
class StochasticPainter extends CustomPainter {
  final List<StochResult> stochValues;
  final bool isDarkMode;
  final Color textColor;
  StochasticPainter({required this.stochValues, this.isDarkMode = false, this.textColor = const Color(0xFF6B7280)});

  @override
  void paint(Canvas canvas, Size size) {
    if (stochValues.isEmpty) return;

    const double leftPadding = 10;
    const double rightPadding = 50;
    const double topPadding = 4;
    const double bottomPadding = 4;

    final chartWidth = size.width - leftPadding - rightPadding;
    final chartHeight = size.height - topPadding - bottomPadding;
    final candleWidth = chartWidth / stochValues.length;

    // 구분선
    final dividerColor = isDarkMode ? const Color(0xFF2D333B) : const Color(0xFFE5E7EB);
    canvas.drawLine(
      Offset(leftPadding, 0),
      Offset(leftPadding + chartWidth, 0),
      Paint()..color = dividerColor..strokeWidth = 0.5,
    );

    double toY(double value) => topPadding + (1 - value / 100) * chartHeight;

    // 과매수/과매도 배경
    canvas.drawRect(
      Rect.fromLTRB(leftPadding, toY(100), leftPadding + chartWidth, toY(80)),
      Paint()..color = AppColors.stockUp.withAlpha(20),
    );
    canvas.drawRect(
      Rect.fromLTRB(leftPadding, toY(20), leftPadding + chartWidth, toY(0)),
      Paint()..color = AppColors.stockDown.withAlpha(20),
    );

    // 기준선 (20, 50, 80)
    final gridColor = isDarkMode ? const Color(0xFF374151) : const Color(0xFFD1D5DB);
    for (final level in [20.0, 50.0, 80.0]) {
      final y = toY(level);
      final paint = Paint()..color = gridColor..strokeWidth = 0.5;
      const dashWidth = 3.0;
      const dashSpace = 3.0;
      double startX = leftPadding;
      while (startX < leftPadding + chartWidth) {
        canvas.drawLine(Offset(startX, y), Offset((startX + dashWidth).clamp(0, leftPadding + chartWidth), y), paint);
        startX += dashWidth + dashSpace;
      }
    }

    // %K 선
    final kPath = Path();
    bool kStarted = false;
    for (int i = 0; i < stochValues.length; i++) {
      if (stochValues[i].k == null) continue;
      final x = leftPadding + i * candleWidth + candleWidth / 2;
      final y = toY(stochValues[i].k!);
      if (!kStarted) { kPath.moveTo(x, y); kStarted = true; } else { kPath.lineTo(x, y); }
    }
    if (kStarted) {
      canvas.drawPath(kPath, Paint()..color = const Color(0xFF2196F3)..strokeWidth = 1.5..style = PaintingStyle.stroke);
    }

    // %D 선
    final dPath = Path();
    bool dStarted = false;
    for (int i = 0; i < stochValues.length; i++) {
      if (stochValues[i].d == null) continue;
      final x = leftPadding + i * candleWidth + candleWidth / 2;
      final y = toY(stochValues[i].d!);
      if (!dStarted) { dPath.moveTo(x, y); dStarted = true; } else { dPath.lineTo(x, y); }
    }
    if (dStarted) {
      canvas.drawPath(dPath, Paint()..color = const Color(0xFFFF9800)..strokeWidth = 1.5..style = PaintingStyle.stroke);
    }

    // Y축 라벨
    for (final label in [
      {'value': 80, 'text': '80'},
      {'value': 50, 'text': '50'},
      {'value': 20, 'text': '20'},
    ]) {
      final y = toY((label['value'] as int).toDouble());
      final textSpan = TextSpan(text: label['text'] as String, style: TextStyle(color: textColor.withValues(alpha: 0.7), fontSize: 12));
      final textPainter = TextPainter(text: textSpan, textDirection: ui.TextDirection.ltr);
      textPainter.layout();
      textPainter.paint(canvas, Offset(size.width - rightPadding + 8, y - textPainter.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant StochasticPainter oldDelegate) => true;
}

/// OBV 서브차트
class OBVPainter extends CustomPainter {
  final List<double> obvValues;
  final bool isDarkMode;
  final Color textColor;
  OBVPainter({required this.obvValues, this.isDarkMode = false, this.textColor = const Color(0xFF6B7280)});

  @override
  void paint(Canvas canvas, Size size) {
    if (obvValues.isEmpty) return;

    const double leftPadding = 10;
    const double rightPadding = 50;
    const double topPadding = 4;
    const double bottomPadding = 4;

    final chartWidth = size.width - leftPadding - rightPadding;
    final chartHeight = size.height - topPadding - bottomPadding;
    final candleWidth = chartWidth / obvValues.length;

    // 구분선
    final dividerColor = isDarkMode ? const Color(0xFF2D333B) : const Color(0xFFE5E7EB);
    canvas.drawLine(
      Offset(leftPadding, 0),
      Offset(leftPadding + chartWidth, 0),
      Paint()..color = dividerColor..strokeWidth = 0.5,
    );

    // Y 범위
    double minVal = double.infinity;
    double maxVal = double.negativeInfinity;
    for (final v in obvValues) {
      if (v < minVal) minVal = v;
      if (v > maxVal) maxVal = v;
    }
    if (minVal == maxVal) { maxVal += 1; minVal -= 1; }
    final range = maxVal - minVal;
    final padY = range * 0.05;
    minVal -= padY;
    maxVal += padY;

    double toY(double value) => topPadding + (1 - (value - minVal) / (maxVal - minVal)) * chartHeight;

    // OBV 선
    final path = Path();
    bool started = false;
    for (int i = 0; i < obvValues.length; i++) {
      final x = leftPadding + i * candleWidth + candleWidth / 2;
      final y = toY(obvValues[i]);
      if (!started) { path.moveTo(x, y); started = true; } else { path.lineTo(x, y); }
    }
    if (started) {
      canvas.drawPath(path, Paint()..color = const Color(0xFF10B981)..strokeWidth = 1.5..style = PaintingStyle.stroke);
    }

    // Y축 라벨
    for (final v in [maxVal, (maxVal + minVal) / 2, minVal]) {
      final y = toY(v);
      final text = _formatVolume(v);
      final textSpan = TextSpan(text: text, style: TextStyle(color: textColor.withValues(alpha: 0.7), fontSize: 12));
      final textPainter = TextPainter(text: textSpan, textDirection: ui.TextDirection.ltr);
      textPainter.layout();
      textPainter.paint(canvas, Offset(size.width - rightPadding + 8, y - textPainter.height / 2));
    }
  }

  String _formatVolume(double v) {
    final absV = v.abs();
    final sign = v < 0 ? '-' : '';
    if (absV >= 1e9) return '$sign${(absV / 1e9).toStringAsFixed(1)}B';
    if (absV >= 1e6) return '$sign${(absV / 1e6).toStringAsFixed(1)}M';
    if (absV >= 1e3) return '$sign${(absV / 1e3).toStringAsFixed(0)}K';
    return '$sign${absV.toStringAsFixed(0)}';
  }

  @override
  bool shouldRepaint(covariant OBVPainter oldDelegate) => true;
}
