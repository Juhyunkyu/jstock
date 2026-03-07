# Alpha Cycle V3 + 순정 무한매수법 V2.1 — 트레이딩 전략 설계서

**문서 버전**: 6.1
**작성일**: 2026-03-07
**목적**: 두 가지 매매 전략의 구현 설계서 (Single Source of Truth)

---

## 1. 개요

### 1.1 두 가지 전략, 왜 이 조합인가

Alpha Cycle 앱은 레버리지 ETF(TQQQ, SOXL 등)를 위한 **두 가지 상호보완적 매매 전략**을 제공한다.

| 구분 | Strategy A: Alpha Cycle V3 | Strategy B: 순정 무한매수법 V2.1 |
|------|---------------------------|-------------------------------|
| 성격 | 방어적 (Defensive) | 공격적 (Offensive) |
| 목표 | 낮은 MDD, 현금 보존 | 높은 수익률, 단순한 기계적 실행 |
| 복잡도 | 5종 신호 체계 | 2종 주문 (LOC A/B) |
| 익절 | 연속 감소 (30→25→20→15→10%) | 고정 (+10%) |
| 현금 관리 | 현금확보 매도 규칙 | 없음 (40분할 소진) |
| 적합 대상 | 변동성 큰 시장, 자본 보존 우선 | 우상향 장세, 복리 수익 극대화 |

**핵심 철학**: 사용자가 시장 전망에 따라 전략을 선택하거나, 두 전략을 동시에 운용하여 포트폴리오를 분산할 수 있다.

### 1.2 커스텀 파라미터

두 전략 모두 핵심 파라미터를 사용자가 조절할 수 있다. 기본값은 백테스트에서 검증된 값이며, 시장 상황이나 개인 성향에 따라 변경 가능하다.

---

## 2. Strategy A: Alpha Cycle V3

### 2.1 기본 용어

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

### 2.2 커스텀 파라미터

| 파라미터 | 기본값 | 설명 | 허용 범위 |
|----------|--------|------|-----------|
| initialEntryRatio | 0.20 (20%) | 시드 대비 초기 진입 비율 | 0.05 ~ 0.50 |
| weightedBuyThreshold | -20% | 가중매수 발동 손실률 | -50% ~ -5% |
| weightedBuyDivisor | 1000 | 가중매수 금액 제수 | 500 ~ 2000 |
| panicBuyThreshold | -50% | 승부수 발동 손실률 | -80% ~ -30% |
| panicBuyMultiplier | 0.50 (50%) | 승부수 금액 배수 (평가금액 기준) | 0.10 ~ 1.00 |
| firstProfitTarget | 30% | 첫 익절 목표 수익률 | 10% ~ 50% |
| profitTargetStep | 5%p | 연속 익절 시 감소폭 | 1%p ~ 10%p |
| minProfitTarget | 10% | 익절 목표 하한 | 3% ~ 20% |
| cashSecureRatio | 1/3 (33.3%) | 현금확보 목표 비율 | 0.10 ~ 0.50 |

### 2.3 공식

#### 초기 진입

```
initialEntryAmount = seedAmount x initialEntryRatio
remainingCash = seedAmount - initialEntryAmount
```

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

#### 가중 매수 (Weighted Buy)

조건: lossRate <= weightedBuyThreshold (기본 -20%)

```
weightedBuyAmount(KRW) = initialEntryAmount x |lossRate| / weightedBuyDivisor
actualBuyAmount = min(weightedBuyAmount, remainingCash)  // 현금 부족 시 잔액만큼만
```

remainingCash <= 0이면 매수 신호 발동하지 않음.

예시 (시드 1억, 진입금 2000만):

| 손실률 | 가중매수 금액 |
|--------|-------------|
| -20% | 40만원 |
| -30% | 60만원 |
| -40% | 80만원 |
| -50% | 100만원 |

#### 승부수 (Panic Buy) — V3 핵심 변경

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

#### 익절 (Take Profit) — 연속 감소

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

#### 현금 확보 (Cash Secure) — V3 신규

조건: returnRate >= 0% AND remainingCash < totalAssets x cashSecureRatio AND totalShares > 0 AND currentPrice > 0

```
목표 현금 = totalAssets x cashSecureRatio
부족분    = 목표현금 - remainingCash
매도 금액 = 부족분 (KRW)
매도 수량 = 매도금액 / (currentPrice x exchangeRate)
```

가중매수로 현금이 줄어든 상태에서 가격이 회복되면(수익률 >= 0%), 추가 하락에 대비하여 현금을 확보. 전량 매도가 아닌 일부 매도.

### 2.4 신호 체계 (5단계 우선순위)

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

### 2.5 전체 매매 플로우

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
  |     YES -> 가중 매수 (진입금x|손실률|/1000, 잔액 한도)
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

## 3. Strategy B: 순정 무한매수법 V2.1

### 3.1 개요

40분할 기계적 매수 전략. LOC(Limit On Close) 주문 2종을 조합하여, 평균단가 이하에서는 더 많이 사고 이상에서는 적게 산다. 익절(+10%) 시 전량 매도 후 새 사이클을 시작하며, 복리 효과로 수익을 극대화한다.

### 3.2 커스텀 파라미터

| 파라미터 | 기본값 | 설명 | 허용 범위 |
|----------|--------|------|-----------|
| totalRounds | 40 | 총 분할 매수 회수 | 20 ~ 80 |
| takeProfitPercent | 10% | 익절 목표 수익률 | 3% ~ 30% |

### 3.3 공식

#### 분할 단위

```
unitAmount = seedAmount / totalRounds
```

예: 시드 1000만원, 40회 -> 1회당 25만원
**Zero-guard**: totalRounds가 0이면 unitAmount = 0 (UI에서 최소 20 강제)

#### LOC 주문 체계

매 회차마다 2종의 LOC 주문을 동시에 낸다:

| 주문 | 조건 | 금액 | 설명 |
|------|------|------|------|
| LOC A | 종가 <= averagePrice 일 때 체결 | 0.5 unit | 평단 이하에서만 체결 |
| LOC B | 항상 체결 | 0.5 unit | 무조건 매수 |

결합 결과:

| 종가 조건 | 체결 주문 | 총 매수 금액 |
|-----------|----------|-------------|
| 종가 <= 평균단가 | A + B | 1.0 unit (전액) |
| 종가 > 평균단가 | B만 | 0.5 unit (반액) |

예외: 사이클 첫 매수(roundsUsed == 0)는 항상 1.0 unit (A+B 동시 체결, 아직 평균단가가 없으므로)

> **roundsUsed 증가 규칙**: LOC 신호(locAB, locB)에 의한 매수에서만 증가. 수동 매수(manual)에서는 증가하지 않음.

#### 익절

조건: returnRate >= takeProfitPercent (기본 +10%)

```
returnRate(%) = (currentPrice - averagePrice) / averagePrice x 100
```

**Zero-guard**: averagePrice가 0이면 returnRate = 0 (익절 조건 미충족)

익절 시:
1. 전량 매도
2. 새 시드 = 매도금액 + 잔여현금 (복리)
3. roundsUsed = 0 (초기화)
4. 새 사이클 시작

#### 40회 소진 후

totalRounds를 모두 소진하면 추가 매수 없이 대기. returnRate >= takeProfitPercent 달성 시에만 매도.

### 3.4 신호 체계

```
우선순위:

1. TAKE_PROFIT   — returnRate >= takeProfitPercent
2. LOC_AB        — 종가 <= averagePrice (A+B 동시 체결, 1.0 unit) OR roundsUsed == 0
3. LOC_B         — 종가 > averagePrice (B만 체결, 0.5 unit)
4. HOLD          — rounds 소진 OR remainingCash <= 0, 익절 대기

전제조건: LOC_AB/LOC_B 신호는 roundsUsed < totalRounds AND remainingCash > 0일 때만 발동.
```

첫 매수(roundsUsed == 0)는 항상 LOC_AB.

| 신호 | 색상 | 표시 내용 |
|------|------|----------|
| TAKE_PROFIT | green | "익절! 전량 매도 (+{percent}%)" |
| LOC_AB | blue | "매수 {금액}원 (평단 이하, A+B)" |
| LOC_B | cyan | "매수 {금액}원 (B만, 0.5 unit)" |
| HOLD | gray | "대기 ({roundsUsed}/{totalRounds} 소진)" |

### 3.5 전체 매매 플로우

```
사이클 시작 (시드 설정)
  |
  v
unitAmount = seedAmount / totalRounds
  |
  v
매일 체크
  |
  +-- returnRate >= +10%?
  |     YES -> 전량 매도 -> 새 시드(복리) -> 새 사이클
  |
  +-- roundsUsed < totalRounds?
  |     YES -> LOC 주문
  |            roundsUsed == 0? -> A+B = 1.0 unit (첫 매수)
  |            종가 <= avgPrice? -> A+B = 1.0 unit
  |            종가 > avgPrice?  -> B만 = 0.5 unit
  |            roundsUsed += 1
  |
  +-- roundsUsed >= totalRounds
        -> 대기 (익절만 기다림)
```

---

## 4. 백테스트 결과

### 4.1 2025 상승장 (4월 -50% 급락 포함)

#### TQQQ ($39.31 -> $52.72, +34%)

| 전략 | 수익률 | MDD | 사이클 수 |
|------|--------|-----|----------|
| Alpha Cycle V3 | +16.85% | -15.22% | 1 |
| 순정 무한매수 | +30.55% | -47.22% | 5 |
| Buy & Hold | +34.10% | -56.97% | - |

#### SOXL ($27.67 -> $42.03, +52%)

| 전략 | 수익률 | MDD | 사이클 수 |
|------|--------|-----|----------|
| Alpha Cycle V3 | +21.67% | -29.03% | 1 |
| 순정 무한매수 | +72.17% | -45.53% | 13 |
| Buy & Hold | +51.90% | -76.53% | - |

분석: 상승장에서 순정 무한매수법이 압도적. 빈번한 익절(+10%)로 복리 효과가 극대화된다. Alpha Cycle은 MDD를 절반 이하로 억제하는 대신 수익률을 희생한다.

### 4.2 2022 하락장

#### TQQQ ($42.78 -> $8.65, -80%)

| 전략 | 수익률 | MDD | 사이클 수 |
|------|--------|-----|----------|
| Alpha Cycle V3 | -62.62% | -67.80% | 0 |
| 순정 무한매수 | -70.98% | -74.17% | 0 |
| Buy & Hold | -79.78% | -81.11% | - |

#### SOXL ($72.10 -> $9.67, -87%)

| 전략 | 수익률 | MDD | 사이클 수 |
|------|--------|-----|----------|
| Alpha Cycle V3 | -72.64% | -81.13% | 0 |
| 순정 무한매수 | -79.11% | -85.22% | 0 |
| Buy & Hold | -86.59% | -90.39% | - |

분석: 순수 하락장에서는 모든 전략이 손실. 하지만 Alpha Cycle이 MDD와 최종 손실 모두 가장 적다. 현금확보 규칙과 동적 승부수가 방어에 기여.

### 4.3 2022-2023 하락 -> 회복 (2년)

| 전략 | TQQQ | SOXL |
|------|------|------|
| Alpha Cycle V3 | **+6.90%** | -11.17% |
| 순정 무한매수 | -14.94% | -32.17% |
| Buy & Hold | -40.75% | -56.45% |

**핵심 인사이트**: Alpha Cycle V3는 TQQQ 2년 하락+회복 구간에서 **유일하게 플러스 수익**을 기록한 전략이다. 현금 보존 + 저가 매수 조합이 회복기에 빛을 발한다.

### 4.4 전략 선택 가이드

| 시장 전망 | 추천 전략 | 이유 |
|-----------|----------|------|
| 우상향 (변동성 높음) | 순정 무한매수 | 빈번한 익절로 복리 효과 극대화 |
| 불확실 / 횡보 | Alpha Cycle V3 | 현금 보존으로 하락 대비 |
| 하락 우려 | Alpha Cycle V3 | MDD 억제, 회복기 수익 전환 가능 |
| 분산 투자 | 두 전략 동시 운용 | 수익 기회 + 방어력 |

---

## 5. 데이터 모델

### 5.1 Hive TypeId Map

```
typeId  0: Stock (TAKEN)
typeId  1: Cycle (신규 — 기존 삭제됨, typeId 재사용 안전)
typeId  2: Trade (신규 — 기존 삭제됨, typeId 재사용 안전)
typeId  3: Settings (TAKEN)
typeId  4: DrawingType enum (TAKEN)
typeId  5: ChartDrawing (TAKEN)
typeId 10: CycleStatus enum (신규 — 기존 삭제됨, typeId 재사용)
typeId 11: TradeAction enum (신규 — 기존 삭제됨, typeId 재사용)
typeId 12: Holding (TAKEN)
typeId 13: HoldingTransaction (TAKEN)
typeId 14: HoldingTransactionType enum (TAKEN)
typeId 15: WatchlistItem (TAKEN)
typeId 16: NotificationRecord (TAKEN)
typeId 20: StrategyType enum (신규)
typeId 21: TradeSignal enum (신규)
```

> **마이그레이션 안전**: typeId 1, 2, 10, 11은 Phase 1에서 모델+어댑터가 삭제되었고, Hive 박스(`cycles`, `trades`)도 비어있음. 앱 시작 시 안전을 위해 레거시 박스를 삭제 후 새로 생성한다 (Section 8.7 참조).

### 5.2 Cycle 모델 (typeId: 1)

두 전략을 하나의 모델로 통합. `strategyType` 필드로 분기.

```dart
@HiveType(typeId: 20)
enum StrategyType {
  @HiveField(0) alphaCycleV3,
  @HiveField(1) infiniteBuy,
}

@HiveType(typeId: 10)
enum CycleStatus {
  @HiveField(0) active,
  @HiveField(1) completed,
}

@HiveType(typeId: 1)
class Cycle extends HiveObject implements TradingPosition {
  // === 공통 필드 ===
  @HiveField(0) String id;                                              // UUID
  @HiveField(1) String ticker;                                          // 종목 코드
  @HiveField(2) String name;                                            // 종목명
  @HiveField(3) double seedAmount;                                      // 시드 금액 (KRW)
  @HiveField(4, defaultValue: 0.0) double averagePrice;                 // 평균 단가 (USD)
  @HiveField(5, defaultValue: 0.0) double totalShares;                  // 총 보유 수량
  @HiveField(6, defaultValue: 0.0) double remainingCash;                  // 잔여 현금 (KRW)
  @HiveField(7, defaultValue: CycleStatus.active) CycleStatus status;   // active | completed
  @HiveField(8) DateTime startDate;                                     // 시작일
  @HiveField(9) DateTime updatedAt;                                     // 마지막 업데이트
  @HiveField(10) double? completedReturnRate;                           // 완료 시 수익률
  @HiveField(11, defaultValue: 0.0) double exchangeRateAtEntry;          // 진입 시 환율 (KRW/USD)
  @HiveField(12, defaultValue: StrategyType.alphaCycleV3) StrategyType strategyType; // 전략 타입

  // === Strategy A: Alpha Cycle V3 전용 ===
  @HiveField(13) double? entryPrice;                                    // 초기 진입가 (USD, 고정)
  @HiveField(14, defaultValue: 0) int consecutiveProfitCount;           // 연속 익절 횟수
  @HiveField(15, defaultValue: false) bool panicBuyUsed;                // 승부수 사용 여부

  // === Strategy B: 순정 무한매수법 전용 ===
  @HiveField(16, defaultValue: 0) int roundsUsed;                       // 사용한 회차
  @HiveField(17, defaultValue: 40) int totalRounds;                     // 총 회차

  // === 커스텀 파라미터 (Strategy A) ===
  @HiveField(18, defaultValue: 0.20) double initialEntryRatio;
  @HiveField(19, defaultValue: -20.0) double weightedBuyThreshold;
  @HiveField(20, defaultValue: 1000.0) double weightedBuyDivisor;
  @HiveField(21, defaultValue: -50.0) double panicBuyThreshold;
  @HiveField(22, defaultValue: 0.50) double panicBuyMultiplier;
  @HiveField(23, defaultValue: 30.0) double firstProfitTarget;
  @HiveField(24, defaultValue: 5.0) double profitTargetStep;
  @HiveField(25, defaultValue: 10.0) double minProfitTarget;
  @HiveField(26, defaultValue: 0.3333) double cashSecureRatio;

  // === 커스텀 파라미터 (Strategy B) ===
  @HiveField(27, defaultValue: 10.0) double takeProfitPercent;

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
  })  : averagePrice = 0,
       totalShares = 0,
       remainingCash = seedAmount,
       status = CycleStatus.active,
       startDate = DateTime.now(),
       updatedAt = DateTime.now();

  // === 계산 프로퍼티 ===

  /// 초기 진입금 (Strategy A)
  double get initialEntryAmount => seedAmount * initialEntryRatio;

  /// 분할 단위 금액 (Strategy B)
  double get unitAmount => totalRounds > 0 ? seedAmount / totalRounds : 0;

  /// 현재 익절 목표 (Strategy A) — v6.0 공식 수정
  double get currentSellTarget {
    final target = firstProfitTarget - consecutiveProfitCount * profitTargetStep;
    return target < minProfitTarget ? minProfitTarget : target;
  }

  // === TradingPosition 구현 ===

  @override
  double get totalInvestedAmount => seedAmount - remainingCash;

  /// TradingPosition.exchangeRate — 진입 시 환율 반환
  /// 주의: 포트폴리오 표시에서는 이 값 대신 라이브 환율을 사용해야 함 (Section 8.4 참조)
  @override
  double get exchangeRate => exchangeRateAtEntry;

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
    'status': status.name,                    // enum -> String
    'startDate': startDate.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'completedReturnRate': completedReturnRate,
    'exchangeRateAtEntry': exchangeRateAtEntry,
    'strategyType': strategyType.name,        // enum -> String
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
    cycle.startDate = DateTime.parse(json['startDate'] as String);
    cycle.updatedAt = DateTime.parse(json['updatedAt'] as String);
    cycle.completedReturnRate = (json['completedReturnRate'] as num?)?.toDouble();
    return cycle;
  }
}
```

### 5.3 Trade 모델 (typeId: 2)

```dart
@HiveType(typeId: 21)
enum TradeSignal {
  // Strategy A: Alpha Cycle V3
  @HiveField(0) initial,        // 초기 진입
  @HiveField(1) weightedBuy,    // 가중 매수
  @HiveField(2) panicBuy,       // 승부수
  @HiveField(3) cashSecure,     // 현금 확보
  @HiveField(4) takeProfit,     // 익절 (공통)

  // Strategy B: 순정 무한매수법
  @HiveField(5) locA,           // LOC A 체결
  @HiveField(6) locB,           // LOC B 체결
  @HiveField(7) locAB,          // LOC A+B 동시 체결

  // 공통
  @HiveField(8) manual,         // 수동 거래
  @HiveField(9) hold,           // 대기 (DB 저장 안 함, UI 표시용)
}

@HiveType(typeId: 11)
enum TradeAction {
  @HiveField(0) buy,
  @HiveField(1) sell,
}

@HiveType(typeId: 2)
class Trade extends HiveObject {
  @HiveField(0) String id;              // UUID
  @HiveField(1) String cycleId;         // 소속 사이클 ID
  @HiveField(2) TradeAction action;     // buy | sell
  @HiveField(3) TradeSignal signal;     // 신호 타입
  @HiveField(4) double price;           // 체결 가격 (USD)
  @HiveField(5) double shares;          // 수량
  @HiveField(6) double amountKrw;       // 금액 (KRW)
  @HiveField(7) double exchangeRate;    // 체결 시 환율
  @HiveField(8) DateTime tradedAt;      // 체결 일시
  @HiveField(9) String? memo;           // 메모 (선택)

  Trade({
    required this.id,
    required this.cycleId,
    required this.action,
    required this.signal,
    required this.price,
    required this.shares,
    required this.amountKrw,
    required this.exchangeRate,
    DateTime? tradedAt,
    this.memo,
  }) : tradedAt = tradedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'cycleId': cycleId,
    'action': action.name,
    'signal': signal.name,
    'price': price,
    'shares': shares,
    'amountKrw': amountKrw,
    'exchangeRate': exchangeRate,
    'tradedAt': tradedAt.toIso8601String(),
    'memo': memo,
  };

  factory Trade.fromJson(Map<String, dynamic> json) => Trade(
    id: json['id'] as String,
    cycleId: json['cycleId'] as String,
    action: TradeAction.values.byName(json['action'] as String),
    signal: TradeSignal.values.byName(json['signal'] as String),
    price: (json['price'] as num).toDouble(),
    shares: (json['shares'] as num).toDouble(),
    amountKrw: (json['amountKrw'] as num).toDouble(),
    exchangeRate: (json['exchangeRate'] as num).toDouble(),
    tradedAt: DateTime.parse(json['tradedAt'] as String),
    memo: json['memo'] as String?,
  );
}
```

### 5.4 Hive Box 이름

```dart
static const String cycleBoxName = 'cycles_v3';  // v3 접미사로 레거시 충돌 회피
static const String tradeBoxName = 'trades_v3';
```

---

## 6. 아키텍처

### 6.1 파일 구조

```
lib/
+-- data/
|   +-- models/
|   |   +-- cycle.dart              # Cycle + StrategyType + CycleStatus
|   |   +-- cycle.g.dart            # generated
|   |   +-- trade.dart              # Trade + TradeSignal + TradeAction
|   |   +-- trade.g.dart            # generated
|   |   +-- models.dart             # barrel export (cycle, trade 추가)
|   +-- repositories/
|       +-- cycle_repository.dart   # Cycle CRUD (Hive)
|       +-- trade_repository.dart   # Trade CRUD (Hive)
|       +-- repositories.dart       # barrel export (cycle_repository, trade_repository 추가)
|
+-- domain/
|   +-- trading/
|       +-- strategy_engine.dart        # StrategyEngine 인터페이스 (TradingStrategy enum 충돌 회피)
|       +-- alpha_cycle_service.dart    # Strategy A 비즈니스 로직 (순수 함수)
|       +-- infinite_buy_service.dart   # Strategy B 비즈니스 로직 (순수 함수)
|       +-- trading_math.dart           # 공용 계산 함수 (returnRate, recalcAveragePrice, evaluatedAmount)
|
+-- presentation/
    +-- providers/
    |   +-- cycle_providers.dart        # Cycle 상태 관리
    |   +-- trade_providers.dart        # Trade 상태 관리
    +-- screens/
    |   +-- stocks/
    |       +-- stocks_screen.dart          # My 탭 (전략 탭 + 일반보유 탭)
    |       +-- cycle_setup_screen.dart     # 사이클 생성 (전략 선택 포함)
    |       +-- cycle_detail_screen.dart    # 사이클 상세 + 신호 + 거래내역
    |       +-- search_screen.dart         # 종목 검색 (기존 유지)
    +-- widgets/
        +-- cycle/
            +-- active_cycle_card.dart     # 활성 사이클 카드
            +-- signal_display.dart        # 신호 표시 위젯
            +-- cycle_stats_card.dart      # 완료 사이클 통계
            +-- strategy_params_sheet.dart  # 커스텀 파라미터 설정 시트
            +-- cycle_header.dart          # 상세 헤더 (티커+현재가+전략배지)
            +-- alpha_cycle_gauge.dart     # Strategy A 게이지 (손실률+수익률+현금비율)
            +-- infinite_buy_gauge.dart    # Strategy B 게이지 (수익률+회차진행)
            +-- trade_record_sheet.dart    # 거래 기록 입력 BottomSheet
```

### 6.2 전략 인터페이스

> **주의**: 기존 `lib/core/interfaces/strategy_position.dart`에 `TradingStrategy` enum이 이미 존재.
> 이름 충돌을 피하기 위해 전략 엔진 인터페이스는 `StrategyEngine`으로 명명한다.
> `StrategyPosition` 인터페이스와 `TradingStrategy` enum은 V3에서 사용하지 않음 (향후 삭제 대상).

```dart
/// 전략 공통 인터페이스
/// returnRate, evaluatedAmount 등 공용 계산은 trading_math.dart 참조
abstract class StrategyEngine {
  /// 현재 신호 감지
  TradeSignal detectSignal({
    required Cycle cycle,
    required double currentPrice,
    required double liveExchangeRate,
  });

  /// 매수/매도 금액 계산 (KRW), null = 행동 불필요
  double? calculateAmount({
    required Cycle cycle,
    required TradeSignal signal,
    required double currentPrice,
    required double liveExchangeRate,
  });
}
```

### 6.3 Alpha Cycle Service (순수 함수)

```dart
class AlphaCycleService implements StrategyEngine {

  /// 손실률 (entryPrice 기준)
  /// Zero-guard: entryPrice가 null이거나 0이면 0.0 반환
  static double lossRate(double currentPrice, double? entryPrice) {
    if (entryPrice == null || entryPrice == 0) return 0.0;
    return (currentPrice - entryPrice) / entryPrice * 100;
  }

  // returnRate → TradingMath.returnRate() 사용

  /// 가중 매수 금액 (KRW)
  static double weightedBuyAmount({
    required double initialEntryAmount,
    required double lossRate,
    required double weightedBuyDivisor,
  }) => initialEntryAmount * lossRate.abs() / weightedBuyDivisor;

  /// 승부수 금액 (KRW) — V3: 평가금액 기준
  static double panicBuyAmount({
    required double evaluatedAmount,
    required double panicBuyMultiplier,
  }) => evaluatedAmount * panicBuyMultiplier;

  /// 현금 확보 매도 금액 (KRW), null = 불필요
  static double? cashSecureAmount({
    required double remainingCash,
    required double totalAssets,
    required double cashSecureRatio,
  }) {
    if (totalAssets <= 0) return null;
    final targetCash = totalAssets * cashSecureRatio;
    if (remainingCash >= targetCash) return null;
    return targetCash - remainingCash;
  }

  // recalcAveragePrice → TradingMath.recalcAveragePrice() 사용

  @override
  double? calculateAmount({...}) {
    // PANIC_BUY 신호일 때: panicBuyAmount + weightedBuyAmount 합산
    // WEIGHTED_BUY: weightedBuyAmount만
    // CASH_SECURE: cashSecureAmount
    // 모든 매수: min(계산금액, remainingCash) 적용
    // 모든 매도: min(매도수량, totalShares) 적용 — 보유 수량 초과 매도 방지
  }
}
```

### 6.4 Infinite Buy Service (순수 함수)

```dart
class InfiniteBuyService implements StrategyEngine {

  // returnRate → TradingMath.returnRate() 사용

  /// LOC 주문 타입 결정
  static TradeSignal locOrderType({
    required double currentPrice,
    required double averagePrice,
    required int roundsUsed,
  }) {
    if (roundsUsed == 0) return TradeSignal.locAB; // 첫 매수
    if (averagePrice <= 0) return TradeSignal.locAB; // zero-guard
    return currentPrice <= averagePrice
      ? TradeSignal.locAB   // A+B = 1.0 unit
      : TradeSignal.locB;   // B만 = 0.5 unit
  }

  /// 매수 금액 (KRW) — remainingCash 초과 방지
  static double buyAmount({
    required double unitAmount,
    required double remainingCash,
    required TradeSignal locType,
  }) {
    final raw = switch (locType) {
      TradeSignal.locAB => unitAmount,       // 1.0 unit
      TradeSignal.locB  => unitAmount * 0.5, // 0.5 unit
      _                 => 0.0,
    };
    return raw > 0 ? raw.clamp(0.0, remainingCash) : 0.0;
  }
}
```

### 6.5 공용 계산 함수 (`trading_math.dart`)

두 전략에서 중복되는 계산을 하나로 중앙화. Service에서 호출.

```dart
class TradingMath {
  TradingMath._();

  /// 수익률 계산 (두 전략 공통)
  /// Zero-guard: averagePrice가 0이면 0.0 반환
  static double returnRate(double currentPrice, double averagePrice) {
    if (averagePrice == 0) return 0.0;
    return (currentPrice - averagePrice) / averagePrice * 100;
  }

  /// 평가금액 (KRW)
  static double evaluatedAmount(double totalShares, double currentPrice, double exchangeRate) =>
    totalShares * currentPrice * exchangeRate;

  /// 평균단가 재계산 (매수 후)
  /// Zero-guard: newBuyPrice, exchangeRate, totalShares가 0이면 0.0 반환
  static double recalcAveragePrice({
    required double prevTotalCostKrw,
    required double prevTotalShares,
    required double newBuyAmountKrw,
    required double newBuyPrice,
    required double exchangeRate,
  }) {
    if (newBuyPrice == 0 || exchangeRate == 0) return 0.0;
    final newShares = newBuyAmountKrw / (newBuyPrice * exchangeRate);
    final totalShares = prevTotalShares + newShares;
    if (totalShares == 0) return 0.0;
    final totalCostKrw = prevTotalCostKrw + newBuyAmountKrw;
    return totalCostKrw / (totalShares * exchangeRate);
  }
}
```

> **신호 감지는 Provider 레벨에서 처리**: 별도 `signal_detector.dart` 없음.
> `cycleSignalProvider`가 전략별 Service의 `detectSignal()`을 호출하여 실시간 신호를 결정한다.

### 6.6 Provider 구조

```dart
// === Repository Providers ===
// RepositoryContainer에서 제공 (Section 8.2 참조)
final cycleRepositoryProvider = Provider<CycleRepository>(...);
final tradeRepositoryProvider = Provider<TradeRepository>(...);

// === 사이클 목록 ===
// HoldingListNotifier 패턴 따름: 생성자에서 자동 로드
// ref.invalidate() 만으로 갱신 가능 (수동 load() 불필요)
final cycleListProvider = StateNotifierProvider<CycleListNotifier, List<Cycle>>();

// === 전략별 필터 ===
final activeCyclesProvider = Provider<List<Cycle>>((ref) {
  return ref.watch(cycleListProvider)
    .where((c) => c.status == CycleStatus.active)
    .toList();
});

final alphaCyclesProvider = Provider<List<Cycle>>((ref) {
  return ref.watch(activeCyclesProvider)
    .where((c) => c.strategyType == StrategyType.alphaCycleV3)
    .toList();
});

final infiniteBuyCyclesProvider = Provider<List<Cycle>>((ref) {
  return ref.watch(activeCyclesProvider)
    .where((c) => c.strategyType == StrategyType.infiniteBuy)
    .toList();
});

final completedCyclesProvider = Provider<List<Cycle>>((ref) {
  return ref.watch(cycleListProvider)
    .where((c) => c.status == CycleStatus.completed)
    .toList();
});

// === 거래 목록 ===
final tradeListProvider = StateNotifierProvider.family<TradeListNotifier, List<Trade>, String>(
  (ref, cycleId) => TradeListNotifier(ref, cycleId),
);

// === 신호 감지 (실시간 가격 연동) ===
final cycleSignalProvider = Provider.family<TradeSignal, String>((ref, cycleId) {
  final cycles = ref.watch(cycleListProvider);
  final cycle = cycles.where((c) => c.id == cycleId).firstOrNull;
  if (cycle == null) return TradeSignal.hold;  // 삭제된 사이클 안전 처리
  final prices = ref.watch(currentPricesProvider);  // Map<String, double>
  final currentPrice = prices[cycle.ticker] ?? 0;
  final liveExchangeRate = ref.watch(currentExchangeRateProvider);

  if (currentPrice == 0) return TradeSignal.hold;

  final service = cycle.strategyType == StrategyType.alphaCycleV3
    ? AlphaCycleService()
    : InfiniteBuyService();

  return service.detectSignal(
    cycle: cycle,
    currentPrice: currentPrice,
    liveExchangeRate: liveExchangeRate,
  );
});
```

---

## 7. UI 설계

### 7.1 My 탭 (`/stocks`)

현재 "준비중" placeholder 상태. 다음 구조로 복원:

```
My 탭
+-- 포트폴리오 요약 카드 (총 투자/평가/손익)
+-- 도넛 차트 (자산 배분)
+-- 탭 바
    +-- Alpha Cycle (N)     <- Strategy A 활성 사이클
    +-- 무한매수 (N)         <- Strategy B 활성 사이클
    +-- 일반 보유 (N)        <- 기존 Holdings (유지)
+-- 각 탭 콘텐츠: 사이클/보유 카드 리스트
+-- FAB: + 새 사이클 생성 (전략 선택)
```

일반 보유 탭은 기존 Holding 코드를 그대로 유지한다.

> **완료된 사이클 표시**: 거래내역(`/history`) 탭에서 표시. 완료된 사이클의 거래 기록과 최종 수익률을 볼 수 있다. 활성 탭에서는 완료된 사이클을 숨긴다.

### 7.2 사이클 생성 (`/stocks/setup`)

```
사이클 생성 화면
+-- 전략 선택 (SegmentedButton)
|   +-- Alpha Cycle V3
|   +-- 순정 무한매수법
+-- 종목 선택 (티커 검색)
+-- 시드 금액 입력 (KRW)
+-- (자동 표시)
|   Strategy A: 초기진입금, 잔여현금, 익절목표
|   Strategy B: 1회 매수금액, 총 회차
+-- [고급 설정] 커스텀 파라미터 (접이식)
|   Strategy A: 9개 파라미터 슬라이더/입력
|   Strategy B: 2개 파라미터 입력
+-- [사이클 시작] 버튼
```

### 7.3 사이클 상세 (`/stocks/detail/:id`)

```
사이클 상세 화면
+-- 헤더: 티커 + 현재가 + 등락률 + [전략 배지]
+-- 신호 카드: 현재 신호 (색상 + 금액/액션)
+-- 손익 게이지
|   Strategy A: 손실률 + 수익률 + 현금비율 바
|   Strategy B: 수익률 + 회차 진행 바 (N/40)
+-- 사이클 정보 카드
|   공통: 시드, 평균단가, 보유수량, 잔여현금
|   Strategy A: 초기진입가, 승부수 상태, 연속익절N
|   Strategy B: 사용회차/총회차, 단위금액
+-- 거래 내역 (시간순 리스트, 신호 타입 배지)
+-- 액션 버튼: 매수 기록 | 매도 기록 | 사이클 완료
```

---

## 8. 연동 수정 필요 파일

Phase 1(기존 코드 삭제)에서 import가 제거된 파일들. 새 모델로 연결 필요.

### 8.1 기본 연동

| 파일 | 수정 내용 |
|------|----------|
| `lib/data/models/models.dart` | cycle.dart, trade.dart export 추가 |
| `lib/data/repositories/repositories.dart` | cycle_repository.dart, trade_repository.dart export 추가 |
| `lib/presentation/providers/providers.dart` | cycle_providers, trade_providers export 추가 |
| `lib/routes/app_router.dart` | /stocks 하위 라우트 연결 (8.8 참조) |
| `lib/presentation/widgets/common/main_shell.dart` | My 탭 화면 참조 |
| `lib/main.dart` | Hive 어댑터 등록 6개 (CycleAdapter, TradeAdapter, StrategyTypeAdapter, TradeSignalAdapter, CycleStatusAdapter, TradeActionAdapter) |

> **주의**: `app_initializer.dart`는 존재하지 않음. 어댑터 등록은 반드시 `lib/main.dart`에서 수행.

### 8.2 RepositoryContainer 확장

`lib/presentation/providers/core/repository_providers.dart`:

```dart
class RepositoryContainer {
  final SettingsRepository settingsRepository;
  final HoldingRepository holdingRepository;
  final ChartDrawingRepository chartDrawingRepository;
  final CycleRepository cycleRepository;       // 추가
  final TradeRepository tradeRepository;       // 추가
  // ...
}
```

- `initialize()`: cycleRepo, tradeRepo 추가 init
- `close()`: 추가 close
- `cycleRepositoryProvider`, `tradeRepositoryProvider` 신규 Provider 추가

### 8.3 DataManagementService 확장

`lib/data/services/data/data_management_service.dart`:

- **생성자**: `required this.cycleRepository`, `required this.tradeRepository` 추가 (총 6개 repo)
- **백업 버전**: `version: 1` → `version: 2`
- **createBackup()**: `data.cycles`, `data.trades` 추가
- **restoreFromBackup()**: version 체크 로직 추가:
  ```dart
  final version = backup['version'] as int? ?? 1;
  if (version > 2) throw FormatException('지원하지 않는 백업 버전: $version');
  // version 1: cycles/trades 없이 복원 (하위 호환)
  if (version >= 2) { /* cycles, trades 복원 */ }
  ```
- **resetAllData()**: `cycleRepository.clearAll()`, `tradeRepository.clearAll()` 추가
- **exportToCsv()**: "=== 사이클 거래내역 ===" 섹션 추가 (cycleId, strategyType, signal 포함)
- **Provider 주입**: `dataManagementServiceProvider`에 cycleRepo, tradeRepo 추가

### 8.4 UnifiedPortfolioSummary 확장

`lib/presentation/providers/portfolio_providers.dart`:

```dart
class UnifiedPortfolioSummary {
  // 기존 holding 필드 유지
  final double holdingValue;
  final double holdingInvested;
  // ...

  // 사이클 필드 추가
  final double cycleValue;       // 활성 사이클 평가금액 합계
  final double cycleInvested;    // 활성 사이클 투자금 합계 (seedAmount - remainingCash)
  final double cycleProfit;      // 사이클 손익
  final int cycleCount;          // 활성 사이클 수

  // totalValue, totalInvested, totalProfit에 cycle 포함
  double get totalValue => holdingValue + cycleValue;
  double get totalInvested => holdingInvested + cycleInvested;
  double get totalProfit => holdingProfit + cycleProfit;
}
```

> **환율 주의**: `cycleValue` 계산 시 `TradingMath.evaluatedAmount(cycle.totalShares, currentPrice, liveExchangeRate)` 사용. `cycle.exchangeRate`(진입 시)가 아닌 `currentExchangeRateProvider`(라이브)를 사용해야 정확한 현재가치가 나온다.
> **참고**: 기존 `holdingTotalValueProvider`는 `h.currentValue(price)`를 사용하며, 이는 `h.exchangeRate`(매수 시 환율)를 사용한다. Cycle은 `remainingCash`(KRW)가 별도 존재하므로 라이브 환율 기반 평가가 더 정확하다. 향후 Holding도 라이브 환율로 통일할 수 있으나 이번 스코프 밖.

### 8.5 formula_constants.dart 업데이트

`lib/core/constants/formula_constants.dart`:

- V2 상수(buyTriggerPercent, panicTriggerPercent, sellTriggerPercent 등)는 **삭제하지 않음**
- V3에서는 Cycle 모델의 커스텀 파라미터 필드를 직접 사용 (FormulaConstants 참조 안 함)
- 파일 상단 주석에 "V2 레거시 — V3는 Cycle 모델 필드 사용" 표기
- 향후 V2 코드가 완전 제거되면 파일 삭제 가능

### 8.6 consecutiveProfitCount 이월 로직

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
    weightedBuyDivisor: cycle.weightedBuyDivisor,
    panicBuyThreshold: cycle.panicBuyThreshold,
    panicBuyMultiplier: cycle.panicBuyMultiplier,
    firstProfitTarget: cycle.firstProfitTarget,
    profitTargetStep: cycle.profitTargetStep,
    minProfitTarget: cycle.minProfitTarget,
    cashSecureRatio: cycle.cashSecureRatio,
    takeProfitPercent: cycle.takeProfitPercent,
    totalRounds: cycle.totalRounds,
  );
  await cycleRepo.add(newCycle);
}
```

> **리셋 조건**: 사용자가 수동으로 사이클을 종료(손절)하면 `consecutiveProfitCount = 0`으로 리셋.
> 새 사이클을 수동 생성하면 기본값 0부터 시작.

### 8.7 Hive 박스 레거시 마이그레이션

`lib/main.dart`에서 새 어댑터 등록 전:

```dart
// 레거시 박스 삭제 (V2 -> V3 마이그레이션 안전)
// V3는 새 박스 이름 사용 (cycles_v3, trades_v3)
// 기존 cycles, trades 박스에 V2 바이너리 잔재가 있을 수 있으므로 삭제
try {
  await Hive.deleteBoxFromDisk('cycles');
  await Hive.deleteBoxFromDisk('trades');
} catch (_) {}

// 새 어댑터 등록
Hive.registerAdapter(CycleAdapter());
Hive.registerAdapter(TradeAdapter());
Hive.registerAdapter(StrategyTypeAdapter());
Hive.registerAdapter(TradeSignalAdapter());
Hive.registerAdapter(CycleStatusAdapter());
Hive.registerAdapter(TradeActionAdapter());
```

### 8.8 라우터 정의

`lib/routes/app_router.dart`:

```dart
// 라우트 상수
static const String cycleSetup = '/stocks/setup';
static const String cycleDetail = '/stocks/detail/:id';

// ShellRoute 내부에 추가 (하단 탭 유지)
GoRoute(
  path: '/stocks/setup',
  builder: (context, state) => const CycleSetupScreen(),
),
GoRoute(
  path: '/stocks/detail/:id',
  builder: (context, state) {
    final id = state.pathParameters['id']!;
    return CycleDetailScreen(cycleId: id);
  },
),
```

### 8.9 WebSocket 티커 등록

사이클 생성 시 해당 티커를 실시간 가격 구독에 등록해야 한다:

- `CycleListNotifier.addCycle()` 내에서 `ref.read(stockQuoteProvider.notifier).fetchQuotes([ticker])` 호출
- `userTickersProvider`에 활성 사이클 티커 포함 (기존 `List<String>` 반환 유지):
  ```dart
  final userTickersProvider = Provider<List<String>>((ref) {
    final activeHoldings = ref.watch(activeHoldingsProvider);
    final cycles = ref.watch(activeCyclesProvider);  // 추가

    final tickers = <String>{};
    for (final holding in activeHoldings) {
      tickers.add(holding.ticker);
    }
    for (final cycle in cycles) {                    // 추가
      tickers.add(cycle.ticker);
    }
    return tickers.toList();
  });
  ```
  > **주의**: 기존 consumer가 `List<String>`을 기대하므로 반환 타입 변경 금지. Set은 내부 중복 제거용으로만 사용.

### 8.10 StrategyPosition 인터페이스 정리

`lib/core/interfaces/strategy_position.dart`:

- V3에서 사용하지 않음 (Cycle은 `TradingPosition`을 직접 구현)
- 파일 상단에 `@Deprecated('V3에서는 Cycle이 TradingPosition을 직접 구현. 향후 삭제 예정')` 주석 추가
- 삭제는 다른 코드에서 참조하지 않는 것을 확인한 후 진행

---

## 9. 구현 단계

### Phase 1: 기존 코드 삭제 --- 완료

삭제된 파일:
- `lib/data/models/cycle.dart`, `trade.dart` + `.g.dart`
- `lib/data/repositories/cycle_repository.dart`, `trade_repository.dart`
- `lib/domain/alpha_cycle/` 디렉토리 전체
- `lib/presentation/providers/cycle_providers.dart`, `alpha_cycle_provider.dart`, `trade_providers.dart`
- `lib/presentation/screens/stocks/stocks_screen.dart`, `cycle_setup_screen.dart`, `cycle_detail_screen.dart`
- `lib/presentation/widgets/cycle/` 관련 위젯들
- 참조 import 정리 완료

My 탭은 현재 "준비중" placeholder 표시 중.

### Phase 2: 데이터 레이어

1. `lib/data/models/cycle.dart` — Cycle + StrategyType + CycleStatus (5.2절 코드 그대로)
2. `lib/data/models/trade.dart` — Trade + TradeSignal + TradeAction (5.3절 코드 그대로)
3. `dart run build_runner build --delete-conflicting-outputs`
4. `lib/data/repositories/cycle_repository.dart` — CRUD (boxName: `cycles_v3`)
5. `lib/data/repositories/trade_repository.dart` — CRUD (boxName: `trades_v3`)
6. `lib/main.dart` — 레거시 박스 삭제 + Hive 어댑터 등록 6개 (8.7절)
7. `lib/data/models/models.dart` — barrel export 추가
8. `lib/data/repositories/repositories.dart` — barrel export 추가

### Phase 3: 도메인 레이어

1. `lib/domain/trading/strategy_engine.dart` — StrategyEngine 인터페이스
2. `lib/domain/trading/trading_math.dart` — TradingMath 클래스 (6.5절 코드)
3. `lib/domain/trading/alpha_cycle_service.dart` — Strategy A 로직 (6.3절, TradingMath 사용)
4. `lib/domain/trading/infinite_buy_service.dart` — Strategy B 로직 (6.4절, TradingMath 사용)

### Phase 4: Provider 레이어

1. `lib/presentation/providers/cycle_providers.dart` — CycleListNotifier (auto-load, HoldingListNotifier 패턴) + `completeTakeProfit()` (8.6절)
2. `lib/presentation/providers/trade_providers.dart` — TradeListNotifier
3. `lib/presentation/providers/providers.dart` — export 정리
4. `cycleSignalProvider` — 실시간 가격 연동 신호 (6.6절, `currentPricesProvider` + `currentExchangeRateProvider` 사용)
5. `lib/presentation/providers/core/repository_providers.dart` — RepositoryContainer 확장 (8.2절)
6. `lib/presentation/providers/portfolio_providers.dart` — UnifiedPortfolioSummary 확장 (8.4절, 라이브 환율 사용)
7. `userTickersProvider` — 활성 사이클 티커 추가 (8.9절)

### Phase 5: 화면 구현

1. `stocks_screen.dart` — My 탭 (3-탭: Alpha Cycle | 무한매수 | 일반 보유)
2. `cycle_setup_screen.dart` — 전략 선택 + 생성 화면
3. `cycle_detail_screen.dart` — 상세 (헤더+게이지+정보+거래내역 위젯 조합)
4. 위젯 분리:
   - `cycle_header.dart` — 상세 헤더 (티커+현재가+전략배지)
   - `alpha_cycle_gauge.dart` — Strategy A 게이지 (손실률+수익률+현금비율)
   - `infinite_buy_gauge.dart` — Strategy B 게이지 (수익률+회차진행)
   - `trade_record_sheet.dart` — 거래 기록 입력 BottomSheet
   - `active_cycle_card.dart`, `signal_display.dart`, `strategy_params_sheet.dart`
5. 일반 보유 탭: 기존 Holding 코드 재연결

### Phase 6: 통합 및 검증

1. 라우터 연결 (8.8절)
2. 포트폴리오 도넛 차트 연동 (UnifiedPortfolioSummary cycle 데이터 반영)
3. 거래내역 화면 연동 (완료된 사이클 표시)
4. 데이터 관리 업데이트 (8.3절 — version 2, cycles/trades, CSV 확장)
5. `formula_constants.dart` — V2 레거시 주석 표기
6. `strategy_position.dart` — @Deprecated 주석 (8.10절)
7. 빌드 + Playwright 테스트

---

## 10. 유지 (변경 불필요)

- 일반 보유 (Holding) 관련 코드 전부
- 관심종목 (Watchlist) 관련 코드 전부
- 홈 탭 (시장 데이터, 공포탐욕 등)
- 설정, 알림, 브라우저 알림
- 테마, 색상, 공통 위젯
- PWA 업데이트 시스템
- 차트 드로잉 도구
