import '../../data/models/cycle.dart';
import '../../data/models/trade.dart';

/// 전략 공통 인터페이스
/// returnRate, evaluatedAmount 등 공용 계산은 trading_math.dart 참조
abstract class StrategyEngine {
  /// 현재 신호 감지
  TradeSignal detectSignal({
    required Cycle cycle,
    required double currentPrice,
    required double liveExchangeRate,
  });

  /// 매수/매도 금액 계산 (KRW), null = 행동 불필요
  double? calculateAmount({
    required Cycle cycle,
    required TradeSignal signal,
    required double currentPrice,
    required double liveExchangeRate,
  });
}
