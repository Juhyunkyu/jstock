import 'package:hive/hive.dart';
import '../../core/interfaces/trading_position.dart';

part 'cycle.g.dart';

@HiveType(typeId: 20)
enum StrategyType {
  @HiveField(0)
  alphaCycleV3,
  @HiveField(1)
  infiniteBuy,
}

@HiveType(typeId: 10)
enum CycleStatus {
  @HiveField(0)
  active,
  @HiveField(1)
  completed,
}

@HiveType(typeId: 1)
class Cycle extends HiveObject implements TradingPosition {
  // === 공통 필드 ===
  @HiveField(0)
  @override
  final String id;

  @HiveField(1)
  @override
  final String ticker;

  @HiveField(2)
  final String name;

  @HiveField(3, defaultValue: 0.0)
  double seedAmount;

  @HiveField(4, defaultValue: 0.0)
  @override
  double averagePrice;

  @HiveField(5, defaultValue: 0.0)
  @override
  double totalShares;

  @HiveField(6, defaultValue: 0.0)
  double remainingCash;

  @HiveField(7, defaultValue: CycleStatus.active)
  CycleStatus status;

  @HiveField(8)
  @override
  final DateTime startDate;

  @HiveField(9)
  DateTime updatedAt;

  @HiveField(10)
  double? completedReturnRate;

  @HiveField(11, defaultValue: 0.0)
  double exchangeRateAtEntry;

  @HiveField(12, defaultValue: StrategyType.alphaCycleV3)
  StrategyType strategyType;

  // === Strategy A: Alpha Cycle V3 전용 ===
  @HiveField(13)
  double? entryPrice;

  @HiveField(14, defaultValue: 0)
  int consecutiveProfitCount;

  @HiveField(15, defaultValue: false)
  bool panicBuyUsed;

  // === Strategy B: 순정 무한매수법 전용 ===
  @HiveField(16, defaultValue: 0)
  int roundsUsed;

  @HiveField(17, defaultValue: 40)
  int totalRounds;

  // === 커스텀 파라미터 (Strategy A) ===
  @HiveField(18, defaultValue: 0.20)
  double initialEntryRatio;

  @HiveField(19, defaultValue: -20.0)
  double weightedBuyThreshold;

  @HiveField(20, defaultValue: 1000.0)
  double weightedBuyDivisor;

  @HiveField(21, defaultValue: -50.0)
  double panicBuyThreshold;

  @HiveField(22, defaultValue: 0.50)
  double panicBuyMultiplier;

  @HiveField(23, defaultValue: 30.0)
  double firstProfitTarget;

  @HiveField(24, defaultValue: 5.0)
  double profitTargetStep;

  @HiveField(25, defaultValue: 10.0)
  double minProfitTarget;

  @HiveField(26, defaultValue: 0.3333)
  double cashSecureRatio;

  // === 커스텀 파라미터 (Strategy B) ===
  @HiveField(27, defaultValue: 10.0)
  double takeProfitPercent;

  // === 생성자 ===

  Cycle({
    required this.id,
    required this.ticker,
    required this.name,
    required this.seedAmount,
    required this.exchangeRateAtEntry,
    required this.strategyType,
    this.entryPrice,
    this.consecutiveProfitCount = 0,
    this.panicBuyUsed = false,
    this.roundsUsed = 0,
    this.totalRounds = 40,
    this.initialEntryRatio = 0.20,
    this.weightedBuyThreshold = -20.0,
    this.weightedBuyDivisor = 1000.0,
    this.panicBuyThreshold = -50.0,
    this.panicBuyMultiplier = 0.50,
    this.firstProfitTarget = 30.0,
    this.profitTargetStep = 5.0,
    this.minProfitTarget = 10.0,
    this.cashSecureRatio = 0.3333,
    this.takeProfitPercent = 10.0,
    this.completedReturnRate,
    DateTime? startDate,
  })  : averagePrice = 0,
       totalShares = 0,
       remainingCash = seedAmount,
       status = CycleStatus.active,
       startDate = startDate ?? DateTime.now(),
       updatedAt = DateTime.now();

  // === 계산 프로퍼티 ===

  /// 초기 진입금 (Strategy A)
  double get initialEntryAmount => seedAmount * initialEntryRatio;

  /// 분할 단위 금액 (Strategy B)
  double get unitAmount => totalRounds > 0 ? seedAmount / totalRounds : 0;

  /// 현재 익절 목표 (Strategy A)
  double get currentSellTarget {
    final target = firstProfitTarget - consecutiveProfitCount * profitTargetStep;
    return target < minProfitTarget ? minProfitTarget : target;
  }

  // === TradingPosition 구현 ===

  @override
  double get totalInvestedAmount => seedAmount - remainingCash;

  /// TradingPosition.exchangeRate -- 진입 시 환율 반환
  /// 주의: 포트폴리오 표시에서는 이 값 대신 라이브 환율을 사용해야 함
  @override
  double get exchangeRate => exchangeRateAtEntry;

  @override
  double currentValue(double currentPrice) {
    return totalShares * currentPrice * exchangeRate;
  }

  @override
  double profitLoss(double currentPrice) {
    return currentValue(currentPrice) - totalInvestedAmount;
  }

  @override
  double returnRate(double currentPrice) {
    if (totalInvestedAmount == 0) return 0;
    return (profitLoss(currentPrice) / totalInvestedAmount) * 100;
  }

  /// CycleStatus.active 기반 (TradingPosition.isActive의 "보유수량>0" 의미와 다름)
  @override
  bool get isActive => status == CycleStatus.active;

  @override
  bool get isEmpty => totalShares == 0;

  // === 직렬화 ===

  Map<String, dynamic> toJson() => {
    'id': id,
    'ticker': ticker,
    'name': name,
    'seedAmount': seedAmount,
    'averagePrice': averagePrice,
    'totalShares': totalShares,
    'remainingCash': remainingCash,
    'status': status.name,
    'startDate': startDate.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'completedReturnRate': completedReturnRate,
    'exchangeRateAtEntry': exchangeRateAtEntry,
    'strategyType': strategyType.name,
    'entryPrice': entryPrice,
    'consecutiveProfitCount': consecutiveProfitCount,
    'panicBuyUsed': panicBuyUsed,
    'roundsUsed': roundsUsed,
    'totalRounds': totalRounds,
    'initialEntryRatio': initialEntryRatio,
    'weightedBuyThreshold': weightedBuyThreshold,
    'weightedBuyDivisor': weightedBuyDivisor,
    'panicBuyThreshold': panicBuyThreshold,
    'panicBuyMultiplier': panicBuyMultiplier,
    'firstProfitTarget': firstProfitTarget,
    'profitTargetStep': profitTargetStep,
    'minProfitTarget': minProfitTarget,
    'cashSecureRatio': cashSecureRatio,
    'takeProfitPercent': takeProfitPercent,
  };

  factory Cycle.fromJson(Map<String, dynamic> json) {
    final cycle = Cycle(
      id: json['id'] as String,
      ticker: json['ticker'] as String,
      name: json['name'] as String,
      seedAmount: (json['seedAmount'] as num).toDouble(),
      exchangeRateAtEntry: (json['exchangeRateAtEntry'] as num).toDouble(),
      strategyType: StrategyType.values.byName(json['strategyType'] as String),
      entryPrice: (json['entryPrice'] as num?)?.toDouble(),
      consecutiveProfitCount: json['consecutiveProfitCount'] as int? ?? 0,
      panicBuyUsed: json['panicBuyUsed'] as bool? ?? false,
      roundsUsed: json['roundsUsed'] as int? ?? 0,
      totalRounds: json['totalRounds'] as int? ?? 40,
      initialEntryRatio: (json['initialEntryRatio'] as num?)?.toDouble() ?? 0.20,
      weightedBuyThreshold: (json['weightedBuyThreshold'] as num?)?.toDouble() ?? -20.0,
      weightedBuyDivisor: (json['weightedBuyDivisor'] as num?)?.toDouble() ?? 1000.0,
      panicBuyThreshold: (json['panicBuyThreshold'] as num?)?.toDouble() ?? -50.0,
      panicBuyMultiplier: (json['panicBuyMultiplier'] as num?)?.toDouble() ?? 0.50,
      firstProfitTarget: (json['firstProfitTarget'] as num?)?.toDouble() ?? 30.0,
      profitTargetStep: (json['profitTargetStep'] as num?)?.toDouble() ?? 5.0,
      minProfitTarget: (json['minProfitTarget'] as num?)?.toDouble() ?? 10.0,
      cashSecureRatio: (json['cashSecureRatio'] as num?)?.toDouble() ?? 0.3333,
      takeProfitPercent: (json['takeProfitPercent'] as num?)?.toDouble() ?? 10.0,
    );
    // 저장된 상태 복원 (생성자 기본값 덮어쓰기)
    cycle.averagePrice = (json['averagePrice'] as num?)?.toDouble() ?? 0;
    cycle.totalShares = (json['totalShares'] as num?)?.toDouble() ?? 0;
    cycle.remainingCash = (json['remainingCash'] as num).toDouble();
    cycle.status = CycleStatus.values.byName(json['status'] as String);
    cycle.updatedAt = json['updatedAt'] != null
        ? DateTime.parse(json['updatedAt'] as String)
        : DateTime.now();
    cycle.completedReturnRate = (json['completedReturnRate'] as num?)?.toDouble();
    return cycle;
  }

  @override
  String toString() {
    return 'Cycle(id: $id, ticker: $ticker, strategy: ${strategyType.name}, '
        'shares: ${totalShares.toStringAsFixed(2)}, '
        'avg: \$${averagePrice.toStringAsFixed(2)}, '
        'cash: ${remainingCash.toStringAsFixed(0)}KRW)';
  }
}
