import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'fear_greed_zone_panel.dart';

/// CNN-style Fear & Greed gauge widget with animation
class FearGreedGauge extends StatefulWidget {
  final int value;
  final bool isLoading;
  final Color cardBackgroundColor;
  final Color textColor;
  final bool isDarkMode;

  const FearGreedGauge({
    super.key,
    required this.value,
    this.isLoading = false,
    required this.cardBackgroundColor,
    required this.textColor,
    required this.isDarkMode,
  });

  @override
  State<FearGreedGauge> createState() => _FearGreedGaugeState();
}

class _FearGreedGaugeState extends State<FearGreedGauge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  int _previousValue = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _animation = Tween<double>(
      begin: 0,
      end: widget.value.toDouble(),
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));
    _controller.forward();
  }

  @override
  void didUpdateWidget(FearGreedGauge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _previousValue = oldWidget.value;
      _animation = Tween<double>(
        begin: _previousValue.toDouble(),
        end: widget.value.toDouble(),
      ).animate(CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ));
      _controller.reset();
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final screenW = MediaQuery.of(context).size.width;
            final maxGaugeWidth = screenW >= 1200 ? 600.0 : screenW >= 768 ? 420.0 : 550.0;
            final width = math.min(constraints.maxWidth, maxGaugeWidth);
            final gaugeHeight = width * 0.55;
            return Center(
              child: SizedBox(
                width: width,
                height: gaugeHeight,
                child: CustomPaint(
                  size: Size(width, gaugeHeight),
                  painter: _CNNFearGreedGaugePainter(
                    value: _animation.value,
                    isLoading: widget.isLoading,
                    cardBackgroundColor: widget.cardBackgroundColor,
                    textColor: widget.textColor,
                    isDarkMode: widget.isDarkMode,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// CNN-style gauge painter with triangular needle and semi-circle base
class _CNNFearGreedGaugePainter extends CustomPainter {
  final double value;
  final bool isLoading;
  final Color cardBackgroundColor;
  final Color textColor;
  final bool isDarkMode;

  // Theme-aware colors
  Color get inactiveSegment => isDarkMode
      ? const Color(0xFF2D333B)
      : const Color(0xFFF0F1F3);

  Color get activeSegment => isDarkMode
      ? const Color(0xFF3D444D)
      : const Color(0xFFDCDEE2);

  Color get needleColor => isDarkMode
      ? const Color(0xFFE6EDF3)
      : const Color(0xFF1F2937);

  Color get numberColor => isDarkMode
      ? const Color(0xFF8B949E)
      : const Color(0xFF6B7280);

  Color get activeLabelColor => isDarkMode
      ? const Color(0xFFE6EDF3)
      : const Color(0xFF1A1A1A);

  Color get inactiveLabelColor => isDarkMode
      ? const Color(0xFF8B949E)
      : const Color(0xFF4B5563);

  Color get tickColor => isDarkMode
      ? const Color(0xFF3D444D)
      : const Color(0xFFD1D5DB);

  Color get borderColor => isDarkMode
      ? const Color(0xFF4D555E)
      : const Color(0xFFB0B3B8);

  _CNNFearGreedGaugePainter({
    required this.value,
    required this.isLoading,
    required this.cardBackgroundColor,
    required this.textColor,
    required this.isDarkMode,
  });

  int _getActiveZone() {
    if (value < 25) return 0;
    if (value < 44) return 1;
    if (value < 56) return 2;
    if (value < 75) return 3;
    return 4;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final scale = (size.width / 550.0).clamp(0.7, 1.0);
    final arcThickness = 82.0 * scale;
    final radius = size.width * 0.40;
    final center = Offset(size.width / 2, size.height - 8 * scale);
    final activeZone = _getActiveZone();

    const totalSweep = math.pi;
    const gapSize = 0.015;

    // Draw each of the 5 arc segments
    for (int i = 0; i < 5; i++) {
      final startPct = fearGreedZones[i].rangeStart / 100.0;
      final endPct = fearGreedZones[i].rangeEnd / 100.0;

      double segStart = math.pi + (startPct * totalSweep);
      double segSweep = (endPct - startPct) * totalSweep;

      if (i > 0) segStart += gapSize / 2;
      if (i < 4) segSweep -= gapSize / 2;
      if (i > 0) segSweep -= gapSize / 2;

      final isActive = (i == activeZone);

      final arcPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = arcThickness
        ..strokeCap = StrokeCap.butt;

      if (isActive) {
        arcPaint.color = activeSegment;
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          segStart,
          segSweep,
          false,
          arcPaint,
        );

        final outerR = radius + arcThickness / 2;
        final innerR = radius - arcThickness / 2;
        final borderPath = Path()
          ..addArc(Rect.fromCircle(center: center, radius: outerR), segStart, segSweep)
          ..arcTo(Rect.fromCircle(center: center, radius: innerR), segStart + segSweep, -segSweep, false)
          ..close();
        final borderPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5 * scale
          ..color = borderColor;
        canvas.drawPath(borderPath, borderPaint);
      } else {
        arcPaint.color = inactiveSegment;
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          segStart,
          segSweep,
          false,
          arcPaint,
        );
      }
    }

    _drawArcLabels(canvas, center, radius, arcThickness, activeZone, scale);
    _drawNumbers(canvas, center, radius, arcThickness, scale);

    if (!isLoading) {
      _drawNeedle(canvas, center, radius, arcThickness, scale);
      _drawSemiCircleBase(canvas, center, scale);
    }
  }

  void _drawArcLabels(Canvas canvas, Offset center, double radius,
      double thickness, int activeZone, double scale) {
    final labelAngles = [
      math.pi + 0.125 * math.pi,
      math.pi + 0.345 * math.pi,
      math.pi + 0.50 * math.pi,
      math.pi + 0.655 * math.pi,
      math.pi + 0.875 * math.pi,
    ];

    for (int i = 0; i < fearGreedZones.length; i++) {
      final angle = labelAngles[i];
      final isActive = i == activeZone;
      final labelColor = isActive ? activeLabelColor : inactiveLabelColor;

      final lines = fearGreedZones[i].label.split('\n');

      double fontSize;
      fontSize = 18.0 * scale;

      final lineSpacing = fontSize + 3.0 * scale;
      final totalH = lines.length * lineSpacing;
      final baseOffset = lines.length > 1
          ? thickness * 0.3 - lineSpacing / 2
          : thickness * 0.3;

      for (int j = 0; j < lines.length; j++) {
        final lineOffset = (j * lineSpacing) - totalH / 2 + lineSpacing / 2;
        final lineRadius = radius + baseOffset - lineOffset;

        final x = center.dx + lineRadius * math.cos(angle);
        final y = center.dy + lineRadius * math.sin(angle);

        final rotation = angle + math.pi / 2;

        final tp = TextPainter(
          text: TextSpan(
            text: lines[j],
            style: TextStyle(
              color: labelColor,
              fontSize: fontSize,
              fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          textDirection: ui.TextDirection.ltr,
        );
        tp.layout();

        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(rotation);
        canvas.scale(0.75, 1.0);
        tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
        canvas.restore();
      }
    }
  }

  void _drawNumbers(
      Canvas canvas, Offset center, double radius, double thickness, double scale) {
    final numRadius = radius - thickness / 2 - 16 * scale;
    const numbers = [0, 25, 50, 75, 100];

    final dotPaint = Paint()
      ..color = numberColor
      ..style = PaintingStyle.fill;
    for (int section = 0; section < 4; section++) {
      for (int dot = 1; dot <= 4; dot++) {
        final dotValue = section * 25 + dot * 5;
        final dotAngle = math.pi + (dotValue / 100) * math.pi;
        canvas.drawCircle(
          Offset(
            center.dx + numRadius * math.cos(dotAngle),
            center.dy + numRadius * math.sin(dotAngle),
          ),
          1.8 * scale,
          dotPaint,
        );
      }
    }

    for (final n in numbers) {
      final angle = math.pi + (n / 100) * math.pi;

      final tickInner = radius - thickness / 2;
      final tickOuter = radius - thickness / 2 + 6 * scale;
      final tickPaint = Paint()
        ..color = tickColor
        ..strokeWidth = 1.5 * scale
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(
          center.dx + tickInner * math.cos(angle),
          center.dy + tickInner * math.sin(angle),
        ),
        Offset(
          center.dx + tickOuter * math.cos(angle),
          center.dy + tickOuter * math.sin(angle),
        ),
        tickPaint,
      );

      final x = center.dx + numRadius * math.cos(angle);
      final y = center.dy + numRadius * math.sin(angle);

      final tp = TextPainter(
        text: TextSpan(
          text: n.toString(),
          style: TextStyle(
            color: numberColor,
            fontSize: 16 * scale,
            fontWeight: FontWeight.w400,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas, Offset(x - tp.width / 2, y - tp.height / 2));
    }
  }

  void _drawNeedle(
      Canvas canvas, Offset center, double radius, double thickness, double scale) {
    final angle = math.pi + (value / 100) * math.pi;
    final needleLength = radius + thickness * 0.1;

    final tipX = center.dx + needleLength * math.cos(angle);
    final tipY = center.dy + needleLength * math.sin(angle);

    final perpAngle = angle + math.pi / 2;
    final baseHalfWidth = 8.0 * scale;

    final baseLeftX = center.dx + baseHalfWidth * math.cos(perpAngle);
    final baseLeftY = center.dy + baseHalfWidth * math.sin(perpAngle);
    final baseRightX = center.dx - baseHalfWidth * math.cos(perpAngle);
    final baseRightY = center.dy - baseHalfWidth * math.sin(perpAngle);

    final needlePath = Path()
      ..moveTo(baseLeftX, baseLeftY)
      ..lineTo(tipX, tipY)
      ..lineTo(baseRightX, baseRightY)
      ..close();

    final needlePaint = Paint()
      ..color = needleColor
      ..style = PaintingStyle.fill;

    canvas.drawPath(needlePath, needlePaint);
  }

  void _drawSemiCircleBase(Canvas canvas, Offset center, double scale) {
    final baseRadius = 55.0 * scale;

    if (!isDarkMode) {
      final shadowSpread = 20.0 * scale;
      canvas.save();
      canvas.clipRect(Rect.fromLTRB(
        center.dx - baseRadius - shadowSpread - 2,
        center.dy - baseRadius - shadowSpread - 2,
        center.dx + baseRadius + shadowSpread + 2,
        center.dy + 2,
      ));
      final shadowPaint = Paint()
        ..shader = ui.Gradient.radial(
          center,
          baseRadius + shadowSpread,
          [
            const Color(0x00000000),
            const Color(0x00000000),
            const Color(0x0C000000),
            const Color(0x00000000),
          ],
          [0.0, baseRadius / (baseRadius + shadowSpread) - 0.01, baseRadius / (baseRadius + shadowSpread), 1.0],
        );
      canvas.drawCircle(center, baseRadius + shadowSpread, shadowPaint);
      canvas.restore();
    }

    final needleBaseMargin = 10.0 * scale;
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(
      center.dx - baseRadius - 2,
      center.dy - baseRadius - 2,
      center.dx + baseRadius + 2,
      center.dy + needleBaseMargin,
    ));

    final baseFillPaint = Paint()
      ..color = cardBackgroundColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, baseRadius, baseFillPaint);

    canvas.restore();

    final valueText = value.round().toString();
    final valuePos = Offset(center.dx, center.dy - baseRadius * 0.45);
    final valueStyle = TextStyle(
      fontSize: 36 * scale,
      fontWeight: FontWeight.w900,
      height: 1,
    );

    final tpStroke = TextPainter(
      text: TextSpan(
        text: valueText,
        style: valueStyle.copyWith(
          foreground: Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.5 * scale
            ..color = textColor
            ..isAntiAlias = true,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    );
    tpStroke.layout();
    tpStroke.paint(canvas, Offset(valuePos.dx - tpStroke.width / 2, valuePos.dy - tpStroke.height / 2));

    final tpFill = TextPainter(
      text: TextSpan(
        text: valueText,
        style: valueStyle.copyWith(
          color: textColor,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    );
    tpFill.layout();
    tpFill.paint(canvas, Offset(valuePos.dx - tpFill.width / 2, valuePos.dy - tpFill.height / 2));
  }

  @override
  bool shouldRepaint(covariant _CNNFearGreedGaugePainter oldDelegate) {
    return oldDelegate.value != value ||
           oldDelegate.isLoading != isLoading ||
           oldDelegate.isDarkMode != isDarkMode;
  }
}
