# Alpha Cycle 트레이딩 전략 설계서 (요약)

**문서 버전**: 8.0 (요약본)
**작성일**: 2026-03-13
**목적**: 두 전략의 핵심 요약 + 상세 설계서 링크

---

## 1. 두 가지 전략

Alpha Cycle 앱은 레버리지 ETF(TQQQ, SOXL 등)를 위한 **두 가지 상호보완적 매매 전략**을 제공한다.

| 구분 | Smart Cycle (방어적) | Steady Cycle (공격적) |
|------|--------------------|--------------------|
| 내부 enum | `CycleStrategy.alphaCycleV3` | `CycleStrategy.steadyCycle` |
| 목표 | 낮은 MDD, 현금 보존 | 높은 수익률, 기계적 복리 |
| 매수 방식 | 손실률 기반 가중매수 (5종 신호) | 분할 매수 + LOC 주문 |
| 매도 방식 | 연속 감소 익절 (30→25→20→15→10%) | 매일 부분매도 + 지정가 익절 |
| 버전 | 단일 (v7.0) | V1 / V2.2 / V3.0 선택 가능 |
| 적합 대상 | 변동성 큰 시장, 자본 보존 우선 | 우상향 장세, 복리 수익 극대화 |

**핵심 철학**: 시장 전망에 따라 전략을 선택하거나, 두 전략을 동시 운용하여 포트폴리오를 분산.

> **상세 설계서**:
> - Smart Cycle: [`SMART_CYCLE_DESIGN.md`](SMART_CYCLE_DESIGN.md)
> - Steady Cycle: [`STEADY_CYCLE_DESIGN.md`](STEADY_CYCLE_DESIGN.md)

---

## 2. Smart Cycle 핵심 공식

**초기 진입**: `initialEntryAmount = seedAmount × 0.20`

**가중매수** (lossRate ≤ -20%):
```
weightedBuyAmount = |lossRate| × weightedBuyPerPercent
weightedBuyPerPercent = seedAmount × 0.00007  (1억 기준: 1%당 7,000원)
```

**승부수** (lossRate ≤ -50%, 1회 한정):
```
panicBuyAmount = evaluatedAmount × 0.50  (현재 평가금액 기준, 동적)
```

**익절** (returnRate ≥ sellTarget):
```
sellTarget = max(10%, 30% - consecutiveProfitCount × 5%p)
→ 30% → 25% → 20% → 15% → 10%(하한)
```

**현금확보** (returnRate ≥ 0% AND cashRatio < 33%):
```
매도금액 = (totalAssets × 33%) - remainingCash
```

**신호 우선순위**: TAKE_PROFIT > CASH_SECURE > PANIC_BUY > WEIGHTED_BUY > HOLD

> 상세 (용어, 파라미터, 신호 코드, 데이터 모델, 백테스트): [`SMART_CYCLE_DESIGN.md`](SMART_CYCLE_DESIGN.md)

---

## 3. Steady Cycle 핵심 공식

### V1 (Simple) — 현재 구현
```
40분할, unitAmount = seedAmount / 40
종가 ≤ 평단 → 1.0 unit (A+B), 종가 > 평단 → 0.5 unit (B만)
익절: +10% 전량매도
```

### V2.2 (Original) — 라오어 2022
```
40분할, T = ceil(투자액 / unitAmount)
LOC 오프셋 = 10 - T/2 (%)
전반전(T<20): A=평단LOC + B=오프셋LOC (각 0.5 unit)
후반전(T≥20): 단일 오프셋LOC (1.0 unit)
매도: 매일 1/4 LOC매도 + 3/4 지정가(+10%) 동시
```

### V3.0 (Aggressive) — 라오어 2024
```
20분할, T = ceil(투자액 / unitAmount)
LOC 오프셋 = 15 - 1.5T (%)  ← V2.2보다 공격적
전반전(T≤19): A=오프셋LOC + B=평단LOC (A/B 역할 반대)
후반전(T>19): 단일 오프셋LOC
매도: 매일 1/4 LOC매도 + 3/4 지정가(TQQQ +15%, SOXL +20%)
복리: 부분매도 수익금 즉시 반영 → unitAmount 동적 재계산
```

> 상세 (T값 테이블, LOC 체결 규칙, UI 가이드, 데이터 모델, 백테스트): [`STEADY_CYCLE_DESIGN.md`](STEADY_CYCLE_DESIGN.md)

---

## 4. 백테스트 비교 요약

시드 1억, 환율 1,350원

### 상승장 (2025)

| 전략 | TQQQ 수익률 | SOXL 수익률 | TQQQ MDD | SOXL MDD |
|------|-----------|-----------|---------|---------|
| Smart Cycle | +16.85% | +21.67% | **-15.22%** | **-29.03%** |
| Steady V1 | **+40.96%** | **+95.18%** | -45.99% | -45.53% |
| Steady V2.2 | +19.59% | +53.33% | -29.23% | -45.53% |
| Steady V3.0 | +23.46% | +85.84% | -34.78% | -51.24% |
| Buy & Hold | +45.14% | +153.31% | -56.97% | -76.53% |

### 하락장 (2022)

| 전략 | TQQQ 수익률 | SOXL 수익률 | TQQQ MDD | SOXL MDD |
|------|-----------|-----------|---------|---------|
| Smart Cycle | -62.62% | -72.64% | -67.80% | -81.13% |
| Steady V1 | -70.98% | -79.11% | -74.17% | -85.22% |
| Steady V2.2 | **-21.76%** | -68.33% | **-40.26%** | -77.63% |
| Steady V3.0 | -62.04% | **-10.22%** | -64.54% | **-53.85%** |
| Buy & Hold | -79.78% | -86.59% | -81.11% | -90.39% |

### 하락→회복 (2022-2024)

| 전략 | TQQQ 수익률 | SOXL 수익률 |
|------|-----------|-----------|
| Smart Cycle | +6.90% | -11.17% |
| Steady V1 | -14.94% | -32.17% |
| Steady V2.2 | **+20.65%** | -4.19% |
| Steady V3.0 | -9.59% | **+61.86%** |
| Buy & Hold | -40.75% | -56.45% |

### 전략 선택 가이드

| 시장 전망 | TQQQ 추천 | SOXL 추천 |
|-----------|----------|----------|
| 확실한 상승장 | Steady V1 | Steady V1 |
| 불확실/횡보 | Smart Cycle 또는 Steady V2.2 | Steady V3.0 |
| 하락 우려 | Steady V2.2 | Steady V3.0 |
| 장기 (2년+) | Steady V2.2 | Steady V3.0 |
| 방어 + 분산 | Smart + Steady 동시 운용 | Smart + Steady 동시 운용 |

> 상세 백테스트 결과: Smart → [`SMART_CYCLE_DESIGN.md` §8](SMART_CYCLE_DESIGN.md), Steady → [`STEADY_CYCLE_DESIGN.md` §9](STEADY_CYCLE_DESIGN.md)

---

## 5. 공통 데이터 모델

### Cycle 모델 (Hive typeId: 1)

```dart
// 공통 필드
@HiveField(0)  String id;
@HiveField(1)  String ticker;
@HiveField(3)  double seedAmount;          // 시드 금액 (KRW)
@HiveField(4)  double remainingCash;       // 잔여 현금 (KRW)
@HiveField(5)  double totalShares;         // 총 보유 수량
@HiveField(6)  double averagePrice;        // 평균 단가 (USD, VWAP)
@HiveField(9)  CycleStatus status;         // active / completed
@HiveField(16) CycleStrategy strategyType; // alphaCycleV3 / steadyCycle

// Smart Cycle 전용: HiveField 13~15, 18~26
// Steady Cycle 전용: HiveField 28~31 (V2.2/V3.0)
```

### VWAP 계산 (공통)
```
newAvgPrice = (기존shares × 기존avgPrice + 신규shares × 체결가) / 총shares
```

### Hive TypeId 현황
```
 0: Stock    1: Cycle     2: Trade     3: Settings
10: CycleStatus  11: TradeAction  12: Holding  13: HoldingTransaction
14: HoldingTransactionType  15: WatchlistItem  16: NotificationRecord
20: StrategyType  21: TradeSignal  22: WatchlistGroup  23: RecentViewItem
24: SteadyVersion (신규)
```

> 전체 필드 목록: Smart → [`SMART_CYCLE_DESIGN.md` §7](SMART_CYCLE_DESIGN.md), Steady → [`STEADY_CYCLE_DESIGN.md` §7](STEADY_CYCLE_DESIGN.md)

---

## 6. 관련 파일

| 레이어 | 파일 | 설명 |
|--------|------|------|
| 도메인 | `alpha_cycle_service.dart` | Smart Cycle 비즈니스 로직 |
| 도메인 | `infinite_buy_service.dart` | Steady V1 비즈니스 로직 |
| 도메인 | `trading_math.dart` | 공용 계산 (returnRate, VWAP 등) |
| 데이터 | `cycle.dart` | Cycle + StrategyType + CycleStatus |
| 데이터 | `trade.dart` | Trade + TradeSignal + TradeAction |
| Provider | `cycle_providers.dart` | CycleListNotifier, 신호감지 |
| Provider | `trade_providers.dart` | TradeListNotifier |
| UI | `cycle_setup_screen.dart` | 사이클 생성 (전략+버전 선택) |
| UI | `cycle_detail_screen.dart` | 사이클 상세 + 주문 가이드 |
| 설계서 | [`SMART_CYCLE_DESIGN.md`](SMART_CYCLE_DESIGN.md) | Smart Cycle 상세 설계 |
| 설계서 | [`STEADY_CYCLE_DESIGN.md`](STEADY_CYCLE_DESIGN.md) | Steady Cycle V1/V2.2/V3.0 상세 설계 |
