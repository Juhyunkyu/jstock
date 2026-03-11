// 원화 금액 포맷 유틸리티 — 천단위 쉼표 + 음수 처리

/// 쉼표 포맷만 (원 단위 없음): "1,234" / "-1,234"
String formatKrwWithComma(double amount) {
  final intAmount = amount.round();
  final absAmount = intAmount.abs();
  final formatted = absAmount.toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
    (Match m) => '${m[1]},',
  );
  return intAmount < 0 ? '-$formatted' : formatted;
}

/// 원 단위 포함: "1,234원" / "-1,234원"
String formatKrw(double amount) {
  return '${formatKrwWithComma(amount)}원';
}

final _commaRegExp = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');

/// 축약 원화 표시: 1억2,000만 / 5,000만 / 1,234
String formatCashShort(double amount) {
  if (amount >= 100000000) {
    final eok = amount / 100000000;
    final remainder = (amount % 100000000) / 10000;
    if (remainder >= 1) {
      return '${eok.toStringAsFixed(0)}억${remainder.round().toString().replaceAllMapped(_commaRegExp, (m) => '${m[1]},')}만';
    }
    return '${eok.toStringAsFixed(0)}억';
  }
  if (amount >= 10000) {
    final man = (amount / 10000).round();
    return '${man.toString().replaceAllMapped(_commaRegExp, (m) => '${m[1]},')}만';
  }
  return formatKrwWithComma(amount);
}
