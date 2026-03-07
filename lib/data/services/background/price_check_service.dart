/// 가격 체크 서비스
///
/// 사이클 로직 제거됨 — 향후 새로운 사이클 시스템에서 재구현 예정.
class PriceCheckService {
  bool _isRunning = false;
  DateTime? _lastCheckTime;

  /// 실행 중 여부
  bool get isRunning => _isRunning;

  /// 마지막 체크 시간
  DateTime? get lastCheckTime => _lastCheckTime;

  /// 주기적 가격 체크 시작 (현재 미구현)
  void startPeriodicCheck() {}

  /// 주기적 가격 체크 중지
  void stopPeriodicCheck() {
    _isRunning = false;
  }

  /// 체크 간격 업데이트
  void updateInterval(int minutes) {}

  /// 수동 가격 체크 실행
  Future<PriceCheckResult> checkNow() async {
    return PriceCheckResult()..message = '사이클 로직 미구현';
  }

  /// 일일 요약 알림 발송 (현재 미구현)
  Future<void> sendDailySummary() async {}

  /// 리소스 정리
  void dispose() {
    stopPeriodicCheck();
  }
}

/// 가격 체크 결과
class PriceCheckResult {
  bool success = false;
  int checkedCount = 0;
  int notificationsSent = 0;
  String? error;
  String? message;

  @override
  String toString() {
    if (error != null) return 'PriceCheckResult(error: $error)';
    return 'PriceCheckResult('
        'success: $success, '
        'checked: $checkedCount, '
        'sent: $notificationsSent)';
  }
}
