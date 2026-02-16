import 'package:uuid/uuid.dart';

import '../../data/models/models.dart';
import '../../data/repositories/repositories.dart';
import 'calculators/calculators.dart';
import 'signal_detector.dart';

/// 알파 사이클 통합 UseCase
///
/// 사이클 생성, 매수, 익절 등 모든 매매 로직을 관리합니다.
class AlphaCycleUseCase {
  final CycleRepository _cycleRepository;
  final TradeRepository _tradeRepository;
  final SettingsRepository _settingsRepository;

  AlphaCycleUseCase({
    required CycleRepository cycleRepository,
    required TradeRepository tradeRepository,
    required SettingsRepository settingsRepository,
  })  : _cycleRepository = cycleRepository,
        _tradeRepository = tradeRepository,
        _settingsRepository = settingsRepository;

  // ═══════════════════════════════════════════════════════════════
  // 사이클 생성
  // ═══════════════════════════════════════════════════════════════

  /// 새 사이클 생성 및 초기 진입
  ///
  /// [ticker] 종목 코드
  /// [seedAmount] 시드 금액 (원화)
  /// [initialEntryPrice] 초기 진입가 (USD)
  /// [exchangeRate] 환율 (원/달러), null이면 설정에서 가져옴
  ///
  /// 반환: 생성된 사이클과 초기 매수 거래
  Future<({Cycle cycle, Trade initialTrade})> createCycle({
    required String ticker,
    required double seedAmount,
    required double initialEntryPrice,
    double? exchangeRate,
  }) async {
    final settings = _settingsRepository.settings;
    final rate = exchangeRate ?? settings.exchangeRate;

    // 다음 사이클 번호 결정
    final cycleNumber = _cycleRepository.getNextCycleNumber(ticker);

    // 사이클 생성
    final cycle = Cycle(
      id: const Uuid().v4(),
      ticker: ticker,
      cycleNumber: cycleNumber,
      seedAmount: seedAmount,
      initialEntryPrice: initialEntryPrice,
      exchangeRate: rate,
      buyTrigger: settings.defaultBuyTrigger,
      sellTrigger: settings.defaultSellTrigger,
      panicTrigger: settings.defaultPanicTrigger,
    );

    // 초기 진입 (시드의 20%)
    final initialAmount = cycle.initialEntryAmount;
    final initialShares = (initialAmount / rate) / initialEntryPrice;

    // 사이클 상태 업데이트
    cycle.recordBuy(
      price: initialEntryPrice,
      shares: initialShares,
      amountKrw: initialAmount,
      isPanic: false,
    );

    // 초기 매수 거래 기록 생성
    final initialTrade = Trade(
      id: const Uuid().v4(),
      cycleId: cycle.id,
      ticker: ticker,
      date: DateTime.now(),
      action: TradeAction.initialBuy,
      price: initialEntryPrice,
      shares: initialShares,
      recommendedAmount: initialAmount,
      actualAmount: initialAmount,
      isExecuted: true,
      lossRate: 0,
      returnRate: 0,
    );

    // 저장
    await _cycleRepository.save(cycle);
    await _tradeRepository.save(initialTrade);

    return (cycle: cycle, initialTrade: initialTrade);
  }

  // ═══════════════════════════════════════════════════════════════
  // 매매 신호 분석
  // ═══════════════════════════════════════════════════════════════

  /// 특정 사이클의 오늘 매매 권장 정보
  TradingRecommendation getRecommendation(Cycle cycle, double currentPrice) {
    return SignalDetector.getRecommendation(cycle, currentPrice);
  }

  /// 모든 활성 사이클의 매매 권장 정보
  List<({Cycle cycle, TradingRecommendation recommendation})> getAllRecommendations(
    Map<String, double> currentPrices,
  ) {
    final activeCycles = _cycleRepository.getActiveCycles();
    final recommendations = <({Cycle cycle, TradingRecommendation recommendation})>[];

    for (final cycle in activeCycles) {
      final price = currentPrices[cycle.ticker];
      if (price != null) {
        recommendations.add((
          cycle: cycle,
          recommendation: getRecommendation(cycle, price),
        ));
      }
    }

    // 신호가 있는 것 우선 정렬
    recommendations.sort((a, b) {
      if (a.recommendation.needsAction && !b.recommendation.needsAction) return -1;
      if (!a.recommendation.needsAction && b.recommendation.needsAction) return 1;
      return 0;
    });

    return recommendations;
  }

  // ═══════════════════════════════════════════════════════════════
  // 매수 실행
  // ═══════════════════════════════════════════════════════════════

  /// 가중 매수 실행
  ///
  /// [cycle] 대상 사이클
  /// [currentPrice] 현재 주가 (USD)
  /// [actualAmount] 실제 투자 금액 (원화), null이면 권장 금액 사용
  Future<Trade> executeWeightedBuy({
    required Cycle cycle,
    required double currentPrice,
    double? actualAmount,
  }) async {
    final lossRate = LossCalculator.calculate(currentPrice, cycle.initialEntryPrice);
    final returnRate = ReturnCalculator.calculate(currentPrice, cycle.averagePrice);

    // 권장 금액 계산
    final recommendedAmount = WeightedBuyCalculator.calculateFromPrice(
      cycle.initialEntryAmount,
      currentPrice,
      cycle.initialEntryPrice,
    );

    final amount = actualAmount ?? recommendedAmount;
    final shares = (amount / cycle.exchangeRate) / currentPrice;

    // 사이클 상태 업데이트
    cycle.recordBuy(
      price: currentPrice,
      shares: shares,
      amountKrw: amount,
      isPanic: false,
    );

    // 거래 기록 생성
    final trade = Trade(
      id: const Uuid().v4(),
      cycleId: cycle.id,
      ticker: cycle.ticker,
      date: DateTime.now(),
      action: TradeAction.weightedBuy,
      price: currentPrice,
      shares: shares,
      recommendedAmount: recommendedAmount,
      actualAmount: amount,
      isExecuted: true,
      lossRate: lossRate,
      returnRate: returnRate,
    );

    // 저장
    await _cycleRepository.save(cycle);
    await _tradeRepository.save(trade);

    return trade;
  }

  /// 승부수 실행 (승부수 + 가중 매수)
  ///
  /// [cycle] 대상 사이클
  /// [currentPrice] 현재 주가 (USD)
  /// [actualAmount] 실제 투자 금액 (원화), null이면 권장 금액 사용
  Future<List<Trade>> executePanicBuy({
    required Cycle cycle,
    required double currentPrice,
    double? actualAmount,
  }) async {
    if (cycle.panicUsed) {
      throw StateError('이미 승부수를 사용한 사이클입니다.');
    }

    final lossRate = LossCalculator.calculate(currentPrice, cycle.initialEntryPrice);
    final returnRate = ReturnCalculator.calculate(currentPrice, cycle.averagePrice);

    final trades = <Trade>[];

    // 1. 승부수 매수
    final panicAmount = PanicBuyCalculator.calculate(cycle.initialEntryAmount);
    final panicShares = (panicAmount / cycle.exchangeRate) / currentPrice;

    cycle.recordBuy(
      price: currentPrice,
      shares: panicShares,
      amountKrw: panicAmount,
      isPanic: true,
    );

    final panicTrade = Trade(
      id: const Uuid().v4(),
      cycleId: cycle.id,
      ticker: cycle.ticker,
      date: DateTime.now(),
      action: TradeAction.panicBuy,
      price: currentPrice,
      shares: panicShares,
      recommendedAmount: panicAmount,
      actualAmount: panicAmount,
      isExecuted: true,
      lossRate: lossRate,
      returnRate: returnRate,
    );
    trades.add(panicTrade);

    // 2. 가중 매수도 같이 실행
    final weightedAmount = WeightedBuyCalculator.calculateFromPrice(
      cycle.initialEntryAmount,
      currentPrice,
      cycle.initialEntryPrice,
    );
    final weightedShares = (weightedAmount / cycle.exchangeRate) / currentPrice;

    cycle.recordBuy(
      price: currentPrice,
      shares: weightedShares,
      amountKrw: weightedAmount,
      isPanic: false,
    );

    final weightedTrade = Trade(
      id: const Uuid().v4(),
      cycleId: cycle.id,
      ticker: cycle.ticker,
      date: DateTime.now(),
      action: TradeAction.weightedBuy,
      price: currentPrice,
      shares: weightedShares,
      recommendedAmount: weightedAmount,
      actualAmount: weightedAmount,
      isExecuted: true,
      lossRate: lossRate,
      returnRate: ReturnCalculator.calculate(currentPrice, cycle.averagePrice),
    );
    trades.add(weightedTrade);

    // 저장
    await _cycleRepository.save(cycle);
    for (final trade in trades) {
      await _tradeRepository.save(trade);
    }

    return trades;
  }

  // ═══════════════════════════════════════════════════════════════
  // 익절 실행
  // ═══════════════════════════════════════════════════════════════

  /// 익절 (전량 매도) 실행
  ///
  /// [cycle] 대상 사이클
  /// [sellPrice] 매도 가격 (USD)
  Future<Trade> executeTakeProfit({
    required Cycle cycle,
    required double sellPrice,
  }) async {
    final lossRate = LossCalculator.calculate(sellPrice, cycle.initialEntryPrice);
    final returnRate = ReturnCalculator.calculate(sellPrice, cycle.averagePrice);

    final sellAmount = cycle.totalShares * sellPrice * cycle.exchangeRate;
    final shares = cycle.totalShares;

    // 사이클 상태 업데이트 (익절 완료)
    cycle.recordTakeProfit(sellPrice);

    // 거래 기록 생성
    final trade = Trade(
      id: const Uuid().v4(),
      cycleId: cycle.id,
      ticker: cycle.ticker,
      date: DateTime.now(),
      action: TradeAction.takeProfit,
      price: sellPrice,
      shares: shares,
      recommendedAmount: sellAmount,
      actualAmount: sellAmount,
      isExecuted: true,
      lossRate: lossRate,
      returnRate: returnRate,
    );

    // 저장
    await _cycleRepository.save(cycle);
    await _tradeRepository.save(trade);

    return trade;
  }

  // ═══════════════════════════════════════════════════════════════
  // 통계 및 분석
  // ═══════════════════════════════════════════════════════════════

  /// 사이클 수익 분석
  ///
  /// [cycle] 대상 사이클
  /// [currentPrice] 현재 주가 (USD), 완료된 사이클이면 무시됨
  CycleAnalysis analyzeCycle(Cycle cycle, [double? currentPrice]) {
    final trades = _tradeRepository.getByCycleId(cycle.id);

    double totalBuyAmount = 0;
    double totalSellAmount = 0;
    int buyCount = 0;
    int sellCount = 0;

    for (final trade in trades) {
      if (trade.isBuy) {
        totalBuyAmount += trade.amount;
        buyCount++;
      } else {
        totalSellAmount += trade.amount;
        sellCount++;
      }
    }

    double currentValue;
    double unrealizedProfit;
    double realizedProfit;

    if (cycle.status == CycleStatus.completed) {
      // 완료된 사이클
      currentValue = cycle.remainingCash;
      realizedProfit = cycle.remainingCash - cycle.seedAmount;
      unrealizedProfit = 0;
    } else {
      // 진행 중인 사이클
      final price = currentPrice ?? cycle.averagePrice;
      currentValue = cycle.totalAsset(price);
      unrealizedProfit = currentValue - cycle.seedAmount;
      realizedProfit = 0;
    }

    return CycleAnalysis(
      cycle: cycle,
      trades: trades,
      totalBuyAmount: totalBuyAmount,
      totalSellAmount: totalSellAmount,
      buyCount: buyCount,
      sellCount: sellCount,
      currentValue: currentValue,
      unrealizedProfit: unrealizedProfit,
      realizedProfit: realizedProfit,
    );
  }
}

/// 사이클 분석 결과
class CycleAnalysis {
  final Cycle cycle;
  final List<Trade> trades;
  final double totalBuyAmount;
  final double totalSellAmount;
  final int buyCount;
  final int sellCount;
  final double currentValue;
  final double unrealizedProfit;
  final double realizedProfit;

  const CycleAnalysis({
    required this.cycle,
    required this.trades,
    required this.totalBuyAmount,
    required this.totalSellAmount,
    required this.buyCount,
    required this.sellCount,
    required this.currentValue,
    required this.unrealizedProfit,
    required this.realizedProfit,
  });

  /// 총 수익 (실현 + 미실현)
  double get totalProfit => realizedProfit + unrealizedProfit;

  /// 수익률 (%)
  double get profitRate {
    if (cycle.seedAmount == 0) return 0;
    return (totalProfit / cycle.seedAmount) * 100;
  }

  /// 사이클 기간 (일)
  int get durationDays {
    final end = cycle.endDate ?? DateTime.now();
    return end.difference(cycle.startDate).inDays;
  }
}
