import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_colors.dart';
import 'core/constants/app_constants.dart';
import 'routes/app_router.dart';
import 'presentation/providers/providers.dart';
import 'presentation/widgets/common/app_title_logo.dart';

/// 알파 사이클 앱 루트 위젯
class AlphaCycleApp extends ConsumerWidget {
  const AlphaCycleApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final initialization = ref.watch(appInitializationProvider);
    final settings = ref.watch(settingsProvider);

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: settings.useDarkMode ? ThemeMode.dark : ThemeMode.light,
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
          data: (_) => child!,
          loading: () => const _SplashScreen(),
          error: (error, stack) => _ErrorScreen(error: error.toString()),
        );
      },
    );
  }
}

/// 앱 초기화 중 표시되는 스플래시 화면
/// index.html의 HTML 스플래시와 동일한 디자인 (흰 배경 + ∞ Alpha Cycle + 스피너)
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // HTML 스플래시와 동일한 색상값 하드코딩 (테마 무관하게 일치시키기 위함)
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '∞',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2563EB), // index.html .infinity-symbol color
                    height: 1,
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  'Alpha Cycle',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1a1a1a), // index.html .app-name color
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 48),
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
                backgroundColor: Color(0xFFe5e7eb),
              ),
            ),
          ],
        ),
      ),
    );
  }
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
