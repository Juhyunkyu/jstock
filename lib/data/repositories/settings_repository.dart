import 'package:hive/hive.dart';
import '../models/settings.dart';

/// 설정 저장소
class SettingsRepository {
  static const String _boxName = 'settings';
  static const String _settingsKey = 'app_settings';

  Box<Settings>? _box;

  /// Box 열기
  Future<void> init() async {
    _box = await Hive.openBox<Settings>(_boxName);

    // 설정이 없으면 기본 설정 생성
    if (_box!.get(_settingsKey) == null) {
      await _box!.put(_settingsKey, Settings.defaults());
    }
  }

  /// Box 가져오기
  Box<Settings> get box {
    if (_box == null || !_box!.isOpen) {
      throw StateError('SettingsRepository가 초기화되지 않았습니다. init()을 먼저 호출하세요.');
    }
    return _box!;
  }

  /// 설정 조회
  Settings get settings {
    return box.get(_settingsKey) ?? Settings.defaults();
  }

  /// 설정 저장
  Future<void> save(Settings settings) async {
    await box.put(_settingsKey, settings);
  }

  /// 환율 업데이트
  Future<void> updateExchangeRate(double rate) async {
    final current = settings;
    await save(current.copyWith(exchangeRate: rate));
  }

  /// 알림 설정 업데이트
  Future<void> updateNotificationSettings({
    bool? notifyBuySignal,
    bool? notifySellSignal,
    bool? notifyPanicSignal,
    bool? notifyDailySummary,
    int? checkIntervalMinutes,
  }) async {
    final current = settings;
    await save(current.copyWith(
      notifyBuySignal: notifyBuySignal,
      notifySellSignal: notifySellSignal,
      notifyPanicSignal: notifyPanicSignal,
      notifyDailySummary: notifyDailySummary,
      checkIntervalMinutes: checkIntervalMinutes,
    ));
  }

  /// 기본 매매 조건 업데이트
  Future<void> updateDefaultTradingConditions({
    double? entryRatio,
    double? buyTrigger,
    double? sellTrigger,
    double? panicTrigger,
  }) async {
    final current = settings;
    await save(current.copyWith(
      defaultEntryRatio: entryRatio,
      defaultBuyTrigger: buyTrigger,
      defaultSellTrigger: sellTrigger,
      defaultPanicTrigger: panicTrigger,
    ));
  }

  /// 백업 일시 업데이트
  Future<void> updateLastBackupDate() async {
    final current = settings;
    await save(current.copyWith(lastBackupDate: DateTime.now()));
  }

  /// 설정 초기화
  Future<void> reset() async {
    await save(Settings.defaults());
  }

  /// Box 닫기
  Future<void> close() async {
    await _box?.close();
  }
}
