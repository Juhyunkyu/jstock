import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/services/notification/notification_service.dart';
import '../../data/services/background/price_check_service.dart';
import '../../data/services/background/background_task_handler.dart';
import 'core/repository_providers.dart';
import 'api_providers.dart';

/// NotificationService Provider (싱글톤)
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

/// BackgroundTaskHandler Provider (싱글톤)
final backgroundTaskHandlerProvider = Provider<BackgroundTaskHandler>((ref) {
  return BackgroundTaskHandler();
});

/// PriceCheckService Provider
final priceCheckServiceProvider = Provider<PriceCheckService>((ref) {
  final stockService = ref.watch(finnhubServiceProvider);
  final notificationService = ref.watch(notificationServiceProvider);
  final cycleRepo = ref.watch(cycleRepositoryProvider);
  final settingsRepo = ref.watch(settingsRepositoryProvider);

  final service = PriceCheckService(
    stockService: stockService,
    notificationService: notificationService,
    cycleRepository: cycleRepo,
    settingsRepository: settingsRepo,
  );

  ref.onDispose(() {
    service.dispose();
  });

  return service;
});

/// 알림 초기화 상태
class NotificationState {
  final bool isInitialized;
  final bool hasPermission;
  final bool isPriceCheckRunning;
  final DateTime? lastCheckTime;
  final String? error;

  const NotificationState({
    this.isInitialized = false,
    this.hasPermission = false,
    this.isPriceCheckRunning = false,
    this.lastCheckTime,
    this.error,
  });

  NotificationState copyWith({
    bool? isInitialized,
    bool? hasPermission,
    bool? isPriceCheckRunning,
    DateTime? lastCheckTime,
    String? error,
  }) {
    return NotificationState(
      isInitialized: isInitialized ?? this.isInitialized,
      hasPermission: hasPermission ?? this.hasPermission,
      isPriceCheckRunning: isPriceCheckRunning ?? this.isPriceCheckRunning,
      lastCheckTime: lastCheckTime ?? this.lastCheckTime,
      error: error,
    );
  }
}

/// 알림 상태 관리 Notifier
class NotificationStateNotifier extends StateNotifier<NotificationState> {
  final NotificationService _notificationService;
  final PriceCheckService _priceCheckService;
  final BackgroundTaskHandler _backgroundTaskHandler;

  NotificationStateNotifier(
    this._notificationService,
    this._priceCheckService,
    this._backgroundTaskHandler,
  ) : super(const NotificationState());

  /// 알림 서비스 초기화
  Future<void> initialize() async {
    try {
      // 알림 서비스 초기화
      final initialized = await _notificationService.initialize();

      // 권한 확인
      final hasPermission = await _notificationService.hasPermission();

      // 백그라운드 태스크 핸들러 초기화
      await _backgroundTaskHandler.initialize();

      state = state.copyWith(
        isInitialized: initialized,
        hasPermission: hasPermission,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// 알림 권한 요청
  Future<bool> requestPermission() async {
    final granted = await _notificationService.requestPermission();
    state = state.copyWith(hasPermission: granted);
    return granted;
  }

  /// 주기적 가격 체크 시작
  void startPriceCheck() {
    _priceCheckService.startPeriodicCheck();
    state = state.copyWith(isPriceCheckRunning: true);
  }

  /// 주기적 가격 체크 중지
  void stopPriceCheck() {
    _priceCheckService.stopPeriodicCheck();
    state = state.copyWith(isPriceCheckRunning: false);
  }

  /// 수동 가격 체크
  Future<PriceCheckResult> checkNow() async {
    final result = await _priceCheckService.checkNow();
    state = state.copyWith(
      lastCheckTime: _priceCheckService.lastCheckTime,
    );
    return result;
  }

  /// 백그라운드 태스크 등록
  Future<void> registerBackgroundTasks(int intervalMinutes) async {
    await _backgroundTaskHandler.registerPriceCheckTask(
      intervalMinutes: intervalMinutes,
    );
    await _backgroundTaskHandler.registerDailySummaryTask();
  }

  /// 백그라운드 태스크 취소
  Future<void> cancelBackgroundTasks() async {
    await _backgroundTaskHandler.cancelAllTasks();
  }

  /// 일일 요약 발송
  Future<void> sendDailySummary() async {
    await _priceCheckService.sendDailySummary();
  }

  /// 모든 알림 취소
  Future<void> cancelAllNotifications() async {
    await _notificationService.cancelAll();
  }
}

/// 알림 상태 Provider
final notificationStateProvider =
    StateNotifierProvider<NotificationStateNotifier, NotificationState>((ref) {
  final notificationService = ref.watch(notificationServiceProvider);
  final priceCheckService = ref.watch(priceCheckServiceProvider);
  final backgroundTaskHandler = ref.watch(backgroundTaskHandlerProvider);

  return NotificationStateNotifier(
    notificationService,
    priceCheckService,
    backgroundTaskHandler,
  );
});

/// 알림 초기화 Provider
final notificationInitProvider = FutureProvider<void>((ref) async {
  final notifier = ref.read(notificationStateProvider.notifier);
  await notifier.initialize();
});

/// 알림 권한 여부 Provider
final hasNotificationPermissionProvider = Provider<bool>((ref) {
  return ref.watch(notificationStateProvider).hasPermission;
});

/// 가격 체크 실행 중 여부 Provider
final isPriceCheckRunningProvider = Provider<bool>((ref) {
  return ref.watch(notificationStateProvider).isPriceCheckRunning;
});

/// 마지막 체크 시간 Provider
final lastCheckTimeProvider = Provider<DateTime?>((ref) {
  return ref.watch(notificationStateProvider).lastCheckTime;
});
