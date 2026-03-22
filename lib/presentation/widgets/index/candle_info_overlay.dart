import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/ohlc_data.dart';

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
    final hintStyle = TextStyle(
      fontSize: 10,
      color: context.appTextHint,
      height: 1.3,
    );
    final priceStyle = TextStyle(
      fontSize: 10,
      color: context.appTextPrimary,
      fontWeight: FontWeight.w600,
      height: 1.3,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: context.appSurface.withValues(alpha: 235 / 255),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: 날짜
          Text(_formatDate(), style: hintStyle),
          const SizedBox(height: 1),
          // Row 2: 시 + 고
          _buildPriceRow(
            context,
            label1: '시',
            value1: candle.open,
            label2: '고',
            value2: candle.high,
            hintStyle: hintStyle,
            priceStyle: priceStyle,
          ),
          const SizedBox(height: 1),
          // Row 3: 저 + 종
          _buildPriceRow(
            context,
            label1: '저',
            value1: candle.low,
            label2: '종',
            value2: candle.close,
            hintStyle: hintStyle,
            priceStyle: priceStyle,
          ),
          const SizedBox(height: 1),
          // Row 4: 거래량 + 거래대금
          RichText(
            text: TextSpan(
              children: [
                TextSpan(text: '거래량 ', style: hintStyle),
                TextSpan(
                  text: _formatKoreanVolume(candle.volume),
                  style: priceStyle,
                ),
                TextSpan(text: '  거래대금 ', style: hintStyle),
                TextSpan(
                  text: _formatKoreanVolume(candle.close * candle.volume),
                  style: priceStyle,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceRow(
    BuildContext context, {
    required String label1,
    required double value1,
    required String label2,
    required double value2,
    required TextStyle hintStyle,
    required TextStyle priceStyle,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildPriceSpan(label1, value1, hintStyle, priceStyle),
        const SizedBox(width: 10),
        _buildPriceSpan(label2, value2, hintStyle, priceStyle),
      ],
    );
  }

  Widget _buildPriceSpan(
    String label,
    double value,
    TextStyle hintStyle,
    TextStyle priceStyle,
  ) {
    final change = _changeFor(value);
    final changeColor = change >= 0 ? AppColors.red500 : AppColors.blue500;
    final sign = change >= 0 ? '+' : '';
    final changeStyle = TextStyle(
      fontSize: 9,
      color: changeColor,
      height: 1.3,
    );

    return RichText(
      text: TextSpan(
        children: [
          TextSpan(text: '$label ', style: hintStyle),
          TextSpan(text: value.toStringAsFixed(2), style: priceStyle),
          TextSpan(
            text: '($sign${change.toStringAsFixed(2)}%)',
            style: changeStyle,
          ),
        ],
      ),
    );
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
      // 1억 이상
      final eok = absV / 1e8;
      if (eok >= 10) {
        return '${formatter.format(eok.round())}억';
      }
      return '${eok.toStringAsFixed(1)}억';
    } else if (absV >= 1e4) {
      // 1만 이상
      final man = absV / 1e4;
      if (man >= 10) {
        return '${formatter.format(man.round())}만';
      }
      return '${man.toStringAsFixed(1)}만';
    } else if (absV >= 1e3) {
      // 1천 이상
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
