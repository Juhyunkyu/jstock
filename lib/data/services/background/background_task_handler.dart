import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:workmanager/workmanager.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../api/finnhub_service.dart';
import '../notification/notification_service.dart';
import '../../repositories/cycle_repository.dart';
import '../../repositories/settings_repository.dart';
import 'price_check_service.dart';

/// 백그라운드 태스크 이름
class BackgroundTasks {
  static const String priceCheck = 'price_check_task';
  static const String dailySummary = 'daily_summary_task';
}

/// 백그라운드 태스크 핸들러
///
/// WorkManager를 사용하여 앱이 백그라운드에 있을 때도
/// 주기적으로 가격을 체크하고 알림을 발송합니다.
class BackgroundTaskHandler {
  static final BackgroundTaskHandler _instance = BackgroundTaskHandler._internal();
  factory BackgroundTaskHandler() => _instance;
  BackgroundTaskHandler._internal();

  bool _isInitialized = false;

  /// 초기화 여부
  bool get isInitialized => _isInitialized;

  /// WorkManager 초기화
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Web에서는 WorkManager가 지원되지 않음
    if (kIsWeb) {
      _isInitialized = true;
      return;
    }

    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: false, // 프로덕션에서는 false
    );

    _isInitialized = true;
  }

  /// 주기적 가격 체크 태스크 등록
  Future<void> registerPriceCheckTask({
    required int intervalMinutes,
  }) async {
    // Web에서는 지원되지 않음
    if (kIsWeb) return;

    if (!_isInitialized) {
      await initialize();
    }

    // 기존 태스크 취소
    await Workmanager().cancelByUniqueName(BackgroundTasks.priceCheck);

    // 새 태스크 등록
    await Workmanager().registerPeriodicTask(
      BackgroundTasks.priceCheck,
      BackgroundTasks.priceCheck,
      frequency: Duration(minutes: intervalMinutes),
      constraints: Constraints(
        networkType: NetworkType.connected,
        requiresBatteryNotLow: false,
        requiresCharging: false,
        requiresDeviceIdle: false,
        requiresStorageNotLow: false,
      ),
      existingWorkPolicy: ExistingWorkPolicy.replace,
      backoffPolicy: BackoffPolicy.linear,
      backoffPolicyDelay: const Duration(minutes: 1),
    );
  }

  /// 일일 요약 태스크 등록
  Future<void> registerDailySummaryTask({
    int hour = 21, // 오후 9시
    int minute = 0,
  }) async {
    // Web에서는 지원되지 않음
    if (kIsWeb) return;

    if (!_isInitialized) {
      await initialize();
    }

    // 기존 태스크 취소
    await Workmanager().cancelByUniqueName(BackgroundTasks.dailySummary);

    // 다음 실행 시간 계산
    final now = DateTime.now();
    var scheduledTime = DateTime(now.year, now.month, now.day, hour, minute);
    if (scheduledTime.isBefore(now)) {
      scheduledTime = scheduledTime.add(const Duration(days: 1));
    }
    final delay = scheduledTime.difference(now);

    // 일회성 태스크로 등록 (실행 후 다음 날 재등록)
    await Workmanager().registerOneOffTask(
      BackgroundTasks.dailySummary,
      BackgroundTasks.dailySummary,
      initialDelay: delay,
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
    );
  }

  /// 가격 체크 태스크 취소
  Future<void> cancelPriceCheckTask() async {
    if (kIsWeb) return;
    await Workmanager().cancelByUniqueName(BackgroundTasks.priceCheck);
  }

  /// 일일 요약 태스크 취소
  Future<void> cancelDailySummaryTask() async {
    if (kIsWeb) return;
    await Workmanager().cancelByUniqueName(BackgroundTasks.dailySummary);
  }

  /// 모든 태스크 취소
  Future<void> cancelAllTasks() async {
    if (kIsWeb) return;
    await Workmanager().cancelAll();
  }
}

/// WorkManager 콜백 디스패처 (Top-level function)
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    try {
      // Hive 초기화
      await Hive.initFlutter();

      // Repository 초기화
      final cycleRepo = CycleRepository();
      final settingsRepo = SettingsRepository();
      await Future.wait([
        cycleRepo.init(),
        settingsRepo.init(),
      ]);

      // 서비스 초기화
      final notificationService = NotificationService();
      await notificationService.initialize();

      final stockService = FinnhubService();

      final priceCheckService = PriceCheckService(
        stockService: stockService,
        notificationService: notificationService,
        cycleRepository: cycleRepo,
        settingsRepository: settingsRepo,
      );

      // 태스크 실행
      switch (taskName) {
        case BackgroundTasks.priceCheck:
          final result = await priceCheckService.checkNow();
          print('Background price check: $result');
          break;

        case BackgroundTasks.dailySummary:
          await priceCheckService.sendDailySummary();
          // 다음 날 태스크 재등록
          final handler = BackgroundTaskHandler();
          await handler.registerDailySummaryTask();
          print('Daily summary sent, next task registered');
          break;
      }

      // Repository 정리
      await Future.wait([
        cycleRepo.close(),
        settingsRepo.close(),
      ]);

      return true;
    } catch (e) {
      print('Background task error: $e');
      return false;
    }
  });
}
