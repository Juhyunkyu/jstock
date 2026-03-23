import '../../data/models/ohlc_data.dart';

/// 다이버전스 유형
enum DivergenceType { bullish, bearish }

/// 감지된 다이버전스
class Divergence {
  final DivergenceType type;

  /// fullData 기준 첫 번째 피봇 인덱스
  final int firstIndex;

  /// fullData 기준 두 번째 피봇 인덱스
  final int secondIndex;

  final double firstRSI;
  final double secondRSI;

  /// 가격 저점(bullish) 또는 고점(bearish)
  final double firstPrice;
  final double secondPrice;

  const Divergence({
    required this.type,
    required this.firstIndex,
    required this.secondIndex,
    required this.firstRSI,
    required this.secondRSI,
    required this.firstPrice,
    required this.secondPrice,
  });

  @override
  String toString() {
    final label = type == DivergenceType.bullish ? 'Bullish' : 'Bearish';
    return '$label Divergence('
        'first: [$firstIndex] price=$firstPrice rsi=$firstRSI, '
        'second: [$secondIndex] price=$secondPrice rsi=$secondRSI)';
  }
}

/// RSI 다이버전스 자동 감지기
///
/// Pivot High/Low 기반으로 Regular Bullish/Bearish Divergence를 감지한다.
/// - Pivot 확정에 [pivotRight]캔들이 필요하므로 마지막 [pivotRight]캔들에서는
///   피봇이 확정되지 않는다 (non-repainting).
/// - 가격의 Pivot 인덱스를 기준으로 해당 인덱스의 RSI 값을 사용한다.
class RSIDivergenceDetector {
  /// 피봇 좌측 확인 캔들 수
  static const int pivotLeft = 5;

  /// 피봇 우측 확인 캔들 수 (확정 지연)
  static const int pivotRight = 5;

  /// 두 피봇 간 최소 거리 (캔들 수)
  static const int minBarsBetween = 5;

  /// 두 피봇 간 최대 거리 (캔들 수)
  static const int maxBarsBetween = 60;

  /// 과매도 기준 (Bullish divergence 신뢰도 필터)
  static const double oversoldLevel = 40.0;

  /// 과매수 기준 (Bearish divergence 신뢰도 필터)
  static const double overboughtLevel = 60.0;

  RSIDivergenceDetector._();

  /// 전체 데이터에서 다이버전스를 감지하여 반환한다.
  ///
  /// [data]와 [rsi]는 같은 길이, 같은 인덱스여야 한다.
  /// [rsi]에는 초기 계산 불가 구간에서 null이 포함될 수 있다.
  static List<Divergence> detect({
    required List<OHLCData> data,
    required List<double?> rsi,
  }) {
    assert(data.length == rsi.length, 'data와 rsi의 길이가 같아야 합니다');

    if (data.length < pivotLeft + pivotRight + 1) {
      return [];
    }

    final pivotLows = _findPricePivotLows(data);
    final pivotHighs = _findPricePivotHighs(data);

    final bullish = _detectBullishDivergences(pivotLows, data, rsi);
    final bearish = _detectBearishDivergences(pivotHighs, data, rsi);

    final result = [...bullish, ...bearish];
    result.sort((a, b) => a.secondIndex.compareTo(b.secondIndex));

    return result;
  }

  /// 가격(low) 기준 Pivot Low 인덱스 목록을 반환한다.
  ///
  /// 인덱스 i가 Pivot Low이려면:
  /// data[i].low가 좌측 [pivotLeft]캔들의 low 이하이고,
  /// 우측 [pivotRight]캔들의 low보다 strictly 작아야 한다.
  /// 우측을 strict로 하여 동일값 연속 시 첫 번째를 피봇으로 선정한다.
  static List<int> _findPricePivotLows(List<OHLCData> data) {
    final pivots = <int>[];
    final lastCheckable = data.length - pivotRight - 1;

    for (int i = pivotLeft; i <= lastCheckable; i++) {
      if (_isPivotLow(data, i)) {
        pivots.add(i);
      }
    }
    return pivots;
  }

  /// 가격(high) 기준 Pivot High 인덱스 목록을 반환한다.
  static List<int> _findPricePivotHighs(List<OHLCData> data) {
    final pivots = <int>[];
    final lastCheckable = data.length - pivotRight - 1;

    for (int i = pivotLeft; i <= lastCheckable; i++) {
      if (_isPivotHigh(data, i)) {
        pivots.add(i);
      }
    }
    return pivots;
  }

  /// 인덱스 [i]가 가격(low) 기준 Pivot Low인지 판정한다.
  ///
  /// 좌측: data[i].low <= 모든 좌측 캔들의 low
  /// 우측: data[i].low < 모든 우측 캔들의 low (strict)
  static bool _isPivotLow(List<OHLCData> data, int i) {
    final val = data[i].low;

    for (int j = i - pivotLeft; j < i; j++) {
      if (data[j].low < val) return false;
    }

    for (int j = i + 1; j <= i + pivotRight; j++) {
      if (data[j].low <= val) return false;
    }

    return true;
  }

  /// 인덱스 [i]가 가격(high) 기준 Pivot High인지 판정한다.
  ///
  /// 좌측: data[i].high >= 모든 좌측 캔들의 high
  /// 우측: data[i].high > 모든 우측 캔들의 high (strict)
  static bool _isPivotHigh(List<OHLCData> data, int i) {
    final val = data[i].high;

    for (int j = i - pivotLeft; j < i; j++) {
      if (data[j].high > val) return false;
    }

    for (int j = i + 1; j <= i + pivotRight; j++) {
      if (data[j].high >= val) return false;
    }

    return true;
  }

  /// Pivot Low 쌍에서 Regular Bullish Divergence를 감지한다.
  ///
  /// 조건:
  /// - 가격: Lower Low (second.low < first.low)
  /// - RSI: Higher Low (second RSI > first RSI)
  /// - 두 번째 피봇의 RSI가 과매도 영역([oversoldLevel] 미만)
  /// - 두 피봇 사이에 가격 반등이 존재해야 함 (구조적 유효성)
  static List<Divergence> _detectBullishDivergences(
    List<int> pivotLowIndices,
    List<OHLCData> data,
    List<double?> rsi,
  ) {
    final divergences = <Divergence>[];
    final usedAsSecond = <int>{};

    // 최신 피봇부터 역순 탐색 — 가장 최근 다이버전스를 우선 감지
    for (int j = pivotLowIndices.length - 1; j >= 1; j--) {
      final secondIdx = pivotLowIndices[j];

      if (usedAsSecond.contains(secondIdx)) continue;

      final secondRsi = rsi[secondIdx];
      if (secondRsi == null) continue;

      // 과매도 영역 필터
      if (secondRsi >= oversoldLevel) continue;

      final secondPrice = data[secondIdx].low;

      // 이전 피봇들과 비교 (가장 가까운 것부터)
      for (int k = j - 1; k >= 0; k--) {
        final firstIdx = pivotLowIndices[k];
        final distance = secondIdx - firstIdx;

        if (distance < minBarsBetween) continue;
        if (distance > maxBarsBetween) break;

        final firstRsi = rsi[firstIdx];
        if (firstRsi == null) continue;

        final firstPrice = data[firstIdx].low;

        // Regular Bullish: 가격 Lower Low + RSI Higher Low
        if (secondPrice < firstPrice && secondRsi > firstRsi) {
          if (_hasPriceRecoveryBetween(
            data,
            firstIdx,
            secondIdx,
            firstPrice,
            isLow: true,
          )) {
            divergences.add(Divergence(
              type: DivergenceType.bullish,
              firstIndex: firstIdx,
              secondIndex: secondIdx,
              firstRSI: firstRsi,
              secondRSI: secondRsi,
              firstPrice: firstPrice,
              secondPrice: secondPrice,
            ));
            usedAsSecond.add(secondIdx);
            break; // 이 두 번째 피봇에 대해 하나만 매칭
          }
        }
      }
    }

    return divergences;
  }

  /// Pivot High 쌍에서 Regular Bearish Divergence를 감지한다.
  ///
  /// 조건:
  /// - 가격: Higher High (second.high > first.high)
  /// - RSI: Lower High (second RSI < first RSI)
  /// - 두 번째 피봇의 RSI가 과매수 영역([overboughtLevel] 초과)
  /// - 두 피봇 사이에 가격 조정이 존재해야 함 (구조적 유효성)
  static List<Divergence> _detectBearishDivergences(
    List<int> pivotHighIndices,
    List<OHLCData> data,
    List<double?> rsi,
  ) {
    final divergences = <Divergence>[];
    final usedAsSecond = <int>{};

    for (int j = pivotHighIndices.length - 1; j >= 1; j--) {
      final secondIdx = pivotHighIndices[j];

      if (usedAsSecond.contains(secondIdx)) continue;

      final secondRsi = rsi[secondIdx];
      if (secondRsi == null) continue;

      // 과매수 영역 필터
      if (secondRsi <= overboughtLevel) continue;

      final secondPrice = data[secondIdx].high;

      for (int k = j - 1; k >= 0; k--) {
        final firstIdx = pivotHighIndices[k];
        final distance = secondIdx - firstIdx;

        if (distance < minBarsBetween) continue;
        if (distance > maxBarsBetween) break;

        final firstRsi = rsi[firstIdx];
        if (firstRsi == null) continue;

        final firstPrice = data[firstIdx].high;

        // Regular Bearish: 가격 Higher High + RSI Lower High
        if (secondPrice > firstPrice && secondRsi < firstRsi) {
          if (_hasPriceRecoveryBetween(
            data,
            firstIdx,
            secondIdx,
            firstPrice,
            isLow: false,
          )) {
            divergences.add(Divergence(
              type: DivergenceType.bearish,
              firstIndex: firstIdx,
              secondIndex: secondIdx,
              firstRSI: firstRsi,
              secondRSI: secondRsi,
              firstPrice: firstPrice,
              secondPrice: secondPrice,
            ));
            usedAsSecond.add(secondIdx);
            break;
          }
        }
      }
    }

    return divergences;
  }

  /// 두 피봇 사이에 가격 반등/조정이 있었는지 확인한다.
  ///
  /// 유효한 다이버전스는 두 피봇 사이에 의미 있는 가격 움직임이 있어야 한다.
  /// 이것이 없으면 단순히 하락 지속 중 연속 저점일 뿐 다이버전스가 아니다.
  ///
  /// - [isLow] true: 두 저점 사이에 [referencePrice]보다 높은 high 존재 여부
  /// - [isLow] false: 두 고점 사이에 [referencePrice]보다 낮은 low 존재 여부
  static bool _hasPriceRecoveryBetween(
    List<OHLCData> data,
    int firstIdx,
    int secondIdx,
    double referencePrice, {
    required bool isLow,
  }) {
    for (int i = firstIdx + 1; i < secondIdx; i++) {
      if (isLow) {
        if (data[i].high > referencePrice) return true;
      } else {
        if (data[i].low < referencePrice) return true;
      }
    }
    return false;
  }
}
