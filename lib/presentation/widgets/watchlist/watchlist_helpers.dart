import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

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
