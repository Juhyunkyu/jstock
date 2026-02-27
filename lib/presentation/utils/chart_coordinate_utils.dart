import 'dart:math' as math;
import '../../data/models/ohlc_data.dart';
import '../../data/services/technical_indicator_service.dart';

/// 차트 Y축 범위 + 좌표 변환 유틸리티
///
/// painter와 drawing overlay가 동일한 좌표계를 공유하도록 보장합니다.
class ChartYRange {
  final double minY;
  final double maxY;
  final double topPadding;
  final double chartHeight;
  final double leftPadding;
  final double chartWidth;
  final int dataLength;

  const ChartYRange({
    required this.minY,
    required this.maxY,
    required this.topPadding,
    required this.chartHeight,
    required this.leftPadding,
    required this.chartWidth,
    required this.dataLength,
  });

  /// 가격 → Y 픽셀
  double toY(double price) {
    return topPadding + (1 - (price - minY) / (maxY - minY)) * chartHeight;
  }

  /// 데이터 인덱스 → X 픽셀 (캔들 중심)
  double toX(int index) {
    final candleWidth = chartWidth / dataLength;
    return leftPadding + index * candleWidth + candleWidth / 2;
  }

  /// Y 픽셀 → 가격
  double fromY(double pixel) {
    return minY + (1 - (pixel - topPadding) / chartHeight) * (maxY - minY);
  }

  /// X 픽셀 → 데이터 인덱스 (반올림)
  int fromX(double pixel) {
    final candleWidth = chartWidth / dataLength;
    return ((pixel - leftPadding) / candleWidth).round().clamp(0, dataLength - 1);
  }

  double get candleWidth => chartWidth / dataLength;
}

/// 차트 좌표 계산기
///
/// detail_candlestick_painter.dart의 Y축 범위 계산 로직을 추출하여
/// painter와 overlay가 동일한 좌표 변환을 사용합니다.
class ChartCoordinateCalculator {
  /// 차트 좌표 범위 계산
  ///
  /// [data] 표시할 OHLC 데이터 (displayData)
  /// [size] 차트 위젯 전체 크기
  /// [bollingerBands] BB 지표 (nullable)
  /// [ichimoku] 일목균형표 지표 (nullable)
  /// [bbSummary] BB 요약 텍스트 (overlay 개수 계산용)
  /// [ichSummary] 일목 요약 텍스트 (overlay 개수 계산용)
  static ChartYRange calculate({
    required List<OHLCData> data,
    required double width,
    required double height,
    List<BBResult>? bollingerBands,
    List<IchimokuResult>? ichimoku,
    String? bbSummary,
    String? ichSummary,
  }) {
    final int overlayCount =
        (bbSummary != null ? 1 : 0) + (ichSummary != null ? 1 : 0);
    final double topPadding = 30.0 + overlayCount * 16.0;
    const double bottomPadding = 25;
    const double rightPadding = 50;
    const double leftPadding = 10;

    final chartWidth = width - leftPadding - rightPadding;
    final chartHeight = height - topPadding - bottomPadding;

    // Y축 범위: Clamped Extension Hybrid 알고리즘
    double candleMin = double.infinity;
    double candleMax = double.negativeInfinity;

    for (int i = 0; i < data.length; i++) {
      final candle = data[i];
      if (candle.low < candleMin) candleMin = candle.low;
      if (candle.high > candleMax) candleMax = candle.high;
    }

    final candleRange = candleMax - candleMin;

    // 보조지표 범위 수집 (BB, 일목만)
    double indicatorMin = double.infinity;
    double indicatorMax = double.negativeInfinity;

    if (bollingerBands != null) {
      for (final bb in bollingerBands) {
        if (bb.upper != null) {
          indicatorMin = math.min(indicatorMin, bb.upper!);
          indicatorMax = math.max(indicatorMax, bb.upper!);
        }
        if (bb.lower != null) {
          indicatorMin = math.min(indicatorMin, bb.lower!);
          indicatorMax = math.max(indicatorMax, bb.lower!);
        }
      }
    }

    if (ichimoku != null) {
      for (final ich in ichimoku) {
        for (final v in [ich.senkouA, ich.senkouB, ich.tenkan, ich.kijun]) {
          if (v != null) {
            indicatorMin = math.min(indicatorMin, v);
            indicatorMax = math.max(indicatorMax, v);
          }
        }
      }
    }

    // 반응형 확장 계수: 모바일(30%), 데스크톱(20%)
    final bool isMobile = width < 600;
    final double extensionFactor = isMobile ? 0.30 : 0.20;
    final double maxExtension = candleRange * extensionFactor;

    // 지표 방향으로 캡 제한 확장
    double minY = candleMin;
    double maxY = candleMax;

    if (indicatorMin < double.infinity) {
      minY = math.max(indicatorMin, candleMin - maxExtension);
      minY = math.min(minY, candleMin);
    }
    if (indicatorMax > double.negativeInfinity) {
      maxY = math.min(indicatorMax, candleMax + maxExtension);
      maxY = math.max(maxY, candleMax);
    }

    // 비대칭 패딩: 상단 여유 > 하단
    final double range = maxY - minY;
    final double topPad = range * (isMobile ? 0.10 : 0.08);
    final double bottomPad = range * (isMobile ? 0.08 : 0.05);
    minY -= bottomPad;
    maxY += topPad;

    return ChartYRange(
      minY: minY,
      maxY: maxY,
      topPadding: topPadding,
      chartHeight: chartHeight,
      leftPadding: leftPadding,
      chartWidth: chartWidth,
      dataLength: data.length,
    );
  }
}
