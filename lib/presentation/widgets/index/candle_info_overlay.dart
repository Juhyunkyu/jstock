import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/ohlc_data.dart';
import 'chart_indicator_calculator.dart';

class CandleInfoOverlay extends StatelessWidget {
  final OHLCData candle;
  final OHLCData? previousCandle;
  final String selectedPeriod;
  final double candleX;
  final double chartWidth;
  final ChartIndicatorData? indicators;
  final int displayIndex;

  const CandleInfoOverlay({
    super.key,
    required this.candle,
    this.previousCandle,
    required this.selectedPeriod,
    required this.candleX,
    required this.chartWidth,
    this.indicators,
    required this.displayIndex,
  });

  @override
  Widget build(BuildContext context) {
    final hintStyle = TextStyle(
      fontSize: 10,
      color: context.appTextHint,
      height: 1.2,
    );
    final valueStyle = TextStyle(
      fontSize: 10,
      color: context.appTextPrimary,
      fontWeight: FontWeight.w600,
      height: 1.2,
    );

    final rows = <Widget>[
      // 날짜
      Text(_formatDate(), style: hintStyle),
      const SizedBox(height: 2),
      // OHLC
      _buildOhlcRow(context, '시', candle.open, hintStyle, valueStyle),
      const SizedBox(height: 2),
      _buildOhlcRow(context, '고', candle.high, hintStyle, valueStyle),
      const SizedBox(height: 2),
      _buildOhlcRow(context, '저', candle.low, hintStyle, valueStyle),
      const SizedBox(height: 2),
      _buildOhlcRow(context, '종', candle.close, hintStyle, valueStyle),
      const SizedBox(height: 2),
      // 거래량
      _buildLabelValueRow('거래량', _formatKoreanVolume(candle.volume), hintStyle, valueStyle),
      const SizedBox(height: 2),
      // 거래대금
      _buildLabelValueRow('거래대금', _formatKoreanVolume(candle.close * candle.volume), hintStyle, valueStyle),
    ];

    // 보조지표
    final indicatorRows = _buildIndicatorRows(hintStyle, valueStyle);
    if (indicatorRows.isNotEmpty) {
      rows.add(const SizedBox(height: 4));
      rows.addAll(indicatorRows);
    }

    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: context.appSurface.withValues(alpha: 235 / 255),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: context.appDivider,
            width: 0.5,
          ),
        ),
      child: IntrinsicWidth(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: rows,
        ),
      ),
    );
  }

  /// OHLC 행: 라벨 + 가격 + 등락률
  Widget _buildOhlcRow(
    BuildContext context,
    String label,
    double price,
    TextStyle hintStyle,
    TextStyle valueStyle,
  ) {
    final change = _changeFor(price);
    final isUp = change >= 0;
    final changeColor = isUp ? AppColors.red500 : AppColors.blue500;
    final sign = isUp ? '+' : '';
    final changeStyle = TextStyle(
      fontSize: 9,
      color: changeColor,
      height: 1.2,
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 14,
          child: Text(label, style: hintStyle),
        ),
        const SizedBox(width: 4),
        Text(price.toStringAsFixed(2), style: valueStyle),
        const SizedBox(width: 4),
        Text('$sign${change.toStringAsFixed(2)}%', style: changeStyle),
      ],
    );
  }

  /// 라벨 + 값 행 (거래량, 거래대금, 보조지표)
  Widget _buildLabelValueRow(
    String label,
    String value,
    TextStyle hintStyle,
    TextStyle valueStyle,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: hintStyle),
        const SizedBox(width: 6),
        Text(value, style: valueStyle),
      ],
    );
  }

  /// 보조지표 행 목록
  List<Widget> _buildIndicatorRows(TextStyle hintStyle, TextStyle valueStyle) {
    final ind = indicators;
    if (ind == null) return [];
    final idx = displayIndex;
    final rows = <Widget>[];

    // BB
    if (ind.displayBB != null && idx < ind.displayBB!.length) {
      final bb = ind.displayBB![idx];
      if (bb.upper != null) {
        rows.add(_buildLabelValueRow('BB 상단', bb.upper!.toStringAsFixed(2), hintStyle, valueStyle));
        rows.add(const SizedBox(height: 2));
      }
      if (bb.middle != null) {
        rows.add(_buildLabelValueRow('BB 중간', bb.middle!.toStringAsFixed(2), hintStyle, valueStyle));
        rows.add(const SizedBox(height: 2));
      }
      if (bb.lower != null) {
        rows.add(_buildLabelValueRow('BB 하단', bb.lower!.toStringAsFixed(2), hintStyle, valueStyle));
        rows.add(const SizedBox(height: 2));
      }
    }

    // RSI
    if (ind.displayRSI != null && idx < ind.displayRSI!.length) {
      final rsi = ind.displayRSI![idx];
      if (rsi != null) {
        rows.add(_buildLabelValueRow('RSI', rsi.toStringAsFixed(1), hintStyle, valueStyle));
        rows.add(const SizedBox(height: 2));
      }
    }

    // MACD
    if (ind.displayMACD != null && idx < ind.displayMACD!.length) {
      final macd = ind.displayMACD![idx];
      if (macd.macdLine != null) {
        rows.add(_buildLabelValueRow('MACD', macd.macdLine!.toStringAsFixed(2), hintStyle, valueStyle));
        rows.add(const SizedBox(height: 2));
      }
      if (macd.signalLine != null) {
        rows.add(_buildLabelValueRow('Signal', macd.signalLine!.toStringAsFixed(2), hintStyle, valueStyle));
        rows.add(const SizedBox(height: 2));
      }
    }

    // Stochastic
    if (ind.displayStoch != null && idx < ind.displayStoch!.length) {
      final stoch = ind.displayStoch![idx];
      if (stoch.k != null) {
        rows.add(_buildLabelValueRow('Stoch %K', stoch.k!.toStringAsFixed(1), hintStyle, valueStyle));
        rows.add(const SizedBox(height: 2));
      }
      if (stoch.d != null) {
        rows.add(_buildLabelValueRow('Stoch %D', stoch.d!.toStringAsFixed(1), hintStyle, valueStyle));
        rows.add(const SizedBox(height: 2));
      }
    }

    // OBV
    if (ind.displayOBV != null && idx < ind.displayOBV!.length) {
      final obv = ind.displayOBV![idx];
      rows.add(_buildLabelValueRow('OBV', _formatKoreanVolume(obv), hintStyle, valueStyle));
      rows.add(const SizedBox(height: 2));
    }

    // 마지막 SizedBox 제거
    if (rows.isNotEmpty && rows.last is SizedBox) {
      rows.removeLast();
    }

    return rows;
  }

  /// 전일 종가 대비 개별 등락률
  double _changeFor(double value) {
    if (previousCandle == null || previousCandle!.close == 0) return 0;
    return (value - previousCandle!.close) / previousCandle!.close * 100;
  }

  /// 한글 단위 포맷 (만, 억)
  String _formatKoreanVolume(double v) {
    final absV = v.abs();
    final formatter = NumberFormat('#,###');

    if (absV >= 1e8) {
      final eok = absV / 1e8;
      if (eok >= 10) {
        return '${formatter.format(eok.round())}억';
      }
      return '${eok.toStringAsFixed(1)}억';
    } else if (absV >= 1e4) {
      final man = absV / 1e4;
      if (man >= 10) {
        return '${formatter.format(man.round())}만';
      }
      return '${man.toStringAsFixed(1)}만';
    } else if (absV >= 1e3) {
      return formatter.format(absV.round());
    }
    return absV.toStringAsFixed(0);
  }

  String _formatDate() {
    final d = candle.date;
    switch (selectedPeriod) {
      case '1day':
        final weekdays = ['월', '화', '수', '목', '금', '토', '일'];
        final dayOfWeek = weekdays[d.weekday - 1];
        return '${DateFormat('yy/MM/dd').format(d)}($dayOfWeek)';
      case '1week':
        return DateFormat('yy/MM/dd').format(d);
      case '1month':
        return DateFormat('yyyy.MM').format(d);
      default:
        return DateFormat('yy/MM/dd').format(d);
    }
  }
}
