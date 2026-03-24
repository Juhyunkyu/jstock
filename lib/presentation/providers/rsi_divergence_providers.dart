import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/rsi_watch_point.dart';
import '../../data/repositories/rsi_watch_point_repository.dart';
import '../../data/services/api/finnhub_service.dart';
import 'api_providers.dart';
import 'core/repository_providers.dart';

// ===============================================================
// RSI 감시점 상태 관리
// ===============================================================

class RsiWatchPointState {
  final List<RsiWatchPoint> points;
  final bool isLoading;

  const RsiWatchPointState({
    this.points = const [],
    this.isLoading = true,
  });

  RsiWatchPointState copyWith({
    List<RsiWatchPoint>? points,
    bool? isLoading,
  }) {
    return RsiWatchPointState(
      points: points ?? this.points,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class RsiWatchPointNotifier extends StateNotifier<RsiWatchPointState> {
  final RsiWatchPointRepository _repository;

  RsiWatchPointNotifier(this._repository)
      : super(const RsiWatchPointState());

  /// 초기 로드 (Repository는 appInitializationProvider에서 이미 init됨)
  Future<void> load() async {
    if (!mounted) return;
    state = state.copyWith(isLoading: true);
    final points = _repository.getAll().map((p) => RsiWatchPoint(
      id: p.id,
      ticker: p.ticker,
      mode: p.mode,
      watchPrice: p.watchPrice,
      watchRsi: p.watchRsi,
      watchDate: p.watchDate,
      interval: p.interval,
      createdAt: p.createdAt,
      isActive: p.isActive,
      triggeredRsi: p.triggeredRsi,
      triggeredPrice: p.triggeredPrice,
      triggeredAt: p.triggeredAt,
      rsiPeriod: p.rsiPeriod,
    )).toList();
    if (!mounted) return;
    state = state.copyWith(points: points, isLoading: false);
  }

  /// 감시점 추가
  Future<void> addWatchPoint(RsiWatchPoint point) async {
    await _repository.add(point);
    _reload();
  }

  /// 감시점 삭제
  Future<void> removeWatchPoint(String id) async {
    await _repository.remove(id);
    _reload();
  }

  /// 감시점 업데이트
  Future<void> updateWatchPoint(RsiWatchPoint point) async {
    await _repository.update(point);
    _reload();
  }

  /// 활성/비활성 토글
  Future<void> toggleActive(String id) async {
    final point = _repository.getById(id);
    if (point == null) return;
    point.isActive = !point.isActive;
    await point.save();
    _reload();
  }

  /// 트리거 완료 처리
  Future<void> markTriggered(
    String id, {
    required double triggeredPrice,
    required double triggeredRsi,
  }) async {
    final point = _repository.getById(id);
    if (point == null) return;
    point.isActive = false;
    point.triggeredPrice = triggeredPrice;
    point.triggeredRsi = triggeredRsi;
    point.triggeredAt = DateTime.now();
    await point.save();
    _reload();
  }

  void _reload() {
    if (!mounted) return;
    // Deep copy to break Hive object identity — ensures Riverpod detects changes
    final freshPoints = _repository.getAll().map((p) => RsiWatchPoint(
      id: p.id,
      ticker: p.ticker,
      mode: p.mode,
      watchPrice: p.watchPrice,
      watchRsi: p.watchRsi,
      watchDate: p.watchDate,
      interval: p.interval,
      createdAt: p.createdAt,
      isActive: p.isActive,
      triggeredRsi: p.triggeredRsi,
      triggeredPrice: p.triggeredPrice,
      triggeredAt: p.triggeredAt,
      rsiPeriod: p.rsiPeriod,
    )).toList();
    state = state.copyWith(points: freshPoints);
  }
}

final rsiWatchPointProvider =
    StateNotifierProvider<RsiWatchPointNotifier, RsiWatchPointState>((ref) {
  final repository = ref.watch(rsiWatchPointRepositoryProvider);
  return RsiWatchPointNotifier(repository);
});

// ===============================================================
// RSI 다이버전스 돌파 감지
// ===============================================================

/// 돌파 알림 상태
enum RsiAlertStatus { breached }

/// 돌파 알림 데이터
class RsiDivergenceAlert {
  final RsiWatchPoint watchPoint;
  final double currentPrice;
  final RsiAlertStatus status;

  const RsiDivergenceAlert({
    required this.watchPoint,
    required this.currentPrice,
    required this.status,
  });
}

/// 1단계 가격 돌파 감지 (WebSocket 데이터, API 호출 없음)
class RsiDivergenceChecker {
  final Map<String, DateTime> _cooldowns = {};    // 감시점별 RSI 체크 쿨다운
  final Map<String, double> _previousPrices = {}; // 이전 가격 (교차 감지)
  static const Duration _rsiCheckCooldown = Duration(minutes: 30);

  /// 가격 돌파 체크
  List<RsiDivergenceAlert> checkBreakthroughs(
    Map<String, StockQuote> quotes,
    List<RsiWatchPoint> activePoints,
  ) {
    final alerts = <RsiDivergenceAlert>[];

    for (final point in activePoints) {
      final quote = quotes[point.ticker];
      if (quote == null || quote.currentPrice <= 0) continue;

      final currentPrice = quote.currentPrice;
      final previousPrice = _previousPrices[point.ticker];
      _previousPrices[point.ticker] = currentPrice;

      // 교차 감지 (관통 판정)
      final breached = _isBreached(point, currentPrice, previousPrice);
      if (!breached) continue;

      // 쿨다운 체크 (API 남용 방지)
      final cooldownKey = '${point.ticker}_${point.id}';
      if (_isInCooldown(cooldownKey)) continue;
      _cooldowns[cooldownKey] = DateTime.now();

      // 돌파 감지 -> RSI 체크 요청 알림 생성
      alerts.add(RsiDivergenceAlert(
        watchPoint: point,
        currentPrice: currentPrice,
        status: RsiAlertStatus.breached,
      ));
    }

    return alerts;
  }

  /// 돌파 감지: 처음 1회만 트리거
  /// - 첫 체크(previous == null): 이미 돌파 상태면 즉시 트리거 (과거 고점 설정 테스트용)
  /// - 이후: 교차 감지 (이전가 ≤ 감시가 → 현재가 > 감시가)
  bool _isBreached(RsiWatchPoint point, double current, double? previous) {
    if (point.mode == RsiWatchMode.bearish) {
      // 고점 감시: 현재가 > 감시가
      if (previous == null) return current > point.watchPrice;
      return previous <= point.watchPrice && current > point.watchPrice;
    } else {
      // 저점 감시: 현재가 < 감시가
      if (previous == null) return current < point.watchPrice;
      return previous >= point.watchPrice && current < point.watchPrice;
    }
  }

  bool _isInCooldown(String key) {
    final last = _cooldowns[key];
    if (last == null) return false;
    return DateTime.now().difference(last) < _rsiCheckCooldown;
  }
}

/// RsiDivergenceChecker 싱글톤 Provider
final rsiDivergenceCheckerProvider = Provider<RsiDivergenceChecker>((ref) {
  return RsiDivergenceChecker();
});

// ===============================================================
// RSI 다이버전스 감시 Provider
// (watchlistAlertMonitorProvider와 동일 패턴)
// ===============================================================

/// RSI 다이버전스 감시 Provider
///
/// stockQuoteProvider를 watch하여 가격 변동 시마다 돌파 체크.
/// 반환값: 돌파가 감지된 알림 리스트 (MainShell에서 비동기 RSI 계산 수행)
final rsiDivergenceMonitorProvider = Provider<List<RsiDivergenceAlert>>((ref) {
  final quoteState = ref.watch(stockQuoteProvider);
  final watchPointState = ref.watch(rsiWatchPointProvider);
  final checker = ref.read(rsiDivergenceCheckerProvider);

  // 활성 감시점이 없으면 빈 리스트
  final activePoints = watchPointState.points.where((p) => p.isActive).toList();
  if (activePoints.isEmpty) return [];
  if (quoteState.quotes.isEmpty) return [];

  return checker.checkBreakthroughs(quoteState.quotes, activePoints);
});
