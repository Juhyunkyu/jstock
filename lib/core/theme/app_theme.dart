import 'package:flutter/material.dart';
import 'app_colors.dart';

/// 앱 테마 정의
/// 시스템 기본 폰트를 사용하여 안정적인 로딩을 보장합니다.
/// 한글은 시스템 기본 한글 폰트 (Android: Noto Sans KR, iOS: Apple SD Gothic Neo)로 표시됩니다.
class AppTheme {
  AppTheme._();

  // 시스템 기본 폰트 패밀리
  // 한글 지원 폰트 스택: 시스템 기본 → 표준 한글 폰트
  static const String _fontFamily = 'Pretendard';
  static const List<String> _fontFamilyFallback = [
    'Noto Sans KR',
    'Apple SD Gothic Neo',
    'Malgun Gothic',
    '-apple-system',
    'BlinkMacSystemFont',
    'Segoe UI',
    'Roboto',
    'sans-serif',
  ];

  /// 텍스트 스타일 생성 헬퍼
  static TextStyle _textStyle({
    required double fontSize,
    FontWeight fontWeight = FontWeight.normal,
    Color? color,
  }) {
    return TextStyle(
      fontFamily: _fontFamily,
      fontFamilyFallback: _fontFamilyFallback,
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
    );
  }

  /// 라이트 테마
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: _fontFamily,

      // 색상 스킴
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.light,
      ),

      // 배경색
      scaffoldBackgroundColor: AppColors.background,

      // 앱바 테마
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: _textStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),

      // 카드 테마
      cardTheme: CardTheme(
        color: AppColors.cardBackground,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),

      // 텍스트 테마
      textTheme: TextTheme(
        headlineLarge: _textStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
        headlineMedium: _textStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        titleLarge: _textStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        titleMedium: _textStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        ),
        bodyLarge: _textStyle(
          fontSize: 16,
          color: AppColors.textPrimary,
        ),
        bodyMedium: _textStyle(
          fontSize: 14,
          color: AppColors.textSecondary,
        ),
        labelLarge: _textStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        ),
      ),

      // 버튼 테마
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),

      // 입력 필드 테마
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.textHint),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.textHint),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),

      // 하단 네비게이션 테마
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),

      // 다이얼로그 테마
      dialogTheme: DialogTheme(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  /// 다크 테마
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: _fontFamily,

      // 색상 스킴
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF58A6FF),
        brightness: Brightness.dark,
        surface: AppColors.darkSurface,
      ),

      // 배경색
      scaffoldBackgroundColor: AppColors.darkBackground,

      // 앱바 테마
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.darkBackground,
        foregroundColor: AppColors.darkTextPrimary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: _textStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.darkTextPrimary,
        ),
      ),

      // 카드 테마
      cardTheme: CardTheme(
        color: AppColors.darkCardBackground,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.darkBorder, width: 0.5),
        ),
      ),

      // 텍스트 테마
      textTheme: TextTheme(
        headlineLarge: _textStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: AppColors.darkTextPrimary,
        ),
        headlineMedium: _textStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: AppColors.darkTextPrimary,
        ),
        titleLarge: _textStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.darkTextPrimary,
        ),
        titleMedium: _textStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: AppColors.darkTextPrimary,
        ),
        bodyLarge: _textStyle(
          fontSize: 16,
          color: AppColors.darkTextPrimary,
        ),
        bodyMedium: _textStyle(
          fontSize: 14,
          color: AppColors.darkTextSecondary,
        ),
        labelLarge: _textStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.darkTextPrimary,
        ),
      ),

      // 버튼 테마
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF58A6FF),
          foregroundColor: AppColors.darkBackground,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),

      // 입력 필드 테마
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF58A6FF), width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),

      // 하단 네비게이션 테마
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.darkSurface,
        selectedItemColor: Color(0xFF58A6FF),
        unselectedItemColor: AppColors.darkTextSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),

      // 다이얼로그 테마
      dialogTheme: DialogTheme(
        backgroundColor: AppColors.darkCardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),

      // 바텀시트 테마
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.darkCardBackground,
      ),

      // 디바이더 테마
      dividerTheme: const DividerThemeData(
        color: AppColors.darkDivider,
      ),

      // 스낵바 테마
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.darkCardBackground,
        contentTextStyle: _textStyle(
          fontSize: 14,
          color: AppColors.darkTextPrimary,
        ),
      ),

      // ListTile 테마
      listTileTheme: const ListTileThemeData(
        textColor: AppColors.darkTextPrimary,
        iconColor: AppColors.darkTextSecondary,
      ),
    );
  }
}
