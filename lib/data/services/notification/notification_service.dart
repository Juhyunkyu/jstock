import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../domain/usecases/signal_detector.dart';
import 'notification_channels.dart';

/// 알림 서비스
///
/// 매매 신호 및 일일 요약 알림을 관리합니다.
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
    // TODO: 알림 탭 시 해당 종목 상세 화면으로 이동
    // payload에 cycleId를 담아서 처리
  }

  /// 매수 신호 알림 (가중 매수)
  Future<void> showBuySignalNotification({
    required String ticker,
    required String stockName,
    required double lossRate,
    required double buyAmount,
    required double currentPrice,
  }) async {
    if (!_isInitialized) return;

    final id = NotificationIds.forBuySignal(ticker);
    final formattedAmount = _formatCurrency(buyAmount);
    final formattedLossRate = lossRate.toStringAsFixed(1);

    await _notifications.show(
      id,
      '📉 $ticker 매수 신호',
      '$stockName 손실률 $formattedLossRate% | 매수 금액: $formattedAmount',
      NotificationDetails(
        android: AndroidNotificationDetails(
          NotificationChannelIds.buySignal,
          '매수 신호',
          channelDescription: '가중 매수 신호 알림',
          importance: Importance.high,
          priority: Priority.high,
          styleInformation: BigTextStyleInformation(
            '현재가: \$${currentPrice.toStringAsFixed(2)}\n'
            '손실률: $formattedLossRate%\n'
            '권장 매수 금액: $formattedAmount\n\n'
            '가중 매수 조건이 충족되었습니다.',
            contentTitle: '📉 $ticker 매수 신호',
            summaryText: stockName,
          ),
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          subtitle: stockName,
        ),
      ),
      payload: ticker,
    );
  }

  /// 승부수 신호 알림
  Future<void> showPanicSignalNotification({
    required String ticker,
    required String stockName,
    required double lossRate,
    required double panicAmount,
    required double weightedAmount,
    required double currentPrice,
  }) async {
    if (!_isInitialized) return;

    final id = NotificationIds.forPanicSignal(ticker);
    final totalAmount = panicAmount + weightedAmount;
    final formattedTotal = _formatCurrency(totalAmount);
    final formattedPanic = _formatCurrency(panicAmount);
    final formattedWeighted = _formatCurrency(weightedAmount);

    await _notifications.show(
      id,
      '🚨 $ticker 승부수 발동!',
      '$stockName 손실률 ${lossRate.toStringAsFixed(1)}% | 총 매수: $formattedTotal',
      NotificationDetails(
        android: AndroidNotificationDetails(
          NotificationChannelIds.panicSignal,
          '승부수 신호',
          channelDescription: '승부수 매수 신호 알림',
          importance: Importance.max,
          priority: Priority.max,
          styleInformation: BigTextStyleInformation(
            '현재가: \$${currentPrice.toStringAsFixed(2)}\n'
            '손실률: ${lossRate.toStringAsFixed(1)}%\n\n'
            '승부수 금액: $formattedPanic\n'
            '가중 매수 금액: $formattedWeighted\n'
            '총 매수 금액: $formattedTotal\n\n'
            '⚠️ 승부수는 사이클당 1회만 사용 가능합니다!',
            contentTitle: '🚨 $ticker 승부수 발동!',
            summaryText: stockName,
          ),
          fullScreenIntent: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          subtitle: stockName,
          interruptionLevel: InterruptionLevel.timeSensitive,
        ),
      ),
      payload: ticker,
    );
  }

  /// 익절 신호 알림
  Future<void> showTakeProfitNotification({
    required String ticker,
    required String stockName,
    required double returnRate,
    required double currentPrice,
    required double totalProfit,
  }) async {
    if (!_isInitialized) return;

    final id = NotificationIds.forTakeProfit(ticker);
    final formattedProfit = _formatCurrency(totalProfit);
    final formattedReturn = returnRate.toStringAsFixed(1);

    await _notifications.show(
      id,
      '🎉 $ticker 익절 신호!',
      '$stockName 수익률 +$formattedReturn% | 예상 수익: $formattedProfit',
      NotificationDetails(
        android: AndroidNotificationDetails(
          NotificationChannelIds.takeProfit,
          '익절 신호',
          channelDescription: '익절 매도 신호 알림',
          importance: Importance.high,
          priority: Priority.high,
          styleInformation: BigTextStyleInformation(
            '현재가: \$${currentPrice.toStringAsFixed(2)}\n'
            '수익률: +$formattedReturn%\n'
            '예상 수익: $formattedProfit\n\n'
            '🎯 목표 수익률 달성! 전량 매도를 권장합니다.',
            contentTitle: '🎉 $ticker 익절 신호!',
            summaryText: stockName,
          ),
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          subtitle: stockName,
        ),
      ),
      payload: ticker,
    );
  }

  /// 일일 요약 알림
  Future<void> showDailySummaryNotification({
    required int activeCycleCount,
    required int buySignalCount,
    required double totalValue,
    required double totalProfit,
  }) async {
    if (!_isInitialized) return;

    final formattedValue = _formatCurrency(totalValue);
    final formattedProfit = _formatCurrency(totalProfit);
    final profitSign = totalProfit >= 0 ? '+' : '';

    await _notifications.show(
      NotificationIds.dailySummary,
      '📊 알파 사이클 일일 요약',
      '활성 사이클: $activeCycleCount개 | 오늘 매수 신호: $buySignalCount건',
      NotificationDetails(
        android: AndroidNotificationDetails(
          NotificationChannelIds.dailySummary,
          '일일 요약',
          channelDescription: '매일 포트폴리오 요약 알림',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          styleInformation: BigTextStyleInformation(
            '활성 사이클: $activeCycleCount개\n'
            '오늘 매수 신호: $buySignalCount건\n\n'
            '총 자산: $formattedValue\n'
            '총 손익: $profitSign$formattedProfit',
            contentTitle: '📊 알파 사이클 일일 요약',
          ),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: false,
        ),
      ),
    );
  }

  /// 신호에 따른 알림 표시
  Future<void> showSignalNotification({
    required TradingRecommendation recommendation,
    required String ticker,
    required String stockName,
    required double currentPrice,
    double? initialEntryAmount,
    double? totalProfit,
  }) async {
    switch (recommendation.signal) {
      case TradingSignal.weightedBuy:
        await showBuySignalNotification(
          ticker: ticker,
          stockName: stockName,
          lossRate: recommendation.lossRate,
          buyAmount: recommendation.recommendedAmount,
          currentPrice: currentPrice,
        );
        break;

      case TradingSignal.panicBuy:
        // 승부수 금액 계산 (초기진입금의 50%)
        final panicAmount = (initialEntryAmount ?? 0) * 0.5;
        final weightedAmount = recommendation.recommendedAmount - panicAmount;
        await showPanicSignalNotification(
          ticker: ticker,
          stockName: stockName,
          lossRate: recommendation.lossRate,
          panicAmount: panicAmount,
          weightedAmount: weightedAmount > 0 ? weightedAmount : 0,
          currentPrice: currentPrice,
        );
        break;

      case TradingSignal.takeProfit:
        await showTakeProfitNotification(
          ticker: ticker,
          stockName: stockName,
          returnRate: recommendation.returnRate,
          currentPrice: currentPrice,
          totalProfit: totalProfit ?? 0,
        );
        break;

      case TradingSignal.hold:
        // HOLD 신호는 알림 없음
        break;
    }
  }

  /// 특정 종목 알림 취소
  Future<void> cancelNotification(String ticker) async {
    await _notifications.cancel(NotificationIds.forBuySignal(ticker));
    await _notifications.cancel(NotificationIds.forPanicSignal(ticker));
    await _notifications.cancel(NotificationIds.forTakeProfit(ticker));
  }

  /// 모든 알림 취소
  Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }

  /// 금액 포맷팅 (콤마 구분)
  String _formatCurrency(double amount) {
    final intAmount = amount.round();
    final absAmount = intAmount.abs();
    final formatted = absAmount.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
    return intAmount < 0 ? '-$formatted원' : '$formatted원';
  }
}
