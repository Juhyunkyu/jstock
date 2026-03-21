import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/repositories/repositories.dart';
import '../api_providers.dart';
import '../stock_providers.dart';
import '../notification_providers.dart';

// ═══════════════════════════════════════════════════════════════
// Repository Providers (싱글턴 인스턴스)
//
// 모든 Repository를 여기서 중앙 관리.
// 각 Provider는 앱 수명 동안 동일한 인스턴스를 반환.
// init()은 appInitializationProvider에서 병렬 호출.
// ═══════════════════════════════════════════════════════════════

final _settingsRepo = SettingsRepository();
final _holdingRepo = HoldingRepository();
final _chartDrawingRepo = ChartDrawingRepository();
final _cycleRepo = CycleRepository();
final _tradeRepo = TradeRepository();
final _memoRepo = MemoRepository();
final _watchlistRepo = WatchlistRepository();
final _notificationRepo = NotificationRepository();
final _watchlistGroupRepo = WatchlistGroupRepository();
final _recentViewRepo = RecentViewRepository();

/// Settings Repository Provider
final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return _settingsRepo;
});

/// Holding Repository Provider
final holdingRepositoryProvider = Provider<HoldingRepository>((ref) {
  return _holdingRepo;
});

/// ChartDrawing Repository Provider
final chartDrawingRepositoryProvider = Provider<ChartDrawingRepository>((ref) {
  return _chartDrawingRepo;
});

/// Cycle Repository Provider
final cycleRepositoryProvider = Provider<CycleRepository>((ref) {
  return _cycleRepo;
});

/// Trade Repository Provider
final tradeRepositoryProvider = Provider<TradeRepository>((ref) {
  return _tradeRepo;
});

/// Memo Repository Provider
final memoRepositoryProvider = Provider<MemoRepository>((ref) {
  return _memoRepo;
});

/// Watchlist Repository Provider
final watchlistRepositoryProvider = Provider<WatchlistRepository>((ref) {
  return _watchlistRepo;
});

/// Notification Repository Provider
final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return _notificationRepo;
});

/// WatchlistGroup Repository Provider
final watchlistGroupRepositoryProvider = Provider<WatchlistGroupRepository>((ref) {
  return _watchlistGroupRepo;
});

/// RecentView Repository Provider
final recentViewRepositoryProvider = Provider<RecentViewRepository>((ref) {
  return _recentViewRepo;
});

// ═══════════════════════════════════════════════════════════════
// 앱 초기화 Provider
// ═══════════════════════════════════════════════════════════════

/// 앱 초기화 — Repository init() + API 로드
final appInitializationProvider = FutureProvider<bool>((ref) async {
  // 1. Repository 초기화 (병렬)
  await Future.wait([
    _settingsRepo.init(),
    _holdingRepo.init(),
    _chartDrawingRepo.init(),
    _cycleRepo.init(),
    _tradeRepo.init(),
    _memoRepo.init(),
    _watchlistRepo.init(),
    _notificationRepo.init(),
    _watchlistGroupRepo.init(),
    _recentViewRepo.init(),
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
