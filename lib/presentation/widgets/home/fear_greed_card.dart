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
              _wrapContent(
                useExpanded: !useOuterMargin,
                child: Center(
                  child: Text(
                    error!,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.appTextSecondary,
                    ),
                  ),
                ),
              )
            else
              _wrapContent(
                useExpanded: !useOuterMargin,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 600;
                    final activeZoneIdx = getActiveZoneIndex(clampedValue);
                    final activeZone = fearGreedZones[activeZoneIdx];

                    if (isWide) {
                      // Wide layout: gauge left, zone description panel right
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            flex: 3,
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
                                  ),
                                  SizedBox(height: 8 * fs),
                                  _ActiveZoneLabel(
                                    zone: activeZone,
                                    fs: fs,
                                    showInfoIcon: false,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(width: 16 * fs),
                          Expanded(
                            flex: 2,
                            child: ZoneDescriptionPanel(value: clampedValue),
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
              ),
          ],
        ),
      ),
    );
  }

  /// 데스크톱(고정높이)에서는 Expanded, 모바일에서는 그대로
  static Widget _wrapContent({required bool useExpanded, required Widget child}) {
    return useExpanded ? Expanded(child: child) : child;
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
