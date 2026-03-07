import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'notification_channels.dart';

/// 알림 서비스
///
/// 로컬 알림 초기화, 권한 관리 등을 담당합니다.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  /// 초기화 여부
  bool get isInitialized => _isInitialized;

  /// 알림 서비스 초기화
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    // Android 초기화 설정
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS 초기화 설정
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    // 초기화
    final result = await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    if (result == true) {
      // Android 알림 채널 생성
      if (Platform.isAndroid) {
        await _createAndroidChannels();
      }
      _isInitialized = true;
    }

    return _isInitialized;
  }

  /// Android 알림 채널 생성
  Future<void> _createAndroidChannels() async {
    final androidPlugin =
        _notifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      for (final channel in NotificationChannels.allChannels) {
        await androidPlugin.createNotificationChannel(channel);
      }
    }
  }

  /// 알림 권한 요청
  Future<bool> requestPermission() async {
    if (Platform.isAndroid) {
      final status = await Permission.notification.request();
      return status.isGranted;
    } else if (Platform.isIOS) {
      final result = await _notifications
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
      return result ?? false;
    }
    return false;
  }

  /// 알림 권한 확인
  Future<bool> hasPermission() async {
    if (Platform.isAndroid) {
      return await Permission.notification.isGranted;
    }
    return true; // iOS는 별도 확인 어려움
  }

  /// 알림 탭 핸들러
  void _onNotificationTapped(NotificationResponse response) {
    // 알림 탭 시 해당 종목 상세 화면으로 이동 (향후 구현)
  }

  /// 모든 알림 취소
  Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }
}
