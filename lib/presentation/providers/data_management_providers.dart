import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/services/data/data_management_service.dart';
import 'core/repository_providers.dart';

/// DataManagementService Provider
final dataManagementServiceProvider = Provider<DataManagementService>((ref) {
  return DataManagementService(
    watchlistRepository: ref.watch(watchlistRepositoryProvider),
    holdingRepository: ref.watch(holdingRepositoryProvider),
    notificationRepository: ref.watch(notificationRepositoryProvider),
    settingsRepository: ref.watch(settingsRepositoryProvider),
    cycleRepository: ref.watch(cycleRepositoryProvider),
    tradeRepository: ref.watch(tradeRepositoryProvider),
    watchlistGroupRepository: ref.watch(watchlistGroupRepositoryProvider),
    recentViewRepository: ref.watch(recentViewRepositoryProvider),
    memoRepository: ref.watch(memoRepositoryProvider),
    chartDrawingRepository: ref.watch(chartDrawingRepositoryProvider),
  );
});
