/// OHLC (Open-High-Low-Close) 캔들스틱 데이터
///
/// 차트 표시를 위한 가격 데이터 모델
class OHLCData {
  final DateTime date;
  final double open;
  final double high;
  final double low;
  final double close;
  final double volume;

  const OHLCData({
    required this.date,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    this.volume = 0,
  });

  /// 상승 캔들 여부 (종가 >= 시가)
  bool get isBullish => close >= open;

  /// 하락 캔들 여부 (종가 < 시가)
  bool get isBearish => close < open;

  /// 캔들 몸통 크기
  double get bodySize => (close - open).abs();

  /// 캔들 전체 범위 (고가 - 저가)
  double get range => high - low;

  /// 일일 변동률 (%)
  double get changePercent {
    if (open == 0) return 0;
    return ((close - open) / open) * 100;
  }

  @override
  String toString() {
    return 'OHLCData(date: $date, O: $open, H: $high, L: $low, C: $close, V: $volume)';
  }

  /// JSON에서 생성
  factory OHLCData.fromJson(Map<String, dynamic> json) {
    return OHLCData(
      date: DateTime.parse(json['date'] as String),
      open: (json['open'] as num).toDouble(),
      high: (json['high'] as num).toDouble(),
      low: (json['low'] as num).toDouble(),
      close: (json['close'] as num).toDouble(),
      volume: (json['volume'] as num?)?.toDouble() ?? 0,
    );
  }

  /// JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'open': open,
      'high': high,
      'low': low,
      'close': close,
      'volume': volume,
    };
  }
}
