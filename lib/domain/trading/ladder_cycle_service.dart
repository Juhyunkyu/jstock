import '../../data/models/cycle.dart';
import '../../data/models/trade.dart';
import 'strategy_engine.dart';

// ─── Top-level 헬퍼 함수: ladderWeights/ladderTriggers 방어적 파싱 ───

/// ladderWeights 문자열을 안전하게 파싱
/// 빈 문자열, 잘못된 형식 → 기본값 반환
List<int> parseLadderWeights(String weightsStr, {int steps = 6}) {
  if (weightsStr.trim().isEmpty) {
    return _defaultWeights(steps);
  }
  try {
    final parts = weightsStr.split(',');
    final weights = parts
        .map((s) => int.tryParse(s.trim()) ?? 1)
        .toList();
    if (weights.isEmpty) return _defaultWeights(steps);
    return weights;
  } catch (_) {
    return _defaultWeights(steps);
  }
}

/// ladderTriggers 문자열을 안전하게 파싱
/// 빈 문자열, 잘못된 형식 → 기본 트리거값 반환
List<double> parseLadderTriggers(String triggersStr, {int steps = 6}) {
  if (triggersStr.trim().isEmpty) {
    return _defaultTriggers(steps);
  }
  try {
    final parts = triggersStr.split(',');
    final triggers = parts
        .map((s) => double.tryParse(s.trim()) ?? 0.0)
        .toList();
    if (triggers.isEmpty) return _defaultTriggers(steps);
    return triggers;
  } catch (_) {
    return _defaultTriggers(steps);
  }
}

/// 단계별 기본 비중
List<int> _defaultWeights(int steps) => switch (steps) {
  3 => [2, 3, 5],
  4 => [1, 2, 3, 4],
  5 => [1, 1, 2, 3, 3],
  _ => [1, 1, 2, 3, 4, 5],
};

/// 단계별 기본 MDD 트리거
List<double> _defaultTriggers(int steps) => switch (steps) {
  3 => [-15, -30, -50],
  4 => [-10, -22, -37, -55],
  5 => [-10, -20, -30, -42, -55],
  _ => [-10, -19, -28, -37, -46, -55],
};

// ─── MDD 계산 ───

double calculateMDD(double athPrice, double currentPrice) {
  if (athPrice <= 0) return 0;
  return ((currentPrice - athPrice) / athPrice) * 100;
  // 예: ATH=$500, 현재=$400 → MDD = -20%
}

// ─── 단계별 투입금 계산 ───

/// 가변 단계/비율 지원 투입금 계산
/// (C-1) tryParse + 기본값 폴백 사용
/// (C-4) step 범위 검증
double stepAmount(double seedAmount, int step, Cycle cycle) {
  final weights = parseLadderWeights(cycle.ladderWeights, steps: cycle.ladderSteps);
  // (C-4) step 범위 미검증 방어
  if (step < 1 || step > weights.length) return 0;
  final totalWeight = weights.fold<int>(0, (sum, w) => sum + w);
  // (M-1) totalWeight가 0이면 방어
  if (totalWeight == 0) return seedAmount / weights.length;
  return seedAmount * weights[step - 1] / totalWeight;
}

/// 갭 하락 처리: fromStep+1 ~ toStep까지 합산
double gapAmount(double seedAmount, int fromStep, int toStep, Cycle cycle) {
  double total = 0;
  for (int s = fromStep + 1; s <= toStep; s++) {
    total += stepAmount(seedAmount, s, cycle);
  }
  return total;
}

// ─── 모드별 티커 추천 ───

List<String> recommendedTickers(int ladderMode, int step) {
  if (ladderMode == 0) {
    if (step <= 1) return ['QQQ', 'QLD', 'TQQQ'];  // 1단계: QQQ 강조
    if (step <= 2) return ['QLD', 'QQQ', 'TQQQ'];  // 2단계: QLD 강조
    return ['TQQQ', 'QQQ', 'QLD'];                  // 3~6단계: TQQQ 강조
  }
  if (ladderMode == 1) return ['TQQQ'];
  return ['SOXL'];
}

// ─── 안정형 멀티 티커 계산 ───

/// Trade.ticker 기준으로 같은 사이클 내 거래를 티커별 분류
Map<String, List<Trade>> groupByTicker(List<Trade> trades, String cycleTicker) {
  final map = <String, List<Trade>>{};
  for (final t in trades) {
    final ticker = t.ticker ?? cycleTicker;
    map.putIfAbsent(ticker, () => []).add(t);
  }
  return map;
}

/// 각 티커의 가중평균매입가 별도 계산
double tickerVwap(List<Trade> buyTrades) {
  final totalCost = buyTrades.fold<double>(0, (s, t) => s + t.price * t.shares);
  final totalShares = buyTrades.fold<double>(0, (s, t) => s + t.shares);
  return totalShares > 0 ? totalCost / totalShares : 0;
}

/// 각 티커의 shares x currentPrice x exchangeRate
double tickerEvalAmount(double shares, double currentPrice, double exchangeRate) {
  return shares * currentPrice * exchangeRate;
}

// ─── TickerHolding 클래스 ───

/// 안정형 상세 화면에서 보유 현황 테이블 데이터 생성
/// Trade 목록에서 티커별 실시간 집계
class TickerHolding {
  final String ticker;
  final double shares;       // 매수 합 - 매도 합
  final double vwap;         // 해당 티커 매수 VWAP (USD)
  final double evalAmount;   // shares x currentPrice x exchangeRate
  final double avgExRate;    // 해당 티커 매수 가중평균 환율

  const TickerHolding({
    required this.ticker,
    required this.shares,
    required this.vwap,
    required this.evalAmount,
    required this.avgExRate,
  });

  /// 환차손익 = (현재환율 - avgExRate) x shares x currentPrice
  double exchangePnl(double currentPrice, double liveExRate) =>
      (liveExRate - avgExRate) * shares * currentPrice;
}

// ─── buildTickerHoldings ───

/// Trade 목록에서 티커별 TickerHolding 생성
List<TickerHolding> buildTickerHoldings(
  List<Trade> trades,
  String cycleTicker,
  Map<String, double> currentPrices,  // {ticker: price}
  double liveExchangeRate,
) {
  final grouped = groupByTicker(trades, cycleTicker);
  return grouped.entries.map((entry) {
    final ticker = entry.key;
    final tickerTrades = entry.value;
    final buys = tickerTrades.where((t) => t.action == TradeAction.buy).toList();
    final sells = tickerTrades.where((t) => t.action == TradeAction.sell).toList();
    final buyShares = buys.fold<double>(0, (s, t) => s + t.shares);
    final sellShares = sells.fold<double>(0, (s, t) => s + t.shares);
    final shares = buyShares - sellShares;
    final vwap = tickerVwap(buys);

    // 티커별 평균 매입환율 (I-6)
    // = 매수 거래의 exchangeRate를 amountKrw 기준 가중평균
    final totalBuyKrw = buys.fold<double>(0, (s, t) => s + t.amountKrw);
    final totalBuyUsd = buys.fold<double>(0, (s, t) => s + t.shares * t.price);
    final avgExRate = totalBuyUsd > 0 ? totalBuyKrw / totalBuyUsd : liveExchangeRate;

    final currentPrice = currentPrices[ticker] ?? 0.0;
    final evalAmount = shares * currentPrice * liveExchangeRate;

    return TickerHolding(
      ticker: ticker,
      shares: shares,
      vwap: vwap,
      evalAmount: evalAmount,
      avgExRate: avgExRate,
    );
  }).where((h) => h.shares > 0).toList();
}

// ─── LadderCycleService ───

/// Strategy C: Ladder Cycle 비즈니스 로직 (순수 함수)
class LadderCycleService implements StrategyEngine {
  const LadderCycleService();

  @override
  TradeSignal detectSignal({
    required Cycle cycle,
    required double currentPrice,
    required double liveExchangeRate,
  }) {
    if (cycle.athPrice <= 0) return TradeSignal.hold;
    final mdd = calculateMDD(cycle.athPrice, currentPrice);
    // (C-1) 방어적 파싱
    final triggers = parseLadderTriggers(
      cycle.ladderTriggers,
      steps: cycle.ladderSteps,
    );

    int targetStep = 0;
    for (int i = 0; i < triggers.length; i++) {
      if (mdd <= triggers[i]) targetStep = i + 1;
    }

    if (targetStep > cycle.currentStep) {
      return TradeSignal.values.firstWhere(
        (s) => s.name == 'ladderStep$targetStep',
        orElse: () => TradeSignal.hold,
      );
    }
    return TradeSignal.hold;
  }

  @override
  double? calculateAmount({
    required Cycle cycle,
    required TradeSignal signal,
    required double currentPrice,
    required double liveExchangeRate,
  }) {
    if (!signal.name.startsWith('ladderStep')) return null;
    // (C-1) tryParse 사용
    final targetStep = int.tryParse(
      signal.name.replaceAll('ladderStep', ''),
    ) ?? 0;
    if (targetStep <= 0) return null;
    return gapAmount(cycle.seedAmount, cycle.currentStep, targetStep, cycle);
  }
}
