import 'dart:js_interop';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

/// 브라우저 Notification API 래퍼
///
/// Flutter Web에서 OS 레벨 알림을 표시합니다.
/// 모바일 빌드 시 안전하게 no-op으로 동작합니다.
class WebNotificationService {
  /// 현재 알림 권한 상태
  static bool get isPermissionGranted {
    if (!kIsWeb) return false;
    return web.Notification.permission == 'granted';
  }

  /// 알림 권한 요청
  ///
  /// 반환값: 권한이 허용되었으면 true
  /// 이미 권한이 있으면 즉시 true 반환.
  /// 권한이 'denied'이면 브라우저에서 재요청 불가 → false 반환.
  static Future<bool> requestPermission() async {
    if (!kIsWeb) return false;
    if (isPermissionGranted) return true;

    // 'denied' 상태면 브라우저가 팝업을 다시 띄우지 않으므로 요청 생략
    if (web.Notification.permission == 'denied') return false;

    final permission = await web.Notification.requestPermission().toDart;
    return permission.toDart == 'granted';
  }

  /// 브라우저 알림 표시
  ///
  /// 권한이 없으면 무시합니다. (인앱 SnackBar는 별도 처리)
  static void show({
    required String title,
    required String body,
    String? icon,
  }) {
    if (!kIsWeb) return;
    if (!isPermissionGranted) return;

    final options = web.NotificationOptions(
      body: body,
      icon: icon ?? 'icons/Icon-192.png',
    );
    web.Notification(title, options);
  }
}
