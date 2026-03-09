/// 주식 수량 포맷: 정수면 소수점 없이, 소수면 2자리
String formatShares(double shares) {
  if (shares == shares.roundToDouble() && shares < 10000) {
    return shares.round().toString();
  }
  return shares.toStringAsFixed(2);
}
