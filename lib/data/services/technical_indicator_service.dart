import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../models/ohlc_data.dart';

// --- Signal Model ---

enum SignalType { strongBuy, buy, neutral, sell, strongSell }

class IndicatorSignal {
  final SignalType type;
  final String label;
  final Color color;
  const IndicatorSignal({required this.type, required this.label, required this.color});
}

// --- Data Models ---

class MACDResult {
  final double? macdLine;
  final double? signalLine;
  final double? histogram;
  const MACDResult({this.macdLine, this.signalLine, this.histogram});
}

class BBResult {
  final double? upper;
  final double? middle;
  final double? lower;
  const BBResult({this.upper, this.middle, this.lower});
}

class StochResult {
  final double? k;
  final double? d;
  const StochResult({this.k, this.d});
}

class IchimokuResult {
  final double? tenkan;
  final double? kijun;
  final double? senkouA;
  final double? senkouB;
  final double? chikou;
  const IchimokuResult({this.tenkan, this.kijun, this.senkouA, this.senkouB, this.chikou});
}

class TechnicalIndicatorService {
  /// RSI (Relative Strength Index)
  List<double?> calculateRSI(List<double> closes, {int period = 14}) {
    final result = List<double?>.filled(closes.length, null);
    if (closes.length < period + 1) return result;

    // Calculate initial gains and losses
    double avgGain = 0;
    double avgLoss = 0;
    for (int i = 1; i <= period; i++) {
      final change = closes[i] - closes[i - 1];
      if (change > 0) {
        avgGain += change;
      } else {
        avgLoss += change.abs();
      }
    }
    avgGain /= period;
    avgLoss /= period;

    if (avgLoss == 0) {
      result[period] = 100.0;
    } else {
      final rs = avgGain / avgLoss;
      result[period] = 100 - (100 / (1 + rs));
    }

    // Smoothed RSI for remaining periods
    for (int i = period + 1; i < closes.length; i++) {
      final change = closes[i] - closes[i - 1];
      final gain = change > 0 ? change : 0.0;
      final loss = change < 0 ? change.abs() : 0.0;

      avgGain = (avgGain * (period - 1) + gain) / period;
      avgLoss = (avgLoss * (period - 1) + loss) / period;

      if (avgLoss == 0) {
        result[i] = 100.0;
      } else {
        final rs = avgGain / avgLoss;
        result[i] = 100 - (100 / (1 + rs));
      }
    }

    return result;
  }

  /// MACD (Moving Average Convergence Divergence)
  List<MACDResult> calculateMACD(List<double> closes, {int fast = 12, int slow = 26, int signal = 9}) {
    final result = List<MACDResult>.filled(closes.length, const MACDResult());
    if (closes.length < slow) return result;

    final fastEMA = _calculateEMA(closes, fast);
    final slowEMA = _calculateEMA(closes, slow);

    // MACD line = fast EMA - slow EMA
    final macdLine = <double?>[];
    for (int i = 0; i < closes.length; i++) {
      if (fastEMA[i] != null && slowEMA[i] != null) {
        macdLine.add(fastEMA[i]! - slowEMA[i]!);
      } else {
        macdLine.add(null);
      }
    }

    // Signal line = EMA of MACD line
    final validMacd = <double>[];
    int firstValidIndex = -1;
    for (int i = 0; i < macdLine.length; i++) {
      if (macdLine[i] != null) {
        if (firstValidIndex == -1) firstValidIndex = i;
        validMacd.add(macdLine[i]!);
      }
    }

    if (validMacd.length < signal || firstValidIndex == -1) {
      // Fill what we can without signal
      for (int i = 0; i < closes.length; i++) {
        result[i] = MACDResult(macdLine: macdLine[i]);
      }
      return result;
    }

    final signalEMA = _calculateEMA(validMacd, signal);

    for (int i = 0; i < closes.length; i++) {
      final macd = macdLine[i];
      double? sig;
      double? hist;

      final validIdx = i - firstValidIndex;
      if (validIdx >= 0 && validIdx < signalEMA.length && signalEMA[validIdx] != null) {
        sig = signalEMA[validIdx];
        if (macd != null) {
          hist = macd - sig!;
        }
      }

      result[i] = MACDResult(macdLine: macd, signalLine: sig, histogram: hist);
    }

    return result;
  }

  /// Bollinger Bands
  List<BBResult> calculateBollingerBands(List<double> closes, {int period = 20, double stdDev = 2.0}) {
    final result = List<BBResult>.filled(closes.length, const BBResult());
    if (closes.length < period) return result;

    for (int i = period - 1; i < closes.length; i++) {
      double sum = 0;
      for (int j = i - period + 1; j <= i; j++) {
        sum += closes[j];
      }
      final middle = sum / period;

      double variance = 0;
      for (int j = i - period + 1; j <= i; j++) {
        variance += (closes[j] - middle) * (closes[j] - middle);
      }
      final sd = _sqrt(variance / period);

      result[i] = BBResult(
        upper: middle + stdDev * sd,
        middle: middle,
        lower: middle - stdDev * sd,
      );
    }

    return result;
  }

  /// Stochastic Oscillator
  List<StochResult> calculateStochastic(List<OHLCData> data, {int kPeriod = 14, int dPeriod = 3}) {
    final result = List<StochResult>.filled(data.length, const StochResult());
    if (data.length < kPeriod) return result;

    // %K calculation
    final kValues = List<double?>.filled(data.length, null);
    for (int i = kPeriod - 1; i < data.length; i++) {
      double highestHigh = double.negativeInfinity;
      double lowestLow = double.infinity;
      for (int j = i - kPeriod + 1; j <= i; j++) {
        if (data[j].high > highestHigh) highestHigh = data[j].high;
        if (data[j].low < lowestLow) lowestLow = data[j].low;
      }
      final range = highestHigh - lowestLow;
      kValues[i] = range == 0 ? 50.0 : ((data[i].close - lowestLow) / range) * 100;
    }

    // %D = SMA of %K
    final dValues = List<double?>.filled(data.length, null);
    for (int i = 0; i < data.length; i++) {
      if (kValues[i] == null) continue;
      // Check if we have enough %K values for D period
      int count = 0;
      double sum = 0;
      for (int j = i; j >= 0 && count < dPeriod; j--) {
        if (kValues[j] != null) {
          sum += kValues[j]!;
          count++;
        } else {
          break;
        }
      }
      if (count == dPeriod) {
        dValues[i] = sum / dPeriod;
      }
    }

    for (int i = 0; i < data.length; i++) {
      result[i] = StochResult(k: kValues[i], d: dValues[i]);
    }

    return result;
  }

  /// Ichimoku Cloud (Ichimoku Kinko Hyo)
  List<IchimokuResult> calculateIchimoku(List<OHLCData> data, {int tenkan = 9, int kijun = 26, int senkou = 52}) {
    // Result length extended by kijun for forward-shifted senkou spans
    final resultLen = data.length + kijun;
    final result = List<IchimokuResult>.filled(resultLen, const IchimokuResult());

    if (data.length < senkou) return result.sublist(0, data.length);

    double? periodMidpoint(int end, int period) {
      if (end < period - 1 || end >= data.length) return null;
      double high = double.negativeInfinity;
      double low = double.infinity;
      for (int j = end - period + 1; j <= end; j++) {
        if (data[j].high > high) high = data[j].high;
        if (data[j].low < low) low = data[j].low;
      }
      return (high + low) / 2;
    }

    // Calculate each component
    final tenkanValues = List<double?>.filled(data.length, null);
    final kijunValues = List<double?>.filled(data.length, null);
    final senkouA = List<double?>.filled(resultLen, null);
    final senkouB = List<double?>.filled(resultLen, null);
    final chikouValues = List<double?>.filled(data.length, null);

    for (int i = 0; i < data.length; i++) {
      tenkanValues[i] = periodMidpoint(i, tenkan);
      kijunValues[i] = periodMidpoint(i, kijun);

      // Senkou Span A = (Tenkan + Kijun) / 2, shifted forward by kijun
      if (tenkanValues[i] != null && kijunValues[i] != null) {
        final shifted = i + kijun;
        if (shifted < resultLen) {
          senkouA[shifted] = (tenkanValues[i]! + kijunValues[i]!) / 2;
        }
      }

      // Senkou Span B = midpoint of senkou period, shifted forward by kijun
      final sb = periodMidpoint(i, senkou);
      if (sb != null) {
        final shifted = i + kijun;
        if (shifted < resultLen) {
          senkouB[shifted] = sb;
        }
      }

      // Chikou Span = current close shifted back by kijun
      if (i >= kijun) {
        chikouValues[i - kijun] = data[i].close;
      }
    }

    // Build result (only up to data.length for display)
    final finalResult = <IchimokuResult>[];
    for (int i = 0; i < data.length; i++) {
      finalResult.add(IchimokuResult(
        tenkan: tenkanValues[i],
        kijun: kijunValues[i],
        senkouA: senkouA[i],
        senkouB: senkouB[i],
        chikou: chikouValues[i],
      ));
    }

    return finalResult;
  }

  /// OBV (On-Balance Volume)
  List<double> calculateOBV(List<OHLCData> data) {
    if (data.isEmpty) return [];
    final result = List<double>.filled(data.length, 0);
    result[0] = data[0].volume;
    for (int i = 1; i < data.length; i++) {
      if (data[i].close > data[i - 1].close) {
        result[i] = result[i - 1] + data[i].volume;
      } else if (data[i].close < data[i - 1].close) {
        result[i] = result[i - 1] - data[i].volume;
      } else {
        result[i] = result[i - 1];
      }
    }
    return result;
  }

  // --- Signal Interpretation Methods ---

  IndicatorSignal getRSISignal(double rsi) {
    if (rsi >= 80) {
      return const IndicatorSignal(type: SignalType.strongSell, label: '강한 과매수', color: AppColors.stockDown);
    } else if (rsi >= 70) {
      return const IndicatorSignal(type: SignalType.sell, label: '과매수', color: AppColors.stockDown);
    } else if (rsi <= 20) {
      return const IndicatorSignal(type: SignalType.strongBuy, label: '강한 과매도', color: AppColors.stockUp);
    } else if (rsi <= 30) {
      return const IndicatorSignal(type: SignalType.buy, label: '과매도', color: AppColors.stockUp);
    } else if (rsi > 50) {
      return const IndicatorSignal(type: SignalType.neutral, label: '상승 편향', color: AppColors.gray500);
    } else {
      return const IndicatorSignal(type: SignalType.neutral, label: '중립', color: AppColors.gray500);
    }
  }

  IndicatorSignal getMACDSignal(MACDResult current, MACDResult? prev) {
    if (current.macdLine == null || current.signalLine == null) {
      return const IndicatorSignal(type: SignalType.neutral, label: '데이터 부족', color: AppColors.gray500);
    }
    final macd = current.macdLine!;
    final signal = current.signalLine!;

    // Check for crossover
    if (prev != null && prev.macdLine != null && prev.signalLine != null) {
      final prevMacd = prev.macdLine!;
      final prevSignal = prev.signalLine!;
      if (prevMacd <= prevSignal && macd > signal) {
        return const IndicatorSignal(type: SignalType.strongBuy, label: '골든크로스', color: AppColors.stockUp);
      }
      if (prevMacd >= prevSignal && macd < signal) {
        return const IndicatorSignal(type: SignalType.strongSell, label: '데드크로스', color: AppColors.stockDown);
      }
    }

    // Histogram direction
    final hist = current.histogram ?? 0;
    if (macd > signal && hist > 0) {
      return const IndicatorSignal(type: SignalType.buy, label: '상승 추세', color: AppColors.stockUp);
    } else if (macd < signal && hist < 0) {
      return const IndicatorSignal(type: SignalType.sell, label: '하락 추세', color: AppColors.stockDown);
    }
    return const IndicatorSignal(type: SignalType.neutral, label: '중립', color: AppColors.gray500);
  }

  IndicatorSignal getBBSignal(double close, BBResult bb) {
    if (bb.upper == null || bb.lower == null || bb.middle == null) {
      return const IndicatorSignal(type: SignalType.neutral, label: '데이터 부족', color: AppColors.gray500);
    }
    final bandwidth = (bb.upper! - bb.lower!) / bb.middle!;

    if (close >= bb.upper!) {
      return const IndicatorSignal(type: SignalType.sell, label: '상단밴드 돌파', color: AppColors.stockDown);
    } else if (close <= bb.lower!) {
      return const IndicatorSignal(type: SignalType.buy, label: '하단밴드 돌파', color: AppColors.stockUp);
    } else if (bandwidth < 0.03) {
      return const IndicatorSignal(type: SignalType.neutral, label: '스퀴즈 (변동성↓)', color: AppColors.gray500);
    } else if (close > bb.middle!) {
      return const IndicatorSignal(type: SignalType.neutral, label: '중심선 위', color: AppColors.gray500);
    } else {
      return const IndicatorSignal(type: SignalType.neutral, label: '중심선 아래', color: AppColors.gray500);
    }
  }

  IndicatorSignal getStochSignal(StochResult current, StochResult? prev) {
    if (current.k == null) {
      return const IndicatorSignal(type: SignalType.neutral, label: '데이터 부족', color: AppColors.gray500);
    }
    final k = current.k!;
    final d = current.d;

    // Check for K-D crossover
    if (prev != null && prev.k != null && prev.d != null && d != null) {
      if (prev.k! <= prev.d! && k > d) {
        if (k < 20) {
          return const IndicatorSignal(type: SignalType.strongBuy, label: '과매도 골든크로스', color: AppColors.stockUp);
        }
        return const IndicatorSignal(type: SignalType.buy, label: '골든크로스', color: AppColors.stockUp);
      }
      if (prev.k! >= prev.d! && k < d!) {
        if (k > 80) {
          return const IndicatorSignal(type: SignalType.strongSell, label: '과매수 데드크로스', color: AppColors.stockDown);
        }
        return const IndicatorSignal(type: SignalType.sell, label: '데드크로스', color: AppColors.stockDown);
      }
    }

    if (k >= 80) {
      return const IndicatorSignal(type: SignalType.sell, label: '과매수', color: AppColors.stockDown);
    } else if (k <= 20) {
      return const IndicatorSignal(type: SignalType.buy, label: '과매도', color: AppColors.stockUp);
    }
    return const IndicatorSignal(type: SignalType.neutral, label: '중립', color: AppColors.gray500);
  }

  IndicatorSignal getIchimokuSignal(double close, IchimokuResult ich) {
    if (ich.tenkan == null || ich.kijun == null) {
      return const IndicatorSignal(type: SignalType.neutral, label: '데이터 부족', color: AppColors.gray500);
    }

    // Cloud position
    final cloudTop = (ich.senkouA != null && ich.senkouB != null)
        ? (ich.senkouA! > ich.senkouB! ? ich.senkouA! : ich.senkouB!)
        : null;
    final cloudBottom = (ich.senkouA != null && ich.senkouB != null)
        ? (ich.senkouA! < ich.senkouB! ? ich.senkouA! : ich.senkouB!)
        : null;

    final aboveCloud = cloudTop != null && close > cloudTop;
    final belowCloud = cloudBottom != null && close < cloudBottom;
    final tenkanAboveKijun = ich.tenkan! > ich.kijun!;

    if (aboveCloud && tenkanAboveKijun) {
      return const IndicatorSignal(type: SignalType.strongBuy, label: '강한 상승', color: AppColors.stockUp);
    } else if (aboveCloud) {
      return const IndicatorSignal(type: SignalType.buy, label: '구름 위 (상승)', color: AppColors.stockUp);
    } else if (belowCloud && !tenkanAboveKijun) {
      return const IndicatorSignal(type: SignalType.strongSell, label: '강한 하락', color: AppColors.stockDown);
    } else if (belowCloud) {
      return const IndicatorSignal(type: SignalType.sell, label: '구름 아래 (하락)', color: AppColors.stockDown);
    } else {
      return const IndicatorSignal(type: SignalType.neutral, label: '구름 안 (중립)', color: AppColors.gray500);
    }
  }

  IndicatorSignal getOBVSignal(List<double> obv, List<double> closes) {
    if (obv.length < 10 || closes.length < 10) {
      return const IndicatorSignal(type: SignalType.neutral, label: '데이터 부족', color: AppColors.gray500);
    }
    final len = obv.length;
    // Compare last 5 periods trend
    final obvTrend = obv[len - 1] - obv[len - 5];
    final priceTrend = closes[closes.length - 1] - closes[closes.length - 5];

    final obvUp = obvTrend > 0;
    final priceUp = priceTrend > 0;

    if (obvUp && !priceUp) {
      return const IndicatorSignal(type: SignalType.buy, label: '상승 다이버전스', color: AppColors.stockUp);
    } else if (!obvUp && priceUp) {
      return const IndicatorSignal(type: SignalType.sell, label: '하락 다이버전스', color: AppColors.stockDown);
    } else if (obvUp && priceUp) {
      return const IndicatorSignal(type: SignalType.buy, label: '상승 확인', color: AppColors.stockUp);
    } else {
      return const IndicatorSignal(type: SignalType.sell, label: '하락 확인', color: AppColors.stockDown);
    }
  }

  // --- Helpers ---

  List<double?> _calculateEMA(List<double> data, int period) {
    final result = List<double?>.filled(data.length, null);
    if (data.length < period) return result;

    // SMA for initial value
    double sum = 0;
    for (int i = 0; i < period; i++) {
      sum += data[i];
    }
    result[period - 1] = sum / period;

    final multiplier = 2 / (period + 1);
    for (int i = period; i < data.length; i++) {
      result[i] = (data[i] - result[i - 1]!) * multiplier + result[i - 1]!;
    }

    return result;
  }

  double _sqrt(double value) {
    if (value <= 0) return 0;
    // Newton's method
    double x = value;
    double y = (x + 1) / 2;
    while (y < x) {
      x = y;
      y = (x + value / x) / 2;
    }
    return x;
  }
}
