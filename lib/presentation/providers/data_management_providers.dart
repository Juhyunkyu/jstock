import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/services/data/data_management_service.dart';
import 'core/repository_providers.dart';
import 'watchlist_providers.dart';
import 'notification_history_provider.dart';

/// DataManagementService Provider
final dataManagementServiceProvider = Provider<DataManagementService>((ref) {
  return DataManagementService(
    cycleRepository: ref.watch(cycleRepositoryProvider),
    tradeRepository: ref.watch(tradeRepositoryProvider),
    watchlistRepository: ref.watch(watchlistRepositoryProvider),
    holdingRepository: ref.watch(holdingRepositoryProvider),
    notificationRepository: ref.watch(notificationRepositoryProvider),
    settingsRepository: ref.watch(settingsRepositoryProvider),
  );
});
