import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../../data/models/chart_drawing.dart';
import '../../../data/models/ohlc_data.dart';
import '../../utils/chart_coordinate_utils.dart';

/// 피보나치 되돌림 레벨 상수
const List<double> _fibLevels = [0.0, 0.236, 0.382, 0.5, 0.618, 0.786, 1.0];

/// 피보나치 레벨 색상 (alpha 적용 전)
const List<int> _fibColors = [
  0xFF26A69A, // 0%
  0xFF66BB6A, // 23.6%
  0xFF42A5F5, // 38.2%
  0xFFAB47BC, // 50%
  0xFFFF7043, // 61.8%
  0xFFEF5350, // 78.6%
  0xFFE53935, // 100%
];

/// 드로잉 오버레이 페인터
///
/// 기존 캔들스틱 페인터 위에 별도 레이어로 드로잉을 렌더링합니다.
class DrawingOverlayPainter extends CustomPainter {
  final List<ChartDrawing> drawings;
  final List<OHLCData> displayData;
  final List<OHLCData> fullData;
  final int scrollOffset;
  final ChartYRange yRange;
  final String? selectedDrawingId;
  final bool isDarkMode;

  /// 새 수평선 드래그 미리보기 가격 (null이면 미표시)
  final double? tempHorizontalPrice;

  /// 미리보기 색상 값
  final int? tempColorValue;

  /// 추세선/피보나치 첫 번째 포인트 (배치 중 시각적 피드백)
  final DateTime? tempTrendStartDate;
  final double? tempTrendStartPrice;

  /// 측정 도구 임시 상태
  final int? tempMeasureStartIndex;
  final double? tempMeasureStartPrice;
  final int? tempMeasureEndIndex;
  final double? tempMeasureEndPrice;

  /// 지지/저항 영역 드래그 미리보기
  final double? tempZoneUpperPrice;
  final double? tempZoneLowerPrice;

  DrawingOverlayPainter({
    required this.drawings,
    required this.displayData,
    required this.fullData,
    required this.scrollOffset,
    required this.yRange,
    this.selectedDrawingId,
    required this.isDarkMode,
    this.tempHorizontalPrice,
    this.tempColorValue,
    this.tempTrendStartDate,
    this.tempTrendStartPrice,
    this.tempMeasureStartIndex,
    this.tempMeasureStartPrice,
    this.tempMeasureEndIndex,
    this.tempMeasureEndPrice,
    this.tempZoneUpperPrice,
    this.tempZoneLowerPrice,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (displayData.isEmpty) return;
    final hasMeasure = tempMeasureStartIndex != null &&
        tempMeasureEndIndex != null;
    final hasZonePreview = tempZoneUpperPrice != null &&
        tempZoneLowerPrice != null;
    final hasContent = drawings.isNotEmpty ||
        tempHorizontalPrice != null ||
        tempTrendStartDate != null ||
        hasMeasure ||
        hasZonePreview;
    if (!hasContent) return;

    // 차트 영역 클리핑
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(
      yRange.leftPadding,
      yRange.topPadding,
      yRange.chartWidth,
      yRange.chartHeight,
    ));

    for (final drawing in drawings) {
      final isSelected = drawing.id == selectedDrawingId;
      final color = Color(drawing.colorValue);

      switch (drawing.type) {
        case DrawingType.horizontalLine:
          _drawHorizontalLine(canvas, size, drawing, color, isSelected);
          break;
        case DrawingType.trendLine:
          _drawTrendLine(canvas, size, drawing, color, isSelected);
          break;
        case DrawingType.fibonacci:
          _drawFibonacci(canvas, size, drawing, color, isSelected);
          break;
        case DrawingType.supportResistanceZone:
          _drawSupportResistanceZone(canvas, size, drawing, color, isSelected);
          break;
      }
    }

    // 미리보기 수평선 (클리핑 내부)
    if (tempHorizontalPrice != null) {
      _drawPreviewLine(canvas, size, tempHorizontalPrice!);
    }

    // 추세선/피보나치 첫 번째 포인트 (배치 중 시각적 피드백)
    if (tempTrendStartDate != null && tempTrendStartPrice != null) {
      _drawTrendStartPoint(canvas, size);
    }

    // 측정 도구
    if (hasMeasure) {
      _drawMeasureTool(canvas, size);
    }

    // 지지/저항 영역 미리보기
    if (hasZonePreview) {
      _drawZonePreview(canvas, size);
    }

    canvas.restore();

    // 가격 라벨은 클리핑 밖에서 그리기 (우측 Y축 영역)
    for (final drawing in drawings) {
      final isSelected = drawing.id == selectedDrawingId;
      final color = Color(drawing.colorValue);

      if (drawing.type == DrawingType.horizontalLine) {
        _drawPriceLabel(canvas, size, drawing.price, color, isSelected);
      }
      if (drawing.type == DrawingType.supportResistanceZone) {
        _drawPriceLabel(canvas, size, drawing.price, color, isSelected);
        _drawPriceLabel(canvas, size, drawing.lowerPrice, color, isSelected);
      }
    }

    // 미리보기 가격 라벨
    if (tempHorizontalPrice != null) {
      final previewColor = Color(tempColorValue ?? 0xFFFF6B6B);
      _drawPriceLabel(canvas, size, tempHorizontalPrice!, previewColor.withAlpha(180), false);
    }

    // 지지/저항 미리보기 가격 라벨
    if (hasZonePreview) {
      final previewColor = Color(tempColorValue ?? 0xFFFF6B6B).withAlpha(180);
      _drawPriceLabel(canvas, size, tempZoneUpperPrice!, previewColor, false);
      _drawPriceLabel(canvas, size, tempZoneLowerPrice!, previewColor, false);
    }
  }

  void _drawHorizontalLine(
    Canvas canvas,
    Size size,
    ChartDrawing drawing,
    Color color,
    bool isSelected,
  ) {
    final y = yRange.toY(drawing.price);
    if (y < yRange.topPadding || y > yRange.topPadding + yRange.chartHeight) {
      return;
    }

    final baseWidth = drawing.strokeWidth;
    final paint = Paint()
      ..color = isSelected ? color : color.withAlpha(180)
      ..strokeWidth = isSelected ? baseWidth + 1.0 : baseWidth
      ..style = PaintingStyle.stroke;

    final startX = yRange.leftPadding;
    final endX = yRange.leftPadding + yRange.chartWidth;
    canvas.drawLine(Offset(startX, y), Offset(endX, y), paint);
  }

  void _drawTrendLine(
    Canvas canvas,
    Size size,
    ChartDrawing drawing,
    Color color,
    bool isSelected,
  ) {
    if (drawing.startDate == null ||
        drawing.startPrice == null ||
        drawing.endDate == null ||
        drawing.endPrice == null) {
      return;
    }

    final startFullIdx = _findDateIndex(fullData, drawing.startDate!);
    final endFullIdx = _findDateIndex(fullData, drawing.endDate!);
    if (startFullIdx == null || endFullIdx == null) return;

    final startDisplayIdx = startFullIdx - scrollOffset;
    final endDisplayIdx = endFullIdx - scrollOffset;

    final startX = yRange.toX(startDisplayIdx);
    final startY = yRange.toY(drawing.startPrice!);
    final endX = yRange.toX(endDisplayIdx);
    final endY = yRange.toY(drawing.endPrice!);

    final baseWidth = drawing.strokeWidth;
    final paint = Paint()
      ..color = isSelected ? color : color.withAlpha(180)
      ..strokeWidth = isSelected ? baseWidth + 0.5 : baseWidth
      ..style = PaintingStyle.stroke;

    final chartLeft = yRange.leftPadding;
    final chartRight = yRange.leftPadding + yRange.chartWidth;
    final dx = endX - startX;
    final dy = endY - startY;

    if (dx.abs() < 0.001) return;

    final slope = dy / dx;
    final leftY = startY + slope * (chartLeft - startX);
    final rightY = startY + slope * (chartRight - startX);
    canvas.drawLine(Offset(chartLeft, leftY), Offset(chartRight, rightY), paint);

    if (isSelected) {
      _drawAnchorDot(canvas, Offset(startX, startY), color);
      _drawAnchorDot(canvas, Offset(endX, endY), color);
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // 피보나치 되돌림
  // ═══════════════════════════════════════════════════════════════

  void _drawFibonacci(
    Canvas canvas,
    Size size,
    ChartDrawing drawing,
    Color color,
    bool isSelected,
  ) {
    if (drawing.startDate == null ||
        drawing.startPrice == null ||
        drawing.endDate == null ||
        drawing.endPrice == null) {
      return;
    }

    final highPrice = drawing.startPrice!; // 100%
    final lowPrice = drawing.endPrice!;    // 0%
    final chartLeft = yRange.leftPadding;
    final chartRight = yRange.leftPadding + yRange.chartWidth;

    // 인접 레벨 사이 반투명 채움
    for (int i = 0; i < _fibLevels.length - 1; i++) {
      final price1 = lowPrice + (highPrice - lowPrice) * _fibLevels[i];
      final price2 = lowPrice + (highPrice - lowPrice) * _fibLevels[i + 1];
      final y1 = yRange.toY(price1);
      final y2 = yRange.toY(price2);

      final fillPaint = Paint()
        ..color = Color(_fibColors[i]).withAlpha(isSelected ? 25 : 15)
        ..style = PaintingStyle.fill;
      canvas.drawRect(
        Rect.fromLTRB(chartLeft, math.min(y1, y2), chartRight, math.max(y1, y2)),
        fillPaint,
      );
    }

    // 7개 레벨 대시선 + 라벨
    for (int i = 0; i < _fibLevels.length; i++) {
      final ratio = _fibLevels[i];
      final price = lowPrice + (highPrice - lowPrice) * ratio;
      final y = yRange.toY(price);

      // 대시선
      final linePaint = Paint()
        ..color = Color(_fibColors[i]).withAlpha(isSelected ? 220 : 150)
        ..strokeWidth = isSelected ? 1.2 : 0.8
        ..style = PaintingStyle.stroke;
      _drawDashedLine(canvas, Offset(chartLeft, y), Offset(chartRight, y), linePaint, 6, 4);

      // 라벨 배지
      final label = '${(ratio * 100).toStringAsFixed(1)}% ${_formatPrice(price)}';
      _drawFibLabel(canvas, label, chartLeft + 4, y, Color(_fibColors[i]));
    }

    // 선택 시 앵커 점
    if (isSelected) {
      final startIdx = _findDateIndex(fullData, drawing.startDate!);
      final endIdx = _findDateIndex(fullData, drawing.endDate!);
      if (startIdx != null && endIdx != null) {
        final startX = yRange.toX(startIdx - scrollOffset);
        final endX = yRange.toX(endIdx - scrollOffset);
        _drawAnchorDot(canvas, Offset(startX, yRange.toY(highPrice)), color);
        _drawAnchorDot(canvas, Offset(endX, yRange.toY(lowPrice)), color);
      }
    }
  }

  /// 피보나치 라벨 배지
  void _drawFibLabel(Canvas canvas, String label, double x, double y, Color color) {
    final textSpan = TextSpan(
      text: label,
      style: TextStyle(
        color: isDarkMode ? Colors.white.withAlpha(220) : Colors.white,
        fontSize: 8,
        fontWeight: FontWeight.w600,
      ),
    );
    final tp = TextPainter(text: textSpan, textDirection: ui.TextDirection.ltr);
    tp.layout();

    final badgeW = tp.width + 6;
    final badgeH = tp.height + 3;
    final badgeY = y - badgeH - 1;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x, badgeY, badgeW, badgeH),
        const Radius.circular(2),
      ),
      Paint()..color = color.withAlpha(200),
    );
    tp.paint(canvas, Offset(x + 3, badgeY + 1.5));
  }

  // ═══════════════════════════════════════════════════════════════
  // 지지/저항 영역
  // ═══════════════════════════════════════════════════════════════

  void _drawSupportResistanceZone(
    Canvas canvas,
    Size size,
    ChartDrawing drawing,
    Color color,
    bool isSelected,
  ) {
    final upperY = yRange.toY(drawing.price);
    final lowerY = yRange.toY(drawing.lowerPrice);
    final chartLeft = yRange.leftPadding;
    final chartRight = yRange.leftPadding + yRange.chartWidth;

    // 반투명 사각형
    final fillPaint = Paint()
      ..color = color.withAlpha(isSelected ? 40 : 25)
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTRB(chartLeft, math.min(upperY, lowerY), chartRight, math.max(upperY, lowerY)),
      fillPaint,
    );

    // 상/하 경계선
    final borderPaint = Paint()
      ..color = color.withAlpha(isSelected ? 220 : 160)
      ..strokeWidth = isSelected ? 1.5 : 1.0
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(chartLeft, upperY), Offset(chartRight, upperY), borderPaint);
    canvas.drawLine(Offset(chartLeft, lowerY), Offset(chartRight, lowerY), borderPaint);
  }

  /// 지지/저항 영역 미리보기
  void _drawZonePreview(Canvas canvas, Size size) {
    final upperY = yRange.toY(tempZoneUpperPrice!);
    final lowerY = yRange.toY(tempZoneLowerPrice!);
    final chartLeft = yRange.leftPadding;
    final chartRight = yRange.leftPadding + yRange.chartWidth;
    final previewColor = Color(tempColorValue ?? 0xFFFF6B6B);

    final fillPaint = Paint()
      ..color = previewColor.withAlpha(20)
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTRB(chartLeft, math.min(upperY, lowerY), chartRight, math.max(upperY, lowerY)),
      fillPaint,
    );

    final borderPaint = Paint()
      ..color = previewColor.withAlpha(140)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    _drawDashedLine(canvas, Offset(chartLeft, upperY), Offset(chartRight, upperY), borderPaint, 6, 4);
    _drawDashedLine(canvas, Offset(chartLeft, lowerY), Offset(chartRight, lowerY), borderPaint, 6, 4);
  }

  // ═══════════════════════════════════════════════════════════════
  // 측정 도구
  // ═══════════════════════════════════════════════════════════════

  void _drawMeasureTool(Canvas canvas, Size size) {
    final startIdx = tempMeasureStartIndex! - scrollOffset;
    final endIdx = tempMeasureEndIndex! - scrollOffset;
    final startPrice = tempMeasureStartPrice!;
    final endPrice = tempMeasureEndPrice!;

    final startX = yRange.toX(startIdx);
    final startY = yRange.toY(startPrice);
    final endX = yRange.toX(endIdx);
    final endY = yRange.toY(endPrice);

    final measureColor = isDarkMode
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);

    // 반투명 채움
    final fillPaint = Paint()
      ..color = measureColor.withAlpha(20)
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTRB(
        math.min(startX, endX), math.min(startY, endY),
        math.max(startX, endX), math.max(startY, endY),
      ),
      fillPaint,
    );

    // 점선 사각형
    final borderPaint = Paint()
      ..color = measureColor.withAlpha(180)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    final rect = Rect.fromLTRB(
      math.min(startX, endX), math.min(startY, endY),
      math.max(startX, endX), math.max(startY, endY),
    );
    _drawDashedRect(canvas, rect, borderPaint, 5, 3);

    // 정보 박스
    _drawMeasureInfoBox(canvas, startPrice, endPrice, startIdx, endIdx, endX, endY, measureColor);
  }

  /// 측정 도구 정보 박스
  void _drawMeasureInfoBox(
    Canvas canvas,
    double startPrice,
    double endPrice,
    int startDisplayIdx,
    int endDisplayIdx,
    double endX,
    double endY,
    Color baseColor,
  ) {
    final priceDiff = endPrice - startPrice;
    final pctChange = startPrice != 0 ? (priceDiff / startPrice) * 100 : 0.0;
    final candleCount = (tempMeasureEndIndex! - tempMeasureStartIndex!).abs();
    final isPositive = priceDiff >= 0;

    final sign = isPositive ? '+' : '';
    final priceText = '$sign\$${priceDiff.abs().toStringAsFixed(2)} (${sign}${pctChange.toStringAsFixed(2)}%)';
    final candleText = '$candleCount 캔들';

    final valueColor = isPositive
        ? (isDarkMode ? const Color(0xFF4ADE80) : const Color(0xFF16A34A))
        : (isDarkMode ? const Color(0xFFF87171) : const Color(0xFFDC2626));

    // 가격 변화 텍스트
    final priceTp = TextPainter(
      text: TextSpan(
        text: priceText,
        style: TextStyle(color: valueColor, fontSize: 10, fontWeight: FontWeight.w700),
      ),
      textDirection: ui.TextDirection.ltr,
    );
    priceTp.layout();

    // 캔들 수 텍스트
    final candleTp = TextPainter(
      text: TextSpan(
        text: candleText,
        style: TextStyle(
          color: isDarkMode ? Colors.white.withAlpha(180) : Colors.black87,
          fontSize: 9,
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    );
    candleTp.layout();

    final boxWidth = math.max(priceTp.width, candleTp.width) + 12;
    final boxHeight = priceTp.height + candleTp.height + 10;

    // 박스 위치: 끝점 근처
    final boxX = endX + 8;
    final boxY = endY - boxHeight / 2;

    // 배경
    final bgColor = isDarkMode
        ? const Color(0xFF1E293B).withAlpha(240)
        : Colors.white.withAlpha(240);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(boxX, boxY, boxWidth, boxHeight),
        const Radius.circular(4),
      ),
      Paint()..color = bgColor,
    );
    // 테두리
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(boxX, boxY, boxWidth, boxHeight),
        const Radius.circular(4),
      ),
      Paint()
        ..color = baseColor.withAlpha(80)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5,
    );

    priceTp.paint(canvas, Offset(boxX + 6, boxY + 4));
    candleTp.paint(canvas, Offset(boxX + 6, boxY + 4 + priceTp.height + 2));
  }

  // ═══════════════════════════════════════════════════════════════
  // 공통 헬퍼
  // ═══════════════════════════════════════════════════════════════

  /// 앵커 점 (바깥 반투명 + 안쪽 진한 + 흰 테두리)
  void _drawAnchorDot(Canvas canvas, Offset center, Color color) {
    canvas.drawCircle(
      center, 10,
      Paint()..color = color.withAlpha(50)..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      center, 5,
      Paint()..color = color..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      center, 5,
      Paint()..color = Colors.white.withAlpha(220)..style = PaintingStyle.stroke..strokeWidth = 1.5,
    );
  }

  void _drawPriceLabel(
    Canvas canvas,
    Size size,
    double price,
    Color color,
    bool isSelected,
  ) {
    final y = yRange.toY(price);
    if (y < yRange.topPadding - 10 ||
        y > yRange.topPadding + yRange.chartHeight + 10) {
      return;
    }

    final priceText = _formatPrice(price);
    final textSpan = TextSpan(
      text: priceText,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 9,
        fontWeight: FontWeight.w600,
      ),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: ui.TextDirection.ltr,
    );
    textPainter.layout();

    final badgeWidth = textPainter.width + 6;
    final badgeHeight = textPainter.height + 4;
    final badgeX = yRange.leftPadding + 4;
    final badgeY = y - badgeHeight - 2;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(badgeX, badgeY, badgeWidth, badgeHeight),
        const Radius.circular(3),
      ),
      Paint()..color = isSelected ? color : color.withAlpha(180),
    );
    textPainter.paint(canvas, Offset(badgeX + 3, badgeY + 2));
  }

  /// 드래그 미리보기 수평선 (반투명)
  void _drawPreviewLine(Canvas canvas, Size size, double price) {
    final y = yRange.toY(price);
    if (y < yRange.topPadding || y > yRange.topPadding + yRange.chartHeight) {
      return;
    }

    final previewColor = Color(tempColorValue ?? 0xFFFF6B6B).withAlpha(140);
    final paint = Paint()
      ..color = previewColor
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final startX = yRange.leftPadding;
    final endX = yRange.leftPadding + yRange.chartWidth;
    canvas.drawLine(Offset(startX, y), Offset(endX, y), paint);
  }

  /// 대시선 그리기
  void _drawDashedLine(
    Canvas canvas,
    Offset start,
    Offset end,
    Paint paint,
    double dashLen,
    double gapLen,
  ) {
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final dist = math.sqrt(dx * dx + dy * dy);
    if (dist < 1) return;
    final unitX = dx / dist;
    final unitY = dy / dist;

    double traveled = 0;
    while (traveled < dist) {
      final segEnd = math.min(traveled + dashLen, dist);
      canvas.drawLine(
        Offset(start.dx + unitX * traveled, start.dy + unitY * traveled),
        Offset(start.dx + unitX * segEnd, start.dy + unitY * segEnd),
        paint,
      );
      traveled = segEnd + gapLen;
    }
  }

  /// 점선 사각형
  void _drawDashedRect(Canvas canvas, Rect rect, Paint paint, double dashLen, double gapLen) {
    _drawDashedLine(canvas, rect.topLeft, rect.topRight, paint, dashLen, gapLen);
    _drawDashedLine(canvas, rect.topRight, rect.bottomRight, paint, dashLen, gapLen);
    _drawDashedLine(canvas, rect.bottomRight, rect.bottomLeft, paint, dashLen, gapLen);
    _drawDashedLine(canvas, rect.bottomLeft, rect.topLeft, paint, dashLen, gapLen);
  }

  /// 날짜에 가장 가까운 fullData 인덱스 찾기
  int? _findDateIndex(List<OHLCData> data, DateTime target) {
    if (data.isEmpty) return null;

    int bestIdx = 0;
    int bestDiff = (data[0].date.difference(target).inMinutes).abs();

    for (int i = 1; i < data.length; i++) {
      final diff = (data[i].date.difference(target).inMinutes).abs();
      if (diff < bestDiff) {
        bestDiff = diff;
        bestIdx = i;
      }
    }
    return bestIdx;
  }

  /// 추세선/피보나치 첫 번째 포인트 점 표시
  void _drawTrendStartPoint(Canvas canvas, Size size) {
    final idx = _findDateIndex(fullData, tempTrendStartDate!);
    if (idx == null) return;

    final visibleIdx = idx - scrollOffset;
    final x = yRange.toX(visibleIdx);
    final y = yRange.toY(tempTrendStartPrice!);

    final pointColor = Color(tempColorValue ?? 0xFFFF6B6B);
    canvas.drawCircle(Offset(x, y), 10, Paint()..color = pointColor.withAlpha(60)..style = PaintingStyle.fill);
    canvas.drawCircle(Offset(x, y), 4, Paint()..color = pointColor..style = PaintingStyle.fill);
    canvas.drawCircle(Offset(x, y), 4, Paint()..color = Colors.white.withAlpha(200)..style = PaintingStyle.stroke..strokeWidth = 1.5);
  }

  String _formatPrice(double price) {
    if (price >= 10000) return price.toStringAsFixed(0);
    if (price >= 100) return price.toStringAsFixed(1);
    return price.toStringAsFixed(2);
  }

  @override
  bool shouldRepaint(covariant DrawingOverlayPainter oldDelegate) {
    return drawings != oldDelegate.drawings ||
        selectedDrawingId != oldDelegate.selectedDrawingId ||
        displayData != oldDelegate.displayData ||
        scrollOffset != oldDelegate.scrollOffset ||
        tempHorizontalPrice != oldDelegate.tempHorizontalPrice ||
        tempColorValue != oldDelegate.tempColorValue ||
        tempTrendStartDate != oldDelegate.tempTrendStartDate ||
        tempTrendStartPrice != oldDelegate.tempTrendStartPrice ||
        tempMeasureStartIndex != oldDelegate.tempMeasureStartIndex ||
        tempMeasureStartPrice != oldDelegate.tempMeasureStartPrice ||
        tempMeasureEndIndex != oldDelegate.tempMeasureEndIndex ||
        tempMeasureEndPrice != oldDelegate.tempMeasureEndPrice ||
        tempZoneUpperPrice != oldDelegate.tempZoneUpperPrice ||
        tempZoneLowerPrice != oldDelegate.tempZoneLowerPrice;
  }
}
