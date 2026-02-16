import 'package:flutter/widgets.dart';

/// 반응형 그리드 유틸리티
///
/// 데스크톱/태블릿에서 2열 그리드 레이아웃을 위한 공통 상수 및 계산 함수
class ResponsiveGrid {
  ResponsiveGrid._();

  /// 2열 그리드 전환 기준 (콘텐츠 영역 너비)
  static const double breakpoint = 700.0;

  /// 그리드 아이템 간 가로 간격
  static const double spacing = 12.0;

  /// 그리드 행 간 세로 간격
  static const double runSpacing = 12.0;

  /// 콘텐츠 좌우 패딩
  static const double horizontalPadding = 16.0;

  /// 현재 콘텐츠 너비에서 그리드 모드 여부 판단
  static bool isGrid(double contentWidth) => contentWidth >= breakpoint;

  /// 2열 그리드에서 각 아이템의 너비 계산
  static double itemWidth(double contentWidth) =>
      (contentWidth - horizontalPadding * 2 - spacing) / 2;

  /// main_shell.dart의 레이아웃 규칙에 맞춰 콘텐츠 영역 너비를 계산합니다.
  /// LayoutBuilder가 NestedScrollView 등에서 올바른 값을 주지 않을 때 사용.
  static double contentWidth(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth >= 1200) {
      // 데스크톱: Extended NavigationRail(220px) + 좌측 정렬 (95%, max 1600)
      final available = screenWidth - 220;
      return (available * 0.95).clamp(0.0, 1600.0);
    }
    if (screenWidth >= 768) {
      // 태블릿: 비율 기반 (화면 폭의 95%, 최대 1100px)
      return (screenWidth * 0.95).clamp(0.0, 1100.0);
    }
    // 모바일: 전체 너비
    return screenWidth;
  }

  /// context 기반 그리드 여부 판단 (MediaQuery 사용)
  static bool shouldUseGrid(BuildContext context) =>
      isGrid(contentWidth(context));

  /// context 기반 아이템 너비 계산 (MediaQuery 사용)
  static double gridItemWidth(BuildContext context) =>
      itemWidth(contentWidth(context));
}
