import '../../data/models/ohlc_data.dart';

/// 이동평균 계산 (period 미만 구간은 NaN)
List<double> calculateMA(List<OHLCData> data, int period) {
  if (data.length < period) return [];
  final result = <double>[];
  for (int i = 0; i < data.length; i++) {
    if (i < period - 1) {
      result.add(double.nan);
    } else {
      double sum = 0;
      for (int j = i - period + 1; j <= i; j++) {
        sum += data[j].close;
      }
      result.add(sum / period);
    }
  }
  return result;
}

/// 거래량 포맷: B/M/K 단위
String formatVolume(double v) {
  final absV = v.abs();
  final sign = v < 0 ? '-' : '';
  if (absV >= 1e9) return '$sign${(absV / 1e9).toStringAsFixed(1)}B';
  if (absV >= 1e6) return '$sign${(absV / 1e6).toStringAsFixed(1)}M';
  if (absV >= 1e3) return '$sign${(absV / 1e3).toStringAsFixed(0)}K';
  return '$sign${absV.toStringAsFixed(0)}';
}

/// 축 가격 포맷: K 단위
String formatAxisPrice(double price) {
  if (price >= 10000) return '${(price / 1000).toStringAsFixed(1)}K';
  if (price >= 1000) return '${(price / 1000).toStringAsFixed(2)}K';
  return price.toStringAsFixed(0);
}
