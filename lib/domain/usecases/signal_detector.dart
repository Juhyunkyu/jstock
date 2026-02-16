import '../../data/models/cycle.dart';
import 'calculators/calculators.dart';

/// 매매 신호 유형
enum TradingSignal {
  /// 보유 유지 - 아무 조건도 충족하지 않음
  hold,

  /// 가중 매수 - 손실률 <= -20%
  weightedBuy,

  /// 승부수 - 손실률 <= -50%, 1회만
  panicBuy,

  /// 익절 - 수익률 >= +20%
  takeProfit,
}

/// 매매 권장 정보
class TradingRecommendation {
  /// 매매 신호
  final TradingSignal signal;

  /// 권장 매수/매도 금액 (원화)
  final double recommendedAmount;

  /// 예상 매수 수량
  final double estimatedShares;

  /// 현재 손실률 (%)
  final double lossRate;

  /// 현재 수익률 (%)
  final double returnRate;

  /// 추가 메시지
  final String? message;

  const TradingRecommendation({
    required this.signal,
    required this.recommendedAmount,
    required this.estimatedShares,
    required this.lossRate,
    required this.returnRate,
    this.message,
  });

  /// 신호 표시 이름
  String get signalDisplayName {
    switch (signal) {
      case TradingSignal.hold:
        return '보유';
      case TradingSignal.weightedBuy:
        return '가중 매수';
      case TradingSignal.panicBuy:
        return '승부수';
      case TradingSignal.takeProfit:
        return '익절';
    }
  }

  /// 신호 이모지
  String get signalEmoji {
    switch (signal) {
      case TradingSignal.hold:
        return '⏸️';
      case TradingSignal.weightedBuy:
        return '🔵';
      case TradingSignal.panicBuy:
        return '🔴';
      case TradingSignal.takeProfit:
        return '💰';
    }
  }

  /// 매수 신호인지 여부
  bool get isBuySignal =>
      signal == TradingSignal.weightedBuy || signal == TradingSignal.panicBuy;

  /// 매도 신호인지 여부
  bool get isSellSignal => signal == TradingSignal.takeProfit;

  /// 액션이 필요한지 여부
  bool get needsAction => signal != TradingSignal.hold;
}

/// 매매 신호 탐지기
///
/// 현재가를 기준으로 사이클의 매매 신호를 판단합니다.
class SignalDetector {
  const SignalDetector._();

  /// 매매 신호 판단
  ///
  /// 우선순위:
  /// 1. 익절 (수익률 >= +20%)
  /// 2. 승부수 (손실률 <= -50%, 미사용)
  /// 3. 가중 매수 (손실률 <= -20%)
  /// 4. 보유 (그 외)
  static TradingSignal detectSignal(Cycle cycle, double currentPrice) {
    final lossRate = LossCalculator.calculate(currentPrice, cycle.initialEntryPrice);
    final returnRate = ReturnCalculator.calculate(currentPrice, cycle.averagePrice);

    // 1. 익절 조건 확인 (최우선)
    if (returnRate >= cycle.sellTrigger) {
      return TradingSignal.takeProfit;
    }

    // 2. 승부수 조건 확인
    if (lossRate <= cycle.panicTrigger && !cycle.panicUsed) {
      return TradingSignal.panicBuy;
    }

    // 3. 가중 매수 조건 확인
    if (lossRate <= cycle.buyTrigger) {
      return TradingSignal.weightedBuy;
    }

    // 4. 그 외
    return TradingSignal.hold;
  }

  /// 오늘의 매매 권장 정보 생성
  static TradingRecommendation getRecommendation(
    Cycle cycle,
    double currentPrice,
  ) {
    final signal = detectSignal(cycle, currentPrice);
    final lossRate = LossCalculator.calculate(currentPrice, cycle.initialEntryPrice);
    final returnRate = ReturnCalculator.calculate(currentPrice, cycle.averagePrice);

    double recommendedAmount = 0;
    double estimatedShares = 0;
    String? message;

    switch (signal) {
      case TradingSignal.takeProfit:
        // 익절: 전량 매도
        recommendedAmount = cycle.stockValue(currentPrice);
        estimatedShares = cycle.totalShares;
        message = '🎉 목표 수익률 달성! 전량 익절 권장';
        break;

      case TradingSignal.panicBuy:
        // 승부수 + 가중 매수
        final panicAmount = PanicBuyCalculator.calculate(cycle.initialEntryAmount);
        final weightedAmount = WeightedBuyCalculator.calculateFromPrice(
          cycle.initialEntryAmount,
          currentPrice,
          cycle.initialEntryPrice,
        );
        recommendedAmount = panicAmount + weightedAmount;
        estimatedShares = _calculateShares(
          recommendedAmount,
          currentPrice,
          cycle.exchangeRate,
        );
        message = '⚠️ 승부수 발동! 승부수 + 가중 매수';
        break;

      case TradingSignal.weightedBuy:
        // 가중 매수만
        recommendedAmount = WeightedBuyCalculator.calculateFromPrice(
          cycle.initialEntryAmount,
          currentPrice,
          cycle.initialEntryPrice,
        );
        estimatedShares = _calculateShares(
          recommendedAmount,
          currentPrice,
          cycle.exchangeRate,
        );
        message = '📉 하락 구간, 가중 매수 권장';
        break;

      case TradingSignal.hold:
        message = _getHoldMessage(lossRate, returnRate, cycle);
        break;
    }

    // 잔여 현금 확인
    if (signal == TradingSignal.weightedBuy || signal == TradingSignal.panicBuy) {
      if (recommendedAmount > cycle.remainingCash) {
        final shortage = recommendedAmount - cycle.remainingCash;
        message = '⚠️ 현금 부족! ${_formatKrw(shortage)} 추가 필요';
        recommendedAmount = cycle.remainingCash;
        estimatedShares = _calculateShares(
          recommendedAmount,
          currentPrice,
          cycle.exchangeRate,
        );
      }
    }

    return TradingRecommendation(
      signal: signal,
      recommendedAmount: recommendedAmount,
      estimatedShares: estimatedShares,
      lossRate: lossRate,
      returnRate: returnRate,
      message: message,
    );
  }

  /// 보유 상태 메시지 생성
  static String _getHoldMessage(double lossRate, double returnRate, Cycle cycle) {
    if (lossRate > 0) {
      final toTakeProfit = cycle.sellTrigger - returnRate;
      return '📈 상승 중 (+${returnRate.toStringAsFixed(1)}%), '
          '익절까지 ${toTakeProfit.toStringAsFixed(1)}%p';
    } else if (lossRate > cycle.buyTrigger) {
      final toBuy = lossRate - cycle.buyTrigger;
      return '📊 관망 구간, 매수 신호까지 ${toBuy.abs().toStringAsFixed(1)}%p';
    }
    return '📊 현재 보유 유지';
  }

  /// 주식 수량 계산 헬퍼
  static double _calculateShares(
    double amountKrw,
    double priceUsd,
    double exchangeRate,
  ) {
    if (priceUsd == 0 || exchangeRate == 0) return 0;
    return (amountKrw / exchangeRate) / priceUsd;
  }

  /// 원화 포맷 헬퍼 (콤마 구분)
  static String _formatKrw(double amount) {
    final intAmount = amount.round();
    final absAmount = intAmount.abs();
    final formatted = absAmount.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
    return intAmount < 0 ? '-$formatted원' : '$formatted원';
  }
}
