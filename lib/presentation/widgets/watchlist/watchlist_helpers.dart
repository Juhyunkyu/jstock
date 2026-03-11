import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../providers/stock_providers.dart';

/// 종목 타입별 색상
Color getTypeColor(String type) {
  switch (type) {
    case 'ETF':
      return AppColors.blue500;
    case 'INDEX':
      return AppColors.amber500;
    default:
      return AppColors.green500;
  }
}

/// 거래소 배지 텍스트
String formatBadge(String exchange, String type) {
  if (exchange.contains('NASDAQ') || exchange.contains('NMS')) return 'NASDAQ';
  if (exchange.contains('NYSE')) return 'NYSE';
  if (exchange.contains('AMEX') || exchange.contains('ARCA')) return 'NYSE ARCA';
  if (exchange == 'US' || exchange.isEmpty) {
    return formatType(type);
  }
  return exchange;
}

/// 종목 타입 표시명
String formatType(String type) {
  switch (type) {
    case 'Common Stock': return 'Stock';
    case 'ETP': return 'ETP';
    case 'ETF': return 'ETF';
    case 'ADR': return 'ADR';
    case 'REIT': return 'REIT';
    default: return type.isNotEmpty ? type : 'US';
  }
}

/// 가격 포맷 (콤마 구분)
String formatPrice(double price) {
  return price.toStringAsFixed(2).replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
        (match) => '${match[1]},',
      );
}

/// 프리/애프터 마켓 가격 서브라인 위젯
///
/// [extPrice]가 null이면 아무것도 렌더링하지 않음.
/// 우측 정렬로 정규장 가격 아래에 표시.
class ExtendedHoursSubLine extends StatelessWidget {
  final ExtendedHoursPrice? extPrice;

  const ExtendedHoursSubLine({super.key, required this.extPrice});

  @override
  Widget build(BuildContext context) {
    if (extPrice == null) return const SizedBox.shrink();
    final ep = extPrice!;
    final isPositive = ep.changePercent >= 0;
    final changeColor = (isPositive ? AppColors.red500 : AppColors.blue500)
        .withValues(alpha: 0.7);
    final sign = isPositive ? '+' : '';

    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            ep.label,
            style: TextStyle(
              fontSize: 11,
              color: context.appTextHint,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '\$${formatPrice(ep.price)}',
            style: TextStyle(
              fontSize: 12,
              color: context.appTextSecondary,
            ),
          ),
          const SizedBox(width: 3),
          Text(
            '$sign${ep.changePercent.toStringAsFixed(2)}%',
            style: TextStyle(
              fontSize: 11,
              color: changeColor,
            ),
          ),
        ],
      ),
    );
  }
}
