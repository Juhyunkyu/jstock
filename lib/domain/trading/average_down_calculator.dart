// 물타기 계산기 — 순수 함수 모음 (외부 의존성 없음)
//
// 기존 TradingMath와 역할 분리:
// - TradingMath: 사이클 거래 중 실시간 평단/수익률 계산 (KRW VWAP)
// - AverageDownCalculator: 물타기 시뮬레이션 전용 (순수 USD VWAP)

// ════════════════════════════════════════════════════════════════
// 결과 모델 클래스
// ════════════════════════════════════════════════════════════════

/// 하락 시나리오 행
class ScenarioRow {
  final double dropPercent;
  final double projectedPrice;
  final double mdd;
  final double lossAmountKrw;

  const ScenarioRow({
    required this.dropPercent,
    required this.projectedPrice,
    required this.mdd,
    required this.lossAmountKrw,
  });
}

/// 수익률 역산 결과
class ReverseCalcResult {
  final double requiredAmountKrw;
  final double requiredShares;
  final double newAvgPrice;
  final bool isFeasible;
  final String? infeasibleReason;

  const ReverseCalcResult({
    required this.requiredAmountKrw,
    required this.requiredShares,
    required this.newAvgPrice,
    required this.isFeasible,
    this.infeasibleReason,
  });
}

/// 목표가 도달 시 수익 결과
class TargetPriceResult {
  final double currentProfit;
  final double currentReturnRate;
  final double newProfit;
  final double newReturnRate;

  const TargetPriceResult({
    required this.currentProfit,
    required this.currentReturnRate,
    required this.newProfit,
    required this.newReturnRate,
  });
}

/// 다회차 물타기 회차별 누적 결과
class RoundResult {
  final int round;
  final double price;
  final double shares;
  final double cumulativeShares;
  final double cumulativeAvgPrice;
  final double cumulativeMdd;

  const RoundResult({
    required this.round,
    required this.price,
    required this.shares,
    required this.cumulativeShares,
    required this.cumulativeAvgPrice,
    required this.cumulativeMdd,
  });
}

/// 물타기 계산 전체 결과
class AvgDownResult {
  // === 핵심 결과 ===
  final double currentAvgPrice;
  final double newAvgPrice;
  final double avgPriceReduction;

  // === MDD ===
  final double currentMdd;
  final double newMdd;
  final double mddImprovement;

  // === 포지션 요약 ===
  final double totalShares;
  final double totalInvestedKrw;
  final double evaluatedAmountKrw;
  final double profitLossKrw;
  final double returnRate;

  // === 시나리오 ===
  final List<ScenarioRow> scenarios;

  // === 수익률 역산 ===
  final ReverseCalcResult? reverseCalc;

  // === 목표가 수익 ===
  final TargetPriceResult? targetPriceResult;

  // === 다회차 누적 ===
  final List<RoundResult> roundResults;

  const AvgDownResult({
    required this.currentAvgPrice,
    required this.newAvgPrice,
    required this.avgPriceReduction,
    required this.currentMdd,
    required this.newMdd,
    required this.mddImprovement,
    required this.totalShares,
    required this.totalInvestedKrw,
    required this.evaluatedAmountKrw,
    required this.profitLossKrw,
    required this.returnRate,
    required this.scenarios,
    this.reverseCalc,
    this.targetPriceResult,
    this.roundResults = const [],
  });
}

// ════════════════════════════════════════════════════════════════
// 계산 엔진
// ════════════════════════════════════════════════════════════════

class AverageDownCalculator {
  AverageDownCalculator._();

  // ──────────────────────────────────────────
  // 1. 평균단가 (순수 USD VWAP)
  // ──────────────────────────────────────────

  /// 물타기 후 새 평균단가
  /// newAvg = (holdingShares × avgPrice + addShares × addPrice)
  ///        / (holdingShares + addShares)
  ///
  /// Zero-guard: 총수량이 0이면 0.0 반환
  static double newAveragePrice({
    required double holdingShares,
    required double averagePrice,
    required double additionalShares,
    required double additionalPrice,
  }) {
    final totalShares = holdingShares + additionalShares;
    if (totalShares <= 0) return 0.0;
    return (holdingShares * averagePrice +
            additionalShares * additionalPrice) /
        totalShares;
  }

  // ──────────────────────────────────────────
  // 2. MDD (Maximum Drawdown from Average)
  // ──────────────────────────────────────────

  /// MDD = (currentPrice - averagePrice) / averagePrice × 100
  ///
  /// 평단 대비 현재가의 하락률. 양수면 수익, 음수면 손실.
  /// Zero-guard: averagePrice가 0이면 0.0 반환
  static double mdd({
    required double currentPrice,
    required double averagePrice,
  }) {
    if (averagePrice <= 0) return 0.0;
    return (currentPrice - averagePrice) / averagePrice * 100;
  }

  /// 물타기 후 MDD
  static double newMdd({
    required double currentPrice,
    required double holdingShares,
    required double averagePrice,
    required double additionalShares,
    required double additionalPrice,
  }) {
    final newAvg = newAveragePrice(
      holdingShares: holdingShares,
      averagePrice: averagePrice,
      additionalShares: additionalShares,
      additionalPrice: additionalPrice,
    );
    return mdd(currentPrice: currentPrice, averagePrice: newAvg);
  }

  // ──────────────────────────────────────────
  // 3. 하락 시나리오
  // ──────────────────────────────────────────

  /// 추가 하락 시나리오별 MDD 및 손실금액 계산
  ///
  /// dropPercents: [-10, -20, -30, -50] 등
  /// 반환: 각 시나리오별 (예상가, MDD%, 손실금액KRW)
  static List<ScenarioRow> dropScenarios({
    required double currentPrice,
    required double averagePrice,
    required double totalShares,
    required double exchangeRate,
    required List<double> dropPercents,
  }) {
    return dropPercents.map((drop) {
      final projectedPrice = currentPrice * (1 + drop / 100);
      final scenarioMdd = mdd(
        currentPrice: projectedPrice,
        averagePrice: averagePrice,
      );
      final investedKrw = totalShares * averagePrice * exchangeRate;
      final evalKrw = totalShares * projectedPrice * exchangeRate;
      final lossKrw = evalKrw - investedKrw;
      return ScenarioRow(
        dropPercent: drop,
        projectedPrice: projectedPrice,
        mdd: scenarioMdd,
        lossAmountKrw: lossKrw,
      );
    }).toList();
  }

  // ──────────────────────────────────────────
  // 4. 수익률 역산
  // ──────────────────────────────────────────

  /// "목표 수익률을 달성하려면 얼마를 물타야 하는가"
  ///
  /// 목표평균단가 = currentPrice / (1 + targetReturnRate / 100)
  /// 필요수량 = (holdingShares × (avgPrice - targetAvg))
  ///          / (targetAvg - additionalPrice)
  ///
  /// 제약: targetAvg > additionalPrice 이어야 함
  ///       targetReturnRate < currentMdd 이면 불가능
  static ReverseCalcResult reverseCalc({
    required double holdingShares,
    required double averagePrice,
    required double currentPrice,
    required double additionalPrice,
    required double exchangeRate,
    required double targetReturnRate,
  }) {
    // targetReturnRate = -100 이면 0 나눗셈 → guard
    if (targetReturnRate <= -100) {
      return const ReverseCalcResult(
        requiredAmountKrw: 0,
        requiredShares: 0,
        newAvgPrice: 0,
        isFeasible: false,
        infeasibleReason: '목표 수익률이 -100% 이하로 설정 불가',
      );
    }

    // 목표 평균단가: currentPrice에서 targetReturnRate를 얻으려면
    // targetReturnRate = (currentPrice - targetAvg) / targetAvg × 100
    // targetAvg × (1 + targetReturnRate/100) = currentPrice
    final targetAvg = currentPrice / (1 + targetReturnRate / 100);

    // 실현 불가능 체크
    if (targetAvg <= additionalPrice) {
      return const ReverseCalcResult(
        requiredAmountKrw: 0,
        requiredShares: 0,
        newAvgPrice: 0,
        isFeasible: false,
        infeasibleReason: '매수가가 목표 평단보다 높아 달성 불가능',
      );
    }

    // 필요수량 = (holdingShares × (avgPrice - targetAvg))
    //          / (targetAvg - additionalPrice)
    final requiredShares =
        (holdingShares * (averagePrice - targetAvg)) /
        (targetAvg - additionalPrice);

    if (requiredShares <= 0) {
      return ReverseCalcResult(
        requiredAmountKrw: 0,
        requiredShares: 0,
        newAvgPrice: averagePrice,
        isFeasible: false,
        infeasibleReason: '이미 목표 수익률에 도달했거나 추가 매수 불필요',
      );
    }

    final requiredAmountKrw =
        requiredShares * additionalPrice * exchangeRate;
    final actualNewAvg = newAveragePrice(
      holdingShares: holdingShares,
      averagePrice: averagePrice,
      additionalShares: requiredShares,
      additionalPrice: additionalPrice,
    );

    return ReverseCalcResult(
      requiredAmountKrw: requiredAmountKrw,
      requiredShares: requiredShares,
      newAvgPrice: actualNewAvg,
      isFeasible: true,
      infeasibleReason: null,
    );
  }

  // ──────────────────────────────────────────
  // 5. 목표가 도달 시 예상 수익
  // ──────────────────────────────────────────

  /// 목표가에서의 수익 비교 (물타기 전 vs 후)
  static TargetPriceResult targetPriceProfit({
    required double holdingShares,
    required double averagePrice,
    required double additionalShares,
    required double additionalPrice,
    required double targetPrice,
    required double exchangeRate,
  }) {
    // 현재 포지션 기준
    final currentInvestedKrw = holdingShares * averagePrice * exchangeRate;
    final currentEvalKrw = holdingShares * targetPrice * exchangeRate;
    final currentProfit = currentEvalKrw - currentInvestedKrw;
    final currentReturn = currentInvestedKrw > 0
        ? (currentProfit / currentInvestedKrw * 100)
        : 0.0;

    // 물타기 후 기준
    final totalShares = holdingShares + additionalShares;
    final newAvg = newAveragePrice(
      holdingShares: holdingShares,
      averagePrice: averagePrice,
      additionalShares: additionalShares,
      additionalPrice: additionalPrice,
    );
    final newInvestedKrw = totalShares * newAvg * exchangeRate;
    final newEvalKrw = totalShares * targetPrice * exchangeRate;
    final newProfit = newEvalKrw - newInvestedKrw;
    final newReturn = newInvestedKrw > 0
        ? (newProfit / newInvestedKrw * 100)
        : 0.0;

    return TargetPriceResult(
      currentProfit: currentProfit,
      currentReturnRate: currentReturn,
      newProfit: newProfit,
      newReturnRate: newReturn,
    );
  }

  // ──────────────────────────────────────────
  // 6. 헬퍼: 금액 → 수량 변환
  // ──────────────────────────────────────────

  /// 매수금액(KRW)으로 매수 가능한 수량 계산
  /// Zero-guard: price 또는 exchangeRate가 0이면 0.0 반환
  static double sharesToBuy({
    required double amountKrw,
    required double price,
    required double exchangeRate,
  }) {
    if (price <= 0 || exchangeRate <= 0) return 0.0;
    return amountKrw / (price * exchangeRate);
  }

  // ──────────────────────────────────────────
  // 7. 다회차 물타기 누적 계산
  // ──────────────────────────────────────────

  /// 여러 회차의 물타기를 순차 적용하여 회차별 누적 평균단가 + MDD 계산
  ///
  /// [rounds]: 각 회차의 (매수가, 매수수량) 리스트
  /// 반환: 회차별 누적 결과 리스트
  static List<RoundResult> multiRoundAverage({
    required double holdingShares,
    required double averagePrice,
    required double currentPrice,
    required List<({double price, double shares})> rounds,
  }) {
    final results = <RoundResult>[];
    var cumShares = holdingShares;
    var cumCostUsd = holdingShares * averagePrice;

    for (var i = 0; i < rounds.length; i++) {
      final (:price, :shares) = rounds[i];
      cumShares += shares;
      cumCostUsd += shares * price;

      final cumAvg = cumShares > 0 ? cumCostUsd / cumShares : 0.0;
      final cumMdd = mdd(currentPrice: currentPrice, averagePrice: cumAvg);

      results.add(RoundResult(
        round: i + 1,
        price: price,
        shares: shares,
        cumulativeShares: cumShares,
        cumulativeAvgPrice: cumAvg,
        cumulativeMdd: cumMdd,
      ));
    }

    return results;
  }

  // ──────────────────────────────────────────
  // 8. 전체 계산 편의 메서드
  // ──────────────────────────────────────────

  /// 모든 결과를 한번에 계산
  ///
  /// [additionalRounds]: 다회차 물타기 리스트 (단일 물타기 시 1개 원소)
  /// [targetReturnRate]: 수익률 역산 목표 (null이면 역산 생략)
  /// [targetPrice]: 목표가 (null이면 목표가 수익 생략)
  /// [dropPercents]: 하락 시나리오 퍼센트 (기본: [-10, -20, -30, -50])
  static AvgDownResult calculateAll({
    required double holdingShares,
    required double averagePrice,
    required double currentPrice,
    required double exchangeRate,
    required List<({double price, double shares})> additionalRounds,
    double? targetReturnRate,
    double? targetPrice,
    List<double> dropPercents = const [-10, -20, -30, -50],
  }) {
    // 다회차 누적 계산
    final roundResults = multiRoundAverage(
      holdingShares: holdingShares,
      averagePrice: averagePrice,
      currentPrice: currentPrice,
      rounds: additionalRounds,
    );

    // 총 추가 수량/비용 합산
    var totalAddShares = 0.0;
    var totalAddCostUsd = 0.0;
    for (final r in additionalRounds) {
      totalAddShares += r.shares;
      totalAddCostUsd += r.shares * r.price;
    }

    // 가중평균 추가매수가 (단일 물타기 호환용)
    final effectiveAddPrice =
        totalAddShares > 0 ? totalAddCostUsd / totalAddShares : 0.0;

    // 핵심 결과
    final newAvg = newAveragePrice(
      holdingShares: holdingShares,
      averagePrice: averagePrice,
      additionalShares: totalAddShares,
      additionalPrice: effectiveAddPrice,
    );
    final currentMddVal = mdd(
      currentPrice: currentPrice,
      averagePrice: averagePrice,
    );
    final newMddVal = mdd(
      currentPrice: currentPrice,
      averagePrice: newAvg,
    );

    final totalShares = holdingShares + totalAddShares;
    final totalInvestedKrw = totalShares * newAvg * exchangeRate;
    final evaluatedAmountKrw = totalShares * currentPrice * exchangeRate;
    final profitLossKrw = evaluatedAmountKrw - totalInvestedKrw;
    final returnRateVal =
        totalInvestedKrw > 0 ? profitLossKrw / totalInvestedKrw * 100 : 0.0;

    final avgReduction = averagePrice > 0
        ? (newAvg - averagePrice) / averagePrice * 100
        : 0.0;

    // 하락 시나리오 (물타기 후 기준)
    final scenarios = dropScenarios(
      currentPrice: currentPrice,
      averagePrice: newAvg,
      totalShares: totalShares,
      exchangeRate: exchangeRate,
      dropPercents: dropPercents,
    );

    // 수익률 역산 (선택)
    ReverseCalcResult? reverseResult;
    if (targetReturnRate != null) {
      reverseResult = reverseCalc(
        holdingShares: holdingShares,
        averagePrice: averagePrice,
        currentPrice: currentPrice,
        additionalPrice: effectiveAddPrice > 0
            ? effectiveAddPrice
            : currentPrice,
        exchangeRate: exchangeRate,
        targetReturnRate: targetReturnRate,
      );
    }

    // 목표가 수익 (선택)
    TargetPriceResult? targetResult;
    if (targetPrice != null) {
      targetResult = targetPriceProfit(
        holdingShares: holdingShares,
        averagePrice: averagePrice,
        additionalShares: totalAddShares,
        additionalPrice: effectiveAddPrice,
        targetPrice: targetPrice,
        exchangeRate: exchangeRate,
      );
    }

    return AvgDownResult(
      currentAvgPrice: averagePrice,
      newAvgPrice: newAvg,
      avgPriceReduction: avgReduction,
      currentMdd: currentMddVal,
      newMdd: newMddVal,
      mddImprovement: newMddVal - currentMddVal,
      totalShares: totalShares,
      totalInvestedKrw: totalInvestedKrw,
      evaluatedAmountKrw: evaluatedAmountKrw,
      profitLossKrw: profitLossKrw,
      returnRate: returnRateVal,
      scenarios: scenarios,
      reverseCalc: reverseResult,
      targetPriceResult: targetResult,
      roundResults: roundResults,
    );
  }
}
