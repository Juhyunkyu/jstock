import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/ohlc_data.dart';
import '../../utils/chart_utils.dart';

class CandleInfoOverlay extends StatelessWidget {
  final OHLCData candle;
  final OHLCData? previousCandle;
  final String selectedPeriod;

  const CandleInfoOverlay({
    super.key,
    required this.candle,
    this.previousCandle,
    required this.selectedPeriod,
  });

  @override
  Widget build(BuildContext context) {
    final changePercent = _calcChangePercent();
    final isPositive = changePercent >= 0;
    final changeColor =
        isPositive ? AppColors.red500 : AppColors.blue500;

    final labelStyle = TextStyle(
      fontSize: 10,
      color: context.appTextHint,
      height: 1.3,
    );
    final valueStyle = TextStyle(
      fontSize: 10,
      color: context.appTextPrimary,
      fontWeight: FontWeight.w500,
      height: 1.3,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: context.appSurface.withValues(alpha: 230 / 255),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: 날짜 + 등락률
          Row(
            children: [
              Text(_formatDate(), style: valueStyle),
              const SizedBox(width: 8),
              Text(
                '${isPositive ? "+" : ""}${changePercent.toStringAsFixed(2)}%',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: changeColor,
                  height: 1.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          // Row 2: O H L C
          RichText(
            text: TextSpan(
              children: [
                TextSpan(text: 'O ', style: labelStyle),
                TextSpan(
                    text: candle.open.toStringAsFixed(2), style: valueStyle),
                TextSpan(text: '  H ', style: labelStyle),
                TextSpan(
                    text: candle.high.toStringAsFixed(2), style: valueStyle),
                TextSpan(text: '  L ', style: labelStyle),
                TextSpan(
                    text: candle.low.toStringAsFixed(2), style: valueStyle),
                TextSpan(text: '  C ', style: labelStyle),
                TextSpan(
                    text: candle.close.toStringAsFixed(2), style: valueStyle),
              ],
            ),
          ),
          const SizedBox(height: 2),
          // Row 3: VOL + 거래대금
          RichText(
            text: TextSpan(
              children: [
                TextSpan(text: 'VOL ', style: labelStyle),
                TextSpan(
                    text: formatVolume(candle.volume), style: valueStyle),
                TextSpan(text: '  거래대금 ', style: labelStyle),
                TextSpan(
                  text: formatVolume(candle.close * candle.volume),
                  style: valueStyle,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  double _calcChangePercent() {
    if (previousCandle != null && previousCandle!.close != 0) {
      return (candle.close - previousCandle!.close) /
          previousCandle!.close *
          100;
    }
    return candle.changePercent;
  }

  String _formatDate() {
    final d = candle.date;
    switch (selectedPeriod) {
      case '1day':
        final weekdays = ['월', '화', '수', '목', '금', '토', '일'];
        final dayOfWeek = weekdays[d.weekday - 1];
        return '${DateFormat('MM/dd').format(d)}($dayOfWeek)';
      case '1week':
        return DateFormat('yyyy.MM.dd').format(d);
      case '1month':
        return DateFormat('yyyy.MM').format(d);
      default:
        return DateFormat('MM/dd').format(d);
    }
  }
}
