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

@HiveType(typeId: 24)
enum SteadyVersion {
  @HiveField(0)
  v1,
  @HiveField(1)
  v2_2,
  @HiveField(2)
  v3_0,
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

  @HiveField(20, defaultValue: 0.0)
  double weightedBuyPerPercent;   // 0 = auto-calc (seedAmount × 0.00007)

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

  // === 별명 ===
  @HiveField(28, defaultValue: '')
  String nickname;

  // === Strategy B: Steady V2.2/V3.0 추가 필드 ===
  @HiveField(29, defaultValue: SteadyVersion.v1)
  SteadyVersion steadyVersion;

  @HiveField(30, defaultValue: 0.25)
  double sellQuarterPercent;

  @HiveField(31, defaultValue: false)
  bool compoundEnabled;

  // === V3.0 오프셋 프리셋 (a - b × T) ===
  @HiveField(32, defaultValue: 15.0)
  double offsetA;

  @HiveField(33, defaultValue: 1.5)
  double offsetB;

  @HiveField(34, defaultValue: -15.0)
  double quarterModeOffset;

  // === 쿼터 손절모드 상태 ===
  @HiveField(35, defaultValue: false)
  bool isQuarterStopLossMode;

  @HiveField(36, defaultValue: 0)
  int quarterStopLossRoundsUsed;

  // === 집계 필드 (거래 재계산 시 자동 업데이트) ===
  @HiveField(37, defaultValue: 0.0)
  double totalBuyAmountKrw;

  @HiveField(38, defaultValue: 0.0)
  double totalSellAmountKrw;

  @HiveField(39)
  DateTime? firstTradeDate;

  @HiveField(40)
  DateTime? lastTradeDate;

  @HiveField(41, defaultValue: 0.0)
  double totalBuyUsd;

  @HiveField(42, defaultValue: 0.0)
  double totalSellUsd;

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
    this.weightedBuyPerPercent = 0.0,
    this.panicBuyThreshold = -50.0,
    this.panicBuyMultiplier = 0.50,
    this.firstProfitTarget = 30.0,
    this.profitTargetStep = 5.0,
    this.minProfitTarget = 10.0,
    this.cashSecureRatio = 0.3333,
    this.takeProfitPercent = 10.0,
    this.nickname = '',
    this.steadyVersion = SteadyVersion.v1,
    this.sellQuarterPercent = 0.25,
    this.compoundEnabled = false,
    this.offsetA = 15.0,
    this.offsetB = 1.5,
    this.quarterModeOffset = -15.0,
    this.isQuarterStopLossMode = false,
    this.quarterStopLossRoundsUsed = 0,
    this.totalBuyAmountKrw = 0.0,
    this.totalSellAmountKrw = 0.0,
    this.firstTradeDate,
    this.lastTradeDate,
    this.totalBuyUsd = 0.0,
    this.totalSellUsd = 0.0,
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

  /// 가중매수 1%당 금액. 0이면 seedAmount 기반 자동 계산
  double get effectiveWeightedBuyPerPercent =>
      weightedBuyPerPercent > 0 ? weightedBuyPerPercent : seedAmount * 0.00007;

  /// 분할 단위 금액 (Strategy B)
  double get unitAmount => totalRounds > 0 ? seedAmount / totalRounds : 0;

  /// 전반전 여부 (V2.2: T<20, V3.0: T<10)
  bool isFirstHalfWith(double tValue) {
    switch (steadyVersion) {
      case SteadyVersion.v1: return true;
      case SteadyVersion.v2_2: return tValue < 20;
      case SteadyVersion.v3_0: return tValue < 10;
    }
  }

  /// 쿼터모드 여부
  bool isQuarterModeWith(double tValue) {
    switch (steadyVersion) {
      case SteadyVersion.v1: return false;
      case SteadyVersion.v2_2: return tValue >= 39.1;
      case SteadyVersion.v3_0: return tValue > 19 && tValue < 20;
    }
  }

  /// LOC 가격 오프셋(%) — V2.2/V3.0 통일: offsetA - offsetB × T
  double locOffsetPercentWith(double tValue) {
    if (steadyVersion == SteadyVersion.v1) return 0;
    return offsetA - offsetB * tValue;
  }

  /// LOC 매수/매도 가격 (USD)
  double locPriceWith(double tValue) =>
      averagePrice * (1 + locOffsetPercentWith(tValue) / 100);

  /// LOC 매수 가격 (-$0.01 조정, 매도와 겹침 방지)
  double locBuyPriceWith(double tValue) => locPriceWith(tValue) - 0.01;

  /// 지정가 매도 가격 (USD)
  double get limitSellPrice => averagePrice * (1 + takeProfitPercent / 100);

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

  /// 전량 매도 완료 대기 (shares==0, 거래 내역 있음, 아직 active)
  bool get isPendingCompletion =>
      totalShares == 0 && status == CycleStatus.active && seedAmount != remainingCash;

  /// 전량 매도 후 실현 순수익 (매도총액 - 매수총액)
  double get realizedProfitKrw => totalSellAmountKrw - totalBuyAmountKrw;

  /// 전량 매도 후 수익률 (매수총액 대비)
  double get realizedProfitRate {
    if (totalBuyAmountKrw <= 0) return 0;
    return (realizedProfitKrw / totalBuyAmountKrw) * 100;
  }

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
    'weightedBuyPerPercent': weightedBuyPerPercent,
    'panicBuyThreshold': panicBuyThreshold,
    'panicBuyMultiplier': panicBuyMultiplier,
    'firstProfitTarget': firstProfitTarget,
    'profitTargetStep': profitTargetStep,
    'minProfitTarget': minProfitTarget,
    'cashSecureRatio': cashSecureRatio,
    'takeProfitPercent': takeProfitPercent,
    'nickname': nickname,
    'steadyVersion': steadyVersion.name,
    'sellQuarterPercent': sellQuarterPercent,
    'compoundEnabled': compoundEnabled,
    'offsetA': offsetA,
    'offsetB': offsetB,
    'quarterModeOffset': quarterModeOffset,
    'isQuarterStopLossMode': isQuarterStopLossMode,
    'quarterStopLossRoundsUsed': quarterStopLossRoundsUsed,
    'totalBuyAmountKrw': totalBuyAmountKrw,
    'totalSellAmountKrw': totalSellAmountKrw,
    'firstTradeDate': firstTradeDate?.toIso8601String(),
    'lastTradeDate': lastTradeDate?.toIso8601String(),
    'totalBuyUsd': totalBuyUsd,
    'totalSellUsd': totalSellUsd,
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
      weightedBuyPerPercent: (json['weightedBuyPerPercent'] as num?)?.toDouble() ?? 0.0,
      panicBuyThreshold: (json['panicBuyThreshold'] as num?)?.toDouble() ?? -50.0,
      panicBuyMultiplier: (json['panicBuyMultiplier'] as num?)?.toDouble() ?? 0.50,
      firstProfitTarget: (json['firstProfitTarget'] as num?)?.toDouble() ?? 30.0,
      profitTargetStep: (json['profitTargetStep'] as num?)?.toDouble() ?? 5.0,
      minProfitTarget: (json['minProfitTarget'] as num?)?.toDouble() ?? 10.0,
      cashSecureRatio: (json['cashSecureRatio'] as num?)?.toDouble() ?? 0.3333,
      takeProfitPercent: (json['takeProfitPercent'] as num?)?.toDouble() ?? 10.0,
      nickname: json['nickname'] as String? ?? '',
      steadyVersion: _parseSteadyVersion(json['steadyVersion'] as String?),
      sellQuarterPercent: (json['sellQuarterPercent'] as num?)?.toDouble() ?? 0.25,
      compoundEnabled: json['compoundEnabled'] as bool? ?? false,
      offsetA: (json['offsetA'] as num?)?.toDouble() ?? 15.0,
      offsetB: (json['offsetB'] as num?)?.toDouble() ?? 1.5,
      quarterModeOffset: (json['quarterModeOffset'] as num?)?.toDouble() ?? -15.0,
      isQuarterStopLossMode: json['isQuarterStopLossMode'] as bool? ?? false,
      quarterStopLossRoundsUsed: json['quarterStopLossRoundsUsed'] as int? ?? 0,
      totalBuyAmountKrw: (json['totalBuyAmountKrw'] as num?)?.toDouble() ?? 0.0,
      totalSellAmountKrw: (json['totalSellAmountKrw'] as num?)?.toDouble() ?? 0.0,
      firstTradeDate: json['firstTradeDate'] != null ? DateTime.parse(json['firstTradeDate'] as String) : null,
      lastTradeDate: json['lastTradeDate'] != null ? DateTime.parse(json['lastTradeDate'] as String) : null,
      totalBuyUsd: (json['totalBuyUsd'] as num?)?.toDouble() ?? 0.0,
      totalSellUsd: (json['totalSellUsd'] as num?)?.toDouble() ?? 0.0,
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

  static SteadyVersion _parseSteadyVersion(String? value) {
    if (value == null) return SteadyVersion.v1;
    try {
      return SteadyVersion.values.byName(value);
    } catch (_) {
      return SteadyVersion.v1;
    }
  }

  Cycle copyWith({
    String? id,
    String? ticker,
    String? name,
    double? seedAmount,
    double? averagePrice,
    double? totalShares,
    double? remainingCash,
    CycleStatus? status,
    DateTime? startDate,
    DateTime? updatedAt,
    double? completedReturnRate,
    double? exchangeRateAtEntry,
    StrategyType? strategyType,
    double? entryPrice,
    int? consecutiveProfitCount,
    bool? panicBuyUsed,
    int? roundsUsed,
    int? totalRounds,
    double? initialEntryRatio,
    double? weightedBuyThreshold,
    double? weightedBuyPerPercent,
    double? panicBuyThreshold,
    double? panicBuyMultiplier,
    double? firstProfitTarget,
    double? profitTargetStep,
    double? minProfitTarget,
    double? cashSecureRatio,
    double? takeProfitPercent,
    String? nickname,
    SteadyVersion? steadyVersion,
    double? sellQuarterPercent,
    bool? compoundEnabled,
    double? offsetA,
    double? offsetB,
    double? quarterModeOffset,
    bool? isQuarterStopLossMode,
    int? quarterStopLossRoundsUsed,
    double? totalBuyAmountKrw,
    double? totalSellAmountKrw,
    DateTime? firstTradeDate,
    DateTime? lastTradeDate,
    double? totalBuyUsd,
    double? totalSellUsd,
  }) {
    final cycle = Cycle(
      id: id ?? this.id,
      ticker: ticker ?? this.ticker,
      name: name ?? this.name,
      seedAmount: seedAmount ?? this.seedAmount,
      exchangeRateAtEntry: exchangeRateAtEntry ?? this.exchangeRateAtEntry,
      strategyType: strategyType ?? this.strategyType,
      entryPrice: entryPrice ?? this.entryPrice,
      consecutiveProfitCount: consecutiveProfitCount ?? this.consecutiveProfitCount,
      panicBuyUsed: panicBuyUsed ?? this.panicBuyUsed,
      roundsUsed: roundsUsed ?? this.roundsUsed,
      totalRounds: totalRounds ?? this.totalRounds,
      initialEntryRatio: initialEntryRatio ?? this.initialEntryRatio,
      weightedBuyThreshold: weightedBuyThreshold ?? this.weightedBuyThreshold,
      weightedBuyPerPercent: weightedBuyPerPercent ?? this.weightedBuyPerPercent,
      panicBuyThreshold: panicBuyThreshold ?? this.panicBuyThreshold,
      panicBuyMultiplier: panicBuyMultiplier ?? this.panicBuyMultiplier,
      firstProfitTarget: firstProfitTarget ?? this.firstProfitTarget,
      profitTargetStep: profitTargetStep ?? this.profitTargetStep,
      minProfitTarget: minProfitTarget ?? this.minProfitTarget,
      cashSecureRatio: cashSecureRatio ?? this.cashSecureRatio,
      takeProfitPercent: takeProfitPercent ?? this.takeProfitPercent,
      nickname: nickname ?? this.nickname,
      steadyVersion: steadyVersion ?? this.steadyVersion,
      sellQuarterPercent: sellQuarterPercent ?? this.sellQuarterPercent,
      compoundEnabled: compoundEnabled ?? this.compoundEnabled,
      offsetA: offsetA ?? this.offsetA,
      offsetB: offsetB ?? this.offsetB,
      quarterModeOffset: quarterModeOffset ?? this.quarterModeOffset,
      isQuarterStopLossMode: isQuarterStopLossMode ?? this.isQuarterStopLossMode,
      quarterStopLossRoundsUsed: quarterStopLossRoundsUsed ?? this.quarterStopLossRoundsUsed,
      totalBuyAmountKrw: totalBuyAmountKrw ?? this.totalBuyAmountKrw,
      totalBuyUsd: totalBuyUsd ?? this.totalBuyUsd,
      totalSellUsd: totalSellUsd ?? this.totalSellUsd,
      totalSellAmountKrw: totalSellAmountKrw ?? this.totalSellAmountKrw,
      firstTradeDate: firstTradeDate ?? this.firstTradeDate,
      lastTradeDate: lastTradeDate ?? this.lastTradeDate,
      completedReturnRate: completedReturnRate ?? this.completedReturnRate,
      startDate: startDate ?? this.startDate,
    );
    // 생성자 기본값을 덮어쓰는 mutable 필드 복원
    cycle.averagePrice = averagePrice ?? this.averagePrice;
    cycle.totalShares = totalShares ?? this.totalShares;
    cycle.remainingCash = remainingCash ?? this.remainingCash;
    cycle.status = status ?? this.status;
    cycle.updatedAt = updatedAt ?? this.updatedAt;
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

/// 사이클 표시명 계산
/// - nickname이 있으면 → nickname 반환
/// - 같은 티커가 2개 이상이면 → '#N' 반환 (생성순서 기준)
/// - 같은 티커가 1개면 → null 반환 (추가 라벨 불필요)
String? cycleDisplayLabel(Cycle cycle, List<Cycle> allActiveCycles) {
  if (cycle.nickname.isNotEmpty) return cycle.nickname;

  final sameTicker = allActiveCycles
      .where((c) => c.ticker == cycle.ticker)
      .toList()
    ..sort((a, b) => a.startDate.compareTo(b.startDate));

  if (sameTicker.length < 2) return null;

  final index = sameTicker.indexWhere((c) => c.id == cycle.id);
  if (index < 0) return null;
  return '#${index + 1}';
}
