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

  const FearGreedCard({
    super.key,
    required this.value,
    this.isLoading = false,
    this.error,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clampedValue = value.clamp(0, 100);
    final screenWidth = MediaQuery.of(context).size.width;
    // Smooth linear scale: 320px→0.92, 1400px→1.35 (no jumps)
    final fs = 0.92 + ((screenWidth - 320) / 1080).clamp(0.0, 1.0) * 0.43;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
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
            // Title row
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
                const Spacer(),
                // Alert bell icon
                GestureDetector(
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
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
            SizedBox(height: 12 * fs),

            // Inline alert status chip
            if (ref.watch(settingsProvider).fearGreedAlertEnabled) ...[
              Builder(builder: (context) {
                final accentColor = context.appAccent;
                return Container(
                  margin: EdgeInsets.only(bottom: 8 * fs),
                  padding: EdgeInsets.symmetric(horizontal: 10 * fs, vertical: 5 * fs),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: accentColor.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.notifications_active_rounded,
                        size: 13 * fs,
                        color: accentColor,
                      ),
                      SizedBox(width: 6 * fs),
                      Text(
                        '${ref.watch(settingsProvider).fearGreedAlertValue} '
                        '${AlertDirection.fromFearGreedInt(ref.watch(settingsProvider).fearGreedAlertDirection).label} 알림',
                        style: TextStyle(
                          fontSize: 12 * fs,
                          fontWeight: FontWeight.w500,
                          color: accentColor,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],

            // Gauge + Zone descriptions (responsive layout)
            if (error != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
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
              LayoutBuilder(
                builder: (context, constraints) {
                  final useRowLayout = constraints.maxWidth >= 600;
                  final gauge = FearGreedGauge(
                    value: clampedValue,
                    isLoading: isLoading,
                    cardBackgroundColor: context.appCardBackground,
                    textColor: context.appTextPrimary,
                    isDarkMode: context.isDarkMode,
                  );
                  final descriptions = ZoneDescriptionPanel(
                    value: clampedValue,
                  );

                  if (useRowLayout) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(flex: 5, child: gauge),
                        const SizedBox(width: 16),
                        Expanded(flex: 5, child: descriptions),
                      ],
                    );
                  }

                  return Column(
                    children: [
                      gauge,
                      const SizedBox(height: 16),
                      descriptions,
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
