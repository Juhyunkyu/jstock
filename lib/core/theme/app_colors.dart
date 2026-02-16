import 'package:flutter/material.dart';

/// 앱 색상 팔레트 - 미니멀 & 모던 디자인
class AppColors {
  AppColors._();

  // 기본 색상 - 깔끔한 다크 블루
  static const Color primary = Color(0xFF1A1A2E); // 다크 네이비
  static const Color primaryDark = Color(0xFF0F0F1A);
  static const Color primaryLight = Color(0xFF2D2D44);

  // 보조 색상 - 차분한 그레이
  static const Color secondary = Color(0xFF4A4A5A);
  static const Color secondaryDark = Color(0xFF3A3A4A);
  static const Color secondaryLight = Color(0xFF6A6A7A);

  // 배경 색상 - 밝은 톤
  static const Color background = Color(0xFFF8F9FA);
  static const Color surface = Colors.white;
  static const Color cardBackground = Colors.white;

  // 텍스트 색상
  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textHint = Color(0xFF9CA3AF);

  // 상태 색상 - 한국 주식 스타일 (상승: 빨강, 하락: 파랑)
  static const Color profit = Color(0xFFEF4444); // 상승 - 레드
  static const Color loss = Color(0xFF3B82F6); // 하락 - 블루
  static const Color warning = Color(0xFFF59E0B); // 앰버
  static const Color neutral = Color(0xFF6B7280); // 그레이

  // 거래 유형별 색상 - 통일된 톤
  static const Color weightedBuy = Color(0xFF3B82F6); // 블루
  static const Color panicBuy = Color(0xFFEF4444); // 레드
  static const Color takeProfit = Color(0xFF10B981); // 민트

  // 차트/게이지 색상 - 한국 스타일
  static const Color gaugePositive = Color(0xFFEF4444); // 상승 - 레드
  static const Color gaugeNegative = Color(0xFF3B82F6); // 하락 - 블루
  static const Color gaugeNeutral = Color(0xFFE5E7EB);

  // 지수별 색상 - 동일한 톤 사용
  static const Color sp500 = Color(0xFF1A1A2E);
  static const Color nasdaq = Color(0xFF1A1A2E);
  static const Color dowJones = Color(0xFF1A1A2E);

  // 회색 팔레트 - Tailwind 스타일
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

  // 블루 팔레트 - 억제된 톤
  static const Color blue50 = Color(0xFFEFF6FF);
  static const Color blue100 = Color(0xFFDBEAFE);
  static const Color blue400 = Color(0xFF60A5FA);
  static const Color blue500 = Color(0xFF3B82F6);
  static const Color blue600 = Color(0xFF2563EB);
  static const Color blue700 = Color(0xFF1D4ED8);

  // 레드 팔레트
  static const Color red50 = Color(0xFFFEF2F2);
  static const Color red100 = Color(0xFFFEE2E2);
  static const Color red200 = Color(0xFFFECACA);
  static const Color red400 = Color(0xFFF87171);
  static const Color red500 = Color(0xFFEF4444);
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

  // 주가 변동 색상 - 한국 스타일 (상승: 빨강, 하락: 파랑)
  static const Color stockUp = Color(0xFFEF4444); // 상승 - 레드
  static const Color stockDown = Color(0xFF3B82F6); // 하락 - 블루
  static const Color stockUp50 = Color(0xFFFEF2F2); // 상승 배경
  static const Color stockDown50 = Color(0xFFEFF6FF); // 하락 배경

  // 거래 액션 색상 - 한국 주식시장 스타일
  static const Color buyAction = Color(0xFFEF4444); // 매수 - 빨강 (상승 색상)
  static const Color buyAction50 = Color(0xFFFEF2F2); // 매수 배경
  static const Color sellAction = Color(0xFF3B82F6); // 매도 - 파랑 (하락 색상)
  static const Color sellAction50 = Color(0xFFEFF6FF); // 매도 배경

  // 첫매수 특별 색상 - 에메랄드 그린 (특별한 첫 거래 강조)
  static const Color initialBuy = Color(0xFF059669); // 첫매수 - 에메랄드
  static const Color initialBuy50 = Color(0xFFECFDF5); // 첫매수 배경

  // ═══════════════════════════════════════════════════════════════
  // 다크 테마 색상 (GitHub Dark 영감)
  // ═══════════════════════════════════════════════════════════════

  static const Color darkBackground = Color(0xFF0D1117);
  static const Color darkSurface = Color(0xFF161B22);
  static const Color darkCardBackground = Color(0xFF1C2128);
  static const Color darkTextPrimary = Color(0xFFE6EDF3);
  static const Color darkTextSecondary = Color(0xFF8B949E);
  static const Color darkTextHint = Color(0xFF6E7681);
  static const Color darkDivider = Color(0xFF21262D);
  static const Color darkBorder = Color(0xFF30363D);
  static const Color darkIconBg = Color(0xFF21262D);

  // 다크 주식 배경색
  static const Color darkStockUp50 = Color(0xFF2D1B1B);
  static const Color darkStockDown50 = Color(0xFF1B2333);
  static const Color darkBuyAction50 = Color(0xFF2D1B1B);
  static const Color darkSellAction50 = Color(0xFF1B2333);
  static const Color darkInitialBuy50 = Color(0xFF1B2D22);
}

/// BuildContext 확장 - 현재 테마에 맞는 색상 반환
extension ThemeAwareColors on BuildContext {
  bool get isDarkMode =>
      Theme.of(this).brightness == Brightness.dark;

  // 배경/표면
  Color get appBackground =>
      isDarkMode ? AppColors.darkBackground : AppColors.background;
  Color get appSurface =>
      isDarkMode ? AppColors.darkSurface : AppColors.surface;
  Color get appCardBackground =>
      isDarkMode ? AppColors.darkCardBackground : AppColors.cardBackground;

  // 텍스트
  Color get appTextPrimary =>
      isDarkMode ? AppColors.darkTextPrimary : AppColors.textPrimary;
  Color get appTextSecondary =>
      isDarkMode ? AppColors.darkTextSecondary : AppColors.textSecondary;
  Color get appTextHint =>
      isDarkMode ? AppColors.darkTextHint : AppColors.textHint;

  // UI 요소
  Color get appDivider =>
      isDarkMode ? AppColors.darkDivider : AppColors.gray200;
  Color get appBorder =>
      isDarkMode ? AppColors.darkBorder : AppColors.gray300;
  Color get appIconBg =>
      isDarkMode ? AppColors.darkIconBg : AppColors.gray100;

  // 주식 배경
  Color get appStockUp50 =>
      isDarkMode ? AppColors.darkStockUp50 : AppColors.stockUp50;
  Color get appStockDown50 =>
      isDarkMode ? AppColors.darkStockDown50 : AppColors.stockDown50;

  // 티커 심볼 (배지 텍스트 + 배경에 공통 사용)
  Color get appTickerColor =>
      isDarkMode ? AppColors.darkTextPrimary : AppColors.primary;

  // 강조 색상 (다크: darkAccent, 라이트: primary)
  Color get appAccent =>
      isDarkMode ? AppColors.darkAccent : AppColors.primary;

  // ═══════════════════════════════════════════════════════════════
  // ReturnBadge 색상 — greenRed (포트폴리오 수익률, 국제식)
  // ═══════════════════════════════════════════════════════════════
  Color get appReturnProfitBg =>
      isDarkMode ? AppColors.green600.withValues(alpha: 0.15) : AppColors.green100;
  Color get appReturnProfitFg =>
      isDarkMode ? const Color(0xFF51CF66) : AppColors.green600;
  Color get appReturnLossBg =>
      isDarkMode ? AppColors.red600.withValues(alpha: 0.15) : AppColors.red100;
  Color get appReturnLossFg =>
      isDarkMode ? const Color(0xFFFF6B6B) : AppColors.red600;

  // ═══════════════════════════════════════════════════════════════
  // ReturnBadge 색상 — redBlue (주가 변동률, 한국식)
  // ═══════════════════════════════════════════════════════════════
  Color get appStockChangePlusBg =>
      isDarkMode ? AppColors.red600.withValues(alpha: 0.15) : AppColors.red100;
  Color get appStockChangePlusFg =>
      isDarkMode ? const Color(0xFFFF6B6B) : AppColors.red500;
  Color get appStockChangeMinusBg =>
      isDarkMode ? AppColors.blue600.withValues(alpha: 0.15) : AppColors.blue100;
  Color get appStockChangeMinusFg =>
      isDarkMode ? AppColors.blue400 : AppColors.blue500;
}
