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

  /// 알림 권한이 거부되었는지 확인
  static bool get isPermissionDenied {
    if (!kIsWeb) return false;
    return web.Notification.permission == 'denied';
  }

  /// 알림 권한 상태 텍스트
  static String get permissionStatus {
    if (!kIsWeb) return '지원 안 함';
    final perm = web.Notification.permission;
    switch (perm) {
      case 'granted':
        return '허용됨';
      case 'denied':
        return '차단됨';
      default:
        return '미설정';
    }
  }

  /// 알림 권한 요청
  ///
  /// 반환값: 권한이 허용되었으면 true
  /// 매번 호출 시 권한 상태가 'default'면 브라우저 팝업 표시
  static Future<bool> requestPermission() async {
    if (!kIsWeb) return false;
    if (isPermissionGranted) return true;
    // 이미 거부된 경우 브라우저가 팝업을 다시 표시하지 않음
    if (isPermissionDenied) return false;

    try {
      final permission = await web.Notification.requestPermission().toDart;
      return permission.toDart == 'granted';
    } catch (_) {
      return false;
    }
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
