import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// Zone data model for Fear & Greed segments
class ZoneData {
  final String label;
  final Color accentColor;
  final Color fillColor;
  final int rangeStart;
  final int rangeEnd;
  final String koreanName;
  final String description;

  const ZoneData({
    required this.label,
    required this.accentColor,
    required this.fillColor,
    required this.rangeStart,
    required this.rangeEnd,
    required this.koreanName,
    required this.description,
  });
}

const List<ZoneData> fearGreedZones = [
  ZoneData(
    label: 'EXTREME\nFEAR',
    accentColor: Color(0xFFDC2626),
    fillColor: Color(0xFFFCA5A5),
    rangeStart: 0,
    rangeEnd: 25,
    koreanName: '극도의 공포',
    description: '패닉 매도 가능, 역발상 매수 기회',
  ),
  ZoneData(
    label: 'FEAR',
    accentColor: Color(0xFFF97316),
    fillColor: Color(0xFFFDBA74),
    rangeStart: 25,
    rangeEnd: 44,
    koreanName: '공포',
    description: '투자자 불안 증가, 하락 압력 주의',
  ),
  ZoneData(
    label: 'NEUTRAL',
    accentColor: Color(0xFFEAB308),
    fillColor: Color(0xFFFDE047),
    rangeStart: 44,
    rangeEnd: 56,
    koreanName: '중립',
    description: '시장 균형 상태, 방향성 탐색 중',
  ),
  ZoneData(
    label: 'GREED',
    accentColor: Color(0xFF84CC16),
    fillColor: Color(0xFFBEF264),
    rangeStart: 56,
    rangeEnd: 75,
    koreanName: '탐욕',
    description: '투자 심리 양호, 상승 모멘텀',
  ),
  ZoneData(
    label: 'EXTREME\nGREED',
    accentColor: Color(0xFF22C55E),
    fillColor: Color(0xFF86EFAC),
    rangeStart: 75,
    rangeEnd: 100,
    koreanName: '극도의 탐욕',
    description: '과열 경고, 조정 가능성 높음',
  ),
];

/// Determine which zone index (0-4) a value falls into
int getActiveZoneIndex(int value) {
  if (value < 25) return 0;
  if (value < 44) return 1;
  if (value < 56) return 2;
  if (value < 75) return 3;
  return 4;
}

/// Panel showing intro text + all 5 zone descriptions (single-line each)
class ZoneDescriptionPanel extends StatelessWidget {
  final int value;

  const ZoneDescriptionPanel({super.key, required this.value});

  @override
  Widget build(BuildContext context) {
    final activeZone = getActiveZoneIndex(value);
    final screenWidth = MediaQuery.of(context).size.width;
    final fs = 0.92 + ((screenWidth - 320) / 1080).clamp(0.0, 1.0) * 0.43;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Intro description
        Text(
          'S&P 500 옵션 시장 기반 시장 심리 종합 지표. '
          'VIX, 모멘텀, 풋/콜 비율 등 7개 지표를 종합하여 '
          '투자자들의 공포·탐욕 수준을 0~100으로 나타냅니다.',
          style: TextStyle(
            fontSize: 13 * fs,
            color: context.appTextSecondary,
            height: 1.4,
          ),
        ),
        SizedBox(height: 10 * fs),
        // Zone items (single-line each)
        for (int i = 0; i < fearGreedZones.length; i++) ...[
          _ZoneDescriptionItem(
            zone: fearGreedZones[i],
            isActive: i == activeZone,
          ),
          if (i < fearGreedZones.length - 1) SizedBox(height: 4 * fs),
        ],
      ],
    );
  }
}

/// Single-line zone description: [bar] dot · name · range · description
class _ZoneDescriptionItem extends StatelessWidget {
  final ZoneData zone;
  final bool isActive;

  const _ZoneDescriptionItem({
    required this.zone,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final screenWidth = MediaQuery.of(context).size.width;
    final fs = 0.92 + ((screenWidth - 320) / 1080).clamp(0.0, 1.0) * 0.43;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: isActive
            ? zone.accentColor.withValues(alpha: isDark ? 0.15 : 0.08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            // Left accent bar
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              width: isActive ? 3 * fs : 0,
              decoration: BoxDecoration(
                color: zone.accentColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(6),
                  bottomLeft: Radius.circular(6),
                ),
              ),
            ),
            // Single-line content
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 8 * fs, vertical: 6 * fs),
                child: Row(
                  children: [
                    // Color dot
                    Container(
                      width: 8 * fs,
                      height: 8 * fs,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isActive
                            ? zone.accentColor
                            : zone.accentColor.withValues(alpha: 0.35),
                      ),
                    ),
                    SizedBox(width: 6 * fs),
                    // Zone name
                    Text(
                      zone.koreanName,
                      style: TextStyle(
                        fontSize: 13 * fs,
                        fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                        color: isActive
                            ? context.appTextPrimary
                            : context.appTextHint,
                      ),
                    ),
                    SizedBox(width: 5 * fs),
                    // Range badge
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 4 * fs,
                        vertical: 1 * fs,
                      ),
                      decoration: BoxDecoration(
                        color: isActive
                            ? zone.accentColor.withValues(alpha: isDark ? 0.25 : 0.12)
                            : context.appIconBg,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        '${zone.rangeStart}-${zone.rangeEnd}',
                        style: TextStyle(
                          fontSize: 10 * fs,
                          fontWeight: FontWeight.w500,
                          color: isActive
                              ? zone.accentColor
                              : context.appTextHint,
                        ),
                      ),
                    ),
                    SizedBox(width: 6 * fs),
                    // Description (fills remaining space)
                    Expanded(
                      child: Text(
                        zone.description,
                        style: TextStyle(
                          fontSize: 12 * fs,
                          color: isActive
                              ? context.appTextSecondary
                              : context.appTextHint.withValues(alpha: isDark ? 0.45 : 0.55),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
