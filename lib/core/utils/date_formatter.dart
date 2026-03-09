/// 날짜를 yyyy.MM.dd 형식으로 포맷
String formatDateDot(DateTime date) {
  return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
}
