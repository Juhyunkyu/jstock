import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/cycle.dart';
import '../../domain/trading/steady_order_guide.dart';
import '../../domain/trading/steady_service.dart';
import 'cycle_providers.dart';
import 'trade_providers.dart';
import 'stock_providers.dart';
import 'api_providers.dart';

/// V2.2/V3.0 주문 가이드 Provider
/// V1이거나 Smart Cycle이면 null 반환
final steadyOrderGuideProvider =
    Provider.family<SteadyOrderGuide?, String>((ref, cycleId) {
  final cycles = ref.watch(cycleListProvider);
  final cycle = cycles.where((c) => c.id == cycleId).firstOrNull;
  if (cycle == null) return null;
  if (cycle.strategyType != StrategyType.infiniteBuy) return null;
  if (cycle.steadyVersion == SteadyVersion.v1) return null;

  final prices = ref.watch(closingPricesProvider);
  final currentPrice = prices[cycle.ticker] ?? 0;
  if (currentPrice == 0) return null;

  final liveExchangeRate = ref.watch(currentExchangeRateProvider);
  if (liveExchangeRate == 0) return null;

  // T값 보정용: 매도 총액
  final pnl = ref.watch(cycleRealizedPnlProvider(cycleId));
  final totalSellKrw = pnl?.totalSellKrw ?? 0.0;

  // 반복리용: 매도 순수익
  final trades = ref.watch(tradeListProvider(cycleId));
  final sellProfit = SteadyService.calcSellProfit(trades, cycle.averagePrice);

  return SteadyService.generateGuide(
    cycle: cycle,
    currentPrice: currentPrice,
    exchangeRate: liveExchangeRate,
    totalSellKrw: totalSellKrw,
    sellProfit: sellProfit,
  );
});
