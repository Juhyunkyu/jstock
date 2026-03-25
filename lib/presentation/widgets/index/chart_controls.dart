import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/services/technical_indicator_service.dart';

// ─────────────────────────────────────────────────────────────
// 반응형 차트 높이 (화면 폭 breakpoint 기반)
// ─────────────────────────────────────────────────────────────

class ChartSizes {
  final double main;
  final double vol;
  final double rsi;
  final double macd;
  final double stoch;
  final double obv;
  final double mfi;

  const ChartSizes._({
    required this.main,
    required this.vol,
    required this.rsi,
    required this.macd,
    required this.stoch,
    required this.obv,
    required this.mfi,
  });

  /// 화면 폭 기준 차트 높이 계산
  factory ChartSizes.fromWidth(double screenWidth) {
    if (screenWidth >= 1200) {
      return const ChartSizes._(main: 450, vol: 65, rsi: 160, macd: 140, stoch: 140, obv: 110, mfi: 160);
    } else if (screenWidth >= 768) {
      return const ChartSizes._(main: 380, vol: 55, rsi: 140, macd: 120, stoch: 120, obv: 90, mfi: 140);
    } else {
      // 모바일: 3개 서브차트가 한 화면에 보이도록 컴팩트하게
      return const ChartSizes._(main: 300, vol: 40, rsi: 90, macd: 80, stoch: 80, obv: 60, mfi: 90);
    }
  }
}

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
    final isDesktop = MediaQuery.sizeOf(context).width >= 768;
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
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 10 : 8,
                vertical: isDesktop ? 5 : 4,
              ),
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
                  fontSize: isDesktop ? 13.0 : 11.0,
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

  const IndicatorChips({
    super.key,
    required this.activeIndicators,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 768;
    const indicators = [
      {'key': 'VOL', 'label': 'VOL'},
      {'key': 'BB', 'label': 'BB'},
      {'key': 'RSI', 'label': 'RSI'},
      {'key': 'MACD', 'label': 'MACD'},
      {'key': 'STOCH', 'label': 'STOCH'},
      {'key': 'ICH', 'label': '일목'},
      {'key': 'OBV', 'label': 'OBV'},
      {'key': 'MFI', 'label': 'MFI'},
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
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 12 : 10,
                  vertical: isDesktop ? 6 : 5,
                ),
                decoration: BoxDecoration(
                  color: isActive ? context.appSurface : context.appIconBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isActive ? context.appBorder : context.appDivider,
                    width: 1,
                  ),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: isDesktop ? 13.0 : 11.0,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                    color: isActive ? context.appTextPrimary : context.appTextHint,
                  ),
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
    final isDesktop = MediaQuery.sizeOf(context).width >= 768;
    final textColor = context.isDarkMode ? color : (darkColor ?? color);
    return Padding(
      padding: const EdgeInsets.only(left: 4, right: 1),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8, height: 2, color: color),
          const SizedBox(width: 2),
          Text(label, style: TextStyle(fontSize: isDesktop ? 11.0 : 10.0, color: textColor, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// 서브차트 헤더 (라벨 + 설명아이콘 + 신호배지)
class SubChartHeader extends StatelessWidget {
  final String label;
  final Color labelColor;
  final IndicatorSignal? signal;
  final String? indicatorKey; // 도움말 다이얼로그용
  final ValueChanged<String>? onHelpTap;

  const SubChartHeader({
    super.key,
    required this.label,
    required this.labelColor,
    this.signal,
    this.indicatorKey,
    this.onHelpTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 768;
    final fontSize = isDesktop ? 13.0 : 11.0;
    return Padding(
      padding: EdgeInsets.only(top: isDesktop ? 6 : 2, bottom: isDesktop ? 2 : 0),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(color: labelColor, fontSize: fontSize, fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          // 설명 아이콘 (? — 신호배지 왼쪽 고정)
          if (indicatorKey != null && onHelpTap != null)
            GestureDetector(
              onTap: () => onHelpTap!(indicatorKey!),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Icon(
                  Icons.help_outline,
                  size: isDesktop ? 14 : 12,
                  color: context.appTextHint.withAlpha(150),
                ),
              ),
            ),
          // 신호 배지 (없어도 60px 공간 예약 → ? 수직 정렬 유지)
          SizedBox(
            width: 60,
            child: signal != null
                ? FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: SignalBadge(signal: signal!),
                  )
                : null,
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
    final isMobile = MediaQuery.sizeOf(context).width < 600;
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
