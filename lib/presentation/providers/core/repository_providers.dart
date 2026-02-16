import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/repositories/repositories.dart';
import '../api_providers.dart';
import '../stock_providers.dart';
import '../notification_providers.dart';

/// Repository 인스턴스 저장을 위한 컨테이너
class RepositoryContainer {
  final CycleRepository cycleRepository;
  final TradeRepository tradeRepository;
  final SettingsRepository settingsRepository;
  final HoldingRepository holdingRepository;

  const RepositoryContainer({
    required this.cycleRepository,
    required this.tradeRepository,
    required this.settingsRepository,
    required this.holdingRepository,
  });

  /// 모든 Repository 초기화
  static Future<RepositoryContainer> initialize() async {
    final cycleRepo = CycleRepository();
    final tradeRepo = TradeRepository();
    final settingsRepo = SettingsRepository();
    final holdingRepo = HoldingRepository();

    await Future.wait([
      cycleRepo.init(),
      tradeRepo.init(),
      settingsRepo.init(),
      holdingRepo.init(),
    ]);

    return RepositoryContainer(
      cycleRepository: cycleRepo,
      tradeRepository: tradeRepo,
      settingsRepository: settingsRepo,
      holdingRepository: holdingRepo,
    );
  }

  /// 모든 Repository 닫기
  Future<void> close() async {
    await Future.wait([
      cycleRepository.close(),
      tradeRepository.close(),
      settingsRepository.close(),
      holdingRepository.close(),
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
