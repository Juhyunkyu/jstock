import 'package:hive/hive.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/formula_constants.dart';

part 'settings.g.dart';

/// 앱 설정 모델
@HiveType(typeId: 3)
class Settings extends HiveObject {
  // ═══════════════════════════════════════════════════════════════
  // 환율 설정
  // ═══════════════════════════════════════════════════════════════

  /// 환율 (원/달러)
  @HiveField(0)
  double exchangeRate;

  /// 실시간 환율 사용 여부
  @HiveField(1)
  bool useRealtimeRate;

  // ═══════════════════════════════════════════════════════════════
  // 알림 설정
  // ═══════════════════════════════════════════════════════════════

  /// 매수 신호 알림
  @HiveField(2)
  bool notifyBuySignal;

  /// 익절 신호 알림
  @HiveField(3)
  bool notifySellSignal;

  /// 승부수 신호 알림
  @HiveField(4)
  bool notifyPanicSignal;

  /// 일일 요약 알림
  @HiveField(5)
  bool notifyDailySummary;

  /// 알림 체크 간격 (분)
  @HiveField(6)
  int checkIntervalMinutes;

  // ═══════════════════════════════════════════════════════════════
  // 기본 매매 조건 (새 사이클 생성 시 적용)
  // ═══════════════════════════════════════════════════════════════

  /// 초기 진입 비율 (0.20 = 20%)
  @HiveField(7)
  double defaultEntryRatio;

  /// 매수 시작점 (기본: -20)
  @HiveField(8)
  double defaultBuyTrigger;

  /// 익절 목표 (기본: +20)
  @HiveField(9)
  double defaultSellTrigger;

  /// 승부수 발동점 (기본: -50)
  @HiveField(10)
  double defaultPanicTrigger;

  // ═══════════════════════════════════════════════════════════════
  // 앱 설정
  // ═══════════════════════════════════════════════════════════════

  /// 다크 모드 사용
  @HiveField(11)
  bool useDarkMode;

  /// 마지막 데이터 백업 일시
  @HiveField(12)
  DateTime? lastBackupDate;

  // ═══════════════════════════════════════════════════════════════
  // 공포탐욕지수 알림 설정
  // ═══════════════════════════════════════════════════════════════

  /// 공포탐욕지수 알림 활성화
  @HiveField(13, defaultValue: false)
  bool fearGreedAlertEnabled;

  /// 공포탐욕지수 알림 임계값 (0-100)
  @HiveField(14, defaultValue: 25)
  int fearGreedAlertValue;

  /// 공포탐욕지수 알림 방향 (0 = 이하, 1 = 이상)
  @HiveField(15, defaultValue: 0)
  int fearGreedAlertDirection;

  Settings({
    this.exchangeRate = AppConstants.defaultExchangeRate,
    this.useRealtimeRate = false,
    this.notifyBuySignal = true,
    this.notifySellSignal = true,
    this.notifyPanicSignal = true,
    this.notifyDailySummary = false,
    this.checkIntervalMinutes = AppConstants.defaultCheckIntervalMinutes,
    this.defaultEntryRatio = FormulaConstants.initialEntryRatio,
    this.defaultBuyTrigger = FormulaConstants.buyTriggerPercent,
    this.defaultSellTrigger = FormulaConstants.sellTriggerPercent,
    this.defaultPanicTrigger = FormulaConstants.panicTriggerPercent,
    this.useDarkMode = false,
    this.lastBackupDate,
    this.fearGreedAlertEnabled = false,
    this.fearGreedAlertValue = 25,
    this.fearGreedAlertDirection = 0,
  });

  /// 기본 설정 생성
  factory Settings.defaults() => Settings();

  /// 복사본 생성
  Settings copyWith({
    double? exchangeRate,
    bool? useRealtimeRate,
    bool? notifyBuySignal,
    bool? notifySellSignal,
    bool? notifyPanicSignal,
    bool? notifyDailySummary,
    int? checkIntervalMinutes,
    double? defaultEntryRatio,
    double? defaultBuyTrigger,
    double? defaultSellTrigger,
    double? defaultPanicTrigger,
    bool? useDarkMode,
    DateTime? lastBackupDate,
    bool? fearGreedAlertEnabled,
    int? fearGreedAlertValue,
    int? fearGreedAlertDirection,
  }) {
    return Settings(
      exchangeRate: exchangeRate ?? this.exchangeRate,
      useRealtimeRate: useRealtimeRate ?? this.useRealtimeRate,
      notifyBuySignal: notifyBuySignal ?? this.notifyBuySignal,
      notifySellSignal: notifySellSignal ?? this.notifySellSignal,
      notifyPanicSignal: notifyPanicSignal ?? this.notifyPanicSignal,
      notifyDailySummary: notifyDailySummary ?? this.notifyDailySummary,
      checkIntervalMinutes: checkIntervalMinutes ?? this.checkIntervalMinutes,
      defaultEntryRatio: defaultEntryRatio ?? this.defaultEntryRatio,
      defaultBuyTrigger: defaultBuyTrigger ?? this.defaultBuyTrigger,
      defaultSellTrigger: defaultSellTrigger ?? this.defaultSellTrigger,
      defaultPanicTrigger: defaultPanicTrigger ?? this.defaultPanicTrigger,
      useDarkMode: useDarkMode ?? this.useDarkMode,
      lastBackupDate: lastBackupDate ?? this.lastBackupDate,
      fearGreedAlertEnabled: fearGreedAlertEnabled ?? this.fearGreedAlertEnabled,
      fearGreedAlertValue: fearGreedAlertValue ?? this.fearGreedAlertValue,
      fearGreedAlertDirection: fearGreedAlertDirection ?? this.fearGreedAlertDirection,
    );
  }

  @override
  String toString() {
    return 'Settings(exchangeRate: $exchangeRate, buyTrigger: $defaultBuyTrigger, '
        'sellTrigger: $defaultSellTrigger, panicTrigger: $defaultPanicTrigger)';
  }
}
