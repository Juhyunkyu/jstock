import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// Zone data model for Fear & Greed segments
class _ZoneData {
  final String label;
  final Color accentColor;
  final Color fillColor;
  final int rangeStart;
  final int rangeEnd;
  final String koreanName;
  final String description;

  const _ZoneData({
    required this.label,
    required this.accentColor,
    required this.fillColor,
    required this.rangeStart,
    required this.rangeEnd,
    required this.koreanName,
    required this.description,
  });
}

const List<_ZoneData> _zones = [
  _ZoneData(
    label: 'EXTREME\nFEAR',
    accentColor: Color(0xFFDC2626),
    fillColor: Color(0xFFFCA5A5),
    rangeStart: 0,
    rangeEnd: 25,
    koreanName: '극도의 공포',
    description: '패닉 매도 가능, 역발상 매수 기회',
  ),
  _ZoneData(
    label: 'FEAR',
    accentColor: Color(0xFFF97316),
    fillColor: Color(0xFFFDBA74),
    rangeStart: 25,
    rangeEnd: 44,
    koreanName: '공포',
    description: '투자자 불안 증가, 하락 압력 주의',
  ),
  _ZoneData(
    label: 'NEUTRAL',
    accentColor: Color(0xFFEAB308),
    fillColor: Color(0xFFFDE047),
    rangeStart: 44,
    rangeEnd: 56,
    koreanName: '중립',
    description: '시장 균형 상태, 방향성 탐색 중',
  ),
  _ZoneData(
    label: 'GREED',
    accentColor: Color(0xFF84CC16),
    fillColor: Color(0xFFBEF264),
    rangeStart: 56,
    rangeEnd: 75,
    koreanName: '탐욕',
    description: '투자 심리 양호, 상승 모멘텀',
  ),
  _ZoneData(
    label: 'EXTREME\nGREED',
    accentColor: Color(0xFF22C55E),
    fillColor: Color(0xFF86EFAC),
    rangeStart: 75,
    rangeEnd: 100,
    koreanName: '극도의 탐욕',
    description: '과열 경고, 조정 가능성 높음',
  ),
];

/// Determine which zone index (0-4) a value falls into
int _getActiveZoneIndex(int value) {
  if (value < 25) return 0;
  if (value < 44) return 1;
  if (value < 56) return 2;
  if (value < 75) return 3;
  return 4;
}

/// CNN-style Fear & Greed Index gauge card
class FearGreedCard extends StatelessWidget {
  final int value;
  final bool isLoading;
  final String? error;
  final VoidCallback? onRefresh;

  const FearGreedCard({
    super.key,
    required this.value,
    this.isLoading = false,
    this.error,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final clampedValue = value.clamp(0, 100);
    final screenWidth = MediaQuery.of(context).size.width;
    // Smooth linear scale: 320px→0.92, 1400px→1.35 (no jumps)
    final fs = 0.92 + ((screenWidth - 320) / 1080).clamp(0.0, 1.0) * 0.43;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: context.appCardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.appBorder),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(14 * fs, 12 * fs, 14 * fs, 10 * fs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title row
            Row(
              children: [
                Text(
                  'Fear & Greed Index',
                  style: TextStyle(
                    fontSize: 14 * fs,
                    fontWeight: FontWeight.w600,
                    color: context.appTextPrimary,
                  ),
                ),
                SizedBox(width: 8 * fs),
                Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 6 * fs, vertical: 2 * fs),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'CNN',
                    style: TextStyle(
                      fontSize: 9 * fs,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const Spacer(),
                if (isLoading)
                  SizedBox(
                    width: 14 * fs,
                    height: 14 * fs,
                    child: const CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: Color(0xFF9CA3AF),
                    ),
                  )
                else if (onRefresh != null)
                  GestureDetector(
                    onTap: onRefresh,
                    child: Icon(
                      Icons.refresh_rounded,
                      size: 16 * fs,
                      color: context.appTextHint,
                    ),
                  ),
              ],
            ),
            SizedBox(height: 12 * fs),

            // Gauge + Zone descriptions (responsive layout)
            if (error != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Text(
                    error!,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.appTextSecondary,
                    ),
                  ),
                ),
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final useRowLayout = constraints.maxWidth >= 600;
                  final gauge = FearGreedGauge(
                    value: clampedValue,
                    isLoading: isLoading,
                    cardBackgroundColor: context.appCardBackground,
                    textColor: context.appTextPrimary,
                    isDarkMode: context.isDarkMode,
                  );
                  final descriptions = _ZoneDescriptionPanel(
                    value: clampedValue,
                  );

                  if (useRowLayout) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(flex: 5, child: gauge),
                        const SizedBox(width: 16),
                        Expanded(flex: 5, child: descriptions),
                      ],
                    );
                  }

                  return Column(
                    children: [
                      gauge,
                      const SizedBox(height: 16),
                      descriptions,
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

/// Panel showing intro text + all 5 zone descriptions (single-line each)
class _ZoneDescriptionPanel extends StatelessWidget {
  final int value;

  const _ZoneDescriptionPanel({required this.value});

  @override
  Widget build(BuildContext context) {
    final activeZone = _getActiveZoneIndex(value);
    final screenWidth = MediaQuery.of(context).size.width;
    final fs = 0.92 + ((screenWidth - 320) / 1080).clamp(0.0, 1.0) * 0.43;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Intro description
        Text(
          'S&P 500 옵션 시장 기반 시장 심리 종합 지표. '
          'VIX, 모멘텀, 풋/콜 비율 등 7개 지표를 종합하여 '
          '투자자들의 공포·탐욕 수준을 0~100으로 나타냅니다.',
          style: TextStyle(
            fontSize: 13 * fs,
            color: context.appTextSecondary,
            height: 1.4,
          ),
        ),
        SizedBox(height: 10 * fs),
        // Zone items (single-line each)
        for (int i = 0; i < _zones.length; i++) ...[
          _ZoneDescriptionItem(
            zone: _zones[i],
            isActive: i == activeZone,
          ),
          if (i < _zones.length - 1) SizedBox(height: 4 * fs),
        ],
      ],
    );
  }
}

/// Single-line zone description: [bar] dot · name · range · description
class _ZoneDescriptionItem extends StatelessWidget {
  final _ZoneData zone;
  final bool isActive;

  const _ZoneDescriptionItem({
    required this.zone,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final screenWidth = MediaQuery.of(context).size.width;
    final fs = 0.92 + ((screenWidth - 320) / 1080).clamp(0.0, 1.0) * 0.43;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: isActive
            ? zone.accentColor.withValues(alpha: isDark ? 0.15 : 0.08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            // Left accent bar
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              width: isActive ? 3 * fs : 0,
              decoration: BoxDecoration(
                color: zone.accentColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(6),
                  bottomLeft: Radius.circular(6),
                ),
              ),
            ),
            // Single-line content
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 8 * fs, vertical: 6 * fs),
                child: Row(
                  children: [
                    // Color dot
                    Container(
                      width: 8 * fs,
                      height: 8 * fs,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isActive
                            ? zone.accentColor
                            : zone.accentColor.withValues(alpha: 0.35),
                      ),
                    ),
                    SizedBox(width: 6 * fs),
                    // Zone name
                    Text(
                      zone.koreanName,
                      style: TextStyle(
                        fontSize: 13 * fs,
                        fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                        color: isActive
                            ? context.appTextPrimary
                            : context.appTextHint,
                      ),
                    ),
                    SizedBox(width: 5 * fs),
                    // Range badge
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 4 * fs,
                        vertical: 1 * fs,
                      ),
                      decoration: BoxDecoration(
                        color: isActive
                            ? zone.accentColor.withValues(alpha: isDark ? 0.25 : 0.12)
                            : context.appIconBg,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        '${zone.rangeStart}-${zone.rangeEnd}',
                        style: TextStyle(
                          fontSize: 10 * fs,
                          fontWeight: FontWeight.w500,
                          color: isActive
                              ? zone.accentColor
                              : context.appTextHint,
                        ),
                      ),
                    ),
                    SizedBox(width: 6 * fs),
                    // Description (fills remaining space)
                    Expanded(
                      child: Text(
                        zone.description,
                        style: TextStyle(
                          fontSize: 12 * fs,
                          color: isActive
                              ? context.appTextSecondary
                              : context.appTextHint.withValues(alpha: isDark ? 0.45 : 0.55),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
      ? const Color(0xFF2D333B)  // Dark gray for dark mode
      : const Color(0xFFF0F1F3); // Light gray for light mode

  Color get activeSegment => isDarkMode
      ? const Color(0xFF3D444D)  // Slightly lighter dark gray
      : const Color(0xFFDCDEE2); // Slightly darker light gray

  Color get needleColor => isDarkMode
      ? const Color(0xFFE6EDF3)  // Light/white needle in dark mode
      : const Color(0xFF1F2937); // Dark needle in light mode

  Color get numberColor => isDarkMode
      ? const Color(0xFF8B949E)  // Muted gray text
      : const Color(0xFF6B7280); // Gray text

  Color get activeLabelColor => isDarkMode
      ? const Color(0xFFE6EDF3)  // Bright white
      : const Color(0xFF1A1A1A); // Black

  Color get inactiveLabelColor => isDarkMode
      ? const Color(0xFF8B949E)  // Muted gray
      : const Color(0xFF4B5563); // Gray

  Color get tickColor => isDarkMode
      ? const Color(0xFF3D444D)  // Dark mode tick marks
      : const Color(0xFFD1D5DB); // Light mode tick marks

  Color get borderColor => isDarkMode
      ? const Color(0xFF4D555E)  // Dark mode active border
      : const Color(0xFFB0B3B8); // Light mode active border

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
    // 반응형: 기준 너비 550px 대비 scale (모바일 최소 0.7 보장)
    final scale = (size.width / 550.0).clamp(0.7, 1.0);
    final arcThickness = 82.0 * scale;
    final radius = size.width * 0.40;
    final center = Offset(size.width / 2, size.height - 8 * scale);
    final activeZone = _getActiveZone();

    const totalSweep = math.pi;
    const gapSize = 0.015;

    // Draw each of the 5 arc segments
    for (int i = 0; i < 5; i++) {
      final startPct = _zones[i].rangeStart / 100.0;
      final endPct = _zones[i].rangeEnd / 100.0;

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
        // Active segment: 진한 그레이
        arcPaint.color = activeSegment;
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          segStart,
          segSweep,
          false,
          arcPaint,
        );

        // Active segment 테두리
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
        // Inactive segment: gray
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

    // Draw labels on arcs
    _drawArcLabels(canvas, center, radius, arcThickness, activeZone, scale);

    // Draw inner numbers (0, 25, 50, 75, 100)
    _drawNumbers(canvas, center, radius, arcThickness, scale);

    // Draw needle and semi-circle base
    if (!isLoading) {
      _drawNeedle(canvas, center, radius, arcThickness, scale);
      _drawSemiCircleBase(canvas, center, scale);
    }
  }

  void _drawArcLabels(Canvas canvas, Offset center, double radius,
      double thickness, int activeZone, double scale) {
    // CNN처럼 아크를 따라 글씨가 회전하도록 그리기
    final labelAngles = [
      math.pi + 0.125 * math.pi,  // Ext Fear: 12.5%
      math.pi + 0.345 * math.pi,  // Fear: 34.5%
      math.pi + 0.50 * math.pi,   // Neutral: 50%
      math.pi + 0.655 * math.pi,  // Greed: 65.5%
      math.pi + 0.875 * math.pi,  // Ext Greed: 87.5%
    ];

    for (int i = 0; i < _zones.length; i++) {
      final angle = labelAngles[i];
      final isActive = i == activeZone;
      final textColor = isActive ? activeLabelColor : inactiveLabelColor;

      final lines = _zones[i].label.split('\n');

      // CNN condensed 효과: 폰트 크게 + 가로 압축
      double fontSize;
      fontSize = 18.0 * scale;

      // 각 줄을 아크 곡선 따라 회전해서 그리기
      final lineSpacing = fontSize + 3.0 * scale;
      final totalH = lines.length * lineSpacing;
      // 2줄 라벨(EXTREME)은 첫 줄이 더 바깥으로 나가므로 보정
      final baseOffset = lines.length > 1
          ? thickness * 0.3 - lineSpacing / 2
          : thickness * 0.3;

      for (int j = 0; j < lines.length; j++) {
        final lineOffset = (j * lineSpacing) - totalH / 2 + lineSpacing / 2;
        final lineRadius = radius + baseOffset - lineOffset;

        final x = center.dx + lineRadius * math.cos(angle);
        final y = center.dy + lineRadius * math.sin(angle);

        // 텍스트 회전 각도: 아크 접선 방향 (angle + 90도)
        final rotation = angle + math.pi / 2;

        final tp = TextPainter(
          text: TextSpan(
            text: lines[j],
            style: TextStyle(
              color: textColor,
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
        // CNN condensed: 가로 75% 압축 → 좁고 키 큰 글씨
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

    // 숫자 사이 눈금 점 4개씩 - 숫자와 같은 높이, 같은 색상
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

      // 숫자 위치의 눈금선
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
    // 바늘 길이: 글씨 밑에 여백을 두고 끝남
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

    // CNN스타일 바깥쪽 그림자: 반원 주변으로 퍼지는 그라데이션
    // Dark mode: skip shadow to avoid center dot artifact
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
            const Color(0x00000000), // 안쪽: 투명
            const Color(0x00000000), // 원 경계까지 투명
            const Color(0x0C000000), // 원 바로 바깥: 연한 그림자
            const Color(0x00000000), // 바깥쪽: 페이드아웃
          ],
          [0.0, baseRadius / (baseRadius + shadowSpread) - 0.01, baseRadius / (baseRadius + shadowSpread), 1.0],
        );
      canvas.drawCircle(center, baseRadius + shadowSpread, shadowPaint);
      canvas.restore();
    }

    // ∩ 돔 모양: clip을 바늘 밑면(baseHalfWidth=8*scale) 아래까지 덮어서
    // 바늘 삼각형이 돔 밖으로 삐져나오는 artifact 방지
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

    // ∩ 반원 안쪽에 숫자
    final valueText = value.round().toString();
    final valuePos = Offset(center.dx, center.dy - baseRadius * 0.45);
    final valueStyle = TextStyle(
      fontSize: 36 * scale,
      fontWeight: FontWeight.w900,
      height: 1,
    );

    // 1) stroke로 살짝 두께 추가
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

    // 2) fill로 채우기
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
