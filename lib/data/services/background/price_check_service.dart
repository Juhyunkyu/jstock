import 'dart:async';
import '../api/finnhub_service.dart';
import '../api/api_exception.dart';
import '../notification/notification_service.dart';
import '../../models/settings.dart';
import '../../repositories/cycle_repository.dart';
import '../../repositories/settings_repository.dart';
import '../../../domain/usecases/signal_detector.dart';

/// 가격 체크 서비스
///
/// 주기적으로 주가를 확인하고 매매 신호를 감지하여 알림을 발송합니다.
class PriceCheckService {
  final FinnhubService _stockService;
  final NotificationService _notificationService;
  final CycleRepository _cycleRepository;
  final SettingsRepository _settingsRepository;

  Timer? _timer;
  bool _isRunning = false;
  DateTime? _lastCheckTime;

  /// 오늘 발생한 신호 (중복 알림 방지)
  final Set<String> _todaySignals = {};

  PriceCheckService({
    required FinnhubService stockService,
    required NotificationService notificationService,
    required CycleRepository cycleRepository,
    required SettingsRepository settingsRepository,
  })  : _stockService = stockService,
        _notificationService = notificationService,
        _cycleRepository = cycleRepository,
        _settingsRepository = settingsRepository;

  /// 실행 중 여부
  bool get isRunning => _isRunning;

  /// 마지막 체크 시간
  DateTime? get lastCheckTime => _lastCheckTime;

  /// 주기적 가격 체크 시작
  void startPeriodicCheck() {
    if (_isRunning) return;

    final settings = _settingsRepository.settings;
    final interval = Duration(minutes: settings.checkIntervalMinutes);

    _isRunning = true;

    // 즉시 한 번 체크
    _checkPricesAndNotify();

    // 주기적 체크 시작
    _timer = Timer.periodic(interval, (_) {
      _checkPricesAndNotify();
    });
  }

  /// 주기적 가격 체크 중지
  void stopPeriodicCheck() {
    _timer?.cancel();
    _timer = null;
    _isRunning = false;
  }

  /// 체크 간격 업데이트
  void updateInterval(int minutes) {
    if (_isRunning) {
      stopPeriodicCheck();
      startPeriodicCheck();
    }
  }

  /// 가격 확인 및 알림 발송
  Future<PriceCheckResult> _checkPricesAndNotify() async {
    final result = PriceCheckResult();

    try {
      // 활성 사이클 가져오기
      final activeCycles = _cycleRepository.getActiveCycles();
      if (activeCycles.isEmpty) {
        result.message = '활성 사이클 없음';
        return result;
      }

      // 설정 가져오기
      final settings = _settingsRepository.settings;

      // 고유 종목 코드 추출
      final tickers = activeCycles.map((c) => c.ticker).toSet().toList();

      // 주가 조회
      Map<String, StockQuote> quotes;
      try {
        quotes = await _stockService.getQuotes(tickers);
      } on ApiException catch (e) {
        result.error = e.message;
        return result;
      }

      // 오늘 날짜 확인 (자정에 신호 기록 초기화)
      _resetDailySignalsIfNeeded();

      // 각 사이클에 대해 신호 확인
      for (final cycle in activeCycles) {
        final quote = quotes[cycle.ticker];
        if (quote == null) continue;

        // 매매 신호 분석
        final recommendation = SignalDetector.getRecommendation(cycle, quote.currentPrice);

        // 신호 처리
        await _processSignal(
          recommendation: recommendation,
          ticker: cycle.ticker,
          initialEntryAmount: cycle.initialEntryAmount,
          quote: quote,
          settings: settings,
          result: result,
        );
      }

      _lastCheckTime = DateTime.now();
      result.success = true;
      result.checkedCount = activeCycles.length;

    } catch (e) {
      result.error = e.toString();
    }

    return result;
  }

  /// 신호 처리 및 알림 발송
  Future<void> _processSignal({
    required TradingRecommendation recommendation,
    required String ticker,
    required double initialEntryAmount,
    required StockQuote quote,
    required Settings settings,
    required PriceCheckResult result,
  }) async {
    final signal = recommendation.signal;
    final signalKey = '${ticker}_${signal.name}_${DateTime.now().toIso8601String().substring(0, 10)}';

    // 이미 오늘 발송한 신호인지 확인
    if (_todaySignals.contains(signalKey)) {
      return;
    }

    // 알림 설정 확인
    bool shouldNotify = false;
    switch (signal) {
      case TradingSignal.weightedBuy:
        shouldNotify = settings.notifyBuySignal;
        result.buySignalCount++;
        break;
      case TradingSignal.panicBuy:
        shouldNotify = settings.notifyPanicSignal;
        result.panicSignalCount++;
        break;
      case TradingSignal.takeProfit:
        shouldNotify = settings.notifySellSignal;
        result.takeProfitCount++;
        break;
      case TradingSignal.hold:
        return; // HOLD는 알림 없음
    }

    if (!shouldNotify) return;

    // 알림 발송
    await _notificationService.showSignalNotification(
      recommendation: recommendation,
      ticker: ticker,
      stockName: _getStockName(ticker),
      currentPrice: quote.currentPrice,
      initialEntryAmount: initialEntryAmount,
    );

    // 신호 기록 (중복 방지)
    _todaySignals.add(signalKey);
    result.notificationsSent++;
  }

  /// 일일 신호 기록 초기화 (자정)
  void _resetDailySignalsIfNeeded() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (_lastCheckTime != null) {
      final lastCheckDate = DateTime(
        _lastCheckTime!.year,
        _lastCheckTime!.month,
        _lastCheckTime!.day,
      );

      if (today.isAfter(lastCheckDate)) {
        _todaySignals.clear();
      }
    }
  }

  /// 종목명 조회 (간략화)
  String _getStockName(String ticker) {
    const stockNames = {
      'TQQQ': '나스닥100 3배',
      'SOXL': '반도체 3배',
      'UPRO': 'S&P500 3배',
      'TECL': '기술주 3배',
      'FNGU': 'FANG+ 3배',
      'LABU': '바이오 3배',
      'TNA': '소형주 3배',
      'SPXL': 'S&P500 3배',
      'FAS': '금융 3배',
      'NUGT': '금광 3배',
    };
    return stockNames[ticker] ?? ticker;
  }

  /// 수동 가격 체크 실행
  Future<PriceCheckResult> checkNow() async {
    return await _checkPricesAndNotify();
  }

  /// 일일 요약 알림 발송
  Future<void> sendDailySummary() async {
    final settings = _settingsRepository.settings;
    if (!settings.notifyDailySummary) return;

    final activeCycles = _cycleRepository.getActiveCycles();

    // 총 자산 및 손익 계산
    double totalValue = 0;
    double totalProfit = 0;

    for (final cycle in activeCycles) {
      totalValue += cycle.remainingCash;
      // 주식 가치는 현재가 정보 필요 - 간략화를 위해 시드 기준 계산
      totalValue += cycle.seedAmount - cycle.remainingCash;
    }

    // 오늘 매수 신호 수
    final buySignalCount = _todaySignals
        .where((s) => s.contains('WEIGHTED_BUY') || s.contains('PANIC_BUY'))
        .length;

    await _notificationService.showDailySummaryNotification(
      activeCycleCount: activeCycles.length,
      buySignalCount: buySignalCount,
      totalValue: totalValue,
      totalProfit: totalProfit,
    );
  }

  /// 리소스 정리
  void dispose() {
    stopPeriodicCheck();
  }
}

/// 가격 체크 결과
class PriceCheckResult {
  bool success = false;
  int checkedCount = 0;
  int buySignalCount = 0;
  int panicSignalCount = 0;
  int takeProfitCount = 0;
  int notificationsSent = 0;
  String? error;
  String? message;

  @override
  String toString() {
    if (error != null) return 'PriceCheckResult(error: $error)';
    return 'PriceCheckResult('
        'success: $success, '
        'checked: $checkedCount, '
        'buy: $buySignalCount, '
        'panic: $panicSignalCount, '
        'profit: $takeProfitCount, '
        'sent: $notificationsSent)';
  }
}
