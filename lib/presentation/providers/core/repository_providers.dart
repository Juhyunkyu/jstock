import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/repositories/repositories.dart';
import '../api_providers.dart';
import '../stock_providers.dart';
import '../notification_providers.dart';

// ═══════════════════════════════════════════════════════════════
// Repository Providers (단순 인스턴스 — init()은 앱 초기화 시 호출)
// ═══════════════════════════════════════════════════════════════

/// Settings Repository Provider
final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository();
});

/// Holding Repository Provider
final holdingRepositoryProvider = Provider<HoldingRepository>((ref) {
  return HoldingRepository();
});

/// ChartDrawing Repository Provider
final chartDrawingRepositoryProvider = Provider<ChartDrawingRepository>((ref) {
  return ChartDrawingRepository();
});

/// Cycle Repository Provider
final cycleRepositoryProvider = Provider<CycleRepository>((ref) {
  return CycleRepository();
});

/// Trade Repository Provider
final tradeRepositoryProvider = Provider<TradeRepository>((ref) {
  return TradeRepository();
});

// ═══════════════════════════════════════════════════════════════
// 앱 초기화 Provider
// ═══════════════════════════════════════════════════════════════

/// 앱 초기화 — Repository init() + API 로드
final appInitializationProvider = FutureProvider<bool>((ref) async {
  // 1. Repository 초기화 (병렬)
  await Future.wait([
    ref.read(settingsRepositoryProvider).init(),
    ref.read(holdingRepositoryProvider).init(),
    ref.read(chartDrawingRepositoryProvider).init(),
    ref.read(cycleRepositoryProvider).init(),
    ref.read(tradeRepositoryProvider).init(),
  ]);

  // 2. API 초기화 (실패해도 앱 시작은 허용)
  try {
    // 환율 조회
    final exchangeRateNotifier = ref.read(exchangeRateProvider.notifier);
    await exchangeRateNotifier.fetchUsdKrwRate();

    // 사용자 등록 종목의 주가 조회
    final userTickers = ref.read(userTickersProvider);
    if (userTickers.isNotEmpty) {
      final stockPriceNotifier = ref.read(stockPriceProvider.notifier);
      await stockPriceNotifier.loadSymbols(userTickers);
    }
  } catch (e) {
    // API 실패 시 빈 상태 유지
  }

  // 3. 알림 서비스 초기화 (실패해도 앱 시작은 허용)
  try {
    final notificationNotifier = ref.read(notificationStateProvider.notifier);
    await notificationNotifier.initialize();
  } catch (e) {
    // 알림 초기화 실패는 무시
  }

  return true;
});
