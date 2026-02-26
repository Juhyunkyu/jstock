import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/ohlc_data.dart';
import '../../utils/chart_utils.dart';

/// 캔들스틱 차트 (이동평균선 포함, 확대/축소/스크롤 지원)
class CompactCandlestickChart extends StatefulWidget {
  final List<OHLCData> data;
  final String selectedPeriod;

  const CompactCandlestickChart({
    super.key,
    required this.data,
    required this.selectedPeriod,
  });

  @override
  State<CompactCandlestickChart> createState() => _CompactCandlestickChartState();
}

class _CompactCandlestickChartState extends State<CompactCandlestickChart> {
  static const int _minVisibleCount = 15;
  static const int _defaultVisibleCount = 60;

  int _visibleCount = _defaultVisibleCount;
  int _scrollOffset = 0; // 0 = 가장 최근 데이터가 오른쪽 끝
  int _baseVisibleCount = _defaultVisibleCount;

  @override
  void didUpdateWidget(covariant CompactCandlestickChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data.length != widget.data.length ||
        oldWidget.selectedPeriod != widget.selectedPeriod) {
      _visibleCount = _defaultVisibleCount.clamp(1, widget.data.length.clamp(1, _defaultVisibleCount));
      _scrollOffset = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    if (data.isEmpty) {
      return const Center(
        child: Text('데이터 없음', style: TextStyle(color: AppColors.textHint, fontSize: 10)),
      );
    }

    final maxVisible = data.length;
    final visibleCount = _visibleCount.clamp(_minVisibleCount, maxVisible);
    final maxOffset = (maxVisible - visibleCount).clamp(0, maxVisible);
    final scrollOffset = _scrollOffset.clamp(0, maxOffset);

    final endIdx = data.length - scrollOffset;
    final startIdx = (endIdx - visibleCount).clamp(0, data.length);
    final displayData = data.sublist(startIdx, endIdx);

    // 이동평균 계산 (전체 데이터 기준)
    final ma5 = calculateMA(data, 5);
    final ma20 = calculateMA(data, 20);
    final ma60 = calculateMA(data, 60);
    final ma120 = calculateMA(data, 120);

    // 표시 범위에 맞게 자르기
    final displayMa5 = _sliceMA(ma5, startIdx, endIdx);
    final displayMa20 = _sliceMA(ma20, startIdx, endIdx);
    final displayMa60 = _sliceMA(ma60, startIdx, endIdx);
    final displayMa120 = _sliceMA(ma120, startIdx, endIdx);

    return Listener(
      onPointerSignal: (event) {
        if (event is PointerScrollEvent) {
          _onMouseWheel(event.scrollDelta.dy);
        }
      },
      child: GestureDetector(
        onScaleStart: _onScaleStart,
        onScaleUpdate: _onScaleUpdate,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return CustomPaint(
              size: Size(constraints.maxWidth, constraints.maxHeight),
              painter: _CompactCandlestickPainter(
                data: displayData,
                ma5: displayMa5,
                ma20: displayMa20,
                ma60: displayMa60,
                ma120: displayMa120,
                selectedPeriod: widget.selectedPeriod,
                isDesktop: MediaQuery.of(context).size.width >= 768,
              ),
            );
          },
        ),
      ),
    );
  }

  List<double> _sliceMA(List<double> ma, int startIdx, int endIdx) {
    if (ma.length <= startIdx) return <double>[];
    return ma.sublist(startIdx, endIdx.clamp(0, ma.length));
  }

  void _onMouseWheel(double deltaY) {
    setState(() {
      final zoomStep = (_visibleCount * 0.1).round().clamp(1, 10);
      if (deltaY > 0) {
        _visibleCount = (_visibleCount + zoomStep).clamp(_minVisibleCount, widget.data.length);
      } else {
        _visibleCount = (_visibleCount - zoomStep).clamp(_minVisibleCount, widget.data.length);
      }
      final maxOffset = (widget.data.length - _visibleCount).clamp(0, widget.data.length);
      _scrollOffset = _scrollOffset.clamp(0, maxOffset);
    });
  }

  void _onScaleStart(ScaleStartDetails details) {
    _baseVisibleCount = _visibleCount;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    setState(() {
      if (details.pointerCount >= 2) {
        // 핀치 줌
        _visibleCount = (_baseVisibleCount / details.scale)
            .round()
            .clamp(_minVisibleCount, widget.data.length);
      } else {
        // 수평 드래그 (한 손가락)
        final sensitivity = _visibleCount / 200.0;
        final delta = (details.focalPointDelta.dx * sensitivity).round();
        _scrollOffset = (_scrollOffset + delta)
            .clamp(0, (widget.data.length - _visibleCount).clamp(0, widget.data.length));
      }
      final maxOffset = (widget.data.length - _visibleCount).clamp(0, widget.data.length);
      _scrollOffset = _scrollOffset.clamp(0, maxOffset);
    });
  }
}

/// 캔들스틱 페인터
class _CompactCandlestickPainter extends CustomPainter {
  final List<OHLCData> data;
  final List<double> ma5;
  final List<double> ma20;
  final List<double> ma60;
  final List<double> ma120;
  final String selectedPeriod;
  final bool isDesktop;

  _CompactCandlestickPainter({
    required this.data,
    required this.ma5,
    required this.ma20,
    required this.ma60,
    required this.ma120,
    required this.selectedPeriod,
    required this.isDesktop,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    const double topPadding = 5;
    const double bottomPadding = 20;
    const double rightPadding = 35;
    const double leftPadding = 5;

    final chartWidth = size.width - leftPadding - rightPadding;
    final chartHeight = size.height - topPadding - bottomPadding;

    // Y축 범위 계산
    double minY = double.infinity;
    double maxY = double.negativeInfinity;

    for (final candle in data) {
      if (candle.low < minY) minY = candle.low;
      if (candle.high > maxY) maxY = candle.high;
    }

    // 이동평균선 범위도 포함
    for (final ma in [ma5, ma20, ma60, ma120]) {
      for (final v in ma) {
        if (!v.isNaN) {
          if (v < minY) minY = v;
          if (v > maxY) maxY = v;
        }
      }
    }

    final range = maxY - minY;
    final padding = range * 0.05;
    minY -= padding;
    maxY += padding;

    // 캔들 너비 계산
    final candleWidth = chartWidth / data.length;
    final bodyWidth = candleWidth * 0.7;

    // 캔들 그리기
    for (int i = 0; i < data.length; i++) {
      final candle = data[i];
      final x = leftPadding + i * candleWidth + candleWidth / 2;

      final openY = topPadding + (1 - (candle.open - minY) / (maxY - minY)) * chartHeight;
      final closeY = topPadding + (1 - (candle.close - minY) / (maxY - minY)) * chartHeight;
      final highY = topPadding + (1 - (candle.high - minY) / (maxY - minY)) * chartHeight;
      final lowY = topPadding + (1 - (candle.low - minY) / (maxY - minY)) * chartHeight;

      final isUp = candle.close >= candle.open;
      final color = isUp ? AppColors.stockUp : AppColors.stockDown;

      // 심지 (wick)
      final wickPaint = Paint()
        ..color = color
        ..strokeWidth = 1;
      canvas.drawLine(Offset(x, highY), Offset(x, lowY), wickPaint);

      // 몸통 (body)
      final bodyPaint = Paint()
        ..color = color
        ..style = isUp ? PaintingStyle.stroke : PaintingStyle.fill
        ..strokeWidth = 1;

      final bodyTop = isUp ? closeY : openY;
      final bodyBottom = isUp ? openY : closeY;
      final bodyHeight = (bodyBottom - bodyTop).abs();

      canvas.drawRect(
        Rect.fromLTWH(x - bodyWidth / 2, bodyTop, bodyWidth, bodyHeight < 1 ? 1 : bodyHeight),
        bodyPaint,
      );
    }

    // 이동평균선 그리기
    _drawMA(canvas, ma5, const Color(0xFFFF6B6B), chartWidth, chartHeight, minY, maxY, leftPadding, topPadding);
    _drawMA(canvas, ma20, const Color(0xFFFFD93D), chartWidth, chartHeight, minY, maxY, leftPadding, topPadding);
    _drawMA(canvas, ma60, const Color(0xFF6BCB77), chartWidth, chartHeight, minY, maxY, leftPadding, topPadding);
    _drawMA(canvas, ma120, const Color(0xFF4D96FF), chartWidth, chartHeight, minY, maxY, leftPadding, topPadding);

    // Y축 라벨
    _drawYAxisLabels(canvas, size, minY, maxY, topPadding, chartHeight, rightPadding);

    // X축 날짜 라벨
    _drawXAxisLabels(canvas, size, leftPadding, chartWidth, topPadding, chartHeight, bottomPadding);
  }

  void _drawMA(Canvas canvas, List<double> ma, Color color, double chartWidth, double chartHeight, double minY, double maxY, double leftPadding, double topPadding) {
    if (ma.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final path = Path();
    bool started = false;
    final candleWidth = chartWidth / data.length;

    for (int i = 0; i < ma.length && i < data.length; i++) {
      if (ma[i].isNaN) continue;

      final x = leftPadding + i * candleWidth + candleWidth / 2;
      final y = topPadding + (1 - (ma[i] - minY) / (maxY - minY)) * chartHeight;

      if (!started) {
        path.moveTo(x, y);
        started = true;
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);
  }

  void _drawYAxisLabels(Canvas canvas, Size size, double minY, double maxY, double topPadding, double chartHeight, double rightPadding) {
    final textStyle = TextStyle(
      color: AppColors.textHint,
      fontSize: isDesktop ? 10 : 8,
    );

    final values = [maxY, (maxY + minY) / 2, minY];
    final yPositions = [topPadding, topPadding + chartHeight / 2, topPadding + chartHeight];

    for (int i = 0; i < values.length; i++) {
      final textSpan = TextSpan(
        text: formatAxisPrice(values[i]),
        style: textStyle,
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: ui.TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(size.width - rightPadding + 4, yPositions[i] - textPainter.height / 2),
      );
    }
  }

  void _drawXAxisLabels(Canvas canvas, Size size, double leftPadding, double chartWidth, double topPadding, double chartHeight, double bottomPadding) {
    if (data.isEmpty) return;

    final textStyle = TextStyle(
      color: AppColors.textHint,
      fontSize: isDesktop ? 10 : 8,
    );

    // 4개의 라벨 표시
    final labelCount = 4;
    final step = (data.length / labelCount).floor();

    for (int i = 0; i < labelCount; i++) {
      final idx = (i * step).clamp(0, data.length - 1);
      final date = data[idx].date;
      final x = leftPadding + idx * (chartWidth / data.length) + (chartWidth / data.length) / 2;

      String label;
      switch (selectedPeriod) {
        case '일':
          label = DateFormat('MM/dd').format(date);
          break;
        case '주':
          label = DateFormat('yy/MM').format(date);
          break;
        case '월':
          label = DateFormat('yyyy').format(date);
          break;
        default:
          label = DateFormat('MM/dd').format(date);
      }

      final textSpan = TextSpan(text: label, style: textStyle);
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: ui.TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, topPadding + chartHeight + 4),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CompactCandlestickPainter oldDelegate) {
    return oldDelegate.data != data ||
           oldDelegate.selectedPeriod != selectedPeriod ||
           oldDelegate.isDesktop != isDesktop;
  }
}
