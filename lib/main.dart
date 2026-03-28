import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'app.dart';
import 'core/theme/app_colors.dart';
import 'data/models/models.dart';
import 'data/services/background/background_task_handler.dart';
import 'data/services/cache/logo_cache_service.dart';
import 'routes/app_router.dart';

void main() async {
  // Flutter 바인딩 초기화
  WidgetsFlutterBinding.ensureInitialized();

  // go_router: push/pop을 브라우저 히스토리에 반영
  AppRouter.init();

  // Hive 초기화
  await Hive.initFlutter();

  // 레거시 박스 삭제 (V2 -> V3 마이그레이션 안전)
  try {
    await Hive.deleteBoxFromDisk('cycles');
    await Hive.deleteBoxFromDisk('trades');
  } catch (_) {}

  // Hive 어댑터 등록
  Hive.registerAdapter(StockAdapter());
  Hive.registerAdapter(SettingsAdapter());
  Hive.registerAdapter(HoldingAdapter());
  Hive.registerAdapter(HoldingTransactionAdapter());
  Hive.registerAdapter(HoldingTransactionTypeAdapter());
  Hive.registerAdapter(WatchlistItemAdapter());
  Hive.registerAdapter(NotificationRecordAdapter());
  Hive.registerAdapter(DrawingTypeAdapter());
  Hive.registerAdapter(ChartDrawingAdapter());
  Hive.registerAdapter(CycleAdapter());
  Hive.registerAdapter(TradeAdapter());
  Hive.registerAdapter(StrategyTypeAdapter());
  Hive.registerAdapter(TradeSignalAdapter());
  Hive.registerAdapter(CycleStatusAdapter());
  Hive.registerAdapter(TradeActionAdapter());
  Hive.registerAdapter(SteadyVersionAdapter());

  // 테마 설정 선행 로드 (앱 시작 전 올바른 테마 적용)
  try {
    final settingsBox = await Hive.openBox<Settings>('settings');
    final settings = settingsBox.get('settings');
    if (settings != null) {
      final themeIndex = settings.themeType.clamp(0, AppThemeType.values.length - 1);
      final themeType = AppThemeType.values[themeIndex];
      final resolved = themeType == AppThemeType.system ? AppThemeType.dark : themeType;
      setCurrentAppTheme(resolved);
    }
    await settingsBox.close();
  } catch (_) {}

  // 로고 캐시 초기화
  final logoCache = LogoCacheService();
  await logoCache.initialize();

  // 백그라운드 태스크 핸들러 초기화
  final backgroundHandler = BackgroundTaskHandler();
  await backgroundHandler.initialize();

  // 앱 실행
  runApp(
    const ProviderScope(
      child: AlphaCycleApp(),
    ),
  );
}
