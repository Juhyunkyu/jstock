import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../../data/models/chart_drawing.dart';
import '../../../data/models/ohlc_data.dart';
import '../../utils/chart_coordinate_utils.dart';

/// 드로잉 오버레이 페인터
///
/// 기존 캔들스틱 페인터 위에 별도 레이어로 수평선/추세선을 렌더링합니다.
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
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (drawings.isEmpty || displayData.isEmpty) return;

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
      }
    }

    // 미리보기 수평선 (클리핑 내부)
    if (tempHorizontalPrice != null) {
      _drawPreviewLine(canvas, size, tempHorizontalPrice!);
    }

    canvas.restore();

    // 가격 라벨은 클리핑 밖에서 그리기 (우측 Y축 영역)
    for (final drawing in drawings) {
      final isSelected = drawing.id == selectedDrawingId;
      final color = Color(drawing.colorValue);

      if (drawing.type == DrawingType.horizontalLine) {
        _drawPriceLabel(canvas, size, drawing.price, color, isSelected);
      }
    }

    // 미리보기 가격 라벨
    if (tempHorizontalPrice != null) {
      final previewColor = Color(tempColorValue ?? 0xFFFF6B6B);
      _drawPriceLabel(canvas, size, tempHorizontalPrice!, previewColor.withAlpha(180), false);
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

    // 실선
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

    // 날짜 → fullData 인덱스 찾기 → displayData 인덱스로 변환
    final startFullIdx = _findDateIndex(fullData, drawing.startDate!);
    final endFullIdx = _findDateIndex(fullData, drawing.endDate!);

    if (startFullIdx == null || endFullIdx == null) return;

    // display 인덱스 = fullData 인덱스 - scrollOffset
    final startDisplayIdx = startFullIdx - scrollOffset;
    final endDisplayIdx = endFullIdx - scrollOffset;

    // 두 앵커 점의 픽셀 좌표
    final startX = yRange.toX(startDisplayIdx);
    final startY = yRange.toY(drawing.startPrice!);
    final endX = yRange.toX(endDisplayIdx);
    final endY = yRange.toY(drawing.endPrice!);

    final baseWidth = drawing.strokeWidth;
    final paint = Paint()
      ..color = isSelected ? color : color.withAlpha(180)
      ..strokeWidth = isSelected ? baseWidth + 0.5 : baseWidth
      ..style = PaintingStyle.stroke;

    // 양방향 무한 연장: 차트 영역 경계까지 직선 확장
    final chartLeft = yRange.leftPadding;
    final chartRight = yRange.leftPadding + yRange.chartWidth;
    final dx = endX - startX;
    final dy = endY - startY;

    // dx가 거의 0이면 수직선 → 그리지 않음 (불필요)
    if (dx.abs() < 0.001) return;

    final slope = dy / dx;
    final leftY = startY + slope * (chartLeft - startX);
    final rightY = startY + slope * (chartRight - startX);
    final Offset p1 = Offset(chartLeft, leftY);
    final Offset p2 = Offset(chartRight, rightY);

    canvas.drawLine(p1, p2, paint);

    // 선택 상태에서 앵커 점 표시
    if (isSelected) {
      final dotPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(startX, startY), 4, dotPaint);
      canvas.drawCircle(Offset(endX, endY), 4, dotPaint);
    }
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
    final badgeX = yRange.leftPadding + 4; // 왼쪽 위
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

  /// 드래그 미리보기 수평선 (반투명 대시선)
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

    // 실선
    final startX = yRange.leftPadding;
    final endX = yRange.leftPadding + yRange.chartWidth;
    canvas.drawLine(Offset(startX, y), Offset(endX, y), paint);
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
        tempColorValue != oldDelegate.tempColorValue;
  }
}
