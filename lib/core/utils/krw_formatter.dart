/// 원화 금액 포맷 유틸리티
/// 천단위 쉼표 + 음수 처리

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
