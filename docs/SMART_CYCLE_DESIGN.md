# Smart Cycle 설계서

**문서 버전**: 1.0 (ALPHA_CYCLE_V3_DESIGN.md v7.0에서 분리)
**작성일**: 2026-03-13
**앱 표시명**: Smart Cycle (내부 enum: CycleStrategy.alphaCycleV3)

> Steady Cycle은 별도 문서 참조: `STEADY_CYCLE_DESIGN.md`

---

## 1. 개요

Smart Cycle (Alpha Cycle V3)은 레버리지 ETF(TQQQ, SOXL 등)를 위한 **방어적(Defensive) 매매 전략**이다.

| 구분 | Smart Cycle (Alpha Cycle V3) |
|------|---------------------------|
| 성격 | 방어적 (Defensive) |
| 목표 | 낮은 MDD, 현금 보존 |
| 복잡도 | 5종 신호 체계 |
| 익절 | 연속 감소 (30→25→20→15→10%) |
| 현금 관리 | 현금확보 매도 규칙 |
| 적합 대상 | 변동성 큰 시장, 자본 보존 우선 |

---

## 2. 용어 정의

| 용어 | 영문 | 정의 |
|------|------|------|
| 시드 금액 | seedAmount | 사이클에 배정한 총 투자 금액 (KRW) |
| 초기 진입금 | initialEntryAmount | seedAmount x initialEntryRatio |
| 초기 진입가 | entryPrice | 첫 매수 시점의 주가 (USD, 이후 고정) |
| 평균 단가 | averagePrice | 총매수금액(KRW) / 총보유수량 기준 역산 USD 가격 |
| 잔여 현금 | remainingCash | 시드 중 미투자 현금 (KRW) |
| 평가 금액 | evaluatedAmount | totalShares x currentPrice x exchangeRate (KRW) |
| 총 자산 | totalAssets | evaluatedAmount + remainingCash |
| 손실률 | lossRate | (currentPrice - entryPrice) / entryPrice x 100 |
| 수익률 | returnRate | (currentPrice - averagePrice) / averagePrice x 100 |

---

## 3. 커스텀 파라미터

| 파라미터 | 기본값 | 설명 | 허용 범위 |
|----------|--------|------|-----------|
| initialEntryRatio | 0.20 (20%) | 시드 대비 초기 진입 비율 | 0.05 ~ 0.50 |
| weightedBuyThreshold | -20% | 가중매수 발동 손실률 | -50% ~ -5% |
| weightedBuyPerPercent | seedAmount × 0.00007 | 1%당 가중매수 금액 (KRW) | 시드 비례 자동계산, 수동 조절 가능 |
| panicBuyThreshold | -50% | 승부수 발동 손실률 | -80% ~ -30% |
| panicBuyMultiplier | 0.50 (50%) | 승부수 금액 배수 (평가금액 기준) | 0.10 ~ 1.00 |
| firstProfitTarget | 30% | 첫 익절 목표 수익률 | 10% ~ 50% |
| profitTargetStep | 5%p | 연속 익절 시 감소폭 | 1%p ~ 10%p |
| minProfitTarget | 10% | 익절 목표 하한 | 3% ~ 20% |
| cashSecureRatio | 1/3 (33.3%) | 현금확보 목표 비율 | 0.10 ~ 0.50 |

---

## 4. 공식

### 4.1 초기 진입

```
initialEntryAmount = seedAmount x initialEntryRatio
remainingCash = seedAmount - initialEntryAmount
```

### 4.2 손실률 / 수익률

#### 손실률 (가중매수/승부수 조건)

```
lossRate(%) = (currentPrice - entryPrice) / entryPrice x 100
```

기준: entryPrice (고정, 추가 매수해도 불변)
**Zero-guard**: entryPrice가 null이거나 0이면 lossRate = 0 반환 (초기 진입 전 상태)

#### 수익률 (익절/현금확보 조건)

```
returnRate(%) = (currentPrice - averagePrice) / averagePrice x 100
```

기준: averagePrice (매수할 때마다 변동)
**Zero-guard**: averagePrice가 0이면 returnRate = 0 반환 (보유 수량 없는 상태)

### 4.3 가중 매수 (v7.0)

조건: lossRate <= weightedBuyThreshold (기본 -20%)

```
weightedBuyAmount(KRW) = |lossRate| × weightedBuyPerPercent
actualBuyAmount = min(weightedBuyAmount, remainingCash)  // 현금 부족 시 잔액만큼만
```

remainingCash <= 0이면 매수 신호 발동하지 않음.

`weightedBuyPerPercent` 기본값 = seedAmount × 0.00007 (시드 비례):

| 시드 금액 | weightedBuyPerPercent (기본) | -20% 매수 | -23% 매수 | -30% 매수 | -50% 매수 |
|-----------|---------------------------|----------|----------|----------|----------|
| 5천만 | 3,500원 | 7만원 | 8.1만원 | 10.5만원 | 17.5만원 |
| **1억** | **7,000원** | **14만원** | **16.1만원** | **21만원** | **35만원** |
| 2억 | 14,000원 | 28만원 | 32.2만원 | 42만원 | 70만원 |

> **v6.1→v7.0 변경**: 기존 공식 `initialEntryAmount × |lossRate| / weightedBuyDivisor(1000)`는 원본 전략(평단추격매매법) 대비 약 2.86배 과다 매수였음. v7.0에서 원본 공식 `|lossRate| × weightedBuyPerPercent`로 수정. 1억 기준 -1%당 7,000원이 정석.

### 4.4 승부수 (V3)

조건: lossRate <= panicBuyThreshold (기본 -50%) AND 미사용 상태

```
V3 공식 (원본 전략, 동적):
panicBuyAmount(KRW) = evaluatedAmount x panicBuyMultiplier
                    = (totalShares x currentPrice x exchangeRate) x 0.50

V2 공식 (기존 앱, 폐기):
panicBuyAmount(KRW) = initialEntryAmount x 0.50  <-- 고정값, 안전장치 없음
```

V3는 **현재 평가금액 기준**(동적)이므로 주가가 크게 떨어지면 승부수 금액도 줄어든다. 하락장에서 현금을 더 보존하는 안전장치.

| 시드 | 초기진입 | 현재 평가금액 | V2 승부수 | V3 승부수 |
|------|---------|-------------|----------|----------|
| 1억 | 2000만 | 1000만 (50% 하락) | 1000만 | **500만** |
| 1억 | 2000만 | 600만 (70% 하락) | 1000만 | **300만** |

승부수 발동일에도 가중매수는 **동시 실행**:

```
총 매수 = min(panicBuyAmount + weightedBuyAmount, remainingCash)
```

### 4.5 익절 (연속 감소)

조건: returnRate >= sellTarget%

```
sellTarget(%) = max(minProfitTarget, firstProfitTarget - consecutiveProfitCount x profitTargetStep)

  consecutiveProfitCount = 이전 사이클들에서 누적된 연속 익절 횟수
  count=0 (신규): max(10, 30 - 0x5) = 30%
  count=1 (1회 익절 후): max(10, 30 - 1x5) = 25%
  count=2 (2회 익절 후): max(10, 30 - 2x5) = 20%
  count=3 (3회 익절 후): max(10, 30 - 3x5) = 15%
  count=4+ (4회 이상): max(10, 30 - 4x5) = 10% (하한)
```

> **이전 공식 오류 수정 (v5.0→v6.0)**: `(N-1)` 대신 `N`을 사용. consecutiveProfitCount는 "완료된 익절 횟수"를 의미하며, 현재 사이클의 목표는 그 횟수에 비례하여 감소한다.

익절 후 처리:
1. 전량 매도
2. 새 시드 = 매도금액 + 잔여현금
3. 새 사이클 생성 (consecutiveProfitCount = 이전값 + 1 이월)
4. panicBuyUsed 초기화

연속 익절 리셋: 수동 손절(사이클 종료) 시 consecutiveProfitCount = 0

### 4.6 현금 확보 (V3)

조건: returnRate >= 0% AND remainingCash < totalAssets x cashSecureRatio AND totalShares > 0 AND currentPrice > 0

```
목표 현금 = totalAssets x cashSecureRatio
부족분    = 목표현금 - remainingCash
매도 금액 = 부족분 (KRW)
매도 수량 = 매도금액 / (currentPrice x exchangeRate)
```

가중매수로 현금이 줄어든 상태에서 가격이 회복되면(수익률 >= 0%), 추가 하락에 대비하여 현금을 확보. 전량 매도가 아닌 일부 매도.

---

## 5. 신호 체계 (5단계 우선순위)

```
우선순위 (높은 -> 낮은):

1. TAKE_PROFIT    — returnRate >= sellTarget%
2. CASH_SECURE    — returnRate >= 0% AND cashRatio < cashSecureRatio AND totalShares > 0
3. PANIC_BUY      — lossRate <= panicBuyThreshold AND !panicBuyUsed AND remainingCash > 0
4. WEIGHTED_BUY   — lossRate <= weightedBuyThreshold AND remainingCash > 0
5. HOLD           — 그 외 (대기)
```

> **승부수+가중매수 동시 실행**: detectSignal()이 PANIC_BUY를 반환하면, calculateBuyAmount()에서 panicBuyAmount + weightedBuyAmount 합산 금액을 반환한다. 별도의 WEIGHTED_BUY 신호는 발생하지 않음.

```dart
TradeSignal detectAlphaCycleSignal({
  required Cycle cycle,
  required double currentPrice,
  required double liveExchangeRate,
}) {
  if (cycle.entryPrice == null || cycle.entryPrice == 0) return TradeSignal.hold;
  if (cycle.averagePrice == 0) return TradeSignal.hold;

  final loss = TradingMath.lossRate(currentPrice, cycle.entryPrice!);
  final ret = TradingMath.returnRate(currentPrice, cycle.averagePrice);
  final evalAmt = TradingMath.evaluatedAmount(cycle.totalShares, currentPrice, liveExchangeRate);
  final totalAssets = evalAmt + cycle.remainingCash;
  final cashRatio = totalAssets > 0 ? cycle.remainingCash / totalAssets : 1.0;

  if (ret >= cycle.currentSellTarget) return TradeSignal.takeProfit;
  if (ret >= 0 && cashRatio < cycle.cashSecureRatio && cycle.totalShares > 0) return TradeSignal.cashSecure;
  if (loss <= cycle.panicBuyThreshold && !cycle.panicBuyUsed && cycle.remainingCash > 0) return TradeSignal.panicBuy;
  if (loss <= cycle.weightedBuyThreshold && cycle.remainingCash > 0) return TradeSignal.weightedBuy;
  return TradeSignal.hold;
}
```

| 신호 | 색상 | 표시 내용 |
|------|------|----------|
| TAKE_PROFIT | green | "익절 신호! 전량 매도 (목표 {target}%)" |
| CASH_SECURE | amber | "현금 확보 필요 (현금비율 {ratio}% < 33%)" + 매도 금액 |
| PANIC_BUY | red | "승부수! {금액}원 매수 (승부수+가중매수 합산)" |
| WEIGHTED_BUY | blue | "가중 매수 {금액}원" |
| HOLD | gray | "대기 (손실률 {loss}%)" |

---

## 6. 매매 플로우

```
사이클 시작
  |
  v
1. 초기 진입: 시드 x initialEntryRatio로 첫 매수
   entryPrice = 이때 가격 (이후 고정)
  |
  v
2. 매일 체크 (신호 우선순위)
  |
  +-- (1) returnRate >= sellTarget?
  |     YES -> 익절! 전량 매도 -> 새 사이클
  |            consecutiveProfitCount 이월 (이전+1)
  |            sellTarget 감소 (30->25->20->15->10%)
  |
  +-- (2) returnRate >= 0% AND cashRatio < 33%?
  |     YES -> 현금 확보 매도 (일부)
  |
  +-- (3) lossRate <= -50% AND !panicBuyUsed AND cash > 0?
  |     YES -> 승부수 (평가금액x50%) + 가중매수 합산
  |            panicBuyUsed = true
  |
  +-- (4) lossRate <= -20% AND cash > 0?
  |     YES -> 가중 매수 (|손실률|×perPercentAmount, 잔액 한도)
  |
  +-- (5) 그 외 -> 대기
  |
  v
3. 수동 조작 (언제든 가능)
   - 수동 매수/매도
   - 사이클 완료 -> 거래내역으로 이동
   - 사이클 삭제

> **수동 거래 시 remainingCash 안전 장치**: 수동 매수 금액이 remainingCash를 초과할 수 있으므로, 거래 처리 후 `cycle.remainingCash = cycle.remainingCash.clamp(0.0, double.infinity).toDouble()` 적용. 음수 현금은 허용하지 않는다.
```

---

## 7. 데이터 모델 (Cycle 모델 Smart 전용 필드)

Cycle 모델은 두 전략을 하나로 통합하며, `strategyType` 필드로 분기한다. 아래는 Smart Cycle 전용 필드 설명이다.

### Smart Cycle 전용 필드

```dart
// === Strategy A: Alpha Cycle V3 전용 ===
@HiveField(13) double? entryPrice;                                    // 초기 진입가 (USD, 고정)
@HiveField(14, defaultValue: 0) int consecutiveProfitCount;           // 연속 익절 횟수
@HiveField(15, defaultValue: false) bool panicBuyUsed;                // 승부수 사용 여부
```

### Smart Cycle 커스텀 파라미터 필드

```dart
// === 커스텀 파라미터 (Strategy A) ===
@HiveField(18, defaultValue: 0.20) double initialEntryRatio;
@HiveField(19, defaultValue: -20.0) double weightedBuyThreshold;
@HiveField(20, defaultValue: 0.0) double weightedBuyPerPercent;    // 기본값 0 = 사이클 생성 시 seedAmount × 0.00007로 계산
@HiveField(21, defaultValue: -50.0) double panicBuyThreshold;
@HiveField(22, defaultValue: 0.50) double panicBuyMultiplier;
@HiveField(23, defaultValue: 30.0) double firstProfitTarget;
@HiveField(24, defaultValue: 5.0) double profitTargetStep;
@HiveField(25, defaultValue: 10.0) double minProfitTarget;
@HiveField(26, defaultValue: 0.3333) double cashSecureRatio;
```

### 계산 프로퍼티

```dart
/// 초기 진입금 (Strategy A)
double get initialEntryAmount => seedAmount * initialEntryRatio;

/// 현재 익절 목표 (Strategy A) — v6.0 공식 수정
double get currentSellTarget {
  final target = firstProfitTarget - consecutiveProfitCount * profitTargetStep;
  return target < minProfitTarget ? minProfitTarget : target;
}
```

### Smart Cycle 전용 TradeSignal enum 값

```dart
@HiveField(0) initial,        // 초기 진입
@HiveField(1) weightedBuy,    // 가중 매수
@HiveField(2) panicBuy,       // 승부수
@HiveField(3) cashSecure,     // 현금 확보
@HiveField(4) takeProfit,     // 익절 (공통)
```

### consecutiveProfitCount 이월 로직

익절 후 새 사이클 생성 시 연속 익절 횟수를 이월해야 한다:

```dart
// cycle_providers.dart — 익절 처리
Future<void> completeTakeProfit(String cycleId, double sellAmountKrw) async {
  final cycle = getCycle(cycleId);
  final newSeed = sellAmountKrw + cycle.remainingCash;
  final carryOverCount = cycle.consecutiveProfitCount + 1;

  // 기존 사이클 완료 처리
  cycle.status = CycleStatus.completed;
  cycle.completedReturnRate = TradingMath.returnRate(currentPrice, cycle.averagePrice);
  cycle.updatedAt = DateTime.now();
  await cycleRepo.save(cycle);

  // 새 사이클 생성 (연속 익절 횟수 이월)
  final newCycle = Cycle(
    id: uuid.v4(),
    ticker: cycle.ticker,
    name: cycle.name,
    seedAmount: newSeed,
    exchangeRateAtEntry: currentExchangeRate,
    strategyType: cycle.strategyType,
    consecutiveProfitCount: carryOverCount,  // 핵심: 이월
    // 커스텀 파라미터 복사
    initialEntryRatio: cycle.initialEntryRatio,
    weightedBuyThreshold: cycle.weightedBuyThreshold,
    weightedBuyPerPercent: cycle.weightedBuyPerPercent,
    panicBuyThreshold: cycle.panicBuyThreshold,
    panicBuyMultiplier: cycle.panicBuyMultiplier,
    firstProfitTarget: cycle.firstProfitTarget,
    profitTargetStep: cycle.profitTargetStep,
    minProfitTarget: cycle.minProfitTarget,
    cashSecureRatio: cycle.cashSecureRatio,
  );
  await cycleRepo.add(newCycle);
}
```

> **리셋 조건**: 사용자가 수동으로 사이클을 종료(손절)하면 `consecutiveProfitCount = 0`으로 리셋.
> 새 사이클을 수동 생성하면 기본값 0부터 시작.

---

## 8. 백테스트 결과

### 8.1 2025 상승장 (4월 -50% 급락 포함)

#### TQQQ ($39.31 -> $52.72, +34%)

| 전략 | 수익률 | MDD | 사이클 수 |
|------|--------|-----|----------|
| Smart Cycle (Alpha Cycle V3) | +16.85% | -15.22% | 1 |
| Buy & Hold | +34.10% | -56.97% | - |

#### SOXL ($27.67 -> $42.03, +52%)

| 전략 | 수익률 | MDD | 사이클 수 |
|------|--------|-----|----------|
| Smart Cycle (Alpha Cycle V3) | +21.67% | -29.03% | 1 |
| Buy & Hold | +51.90% | -76.53% | - |

분석: 상승장에서 Smart Cycle은 MDD를 절반 이하로 억제하는 대신 수익률을 희생한다.

### 8.2 2022 하락장

#### TQQQ ($42.78 -> $8.65, -80%)

| 전략 | 수익률 | MDD | 사이클 수 |
|------|--------|-----|----------|
| Smart Cycle (Alpha Cycle V3) | -62.62% | -67.80% | 0 |
| Buy & Hold | -79.78% | -81.11% | - |

#### SOXL ($72.10 -> $9.67, -87%)

| 전략 | 수익률 | MDD | 사이클 수 |
|------|--------|-----|----------|
| Smart Cycle (Alpha Cycle V3) | -72.64% | -81.13% | 0 |
| Buy & Hold | -86.59% | -90.39% | - |

분석: 순수 하락장에서는 모든 전략이 손실. 하지만 Smart Cycle이 MDD와 최종 손실 모두 가장 적다. 현금확보 규칙과 동적 승부수가 방어에 기여.

### 8.3 2022-2023 하락 -> 회복 (2년)

| 전략 | TQQQ | SOXL |
|------|------|------|
| Smart Cycle (Alpha Cycle V3) | **+6.90%** | -11.17% |
| Buy & Hold | -40.75% | -56.45% |

**핵심 인사이트**: Smart Cycle은 TQQQ 2년 하락+회복 구간에서 **유일하게 플러스 수익**을 기록한 전략이다. 현금 보존 + 저가 매수 조합이 회복기에 빛을 발한다.

---

## 9. 전략 선택 가이드

| 시장 전망 | Smart Cycle 적합도 | 이유 |
|-----------|-------------------|------|
| 우상향 (변동성 높음) | 보통 | 수익률은 낮지만 MDD 억제 |
| 불확실 / 횡보 | **높음** | 현금 보존으로 하락 대비 |
| 하락 우려 | **높음** | MDD 억제, 회복기 수익 전환 가능 |
| 분산 투자 | 높음 | Steady Cycle과 동시 운용으로 방어력 확보 |

---

## 관련 파일

### 도메인 레이어
- `lib/domain/trading/alpha_cycle_service.dart` — Smart Cycle 비즈니스 로직 (순수 함수)
- `lib/domain/trading/trading_math.dart` — 공용 계산 함수 (returnRate, recalcAveragePrice, evaluatedAmount)
- `lib/domain/trading/strategy_engine.dart` — StrategyEngine 인터페이스

### 데이터 레이어
- `lib/data/models/cycle.dart` — Cycle + StrategyType + CycleStatus
- `lib/data/models/trade.dart` — Trade + TradeSignal + TradeAction
- `lib/data/repositories/cycle_repository.dart` — Cycle CRUD (Hive)
- `lib/data/repositories/trade_repository.dart` — Trade CRUD (Hive)

### Provider 레이어
- `lib/presentation/providers/cycle_providers.dart` — CycleListNotifier, 필터, 신호감지, completeTakeProfit
- `lib/presentation/providers/trade_providers.dart` — TradeListNotifier

### UI 레이어
- `lib/presentation/screens/stocks/cycle_setup_screen.dart` — 사이클 생성
- `lib/presentation/screens/stocks/cycle_detail_screen.dart` — 사이클 상세
- `lib/presentation/widgets/cycle/signal_display.dart` — 신호 표시 위젯
- `lib/presentation/widgets/cycle/active_cycle_card.dart` — 활성 사이클 카드
- `lib/presentation/widgets/cycle/alpha_cycle_gauge.dart` — 손실률+수익률+현금비율 게이지
- `lib/presentation/widgets/cycle/cycle_info_card.dart` — 사이클 정보 카드
