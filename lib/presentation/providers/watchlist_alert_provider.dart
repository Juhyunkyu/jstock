import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/watchlist_item.dart';
import '../../data/services/api/finnhub_service.dart';
import '../../data/services/notification/web_notification_service.dart';
import 'api_providers.dart';
import 'notification_history_provider.dart';
import 'watchlist_providers.dart';

/// 알림 트리거 결과
class AlertNotification {
  final String ticker;
  final String title;
  final String body;
  final String type; // 'target' or 'percent'

  const AlertNotification({
    required this.ticker,
    required this.title,
    required this.body,
    required this.type,
  });
}

/// 관심종목 알림 조건 체크 서비스
class WatchlistAlertChecker {
  /// 이미 트리거된 알림의 타임스탬프 (중복 방지 + 1시간 쿨다운)
  final Map<String, DateTime> _triggeredAt = {};

  /// 이전 가격 기록 (목표가 관통 판정용)
  final Map<String, double> _previousPrices = {};

  /// 쿨다운 기간 (1시간)
  static const Duration _cooldown = Duration(hours: 1);

  /// 가격 업데이트 시 모든 알림 조건 체크
  List<AlertNotification> checkAlerts(
    Map<String, StockQuote> quotes,
    List<WatchlistItem> items,
  ) {
    final alerts = <AlertNotification>[];

    for (final item in items) {
      if (!item.hasAlert) continue;

      final quote = quotes[item.ticker];
      if (quote == null) continue;

      final currentPrice = quote.currentPrice;
      if (currentPrice <= 0) continue;

      // 목표가 알림 체크
      if (item.hasTargetAlert) {
        final key = '${item.ticker}_target';
        if (!_isInCooldown(key)) {
          final previousPrice = _previousPrices[item.ticker];
          if (item.isTargetAlertTriggered(currentPrice, previousPrice)) {
            _triggeredAt[key] = DateTime.now();
            final dirLabel = (item.alertTargetDirection ?? 0) == 1 ? '이하' : '이상';
            alerts.add(AlertNotification(
              ticker: item.ticker,
              title: '${item.ticker} 목표가 $dirLabel 도달!',
              body:
                  '현재가 \$${currentPrice.toStringAsFixed(2)} | '
                  '목표가 \$${item.alertPrice!.toStringAsFixed(2)} $dirLabel',
              type: 'target',
            ));
          }
        }
      }

      // 변동률 알림 체크
      if (item.hasPercentAlert) {
        final key = '${item.ticker}_percent';
        if (!_isInCooldown(key)) {
          if (item.isPercentAlertTriggered(currentPrice)) {
            _triggeredAt[key] = DateTime.now();
            final changeRate =
                (currentPrice - item.alertBasePrice!) / item.alertBasePrice! * 100;
            final sign = changeRate >= 0 ? '▲' : '▼';
            final dirLabel = _directionLabel(item.alertDirection ?? 0);
            alerts.add(AlertNotification(
              ticker: item.ticker,
              title: '${item.ticker} 변동률 알림',
              body:
                  '현재가 \$${currentPrice.toStringAsFixed(2)} | '
                  '기준가 대비 $sign${changeRate.abs().toStringAsFixed(1)}% '
                  '(설정: $dirLabel${item.alertPercent!.toStringAsFixed(1)}%)',
              type: 'percent',
            ));
          }
        }
      }

      // 이전 가격 업데이트 (다음 체크를 위해)
      _previousPrices[item.ticker] = currentPrice;
    }

    return alerts;
  }

  /// 쿨다운 중인지 확인
  bool _isInCooldown(String key) {
    final triggeredTime = _triggeredAt[key];
    if (triggeredTime == null) return false;
    return DateTime.now().difference(triggeredTime) < _cooldown;
  }

  /// 방향 라벨
  String _directionLabel(int direction) {
    switch (direction) {
      case 1: return '▲';
      case 2: return '▼';
      default: return '±';
    }
  }

  /// 특정 알림의 쿨다운 리셋 (알림 재설정 시 호출)
  void resetAlert(String ticker, String type) {
    _triggeredAt.remove('${ticker}_$type');
  }

  /// 특정 종목의 모든 알림 쿨다운 리셋
  void resetAllAlerts(String ticker) {
    _triggeredAt.remove('${ticker}_target');
    _triggeredAt.remove('${ticker}_percent');
    _previousPrices.remove(ticker);
  }
}

/// WatchlistAlertChecker 싱글톤 Provider
final watchlistAlertCheckerProvider = Provider<WatchlistAlertChecker>((ref) {
  return WatchlistAlertChecker();
});

/// 알림 감시 Provider
///
/// UI에서 ref.watch()하여 활성화합니다.
/// quotes나 items가 변경될 때마다 자동으로 알림 조건을 체크합니다.
///
/// 반환값: 트리거된 알림 리스트 (UI에서 SnackBar 표시에 사용)
final watchlistAlertMonitorProvider = Provider<List<AlertNotification>>((ref) {
  final quoteState = ref.watch(stockQuoteProvider);
  final watchlistState = ref.watch(watchlistProvider);
  final checker = ref.read(watchlistAlertCheckerProvider);

  // 알림 설정이 있는 종목이 없으면 빈 리스트 반환
  final hasAlerts = watchlistState.items.any((item) => item.hasAlert);
  if (!hasAlerts) return [];

  // quotes가 비어있으면 빈 리스트 반환
  if (quoteState.quotes.isEmpty) return [];

  final alerts = checker.checkAlerts(quoteState.quotes, watchlistState.items);

  // 브라우저 알림 발송 + 내역 저장
  for (final alert in alerts) {
    WebNotificationService.show(title: alert.title, body: alert.body);
    ref.read(notificationHistoryProvider.notifier).addFromAlert(alert);
  }

  return alerts;
});
