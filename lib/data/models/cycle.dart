import 'package:hive/hive.dart';
import '../../core/constants/formula_constants.dart';
import '../../core/interfaces/strategy_position.dart';

part 'cycle.g.dart';

/// 사이클 상태
@HiveType(typeId: 10)
enum CycleStatus {
  /// 활성 상태 - 매매 진행 중
  @HiveField(0)
  active,
  /// 완료 - 익절 완료
  @HiveField(1)
  completed,
  /// 중단 - 사용자가 수동으로 종료
  @HiveField(2)
  cancelled,
}

/// 알파 사이클 모델
///
/// 하나의 종목에 대한 매매 사이클 정보를 담고 있습니다.
/// 핵심 개념:
/// - 초기 진입가: 첫 매수 시점의 가격 (고정, 절대 변하지 않음)
/// - 평균 단가: 추가 매수할 때마다 변동
/// - 손실률: 초기 진입가 기준
/// - 수익률: 평균 단가 기준
///
/// StrategyPosition 인터페이스를 구현하여 통합 포트폴리오 관리 및
/// 향후 다른 매매 전략과의 호환성을 제공합니다.
@HiveType(typeId: 1)
class Cycle extends HiveObject implements StrategyPosition {
  /// 고유 ID
  @HiveField(0)
  final String id;

  /// 종목 코드
  @HiveField(1)
  final String ticker;

  /// 사이클 번호 (1, 2, 3...)
  @HiveField(2)
  final int cycleNumber;

  /// 시드 금액 (원화)
  @HiveField(3)
  final double seedAmount;

  /// 초기 진입금 (원화) = 시드 × 0.20
  @HiveField(4)
  final double initialEntryAmount;

  /// 초기 진입가 (USD) - ⚠️ 고정값, 절대 변하지 않음
  @HiveField(5)
  final double initialEntryPrice;

  /// 평균 단가 (USD) - 추가 매수할 때마다 변동
  @HiveField(6)
  double averagePrice;

  /// 총 보유 수량
  @HiveField(7)
  double totalShares;

  /// 총 투자 금액 (원화) - 지금까지 매수에 사용한 금액
  @HiveField(8)
  double totalInvestedAmount;

  /// 잔여 현금 (원화)
  @HiveField(9)
  double remainingCash;

  /// 승부수 사용 여부 (사이클당 1회만)
  @HiveField(10)
  bool panicUsed;

  /// 사이클 상태
  @HiveField(11)
  CycleStatus status;

  /// 매수 시작점 (기본값: -20)
  @HiveField(12)
  final double buyTrigger;

  /// 익절 목표 (기본값: +20)
  @HiveField(13)
  final double sellTrigger;

  /// 승부수 발동점 (기본값: -50)
  @HiveField(14)
  final double panicTrigger;

  /// 사이클 시작일
  @HiveField(15)
  final DateTime startDate;

  /// 사이클 종료일 (익절 또는 취소 시 설정)
  @HiveField(16)
  DateTime? endDate;

  /// 환율 (원/달러)
  @HiveField(17)
  final double exchangeRate;

  Cycle({
    required this.id,
    required this.ticker,
    required this.cycleNumber,
    required this.seedAmount,
    required this.initialEntryPrice,
    required this.exchangeRate,
    this.buyTrigger = FormulaConstants.buyTriggerPercent,
    this.sellTrigger = FormulaConstants.sellTriggerPercent,
    this.panicTrigger = FormulaConstants.panicTriggerPercent,
    DateTime? startDate,
  })  : initialEntryAmount = seedAmount * FormulaConstants.initialEntryRatio,
        averagePrice = initialEntryPrice,
        totalShares = 0,
        totalInvestedAmount = 0,
        remainingCash = seedAmount, // ✅ 시드 전체가 현금으로 시작 (매수 시 차감됨)
        panicUsed = false,
        status = CycleStatus.active,
        startDate = startDate ?? DateTime.now();

  // ═══════════════════════════════════════════════════════════════
  // 계산 속성 (Computed Properties)
  // ═══════════════════════════════════════════════════════════════

  /// 손실률 (%) - 초기 진입가 기준
  /// 공식: (현재가 - 초기진입가) ÷ 초기진입가 × 100
  double lossRate(double currentPrice) {
    if (initialEntryPrice == 0) return 0;
    return ((currentPrice - initialEntryPrice) / initialEntryPrice) * 100;
  }

  /// 수익률 (%) - 평균 단가 기준
  /// 공식: (현재가 - 평균단가) ÷ 평균단가 × 100
  double returnRate(double currentPrice) {
    if (averagePrice == 0) return 0;
    return ((currentPrice - averagePrice) / averagePrice) * 100;
  }

  /// 주식 평가금 (원화)
  double stockValue(double currentPrice) {
    return totalShares * currentPrice * exchangeRate;
  }

  /// 총 자산 (원화) = 주식 평가금 + 잔여 현금
  double totalAsset(double currentPrice) {
    return stockValue(currentPrice) + remainingCash;
  }

  /// 전체 수익률 (%) - 시드 대비 총 자산
  double totalReturnRate(double currentPrice) {
    if (seedAmount == 0) return 0;
    return ((totalAsset(currentPrice) - seedAmount) / seedAmount) * 100;
  }

  /// 현금 비율 (%)
  double get cashRatio {
    if (seedAmount == 0) return 0;
    return (remainingCash / seedAmount) * 100;
  }

  // ═══════════════════════════════════════════════════════════════
  // 매매 신호 판단
  // ═══════════════════════════════════════════════════════════════

  /// 가중 매수 조건 충족 여부
  /// 조건: 손실률 <= buyTrigger (기본 -20%)
  bool shouldWeightedBuy(double currentPrice) {
    return lossRate(currentPrice) <= buyTrigger;
  }

  /// 승부수 조건 충족 여부
  /// 조건: 손실률 <= panicTrigger (기본 -50%) AND 미사용
  bool shouldPanicBuy(double currentPrice) {
    return lossRate(currentPrice) <= panicTrigger && !panicUsed;
  }

  /// 익절 조건 충족 여부
  /// 조건: 수익률 >= sellTrigger (기본 +20%)
  bool shouldTakeProfit(double currentPrice) {
    return returnRate(currentPrice) >= sellTrigger;
  }

  // ═══════════════════════════════════════════════════════════════
  // 매수 금액 계산
  // ═══════════════════════════════════════════════════════════════

  /// 가중 매수 금액 (원화)
  /// 공식: 초기진입금 × |손실률| ÷ 1000
  double weightedBuyAmount(double currentPrice) {
    final loss = lossRate(currentPrice).abs();
    return initialEntryAmount * loss / FormulaConstants.weightedBuyDivisor;
  }

  /// 승부수 금액 (원화)
  /// 공식: 초기진입금 × 0.50
  double get panicBuyAmount {
    return initialEntryAmount * FormulaConstants.panicBuyRatio;
  }

  /// 오늘 총 매수 금액 (원화)
  /// 승부수 조건 시: 승부수 + 가중 매수
  /// 가중 매수 조건 시: 가중 매수만
  double todayBuyAmount(double currentPrice) {
    if (!shouldWeightedBuy(currentPrice)) return 0;

    double amount = weightedBuyAmount(currentPrice);
    if (shouldPanicBuy(currentPrice)) {
      amount += panicBuyAmount;
    }
    return amount;
  }

  // ═══════════════════════════════════════════════════════════════
  // 상태 업데이트 메서드
  // ═══════════════════════════════════════════════════════════════

  /// 매수 후 상태 업데이트
  void recordBuy({
    required double price,
    required double shares,
    required double amountKrw,
    required bool isPanic,
  }) {
    // 총 보유 수량 증가
    totalShares += shares;

    // 총 투자 금액 증가
    totalInvestedAmount += amountKrw;

    // 잔여 현금 감소
    remainingCash -= amountKrw;

    // 평균 단가 재계산
    if (totalShares > 0) {
      averagePrice = (totalInvestedAmount / exchangeRate) / totalShares;
    }

    // 승부수 사용 표시
    if (isPanic) {
      panicUsed = true;
    }
  }

  /// 익절 (전량 매도) 후 상태 업데이트
  /// 주의: status는 변경하지 않음 → 사용자가 "완료(기록)" 버튼으로 직접 아카이브
  void recordTakeProfit(double sellPrice) {
    // 매도 금액을 잔여 현금에 추가
    final sellAmountKrw = totalShares * sellPrice * exchangeRate;
    remainingCash += sellAmountKrw;

    // 보유 수량 초기화
    totalShares = 0;
  }

  /// 사이클 아카이브 (완료 처리)
  void archive() {
    status = CycleStatus.completed;
    endDate = DateTime.now();
  }

  /// 사이클 취소
  void cancel() {
    status = CycleStatus.cancelled;
    endDate = DateTime.now();
  }

  // ═══════════════════════════════════════════════════════════════
  // StrategyPosition 인터페이스 구현
  // ═══════════════════════════════════════════════════════════════

  @override
  TradingStrategy get strategy => TradingStrategy.alphaCycle;

  @override
  bool get isStrategyActive => status == CycleStatus.active;

  @override
  String getSignal(double currentPrice) {
    if (shouldTakeProfit(currentPrice)) return 'takeProfit';
    if (shouldPanicBuy(currentPrice)) return 'panicBuy';
    if (shouldWeightedBuy(currentPrice)) return 'weightedBuy';
    return 'hold';
  }

  @override
  Map<String, dynamic> get strategyConfig => {
        'buyTrigger': buyTrigger,
        'sellTrigger': sellTrigger,
        'panicTrigger': panicTrigger,
        'panicUsed': panicUsed,
        'initialEntryPrice': initialEntryPrice,
        'seedAmount': seedAmount,
        'initialEntryAmount': initialEntryAmount,
      };

  @override
  String? getRecommendationMessage(double currentPrice) {
    final signal = getSignal(currentPrice);
    switch (signal) {
      case 'takeProfit':
        return '익절 권장: 수익률 ${returnRate(currentPrice).toStringAsFixed(1)}%';
      case 'panicBuy':
        return '승부수 매수 권장: ${_formatKrwWithComma(panicBuyAmount)}';
      case 'weightedBuy':
        final amount = weightedBuyAmount(currentPrice);
        return '가중 매수 권장: ${_formatKrwWithComma(amount)}';
      default:
        return null;
    }
  }

  /// 원화 포맷팅 (콤마 구분)
  String _formatKrwWithComma(double amount) {
    final intAmount = amount.round();
    final absAmount = intAmount.abs();
    final formatted = absAmount.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
    return intAmount < 0 ? '-$formatted원' : '$formatted원';
  }

  // TradingPosition 인터페이스의 currentValue (stockValue와 동일)
  @override
  double currentValue(double currentPrice) => stockValue(currentPrice);

  // TradingPosition 인터페이스의 profitLoss
  @override
  double profitLoss(double currentPrice) {
    return stockValue(currentPrice) - totalInvestedAmount;
  }

  // TradingPosition 인터페이스의 isEmpty/isActive
  @override
  bool get isEmpty => totalShares == 0;

  @override
  bool get isActive => totalShares > 0 && status == CycleStatus.active;

  @override
  String toString() {
    return 'Cycle(id: $id, ticker: $ticker, #$cycleNumber, '
        'seed: ${seedAmount.toStringAsFixed(0)}원, '
        'shares: ${totalShares.toStringAsFixed(2)}, '
        'avg: \$${averagePrice.toStringAsFixed(2)}, '
        'status: $status)';
  }
}
