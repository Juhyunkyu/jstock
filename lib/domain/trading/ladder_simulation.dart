import 'dart:math';
import '../../data/models/cycle.dart';
import 'ladder_cycle_service.dart';

// ─── 시뮬레이션 단계 데이터 모델 ───

class LadderSimulationStep {
  final int step;                    // 1~N
  final double baseTriggerPrice;     // 기준 티커 예상가 (ATH x (1 + MDD/100))
  final String buyTicker;            // 이 단계 매수 티커
  final int leverageMultiplier;      // 레버리지 배율 (1/2/3)
  final double buyTickerEstPrice;    // 매수 티커 예상가
  final double investAmountKrw;      // 이 단계 투입금 (KRW)
  final double shares;               // 이 단계 매수 수량 (정수)
  final double cumulativeInvestKrw;  // 누적 투입금
  final double vwap;                 // 누적 VWAP (USD 평균 매입가)
  final double cumulativeEvalKrw;    // 누적 평가금 (해당 단계 가격 기준)
  final double pnlPercent;           // 손익률 (평가금 vs 투입금)
  final double recoveryPercent;      // 본주 회복 필요 %
  final bool isCompleted;            // 완료된 단계인지
  final bool isCurrent;              // 현재 단계인지

  const LadderSimulationStep({
    required this.step,
    required this.baseTriggerPrice,
    required this.buyTicker,
    required this.leverageMultiplier,
    required this.buyTickerEstPrice,
    required this.investAmountKrw,
    required this.shares,
    required this.cumulativeInvestKrw,
    required this.vwap,
    required this.cumulativeEvalKrw,
    required this.pnlPercent,
    required this.recoveryPercent,
    required this.isCompleted,
    required this.isCurrent,
  });
}

// ─── 시뮬레이션 함수 ───

/// 단계별 투입 시뮬레이션 계산
/// - cycle: Ladder Cycle 데이터
/// - currentBasePrice: 기준 티커(cycle.ticker)의 현재 종가
/// - currentBuyPrices: 매수 티커들의 현재 종가 Map (예: {'SOXL': 46.0, 'SOXX': 323.0})
/// - exchangeRate: 현재 환율
List<LadderSimulationStep> simulateLadder({
  required Cycle cycle,
  required double currentBasePrice,
  required Map<String, double> currentBuyPrices,
  required double exchangeRate,
}) {
  // 방어: 필수값 검증
  if (cycle.athPrice <= 0 || currentBasePrice <= 0 || exchangeRate <= 0) {
    return [];
  }

  final triggers = parseLadderTriggers(
    cycle.ladderTriggers,
    steps: cycle.ladderSteps,
  );
  final totalSteps = triggers.length;
  final isStable = cycle.ladderMode == 0; // 안정형

  if (isStable) {
    return _simulateStable(
      cycle: cycle,
      triggers: triggers,
      totalSteps: totalSteps,
      currentBasePrice: currentBasePrice,
      currentBuyPrices: currentBuyPrices,
      exchangeRate: exchangeRate,
    );
  } else {
    return _simulateAggressive(
      cycle: cycle,
      triggers: triggers,
      totalSteps: totalSteps,
      currentBasePrice: currentBasePrice,
      currentBuyPrices: currentBuyPrices,
      exchangeRate: exchangeRate,
    );
  }
}

// ─── 공격형 시뮬레이션 (단일 티커) ───

List<LadderSimulationStep> _simulateAggressive({
  required Cycle cycle,
  required List<double> triggers,
  required int totalSteps,
  required double currentBasePrice,
  required Map<String, double> currentBuyPrices,
  required double exchangeRate,
}) {
  final buyTicker = cycle.buyTicker.isNotEmpty ? cycle.buyTicker : cycle.ticker;
  final currentBuyPrice = currentBuyPrices[buyTicker] ?? currentBuyPrices[cycle.ticker] ?? currentBasePrice;
  final leverageMultiplier = _leverageForTicker(buyTicker, cycle);

  final steps = <LadderSimulationStep>[];
  double cumulativeInvest = 0;
  double cumulativeShares = 0;
  double cumulativeCostUsd = 0; // sum(shares[j] * price[j])

  for (int i = 0; i < totalSteps; i++) {
    final stepNum = i + 1;

    // 1. 기준 티커 예상가
    final baseTriggerPrice = cycle.athPrice * (1 + triggers[i] / 100);

    // 2. 매수 티커 예상가
    final additionalChangeBase =
        (baseTriggerPrice - currentBasePrice) / currentBasePrice;
    final rawEstPrice =
        currentBuyPrice * (1 + additionalChangeBase * leverageMultiplier);
    final buyTickerEstPrice = max(rawEstPrice, 0.01);

    // 3. 투입금/수량
    final investAmount = stepAmount(cycle.seedAmount, stepNum, cycle);
    final priceInKrw = buyTickerEstPrice * exchangeRate;
    var shareCount = priceInKrw > 0 ? (investAmount / priceInKrw).floor() : 1;
    if (shareCount < 1) shareCount = 1;

    // 4. 누적 계산
    cumulativeInvest += investAmount;
    cumulativeShares += shareCount;
    cumulativeCostUsd += shareCount * buyTickerEstPrice;
    final vwap = cumulativeShares > 0 ? cumulativeCostUsd / cumulativeShares : 0.0;
    final cumulativeEval = cumulativeShares * buyTickerEstPrice * exchangeRate;
    final pnlPercent = cumulativeInvest > 0
        ? (cumulativeEval - cumulativeInvest) / cumulativeInvest * 100
        : 0.0;

    // 5. 본주 회복 필요 %
    final recoveryPercent = _calcRecoveryPercent(
      vwap: vwap,
      currentEstPrice: buyTickerEstPrice,
      leverageMultiplier: leverageMultiplier,
    );

    steps.add(LadderSimulationStep(
      step: stepNum,
      baseTriggerPrice: baseTriggerPrice,
      buyTicker: buyTicker,
      leverageMultiplier: leverageMultiplier,
      buyTickerEstPrice: buyTickerEstPrice,
      investAmountKrw: investAmount,
      shares: shareCount.toDouble(),
      cumulativeInvestKrw: cumulativeInvest,
      vwap: vwap,
      cumulativeEvalKrw: cumulativeEval,
      pnlPercent: pnlPercent,
      recoveryPercent: recoveryPercent,
      isCompleted: stepNum <= cycle.currentStep,
      isCurrent: stepNum == cycle.currentStep + 1,
    ));
  }
  return steps;
}

// ─── 안정형 시뮬레이션 (멀티 티커) ───

List<LadderSimulationStep> _simulateStable({
  required Cycle cycle,
  required List<double> triggers,
  required int totalSteps,
  required double currentBasePrice,
  required Map<String, double> currentBuyPrices,
  required double exchangeRate,
}) {
  // 안정형 티커 결정
  final t1x = cycle.buyTicker1x.isNotEmpty ? cycle.buyTicker1x : cycle.ticker;
  final t2x = cycle.buyTicker2x.isNotEmpty ? cycle.buyTicker2x : cycle.ticker;
  final t3x = cycle.buyTicker3x.isNotEmpty ? cycle.buyTicker3x : cycle.ticker;

  final steps = <LadderSimulationStep>[];
  double cumulativeInvest = 0;

  // 티커별 누적 수량/비용 추적
  final tickerShares = <String, double>{};
  final tickerCostSum = <String, double>{};

  // 각 단계의 매수 티커/예상가 캐시 (평가금 계산용)
  final stepBuyTickers = <String>[];
  final stepEstPrices = <Map<String, double>>[];

  for (int i = 0; i < totalSteps; i++) {
    final stepNum = i + 1;

    // 1. 기준 티커 예상가
    final baseTriggerPrice = cycle.athPrice * (1 + triggers[i] / 100);

    // 2. 이 단계 매수 티커 결정 (recommendedTickers 첫 번째)
    final recommended = recommendedTickers(cycle, stepNum);
    final buyTicker = recommended.first;
    final leverage = _leverageForTicker(buyTicker, cycle);
    stepBuyTickers.add(buyTicker);

    // 3. 매수 티커 예상가
    final currentBuyPrice = currentBuyPrices[buyTicker] ?? currentBasePrice;
    final additionalChangeBase =
        (baseTriggerPrice - currentBasePrice) / currentBasePrice;
    final rawEstPrice =
        currentBuyPrice * (1 + additionalChangeBase * leverage);
    final buyTickerEstPrice = max(rawEstPrice, 0.01);

    // 모든 보유 티커의 이 단계 시점 예상가 계산
    final pricesAtStep = <String, double>{};
    for (final ticker in {t1x, t2x, t3x}) {
      final lev = _leverageForTicker(ticker, cycle);
      final curPrice = currentBuyPrices[ticker] ?? currentBasePrice;
      final rawP = curPrice * (1 + additionalChangeBase * lev);
      pricesAtStep[ticker] = max(rawP, 0.01);
    }
    stepEstPrices.add(pricesAtStep);

    // 4. 투입금/수량
    final investAmount = stepAmount(cycle.seedAmount, stepNum, cycle);
    final priceInKrw = buyTickerEstPrice * exchangeRate;
    var shareCount = priceInKrw > 0 ? (investAmount / priceInKrw).floor() : 1;
    if (shareCount < 1) shareCount = 1;

    // 5. 티커별 누적
    tickerShares[buyTicker] =
        (tickerShares[buyTicker] ?? 0) + shareCount;
    tickerCostSum[buyTicker] =
        (tickerCostSum[buyTicker] ?? 0) + shareCount * buyTickerEstPrice;

    cumulativeInvest += investAmount;

    // 6. 이 단계 시점에서 모든 보유 티커의 평가금 합산
    double cumulativeEval = 0;
    for (final entry in tickerShares.entries) {
      final ticker = entry.key;
      final qty = entry.value;
      final tickerPrice = pricesAtStep[ticker] ?? buyTickerEstPrice;
      cumulativeEval += qty * tickerPrice * exchangeRate;
    }

    final pnlPercent = cumulativeInvest > 0
        ? (cumulativeEval - cumulativeInvest) / cumulativeInvest * 100
        : 0.0;

    // 안정형 VWAP: 멀티 티커 혼합이므로 0 (의미 없음)
    const vwap = 0.0;

    // 본주 회복: 안정형에서는 전체 pnl 기반 역산
    // 현재 단계 매수 티커 기준으로 계산
    final recoveryPercent = pnlPercent < 0
        ? (-pnlPercent) / leverage
        : 0.0;

    steps.add(LadderSimulationStep(
      step: stepNum,
      baseTriggerPrice: baseTriggerPrice,
      buyTicker: buyTicker,
      leverageMultiplier: leverage,
      buyTickerEstPrice: buyTickerEstPrice,
      investAmountKrw: investAmount,
      shares: shareCount.toDouble(),
      cumulativeInvestKrw: cumulativeInvest,
      vwap: vwap,
      cumulativeEvalKrw: cumulativeEval,
      pnlPercent: pnlPercent,
      recoveryPercent: recoveryPercent,
      isCompleted: stepNum <= cycle.currentStep,
      isCurrent: stepNum == cycle.currentStep + 1,
    ));
  }
  return steps;
}

// ─── 내부 헬퍼 함수 ───

/// 티커에 대한 레버리지 배율 결정
int _leverageForTicker(String ticker, Cycle cycle) {
  if (cycle.ladderMode == 0) {
    // 안정형: buyTicker1x=1배, 2x=2배, 3x=3배
    final t1x = cycle.buyTicker1x.isNotEmpty ? cycle.buyTicker1x : cycle.ticker;
    final t2x = cycle.buyTicker2x.isNotEmpty ? cycle.buyTicker2x : cycle.ticker;
    final t3x = cycle.buyTicker3x.isNotEmpty ? cycle.buyTicker3x : cycle.ticker;
    if (ticker == t1x) return 1;
    if (ticker == t2x) return 2;
    if (ticker == t3x) return 3;
    // 폴백: ticker가 cycle.ticker와 같으면 1배
    return 1;
  }
  // 공격형: 항상 3배
  return 3;
}

/// 본주 회복 필요 % 계산
/// VWAP까지 회복하려면 매수 티커가 몇% 올라야 하는지 → 본주 기준 역산
double _calcRecoveryPercent({
  required double vwap,
  required double currentEstPrice,
  required int leverageMultiplier,
}) {
  if (currentEstPrice <= 0 || vwap <= 0) return 0;
  if (currentEstPrice >= vwap) return 0;
  // 매수 티커 회복 필요 %
  final leveragedRecovery = (vwap - currentEstPrice) / currentEstPrice * 100;
  // 본주(기준 티커) 기준: 1/레버리지
  return leveragedRecovery / leverageMultiplier;
}

// ─── 검증 예시 (주석) ───
//
// 검증 예시: SOXX ATH $350, SOXL 현재 $46, SOXX 현재 $323, 시드 500만, 6단계 가속형
// triggers: [-10, -19, -28, -37, -46, -55]
// weights:  [1, 1, 2, 3, 4, 5] → totalWeight=16
//
// 1단계: baseTriggerPrice = 350 * 0.90 = $315
//        additionalChangeBase = (315-323)/323 = -0.02478
//        buyTickerEstPrice = 46 * (1 + (-0.02478)*3) = 46 * 0.9257 = $42.58
//        investAmount = 5,000,000 * 1/16 = 312,500 KRW
//        shares = floor(312500 / (42.58 * 1509)) = floor(312500 / 64233) = 4주
//        cumulativeEval = 4 * 42.58 * 1509 = 256,918 KRW
//        pnl = (256918 - 312500) / 312500 * 100 = -17.8%
//        recoveryPercent = ((42.58→VWAP)/42.58*100) / 3
