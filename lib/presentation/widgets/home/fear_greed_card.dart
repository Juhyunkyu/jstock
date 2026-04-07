import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/alert_direction.dart';
import '../../../core/theme/app_colors.dart';
import '../../providers/settings_providers.dart';
import 'fear_greed_alert_sheet.dart';
import 'fear_greed_gauge_painter.dart';
import 'fear_greed_zone_panel.dart';

/// CNN-style Fear & Greed Index gauge card
class FearGreedCard extends ConsumerWidget {
  final int value;
  final bool isLoading;
  final String? error;
  final VoidCallback? onRefresh;
  final bool useOuterMargin;

  const FearGreedCard({
    super.key,
    required this.value,
    this.isLoading = false,
    this.error,
    this.onRefresh,
    this.useOuterMargin = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clampedValue = value.clamp(0, 100);
    final screenWidth = MediaQuery.sizeOf(context).width;
    // Smooth linear scale: 320px→0.92, 1400px→1.35 (no jumps)
    final fs = 0.92 + ((screenWidth - 320) / 1080).clamp(0.0, 1.0) * 0.43;

    return Container(
      margin: useOuterMargin ? const EdgeInsets.symmetric(horizontal: 16) : EdgeInsets.zero,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: context.appCardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.appBorder),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(14 * fs, 12 * fs, 14 * fs, 10 * fs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title row: Fear & Greed Index [CNN] [알림칩] ... 🔔 ↻
            Row(
              children: [
                Text(
                  'Fear & Greed Index',
                  style: TextStyle(
                    fontSize: 14 * fs,
                    fontWeight: FontWeight.w600,
                    color: context.appTextPrimary,
                  ),
                ),
                SizedBox(width: 8 * fs),
                Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 6 * fs, vertical: 2 * fs),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'CNN',
                    style: TextStyle(
                      fontSize: 9 * fs,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                // 알림 칩 (CNN 뱃지 옆, 인라인)
                if (ref.watch(settingsProvider).fearGreedAlertEnabled) ...[
                  SizedBox(width: 8 * fs),
                  Builder(builder: (context) {
                    final accentColor = context.appAccent;
                    return GestureDetector(
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          useRootNavigator: true,
                          isScrollControlled: true,
                          backgroundColor: context.appCardBackground,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                          ),
                          builder: (_) => FearGreedAlertSheet(currentValue: clampedValue),
                        );
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 8 * fs, vertical: 3 * fs),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: accentColor.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.notifications_active_rounded,
                              size: 11 * fs,
                              color: accentColor,
                            ),
                            SizedBox(width: 4 * fs),
                            Text(
                              '${ref.watch(settingsProvider).fearGreedAlertValue} '
                              '${AlertDirection.fromFearGreedInt(ref.watch(settingsProvider).fearGreedAlertDirection).label} 알림',
                              style: TextStyle(
                                fontSize: 10 * fs,
                                fontWeight: FontWeight.w500,
                                color: accentColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
                const Spacer(),
                // Alert bell icon
                GestureDetector(
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      useRootNavigator: true,
                      isScrollControlled: true,
                      backgroundColor: context.appCardBackground,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                      ),
                      builder: (_) => FearGreedAlertSheet(currentValue: clampedValue),
                    );
                  },
                  child: Padding(
                    padding: EdgeInsets.only(right: 8 * fs),
                    child: Icon(
                      ref.watch(settingsProvider).fearGreedAlertEnabled
                          ? Icons.notifications_active_rounded
                          : Icons.notifications_outlined,
                      size: 16 * fs,
                      color: ref.watch(settingsProvider).fearGreedAlertEnabled
                          ? context.appAccent
                          : context.appTextHint,
                    ),
                  ),
                ),
                if (isLoading)
                  SizedBox(
                    width: 14 * fs,
                    height: 14 * fs,
                    child: const CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: Color(0xFF9CA3AF),
                    ),
                  )
                else if (onRefresh != null)
                  GestureDetector(
                    onTap: onRefresh,
                    child: Icon(
                      Icons.refresh_rounded,
                      size: 16 * fs,
                      color: context.appTextHint,
                    ),
                  ),
              ],
            ),
            SizedBox(height: useOuterMargin ? 4 * fs : 2 * fs),

            // Gauge + Active zone (responsive layout)
            if (error != null)
              Center(
                child: Text(
                  error!,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.appTextSecondary,
                  ),
                ),
              )
            else
              LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 600;
                    final activeZoneIdx = getActiveZoneIndex(clampedValue);
                    final activeZone = fearGreedZones[activeZoneIdx];

                    if (isWide) {
                      // Wide layout: gauge left, compact zone list right
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            flex: 4,
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  FearGreedGauge(
                                    value: clampedValue,
                                    isLoading: isLoading,
                                    cardBackgroundColor: context.appCardBackground,
                                    textColor: context.appTextPrimary,
                                    isDarkMode: context.isDarkMode,
                                    borderThemeColor: context.appBorder,
                                    dividerThemeColor: context.appDivider,
                                    iconBgThemeColor: context.appIconBg,
                                    textPrimaryThemeColor: context.appTextPrimary,
                                    textSecondaryThemeColor: context.appTextSecondary,
                                  ),
                                  // 와이드: 극도의 공포 라벨 제거 (오른쪽 목록과 중복)
                                ],
                              ),
                            ),
                          ),
                          SizedBox(width: 12 * fs),
                          Expanded(
                            flex: 2,
                            child: _CompactZoneList(
                              value: clampedValue,
                              fs: fs,
                            ),
                          ),
                        ],
                      );
                    }

                    // Narrow layout: vertical stack (unchanged)
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FearGreedGauge(
                            value: clampedValue,
                            isLoading: isLoading,
                            cardBackgroundColor: context.appCardBackground,
                            textColor: context.appTextPrimary,
                            isDarkMode: context.isDarkMode,
                            borderThemeColor: context.appBorder,
                            dividerThemeColor: context.appDivider,
                            iconBgThemeColor: context.appIconBg,
                            textPrimaryThemeColor: context.appTextPrimary,
                            textSecondaryThemeColor: context.appTextSecondary,
                          ),
                          SizedBox(height: 8 * fs),
                          _ActiveZoneLabel(
                            zone: activeZone,
                            fs: fs,
                          ),
                        ],
                      ),
                    );
                  },
                ),
          ],
        ),
      ),
    );
  }
}

/// 현재 활성 단계 라벨 + ⓘ 툴팁
class _ActiveZoneLabel extends StatelessWidget {
  final ZoneData zone;
  final double fs;
  final bool showInfoIcon;

  const _ActiveZoneLabel({
    required this.zone,
    required this.fs,
    this.showInfoIcon = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8 * fs, vertical: 4 * fs),
      decoration: BoxDecoration(
        color: zone.accentColor.withValues(alpha: isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6 * fs,
            height: 6 * fs,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: zone.accentColor,
            ),
          ),
          SizedBox(width: 6 * fs),
          Text(
            zone.koreanName,
            style: TextStyle(
              fontSize: 11 * fs,
              fontWeight: FontWeight.w600,
              color: context.appTextPrimary,
            ),
          ),
          if (showInfoIcon) ...[
            SizedBox(width: 6 * fs),
            GestureDetector(
              onTap: () => _showAllZones(context),
              child: Icon(
                Icons.info_outline_rounded,
                size: 12 * fs,
                color: context.appTextHint,
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showAllZones(BuildContext context) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: context.appCardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Fear & Greed 단계 설명',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: context.appTextPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'S&P 500 옵션 시장 기반 시장 심리 종합 지표. '
              'VIX, 모멘텀, 풋/콜 비율 등 7개 지표를 종합하여 '
              '투자자들의 공포·탐욕 수준을 0~100으로 나타냅니다.',
              style: TextStyle(
                fontSize: 13,
                color: context.appTextSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            for (final z in fearGreedZones) ...[
              _ZoneInfoRow(zone: z),
              const SizedBox(height: 6),
            ],
          ],
        ),
      ),
    );
  }
}

/// 와이드 레이아웃 전용 — 간결한 Zone 목록 (이름 + 범위만)
/// ⓘ 아이콘 상단, 게이지와 높이 맞춤
class _CompactZoneList extends StatelessWidget {
  final int value;
  final double fs;

  const _CompactZoneList({required this.value, required this.fs});

  @override
  Widget build(BuildContext context) {
    final activeIdx = getActiveZoneIndex(value);
    final isDark = context.isDarkMode;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ⓘ 아이콘 (탭하면 상세 설명)
        GestureDetector(
          onTap: () => _showAllZones(context),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Icon(
              Icons.info_outline_rounded,
              size: 16,
              color: context.appTextHint,
            ),
          ),
        ),
        // 5단계 목록
        for (int i = 0; i < fearGreedZones.length; i++) ...[
          _CompactZoneRow(
            zone: fearGreedZones[i],
            isActive: i == activeIdx,
            isDark: isDark,
          ),
          if (i < fearGreedZones.length - 1) const SizedBox(height: 4),
        ],
      ],
    );
  }

  void _showAllZones(BuildContext context) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: context.appCardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Fear & Greed 단계 설명',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: context.appTextPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'S&P 500 옵션 시장 기반 시장 심리 종합 지표. '
              'VIX, 모멘텀, 풋/콜 비율 등 7개 지표를 종합하여 '
              '투자자들의 공포·탐욕 수준을 0~100으로 나타냅니다.',
              style: TextStyle(
                fontSize: 13,
                color: context.appTextSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            for (final z in fearGreedZones) ...[
              _ZoneInfoRow(zone: z),
              const SizedBox(height: 6),
            ],
          ],
        ),
      ),
    );
  }
}

/// 간결한 Zone 행 (이름 + 범위만, 설명 없음)
class _CompactZoneRow extends StatelessWidget {
  final ZoneData zone;
  final bool isActive;
  final bool isDark;

  const _CompactZoneRow({
    required this.zone,
    required this.isActive,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: isActive
                ? zone.accentColor.withValues(alpha: isDark ? 0.15 : 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 색상 원
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isActive
                      ? zone.accentColor
                      : zone.accentColor.withValues(alpha: 0.35),
                ),
              ),
              const SizedBox(width: 8),
              // 이름 (고정 폭으로 수직 정렬)
              SizedBox(
                width: 90,
                child: Text(
                  zone.koreanName,
                  style: TextStyle(
                    fontSize: isActive ? 15 : 13,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    color: isActive
                        ? context.appTextPrimary
                        : context.appTextHint,
                  ),
                ),
              ),
              // 범위 뱃지 (수직 정렬됨)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: isActive
                      ? zone.accentColor.withValues(alpha: isDark ? 0.25 : 0.12)
                      : context.appIconBg,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${zone.rangeStart}-${zone.rangeEnd}',
                  style: TextStyle(
                    fontSize: isActive ? 12 : 11,
                    fontWeight: FontWeight.w500,
                    color: isActive
                        ? zone.accentColor
                        : context.appTextHint,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// ⓘ 바텀시트 내 단계별 설명 행
class _ZoneInfoRow extends StatelessWidget {
  final ZoneData zone;

  const _ZoneInfoRow({required this.zone});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: zone.accentColor,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          zone.koreanName,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: context.appTextPrimary,
          ),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          decoration: BoxDecoration(
            color: context.appIconBg,
            borderRadius: BorderRadius.circular(3),
          ),
          child: Text(
            '${zone.rangeStart}-${zone.rangeEnd}',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: context.appTextHint,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            zone.description,
            style: TextStyle(
              fontSize: 12,
              color: context.appTextSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
