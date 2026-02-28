import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/services/technical_indicator_service.dart';

/// 기간 선택기 (일봉/주봉/월봉)
class ChartPeriodSelector extends StatelessWidget {
  final String selectedPeriod;
  final ValueChanged<String> onPeriodChanged;

  const ChartPeriodSelector({
    super.key,
    required this.selectedPeriod,
    required this.onPeriodChanged,
  });

  @override
  Widget build(BuildContext context) {
    const periods = ['일봉', '주봉', '월봉'];
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: context.appIconBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: periods.map((period) {
          final isSelected = period == selectedPeriod;
          return GestureDetector(
            onTap: () => onPeriodChanged(period),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected ? context.appSurface.withValues(alpha: 0.5) : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                boxShadow: isSelected
                    ? [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 4, offset: const Offset(0, 1))]
                    : null,
              ),
              child: Text(
                period,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? context.appTextPrimary : context.appTextHint,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// 보조지표 선택 칩 목록
class IndicatorChips extends StatelessWidget {
  final Set<String> activeIndicators;
  final ValueChanged<String> onToggle;
  final ValueChanged<String> onHelpTap;

  const IndicatorChips({
    super.key,
    required this.activeIndicators,
    required this.onToggle,
    required this.onHelpTap,
  });

  @override
  Widget build(BuildContext context) {
    const indicators = [
      {'key': 'VOL', 'label': 'VOL'},
      {'key': 'BB', 'label': 'BB'},
      {'key': 'RSI', 'label': 'RSI'},
      {'key': 'MACD', 'label': 'MACD'},
      {'key': 'STOCH', 'label': 'STOCH'},
      {'key': 'ICH', 'label': '일목'},
      {'key': 'OBV', 'label': 'OBV'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: indicators.map((ind) {
          final key = ind['key']!;
          final label = ind['label']!;
          final isActive = activeIndicators.contains(key);

          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: GestureDetector(
              onTap: () => onToggle(key),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isActive ? context.appSurface : context.appIconBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isActive ? context.appBorder : context.appDivider,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                        color: isActive ? context.appTextPrimary : context.appTextHint,
                      ),
                    ),
                    const SizedBox(width: 3),
                    GestureDetector(
                      onTap: () => onHelpTap(key),
                      child: Icon(Icons.help_outline, size: 14, color: context.appTextHint),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// MA 범례 아이템
class LegendItem extends StatelessWidget {
  final String label;
  final Color color;
  /// 라이트 모드에서 텍스트에 사용할 진한 색상 (차트 선은 원래 color 사용)
  final Color? darkColor;

  const LegendItem({super.key, required this.label, required this.color, this.darkColor});

  @override
  Widget build(BuildContext context) {
    final textColor = context.isDarkMode ? color : (darkColor ?? color);
    return Padding(
      padding: const EdgeInsets.only(left: 4, right: 1),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8, height: 2, color: color),
          const SizedBox(width: 2),
          Text(label, style: TextStyle(fontSize: 10, color: textColor, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// 서브차트 헤더 (라벨 + 신호배지)
class SubChartHeader extends StatelessWidget {
  final String label;
  final Color labelColor;
  final IndicatorSignal? signal;

  const SubChartHeader({
    super.key,
    required this.label,
    required this.labelColor,
    this.signal,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final fontSize = isMobile ? 11.0 : 13.0;
    return Padding(
      padding: EdgeInsets.only(top: isMobile ? 4 : 6, bottom: 2),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(color: labelColor, fontSize: fontSize, fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          if (signal != null)
            SizedBox(
              width: 50,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: SignalBadge(signal: signal!),
              ),
            ),
        ],
      ),
    );
  }
}

/// 신호 배지 위젯 (강매수/매수/중립/매도/강매도)
class SignalBadge extends StatelessWidget {
  final IndicatorSignal signal;

  const SignalBadge({super.key, required this.signal});

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color fgColor;
    switch (signal.type) {
      case SignalType.strongBuy:
        bgColor = AppColors.stockUp.withAlpha(40);
        fgColor = AppColors.stockUp;
        break;
      case SignalType.buy:
        bgColor = AppColors.stockUp.withAlpha(25);
        fgColor = AppColors.stockUp;
        break;
      case SignalType.neutral:
        bgColor = context.appIconBg;
        fgColor = context.appTextHint;
        break;
      case SignalType.sell:
        bgColor = AppColors.stockDown.withAlpha(25);
        fgColor = AppColors.stockDown;
        break;
      case SignalType.strongSell:
        bgColor = AppColors.stockDown.withAlpha(40);
        fgColor = AppColors.stockDown;
        break;
    }
    final isMobile = MediaQuery.of(context).size.width < 600;
    final fontSize = isMobile ? 10.0 : 12.0;
    final hPad = isMobile ? 5.0 : 8.0;
    final vPad = isMobile ? 2.0 : 3.0;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        signal.label,
        style: TextStyle(color: fgColor, fontSize: fontSize, fontWeight: FontWeight.w700),
      ),
    );
  }
}
