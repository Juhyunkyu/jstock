// 한국어 금액 표시 유틸리티 — 만/억 단위 + 한글 숫자

/// 숫자를 한글 금액으로 변환 (예: 350000000 → "삼억 오천만원")
///
/// [cycle_setup_screen]에서 시드 금액을 한글로 표시할 때 사용.
String formatKoreanAmountFull(double amount) {
  final value = amount.toInt();
  if (value <= 0) return '';

  final buffer = StringBuffer();

  final eok = value ~/ 100000000;
  final man = (value % 100000000) ~/ 10000;
  final rest = value % 10000;

  if (eok > 0) {
    final eokStr = _toKoreanUnit(eok);
    buffer.write('${eokStr.isEmpty ? '일' : eokStr}억');
    if (man > 0 || rest > 0) buffer.write(' ');
  }
  if (man > 0) {
    buffer.write('${_toKoreanUnit(man)}만');
    if (rest > 0) buffer.write(' ');
  }
  if (rest > 0) {
    buffer.write(_toKoreanUnit(rest));
  }

  if (buffer.isEmpty) return '0원';
  return '$buffer원';
}

/// 숫자를 축약 한국어 금액으로 변환 (예: 350000000 → "3억 5000만원")
///
/// [cycle_trade_record_sheet], [cycle_settings_sheet]에서 금액 표시에 사용.
String formatKoreanAmountShort(double amount) {
  if (amount >= 100000000) {
    final eok = amount / 100000000;
    final remainder = (amount % 100000000) / 10000;
    if (remainder > 0) {
      return '${eok.toStringAsFixed(0)}억 ${remainder.toStringAsFixed(0)}만원';
    }
    return '${eok.toStringAsFixed(0)}억원';
  } else if (amount >= 10000) {
    return '${(amount / 10000).toStringAsFixed(0)}만원';
  }
  return '${amount.toStringAsFixed(0)}원';
}

/// 숫자 문자열에 천단위 쉼표 추가 (예: "1234567" → "1,234,567")
String addCommas(String digits) {
  final buffer = StringBuffer();
  final length = digits.length;
  for (int i = 0; i < length; i++) {
    if (i > 0 && (length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

// ═══════════════════════════════════════════════════════════════
// 내부 헬퍼
// ═══════════════════════════════════════════════════════════════

const _koreanDigits = ['', '일', '이', '삼', '사', '오', '육', '칠', '팔', '구'];

/// 1~9999를 순수 한글로 변환
/// 1000 → 천, 5000 → 오천, 100 → 백, 1500 → 천오백
String _toKoreanUnit(int n) {
  if (n <= 0) return '';
  final buffer = StringBuffer();
  final cheon = n ~/ 1000;
  final baek = (n % 1000) ~/ 100;
  final sip = (n % 100) ~/ 10;
  final il = n % 10;

  if (cheon > 0) {
    if (cheon > 1) buffer.write(_koreanDigits[cheon]);
    buffer.write('천');
  }
  if (baek > 0) {
    if (baek > 1) buffer.write(_koreanDigits[baek]);
    buffer.write('백');
  }
  if (sip > 0) {
    if (sip > 1) buffer.write(_koreanDigits[sip]);
    buffer.write('십');
  }
  if (il > 0) {
    buffer.write(_koreanDigits[il]);
  }
  return buffer.toString();
}
