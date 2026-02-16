import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/cycle.dart';
import '../../data/models/trade.dart';
import '../../domain/usecases/alpha_cycle_usecase.dart';
import '../../domain/usecases/signal_detector.dart';
import 'core/repository_providers.dart';
import 'cycle_providers.dart';
import 'trade_providers.dart';

/// AlphaCycleUseCase Provider
final alphaCycleUseCaseProvider = Provider<AlphaCycleUseCase>((ref) {
  final cycleRepo = ref.watch(cycleRepositoryProvider);
  final tradeRepo = ref.watch(tradeRepositoryProvider);
  final settingsRepo = ref.watch(settingsRepositoryProvider);

  return AlphaCycleUseCase(
    cycleRepository: cycleRepo,
    tradeRepository: tradeRepo,
    settingsRepository: settingsRepo,
  );
});

/// 사이클 생성 Provider
class CycleCreator extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  CycleCreator(this._ref) : super(const AsyncValue.data(null));

  /// 새 사이클 생성
  Future<Cycle?> createCycle({
    required String ticker,
    required double seedAmount,
    required double initialEntryPrice,
    double? exchangeRate,
  }) async {
    state = const AsyncValue.loading();
    try {
      final useCase = _ref.read(alphaCycleUseCaseProvider);
      final result = await useCase.createCycle(
        ticker: ticker,
        seedAmount: seedAmount,
        initialEntryPrice: initialEntryPrice,
        exchangeRate: exchangeRate,
      );

      // 목록 새로고침
      _ref.read(cycleListProvider.notifier).refresh();
      _ref.read(tradeListProvider.notifier).refresh();

      state = const AsyncValue.data(null);
      return result.cycle;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }
}

/// 사이클 생성 Provider
final cycleCreatorProvider = StateNotifierProvider<CycleCreator, AsyncValue<void>>((ref) {
  return CycleCreator(ref);
});

/// 매매 실행 Provider
class TradeExecutor extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  TradeExecutor(this._ref) : super(const AsyncValue.data(null));

  /// 가중 매수 실행
  Future<Trade?> executeWeightedBuy({
    required Cycle cycle,
    required double currentPrice,
    double? actualAmount,
  }) async {
    state = const AsyncValue.loading();
    try {
      final useCase = _ref.read(alphaCycleUseCaseProvider);
      final trade = await useCase.executeWeightedBuy(
        cycle: cycle,
        currentPrice: currentPrice,
        actualAmount: actualAmount,
      );

      _refreshAll();
      state = const AsyncValue.data(null);
      return trade;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  /// 승부수 실행
  Future<List<Trade>?> executePanicBuy({
    required Cycle cycle,
    required double currentPrice,
    double? actualAmount,
  }) async {
    state = const AsyncValue.loading();
    try {
      final useCase = _ref.read(alphaCycleUseCaseProvider);
      final trades = await useCase.executePanicBuy(
        cycle: cycle,
        currentPrice: currentPrice,
        actualAmount: actualAmount,
      );

      _refreshAll();
      state = const AsyncValue.data(null);
      return trades;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  /// 익절 실행
  Future<Trade?> executeTakeProfit({
    required Cycle cycle,
    required double sellPrice,
  }) async {
    state = const AsyncValue.loading();
    try {
      final useCase = _ref.read(alphaCycleUseCaseProvider);
      final trade = await useCase.executeTakeProfit(
        cycle: cycle,
        sellPrice: sellPrice,
      );

      _refreshAll();
      state = const AsyncValue.data(null);
      return trade;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  void _refreshAll() {
    _ref.read(cycleListProvider.notifier).refresh();
    _ref.read(tradeListProvider.notifier).refresh();
  }
}

/// 매매 실행 Provider
final tradeExecutorProvider = StateNotifierProvider<TradeExecutor, AsyncValue<void>>((ref) {
  return TradeExecutor(ref);
});

/// 특정 사이클의 매매 권장 Provider (Family)
final cycleRecommendationProvider = Provider.family<TradingRecommendation?, CycleWithPrice>((ref, params) {
  final cycle = ref.watch(cycleByIdProvider(params.cycleId));
  if (cycle == null) return null;

  return SignalDetector.getRecommendation(cycle, params.currentPrice);
});

/// 모든 활성 사이클의 매매 권장 Provider
final allRecommendationsProvider = Provider.family<List<CycleRecommendation>, Map<String, double>>((ref, prices) {
  final activeCycles = ref.watch(activeCyclesProvider);
  final recommendations = <CycleRecommendation>[];

  for (final cycle in activeCycles) {
    final price = prices[cycle.ticker];
    if (price != null) {
      final recommendation = SignalDetector.getRecommendation(cycle, price);
      recommendations.add(CycleRecommendation(
        cycle: cycle,
        recommendation: recommendation,
        currentPrice: price,
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
});

/// 액션이 필요한 사이클 수 Provider
final actionRequiredCountProvider = Provider.family<int, Map<String, double>>((ref, prices) {
  final recommendations = ref.watch(allRecommendationsProvider(prices));
  return recommendations.where((r) => r.recommendation.needsAction).length;
});

/// 사이클 분석 Provider (Family)
final cycleAnalysisProvider = Provider.family<CycleAnalysis?, CycleWithPrice>((ref, params) {
  final cycle = ref.watch(cycleByIdProvider(params.cycleId));
  if (cycle == null) return null;

  final useCase = ref.watch(alphaCycleUseCaseProvider);
  return useCase.analyzeCycle(cycle, params.currentPrice);
});

/// 사이클 + 가격 파라미터 클래스
class CycleWithPrice {
  final String cycleId;
  final double currentPrice;

  const CycleWithPrice({
    required this.cycleId,
    required this.currentPrice,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CycleWithPrice &&
          runtimeType == other.runtimeType &&
          cycleId == other.cycleId &&
          currentPrice == other.currentPrice;

  @override
  int get hashCode => cycleId.hashCode ^ currentPrice.hashCode;
}

/// 사이클 + 권장 정보 데이터 클래스
class CycleRecommendation {
  final Cycle cycle;
  final TradingRecommendation recommendation;
  final double currentPrice;

  const CycleRecommendation({
    required this.cycle,
    required this.recommendation,
    required this.currentPrice,
  });
}
