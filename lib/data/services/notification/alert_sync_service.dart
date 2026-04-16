import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/config/app_config.dart';
import '../../models/settings.dart';
import '../../models/watchlist_item.dart';
import '../api/proxy_config.dart';

/// 알림 조건 동기화 서비스
///
/// Hive에 저장된 알림 조건을 Worker KV에 동기화하여
/// 서버 cron이 앱 종료 후에도 가격 감시를 수행할 수 있도록 합니다.
class AlertSyncService {
  AlertSyncService._();

  static final _dio = Dio()
    ..options.baseUrl = ProxyConfig.proxyBase
    ..options.headers = {
      if (AppConfig.appToken.isNotEmpty) 'X-App-Token': AppConfig.appToken,
    };

  /// 전체 알림 조건을 서버에 동기화
  ///
  /// [watchlistItems] — 관심종목 전체 (알림 설정된 것만 필터)
  /// [settings] — 앱 설정 (공포탐욕 알림)
  static Future<void> syncAlerts({
    required List<WatchlistItem> watchlistItems,
    required Settings settings,
  }) async {
    if (!ProxyConfig.useProxy) return;

    try {
      final alerts = <Map<String, dynamic>>[];

      // 1. 목표가 알림
      for (final item in watchlistItems) {
        if (item.hasTargetAlert) {
          alerts.add({
            'type': 'target_price',
            'ticker': item.ticker,
            'targetPrice': item.alertPrice,
            'direction': item.alertTargetDirection ?? 0,
            'cooldownMinutes': 60,
          });
        }
      }

      // 2. 등락률 알림
      for (final item in watchlistItems) {
        if (item.hasPercentAlert) {
          alerts.add({
            'type': 'percent_change',
            'ticker': item.ticker,
            'basePrice': item.alertBasePrice,
            'percent': item.alertPercent,
            'direction': item.alertDirection ?? 0,
            'cooldownMinutes': 60,
          });
        }
      }

      // 3. 공포탐욕지수 알림 (활성 시에만)
      if (settings.fearGreedAlertEnabled) {
        alerts.add({
          'type': 'fear_greed',
          'threshold': settings.fearGreedAlertValue,
          'direction': settings.fearGreedAlertDirection,
          'cooldownMinutes': 60,
        });
      }

      await _dio.post('/api/alerts/sync', data: {'alerts': alerts});
      debugPrint('[AlertSync] Synced ${alerts.length} alerts to server');
    } catch (e) {
      debugPrint('[AlertSync] Sync failed: $e');
    }
  }
}
