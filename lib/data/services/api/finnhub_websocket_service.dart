import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../../core/config/app_config.dart';

/// 실시간 가격 업데이트 데이터
class RealtimePrice {
  final String symbol;
  final double price;
  final double volume;
  final DateTime timestamp;

  const RealtimePrice({
    required this.symbol,
    required this.price,
    required this.volume,
    required this.timestamp,
  });

  factory RealtimePrice.fromJson(Map<String, dynamic> json) {
    return RealtimePrice(
      symbol: json['s'] as String,
      price: (json['p'] as num).toDouble(),
      volume: (json['v'] as num?)?.toDouble() ?? 0,
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['t'] as int),
    );
  }

  @override
  String toString() => 'RealtimePrice($symbol: \$$price)';
}

/// Finnhub WebSocket 서비스 (실시간 주가)
///
/// BroadcastStream을 사용하여 여러 리스너가 동시에 구독 가능
class FinnhubWebSocketService {
  WebSocketChannel? _channel;
  StreamController<RealtimePrice>? _controller;
  Stream<RealtimePrice>? _broadcastStream;
  final Set<String> _subscribedSymbols = {};
  bool _isConnected = false;
  bool _isConnecting = false;
  Timer? _reconnectTimer;
  Timer? _pingTimer;

  // Exponential backoff 설정
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 10;
  static const Duration _baseReconnectDelay = Duration(seconds: 5);
  static const Duration _maxReconnectDelay = Duration(minutes: 5);
  static const Duration _rateLimitDelay = Duration(minutes: 2); // 429 에러 시 대기 시간

  bool _isRateLimited = false;
  DateTime? _rateLimitedUntil;
  DateTime? _lastFailureTime;
  int _rapidFailureCount = 0;
  static const int _rapidFailureThreshold = 3; // 빠른 연속 실패 횟수 임계값
  static const Duration _rapidFailureWindow = Duration(seconds: 30); // 빠른 실패 판정 시간

  /// 연결 상태
  bool get isConnected => _isConnected;

  /// 구독 중인 심볼 목록
  Set<String> get subscribedSymbols => Set.unmodifiable(_subscribedSymbols);

  /// 실시간 가격 스트림 (BroadcastStream)
  ///
  /// 여러 위젯에서 동시에 listen 가능
  Stream<RealtimePrice> get priceStream {
    _ensureConnected();
    return _broadcastStream!;
  }

  /// 특정 심볼의 가격만 필터링한 스트림
  Stream<RealtimePrice> priceStreamFor(String symbol) {
    return priceStream.where((price) => price.symbol == symbol.toUpperCase());
  }

  /// 여러 심볼의 가격을 필터링한 스트림
  Stream<RealtimePrice> priceStreamForSymbols(List<String> symbols) {
    final upperSymbols = symbols.map((s) => s.toUpperCase()).toSet();
    return priceStream.where((price) => upperSymbols.contains(price.symbol));
  }

  /// WebSocket 연결 확보
  void _ensureConnected() {
    if (_controller == null || _controller!.isClosed) {
      _controller = StreamController<RealtimePrice>.broadcast();
      _broadcastStream = _controller!.stream;
    }

    if (!_isConnected) {
      connect();
    }
  }

  /// WebSocket 연결
  Future<void> connect() async {
    if (_isConnected || _isConnecting) return;

    // Rate limit 상태 확인
    if (_isRateLimited && _rateLimitedUntil != null) {
      if (DateTime.now().isBefore(_rateLimitedUntil!)) {
        final remaining = _rateLimitedUntil!.difference(DateTime.now());
        print('[FinnhubWS] Rate limited. Retry in ${remaining.inSeconds}s');
        _scheduleReconnect(delay: remaining);
        return;
      }
      _isRateLimited = false;
      _rateLimitedUntil = null;
    }

    // 최대 재시도 횟수 확인
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      print('[FinnhubWS] Max reconnect attempts reached ($_maxReconnectAttempts). Giving up.');
      _controller?.addError(
        Exception('WebSocket connection failed after $_maxReconnectAttempts attempts'),
      );
      return;
    }

    _isConnecting = true;

    try {
      print('[FinnhubWS] Connecting... (attempt ${_reconnectAttempts + 1})');

      _channel = WebSocketChannel.connect(
        Uri.parse(AppConfig.finnhubWebSocketUrl),
      );

      // 연결 준비 대기
      await _channel!.ready;

      _isConnected = true;
      _isConnecting = false;
      _reconnectAttempts = 0; // 성공 시 재시도 카운터 리셋

      print('[FinnhubWS] Connected successfully');

      // 메시지 수신 리스너
      _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
      );

      // 이전에 구독했던 심볼들 재구독
      for (final symbol in _subscribedSymbols) {
        _sendSubscribe(symbol);
      }

      // Ping 타이머 시작 (연결 유지용)
      _startPingTimer();

    } catch (e) {
      _isConnected = false;
      _isConnecting = false;
      _handleConnectionError(e);
    }
  }

  /// 연결 에러 처리
  void _handleConnectionError(dynamic error) {
    final errorStr = error.toString().toLowerCase();
    final now = DateTime.now();

    // 빠른 연속 실패 감지 (브라우저에서 429는 일반 실패로 보임)
    if (_lastFailureTime != null &&
        now.difference(_lastFailureTime!) < _rapidFailureWindow) {
      _rapidFailureCount++;
    } else {
      _rapidFailureCount = 1;
    }
    _lastFailureTime = now;

    // 429 Rate Limit 에러 감지 (문자열 또는 빠른 연속 실패)
    final isRateLimitError = errorStr.contains('429') ||
        errorStr.contains('too many requests') ||
        _rapidFailureCount >= _rapidFailureThreshold;

    if (isRateLimitError) {
      print('[FinnhubWS] Rate limit detected (rapid failures: $_rapidFailureCount). Waiting ${_rateLimitDelay.inMinutes}min');
      _isRateLimited = true;
      _rateLimitedUntil = DateTime.now().add(_rateLimitDelay);
      _reconnectAttempts = 0;
      _rapidFailureCount = 0;
      _scheduleReconnect(delay: _rateLimitDelay);
      return;
    }

    _reconnectAttempts++;
    print('[FinnhubWS] Connection error: $error (attempt $_reconnectAttempts/$_maxReconnectAttempts)');
    _scheduleReconnect();
  }

  /// 메시지 수신 처리
  void _onMessage(dynamic message) {
    try {
      final data = jsonDecode(message as String);

      if (data['type'] == 'trade') {
        final trades = data['data'] as List?;
        if (trades != null && trades.isNotEmpty) {
          // 각 거래 데이터를 스트림에 추가
          for (final trade in trades) {
            final price = RealtimePrice.fromJson(trade as Map<String, dynamic>);
            _controller?.add(price);
          }
        }
      } else if (data['type'] == 'ping') {
        // Ping 응답 (Pong)
        _channel?.sink.add(jsonEncode({'type': 'pong'}));
      }
    } catch (e) {
      // JSON 파싱 에러 무시
    }
  }

  /// 에러 처리
  void _onError(dynamic error) {
    _isConnected = false;
    _isConnecting = false;
    _handleConnectionError(error);
  }

  /// 연결 종료 처리
  void _onDone() {
    _isConnected = false;
    _isConnecting = false;
    // 정상 종료가 아닌 경우에만 재연결
    if (_subscribedSymbols.isNotEmpty) {
      print('[FinnhubWS] Connection closed unexpectedly. Scheduling reconnect...');
      _scheduleReconnect();
    }
  }

  /// Exponential backoff를 적용한 재연결 스케줄링
  void _scheduleReconnect({Duration? delay}) {
    _reconnectTimer?.cancel();

    // delay가 지정되지 않은 경우 exponential backoff 계산
    final reconnectDelay = delay ?? _calculateBackoffDelay();

    print('[FinnhubWS] Reconnecting in ${reconnectDelay.inSeconds}s...');

    _reconnectTimer = Timer(reconnectDelay, () {
      if (!_isConnected && !_isConnecting) {
        connect();
      }
    });
  }

  /// Exponential backoff 딜레이 계산
  Duration _calculateBackoffDelay() {
    // 2^attempts * baseDelay (최대 maxDelay)
    final exponentialDelay = _baseReconnectDelay * (1 << _reconnectAttempts);
    final cappedDelay = exponentialDelay > _maxReconnectDelay
        ? _maxReconnectDelay
        : exponentialDelay;

    // Jitter 추가 (0-30% 랜덤 추가 지연)
    final jitter = Duration(
      milliseconds: (cappedDelay.inMilliseconds * 0.3 * (DateTime.now().millisecond / 1000)).round(),
    );

    return cappedDelay + jitter;
  }

  /// 수동 재연결 (재시도 카운터 리셋)
  void reconnect() {
    _reconnectAttempts = 0;
    _isRateLimited = false;
    _rateLimitedUntil = null;
    _rapidFailureCount = 0;
    _lastFailureTime = null;
    disconnect();
    connect();
  }

  /// Ping 타이머 시작 (연결 유지)
  void _startPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_isConnected) {
        try {
          _channel?.sink.add(jsonEncode({'type': 'ping'}));
        } catch (_) {}
      }
    });
  }

  /// 심볼 구독
  void subscribe(String symbol) {
    final upperSymbol = symbol.toUpperCase();
    if (_subscribedSymbols.contains(upperSymbol)) return;

    _subscribedSymbols.add(upperSymbol);
    _ensureConnected();

    if (_isConnected) {
      _sendSubscribe(upperSymbol);
    }
  }

  /// 여러 심볼 구독
  void subscribeAll(List<String> symbols) {
    for (final symbol in symbols) {
      subscribe(symbol);
    }
  }

  /// 구독 메시지 전송
  void _sendSubscribe(String symbol) {
    try {
      _channel?.sink.add(jsonEncode({
        'type': 'subscribe',
        'symbol': symbol,
      }));
    } catch (_) {}
  }

  /// 심볼 구독 취소
  void unsubscribe(String symbol) {
    final upperSymbol = symbol.toUpperCase();
    if (!_subscribedSymbols.contains(upperSymbol)) return;

    _subscribedSymbols.remove(upperSymbol);

    if (_isConnected) {
      try {
        _channel?.sink.add(jsonEncode({
          'type': 'unsubscribe',
          'symbol': upperSymbol,
        }));
      } catch (_) {}
    }
  }

  /// 모든 구독 취소
  void unsubscribeAll() {
    for (final symbol in _subscribedSymbols.toList()) {
      unsubscribe(symbol);
    }
  }

  /// 연결 해제
  void disconnect() {
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
    _isConnected = false;
    _isConnecting = false;
  }

  /// 리소스 정리
  void dispose() {
    disconnect();
    _controller?.close();
    _controller = null;
    _broadcastStream = null;
    _subscribedSymbols.clear();
    _reconnectAttempts = 0;
    _isRateLimited = false;
    _rateLimitedUntil = null;
    _rapidFailureCount = 0;
    _lastFailureTime = null;
  }

  /// 연결 상태 상세 정보
  Map<String, dynamic> get connectionStatus => {
    'isConnected': _isConnected,
    'isConnecting': _isConnecting,
    'isRateLimited': _isRateLimited,
    'rateLimitedUntil': _rateLimitedUntil?.toIso8601String(),
    'reconnectAttempts': _reconnectAttempts,
    'maxReconnectAttempts': _maxReconnectAttempts,
    'subscribedSymbols': _subscribedSymbols.toList(),
  };
}
