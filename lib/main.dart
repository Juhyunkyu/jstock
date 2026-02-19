import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'app.dart';
import 'data/models/models.dart';
import 'data/services/background/background_task_handler.dart';
import 'data/services/cache/logo_cache_service.dart';

void main() async {
  // Flutter 바인딩 초기화
  WidgetsFlutterBinding.ensureInitialized();

  // Hive 초기화
  await Hive.initFlutter();

  // Hive 어댑터 등록
  Hive.registerAdapter(StockAdapter());
  Hive.registerAdapter(CycleAdapter());
  Hive.registerAdapter(CycleStatusAdapter());
  Hive.registerAdapter(TradeAdapter());
  Hive.registerAdapter(TradeActionAdapter());
  Hive.registerAdapter(SettingsAdapter());
  Hive.registerAdapter(HoldingAdapter());
  Hive.registerAdapter(HoldingTransactionAdapter());
  Hive.registerAdapter(HoldingTransactionTypeAdapter());
  Hive.registerAdapter(WatchlistItemAdapter());
  Hive.registerAdapter(NotificationRecordAdapter());

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
