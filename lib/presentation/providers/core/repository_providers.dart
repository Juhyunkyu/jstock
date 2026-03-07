import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/repositories/repositories.dart';
import '../api_providers.dart';
import '../stock_providers.dart';
import '../notification_providers.dart';

/// Repository 인스턴스 저장을 위한 컨테이너
class RepositoryContainer {
  final SettingsRepository settingsRepository;
  final HoldingRepository holdingRepository;
  final ChartDrawingRepository chartDrawingRepository;
  final CycleRepository cycleRepository;
  final TradeRepository tradeRepository;

  const RepositoryContainer({
    required this.settingsRepository,
    required this.holdingRepository,
    required this.chartDrawingRepository,
    required this.cycleRepository,
    required this.tradeRepository,
  });

  /// 모든 Repository 초기화
  static Future<RepositoryContainer> initialize() async {
    final settingsRepo = SettingsRepository();
    final holdingRepo = HoldingRepository();
    final chartDrawingRepo = ChartDrawingRepository();
    final cycleRepo = CycleRepository();
    final tradeRepo = TradeRepository();

    await Future.wait([
      settingsRepo.init(),
      holdingRepo.init(),
      chartDrawingRepo.init(),
      cycleRepo.init(),
      tradeRepo.init(),
    ]);

    return RepositoryContainer(
      settingsRepository: settingsRepo,
      holdingRepository: holdingRepo,
      chartDrawingRepository: chartDrawingRepo,
      cycleRepository: cycleRepo,
      tradeRepository: tradeRepo,
    );
  }

  /// 모든 Repository 닫기
  Future<void> close() async {
    await Future.wait([
      settingsRepository.close(),
      holdingRepository.close(),
      chartDrawingRepository.close(),
      cycleRepository.close(),
      tradeRepository.close(),
    ]);
  }
}

/// Repository 컨테이너 Provider (비동기 초기화)
final repositoryContainerProvider = FutureProvider<RepositoryContainer>((ref) async {
  final container = await RepositoryContainer.initialize();

  // Provider가 dispose될 때 Repository 닫기
  ref.onDispose(() {
    container.close();
  });

  return container;
});

/// Settings Repository Provider
final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  final container = ref.watch(repositoryContainerProvider);
  return container.maybeWhen(
    data: (c) => c.settingsRepository,
    orElse: () => throw StateError('Repository not initialized'),
  );
});

/// Holding Repository Provider
final holdingRepositoryProvider = Provider<HoldingRepository>((ref) {
  final container = ref.watch(repositoryContainerProvider);
  return container.maybeWhen(
    data: (c) => c.holdingRepository,
    orElse: () => throw StateError('Repository not initialized'),
  );
});

/// ChartDrawing Repository Provider
final chartDrawingRepositoryProvider = Provider<ChartDrawingRepository>((ref) {
  final container = ref.watch(repositoryContainerProvider);
  return container.maybeWhen(
    data: (c) => c.chartDrawingRepository,
    orElse: () => throw StateError('Repository not initialized'),
  );
});

/// Cycle Repository Provider
final cycleRepositoryProvider = Provider<CycleRepository>((ref) {
  final container = ref.watch(repositoryContainerProvider);
  return container.maybeWhen(
    data: (c) => c.cycleRepository,
    orElse: () => throw StateError('Repository not initialized'),
  );
});

/// Trade Repository Provider
final tradeRepositoryProvider = Provider<TradeRepository>((ref) {
  final container = ref.watch(repositoryContainerProvider);
  return container.maybeWhen(
    data: (c) => c.tradeRepository,
    orElse: () => throw StateError('Repository not initialized'),
  );
});

/// 앱 초기화 상태 Provider
final appInitializationProvider = FutureProvider<bool>((ref) async {
  // 1. Repository 초기화
  await ref.watch(repositoryContainerProvider.future);

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
    // API 실패 시 빈 상태 유지 (Mock 데이터 제거)
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
