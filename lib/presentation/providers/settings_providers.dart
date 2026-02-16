import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/settings.dart';
import 'core/repository_providers.dart';
import 'api_providers.dart' as api;

/// 앱 설정 StateNotifier
class SettingsNotifier extends StateNotifier<Settings> {
  final Ref _ref;

  SettingsNotifier(this._ref) : super(Settings.defaults()) {
    _loadSettings();
  }

  void _loadSettings() {
    try {
      final repo = _ref.read(settingsRepositoryProvider);
      state = repo.settings;
    } catch (e) {
      // Repository 초기화 전에는 기본값 사용
    }
  }

  /// 설정 새로고침
  void refresh() {
    _loadSettings();
  }

  /// 환율 업데이트
  Future<void> updateExchangeRate(double rate) async {
    final repo = _ref.read(settingsRepositoryProvider);
    await repo.updateExchangeRate(rate);
    state = repo.settings;
  }

  /// 실시간 환율 사용 여부 업데이트
  Future<void> updateUseRealtimeRate(bool use) async {
    final repo = _ref.read(settingsRepositoryProvider);
    await repo.save(state.copyWith(useRealtimeRate: use));
    state = repo.settings;
  }

  /// 알림 설정 업데이트
  Future<void> updateNotificationSettings({
    bool? notifyBuySignal,
    bool? notifySellSignal,
    bool? notifyPanicSignal,
    bool? notifyDailySummary,
    int? checkIntervalMinutes,
  }) async {
    final repo = _ref.read(settingsRepositoryProvider);
    await repo.updateNotificationSettings(
      notifyBuySignal: notifyBuySignal,
      notifySellSignal: notifySellSignal,
      notifyPanicSignal: notifyPanicSignal,
      notifyDailySummary: notifyDailySummary,
      checkIntervalMinutes: checkIntervalMinutes,
    );
    state = repo.settings;
  }

  /// 기본 매매 조건 업데이트
  Future<void> updateTradingConditions({
    double? entryRatio,
    double? buyTrigger,
    double? sellTrigger,
    double? panicTrigger,
  }) async {
    final repo = _ref.read(settingsRepositoryProvider);
    await repo.updateDefaultTradingConditions(
      entryRatio: entryRatio,
      buyTrigger: buyTrigger,
      sellTrigger: sellTrigger,
      panicTrigger: panicTrigger,
    );
    state = repo.settings;
  }

  /// 다크 모드 토글
  Future<void> toggleDarkMode() async {
    final repo = _ref.read(settingsRepositoryProvider);
    await repo.save(state.copyWith(useDarkMode: !state.useDarkMode));
    state = repo.settings;
  }

  /// 다크 모드 설정
  Future<void> setDarkMode(bool isDark) async {
    final repo = _ref.read(settingsRepositoryProvider);
    await repo.save(state.copyWith(useDarkMode: isDark));
    state = repo.settings;
  }

  /// 백업 일시 업데이트
  Future<void> updateLastBackupDate() async {
    final repo = _ref.read(settingsRepositoryProvider);
    await repo.updateLastBackupDate();
    state = repo.settings;
  }

  /// 설정 초기화
  Future<void> reset() async {
    final repo = _ref.read(settingsRepositoryProvider);
    await repo.reset();
    state = repo.settings;
  }

  /// API에서 실시간 환율 가져와서 저장
  Future<void> syncExchangeRateFromApi() async {
    final apiNotifier = _ref.read(api.exchangeRateProvider.notifier);
    final rate = await apiNotifier.fetchUsdKrwRate();
    if (rate != null) {
      await updateExchangeRate(rate.rate);
    }
  }
}

/// 설정 Provider
final settingsProvider = StateNotifierProvider<SettingsNotifier, Settings>((ref) {
  return SettingsNotifier(ref);
});

/// 환율 Provider (실시간/수동 설정 통합)
final exchangeRateSettingsProvider = Provider<double>((ref) {
  final settings = ref.watch(settingsProvider);

  // 실시간 환율 사용 설정 시 API에서 가져옴
  if (settings.useRealtimeRate) {
    final apiRate = ref.watch(api.currentExchangeRateProvider);
    return apiRate;
  }

  // 수동 설정 환율 반환
  return settings.exchangeRate;
});

/// 매매 조건 Provider
final tradingConditionsProvider = Provider<TradingConditions>((ref) {
  final settings = ref.watch(settingsProvider);
  return TradingConditions(
    buyTrigger: settings.defaultBuyTrigger,
    sellTrigger: settings.defaultSellTrigger,
    panicTrigger: settings.defaultPanicTrigger,
  );
});

/// 알림 설정 Provider
final notificationSettingsProvider = Provider<NotificationSettings>((ref) {
  final settings = ref.watch(settingsProvider);
  return NotificationSettings(
    buySignal: settings.notifyBuySignal,
    sellSignal: settings.notifySellSignal,
    panicSignal: settings.notifyPanicSignal,
    dailySummary: settings.notifyDailySummary,
    checkIntervalMinutes: settings.checkIntervalMinutes,
  );
});

/// 매매 조건 데이터 클래스
class TradingConditions {
  final double buyTrigger;
  final double sellTrigger;
  final double panicTrigger;

  const TradingConditions({
    required this.buyTrigger,
    required this.sellTrigger,
    required this.panicTrigger,
  });
}

/// 알림 설정 데이터 클래스
class NotificationSettings {
  final bool buySignal;
  final bool sellSignal;
  final bool panicSignal;
  final bool dailySummary;
  final int checkIntervalMinutes;

  const NotificationSettings({
    required this.buySignal,
    required this.sellSignal,
    required this.panicSignal,
    required this.dailySummary,
    required this.checkIntervalMinutes,
  });
}
