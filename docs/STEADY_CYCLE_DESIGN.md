# Steady Cycle (무한매수법) 설계서

**문서 버전**: 2.4
**작성일**: 2026-03-13 (v1.0) → 2026-03-17 (v2.0~2.2) → 2026-03-18 (v2.3 아키텍처 리뷰 반영) → 2026-03-28 (v2.4 구현 반영)
**앱 표시명**: Steady Cycle (내부 enum: `CycleStrategy.steadyCycle`)
**원본 전략**: 라오어의 무한매수법 (V1/V2.2/V3.0)

### v2.0 주요 변경사항
- HiveField 번호 충돌 수정 (28→29부터)
- `accumulatedSellProfit` Hive 필드 제거 → 거래 이력 기반 실시간 계산으로 변경
- T=0 첫 매수 예외 로직 추가 (V2.2/V3.0 공통)
- `SteadyOrderGuide` DTO 신규 설계 (복합 주문 가이드)
- 부분 매도 시 사이클 상태 갱신 시퀀스 명시
- 3/4 매도 후 잔존 행동 규칙 정의
- 사이클 완료 = 자동 아님, 확인 다이얼로그
- 매도 수량 > 보유수량 입력 검증 추가
- UI: 클립보드 복사, T값 진행률 바, 버전 비교 카드, 미체결 안내
- 백업 호환 fallback 처리 명시

### v2.1 디자인 리뷰 반영사항
- [Critical] Phase 순서 조정: TradeSignal enum + exhaustive switch 파일 동시 수정 (Phase 1)
- [Critical] 백업 버전 3→4 범프 명시
- [Important] `Cycle.copyWith()` 3개 신규 필드 추가 명시
- [Important] `completeTakeProfit()` 신규 필드 복사 코드 구체화
- [Important] `roundsUsed` 카운팅 수정: manual 제거, locA/buySingle 추가
- [Important] V2.2 섹션 4.5 "복리 없음" 문구 정정 (remainingCash vs unitAmount 구분)
- [Important] `buySignalsFor`/`sellSignalsFor` 시그니처 변경 명시
- [Important] `accumulatedSellProfit`은 기존 `cycleRealizedPnlProvider` 재사용
- [Minor] V3.0 복리 시 `totalInvestedAmount` 의미 변화 문서화
- [Minor] Hive adapter 등록 순서 명시 (Cycle box 열기 전)

### v2.2 원본 검증 반영사항 (pbdfinance.com + 라오어 원본 이미지 기반)
- V3.0 전반전/후반전 기준 수정: T<=19 → **T < 10 / T >= 10** (20분할의 절반)
- V3.0 SOXL 오프셋 공식 추가: TQQQ `15-1.5T` / **SOXL `20-2T`** (종목별 분리)
- V3.0 복리 공식 수정: 전체 재분배 → **수익금/40분할 추가 (반복리), 손해 시 유지**
- V3.0 쿼터모드 신규 추가: 19 < T < 20 구간, MOC 매도, 5번 추가매수, 탈출규칙
- V2.2 별% 일반화 공식: 분할 수 != 40일 때 `(10 - T/2 × 40/A)%`
- LOC 매수 주문 -$0.01 조정 (매도와 겹침 방지)
- V2.2 쿼터 손절모드 추가: T 39.1~40, MOC 손절 + 10회 재진입
- T값 올림 기준 정밀화: 소수점 둘째 자리에서 올림 (int → double)
- 오프셋 프리셋 시스템: TQQQ형/SOXL형/커스텀 (a-b×T 일반 공식)
- Cycle 모델 필드 추가: offsetA(32), offsetB(33), quarterModeOffset(34)

### v2.4 구현 반영사항 (2026-03-28)
- Trade groupId 추가: `@HiveField(10) String? groupId` — 동일 세션 거래 그룹핑, roundsUsed groupId 기준 카운팅
- SteadyCombinedTradeSheet 수정 모드: editingTrades/editGroupId/onReplaceTrades 파라미터, 컨트롤러 프리필, batch replace
- Trade Card UI 리디자인: 단일 카드(1줄), 그룹 카드(badge+detail box), 회차 섹션 fieldset border, formatShares()
- Pending Completion: isPendingCompletion 조건, summary card(시드/투자금/회수금/외화손익/FX toggle), "사이클 완료 및 정산"
- LOC A 추천: currentPrice > averagePrice → "LOC B만 매수 추천" 텍스트
- Cycle 집계 필드: HiveField 37~42 (totalBuyAmountKrw, totalSellAmountKrw, firstTradeDate, lastTradeDate, totalBuyUsd, totalSellUsd)
- realizedProfitKrw / realizedProfitRate 파생 계산

### v2.3 아키텍처 리뷰 반영사항
- V2.2 + V3.0 서비스 통합: `steady_v22_service.dart` + `steady_v30_service.dart` → **`steady_service.dart` 1개** (공통 80% + private 메서드 분기)
- V1(`InfiniteBuyService`)은 변경 없음 (T값/LOC/동시매도 없어 공유 로직 부재)
- 계산 프로퍼티 위치 정리: `tValueWith`, `adjustedUnitAmountWith`, `calcSellProfit` → `SteadyService`로 이동 (AlphaCycleService 패턴 일관성)
- Provider 분리: `steadyOrderGuideProvider` → 신규 `steady_providers.dart` (cycle_providers 비대화 방지)
- V2.2 offsetA/offsetB 활용: `10 - T/2*(40/A)` → `offsetA=10, offsetB=0.5*(40/A)`로 통일 → `locOffsetPercentWith()` 분기 제거
- Phase 2-3 통합 → Phase 2 (서비스 1개), Phase 3 → Provider 계층

---

## 1. 개요

### 1.1 무한매수법이란

무한매수법은 레버리지 ETF(TQQQ, SOXL 등)를 대상으로 한 **기계적 분할 매수 전략**이다. 핵심 원리는 단순하다:

1. 시드 금액을 N등분하여 매일 일정액을 매수
2. 평균단가 이하에서는 더 많이, 이상에서는 적게 매수 (LOC 주문 활용)
3. 목표 수익률 도달 시 전량 매도 후 복리로 재투자
4. 이 사이클을 무한 반복

**LOC(Limit On Close)** 주문은 종가 기준 조건부 체결 주문이다. 매수 LOC는 종가가 설정가 이하일 때, 매도 LOC는 종가가 설정가 이상일 때 체결된다. 미국 시장에서 장 마감 직전에 걸 수 있다.

### 1.2 버전별 철학 차이

| 구분 | V1 (Simple) | V2.2 (Original) | V3.0 (Aggressive) |
|------|-------------|-----------------|-------------------|
| 출처 | 앱 초기 구현 (간소화) | 라오어 2022년 12월 발표 | 라오어 2024년 발표 |
| 분할 수 | 40분할 | 40분할 | **20분할** |
| 매수 공식 | 종가 vs 평단 비교 | T값 기반 LOC 가격 공식 | T값 기반 + 공격적 공식 |
| 매도 방식 | 수익률 도달 시 전량 매도 | **매일 매도 주문 동시 걸기** | 매일 매도 주문 동시 걸기 |
| 복리 | 익절 후 재투자 | 익절 후 재투자 | **수익금 즉시 반영** |
| 적합 대상 | 입문자, 단순 운용 | 정통 무한매수법 사용자 | 공격적 수익 추구자 |

### 1.3 앱의 역할

이 앱은 **시뮬레이션/추적 앱**이다. 실제 주문 체결 기능이 아니라:

1. **주문 가이드 표시**: 오늘 어떤 LOC 주문을 걸어야 하는지 (가격, 수량) 계산하여 표시
2. **수동 입력**: 사용자가 실제 증권사에서 거래 후 결과(체결가, 수량)를 수동 입력
3. **자동 추적**: T값, 평균단가, 회차, 잔여 시드 등을 앱이 자동 계산/관리
4. **신호 표시**: 현재 상태에 따른 매매 신호를 실시간으로 표시

> **중요**: 앱의 신호 표시는 **현재가 기준 예상**이며, 실제 체결은 **종가 기준**이다. 장중에 표시되는 가이드는 "이 가격이 종가가 된다면" 이라는 조건부 가이드이다.

```
[증권사 앱]          [Alpha Cycle 앱]
   |                     |
   |   1. 주문 가이드    |
   |  <------ 표시 ------|  "오늘 LOC 매수: $45.20에 5주"
   |                     |
   |   2. 실제 주문      |
   |--- 사용자 직접 ---->|
   |                     |
   |   3. 체결 후 입력   |
   |  <------ 수동 ------|  체결가 $45.15, 5주 입력
   |                     |
   |   4. 상태 갱신      |
   |        자동 ------->|  T값, 평단가, 수익률 업데이트
```

### 1.4 버전 잠금 원칙

사이클 생성 시 선택한 버전은 **해당 사이클이 끝날 때까지 변경 불가**하다.
- V3.0으로 시작하면 V3.0 공식만 적용된다.
- 다른 버전으로 전환하려면 현재 사이클을 완료하고 새 사이클을 만들어야 한다.
- 익절 후 새 사이클 자동 생성 시 이전 사이클의 버전을 이어받는다.

---

## 2. 공통 용어

| 용어 | 영문 | 정의 |
|------|------|------|
| 시드 금액 | seedAmount | 사이클에 배정한 총 투자 금액 (KRW) |
| 1회 매수 금액 | unitAmount | seedAmount / totalRounds |
| 평균 단가 | averagePrice | VWAP 기반 보유 평균가 (USD) |
| T값 | tValue | 누적 매수액 / 1회 매수액 (올림). 매수 진행도를 나타내는 핵심 지표 |
| LOC | Limit On Close | 종가 기준 조건부 체결 주문 |
| 전반전 | firstHalf | T값이 분할의 절반 미만인 구간 (V2.2: T<20, V3.0: T<10) |
| 후반전 | secondHalf | T값이 분할의 절반 이상인 구간 (V2.2: T>=20, V3.0: T>=10) |
| 회차 | roundsUsed | LOC 신호에 의한 매수 실행 횟수 (수동 매수 제외) |
| 잔여 현금 | remainingCash | 시드 중 미투자 잔액 (KRW) |
| 수익률 | returnRate | (currentPrice - averagePrice) / averagePrice x 100 |
| 평가 금액 | evaluatedAmount | totalShares x currentPrice x exchangeRate (KRW) |
| 복리 | compound | 익절 후 수익금을 새 시드에 포함하여 재투자 |

### LOC 체결 규칙

| 주문 종류 | 체결 조건 | 설명 |
|-----------|----------|------|
| 매수 LOC | 종가 <= 설정가 | 설정가 이하에서만 체결 (더 싸게 살 수 있을 때) |
| 매도 LOC | 종가 >= 설정가 | 설정가 이상에서만 체결 (원하는 가격 이상일 때) |
| 지정가 매도 | 장중 가격 >= 설정가 | 장중 도달 시 즉시 체결 |

---

## 3. Version 1 (Simple) — 현재 구현

### 3.1 파라미터

| 파라미터 | 기본값 | 설명 | 허용 범위 |
|----------|--------|------|-----------|
| totalRounds | 40 | 총 분할 매수 회수 | 20 ~ 80 |
| takeProfitPercent | 10% | 익절 목표 수익률 | 3% ~ 30% |

### 3.2 분할 단위

```
unitAmount = seedAmount / totalRounds
```

예: 시드 1,000만원, 40회 -> 1회당 250,000원
**Zero-guard**: totalRounds가 0이면 unitAmount = 0 (UI에서 최소 20 강제)

### 3.3 매수 공식

매 회차마다 종가와 평균단가를 비교하여 2종의 LOC 주문을 조합한다:

| 주문 | 조건 | 금액 | 설명 |
|------|------|------|------|
| LOC A | 종가 <= averagePrice 일 때 체결 | 0.5 unit | 평단 이하에서만 체결 |
| LOC B | 항상 체결 | 0.5 unit | 무조건 매수 |

**결합 결과:**

| 종가 조건 | 체결 주문 | 총 매수 금액 | 설명 |
|-----------|----------|-------------|------|
| 종가 <= 평균단가 | A + B | 1.0 unit (전액) | 싸게 살 때 많이 사기 |
| 종가 > 평균단가 | B만 | 0.5 unit (반액) | 비싸면 적게 사기 |

**예외**: 사이클 첫 매수(roundsUsed == 0)는 항상 1.0 unit (A+B 동시 체결, 아직 평균단가가 없으므로)

> **roundsUsed 증가 규칙**: LOC 신호(locAB, locB)에 의한 매수에서만 증가. 수동 매수(manual)에서는 증가하지 않음.

### 3.4 익절 공식

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

**40회 소진 후**: totalRounds를 모두 소진하면 추가 매수 없이 대기. returnRate >= takeProfitPercent 달성 시에만 매도.

### 3.5 신호 체계

```
우선순위:

1. TAKE_PROFIT   -- returnRate >= takeProfitPercent
2. LOC_AB        -- 종가 <= averagePrice (A+B 동시 체결, 1.0 unit) OR roundsUsed == 0
3. LOC_B         -- 종가 > averagePrice (B만 체결, 0.5 unit)
4. HOLD          -- rounds 소진 OR remainingCash <= 0, 익절 대기

전제조건: LOC_AB/LOC_B 신호는 roundsUsed < totalRounds AND remainingCash > 0일 때만 발동.
```

| 신호 | 색상 | 표시 내용 |
|------|------|----------|
| TAKE_PROFIT | green | "익절! 전량 매도 (+{percent}%)" |
| LOC_AB | blue | "매수 {금액}원 (평단 이하, A+B)" |
| LOC_B | cyan | "매수 {금액}원 (B만, 0.5 unit)" |
| HOLD | gray | "대기 ({roundsUsed}/{totalRounds} 소진)" |

### 3.6 매매 플로우

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
  +-- roundsUsed < totalRounds AND remainingCash > 0?
  |     YES -> LOC 주문
  |            roundsUsed == 0? -> A+B = 1.0 unit (첫 매수)
  |            종가 <= avgPrice? -> A+B = 1.0 unit
  |            종가 > avgPrice?  -> B만 = 0.5 unit
  |            roundsUsed += 1
  |
  +-- roundsUsed >= totalRounds OR remainingCash <= 0
        -> 대기 (익절만 기다림)
```

---

## 4. Version 2.2 (Original) — 라오어 정통 (2022.12)

### 4.1 파라미터

| 파라미터 | 기본값 | 설명 | 허용 범위 |
|----------|--------|------|-----------|
| totalRounds | 40 | 총 분할 매수 회수 | 20 ~ 80 |
| takeProfitPercent | 10% | 지정가 매도 목표 수익률 | 3% ~ 30% |
| sellQuarterPercent | 25% | 부분 매도 비율 (보유수량의 1/4) | 10% ~ 50% |

### 4.2 T값 계산

T값은 현재까지의 매수 진행도를 나타내는 핵심 지표이다.

```
T = 누적 매수액 / 1회 매수 시도액
    → 소수점 둘째 자리에서 올림
```

**올림 기준 예시** (1회 매수 시도액 = $1000):
| 누적 매수액 | 나눗셈 결과 | T값 (둘째 자리 올림) |
|------------|-----------|-------------------|
| $975 | 0.975 | **1.0** |
| $1,935 | 1.935 | **2.0** |
| $2,880 | 2.88 | **2.9** |

- T = 0: 아직 매수 전
- T = 1: 1회분 매수 완료
- T = 20: 절반 소진 (40분할 기준)
- T = 39.1~40: 원금 소진으로 간주

> **소수점 둘째 자리 올림**: 단순 `ceil()`이 아니라 `(value * 10).ceil() / 10` 형태. 수동 입력에서 정확히 1회분이 아닌 금액이 입력되어도 정밀하게 추적한다.

```dart
// T값 올림 구현 (소수점 둘째 자리에서 올림)
double tValueRaw = invested / unitAmount;
double tValue = (tValueRaw * 10).ceilToDouble() / 10;
```

> **수동 매수의 T값 영향**: V2.2/V3.0에서 T값은 `remainingCash` 기반으로 계산하므로, 수동 매수도 remainingCash를 줄이면 T값이 자동 증가한다. V1의 `roundsUsed`(LOC 신호 매수에서만 증가)와 다른 점이다.

### 4.3 매수 공식

V2.2의 핵심은 T값에 따라 LOC 매수가를 **평단가 대비 일정 %**로 설정하는 것이다.

#### 매수 LOC 가격 오프셋 공식 (별퍼센트)

```
기본 (40분할): 별퍼센트(%) = 10 - T/2
일반화 (A분할): 별퍼센트(%) = 10 - T/2 × (40/A)
```

> **분할 수가 40이 아닐 경우**: 사용자가 분할 수(A)를 변경하면 오프셋 공식도 자동 조정된다. 예: 30분할이면 `10 - T/2 × (40/30) = 10 - T/2 × 1.333`.  40분할일 때 `40/A = 1`이므로 기본 공식과 동일하다.

#### ★ LOC 주문 -$0.01 조정

> **매수 LOC와 매도 LOC가 동일한 별% 가격을 사용하므로**, 같은 가격에 매수+매도가 동시에 걸리면 겹칠 수 있다. 이를 방지하기 위해 **매수 LOC 주문 시 -$0.01을 차감**한다. 앱의 주문 가이드에서 매수 LOC가는 `별% 가격 - $0.01`로 표시한다.

| T값 | 오프셋 (10 - T/2) | LOC 매수가 | 설명 |
|-----|-------------------|-----------|------|
| 0 | +10.0% | 평단 + 10% | 초기: 평단보다 10% 높은 가격까지 매수 허용 |
| 10 | +5.0% | 평단 + 5% | |
| 20 | 0.0% | 평단가 | 전환점: 평단 이하에서만 매수 |
| 30 | -5.0% | 평단 - 5% | |
| 40 | -10.0% | 평단 - 10% | 최종: 평단보다 10% 싼 가격에만 매수 |

#### ★ T=0 첫 매수 예외 (Critical)

사이클 시작 시 `averagePrice = 0`이므로, LOC 가격 공식(`averagePrice × (1 + offset%)`)이 $0이 된다. 따라서:

```
if (averagePrice == 0 또는 totalShares == 0) {
  → 첫 매수 예외: 현재가(currentPrice) 기준으로 1.0 unit 무조건 매수
  → LOC 가격 = currentPrice (사실상 시장가 매수)
  → 이후 averagePrice가 설정되면 정상 공식 적용
}
```

이는 V1의 "roundsUsed == 0이면 1.0 unit" 예외와 동일한 맥락이다.

#### 전반전 (T < 20): 2종 주문

```
A주문 (절반):
  금액 = unitAmount / 2
  LOC 가격 = averagePrice (평단가)
  -> 종가 <= 평단가 일 때 체결

B주문 (절반):
  금액 = unitAmount / 2
  LOC 가격 = averagePrice x (1 + (10 - T/2) / 100)
  -> 종가 <= LOC가격 일 때 체결
```

**전반전 체결 시나리오:**

| 종가 위치 | A주문 | B주문 | 총 매수 |
|-----------|-------|-------|--------|
| 종가 > B가격 | 미체결 | 미체결 | 0 (매수 없음) |
| 평단 < 종가 <= B가격 | 미체결 | 체결 | 0.5 unit |
| 종가 <= 평단 | 체결 | 체결 | 1.0 unit |

#### 후반전 (T >= 20): 단일 주문

```
단일 주문:
  금액 = unitAmount (전체 1회분)
  LOC 가격 = averagePrice x (1 + (10 - T/2) / 100)
  -> 종가 <= LOC가격 일 때 체결
```

후반전에서는 오프셋이 0% 이하이므로, 평단가 이하에서만 체결된다.

### 4.4 매도 공식

V2.2의 **핵심 차이점**: 매일 매수 주문과 함께 **매도 주문도 동시에** 걸어놓는다.

```
매도 주문 1 (LOC 매도, 부분):
  수량 = 보유수량 x sellQuarterPercent (기본 1/4)
  LOC 가격 = averagePrice x (1 + (10 - T/2) / 100)
  -> 종가 >= LOC가격 일 때 체결

매도 주문 2 (지정가 매도, 대량):
  수량 = 보유수량 x (1 - sellQuarterPercent) (기본 3/4)
  지정가 = averagePrice x (1 + takeProfitPercent / 100)
  -> 장중 가격 >= 지정가 일 때 즉시 체결
```

**매도 시나리오:**

| 상황 | LOC 매도 (1/4) | 지정가 매도 (3/4) | 결과 |
|------|---------------|------------------|------|
| 종가 < LOC가, 장중 < 지정가 | 미체결 | 미체결 | 매도 없음 |
| 종가 >= LOC가, 장중 < 지정가 | **체결** | 미체결 | 부분 익절 (1/4) |
| 종가 < LOC가, 장중 >= 지정가 | 미체결 | **체결** | 대량 익절 (3/4) |
| 종가 >= LOC가, 장중 >= 지정가 | **체결** | **체결** | 전량 익절 |

> **부분 익절의 의미**: V1은 +10% 도달 시에만 전량 매도하지만, V2.2는 매일 부분 매도 기회를 만든다. 수익 실현 빈도가 높아지고, 복리 효과가 증가한다.

> **후반전 매도 LOC가가 평단 이하가 되는 것은 의도된 동작이다**: T=25일 때 매도 LOC가는 평단 -2.5%이므로 "손실 매도"에 해당한다. 이는 하락장에서 현금을 확보하여 다음 매수 기회를 만드는 안전장치 역할을 한다. 백테스트 결과에서 V2.2의 하락장 방어력(-40% MDD vs V1의 -74%)이 이 메커니즘 덕분이다.

### 4.5 부분 매도 시 사이클 상태 갱신 시퀀스

부분 매도(1/4 LOC 또는 3/4 지정가)가 기록되면, 사이클 상태는 다음 순서로 갱신된다:

```
1. cycle.totalShares -= 매도수량
2. 매도금액(KRW) = 매도수량 × 체결가 × 환율
3. averagePrice는 변경하지 않음 (매도는 매입원가에 영향 없음)
4. remainingCash: _recalculateCycleState()가 seedAmount - totalBuy + totalSell로 자동 계산
   → 데이터 레벨에서 매도금액은 remainingCash에 포함됨
5. cycle.updatedAt = DateTime.now()
6. save cycle
```

> **V2.2 "복리 없음"의 정확한 의미**: `_recalculateCycleState()`는 항상 `remainingCash = seedAmount - totalBuyKrw + totalSellKrw`로 계산하므로, 데이터 레벨에서 매도 수익은 remainingCash에 포함된다. V2.2에서 "복리 없음"이란 **매수 금액 계산에 매도 수익이 반영되지 않는다**는 뜻이다. V2.2는 고정 `unitAmount`(`seedAmount / totalRounds`)를 사용하므로 remainingCash가 늘어도 매수 단위가 변하지 않는다. V3.0만 `adjustedUnitAmount`(`remainingCash / 남은라운드`)를 사용하여 복리 효과가 발생한다.

### 4.6 3/4 매도 후 잔존 행동 규칙

3/4 지정가 매도만 체결되고 1/4 LOC 매도는 미체결인 경우, 보유수량의 75%가 빠지고 25%가 남는다.

**잔존 상태 규칙:**

| 조건 | 매수 | 매도 | 설명 |
|------|------|------|------|
| 잔존 25% + T < totalRounds + remainingCash > 0 | **계속** | **계속** | 정상 운용, 매수+매도 동시 |
| 잔존 25% + T >= totalRounds 또는 remainingCash <= 0 | 중단 | **계속** | 매도 주문만 계속 걸기 |
| totalShares == 0 | - | - | → **사이클 완료 확인 다이얼로그** (섹션 4.8 참조) |

핵심 원칙: **주식이 남아있는 한 매도 주문은 항상 건다.** 매수 가능 여부는 T값과 잔여현금으로 판단.

### 4.7 사이클 완료 조건 및 확인 절차

사이클 완료는 **자동이 아니라 사용자 확인**이 필요하다.

```
매도 거래 기록 후:
  |
  +-- totalShares > 0?
  |     → 사이클 계속 (아무 일 없음)
  |
  +-- totalShares == 0?
        → ⚠️ 확인 다이얼로그:
           "보유 수량이 0주가 되었습니다.
            사이클을 완료하고 새 사이클을 시작할까요?"
           [완료하기] → 사이클 완료 + 새 사이클 생성 (복리)
           [취소]     → 거래 기록은 유지, 사이클도 유지 (실수 교정 가능)
```

**이유**: 사용자가 수동 입력하므로 실수로 전량 매도를 기록할 수 있다. 자동 완료하면 되돌리기 복잡하지만, 확인 후 "취소"를 누르면 거래 기록을 수정/삭제하여 복구할 수 있다.

### 4.8 입력 검증: 매도 수량 보호

```
매도 수량 입력 시:
  |
  +-- 매도수량 > 보유수량?
  |     → ⚠️ 경고: "보유 수량(12주)보다 많습니다."
  |     → 입력 차단 (자동 보정: 보유수량으로 클램핑)
  |
  +-- 매도수량 == 보유수량?
  |     → 전량 매도 경고: "전량 매도하면 사이클이 완료될 수 있습니다."
  |     → 진행 허용
  |
  +-- 매도수량 < 보유수량?
        → 정상 진행
```

### 4.9 쿼터 손절모드 (V2.2, T가 39.1~40)

원금이 거의 소진된 구간(T가 39.1~40 사이)에서 발동하는 **V2.2 전용 안전장치**이다.

```
쿼터 손절모드 진입 조건: T가 39.1 ~ 40 사이 (1회 매수 시도액이 부족할 때)

Step 1. 쿼터 손절
  → 보유수량 1/4을 MOC(시장가) 매도로 손절

Step 2. 재진입 준비
  → 남은 자금 + 손절 수익금 = 새 시드
  → 새 시드를 10회 분할로 재진입 (쿼터손절모드)

Step 3. 쿼터손절모드 매수
  → -10% LOC 기준 매수 (평단 대비 -10%에서만 매수)

Step 4. 쿼터손절모드 매도
  → ~10회: 누적수량 1/4 → -10% LOC 매도, 나머지 → +10% 지정가 매도
  → 10회 매수 끝난 후: 1/4 MOC 매도

Step 5. 후반전 복귀 조건
  → 매도 1회 성립
  → 또는 2번 MOC 매도에서 -10% 안으로 매도 성립

Step 6. 반복
  → -10% MOC 매도 지속 시 쿼터손절모드 반복
```

> **쿼터 손절모드의 핵심**: 원금 소진 시 "보유만 하고 기다리기"(V1의 약점) 대신, 1/4을 팔아 현금을 확보하고 10회 재진입한다. 이것이 V2.2의 하락장 방어력(-40% MDD)의 핵심 메커니즘이다.

> **앱에서의 쿼터 손절모드 표시**: T가 39.1~40에 도달하면 주문 가이드에 "⚠️ 쿼터 손절모드: MOC 매도 {수량}주 권장" 알림을 표시한다. 사용자가 MOC 매도를 기록하면 앱이 10회 재진입 모드로 전환한다.

### 4.10 신호 체계

V2.2는 매수와 매도가 동시에 이루어지므로, 신호 체계가 V1보다 복합적이다.

**주문 가이드 신호** (앱이 표시하는 "오늘 걸어야 할 주문"):

```
매수 신호 (우선순위):
  1. FIRST_BUY      -- averagePrice == 0 (첫 매수, 1.0 unit 무조건)
  2. BUY_AB         -- 전반전 A+B 주문 (T < 20, 최대 1.0 unit)
  3. BUY_SINGLE     -- 후반전 단일 주문 (T >= 20, 1.0 unit)
  4. HOLD           -- rounds 소진 OR remainingCash <= 0

매도 신호 (매수와 동시, totalShares > 0일 때):
  항상: SELL_LOC_QUARTER + SELL_LIMIT_THREE_Q 동시 표시
```

**거래 기록 신호** (사용자가 체결 결과를 입력할 때 선택):

| 신호 | 의미 | 설명 |
|------|------|------|
| locAB | 전반전 A+B 동시 체결 | 종가 <= 평단 → 1.0 unit |
| locB | 전반전 B만 체결 | 평단 < 종가 <= B가격 → 0.5 unit |
| buySingle | 후반전 단일 체결 | 종가 <= LOC가 → 1.0 unit |
| noFill | LOC 미체결 | 종가 > LOC가 (매수 없음) |
| sellLocQuarter | LOC 매도 체결 (1/4) | 종가 >= LOC가 |
| sellLimitThreeQ | 지정가 매도 체결 (3/4) | 장중 >= 지정가 |
| takeProfitFull | 전량 매도 (1/4 + 3/4 동시) | 둘 다 체결 |
| manual | 수동 매수/매도 | 사용자 임의 거래 |

> **noFill(미체결)은 정상 상황이다**: V2.2에서 종가가 LOC가보다 높으면 매수가 체결되지 않는다. 이는 "현금 보존"이며, 하락장에서 V2.2의 핵심 강점이다. 앱에서는 "📭 오늘 매수 미체결 — 현금이 보존되어 다음 기회에 유리합니다" 안내를 표시한다.

### 4.10 매매 플로우

```
사이클 시작 (시드 설정, 40분할)
  |
  v
unitAmount = seedAmount / 40
  |
  v
매일 주문 가이드 표시
  |
  +-- averagePrice == 0? (첫 매수)
  |     → 1.0 unit 무조건 매수 가이드 표시
  |
  +-- T값 계산: T = ceil((seedAmount - remainingCash) / unitAmount)
  |
  +-- 전반전 (T < 20)?
  |     |
  |     +-- 매수 주문 (2종):
  |     |     A: unitAmount/2 -> 평단가 LOC
  |     |     B: unitAmount/2 -> 평단 x (1 + (10-T/2)%) LOC
  |     |
  |     +-- 매도 주문 (2종, 동시):
  |           sellQuarterPercent 보유량 -> 평단 x (1 + (10-T/2)%) LOC 매도
  |           (1-sellQuarterPercent) 보유량 -> 평단 x (1+takeProfitPercent%) 지정가 매도
  |
  +-- 후반전 (T >= 20)?
  |     |
  |     +-- 매수 주문 (1종):
  |     |     전체: unitAmount -> 평단 x (1 + (10-T/2)%) LOC
  |     |
  |     +-- 매도 주문 (2종, 동시):
  |           (위와 동일)
  |
  +-- 사용자가 체결 결과 입력
  |     -> T값, 평단가, 보유수량 자동 갱신
  |     -> totalShares == 0 → 사이클 완료 확인 다이얼로그
  |
  +-- T >= 40 AND remainingCash <= 0?
        -> 매도 주문만 계속 (매수 없음, 익절 대기)
```

---

## 5. Version 3.0 (Aggressive) — 라오어 최신 (2024)

### 5.1 파라미터

| 파라미터 | 기본값 | 설명 | 허용 범위 |
|----------|--------|------|-----------|
| totalRounds | **20** | 총 분할 매수 회수 | 10 ~ 40 |
| takeProfitPercent | 15% (TQQQ), 20% (SOXL) | 지정가 매도 목표 | 10% ~ 30% |
| sellQuarterPercent | 25% | 부분 매도 비율 (보유수량의 1/4) | 10% ~ 50% |
| compoundEnabled | true | 반복리 활성화 (수익금/40 추가) | true / false |

### 5.2 공식 변경

V3.0의 핵심 변경: LOC 가격 오프셋 공식이 **더 공격적**으로 변경되었다.

#### V2.2 vs V3.0 공식 비교

V3.0의 오프셋 공식은 **종목에 따라 다르다**:

```
V2.2:         오프셋(%) = 10 - T/2       (모든 종목 동일)
V3.0 TQQQ:    오프셋(%) = 15 - 1.5T
V3.0 SOXL:    오프셋(%) = 20 - 2T        (더 공격적)
```

| T값 | V3.0 TQQQ (15-1.5T) | V3.0 SOXL (20-2T) | V2.2 (10-T/2) |
|-----|---------------------|-------------------|---------------|
| 0 | +15.0% | +20.0% | +10.0% |
| 5 | +7.5% | +10.0% | +7.5% |
| 10 | 0.0% | 0.0% | +5.0% |
| 15 | -7.5% | -10.0% | +2.5% |
| 20 | -15.0% | -20.0% | 0.0% |

**핵심 특성:**
- T=0~4: V2.2보다 **더 높은 가격에서 매수 허용** (초기 진입 적극적)
- SOXL은 TQQQ보다 **더 공격적** (변동성이 큰 종목에 더 넓은 범위)
- T=10에서 두 종목 모두 오프셋 0% (V2.2는 T=20에서 0%) → **전환이 2배 빠름**

#### 오프셋 프리셋 시스템

TQQQ/SOXL 외에도 다양한 3배 레버리지 ETF(UPRO, TECL, FAS 등)를 사용할 수 있으므로, 오프셋 공식을 **하드코딩하지 않고 프리셋 + 커스텀**으로 제공한다.

```
일반 공식: 오프셋(%) = a - b × T
```

| 프리셋 | a | b | 익절 목표 | 쿼터모드 별% | 대상 종목 |
|--------|---|---|----------|-------------|----------|
| **TQQQ형** (기본) | 15 | 1.5 | +15% | -15% | TQQQ, UPRO 등 중변동성 |
| **SOXL형** | 20 | 2.0 | +20% | -20% | SOXL, TECL 등 고변동성 |
| **커스텀** | 사용자 입력 | 사용자 입력 | 사용자 입력 | 사용자 입력 | 기타 종목 |

**앱 UI에서의 프리셋 선택** (사이클 생성 시):
```
[오프셋 프리셋]
  ┌──────────┐ ┌──────────┐ ┌──────────┐
  │  TQQQ형  │ │  SOXL형  │ │  커스텀  │
  │ 15-1.5T  │ │  20-2T   │ │  a-b×T   │
  │ 익절 +15%│ │ 익절 +20%│ │ 사용자설정│
  └──────────┘ └──────────┘ └──────────┘
```

버전 선택 시 종목에 따라 프리셋을 자동 추천하되, 사용자가 변경할 수 있다. 프리셋 선택 시 익절 목표와 쿼터모드 별%도 연동된다.

### 5.3 매수 공식

#### ★ T=0 첫 매수 예외 (V2.2와 동일)

```
if (averagePrice == 0 또는 totalShares == 0) {
  → 첫 매수 예외: 현재가(currentPrice) 기준으로 1.0 unit 무조건 매수
}
```

#### 전반전 (T < 10): 2종 주문

> V3.0은 20분할이므로, V2.2(40분할, T<20)와 동일한 원리로 **절반인 T=10이 전환점**이다.

```
A주문 (절반):
  금액 = adjustedUnitAmount / 2  (V3.0 반복리 시 동적 금액)
  LOC 가격 = averagePrice x (1 + locOffset% / 100)
  -> 종가 <= LOC가격 일 때 체결
  (TQQQ: 15-1.5T, SOXL: 20-2T)

B주문 (절반):
  금액 = adjustedUnitAmount / 2
  LOC 가격 = averagePrice (평단가)
  -> 종가 <= 평단가 일 때 체결
```

> **주의: V2.2와 A/B 역할이 반대이다.**
> - V2.2: A = 평단가, B = 오프셋 가격
> - V3.0: A = 오프셋 가격, B = 평단가
>
> 이 차이는 **주문 가이드 UI에서 명시적으로 표시**한다. 거래 이력에는 체결가가 기록되므로, A/B 의미 차이보다 실제 체결가가 중요하다.

**전반전 체결 시나리오:**

| 종가 위치 | A주문 (오프셋) | B주문 (평단) | 총 매수 |
|-----------|--------------|------------|--------|
| 종가 > A가격 > 평단 | 미체결 | 미체결 | 0 |
| 평단 < 종가 <= A가격 | 체결 | 미체결 | 0.5 unit |
| 종가 <= 평단 (둘 다 체결) | 체결 | 체결 | 1.0 unit |

#### 후반전 (T >= 10): 단일 주문

```
단일 주문:
  금액 = adjustedUnitAmount (전체 1회분)
  LOC 가격 = averagePrice x (1 + locOffset% / 100)
  -> 종가 <= LOC가격 일 때 체결
  (TQQQ: 15-1.5T, SOXL: 20-2T)
```

### 5.4 매도 공식 (T <= 19, 일반 매도)

```
매도 주문 1 (LOC 매도, 쿼터):
  수량 = 보유수량 x sellQuarterPercent (기본 1/4)
  LOC 가격 = averagePrice x (1 + locOffset% / 100)
  -> 종가 >= LOC가격 일 때 체결
  (TQQQ: 15-1.5T, SOXL: 20-2T)

매도 주문 2 (지정가 매도, 대량):
  수량 = 보유수량 x (1 - sellQuarterPercent) (기본 3/4)
  지정가 = averagePrice x (1 + takeProfitPercent / 100)
  -> 장중 가격 >= 지정가 일 때 즉시 체결
```

**종목별 오프셋 및 지정가 매도 목표:**

| 종목 | 오프셋 공식 | 지정가 매도 목표 |
|------|------------|-----------------|
| TQQQ | 15 - 1.5T | +15% |
| SOXL | 20 - 2T | +20% |
| 기타 | 사용자 설정 | 사용자 설정 |

### 5.5 쿼터모드 (19 < T < 20)

원금이 거의 소진된 구간(19 < T < 20)에서 발동하는 **특수 매도 모드**이다.

```
쿼터모드 진입 조건: 19 < T < 20

매수:
  쿼터모드 진입 날에는 매수하지 않음
  MOC 매도 후에도 1회 매수금 동일 유지, 이후 5번 더 매수 가능
  이 기간 별% 지점은 고정: TQQQ -15%, SOXL -20%

매도:
  1/4 → MOC 매도 (Market On Close, 종가 시장가 → 무조건 체결)
  3/4 → TQQQ +15% / SOXL +20% 지정가 매도

탈출 조건:
  별% 지점 이상으로 가격이 올라 매도가 되면 쿼터모드 탈출
  → T값 재계산하여 정상 매매 복귀

반복:
  탈출하지 못하면 다시 MOC 매도를 반복
```

> **쿼터모드의 핵심 역할**: 원금 소진 직전에 보유수량의 1/4을 MOC(무조건 체결)로 팔아 현금을 확보한다. 이 현금으로 추가 5회 매수가 가능해져 사이클을 연장한다. 하락장에서 "시드 소진 → 무방비" 상태를 방지하는 안전장치이다.

> **앱에서의 쿼터모드 표시**: 쿼터모드 진입 시 주문 가이드에 "⚠️ 쿼터모드: MOC 매도 {수량}주 + 지정가 매도 {수량}주" 를 별도 강조하여 표시한다.

### 5.6 반복리 (수익금 부분 반영)

V3.0은 **완전한 복리가 아니라 "반복리"**를 사용한다. 수익금의 일부만 즉시 반영하고, 손해 시에는 매수금을 줄이지 않는다.

```
V1/V2.2:
  사이클 내 복리 없음
  익절(전량 매도) -> 새 사이클 시드 = 매도금액 + 잔여현금

V3.0 반복리:
  수익 발생 시: 수익금을 40분할하여 1회 매수금에 추가
  손해 발생 시: 1회 매수금 변경하지 않음 (직전 매수금 유지)
```

#### adjustedUnitAmount 계산 (반복리)

```dart
// 기본 1회 매수금
baseUnitAmount = seedAmount / totalRounds

// 매도 순수익 계산 (별도 필드 저장 불필요, trades에서 실시간 산출)
sellProfit = sum of (sellTrade.amountKrw - sellTrade.shares × averagePrice × sellTrade.exchangeRate)
  // amountKrw: 사용자가 입력한 실제 매도 금액
  // averagePrice: 앱이 관리하는 매수 VWAP
  // exchangeRate: 사용자가 입력한 매도 시 환율

// V3.0 반복리 적용
if (compoundEnabled && steadyVersion == SteadyVersion.v3_0) {
  if (sellProfit > 0) {
    adjustedUnitAmount = baseUnitAmount + (sellProfit / 40);  // 수익금/40 추가
  } else {
    adjustedUnitAmount = baseUnitAmount;  // 손해 시 유지 (줄이지 않음)
  }
}

// V1/V2.2 또는 반복리 비활성화: 초기 고정값
adjustedUnitAmount = baseUnitAmount
```

> **"반복리"인 이유**: 수익금 전체를 다음 매수에 반영하면 변동성이 너무 커진다. 40분할로 나누어 점진적으로 반영하면 안정적인 복리 효과를 얻을 수 있다. 또한 손해 시 매수금을 유지하는 이유는 "반복리이기 때문에 수익의 반이 남아있으므로 그것으로 충당"하기 위해서이다. (원본 라오어 설명)

> **매도 원가 계산이 가능한 이유**: 사용자가 매도 거래를 기록할 때 체결가, 수량, 환율을 직접 입력하고, `averagePrice`(매수 VWAP)는 앱이 자동 관리한다. 따라서 `매도원가 = 수량 × averagePrice × 환율`로 산출 가능하며, 별도 Hive 필드가 필요 없다.

#### T값 계산과 adjustedUnitAmount의 관계

**T값 계산에는 항상 초기 고정 `unitAmount`(`seedAmount / totalRounds`)를 사용한다.** `adjustedUnitAmount`는 T값 산출과 독립적인 별도 프로퍼티이다.

```
                  ┌─────────────────────────┐
                  │ unitAmount (고정)        │
                  │ = seedAmount/totalRounds │
                  └────────┬────────────────┘
                           │
                           v
                  ┌─────────────────┐
                  │ tValue 계산     │ ← remainingCash, totalSellKrw 참조
                  │ (고정 기준)     │
                  └────────┬────────┘
                           │
                           v
                  ┌──────────────────────────────────────┐
                  │ adjustedUnitAmount (반복리)           │
                  │ 수익 시: baseUnit + (profit / 40)     │
                  │ 손해 시: baseUnit (유지)              │
                  └──────────────────────────────────────┘
```

### 5.6 부분 매도 시 사이클 상태 갱신 시퀀스 (V3.0 복리)

V3.0 복리 활성 시, 부분 매도 기록 후 상태 갱신:

```
1. Trade 저장 (매도 기록)
2. _recalculateCycleState() 호출 — 전체 거래 이력에서 재계산:
   - cycle.totalShares = totalBuyShares - totalSellShares
   - cycle.averagePrice = weightedPriceSum / totalBuyShares (매도와 무관, 매수 기준 VWAP)
   - cycle.remainingCash = seedAmount - totalBuyKrw + totalSellKrw
     → V3.0 복리 효과: 매도금액이 remainingCash에 자동 반영됨
     → V2.2도 동일한 공식이지만, V2.2는 adjustedUnitAmount를 쓰지 않으므로 복리 효과 없음
3. cycle.updatedAt = DateTime.now()
4. save cycle
```

> **V3.0 복리는 `_recalculateCycleState()`의 기존 공식이 자동 처리한다.** 별도 V3.0 분기를 추가할 필요 없다. 복리/비복리 차이는 `adjustedUnitAmountWith()` 레벨에서 발생한다.

> **2가지 매도 관련 값의 구분**:
> - `totalSellKrw` (매도 총액): T값 보정에 사용. `cycleRealizedPnlProvider.totalSellKrw`에서 획득.
> - `sellProfit` (매도 순수익): 반복리에 사용. `Cycle.calcSellProfit(trades, averagePrice)`로 산출.
> 두 값은 수학적으로 다르므로 혼동하면 안 된다.

```dart
// steadyOrderGuideProvider에서 사용 시:
final totalSellKrw = ref.watch(cycleRealizedPnlProvider(cycleId))?.totalSellKrw ?? 0.0;
final sellProfit = Cycle.calcSellProfit(trades, cycle.averagePrice);
```

### 5.7 3/4 매도 후 잔존 행동 규칙

V2.2 섹션 4.6과 동일한 규칙을 따른다:
- 주식 남아있으면 매수/매도 모두 계속
- totalShares == 0이면 사이클 완료 확인 다이얼로그

### 5.8 사이클 완료 조건 및 확인 절차

V2.2 섹션 4.7과 동일. 자동 완료 아님, 확인 다이얼로그 필수.

V3.0 특이사항: 사이클 완료 후 새 사이클 시드 계산이 다르다.
```
V1/V2.2: 새 시드 = 마지막 매도금액 + 잔여현금
V3.0:    새 시드 = 마지막 매도금액 + 잔여현금
         (복리로 remainingCash가 이미 매도수익 포함 → 결과적으로 동일한 공식이지만
          잔여현금 값 자체가 V2.2보다 클 수 있음)
```

### 5.10 신호 체계

V2.2 섹션 4.9와 동일한 구조. 차이점:
- LOC 오프셋 공식: TQQQ `15-1.5T`, SOXL `20-2T` (종목별 분리)
- A/B 주문 역할 반전 (UI에서 명시)
- 반복리 시 `adjustedUnitAmount` 기준 금액 표시
- **쿼터모드 신호 추가**: `quarterMode` (19 < T < 20)

### 5.11 매매 플로우

```
사이클 시작 (시드 설정, 20분할)
  |
  v
unitAmount = seedAmount / 20 (T값 계산용 고정)
adjustedUnitAmount = unitAmount (초기값)
  |
  v
매일 주문 가이드 표시
  |
  +-- averagePrice == 0? (첫 매수)
  |     → 1.0 unit 무조건 매수 가이드 표시
  |
  +-- T값 계산: T = ceil((seedAmount - remainingCash + totalSellKrw) / unitAmount)
  |
  +-- 반복리 적용: 수익 시 adjustedUnitAmount = unitAmount + (profit / 40)
  |                손해 시 adjustedUnitAmount = unitAmount (유지)
  |
  +-- 19 < T < 20? (쿼터모드)
  |     |
  |     +-- 매수: 진입일 매수 없음, 이후 5회 매수 가능 (별% 고정: TQ -15%, SOXL -20%)
  |     +-- 매도: 1/4 MOC(무조건 체결) + 3/4 지정가(TQ +15%, SOXL +20%)
  |     +-- 탈출: 별% 이상 매도 → T값 재계산 → 정상 복귀
  |     +-- 반복: 탈출 못하면 다시 MOC 매도
  |
  +-- T < 10? (전반전)
  |     |
  |     +-- 매수 주문 (2종):
  |     |     A: adjustedUnitAmount/2 -> 별% LOC (TQQQ: 15-1.5T, SOXL: 20-2T)
  |     |     B: adjustedUnitAmount/2 -> 평단가 LOC
  |     |
  |     +-- 매도 주문 (T <= 19, 2종 동시):
  |           1/4 보유량 -> 별% LOC 매도
  |           3/4 보유량 -> 지정가 매도 (TQ +15%, SOXL +20%)
  |
  +-- T >= 10? (후반전)
  |     |
  |     +-- 매수 주문 (1종):
  |     |     전체: adjustedUnitAmount -> 별% LOC
  |     |
  |     +-- 매도 주문 (T <= 19, 2종 동시):
  |           (위와 동일)
  |
  +-- 사용자가 체결 결과 입력
  |     -> T값, 평단가, 보유수량, 잔여현금 자동 갱신
  |     -> 반복리: 매도 수익/손해 → adjustedUnitAmount 재계산
  |     -> totalShares == 0 → 사이클 완료 확인 다이얼로그
  |
  +-- T >= 20 AND remainingCash <= 0 AND 쿼터모드 아님?
        -> 매도 주문만 계속 (매수 없음, 익절 대기)
```

---

## 6. 버전별 비교표

### 6.1 전체 비교

| 항목 | V1 (Simple) | V2.2 (Original) | V3.0 (Aggressive) |
|------|-------------|-----------------|-------------------|
| **분할 수** | 40 | 40 | **20** |
| **매수 공식** | 종가 vs 평단 비교 | (10 - T/2)% | **TQQQ: 15-1.5T / SOXL: 20-2T** |
| **매도 방식** | 수익률 전량 매도 | 1/4 LOC + 3/4 지정가 | 1/4 LOC + 3/4 지정가 |
| **매도 시점** | 목표 도달 시만 | **매일 동시** | **매일 동시** |
| **지정가 매도** | +10% | +10% | **종목별 차등** |
| **복리** | 사이클 간 | 사이클 간 | **반복리 (수익금/40 추가)** |
| **T값** | 미사용 | 사용 | 사용 |
| **전반/후반** | 없음 | T<20 / T>=20 | **T<10 / T>=10** |
| **미체결** | 불가 (B 항상 체결) | 가능 | 가능 |
| **부분 익절** | 불가 | **가능** | **가능** |
| **난이도** | 입문 | 중급 | 고급 |

### 6.2 수치 예시 (시드 1,000만원, 평단 $50)

| 항목 | V1 | V2.2 | V3.0 |
|------|-----|------|------|
| 1회 매수액 | 25만원 | 25만원 | **50만원** |
| T=0 매수 LOC가 | $50 (평단) | $55.00 (+10%) | $57.50 (+15%) |
| T=10 매수 LOC가 | $50 (평단) | $52.50 (+5%) | $50.00 (0%) |
| T=20 매수 LOC가 | $50 (평단) | $50.00 (0%) | $35.00 (-30%) |
| 매도 LOC가 (T=10) | 없음 | $52.50 | $50.00 |
| 지정가 매도 | $55.00 (+10%) | $55.00 (+10%) | TQQQ $57.50, SOXL $60.00 |

---

## 7. 데이터 모델

### 7.1 Steady 버전 필드 추가

> **주의**: 기존 `Cycle` 모델에서 `@HiveField(28)`은 `nickname`이 사용 중이다. 새 필드는 **29번부터** 시작한다.

#### 새 enum: SteadyVersion

```dart
@HiveType(typeId: 24)  // 다음 사용 가능한 typeId
enum SteadyVersion {
  @HiveField(0) v1,      // Simple (현재 구현)
  @HiveField(1) v2_2,    // Original (라오어 정통)
  @HiveField(2) v3_0,    // Aggressive (라오어 최신)
}
```

#### Cycle 모델 추가 필드

```dart
// === Strategy B: Steady Cycle 추가 필드 (V2.2/V3.0) ===

@HiveField(29, defaultValue: SteadyVersion.v1)
SteadyVersion steadyVersion;                    // Steady 버전

@HiveField(30, defaultValue: 0.25)
double sellQuarterPercent;                       // 매도 LOC 비율 (기본 1/4 = 25%)

@HiveField(31, defaultValue: false)
bool compoundEnabled;                            // V3.0 반복리 활성화

// === V3.0 오프셋 프리셋 (a - b × T) ===

@HiveField(32, defaultValue: 15.0)
double offsetA;                                  // 오프셋 공식의 a (TQQQ: 15, SOXL: 20)

@HiveField(33, defaultValue: 1.5)
double offsetB;                                  // 오프셋 공식의 b (TQQQ: 1.5, SOXL: 2.0)

@HiveField(34, defaultValue: -15.0)
double quarterModeOffset;                        // 쿼터모드 고정 별% (TQQQ: -15, SOXL: -20)

// === 쿼터 손절모드 상태 (V2.2 전용) ===

@HiveField(35, defaultValue: false)
bool isQuarterStopLossMode;                      // 쿼터 손절모드 진행 중 여부

@HiveField(36, defaultValue: 0)
int quarterStopLossRoundsUsed;                   // 10회 재진입 중 사용한 회차
```

> **V2.2에서 offsetA/offsetB**: V2.2는 고정 공식 `10 - T/2`를 사용하지만, 분할 수가 40이 아닌 경우 `10 - T/2 × (40/A)`로 일반화된다. V2.2에서는 이 필드를 사용하지 않고 `totalRounds` 기반으로 자동 계산한다. offsetA/offsetB/quarterModeOffset은 **V3.0 전용**이다.

> **totalSellKrw와 sellProfit은 Hive에 저장하지 않는다.** 거래 이력(Trade)에서 실시간 계산한다. 이렇게 하면:
> - 거래 삭제/수정 시 자동으로 동기화됨
> - Hive 필드 절약 (accumulatedSellProfit 저장 불필요, trades에서 실시간 계산)
> - 데이터 정합성 보장

#### Hive Adapter 등록

`main.dart`의 Hive 초기화 구간에 추가. **반드시 Cycle box를 열기 전에 등록해야 한다.** 기존 Cycle 데이터에 `steadyVersion` 필드가 없으면 `defaultValue: SteadyVersion.v1`이 적용되는데, 이 시점에 adapter가 미등록이면 역직렬화 크래시가 발생한다.

```dart
// main.dart — 기존 adapter 등록 블록에 추가 (Hive.openBox 호출 전)
Hive.registerAdapter(SteadyVersionAdapter());
```

#### Cycle 생성자 업데이트

3개 신규 필드를 생성자의 named parameter로 추가:

```dart
Cycle({
  // ... 기존 파라미터 ...
  this.nickname = '',
  // === V2.2/V3.0 신규 (HiveField 29~36) ===
  this.steadyVersion = SteadyVersion.v1,
  this.sellQuarterPercent = 0.25,
  this.compoundEnabled = false,
  this.offsetA = 15.0,
  this.offsetB = 1.5,
  this.quarterModeOffset = -15.0,
  this.isQuarterStopLossMode = false,
  this.quarterStopLossRoundsUsed = 0,
  // ...
})
```

#### Cycle.copyWith() 업데이트

`copyWith()`에도 3개 신규 파라미터를 추가해야 한다:

```dart
Cycle copyWith({
  // ... 기존 파라미터 ...
  SteadyVersion? steadyVersion,
  double? sellQuarterPercent,
  bool? compoundEnabled,
  double? offsetA,
  double? offsetB,
  double? quarterModeOffset,
  bool? isQuarterStopLossMode,
  int? quarterStopLossRoundsUsed,
}) {
  final cycle = Cycle(
    // ... 기존 전달 ...
    steadyVersion: steadyVersion ?? this.steadyVersion,
    sellQuarterPercent: sellQuarterPercent ?? this.sellQuarterPercent,
    compoundEnabled: compoundEnabled ?? this.compoundEnabled,
    offsetA: offsetA ?? this.offsetA,
    offsetB: offsetB ?? this.offsetB,
    quarterModeOffset: quarterModeOffset ?? this.quarterModeOffset,
    isQuarterStopLossMode: isQuarterStopLossMode ?? this.isQuarterStopLossMode,
    quarterStopLossRoundsUsed: quarterStopLossRoundsUsed ?? this.quarterStopLossRoundsUsed,
  );
  // ... mutable 필드 복원 ...
  return cycle;
}
```

#### V3.0 복리 시 totalInvestedAmount 의미 변화

`TradingPosition.totalInvestedAmount`는 `seedAmount - remainingCash`로 계산된다. V3.0 복리에서 매도 수익이 remainingCash에 추가되면, totalInvestedAmount가 **감소**한다. 이는 "순 투입 현금(net cash deployed)"으로서 수학적으로 정확하지만, 포트폴리오 UI에서 "투자금이 줄었다"로 보일 수 있다.

**UI 대응**: V3.0 사이클의 포트폴리오 표시에서는 `totalInvestedAmount` 대신 `seedAmount - remainingCash + totalSellKrw` (= 총 매수 투입액)을 별도로 표시하거나, "순투입" vs "총매수"를 구분하여 표시하는 것을 고려한다.

### 7.2 계산 프로퍼티 — Cycle 모델 vs SteadyService 분리

> **배치 원칙**: `AlphaCycleService` 패턴과 일관성을 위해, **자기 필드만으로 되는 단순 파생**은 Cycle 모델에, **외부 데이터를 받는 비즈니스 계산**은 `SteadyService`에 배치한다.

#### Cycle 모델에 추가 (순수 파생 프로퍼티)

```dart
// Cycle 클래스 내 computed property

/// 전반전 여부
bool isFirstHalfWith(double tValue) {
  switch (steadyVersion) {
    case SteadyVersion.v1: return true; // V1은 전반/후반 구분 없음
    case SteadyVersion.v2_2: return tValue < 20;  // 40분할의 절반
    case SteadyVersion.v3_0: return tValue < 10;   // 20분할의 절반
  }
}

/// 쿼터모드 여부
bool isQuarterModeWith(double tValue) {
  switch (steadyVersion) {
    case SteadyVersion.v1: return false;
    case SteadyVersion.v2_2: return tValue >= 39.1;   // V2.2: T가 39.1~40
    case SteadyVersion.v3_0: return tValue > 19 && tValue < 20; // V3.0: 19 < T < 20
  }
}

/// LOC 가격 오프셋(%) — V2.2/V3.0 모두 offsetA/offsetB 사용으로 통일
double locOffsetPercentWith(double tValue) {
  if (steadyVersion == SteadyVersion.v1) return 0;
  return offsetA - offsetB * tValue;
  // V2.2 생성 시: offsetA=10, offsetB=0.5*(40/totalRounds) 자동 설정
  // V3.0 TQQQ: offsetA=15, offsetB=1.5
  // V3.0 SOXL: offsetA=20, offsetB=2.0
}

/// LOC 매수/매도 가격 (USD)
double locPriceWith(double tValue) =>
    averagePrice * (1 + locOffsetPercentWith(tValue) / 100);

/// LOC 매수 가격 (-$0.01 조정, 매도와 겹침 방지)
double locBuyPriceWith(double tValue) =>
    locPriceWith(tValue) - 0.01;

/// 지정가 매도 가격 (USD)
double get limitSellPrice => averagePrice * (1 + takeProfitPercent / 100);
```

#### SteadyService에 배치 (비즈니스 로직)

```dart
// SteadyService 클래스 내 static 메서드

/// T값 계산 — 외부 데이터(totalSellKrw) 의존
static double calcTValue(Cycle cycle, double totalSellKrw) {
  if (cycle.unitAmount <= 0) return 0;
  final invested = cycle.seedAmount - cycle.remainingCash;
  double raw;
  if (cycle.compoundEnabled && cycle.steadyVersion == SteadyVersion.v3_0) {
    // V3.0 반복리 보정: invested + 매도총액 = 순수 매수 투입액
    raw = (invested + totalSellKrw) / cycle.unitAmount;
  } else {
    raw = invested / cycle.unitAmount;
  }
  // 소수점 둘째 자리에서 올림
  return ((raw * 10).ceilToDouble() / 10).clamp(0, cycle.totalRounds.toDouble());
}

/// 반복리 매수금 — 매도 순수익(sellProfit) 기반
static double calcAdjustedUnitAmount(Cycle cycle, double sellProfit) {
  if (!cycle.compoundEnabled || cycle.steadyVersion != SteadyVersion.v3_0) {
    return cycle.unitAmount;
  }
  if (sellProfit > 0) {
    return cycle.unitAmount + (sellProfit / 40); // 수익금/40 추가
  }
  return cycle.unitAmount; // 손해 시 유지
}

/// 매도 순수익 — Trade 리스트 의존
static double calcSellProfit(List<Trade> trades, double averagePrice) {
  double profit = 0;
  for (final t in trades) {
    if (t.action != TradeAction.sell) continue;
    final costKrw = t.shares * averagePrice * t.exchangeRate;
    profit += t.amountKrw - costKrw;
  }
  return profit;
}
```

### 7.3 Hive TypeId 현황 (업데이트)

```
typeId  0: Stock (TAKEN)
typeId  1: Cycle (TAKEN)
typeId  2: Trade (TAKEN)
typeId  3: Settings (TAKEN)
typeId  4: DrawingType enum (TAKEN)
typeId  5: ChartDrawing (TAKEN)
typeId 10: CycleStatus enum (TAKEN)
typeId 11: TradeAction enum (TAKEN)
typeId 12: Holding (TAKEN)
typeId 13: HoldingTransaction (TAKEN)
typeId 14: HoldingTransactionType enum (TAKEN)
typeId 15: WatchlistItem (TAKEN)
typeId 16: NotificationRecord (TAKEN)
typeId 20: StrategyType enum (TAKEN)
typeId 21: TradeSignal enum (TAKEN)
typeId 22: WatchlistGroup (TAKEN)
typeId 23: RecentViewItem (TAKEN)
typeId 24: SteadyVersion enum (신규)
```

### 7.4 TradeSignal enum 확장

V2.2/V3.0 지원을 위해 TradeSignal에 새 값 추가:

```dart
@HiveType(typeId: 21)
enum TradeSignal {
  // Strategy A: Alpha Cycle V3 (기존)
  @HiveField(0) initial,
  @HiveField(1) weightedBuy,
  @HiveField(2) panicBuy,
  @HiveField(3) cashSecure,
  @HiveField(4) takeProfit,

  // Strategy B: Steady V1 (기존)
  @HiveField(5) locA,
  @HiveField(6) locB,
  @HiveField(7) locAB,

  // 공통 (기존)
  @HiveField(8) manual,
  @HiveField(9) hold,

  // Strategy B: Steady V2.2/V3.0 (신규)
  @HiveField(10) sellLocQuarter,     // 매도 LOC 체결 (1/4)
  @HiveField(11) sellLimitThreeQ,    // 지정가 매도 체결 (3/4)
  @HiveField(12) takeProfitFull,     // 전량 매도 (1/4 + 3/4 동시)
  @HiveField(13) buySingle,          // 후반전 단일 매수 (V2.2/V3.0)
  @HiveField(14) noFill,             // LOC 미체결 (V2.2/V3.0)
}
```

### 7.5 직렬화 (백업 호환)

#### 백업 버전 범프: 3 → 4

`data_management_service.dart`의 `backupVersion`을 **3에서 4로** 변경한다. 이유:
- 새 버전 앱의 백업에 `sellLocQuarter`, `v2_2` 등 새 enum 값이 포함됨
- 구 버전 앱(v3 이하)에서 이 백업을 복원하면 `byName()` 크래시 발생
- 버전 4로 범프하면 구 앱이 "지원하지 않는 백업 버전" 메시지로 **안전하게 거부**

새 필드들은 `defaultValue`가 있으므로 기존(v3) 백업 파일에서 복원 시 자동으로 기본값이 적용된다.

```dart
// Cycle.toJson() 추가
'steadyVersion': steadyVersion.name,
'sellQuarterPercent': sellQuarterPercent,
'compoundEnabled': compoundEnabled,
'offsetA': offsetA,
'offsetB': offsetB,
'quarterModeOffset': quarterModeOffset,
'isQuarterStopLossMode': isQuarterStopLossMode,
'quarterStopLossRoundsUsed': quarterStopLossRoundsUsed,

// Cycle.fromJson() 추가 (fallback 처리 포함)
steadyVersion: _parseSteadyVersion(json['steadyVersion'] as String?),
sellQuarterPercent: (json['sellQuarterPercent'] as num?)?.toDouble() ?? 0.25,
compoundEnabled: json['compoundEnabled'] as bool? ?? false,
offsetA: (json['offsetA'] as num?)?.toDouble() ?? 15.0,
offsetB: (json['offsetB'] as num?)?.toDouble() ?? 1.5,
quarterModeOffset: (json['quarterModeOffset'] as num?)?.toDouble() ?? -15.0,
isQuarterStopLossMode: json['isQuarterStopLossMode'] as bool? ?? false,
quarterStopLossRoundsUsed: json['quarterStopLossRoundsUsed'] as int? ?? 0,

// 안전한 enum 파싱 (구 버전 호환)
static SteadyVersion _parseSteadyVersion(String? value) {
  if (value == null) return SteadyVersion.v1;
  try {
    return SteadyVersion.values.byName(value);
  } catch (_) {
    return SteadyVersion.v1; // 알 수 없는 값 → V1 fallback
  }
}
```

**TradeSignal.fromJson 안전 파싱:**

```dart
// Trade.fromJson에서 signal 파싱
signal: _parseTradeSignal(json['signal'] as String),

static TradeSignal _parseTradeSignal(String value) {
  try {
    return TradeSignal.values.byName(value);
  } catch (_) {
    return TradeSignal.manual; // 알 수 없는 신호 → manual fallback
  }
}
```

> **백업 호환 시나리오**: 새 버전 앱에서 만든 백업을 구 버전 앱에서 복원하면, 새 enum 값(v2_2, sellLocQuarter 등)을 알 수 없다. fallback 처리로 크래시 없이 기본값으로 대체된다.

---

## 8. SteadyOrderGuide DTO

V2.2/V3.0은 매수+매도 복합 주문을 동시에 표시해야 한다. 기존 `StrategyEngine`의 단일 `TradeSignal` 반환으로는 부족하므로, **주문 가이드 데이터 묶음**을 새로 정의한다.

### 8.1 데이터 구조

```dart
/// V2.2/V3.0 주문 가이드 (오늘 걸어야 할 주문 전체)
class SteadyOrderGuide {
  // === 상태 정보 ===
  final double tValue;
  final bool isFirstHalf;
  final double locOffsetPercent;
  final double locPrice;            // LOC 주문가 (USD)
  final double limitSellPrice;      // 지정가 매도가 (USD)
  final bool canBuy;                // 매수 가능 여부 (T < totalRounds AND remainingCash > 0)
  final bool isFirstBuy;            // 첫 매수 여부 (averagePrice == 0)

  // === 매수 주문 (null이면 해당 주문 없음) ===
  final OrderItem? buyOrderA;       // 전반전 A주문
  final OrderItem? buyOrderB;       // 전반전 B주문
  final OrderItem? buySingleOrder;  // 후반전 단일주문

  // === 매도 주문 (totalShares > 0일 때만) ===
  final OrderItem? sellLocOrder;    // LOC 매도 (1/4)
  final OrderItem? sellLimitOrder;  // 지정가 매도 (3/4)

  const SteadyOrderGuide({...});
}

/// 개별 주문 항목
class OrderItem {
  final String label;           // "LOC A: 평단가" 등
  final double price;           // USD
  final double shares;          // 주문 수량
  final double amountKrw;       // 주문 금액 (KRW)
  final String description;     // "+4.0%" 등 부가 설명

  const OrderItem({...});
}
```

### 8.2 생성 위치

`SteadyV22Service`와 `SteadyV30Service`에 정적 메서드로 생성:

```dart
static SteadyOrderGuide generateGuide({
  required Cycle cycle,
  required double currentPrice,
  required double exchangeRate,
  required double totalSellKrw,    // T값 보정용: 매도 총액 (cycleRealizedPnlProvider.totalSellKrw)
  required double sellProfit,      // 반복리용: 매도 순수익 (Cycle.calcSellProfit)
}) { ... }

// 내부에서:
// final tValue = cycle.tValueWith(totalSellKrw);        // T값 보정
// final adjUnit = cycle.adjustedUnitAmountWith(sellProfit); // 반복리
```

### 8.3 Provider

```dart
/// V2.2/V3.0 주문 가이드 Provider
final steadyOrderGuideProvider =
    Provider.family<SteadyOrderGuide?, String>((ref, cycleId) {
  final cycle = ...;
  if (cycle.strategyType != StrategyType.infiniteBuy) return null;
  if (cycle.steadyVersion == SteadyVersion.v1) return null;

  final currentPrice = ...;
  final exchangeRate = ...;
  // T값 보정용: 매도 총액
  final pnl = ref.watch(cycleRealizedPnlProvider(cycleId));
  final totalSellKrw = pnl?.totalSellKrw ?? 0.0;

  // 반복리용: 매도 순수익 (trades + averagePrice로 계산)
  final trades = ref.watch(tradeListProvider(cycleId));
  final sellProfit = Cycle.calcSellProfit(trades, cycle.averagePrice);

  return cycle.steadyVersion == SteadyVersion.v2_2
      ? SteadyV22Service.generateGuide(...)
      : SteadyV30Service.generateGuide(...);
});
```

### 8.4 기존 StrategyEngine과의 관계

- `StrategyEngine.detectSignal()` / `calculateAmount()`는 기존 V1과 Smart Cycle에서 계속 사용
- V2.2/V3.0에서도 `detectSignal()`은 유지하되, **주요 매수 신호**(locAB/buySingle/hold)만 반환
- 상세 주문 정보는 `SteadyOrderGuide`에서 제공
- 기존 인터페이스를 변경하지 않으므로 Smart Cycle과 V1에 영향 없음

---

## 9. 앱 UI 가이드

### 9.1 사이클 설정 시 버전 선택

`cycle_setup_screen.dart`에서 전략이 Steady Cycle일 때 버전 선택 UI를 표시한다.

```
[전략 선택]
  ┌─────────────┐ ┌─────────────┐
  │ Smart Cycle  │ │ Steady Cycle│  <-- SegmentedButton
  └─────────────┘ └─────────────┘

[Steady 버전 선택] (Steady 선택 시에만 표시)
  ┌────────┐ ┌────────┐ ┌────────┐
  │  V1    │ │ V2.2   │ │ V3.0   │  <-- SegmentedButton
  │ Simple │ │Original│ │  Aggr  │
  └────────┘ └────────┘ └────────┘
```

#### 버전 비교 카드

버전 선택 아래에 **선택된 버전의 한 줄 요약** 카드를 표시한다:

```
┌─ V1 Simple ──────────────────────────┐
│ 40분할 · 단순 매수 · 전량 익절       │
│ 🟢 입문자 추천 · 상승장 최고 효율    │
└──────────────────────────────────────┘

┌─ V2.2 Original ─────────────────────┐
│ 40분할 · T값 LOC · 매일 매수+매도    │
│ 🛡️ 하락장 방어 우수 (MDD -40%)      │
└──────────────────────────────────────┘

┌─ V3.0 Aggressive ───────────────────┐
│ 20분할 · 공격적 LOC · 사이클 내 복리 │
│ ⚡ 고변동성(SOXL) 시너지             │
└──────────────────────────────────────┘
```

#### 버전 선택 시 기본값 자동 설정

| 파라미터 | V1 | V2.2 | V3.0 TQQQ형 | V3.0 SOXL형 |
|----------|-----|------|------------|------------|
| totalRounds | 40 | 40 | 20 | 20 |
| takeProfitPercent | 10% | 10% | 15% | 20% |
| sellQuarterPercent | - | 25% | 25% | 25% |
| compoundEnabled | - | - | true | true |
| offsetA | - | **10** | **15** | **20** |
| offsetB | - | **0.5×(40/A)** | **1.5** | **2.0** |
| quarterModeOffset | - | **-10** | **-15** | **-20** |

> **V2.2의 offsetA/offsetB 자동 계산**: V2.2 선택 시 `offsetA = 10`, `offsetB = 0.5 × (40/totalRounds)`. 사용자가 분할수(totalRounds)를 변경하면 offsetB가 자동 재계산된다. 이로써 `locOffsetPercentWith()` 코드에서 V2.2/V3.0 분기가 사라지고 `offsetA - offsetB × T` 단일 공식으로 통일된다.

#### 고급 설정 (버전별 차등)

```
V1:   [분할 횟수] 슬라이더 + [익절 목표] 슬라이더
V2.2: [분할 횟수] + [익절 목표] + [매도 LOC 비율] 슬라이더
V3.0: [분할 횟수] + [익절 목표] + [매도 LOC 비율] + [복리 활성화] 토글
```

### 9.2 CycleDetailScreen: 오늘의 주문 가이드

#### T값 진행률 바

V2.2/V3.0 사이클 상세 화면 상단에 T값 진행률을 시각적으로 표시:

```
T: 12/40  ███████░░░░░░░░░░░░░░  전반전
                    ↑
               오프셋 +4.0%
          (전환점: T=20)
```

- 전반전: 파란색 바
- 후반전: 주황색 바
- 전환점(V2.2: T=20, V3.0: T=10)에 구분선 표시

#### V1 표시 정보 (기존과 동일)

```
┌──────────────────────────────────┐
│  Steady V1 · TQQQ               │
│  회차: 15/40  잔여: 6,250,000원  │
│                                  │
│  ── 오늘의 가이드 ──             │
│  📊 현재가: $45.20               │
│  📊 평단가: $48.30               │
│  📊 수익률: -6.42%               │
│                                  │
│  🔵 매수: 250,000원 (A+B, 평단↓) │
│     LOC A: $48.30에 2주           │
│     LOC B: 무조건 2주             │
└──────────────────────────────────┘
```

#### V2.2 표시 정보

```
┌──────────────────────────────────────┐
│  Steady V2.2 · TQQQ                 │
│  T: 12/40  전반전  잔여: 7,000,000원 │
│  ███████░░░░░░░░░░░░░░  오프셋 +4.0%│
│                                      │
│  ── 오늘의 주문 가이드 ──            │
│  📊 현재가: $45.20                   │
│  📊 평단가: $48.30                   │
│  📊 LOC가: $50.23 (+4.0%)           │
│                                      │
│  ── 매수 주문 ──                     │
│  🔵 LOC A: $48.30에 2주 (평단) [📋] │
│  🔵 LOC B: $50.23에 2주 (+4.0%)[📋] │
│                                      │
│  ── 매도 주문 (동시) ──              │
│  🟢 LOC 매도: $50.23에 3주 (1/4)[📋]│
│  🟢 지정가: $53.13에 9주 (3/4) [📋] │
└──────────────────────────────────────┘
```

#### V3.0 표시 정보

```
┌──────────────────────────────────────┐
│  Steady V3.0 · TQQQ                 │
│  T: 8/20  전반전  잔여: 6,000,000원  │
│  ████████████░░░░░░░░  오프셋 +3.0%  │
│  복리 활성 ✓                         │
│                                      │
│  ── 오늘의 주문 가이드 ──            │
│  📊 현재가: $45.20                   │
│  📊 평단가: $48.30                   │
│  📊 LOC가: $49.75 (+3.0%)           │
│  📊 조정 1회분: 500,000원            │
│     (복리로 인한 동적 금액)           │
│                                      │
│  ── 매수 주문 ──                     │
│  🔵 LOC A: $49.75에 3주 (+3.0%)[📋] │
│  🔵 LOC B: $48.30에 3주 (평단) [📋] │
│                                      │
│  ── 매도 주문 (동시) ──              │
│  🟢 LOC 매도: $49.75에 5주 (1/4)[📋]│
│  🟢 지정가: $55.55에 15주 (3/4)[📋] │
│     (TQQQ +15%)                      │
└──────────────────────────────────────┘
```

#### 클립보드 복사 [📋]

각 주문 항목 오른쪽의 [📋] 버튼을 누르면 **"$50.23 / 2주"** 형태로 클립보드에 복사된다. 증권사 앱에 붙여넣기 편의를 위한 기능.

#### 미체결 안내

현재가가 LOC가보다 높아 매수 미체결이 예상되는 경우:

```
┌──────────────────────────────────────┐
│  📭 오늘 매수 미체결 예상            │
│  현재가 $52.10 > LOC가 $50.23       │
│                                      │
│  정상입니다. 현금이 보존되어          │
│  다음 기회에 유리합니다.              │
└──────────────────────────────────────┘
```

### 9.3 거래 입력: 기존 패턴과 동일하게

> **핵심 원칙**: V2.2/V3.0이라고 해서 거래 입력이 복잡해지면 안 된다. Smart Cycle이나 V1과 **동일한 패턴**(가격 + 수량 입력)을 유지한다. 복잡한 계산은 앱이 처리하고, 사용자는 증권사에서 체결된 결과만 기록한다.

#### 거래 기록 플로우 (V2.2/V3.0)

```
[거래 기록] FAB 탭
  |
  +-- [매수] / [매도] 탭 선택
  |
  +-- 매수 탭:
  |     신호 자동 추천 (현재 T값 기반):
  |       전반전 → "LOC A+B" 또는 "LOC B만" 추천
  |       후반전 → "단일 매수" 추천
  |     입력 필드: [체결가 $___] [수량 ___주]
  |     환율: 메인 화면의 평균환율 자동 적용 (수정 가능)
  |     → [기록] 버튼
  |
  +-- 매도 탭:
        신호 자동 추천:
          "LOC 매도 (1/4)" 또는 "지정가 매도 (3/4)" 추천
        입력 필드: [체결가 $___] [수량 ___주]
        환율: 메인 화면의 평균환율 자동 적용 (수정 가능)
        → [기록] 버튼
```

**기존 cycle_trade_record_sheet와의 차이**:
- 입력 필드 동일: 체결가(USD) + 수량
- 환율: 메인 화면 평균환율 사용 (사용자가 수정 가능, Smart Cycle과 동일 패턴)
- 신호 칩: 현재 상태에 맞는 신호를 **자동 추천** (사용자가 변경 가능)
- 금액(KRW): 체결가 × 수량 × 환율로 자동 계산

#### 반복리 — 사용자에게 보이는 방식

반복리 계산은 **앱이 자동으로 처리**하며, 사용자에게는 결과만 보여준다:

```
┌──────────────────────────────────────┐
│  📊 1회 매수금: 525,000원            │
│     (기본 500,000 + 수익반영 25,000) │ ← 이 한 줄이면 충분
└──────────────────────────────────────┘
```

사용자는 "다음 매수금이 52.5만원이구나"만 알면 된다. 수익금/40분할 같은 공식은 보여줄 필요 없다.

손해가 발생하면:
```
┌──────────────────────────────────────┐
│  📊 1회 매수금: 500,000원 (유지)     │
│     손해 발생 시 매수금 변동 없음    │
└──────────────────────────────────────┘
```

#### 쿼터모드 — 사용자에게 보이는 방식

쿼터모드 진입 시에도 복잡한 규칙 대신 **명확한 안내**만 표시:

```
V2.2 (T ≈ 39.1~40):
┌──────────────────────────────────────┐
│  ⚠️ 원금 소진 — 쿼터 손절모드       │
│                                      │
│  오늘의 주문:                        │
│  🔴 MOC 매도: 3주 (보유의 1/4)      │
│     → 종가에 무조건 체결됩니다       │
│                                      │
│  체결 후 기록하면 10회 재진입이       │
│  자동으로 시작됩니다.                │
└──────────────────────────────────────┘

V3.0 (19 < T < 20):
┌──────────────────────────────────────┐
│  ⚠️ 쿼터모드                        │
│                                      │
│  오늘의 주문:                        │
│  🔴 MOC 매도: 5주 (보유의 1/4)      │
│  🟢 지정가 매도: 15주 (+15%)        │
│                                      │
│  오늘은 매수하지 않습니다.           │
│  체결 후 기록해주세요.               │
└──────────────────────────────────────┘
```

#### 입력 검증 (기존과 동일)

- 매도 수량 > 보유수량 → 경고 + 보유수량으로 클램핑
- 매도 후 totalShares == 0 → 사이클 완료 확인 다이얼로그
- 체결가 0 이하 → 입력 차단

### 9.4 StrategyBadge 표시

```dart
// strategy_badge.dart 확장
// SteadyVersion? 옵셔널 파라미터 추가

// 표시:
// V1 또는 null → "Steady"
// V2.2 → "Steady V2.2"
// V3.0 → "Steady V3.0"
```

### 9.5 SignalBadgeConfig 확장

```dart
// 새 5개 신호에 대한 배지 설정
sellLocQuarter  → label: 'LOC매도¼',  color: green500
sellLimitThreeQ → label: '지정가¾',   color: green600
takeProfitFull  → label: '전량익절',   color: green500
buySingle       → label: '단일매수',   color: blue500
noFill          → label: '미체결',     color: gray400
```

---

## 10. 백테스트 결과

**시드**: 1억원 | **환율**: 1,350원/USD | **소스**: `backtest_all_versions.py`

### 10.1 2025 상승장 (2025-01 ~ 2026-01)

TQQQ: $39.31 → $57.06 (+45.1%, 268거래일)

| 항목 | V1 (현재) | V2.2 (정통) | V3.0 (공격) | Buy&Hold |
|------|----------|------------|------------|----------|
| **수익률** | **+40.96%** | +19.59% | +23.46% | +45.14% |
| 최종자산 | 14,096만 | 11,959만 | 12,346만 | 14,514만 |
| 사이클 | 5회 | 5회 | 2회 | - |
| MDD | -45.99% | **-29.23%** | -34.78% | -56.97% |
| 효율(수익/MDD) | **0.89** | 0.67 | 0.67 | 0.79 |

SOXL: $27.67 → $70.09 (+153.3%, 268거래일)

| 항목 | V1 (현재) | V2.2 (정통) | V3.0 (공격) | Buy&Hold |
|------|----------|------------|------------|----------|
| **수익률** | **+95.18%** | +53.33% | +85.84% | +153.31% |
| 최종자산 | 19,518만 | 15,333만 | 18,584만 | 25,331만 |
| 사이클 | 14회 | 17회 | 8회 | - |
| MDD | **-45.53%** | -45.53% | -51.24% | -76.53% |
| 효율(수익/MDD) | **2.09** | 1.17 | 1.68 | 2.00 |

> **상승장 요약**: V1이 가장 높은 수익률과 효율을 기록. V2.2는 LOC 가격 제한으로 매수 미체결이 잦아 현금 비중이 높음(80%+ 유휴). V3.0는 20분할+복리로 V2.2보다 우수하나 V1에는 미달.

### 10.2 2022 하락장 (2022-01 ~ 2023-01)

TQQQ: $42.78 → $8.65 (-79.8%, 251거래일)

| 항목 | V1 (현재) | V2.2 (정통) | V3.0 (공격) | Buy&Hold |
|------|----------|------------|------------|----------|
| **수익률** | -70.98% | **-21.76%** | -62.04% | -79.78% |
| 최종자산 | 2,902만 | **7,824만** | 3,796만 | 2,022만 |
| 사이클 | 0회 | 2회 | 1회 | - |
| MDD | -74.17% | **-40.26%** | -64.54% | -81.11% |

SOXL: $72.10 → $9.67 (-86.6%, 251거래일)

| 항목 | V1 (현재) | V2.2 (정통) | V3.0 (공격) | Buy&Hold |
|------|----------|------------|------------|----------|
| **수익률** | -79.11% | -68.33% | **-10.22%** | -86.59% |
| 최종자산 | 2,089만 | 3,167만 | **8,978만** | 1,341만 |
| 사이클 | 0회 | 0회 | **3회** | - |
| MDD | -85.22% | -77.63% | **-53.85%** | -90.39% |

> **하락장 요약**:
> - **TQQQ**: V2.2 압도적 우승. LOC 가격 제한이 하락장에서 안전장치 역할 → 미체결로 현금 보존 → MDD -40.26%(V1 -74.17% 대비 절반).
> - **SOXL**: V3.0이 놀라운 방어력(-10.22%). 20분할+높은 익절(+20%)+복리로 하락장 중에서도 3회 사이클 완료.
> - **V1**: 40분할을 초반에 모두 소진하고 하락을 고스란히 맞음. 사이클 완료 0회.

### 10.3 2022-2023 하락→회복 (2022-01 ~ 2024-01)

TQQQ: $42.78 → $25.35 (-40.7%, 501거래일)

| 항목 | V1 (현재) | V2.2 (정통) | V3.0 (공격) | Buy&Hold |
|------|----------|------------|------------|----------|
| **수익률** | -14.94% | **+20.65%** | -9.59% | -40.75% |
| 최종자산 | 8,506만 | **12,065만** | 9,041만 | 5,925만 |
| 사이클 | 0회 | **12회** | 4회 | - |
| MDD | -74.17% | **-40.26%** | -64.54% | -81.11% |

SOXL: $72.10 → $31.40 (-56.4%, 501거래일)

| 항목 | V1 (현재) | V2.2 (정통) | V3.0 (공격) | Buy&Hold |
|------|----------|------------|------------|----------|
| **수익률** | -32.17% | -4.19% | **+61.86%** | -56.45% |
| 최종자산 | 6,783만 | 9,581만 | **16,186만** | 4,355만 |
| 사이클 | 0회 | 3회 | **11회** | - |
| MDD | -85.22% | -77.63% | **-53.85%** | -90.39% |

> **하락→회복 요약**:
> - **TQQQ**: V2.2 유일하게 **플러스 수익(+20.65%)**.
> - **SOXL**: V3.0이 **+61.86%**로 압도적 1위.

### 10.4 종합 분석

#### 버전 선택 가이드

| 상황 | 추천 버전 | 이유 |
|------|----------|------|
| **입문자 / 단순 운용** | V1 | 가장 단순, 상승장에서 최고 수익률 |
| **TQQQ + 시장 불확실** | V2.2 | 하락장 MDD -40% (V1의 절반), 회복기 유일한 플러스 |
| **SOXL + 공격적 운용** | V3.0 | 하락장에서도 -10%, 회복기 +62% 경이적 성과 |
| **장기 투자 (2년+)** | V2.2 (TQQQ) / V3.0 (SOXL) | 하락→회복 사이클에서 압도적 성과 |

#### 주요 발견

1. **V2.2의 역설**: 상승장에서 "매수 미체결"이라는 약점이 하락장에서 "현금 보존"이라는 강점으로 변환
2. **V3.0의 SOXL 시너지**: 20분할 빠른 투입 + 높은 변동성 = 빠른 사이클 회전
3. **V1의 한계**: 40분할 초반 소진 후 하락장에서 무방비. 상승장 전용 전략에 가까움
4. **복리의 힘**: V3.0 SOXL 하락→회복에서 11회 사이클 × 복리 = +61.86% (B&H -56.45%와 118%p 차이)

---

## 11. 구현 우선순위

### Phase 1: 데이터 모델 + exhaustive switch 동시 수정 + 코드 생성

> **중요**: TradeSignal enum에 5개 값을 추가하면 exhaustive switch를 사용하는 파일이 **즉시 컴파일 에러**를 발생시킨다. 따라서 enum 변경과 switch 업데이트를 **반드시 같은 Phase에서** 처리해야 한다.

```
수정: lib/data/models/cycle.dart    (SteadyVersion enum, 3개 필드, 계산 프로퍼티, 생성자, copyWith, 직렬화)
수정: lib/data/models/trade.dart    (TradeSignal 5개 추가 + fromJson 안전 파싱)
수정: lib/main.dart                 (SteadyVersionAdapter 등록 — Cycle box 열기 전)
수정: lib/presentation/widgets/shared/signal_badge_config.dart  (5개 신호 배지 추가 — exhaustive switch 수정)
수정: lib/presentation/widgets/cycle/signal_display.dart        (5개 신호 표시 설정 — exhaustive switch 수정)
실행: flutter pub run build_runner build --delete-conflicting-outputs
```

### Phase 2: V2.2 + V3.0 도메인 로직 (통합 서비스)

> **아키텍처 결정**: V2.2와 V3.0을 별도 파일로 분리하지 않고 **하나의 `SteadyService`로 통합**한다.
> - 공통 로직(T값, LOC가격, 신호감지 구조)이 **80%**를 차지
> - 오프셋 공식 차이는 `offsetA/offsetB` 필드로 이미 통일됨
> - 반복리/쿼터모드 같은 **진짜 다른 부분만 private 메서드로 격리**
> - `AlphaCycleService`가 단일 클래스인 것과 동일한 패턴

> **V1(`InfiniteBuyService`)은 건드리지 않는다.** V1은 T값, LOC 오프셋, 동시 매수/매도가 모두 없어 V2.2/V3.0과 공유 로직이 거의 없다. Provider에서 `steadyVersion == v1`이면 `InfiniteBuyService`, 아니면 `SteadyService`로 라우팅한다.

```
신규: lib/domain/trading/steady_order_guide.dart   (SteadyOrderGuide + OrderItem DTO)
신규: lib/domain/trading/steady_service.dart        (V2.2 + V3.0 통합 서비스)
```

#### `steady_service.dart` 내부 구조

```dart
class SteadyService implements StrategyEngine {
  const SteadyService();

  // ══════════════════════════════════════════
  // 공통 (V2.2 + V3.0 동일, ~80%)
  // ══════════════════════════════════════════

  /// T값 계산 (외부 데이터 의존 → 모델이 아닌 서비스에 배치)
  static double calcTValue(Cycle cycle, double totalSellKrw) { ... }

  /// 반복리 매수금 계산 (비즈니스 로직 → 서비스에 배치)
  static double calcAdjustedUnitAmount(Cycle cycle, double sellProfit) { ... }

  /// 매도 순수익 계산 (Trade 리스트 의존 → 서비스에 배치)
  static double calcSellProfit(List<Trade> trades, double averagePrice) { ... }

  /// 주문 가이드 생성 (공통 플로우 + 버전별 분기)
  static SteadyOrderGuide generateGuide({
    required Cycle cycle,
    required double currentPrice,
    required double exchangeRate,
    required double totalSellKrw,
    required double sellProfit,
  }) {
    // 공통: T값, LOC가격, 매수/매도 주문 생성
    // ...

    // 쿼터모드 분기 (진짜 다른 부분만 격리)
    if (cycle.isQuarterModeWith(t)) {
      return cycle.steadyVersion == SteadyVersion.v2_2
          ? _v22QuarterGuide(cycle, ...)
          : _v30QuarterGuide(cycle, ...);
    }

    // 반복리 (V3.0만)
    final unit = cycle.compoundEnabled
        ? calcAdjustedUnitAmount(cycle, sellProfit)
        : cycle.unitAmount;
    // ...
  }

  @override
  TradeSignal detectSignal({...}) { ... }  // 공통 신호 감지

  @override
  double? calculateAmount({...}) { ... }   // 공통 금액 계산

  // ══════════════════════════════════════════
  // V2.2 전용 (~10%)
  // ══════════════════════════════════════════

  /// V2.2 쿼터 손절모드 주문 가이드 (T 39.1~40, 10회 재진입)
  static SteadyOrderGuide _v22QuarterGuide(Cycle cycle, ...) { ... }

  // ══════════════════════════════════════════
  // V3.0 전용 (~10%)
  // ══════════════════════════════════════════

  /// V3.0 쿼터모드 주문 가이드 (19 < T < 20, MOC + 5회 추가매수)
  static SteadyOrderGuide _v30QuarterGuide(Cycle cycle, ...) { ... }
}
```

> **계산 프로퍼티 위치 정리**: `AlphaCycleService` 패턴과 일관성을 위해, **외부 데이터를 받는 비즈니스 계산**은 `SteadyService`에 배치하고, **자기 필드만으로 되는 단순 파생**은 `Cycle` 모델에 유지한다.
>
> | Cycle 모델 (순수 파생) | SteadyService (비즈니스 로직) |
> |---|---|
> | `locOffsetPercentWith(t)` | `calcTValue(cycle, totalSellKrw)` |
> | `isFirstHalfWith(t)` | `calcAdjustedUnitAmount(cycle, sellProfit)` |
> | `isQuarterModeWith(t)` | `calcSellProfit(trades, avgPrice)` |
> | `locPriceWith(t)`, `locBuyPriceWith(t)` | `generateGuide(...)` |
> | `limitSellPrice` | |

### Phase 3: Provider 계층

```
수정: lib/presentation/providers/cycle_providers.dart
  - 전략 서비스 라우팅: steadyVersion별 분기:
      V1 → InfiniteBuyService (기존 유지)
      V2.2/V3.0 → SteadyService (신규)
  - addCycle(): 8개 신규 파라미터 추가
  - completeTakeProfit(): Steady 전용 필드 이월:
      steadyVersion, sellQuarterPercent, compoundEnabled,
      offsetA, offsetB, quarterModeOffset
      (isQuarterStopLossMode/quarterStopLossRoundsUsed → 새 사이클에서 리셋)

신규: lib/presentation/providers/steady_providers.dart
  - steadyOrderGuideProvider (관심사 분리, cycle_providers.dart 비대화 방지)
  - totalSellKrw → cycleRealizedPnlProvider 재사용
  - sellProfit → SteadyService.calcSellProfit(trades, averagePrice)

수정: lib/presentation/providers/trade_providers.dart
  - _recalculateCycleState() roundsUsed 카운팅 수정:
      기존 버그 수정: TradeSignal.manual 제거 (V1 설계서: 수동 매수는 roundsUsed 증가 안 함)
      추가: TradeSignal.locA (기존 누락)
      추가: TradeSignal.buySingle (V2.2/V3.0 후반전)
  - V3.0 복리: _recalculateCycleState()의 기존 공식
      (remainingCash = seedAmount - totalBuy + totalSell)이 이미 처리하므로
      별도 분기 불필요.
```

### Phase 5: UI - 설정 화면

```
수정: lib/presentation/screens/stocks/cycle_setup_screen.dart
  - 3개 상태 변수 추가: _steadyVersion, _sellQuarterPercent, _compoundEnabled
  - Steady 버전 선택 SegmentedButton (V1/V2.2/V3.0)
  - 버전 비교 카드 (한 줄 요약)
  - 버전 전환 시 기본값 자동 리셋
  - 고급 설정: 버전별 슬라이더 분기 (V2.2: +매도비율, V3.0: +매도비율+복리토글)
  - _createCycle()에 3개 신규 파라미터 전달

수정: lib/presentation/screens/stocks/widgets/cycle_settings_sheet.dart
  - V2.2/V3.0 파라미터 슬라이더 추가
  - steadyVersion 읽기 전용 표시 (변경 불가)
  - _save()에 신규 필드 저장
```

### Phase 6: UI - 상세 화면

```
수정: lib/presentation/screens/stocks/cycle_detail_screen.dart         (V2.2/V3.0 주문 가이드 통합)
수정: lib/presentation/screens/stocks/widgets/cycle_info_card.dart     (T값, 오프셋, LOC가 표시)
신규: lib/presentation/screens/stocks/widgets/steady_order_guide_card.dart (주문 가이드 카드 + 클립보드 복사 + 미체결 안내)
수정: lib/presentation/widgets/cycle/strategy_badge.dart               (SteadyVersion? 파라미터 추가)
```

### Phase 7: UI - 거래 기록

```
수정: lib/presentation/screens/stocks/widgets/cycle_trade_card.dart
  - buySignalsFor/sellSignalsFor 시그니처 변경:
      static List<TradeSignal> buySignalsFor(StrategyType type, {SteadyVersion? steadyVersion})
      static List<TradeSignal> sellSignalsFor(StrategyType type, {SteadyVersion? steadyVersion})
  - V1: 기존 [locAB, locB, manual] 유지
  - V2.2/V3.0 매수: [locAB, locA, locB, buySingle, manual]
  - V2.2/V3.0 매도: [sellLocQuarter, sellLimitThreeQ, takeProfitFull, takeProfit, manual]
  - 호출부 7곳 수정 (cycle_trade_record_sheet.dart 등)

수정: lib/presentation/screens/stocks/widgets/cycle_trade_record_sheet.dart
  - V2.2/V3.0 매도 선택지 확장
  - 매도 수량 > 보유수량 입력 검증 + 경고
  - 매도 후 totalShares == 0 → 사이클 완료 확인 다이얼로그
```

### Phase 8: 통합 및 정리

```
수정: lib/data/services/data_management_service.dart
  - backupVersion: 3 → 4 범프
  - 복원 시 버전 체크 로직 확인
  - Cycle.fromJson/Trade.fromJson fallback 파싱 동작 확인

실행: flutter pub run build_runner build --delete-conflicting-outputs (최종)
테스트: ./build.sh + Playwright MCP 검증
```

---

## 12. 기존 V1 사이클 마이그레이션

기존 V1 사이클의 마이그레이션은 **자동이며 무개입**이다:

1. `steadyVersion` 기본값 `SteadyVersion.v1` → 기존 V1 사이클은 자동으로 V1으로 동작
2. `sellQuarterPercent` 기본값 `0.25` → V1에서는 사용하지 않으므로 무영향
3. `compoundEnabled` 기본값 `false` → V1에서는 사용하지 않으므로 무영향

**기존 V1 사이클을 V2.2/V3.0으로 변경하는 것은 지원하지 않는다.** 다른 버전을 사용하려면 새 사이클을 만들어야 한다.

---

## 13. 참고

### 13.1 원본 출처

- **라오어 무한매수법 V2.2/V3.0 비교**: https://www.pbdfinance.com/2024/09/v22-v30.html
- **라오어 무한매수법 원서**: 라오어, "무한매수법"

### 13.2 관련 문서

| 문서 | 설명 |
|------|------|
| `docs/ALPHA_CYCLE_V3_DESIGN.md` | Smart Cycle + Steady V1 통합 설계서 (기존) |
| `docs/SMART_CYCLE_DESIGN.md` | Smart Cycle 독립 설계서 |
| `lib/domain/trading/infinite_buy_service.dart` | Steady V1 비즈니스 로직 (현재 구현, 변경 안 함) |
| `lib/domain/trading/steady_service.dart` | Steady V2.2 + V3.0 통합 서비스 (신규) |
| `lib/domain/trading/steady_order_guide.dart` | SteadyOrderGuide + OrderItem DTO (신규) |
| `lib/presentation/providers/steady_providers.dart` | V2.2/V3.0 주문 가이드 Provider (신규) |
| `lib/data/models/cycle.dart` | Cycle 데이터 모델 |

---

## 14. Trade Grouping (groupId)

### 14.1 개요

동일 세션(LOC A + LOC B + 매도)에서 발생한 거래를 하나의 그룹으로 묶어 **1회차**로 카운팅한다.

### 14.2 Trade 모델 필드

```dart
@HiveField(10)
String? groupId;  // 동일 세션 거래 그룹 식별자 (UUID)
```

- 같은 세션에서 기록한 거래(예: LOC A 매수 + LOC B 매수 + 매도)가 동일한 `groupId`를 공유
- `SteadyCombinedTradeSheet`에서 거래 저장 시 UUID를 생성하여 모든 거래에 동일하게 할당

### 14.3 roundsUsed 카운팅

`_recalculateCycleState()`에서 `roundsUsed`는 **groupId 기준으로 중복 제거**하여 카운팅한다:

```
같은 groupId를 가진 거래들 = 1 round
groupId가 null인 개별 거래 = 각각 1 round
```

- VWAP 계산은 변경 없음 (개별 거래 단위로 정확도 유지)

---

## 15. SteadyCombinedTradeSheet 수정 모드

### 15.1 수정 모드 파라미터

```dart
SteadyCombinedTradeSheet({
  // ... 기존 파라미터 ...
  List<Trade>? editingTrades,     // 수정 대상 거래 목록
  String? editGroupId,            // 수정 대상 groupId
  Function(List<Trade>)? onReplaceTrades,  // 수정 완료 콜백
})
```

### 15.2 수정 모드 동작

- **컨트롤러 프리필**: 기존 거래의 signal → 해당 컨트롤러에 가격/수량 매핑
- **가이드 추천 숨김**: 수정 모드에서는 guide 추천 텍스트 비표시
- **매수/매도 섹션 표시**: 원래 거래의 signal 종류에 따라 해당 섹션만 표시
- **매도 섹션**: 수정 모드에서는 항상 표시 (매도 추가 가능)
- **제목/버튼**: "거래 기록 수정" / "수정 완료"

### 15.3 replaceGroupedTrades()

수정 완료 시 batch 처리: 기존 groupId 거래 전체 삭제 → 새 거래 생성 → `_recalculateCycleState()` 1회 호출

### 15.4 Unified Edit Flow

- Steady 거래는 항상 `SteadyCombinedTradeSheet`로 수정 (Smart 에디터 사용 안 함)
- groupId가 없는 단일 거래: 수정 진입 시 groupId 자동 할당
- 수정 모드에서 매도 섹션은 항상 visible (기존 매도 없어도 매도 추가 가능)

---

## 16. Trade Card UI 리디자인

### 16.1 단일 거래 카드 (groupId 없거나 1개)

```
[LOC B] $45.20 × 5주                        ← badge + signal+price×shares (1줄, detail box 없음)
```

### 16.2 그룹 거래 카드 (동일 groupId, 2개 이상)

```
[LOC A+B]  [LOC매도¼]                        ← badge 나열
┌─────────────────────────────────┐
│ LOC A  $45.20 × 3주            │           ← per-trade rows
│ LOC B  $46.10 × 2주            │
│ LOC매도 $47.50 × 4주           │
└─────────────────────────────────┘
```

### 16.3 매도 섹션

매수와 동일한 구조 (header + detail box). 매수/매도가 같은 그룹에 있으면 하나의 카드에 통합 표시.

### 16.4 회차 섹션

```
── N회차 · YYYY.MM.DD ──────────────         ← fieldset-style border
[카드들...]
```

### 16.5 formatShares()

정수일 때 소수점 미표시: `5.0` → `5`, `3.5` → `3.5`

---

## 17. Pending Completion (전량 매도 완료 대기)

### 17.1 진입 조건

```dart
bool get isPendingCompletion =>
    totalShares == 0 &&
    status == CycleStatus.active &&
    seedAmount != remainingCash;  // 거래 이력이 존재
```

### 17.2 Summary Card 표시

| 항목 | 내용 |
|------|------|
| 설정시드 | `cycle.seedAmount` (KRW) |
| 총투자금 | KRW (`totalBuyAmountKrw`) + USD (`totalBuyUsd`) |
| 총회수금 | KRW (`totalSellAmountKrw`) + USD (`totalSellUsd`) |
| 외화손익 | `totalSellUsd - totalBuyUsd` (USD 기준 실현 P&L) |
| FX P&L | 환차손익 toggle (체크박스 "환차") |
| 평균환율 | 수정 가능 → 즉시 KRW 손익 재계산 |

### 17.3 "사이클 완료 및 정산" 버튼

- Pending 상태에서만 표시
- 탭 시 사이클 상태를 `completed`로 전환

### 17.4 숨김 요소

Pending 상태에서는 다음을 숨김: signal display, order guide, cycle info card

### 17.5 My 탭 카드 표시

- "완료 대기" 배지 표시
- Compact 3-line layout: 종목 / 설정시드 · 총투자금(USD) / 총회수금(USD) · 손익

---

## 18. LOC A 매수 추천 조건

현재가 > 평균단가일 때: "LOC B만 매수 추천" 텍스트 표시.

- LOC A 입력 필드는 계속 visible (사용자가 override 가능)
- 추천 텍스트만 표시하여 가이드 역할

---

## 19. Cycle Model 집계 필드 (HiveField 37~42)

### 19.1 새 필드

```dart
@HiveField(37, defaultValue: 0.0)
double totalBuyAmountKrw;      // 총 매수금액 (KRW)

@HiveField(38, defaultValue: 0.0)
double totalSellAmountKrw;     // 총 매도금액 (KRW)

@HiveField(39)
DateTime? firstTradeDate;      // 첫 거래일

@HiveField(40)
DateTime? lastTradeDate;       // 마지막 거래일

@HiveField(41, defaultValue: 0.0)
double totalBuyUsd;            // 총 매수금액 (USD)

@HiveField(42, defaultValue: 0.0)
double totalSellUsd;           // 총 매도금액 (USD)
```

### 19.2 파생 계산

```dart
// 실현 손익 (KRW)
double get realizedProfitKrw => totalSellAmountKrw - totalBuyAmountKrw;

// 실현 수익률 (%)
double get realizedProfitRate =>
    totalBuyAmountKrw == 0 ? 0 : realizedProfitKrw / totalBuyAmountKrw * 100;
```

### 19.3 갱신 시점

`_recalculateCycleState()`에서 전체 거래 이력 순회 시 함께 집계. `firstTradeDate`/`lastTradeDate`는 거래 추가/삭제 시 min/max로 재계산.
