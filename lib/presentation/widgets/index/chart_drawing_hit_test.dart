import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../data/models/chart_drawing.dart';
import '../../../data/models/ohlc_data.dart';
import '../../utils/chart_coordinate_utils.dart';

/// 드로잉 hit-test 관련 순수 유틸리티 함수 모음
class ChartDrawingHitTest {
  ChartDrawingHitTest._();

  /// 추세선과 점 사이의 거리 (px)
  static double trendLineDistance(
    Offset point,
    ChartDrawing drawing,
    ChartYRange yRange,
    int scrollOffset,
    List<OHLCData> fullData,
  ) {
    if (drawing.startDate == null || drawing.endDate == null ||
        drawing.startPrice == null || drawing.endPrice == null) {
      return double.infinity;
    }

    final startIdx = findDateIndex(fullData, drawing.startDate!);
    final endIdx = findDateIndex(fullData, drawing.endDate!);
    if (startIdx == null || endIdx == null) return double.infinity;

    final startX = yRange.toX(startIdx - scrollOffset);
    final startY = yRange.toY(drawing.startPrice!);
    final endX = yRange.toX(endIdx - scrollOffset);
    final endY = yRange.toY(drawing.endPrice!);

    // 점과 직선 사이 거리 공식
    final dx = endX - startX;
    final dy = endY - startY;
    final lenSq = dx * dx + dy * dy;
    if (lenSq == 0) return (point - Offset(startX, startY)).distance;
    return ((point.dx - startX) * dy - (point.dy - startY) * dx).abs() /
        math.sqrt(lenSq);
  }

  /// 날짜에 가장 가까운 데이터 인덱스 찾기
  static int? findDateIndex(List<OHLCData> data, DateTime target) {
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

  /// 피보나치 hit test: 가장 가까운 레벨 선까지 거리
  static double fibonacciDistance(
    Offset point,
    ChartDrawing drawing,
    ChartYRange yRange,
  ) {
    if (drawing.startPrice == null || drawing.endPrice == null) {
      return double.infinity;
    }
    final highPrice = drawing.startPrice!;
    final lowPrice = drawing.endPrice!;
    const levels = [0.0, 0.236, 0.382, 0.5, 0.618, 0.786, 1.0];

    double minDist = double.infinity;
    for (final ratio in levels) {
      final price = lowPrice + (highPrice - lowPrice) * ratio;
      final lineY = yRange.toY(price);
      final dist = (point.dy - lineY).abs();
      if (dist < minDist) minDist = dist;
    }
    return minDist;
  }

  /// 지지/저항 영역 hit test
  static double zoneDistance(
    Offset point,
    ChartDrawing drawing,
    ChartYRange yRange,
  ) {
    final upperY = yRange.toY(drawing.price);
    final lowerY = yRange.toY(drawing.lowerPrice);
    final top = math.min(upperY, lowerY);
    final bottom = math.max(upperY, lowerY);

    // 영역 안이면 0
    if (point.dy >= top && point.dy <= bottom) return 0;
    // 밖이면 가장 가까운 경계까지
    return math.min((point.dy - top).abs(), (point.dy - bottom).abs());
  }

  /// 선택된 드로잉의 Y 픽셀 좌표 계산 (인라인 버튼 위치용)
  static double? getSelectedLineY(
    String? selectedDrawingId,
    List<ChartDrawing> drawings,
    ChartYRange yRange,
  ) {
    if (selectedDrawingId == null) return null;
    final selected = drawings.where((d) => d.id == selectedDrawingId).firstOrNull;
    if (selected == null) return null;

    if (selected.type == DrawingType.horizontalLine) {
      return yRange.toY(selected.price);
    }
    // 추세선/피보나치: 중간점의 Y 좌표 사용
    if (selected.type == DrawingType.trendLine || selected.type == DrawingType.fibonacci) {
      if (selected.startPrice != null && selected.endPrice != null) {
        return yRange.toY((selected.startPrice! + selected.endPrice!) / 2);
      }
    }
    // 지지/저항 영역: 중간 가격의 Y 좌표
    if (selected.type == DrawingType.supportResistanceZone) {
      return yRange.toY((selected.price + selected.lowerPrice) / 2);
    }
    return null;
  }
}
