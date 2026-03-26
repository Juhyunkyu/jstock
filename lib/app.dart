import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_colors.dart';
import 'core/constants/app_constants.dart';
import 'routes/app_router.dart';
import 'presentation/providers/providers.dart';

/// 알파 사이클 앱 루트 위젯
class AlphaCycleApp extends ConsumerWidget {
  const AlphaCycleApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final initialization = ref.watch(appInitializationProvider);
    final settings = ref.watch(settingsProvider);

    // 테마 적용
    final themeType = AppThemeType.values[settings.themeType.clamp(0, AppThemeType.values.length - 1)];
    final resolvedTheme = themeType == AppThemeType.system
        ? (MediaQuery.platformBrightnessOf(context) == Brightness.dark
            ? AppThemeType.dark
            : AppThemeType.light)
        : themeType;
    setCurrentAppTheme(resolvedTheme);
    final isDark = resolvedTheme.isDark;

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      routerConfig: AppRouter.router,
      // 한국어 로케일 지원
      locale: const Locale('ko', 'KR'),
      supportedLocales: const [
        Locale('ko', 'KR'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        return initialization.when(
          data: (_) {
            // 초기화 완료 → HTML 스플래시 제거
            _removeSplash();
            return child!;
          },
          loading: () => const SizedBox.shrink(), // HTML 스플래시가 위에 덮고 있음
          error: (error, stack) {
            _removeSplash();
            return _ErrorScreen(error: error.toString());
          },
        );
      },
    );
  }
}

/// JS interop: window._removeSplash() 호출
@JS('_removeSplash')
external void _jsRemoveSplash();

bool _splashRemoved = false;

/// HTML 스플래시 제거 (1회만 실행)
void _removeSplash() {
  if (_splashRemoved) return;
  _splashRemoved = true;
  try {
    _jsRemoveSplash();
  } catch (_) {}
}

/// 에러 화면
class _ErrorScreen extends StatelessWidget {
  final String error;

  const _ErrorScreen({required this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: AppColors.red500,
              ),
              const SizedBox(height: 16),
              const Text(
                '앱 초기화 실패',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                error,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
