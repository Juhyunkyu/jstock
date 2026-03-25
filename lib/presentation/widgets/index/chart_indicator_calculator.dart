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
  final List<double?>? fullRSI; // full data basis (for RSI drawing)
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

  // PVT
  final List<double>? displayPVT;
  final IndicatorSignal? pvtSignal;
  final String? pvtLabel;

  // MFI
  final List<double?>? displayMFI;
  final IndicatorSignal? mfiSignal;
  final String? mfiLabel;

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
    this.fullRSI,
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
    this.displayPVT,
    this.pvtSignal,
    this.pvtLabel,
    this.displayMFI,
    this.mfiSignal,
    this.mfiLabel,
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
    required List<String> activeIndicators,
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
    List<double?>? fullRSI;
    IndicatorSignal? rsiSignal;
    String? rsiLabel;
    if (activeIndicators.contains('RSI')) {
      final rsi = indicatorService.calculateRSI(closes);
      fullRSI = rsi;
      displayRSI = rsi.sublist(offset, end.clamp(0, rsi.length));
      // display 데이터의 마지막 RSI 기준으로 신호+라벨 표시 (스크롤 시 변동)
      final displayLastRsi = lastNonNull(displayRSI);
      if (displayLastRsi != null) {
        rsiSignal = indicatorService.getRSISignal(displayLastRsi);
      }
      rsiLabel = displayLastRsi != null ? 'RSI(14): ${displayLastRsi.toStringAsFixed(1)}' : 'RSI(14)';
    }

    // MACD
    List<MACDResult>? displayMACD;
    IndicatorSignal? macdSignal;
    String? macdLabel;
    if (activeIndicators.contains('MACD')) {
      final macd = indicatorService.calculateMACD(closes);
      displayMACD = macd.sublist(offset, end.clamp(0, macd.length));
      // display 데이터 기준 신호 (스크롤 시 변동)
      final displayLastMacd = lastValid(displayMACD, (m) => m.macdLine != null);
      final displayPrevMacd = displayMACD.length >= 2
          ? lastValid(displayMACD.sublist(0, displayMACD.length - 1), (m) => m.macdLine != null)
          : null;
      if (displayLastMacd != null) {
        macdSignal = indicatorService.getMACDSignal(displayLastMacd, displayPrevMacd);
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
      // display 데이터 기준 신호
      final displayLastStoch = lastValid(displayStoch, (s) => s.k != null);
      final displayPrevStoch = displayStoch.length >= 2
          ? lastValid(displayStoch.sublist(0, displayStoch.length - 1), (s) => s.k != null)
          : null;
      if (displayLastStoch != null) {
        stochSignal = indicatorService.getStochSignal(displayLastStoch, displayPrevStoch);
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
      // display 데이터 기준 신호
      if (displayOBV.length >= 10) {
        final displayCloses = closes.sublist(offset, end.clamp(0, closes.length));
        obvSignal = indicatorService.getOBVSignal(displayOBV, displayCloses);
      }
      if (displayOBV.isNotEmpty) {
        obvLabel = 'OBV: ${formatVolume(displayOBV.last)}';
      }
    }

    // PVT
    List<double>? displayPVT;
    IndicatorSignal? pvtSignal;
    String? pvtLabel;
    if (activeIndicators.contains('PVT')) {
      final pvt = indicatorService.calculatePVT(fullData);
      displayPVT = pvt.sublist(offset, end.clamp(0, pvt.length));
      if (displayPVT.length >= 10) {
        final displayCloses = closes.sublist(offset, end.clamp(0, closes.length));
        pvtSignal = indicatorService.getPVTSignal(displayPVT, displayCloses);
      }
      if (displayPVT.isNotEmpty) {
        pvtLabel = 'PVT: ${formatVolume(displayPVT.last)}';
      }
    }

    // MFI
    List<double?>? displayMFI;
    IndicatorSignal? mfiSignal;
    String? mfiLabel;
    if (activeIndicators.contains('MFI')) {
      final mfi = indicatorService.calculateMFI(fullData);
      displayMFI = mfi.sublist(offset, end.clamp(0, mfi.length));
      final displayLastMfi = lastNonNull(displayMFI);
      if (displayLastMfi != null) {
        mfiSignal = indicatorService.getMFISignal(displayLastMfi);
      }
      mfiLabel = displayLastMfi != null ? 'MFI(14): ${displayLastMfi.toStringAsFixed(1)}' : 'MFI(14)';
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
      fullRSI: fullRSI,
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
      displayPVT: displayPVT,
      pvtSignal: pvtSignal,
      pvtLabel: pvtLabel,
      displayMFI: displayMFI,
      mfiSignal: mfiSignal,
      mfiLabel: mfiLabel,
      volCurrentValue: volCurrentValue,
    );
  }
}
