import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/cycle.dart';
import '../../data/models/trade.dart';
import '../../domain/trading/steady_order_guide.dart';
import '../../domain/trading/steady_service.dart';
import '../../domain/trading/infinite_buy_service.dart';
import 'cycle_providers.dart';
import 'trade_providers.dart';
import 'stock_providers.dart';
import 'api_providers.dart';

/// Steady Cycle 주문 가이드 Provider (V1/V2.2/V3.0 통합)
/// Smart Cycle이면 null 반환
final steadyOrderGuideProvider =
    Provider.family<SteadyOrderGuide?, String>((ref, cycleId) {
  final cycles = ref.watch(cycleListProvider);
  final cycle = cycles.where((c) => c.id == cycleId).firstOrNull;
  if (cycle == null) return null;
  if (cycle.strategyType != StrategyType.infiniteBuy) return null;

  final prices = ref.watch(closingPricesProvider);
  final currentPrice = prices[cycle.ticker] ?? 0;
  if (currentPrice == 0) return null;

  final liveExchangeRate = ref.watch(currentExchangeRateProvider);
  if (liveExchangeRate == 0) return null;

  // V1: 간단한 가이드 (totalSellKrw/sellProfit 불필요)
  if (cycle.steadyVersion == SteadyVersion.v1) {
    return InfiniteBuyService.generateV1Guide(
      cycle: cycle,
      currentPrice: currentPrice,
      exchangeRate: liveExchangeRate,
    );
  }

  // V2.2/V3.0: 거래 이력에서 totalSellKrw + sellProfit 계산
  final trades = ref.watch(tradeListProvider(cycleId));
  double totalSellKrw = 0;
  double sellProfit = 0;
  for (final t in trades) {
    if (t.action != TradeAction.sell) continue;
    totalSellKrw += t.amountKrw;
    sellProfit += t.amountKrw - (t.shares * cycle.averagePrice * t.exchangeRate);
  }

  return SteadyService.generateGuide(
    cycle: cycle,
    currentPrice: currentPrice,
    exchangeRate: liveExchangeRate,
    totalSellKrw: totalSellKrw,
    sellProfit: sellProfit,
  );
});
