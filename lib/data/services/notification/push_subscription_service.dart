import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

import '../../../core/config/app_config.dart';
import '../api/proxy_config.dart';

/// Web Push API 구독 서비스
///
/// Push API를 통해 브라우저에 Push 구독을 등록하고,
/// 구독 정보를 Worker KV에 전송하여 서버 푸시를 활성화합니다.
///
/// 앱 열릴 때마다 [ensureSubscribed]를 호출하여 구독 상태를 확인/갱신합니다.
class PushSubscriptionService {
  PushSubscriptionService._();

  static final _dio = Dio()
    ..options.baseUrl = ProxyConfig.proxyBase
    ..options.headers = {
      if (AppConfig.appToken.isNotEmpty) 'X-App-Token': AppConfig.appToken,
    };

  /// Push API 지원 여부
  static bool get isSupported {
    if (!kIsWeb) return false;
    try {
      return web.window.navigator.serviceWorker != null;
    } catch (_) {
      return false;
    }
  }

  /// 현재 Push 구독 활성 여부 확인 (서버 측)
  static Future<bool> isSubscribed() async {
    try {
      final resp = await _dio.get('/api/push/subscribe');
      return resp.data['subscribed'] == true;
    } catch (_) {
      return false;
    }
  }

  /// Push 구독 보장 — 앱 시작 시 호출
  ///
  /// 1. 알림 권한 확인 (없으면 요청)
  /// 2. SW에서 Push 구독 얻기 (없으면 생성)
  /// 3. 서버에 구독 정보 등록
  static Future<bool> ensureSubscribed() async {
    if (!isSupported || AppConfig.vapidPublicKey.isEmpty) return false;

    try {
      // 알림 권한 확인
      final permission = web.Notification.permission;
      if (permission == 'denied') return false;
      if (permission != 'granted') {
        final result = await web.Notification.requestPermission().toDart;
        if (result.toDart != 'granted') return false;
      }

      // Service Worker registration 획득
      final registration =
          await web.window.navigator.serviceWorker.ready.toDart;

      // 기존 Push 구독 확인
      var subscription =
          await registration.pushManager.getSubscription().toDart;

      // 없으면 새로 구독
      if (subscription == null) {
        final serverKey = _urlBase64ToArrayBuffer(AppConfig.vapidPublicKey);
        subscription = await registration.pushManager
            .subscribe(
              web.PushSubscriptionOptionsInit(
                userVisibleOnly: true,
                applicationServerKey: serverKey,
              ),
            )
            .toDart;
      }

      if (subscription == null) return false;

      // 구독 키를 base64url로 인코딩하여 서버 전송
      final p256dhBuffer = subscription.getKey('p256dh');
      final authBuffer = subscription.getKey('auth');
      if (p256dhBuffer == null || authBuffer == null) return false;

      final p256dh = _arrayBufferToBase64Url(p256dhBuffer);
      final auth = _arrayBufferToBase64Url(authBuffer);

      await _dio.post('/api/push/subscribe', data: {
        'endpoint': subscription.endpoint,
        'keys': {
          'p256dh': p256dh,
          'auth': auth,
        },
      });

      debugPrint('[PushSubscription] Registered with server');
      return true;
    } catch (e) {
      debugPrint('[PushSubscription] Failed: $e');
      return false;
    }
  }

  /// 구독 해제
  static Future<void> unsubscribe() async {
    try {
      final registration =
          await web.window.navigator.serviceWorker.ready.toDart;
      final subscription =
          await registration.pushManager.getSubscription().toDart;
      if (subscription != null) {
        await subscription.unsubscribe().toDart;
      }
      await _dio.delete('/api/push/subscribe');
      debugPrint('[PushSubscription] Unsubscribed');
    } catch (e) {
      debugPrint('[PushSubscription] Unsubscribe failed: $e');
    }
  }

  /// VAPID public key (URL-safe base64) → ArrayBuffer
  static JSArrayBuffer _urlBase64ToArrayBuffer(String base64String) {
    final padding = '=' * ((4 - base64String.length % 4) % 4);
    final base64 = (base64String + padding)
        .replaceAll('-', '+')
        .replaceAll('_', '/');
    final rawData = base64Decode(base64);
    return Uint8List.fromList(rawData).buffer.toJS;
  }

  /// ArrayBuffer → URL-safe base64 문자열
  static String _arrayBufferToBase64Url(JSArrayBuffer buffer) {
    final bytes = buffer.toDart.asUint8List();
    return base64UrlEncode(bytes).replaceAll('=', '');
  }
}
