import 'dart:js_interop';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

/// 브라우저 Notification API 래퍼
///
/// Flutter Web에서 OS 레벨 알림을 표시합니다.
/// 모바일 빌드 시 안전하게 no-op으로 동작합니다.
class WebNotificationService {
  /// Notification API를 지원하는 브라우저인지 확인
  static bool get _isSupported {
    if (!kIsWeb) return false;
    try {
      // Notification 객체 접근 자체가 실패하면 미지원
      web.Notification.permission;
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 현재 알림 권한 상태
  static bool get isPermissionGranted {
    if (!_isSupported) return false;
    try {
      return web.Notification.permission == 'granted';
    } catch (_) {
      return false;
    }
  }

  /// 알림 권한 요청
  ///
  /// 반환값: 권한이 허용되었으면 true
  /// 이미 권한이 있으면 즉시 true 반환.
  /// 권한이 'denied'이면 브라우저에서 재요청 불가 → false 반환.
  /// Notification API 미지원 브라우저에서는 false 반환.
  static Future<bool> requestPermission() async {
    if (!_isSupported) return false;
    try {
      if (isPermissionGranted) return true;
      if (web.Notification.permission == 'denied') return false;

      final permission = await web.Notification.requestPermission().toDart;
      return permission.toDart == 'granted';
    } catch (_) {
      return false;
    }
  }

  /// 브라우저 알림 표시
  ///
  /// 권한이 없거나 API 미지원이면 무시합니다.
  static void show({
    required String title,
    required String body,
    String? icon,
  }) {
    if (!isPermissionGranted) return;
    try {
      final options = web.NotificationOptions(
        body: body,
        icon: icon ?? 'icons/Icon-192.png',
      );
      web.Notification(title, options);
    } catch (_) {
      // 모바일 브라우저에서 Notification 생성 실패 시 무시
    }
  }
}
