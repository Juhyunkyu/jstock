import 'dart:ui' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// 알림 채널 ID 상수
class NotificationChannelIds {
  static const String buySignal = 'buy_signal_channel';
  static const String panicSignal = 'panic_signal_channel';
  static const String takeProfit = 'take_profit_channel';
  static const String dailySummary = 'daily_summary_channel';
}

/// 알림 ID 상수 (각 종목별로 고유 ID 생성에 사용)
class NotificationIds {
  static const int buySignalBase = 1000;
  static const int panicSignalBase = 2000;
  static const int takeProfitBase = 3000;
  static const int dailySummary = 9999;

  /// 종목 코드로부터 알림 ID 생성
  static int forBuySignal(String ticker) =>
      buySignalBase + ticker.hashCode.abs() % 1000;

  static int forPanicSignal(String ticker) =>
      panicSignalBase + ticker.hashCode.abs() % 1000;

  static int forTakeProfit(String ticker) =>
      takeProfitBase + ticker.hashCode.abs() % 1000;
}

/// Android 알림 채널 설정
class NotificationChannels {
  /// 매수 신호 채널 (가중 매수)
  static const AndroidNotificationChannel buySignalChannel =
      AndroidNotificationChannel(
    NotificationChannelIds.buySignal,
    '매수 신호',
    description: '가중 매수 신호 알림 (-20% 이하)',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
    enableLights: true,
    ledColor: Color(0xFF2196F3), // Blue
  );

  /// 승부수 신호 채널 (긴급)
  static const AndroidNotificationChannel panicSignalChannel =
      AndroidNotificationChannel(
    NotificationChannelIds.panicSignal,
    '승부수 신호',
    description: '승부수 매수 신호 알림 (-50% 이하)',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
    enableLights: true,
    ledColor: Color(0xFFF44336), // Red
  );

  /// 익절 신호 채널
  static const AndroidNotificationChannel takeProfitChannel =
      AndroidNotificationChannel(
    NotificationChannelIds.takeProfit,
    '익절 신호',
    description: '익절 매도 신호 알림 (+20% 이상)',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
    enableLights: true,
    ledColor: Color(0xFF4CAF50), // Green
  );

  /// 일일 요약 채널
  static const AndroidNotificationChannel dailySummaryChannel =
      AndroidNotificationChannel(
    NotificationChannelIds.dailySummary,
    '일일 요약',
    description: '매일 포트폴리오 요약 알림',
    importance: Importance.defaultImportance,
    playSound: false,
    enableVibration: false,
  );

  /// 모든 채널 목록
  static List<AndroidNotificationChannel> get allChannels => [
        buySignalChannel,
        panicSignalChannel,
        takeProfitChannel,
        dailySummaryChannel,
      ];
}
