import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════════
// 앱 테마 타입
// ═══════════════════════════════════════════════════════════════

enum AppThemeType {
  light,        // 기본 라이트
  dark,         // GitHub Dark
  amoledBlack,  // AMOLED 순수 검정
  midnightBlue, // 미드나이트 블루 (Bloomberg)
  darkOlive,    // 다크 올리브
  cream,        // 크림 (Solarized Light)
  coolGray,     // 쿨 그레이 (Yahoo Finance)
  system,       // 시스템 설정 따르기
}

extension AppThemeTypeExt on AppThemeType {
  bool get isDark => this == AppThemeType.dark ||
      this == AppThemeType.amoledBlack ||
      this == AppThemeType.midnightBlue ||
      this == AppThemeType.darkOlive;

  String get label => switch (this) {
    AppThemeType.light => '라이트',
    AppThemeType.dark => '다크',
    AppThemeType.amoledBlack => 'AMOLED 블랙',
    AppThemeType.midnightBlue => '미드나이트 블루',
    AppThemeType.darkOlive => '다크 올리브',
    AppThemeType.cream => '크림',
    AppThemeType.coolGray => '쿨 그레이',
    AppThemeType.system => '시스템 설정',
  };

  IconData get icon => switch (this) {
    AppThemeType.light => Icons.light_mode_outlined,
    AppThemeType.dark => Icons.dark_mode_outlined,
    AppThemeType.amoledBlack => Icons.brightness_1,
    AppThemeType.midnightBlue => Icons.nights_stay_outlined,
    AppThemeType.darkOlive => Icons.eco_outlined,
    AppThemeType.cream => Icons.wb_sunny_outlined,
    AppThemeType.coolGray => Icons.cloud_outlined,
    AppThemeType.system => Icons.settings_suggest_outlined,
  };
}

// ═══════════════════════════════════════════════════════════════
// 테마별 색상 세트
// ═══════════════════════════════════════════════════════════════

class ThemeColorSet {
  final Color background;
  final Color surface;
  final Color cardBackground;
  final Color iconBg;
  final Color textPrimary;
  final Color textSecondary;
  final Color textHint;
  final Color divider;
  final Color border;
  final Color accent;
  final Color stockUp;
  final Color stockDown;
  final Color stockUp50;
  final Color stockDown50;
  final Color tickerColor;
  final Color gradientCardStart;
  final Color gradientCardEnd;
  final Color periodReturnPositiveBg;
  final Color periodReturnNegativeBg;
  final Color returnProfitBg;
  final Color returnProfitFg;
  final Color returnLossBg;
  final Color returnLossFg;
  final Color stockChangePlusBg;
  final Color stockChangePlusFg;
  final Color stockChangeMinusBg;
  final Color stockChangeMinusFg;
  final Color disabledBg;
  final Color goodColor;
  final Color cautionColor;
  final Color warningColor;
  final Color shadowColor;
  final double shadowAlpha;

  const ThemeColorSet({
    required this.background,
    required this.surface,
    required this.cardBackground,
    required this.iconBg,
    required this.textPrimary,
    required this.textSecondary,
    required this.textHint,
    required this.divider,
    required this.border,
    required this.accent,
    required this.stockUp,
    required this.stockDown,
    required this.stockUp50,
    required this.stockDown50,
    required this.tickerColor,
    required this.gradientCardStart,
    required this.gradientCardEnd,
    required this.periodReturnPositiveBg,
    required this.periodReturnNegativeBg,
    required this.returnProfitBg,
    required this.returnProfitFg,
    required this.returnLossBg,
    required this.returnLossFg,
    required this.stockChangePlusBg,
    required this.stockChangePlusFg,
    required this.stockChangeMinusBg,
    required this.stockChangeMinusFg,
    required this.disabledBg,
    required this.goodColor,
    required this.cautionColor,
    required this.warningColor,
    required this.shadowColor,
    required this.shadowAlpha,
  });
}

// ═══════════════════════════════════════════════════════════════
// 7개 테마 팔레트 정의
// ═══════════════════════════════════════════════════════════════

const _themes = <AppThemeType, ThemeColorSet>{
  // ─── 라이트 (기존) ───
  AppThemeType.light: ThemeColorSet(
    background: Color(0xFFF8F9FA),
    surface: Color(0xFFFFFFFF),
    cardBackground: Color(0xFFFFFFFF),
    iconBg: Color(0xFFF3F4F6),
    textPrimary: Color(0xFF1A1A2E),
    textSecondary: Color(0xFF4B5563),
    textHint: Color(0xFF6B7280),
    divider: Color(0xFFE5E7EB),
    border: Color(0xFFD1D5DB),
    accent: Color(0xFF1A1A2E),
    stockUp: Color(0xFFEF4444),
    stockDown: Color(0xFF3B82F6),
    stockUp50: Color(0xFFFEF2F2),
    stockDown50: Color(0xFFEFF6FF),
    tickerColor: Color(0xFF1A1A2E),
    gradientCardStart: Color(0xFF2C3E50),
    gradientCardEnd: Color(0xFF1A252F),
    periodReturnPositiveBg: Color(0xFFFEF2F2),
    periodReturnNegativeBg: Color(0xFFEFF6FF),
    returnProfitBg: Color(0xFFD1FAE5),
    returnProfitFg: Color(0xFF059669),
    returnLossBg: Color(0xFFFEE2E2),
    returnLossFg: Color(0xFFDC2626),
    stockChangePlusBg: Color(0xFFFEE2E2),
    stockChangePlusFg: Color(0xFFEF4444),
    stockChangeMinusBg: Color(0xFFDBEAFE),
    stockChangeMinusFg: Color(0xFF3B82F6),
    disabledBg: Color(0xFFD1D5DB),
    goodColor: Color(0xFF059669),
    cautionColor: Color(0xFFD97706),
    warningColor: Color(0xFFDC2626),
    shadowColor: Color(0xFF000000),
    shadowAlpha: 0.05,
  ),

  // ─── 다크 (GitHub Dark, 기존) ───
  AppThemeType.dark: ThemeColorSet(
    background: Color(0xFF0D1117),
    surface: Color(0xFF161B22),
    cardBackground: Color(0xFF1C2128),
    iconBg: Color(0xFF21262D),
    textPrimary: Color(0xFFE6EDF3),
    textSecondary: Color(0xFF8B949E),
    textHint: Color(0xFF6E7681),
    divider: Color(0xFF21262D),
    border: Color(0xFF30363D),
    accent: Color(0xFF58A6FF),
    stockUp: Color(0xFFEF4444),
    stockDown: Color(0xFF3B82F6),
    stockUp50: Color(0xFF2D1B1B),
    stockDown50: Color(0xFF1B2333),
    tickerColor: Color(0xFFE6EDF3),
    gradientCardStart: Color(0xFF1A1F2E),
    gradientCardEnd: Color(0xFF0F1923),
    periodReturnPositiveBg: Color(0xFF2D1A1A),
    periodReturnNegativeBg: Color(0xFF1A2D3D),
    returnProfitBg: Color(0x26059669),
    returnProfitFg: Color(0xFF51CF66),
    returnLossBg: Color(0x26DC2626),
    returnLossFg: Color(0xFFFF6B6B),
    stockChangePlusBg: Color(0x26DC2626),
    stockChangePlusFg: Color(0xFFFF6B6B),
    stockChangeMinusBg: Color(0x262563EB),
    stockChangeMinusFg: Color(0xFF60A5FA),
    disabledBg: Color(0xFF30363D),
    goodColor: Color(0xFF10B981),
    cautionColor: Color(0xFFF59E0B),
    warningColor: Color(0xFFEF4444),
    shadowColor: Color(0xFFFFFFFF),
    shadowAlpha: 0.03,
  ),

  // ─── AMOLED 블랙 ───
  AppThemeType.amoledBlack: ThemeColorSet(
    background: Color(0xFF000000),
    surface: Color(0xFF0A0A0A),
    cardBackground: Color(0xFF121212),
    iconBg: Color(0xFF1A1A1A),
    textPrimary: Color(0xFFE8E8E8),
    textSecondary: Color(0xFF9E9E9E),
    textHint: Color(0xFF616161),
    divider: Color(0xFF1E1E1E),
    border: Color(0xFF2A2A2A),
    accent: Color(0xFF4FC3F7),
    stockUp: Color(0xFFF44336),
    stockDown: Color(0xFF42A5F5),
    stockUp50: Color(0xFF2D1515),
    stockDown50: Color(0xFF152233),
    tickerColor: Color(0xFFE8E8E8),
    gradientCardStart: Color(0xFF121218),
    gradientCardEnd: Color(0xFF080810),
    periodReturnPositiveBg: Color(0xFF2D1515),
    periodReturnNegativeBg: Color(0xFF152233),
    returnProfitBg: Color(0x26059669),
    returnProfitFg: Color(0xFF51CF66),
    returnLossBg: Color(0x26DC2626),
    returnLossFg: Color(0xFFFF6B6B),
    stockChangePlusBg: Color(0x26DC2626),
    stockChangePlusFg: Color(0xFFFF6B6B),
    stockChangeMinusBg: Color(0x262563EB),
    stockChangeMinusFg: Color(0xFF60A5FA),
    disabledBg: Color(0xFF2A2A2A),
    goodColor: Color(0xFF10B981),
    cautionColor: Color(0xFFF59E0B),
    warningColor: Color(0xFFEF4444),
    shadowColor: Color(0xFFFFFFFF),
    shadowAlpha: 0.02,
  ),

  // ─── 미드나이트 블루 ───
  AppThemeType.midnightBlue: ThemeColorSet(
    background: Color(0xFF0B1426),
    surface: Color(0xFF101D33),
    cardBackground: Color(0xFF152540),
    iconBg: Color(0xFF1B2D4D),
    textPrimary: Color(0xFFE2E8F0),
    textSecondary: Color(0xFF8899AA),
    textHint: Color(0xFF566676),
    divider: Color(0xFF1C2E47),
    border: Color(0xFF243B5C),
    accent: Color(0xFFFF9F1C),
    stockUp: Color(0xFFEF5350),
    stockDown: Color(0xFF42A5F5),
    stockUp50: Color(0xFF2D1B1E),
    stockDown50: Color(0xFF152540),
    tickerColor: Color(0xFFE2E8F0),
    gradientCardStart: Color(0xFF152540),
    gradientCardEnd: Color(0xFF0B1426),
    periodReturnPositiveBg: Color(0xFF2D1B1E),
    periodReturnNegativeBg: Color(0xFF0F1E33),
    returnProfitBg: Color(0x26059669),
    returnProfitFg: Color(0xFF51CF66),
    returnLossBg: Color(0x26DC2626),
    returnLossFg: Color(0xFFFF6B6B),
    stockChangePlusBg: Color(0x26DC2626),
    stockChangePlusFg: Color(0xFFFF6B6B),
    stockChangeMinusBg: Color(0x262563EB),
    stockChangeMinusFg: Color(0xFF60A5FA),
    disabledBg: Color(0xFF243B5C),
    goodColor: Color(0xFF10B981),
    cautionColor: Color(0xFFF59E0B),
    warningColor: Color(0xFFEF4444),
    shadowColor: Color(0xFFFFFFFF),
    shadowAlpha: 0.03,
  ),

  // ─── 다크 올리브 ───
  AppThemeType.darkOlive: ThemeColorSet(
    background: Color(0xFF141A13),
    surface: Color(0xFF1A2119),
    cardBackground: Color(0xFF1F2A1E),
    iconBg: Color(0xFF263326),
    textPrimary: Color(0xFFDAE0D3),
    textSecondary: Color(0xFF97A08E),
    textHint: Color(0xFF687560),
    divider: Color(0xFF232E22),
    border: Color(0xFF2E3D2D),
    accent: Color(0xFF8BC34A),
    stockUp: Color(0xFFEF5350),
    stockDown: Color(0xFF5C9DED),
    stockUp50: Color(0xFF2D1B1B),
    stockDown50: Color(0xFF1B2333),
    tickerColor: Color(0xFFDAE0D3),
    gradientCardStart: Color(0xFF1F2A1E),
    gradientCardEnd: Color(0xFF141A13),
    periodReturnPositiveBg: Color(0xFF2D1B1B),
    periodReturnNegativeBg: Color(0xFF1A2D3D),
    returnProfitBg: Color(0x26059669),
    returnProfitFg: Color(0xFF51CF66),
    returnLossBg: Color(0x26DC2626),
    returnLossFg: Color(0xFFFF6B6B),
    stockChangePlusBg: Color(0x26DC2626),
    stockChangePlusFg: Color(0xFFFF6B6B),
    stockChangeMinusBg: Color(0x262563EB),
    stockChangeMinusFg: Color(0xFF60A5FA),
    disabledBg: Color(0xFF2E3D2D),
    goodColor: Color(0xFF10B981),
    cautionColor: Color(0xFFF59E0B),
    warningColor: Color(0xFFEF4444),
    shadowColor: Color(0xFFFFFFFF),
    shadowAlpha: 0.03,
  ),

  // ─── 크림 (Solarized Light) ───
  AppThemeType.cream: ThemeColorSet(
    background: Color(0xFFFDF6E3),
    surface: Color(0xFFFAF0D2),
    cardBackground: Color(0xFFFFFFFF),
    iconBg: Color(0xFFEEE8D5),
    textPrimary: Color(0xFF3B3228),
    textSecondary: Color(0xFF6B5F52),
    textHint: Color(0xFF9C8E7E),
    divider: Color(0xFFE8DFC8),
    border: Color(0xFFD9CEBC),
    accent: Color(0xFF268BD2),
    stockUp: Color(0xFFD32F2F),
    stockDown: Color(0xFF1565C0),
    stockUp50: Color(0xFFFEE2E2),
    stockDown50: Color(0xFFDBEAFE),
    tickerColor: Color(0xFF3B3228),
    gradientCardStart: Color(0xFF3B3228),
    gradientCardEnd: Color(0xFF2A2318),
    periodReturnPositiveBg: Color(0xFFFEF2F2),
    periodReturnNegativeBg: Color(0xFFEFF6FF),
    returnProfitBg: Color(0xFFD1FAE5),
    returnProfitFg: Color(0xFF059669),
    returnLossBg: Color(0xFFFEE2E2),
    returnLossFg: Color(0xFFDC2626),
    stockChangePlusBg: Color(0xFFFEE2E2),
    stockChangePlusFg: Color(0xFFD32F2F),
    stockChangeMinusBg: Color(0xFFDBEAFE),
    stockChangeMinusFg: Color(0xFF1565C0),
    disabledBg: Color(0xFFD9CEBC),
    goodColor: Color(0xFF059669),
    cautionColor: Color(0xFFD97706),
    warningColor: Color(0xFFDC2626),
    shadowColor: Color(0xFF000000),
    shadowAlpha: 0.05,
  ),

  // ─── 쿨 그레이 (Yahoo Finance) ───
  AppThemeType.coolGray: ThemeColorSet(
    background: Color(0xFFF4F5F7),
    surface: Color(0xFFFFFFFF),
    cardBackground: Color(0xFFFFFFFF),
    iconBg: Color(0xFFE8EAED),
    textPrimary: Color(0xFF1F2937),
    textSecondary: Color(0xFF6B7280),
    textHint: Color(0xFF9CA3AF),
    divider: Color(0xFFE5E7EB),
    border: Color(0xFFD1D5DB),
    accent: Color(0xFF6366F1),
    stockUp: Color(0xFFDC2626),
    stockDown: Color(0xFF2563EB),
    stockUp50: Color(0xFFFEF2F2),
    stockDown50: Color(0xFFEFF6FF),
    tickerColor: Color(0xFF1F2937),
    gradientCardStart: Color(0xFF374151),
    gradientCardEnd: Color(0xFF1F2937),
    periodReturnPositiveBg: Color(0xFFFEF2F2),
    periodReturnNegativeBg: Color(0xFFEFF6FF),
    returnProfitBg: Color(0xFFD1FAE5),
    returnProfitFg: Color(0xFF059669),
    returnLossBg: Color(0xFFFEE2E2),
    returnLossFg: Color(0xFFDC2626),
    stockChangePlusBg: Color(0xFFFEE2E2),
    stockChangePlusFg: Color(0xFFDC2626),
    stockChangeMinusBg: Color(0xFFDBEAFE),
    stockChangeMinusFg: Color(0xFF2563EB),
    disabledBg: Color(0xFFD1D5DB),
    goodColor: Color(0xFF059669),
    cautionColor: Color(0xFFD97706),
    warningColor: Color(0xFFDC2626),
    shadowColor: Color(0xFF000000),
    shadowAlpha: 0.05,
  ),
};

// ═══════════════════════════════════════════════════════════════
// 앱 색상 팔레트 (정적 상수 — 테마 무관)
// ═══════════════════════════════════════════════════════════════

class AppColors {
  AppColors._();

  // 기본 색상
  static const Color primary = Color(0xFF1A1A2E);
  static const Color primaryDark = Color(0xFF0F0F1A);
  static const Color primaryLight = Color(0xFF2D2D44);

  static const Color secondary = Color(0xFF4A4A5A);
  static const Color secondaryDark = Color(0xFF3A3A4A);
  static const Color secondaryLight = Color(0xFF6A6A7A);

  // 정적 배경/텍스트 (레거시 호환)
  static const Color background = Color(0xFFF8F9FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF4B5563);
  static const Color textHint = Color(0xFF6B7280);

  // 상태 색상
  static const Color profit = Color(0xFFEF4444);
  static const Color loss = Color(0xFF3B82F6);
  static const Color warning = Color(0xFFF59E0B);
  static const Color neutral = Color(0xFF6B7280);

  // 거래 유형
  static const Color weightedBuy = Color(0xFF3B82F6);
  static const Color panicBuy = Color(0xFFEF4444);
  static const Color takeProfit = Color(0xFF10B981);

  // 차트/게이지
  static const Color gaugePositive = Color(0xFFEF4444);
  static const Color gaugeNegative = Color(0xFF3B82F6);
  static const Color gaugeNeutral = Color(0xFFE5E7EB);

  // 지수
  static const Color sp500 = Color(0xFF1A1A2E);
  static const Color nasdaq = Color(0xFF1A1A2E);
  static const Color dowJones = Color(0xFF1A1A2E);

  // 회색 팔레트
  static const Color gray50 = Color(0xFFF9FAFB);
  static const Color gray100 = Color(0xFFF3F4F6);
  static const Color gray200 = Color(0xFFE5E7EB);
  static const Color gray300 = Color(0xFFD1D5DB);
  static const Color gray400 = Color(0xFF9CA3AF);
  static const Color gray500 = Color(0xFF6B7280);
  static const Color gray600 = Color(0xFF4B5563);
  static const Color gray700 = Color(0xFF374151);
  static const Color gray800 = Color(0xFF1F2937);
  static const Color gray900 = Color(0xFF111827);

  // 다크 테마 강조 색상
  static const Color darkAccent = Color(0xFF58A6FF);

  // 블루 팔레트
  static const Color blue50 = Color(0xFFEFF6FF);
  static const Color blue100 = Color(0xFFDBEAFE);
  static const Color blue400 = Color(0xFF60A5FA);
  static const Color blue500 = Color(0xFF5B9CF6);
  static const Color blue600 = Color(0xFF2563EB);
  static const Color blue700 = Color(0xFF1D4ED8);

  // 레드 팔레트
  static const Color red50 = Color(0xFFFEF2F2);
  static const Color red100 = Color(0xFFFEE2E2);
  static const Color red200 = Color(0xFFFECACA);
  static const Color red400 = Color(0xFFF87171);
  static const Color red500 = Color(0xFFF06C6C);
  static const Color red600 = Color(0xFFDC2626);
  static const Color red700 = Color(0xFFB91C1C);

  // 그린 팔레트
  static const Color green50 = Color(0xFFECFDF5);
  static const Color green100 = Color(0xFFD1FAE5);
  static const Color green400 = Color(0xFF34D399);
  static const Color green500 = Color(0xFF10B981);
  static const Color green600 = Color(0xFF059669);
  static const Color green700 = Color(0xFF047857);

  // 앰버 팔레트
  static const Color amber50 = Color(0xFFFFFBEB);
  static const Color amber100 = Color(0xFFFEF3C7);
  static const Color amber400 = Color(0xFFFBBF24);
  static const Color amber500 = Color(0xFFF59E0B);
  static const Color amber600 = Color(0xFFD97706);
  static const Color amber700 = Color(0xFFB45309);

  // 주가 변동 색상
  static const Color stockUp = Color(0xFFEF4444);
  static const Color stockDown = Color(0xFF3B82F6);
  static const Color stockUp50 = Color(0xFFFEF2F2);
  static const Color stockDown50 = Color(0xFFEFF6FF);

  // 거래 액션 색상
  static const Color buyAction = Color(0xFFEF4444);
  static const Color buyAction50 = Color(0xFFFEF2F2);
  static const Color sellAction = Color(0xFF3B82F6);
  static const Color sellAction50 = Color(0xFFEFF6FF);
  static const Color initialBuy = Color(0xFF059669);
  static const Color initialBuy50 = Color(0xFFECFDF5);

  // 다크 테마 정적 색상 (레거시 호환)
  static const Color darkBackground = Color(0xFF0D1117);
  static const Color darkSurface = Color(0xFF161B22);
  static const Color darkCardBackground = Color(0xFF1C2128);
  static const Color darkTextPrimary = Color(0xFFE6EDF3);
  static const Color darkTextSecondary = Color(0xFF8B949E);
  static const Color darkTextHint = Color(0xFF6E7681);
  static const Color darkDivider = Color(0xFF21262D);
  static const Color darkBorder = Color(0xFF30363D);
  static const Color darkIconBg = Color(0xFF21262D);

  // ETF 카테고리 색상
  static const Color etfCategorySemiconductor = Color(0xFF00BCD4);
  static const Color etfCategoryTech = Color(0xFF9C27B0);
  static const Color etfCategoryFangPlus = Color(0xFFFF5722);
  static const Color etfCategoryBio = Color(0xFF4CAF50);
  static const Color etfCategorySmallCap = Color(0xFF795548);
  static const Color etfCategoryHealthcare = Color(0xFFE91E63);

  // 그라데이션 카드 위 수익/손실 텍스트
  static const Color overlayGreen = Color(0xFF4ADE80);
  static const Color overlayRed = Color(0xFFF87171);

  // 캘린더 카테고리 색상 (GitHub Dark 팔레트 호환, 라이트/다크 공용)
  static const Color calendarFomc = Color(0xFFF85149);
  static const Color calendarInflation = Color(0xFFF0883E);
  static const Color calendarEmployment = Color(0xFF3FB950);
  static const Color calendarEarnings = Color(0xFF58A6FF);
  static const Color calendarGdp = Color(0xFFA371F7);
  static const Color calendarHoliday = Color(0xFFDA3633);
  static const Color calendarOther = Color(0xFF8B949E);

  // 다크 주식 배경색
  static const Color darkStockUp50 = Color(0xFF2D1B1B);
  static const Color darkStockDown50 = Color(0xFF1B2333);
  static const Color darkBuyAction50 = Color(0xFF2D1B1B);
  static const Color darkSellAction50 = Color(0xFF1B2333);
  static const Color darkInitialBuy50 = Color(0xFF1B2D22);

  /// 테마 색상 세트 조회
  static ThemeColorSet getThemeColors(AppThemeType type) =>
      _themes[type] ?? _themes[AppThemeType.dark]!;
}

// ═══════════════════════════════════════════════════════════════
// BuildContext 확장 — 현재 테마에 맞는 색상 반환
// ═══════════════════════════════════════════════════════════════

/// 현재 활성 테마를 저장하는 InheritedWidget용 전역 변수
/// (app.dart에서 설정, ThemeAwareColors에서 읽음)
AppThemeType _currentAppTheme = AppThemeType.dark;

void setCurrentAppTheme(AppThemeType type) => _currentAppTheme = type;
AppThemeType getCurrentAppTheme() => _currentAppTheme;

extension ThemeAwareColors on BuildContext {
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;

  ThemeColorSet get _colors => AppColors.getThemeColors(_currentAppTheme);

  // 배경/표면
  Color get appBackground => _colors.background;
  Color get appSurface => _colors.surface;
  Color get appCardBackground => _colors.cardBackground;

  // 텍스트
  Color get appTextPrimary => _colors.textPrimary;
  Color get appTextSecondary => _colors.textSecondary;
  Color get appTextHint => _colors.textHint;

  // UI 요소
  Color get appDivider => _colors.divider;
  Color get appBorder => _colors.border;
  Color get appIconBg => _colors.iconBg;

  // 주식 배경
  Color get appStockUp50 => _colors.stockUp50;
  Color get appStockDown50 => _colors.stockDown50;

  // 티커 심볼
  Color get appTickerColor => _colors.tickerColor;

  // 강조
  Color get appAccent => _colors.accent;

  // 수익/손실 (국제식)
  Color get appReturnProfitBg => _colors.returnProfitBg;
  Color get appReturnProfitFg => _colors.returnProfitFg;
  Color get appReturnLossBg => _colors.returnLossBg;
  Color get appReturnLossFg => _colors.returnLossFg;

  // 주가 변동 (한국식)
  Color get appStockChangePlusBg => _colors.stockChangePlusBg;
  Color get appStockChangePlusFg => _colors.stockChangePlusFg;
  Color get appStockChangeMinusBg => _colors.stockChangeMinusBg;
  Color get appStockChangeMinusFg => _colors.stockChangeMinusFg;

  // 비활성
  Color get appDisabledBackground => _colors.disabledBg;

  // 그라데이션 카드
  Color get appGradientCardStart => _colors.gradientCardStart;
  Color get appGradientCardEnd => _colors.gradientCardEnd;

  // 기간별 수익률 배경
  Color get appPeriodReturnPositiveBg => _colors.periodReturnPositiveBg;
  Color get appPeriodReturnNegativeBg => _colors.periodReturnNegativeBg;

  // 카드 그림자
  List<BoxShadow> get appCardShadow => [
        BoxShadow(
          color: _colors.shadowColor.withValues(alpha: _colors.shadowAlpha),
          blurRadius: 6,
          offset: const Offset(0, 1),
        ),
      ];

  // 재무 지표 판정 색상
  Color get appGoodColor => _colors.goodColor;
  Color get appCautionColor => _colors.cautionColor;
  Color get appWarningColor => _colors.warningColor;
}
