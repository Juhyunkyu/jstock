import '../../../data/models/ohlc_data.dart';
import '../../../data/services/technical_indicator_service.dart';
import '../../utils/chart_utils.dart';

/// 보조 지표 계산 결과를 담는 데이터 클래스
class ChartIndicatorData {
  // BB
  final List<BBResult>? displayBB;
  final IndicatorSignal? bbSignal;
  final String? bbSummary;

  // Ichimoku
  final List<IchimokuResult>? displayIchimoku;
  final IndicatorSignal? ichSignal;
  final String? ichSummary;

  // RSI
  final List<double?>? displayRSI;
  final IndicatorSignal? rsiSignal;
  final String? rsiLabel;

  // MACD
  final List<MACDResult>? displayMACD;
  final IndicatorSignal? macdSignal;
  final String? macdLabel;

  // Stochastic
  final List<StochResult>? displayStoch;
  final IndicatorSignal? stochSignal;
  final String? stochLabel;

  // OBV
  final List<double>? displayOBV;
  final IndicatorSignal? obvSignal;
  final String? obvLabel;

  // Volume
  final String? volCurrentValue;

  const ChartIndicatorData({
    this.displayBB,
    this.bbSignal,
    this.bbSummary,
    this.displayIchimoku,
    this.ichSignal,
    this.ichSummary,
    this.displayRSI,
    this.rsiSignal,
    this.rsiLabel,
    this.displayMACD,
    this.macdSignal,
    this.macdLabel,
    this.displayStoch,
    this.stochSignal,
    this.stochLabel,
    this.displayOBV,
    this.obvSignal,
    this.obvLabel,
    this.volCurrentValue,
  });
}

/// 보조 지표 일괄 계산 유틸리티
class ChartIndicatorCalculator {
  ChartIndicatorCalculator._();

  /// 리스트의 마지막 non-null 값 반환
  static double? lastNonNull(List<double?> values) {
    for (int i = values.length - 1; i >= 0; i--) {
      if (values[i] != null) return values[i];
    }
    return null;
  }

  /// 리스트의 마지막 유효 값 반환
  static T? lastValid<T>(List<T> values, bool Function(T) isValid) {
    for (int i = values.length - 1; i >= 0; i--) {
      if (isValid(values[i])) return values[i];
    }
    return null;
  }

  /// 활성화된 보조 지표를 일괄 계산
  static ChartIndicatorData calculate({
    required List<OHLCData> fullData,
    required List<OHLCData> displayData,
    required int offset,
    required int end,
    required Set<String> activeIndicators,
    required TechnicalIndicatorService indicatorService,
  }) {
    final closes = fullData.map((e) => e.close).toList();
    final lastClose = closes.last;

    // BB
    List<BBResult>? displayBB;
    IndicatorSignal? bbSignal;
    String? bbSummary;
    if (activeIndicators.contains('BB')) {
      final bb = indicatorService.calculateBollingerBands(closes);
      displayBB = bb.sublist(offset, end.clamp(0, bb.length));
      final lastBB = lastValid(bb, (b) => b.upper != null);
      if (lastBB != null) {
        bbSignal = indicatorService.getBBSignal(lastClose, lastBB);
        bbSummary = 'BB: 상단 ${lastBB.upper!.toStringAsFixed(1)} / 중심 ${lastBB.middle!.toStringAsFixed(1)} / 하단 ${lastBB.lower!.toStringAsFixed(1)}';
      }
    }

    // Ichimoku
    List<IchimokuResult>? displayIchimoku;
    IndicatorSignal? ichSignal;
    String? ichSummary;
    if (activeIndicators.contains('ICH')) {
      final ich = indicatorService.calculateIchimoku(fullData);
      displayIchimoku = ich.sublist(offset, end.clamp(0, ich.length));
      final lastIch = lastValid(ich, (i) => i.tenkan != null);
      if (lastIch != null) {
        ichSignal = indicatorService.getIchimokuSignal(lastClose, lastIch);
        final cloudDir = (lastIch.senkouA != null && lastIch.senkouB != null)
            ? (lastClose > (lastIch.senkouA! > lastIch.senkouB! ? lastIch.senkouA! : lastIch.senkouB!) ? '▲' : '▼')
            : '-';
        ichSummary = '일목: 전환 ${lastIch.tenkan?.toStringAsFixed(1) ?? '-'} 기준 ${lastIch.kijun?.toStringAsFixed(1) ?? '-'} 구름 $cloudDir';
      }
    }

    // RSI
    List<double?>? displayRSI;
    IndicatorSignal? rsiSignal;
    String? rsiLabel;
    if (activeIndicators.contains('RSI')) {
      final rsi = indicatorService.calculateRSI(closes);
      displayRSI = rsi.sublist(offset, end.clamp(0, rsi.length));
      final lastRsi = lastNonNull(rsi);
      if (lastRsi != null) {
        rsiSignal = indicatorService.getRSISignal(lastRsi);
      }
      final displayLastRsi = lastNonNull(displayRSI);
      rsiLabel = displayLastRsi != null ? 'RSI(14): ${displayLastRsi.toStringAsFixed(1)}' : 'RSI(14)';
    }

    // MACD
    List<MACDResult>? displayMACD;
    IndicatorSignal? macdSignal;
    String? macdLabel;
    if (activeIndicators.contains('MACD')) {
      final macd = indicatorService.calculateMACD(closes);
      displayMACD = macd.sublist(offset, end.clamp(0, macd.length));
      final lastMacd = lastValid(macd, (m) => m.macdLine != null);
      final prevMacd = macd.length >= 2 ? lastValid(macd.sublist(0, macd.length - 1), (m) => m.macdLine != null) : null;
      if (lastMacd != null) {
        macdSignal = indicatorService.getMACDSignal(lastMacd, prevMacd);
      }
      final displayLastMacd = lastValid(displayMACD, (m) => m.macdLine != null);
      if (displayLastMacd != null) {
        final m = displayLastMacd.macdLine?.toStringAsFixed(2) ?? '-';
        final s = displayLastMacd.signalLine?.toStringAsFixed(2) ?? '-';
        macdLabel = 'MACD: $m / Signal: $s';
      } else {
        macdLabel = 'MACD(12,26,9)';
      }
    }

    // Stochastic
    List<StochResult>? displayStoch;
    IndicatorSignal? stochSignal;
    String? stochLabel;
    if (activeIndicators.contains('STOCH')) {
      final stoch = indicatorService.calculateStochastic(fullData);
      displayStoch = stoch.sublist(offset, end.clamp(0, stoch.length));
      final lastStoch = lastValid(stoch, (s) => s.k != null);
      final prevStoch = stoch.length >= 2 ? lastValid(stoch.sublist(0, stoch.length - 1), (s) => s.k != null) : null;
      if (lastStoch != null) {
        stochSignal = indicatorService.getStochSignal(lastStoch, prevStoch);
      }
      final displayLastStoch = lastValid(displayStoch, (s) => s.k != null);
      if (displayLastStoch != null) {
        final kStr = displayLastStoch.k?.toStringAsFixed(1) ?? '-';
        final dStr = displayLastStoch.d?.toStringAsFixed(1) ?? '-';
        stochLabel = '%K: $kStr  %D: $dStr';
      } else {
        stochLabel = 'STOCH(14,3)';
      }
    }

    // OBV
    List<double>? displayOBV;
    IndicatorSignal? obvSignal;
    String? obvLabel;
    if (activeIndicators.contains('OBV')) {
      final obv = indicatorService.calculateOBV(fullData);
      displayOBV = obv.sublist(offset, end.clamp(0, obv.length));
      if (obv.length >= 10) {
        obvSignal = indicatorService.getOBVSignal(obv, closes);
      }
      if (displayOBV.isNotEmpty) {
        obvLabel = 'OBV: ${formatVolume(displayOBV.last)}';
      }
    }

    // Volume
    String? volCurrentValue;
    if (activeIndicators.contains('VOL') && displayData.isNotEmpty) {
      volCurrentValue = formatVolume(displayData.last.volume);
    }

    return ChartIndicatorData(
      displayBB: displayBB,
      bbSignal: bbSignal,
      bbSummary: bbSummary,
      displayIchimoku: displayIchimoku,
      ichSignal: ichSignal,
      ichSummary: ichSummary,
      displayRSI: displayRSI,
      rsiSignal: rsiSignal,
      rsiLabel: rsiLabel,
      displayMACD: displayMACD,
      macdSignal: macdSignal,
      macdLabel: macdLabel,
      displayStoch: displayStoch,
      stochSignal: stochSignal,
      stochLabel: stochLabel,
      displayOBV: displayOBV,
      obvSignal: obvSignal,
      obvLabel: obvLabel,
      volCurrentValue: volCurrentValue,
    );
  }
}
