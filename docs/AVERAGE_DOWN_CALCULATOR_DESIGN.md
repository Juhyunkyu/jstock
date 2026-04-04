# 물타기 계산기 설계서

> **문서 버전**: 2.0
> **최종 업데이트**: 2026-04-04
> **상태**: 구현 완료
> **라우트**: `/tools/avg-down`
> **진입점**: 홈/관심종목/My 앱바 계산기 아이콘 (알림 벨 좌측)

---

## 1. 개요

### 1.1 목적
레버리지 ETF 분할매수 전략에서 **"지금 물타면 평단이 얼마나 내려가고, 추가 하락 시 얼마나 버틸 수 있는가"**를 즉시 파악하는 계산기.

### 1.2 핵심 가치
1. **MDD 중심**: "내가 어느 정도 버틸 수 있냐" — 결과 영역에서 MDD가 가장 크게 표시
2. **실시간 계산**: 입력 변경 즉시 결과 업데이트 (계산 버튼 없음)
3. **사이클/보유 연동**: 활성 사이클 및 일반 보유 데이터를 한 번에 불러오기
4. **직접 입력**: 국내주식 포함, 사이클 없이도 독립 사용 가능
5. **통화 전환**: USD/KRW 토글로 해외/국내 주식 모두 지원
6. **3필드 상호 연동**: 매수수량/매수금액/목표손익률 중 하나를 입력하면 나머지 자동 계산
7. **수익률 역산**: "현재 -15%인데 -5%로 만들려면 얼마 필요?"
8. **시나리오 테이블**: 추가 하락 시 MDD/손실금액 색상 그라데이션 시각화
9. **메모 저장**: 스크린샷 캡처 + 텍스트 요약을 전략 메모로 저장

### 1.3 범위 외 (구현하지 않음)
- Hive 영속화 (계산기 상태 저장 불필요)
- 다중 물타기 시뮬레이션 (2회 이상 연속 물타기) — **엔진(`calculateAll`)에서도 제거됨**, 단일 라운드만 지원
- 레버리지 일간 추종 괴리 정밀 계산
- 환율 변동 시나리오 (현재 환율 기준 고정)

---

## 2. UI 와이어프레임

### 2.1 모바일 메인 화면 (< 900px)

전체가 `SingleChildScrollView`로 세로 스크롤. Section A+B (입력) → Section C (결과) → Section D (시나리오) → Section E (목표가).

```
┌─────────────────────────────────────────────┐
│  ←   물타기 계산기                     [💾]  │  AppBar
├─────────────────────────────────────────────┤
│                                             │
│  ┌─────────────────────────────────────────┐│
│  │ 현재 보유  [USD|KRW]    [초기화] [불러오기]││  Section A
│  │─────────────────────────────────────────││
│  │ 종목명     [TQQQ                      ] ││
│  │ 평균단가   [$ 45.00                   ] ││
│  │ 보유수량   [100               ] 주      ││
│  │ 현재가     [$ 30.00                   ] ││
│  │ ▶ 환율 설정                     ₩1,400  ││  접이식 (USD만)
│  │  ┌ 환율   [₩ 1400                  ] ┐ ││  펼치면 표시
│  └─────────────────────────────────────────┘│
│                                             │
│  ┌─────────────────────────────────────────┐│
│  │ 추가 매수                      [초기화] ││  Section B
│  │─────────────────────────────────────────││
│  │ 매수가     [$ 30.00                   ] ││
│  │ 매수수량   [50                 ] 주     ││  *하이라이트
│  │ 매수금액   [₩ 2,100,000] 약 210만      ││  한글 축약 suffix
│  │ 목표손익률 [−] [-10.50          ] %     ││  +/- 토글 버튼
│  │            수량은 소수점 포함 참고용입니다 ││  역산 안내 텍스트
│  └─────────────────────────────────────────┘│
│                                             │
│  ┌─────────────────────────────────────────┐│
│  │ 결과                                    ││  Section C
│  │─────────────────────────────────────────││
│  │ 현재 평단                      $45.00   ││
│  │ → 새 평단                      $40.00   ││  accent 색상
│  │                               -11.1%    ││  평단 변화율
│  │                                         ││
│  │ ┌─ MDD 카드 ──────────────────────────┐ ││
│  │ │ 현재 MDD                   -33.3%   │ ││  큰 폰트(20)
│  │ │ ↓ 물타기 후                 -25.0%   │ ││  큰 폰트(24)
│  │ │ 개선폭                     +8.3%p   │ ││
│  │ └────────────────────────────────────┘ ││
│  │                                         ││
│  │ 총 투자금                ₩8,400,000     ││  InfoRow
│  │ 총 수량                  150.00주        ││
│  │ 평가금액                 ₩6,300,000     ││
│  │ 평가손익               -₩2,100,000     ││  빨강/파랑
│  │ 손익률                     -25.0%       ││  빨강/파랑
│  └─────────────────────────────────────────┘│
│                                             │
│  ┌─────────────────────────────────────────┐│
│  │ 하락 시나리오              [접기/펼치기] ││  Section D (접이식)
│  │─────────────────────────────────────────││
│  │ 추가하락 │ 예상가 │  MDD  │ 손실금액   ││
│  │─────────│────────│───────│────────────││
│  │░ -10%   │ $27.00 │-32.5% │ -₩560만   ░││  그라데이션 행
│  │▒ -20%   │ $24.00 │-40.0% │ -₩1,120만 ▒││
│  │▓ -30%   │ $21.00 │-47.5% │ -₩1,680만 ▓││
│  │█ -50%   │ $15.00 │-62.5% │ -₩2,800만 █││
│  └─────────────────────────────────────────┘│
│                                             │
│  ┌─────────────────────────────────────────┐│
│  │ 목표가 수익                             ││  Section E
│  │─────────────────────────────────────────││
│  │ 목표가     [$ 50.00                   ] ││
│  │ 현재 기준 수익          +₩700,000       ││
│  │ 물타기 후 수익          +₩1,500,000     ││
│  │ 수익률 비교      +11.1% → +23.8%       ││
│  └─────────────────────────────────────────┘│
│                                             │
└─────────────────────────────────────────────┘
```

### 2.2 데스크톱 레이아웃 (>= 900px)

좌측 고정 380px 패널(입력), 우측 `Expanded` 패널(결과+시나리오+목표가).

```
┌─────────────────────────────────────────────────────────────────────┐
│  ←   물타기 계산기                                           [💾]  │
├──────────────────────┬──────────────────────────────────────────────┤
│                      │                                              │
│  ┌────────────────┐  │  ┌────────────────────────────────────────┐  │
│  │ 현재 보유      │  │  │ 결과                                  │  │
│  │ [USD|KRW]      │  │  │ (Section C — 위와 동일)               │  │
│  │ [초기화][불러오기]│  │  └────────────────────────────────────────┘  │
│  │                │  │                                              │
│  │ 종목명  [    ] │  │  ┌────────────────────────────────────────┐  │
│  │ 평균단가 [   ] │  │  │ 하락 시나리오          [접기/펼치기]  │  │
│  │ 보유수량 [   ] │  │  │ (Section D — 위와 동일)               │  │
│  │ 현재가  [    ] │  │  └────────────────────────────────────────┘  │
│  │ ▶ 환율 설정    │  │                                              │
│  └────────────────┘  │  ┌────────────────────────────────────────┐  │
│                      │  │ 목표가 수익                            │  │
│  ┌────────────────┐  │  │ (Section E — 위와 동일)               │  │
│  │ 추가 매수      │  │  └────────────────────────────────────────┘  │
│  │ [초기화]       │  │                                              │
│  │                │  │                                              │
│  │ 매수가  [    ] │  │                                              │
│  │ 매수수량 [   ] │  │                                              │
│  │ 매수금액 [   ] │  │                                              │
│  │ 목표손익률[  ] │  │                                              │
│  └────────────────┘  │                                              │
│   (고정 380px)       │  (나머지 Expanded, 스크롤)                   │
├──────────────────────┴──────────────────────────────────────────────┤
```

### 2.3 보유 데이터 불러오기 시트 (BottomSheet)

```
┌──────────────────────────────────────────┐
│              ────  (drag handle)          │
│                                          │
│          보유 데이터 불러오기             │
│ ─────────────────────────────────────── │
│                                          │
│ 📊 활성 사이클 (2)                       │
│ ─────────────────────────────────────── │
│ TQQQ (내 포트)                           │
│ Smart · 100.0주 · 평단 $45.00           │
│                                          │
│ SOXL                                     │
│ Steady · 50.0주 · 평단 $22.50           │
│                                          │
│ 💼 일반 보유 (1)                         │
│ ─────────────────────────────────────── │
│ AAPL (Apple Inc.)                        │
│ 30.0주 · 평단 $175.00                   │
│                                          │
│        [ 직접 입력으로 전환 ]            │
│                                          │
└──────────────────────────────────────────┘
```

---

## 3. 데이터 모델

### 3.1 UI 상태 (StatefulWidget 인스턴스 변수)

클래스 분리 없이 `_AvgDownScreenState`에 직접 선언 (라인 29~67):

```dart
// === 스크린샷 캡처용 키 ===
final _screenshotKey = GlobalKey();

// === 현재 보유 ===
final _tickerNameController = TextEditingController();
final _holdingSharesController = TextEditingController();
final _avgPriceController = TextEditingController();
final _currentPriceController = TextEditingController();
final _exchangeRateController = TextEditingController();

// === 추가 매수 (3필드 상호 연동) ===
final _addPriceController = TextEditingController();
final _addAmountController = TextEditingController();
final _addSharesController = TextEditingController();
final _targetReturnController = TextEditingController();

// === 목표가 ===
final _targetPriceController = TextEditingController();

// === 통화 모드 ===
bool _isKrwMode = false; // false=USD, true=KRW

// === 접이식 ===
bool _showExchangeRate = false;
bool _showScenario = false;

// === 3필드 연동: 마지막 입력 필드 추적 ===
_EditedField _lastEditedField = _EditedField.shares;

// 프로그래밍적 텍스트 업데이트 중 순환 방지
bool _isAutoUpdating = false;

// === 계산 결과 ===
AvgDownResult? _result;
```

### 3.2 출력 데이터 모델 (`average_down_calculator.dart`)

**AvgDownResult** — 전체 계산 결과:
```dart
class AvgDownResult {
  final double currentAvgPrice;      // 현재 평균단가
  final double newAvgPrice;          // 물타기 후 평균단가
  final double avgPriceReduction;    // 평단 변화율 (%)
  final double currentMdd;           // 현재 MDD (%)
  final double newMdd;               // 물타기 후 MDD (%)
  final double mddImprovement;       // MDD 개선폭 (%p)
  final double totalShares;          // 총 수량
  final double totalInvestedKrw;     // 총 투자금 (KRW)
  final double evaluatedAmountKrw;   // 평가금액 (KRW)
  final double profitLossKrw;        // 평가손익 (KRW)
  final double returnRate;           // 손익률 (%)
  final List<ScenarioRow> scenarios; // 하락 시나리오 목록
  final ReverseCalcResult? reverseCalc;      // 수익률 역산 결과
  final TargetPriceResult? targetPriceResult; // 목표가 수익 결과
}
```

**ScenarioRow** — 하락 시나리오 행:
```dart
class ScenarioRow {
  final double dropPercent;     // 하락 퍼센트 (예: -10)
  final double projectedPrice;  // 예상가
  final double mdd;             // 해당 시나리오 MDD (%)
  final double lossAmountKrw;   // 손실금액 (KRW)
}
```

**ReverseCalcResult** — 수익률 역산 결과:
```dart
class ReverseCalcResult {
  final double requiredAmountKrw;   // 필요 금액 (KRW)
  final double requiredShares;      // 필요 수량
  final double newAvgPrice;         // 역산 후 새 평단
  final bool isFeasible;            // 달성 가능 여부
  final String? infeasibleReason;   // 불가능 사유
}
```

**TargetPriceResult** — 목표가 수익 결과:
```dart
class TargetPriceResult {
  final double currentProfit;       // 현재 포지션 기준 수익 (KRW)
  final double currentReturnRate;   // 현재 포지션 수익률 (%)
  final double newProfit;           // 물타기 후 수익 (KRW)
  final double newReturnRate;       // 물타기 후 수익률 (%)
}
```

### 3.3 `_EditedField` enum (라인 19)

```dart
enum _EditedField { shares, amount, targetReturn }
```

3필드 연동 시 마지막으로 사용자가 직접 수정한 필드를 추적. `_lastEditedField`에 저장되어 매수가 변경 시 어떤 필드 기준으로 나머지를 재계산할지 결정.

---

## 4. 계산 공식

모든 계산은 `AverageDownCalculator` 클래스의 static 메서드로 구현 (`average_down_calculator.dart` 라인 108~460).

### 4.1 평균단가 — `newAveragePrice` (라인 120~131)

순수 USD VWAP (Volume Weighted Average Price):

```dart
static double newAveragePrice({
  required double holdingShares,
  required double averagePrice,
  required double additionalShares,
  required double additionalPrice,
}) {
  final totalShares = holdingShares + additionalShares;
  if (totalShares <= 0) return 0.0;
  return (holdingShares * averagePrice +
          additionalShares * additionalPrice) /
      totalShares;
}
```

### 4.2 MDD — `mdd` (라인 141~147)

Maximum Drawdown from Average:

```
MDD = (currentPrice - averagePrice) / averagePrice × 100
```

양수면 수익, 음수면 손실. Zero-guard: `averagePrice <= 0` 이면 `0.0`.

### 4.3 물타기 후 MDD — `newMdd` (라인 149~164)

`newAveragePrice` 계산 후 동일한 `mdd` 공식 적용.

### 4.4 하락 시나리오 — `dropScenarios` (라인 174~197)

```dart
static List<ScenarioRow> dropScenarios({
  required double currentPrice,
  required double averagePrice,
  required double totalShares,
  required double exchangeRate,
  required List<double> dropPercents,  // 기본: [-10, -20, -30, -50]
})
```

각 시나리오별 계산:
- `projectedPrice = currentPrice × (1 + drop/100)`
- `scenarioMdd = mdd(projectedPrice, averagePrice)`
- `lossKrw = (totalShares × projectedPrice × exchangeRate) - (totalShares × averagePrice × exchangeRate)`

### 4.5 수익률 역산 — `reverseCalc` (라인 211~278)

"목표 수익률을 달성하려면 얼마를 물타야 하는가":

```
targetAvg = currentPrice / (1 + targetReturnRate / 100)

requiredShares = holdingShares × (avgPrice - targetAvg)
                / (targetAvg - additionalPrice)

requiredAmountKrw = requiredShares × additionalPrice × exchangeRate
```

**가드 조건**:
- `targetReturnRate <= -100` → 0 나눗셈 방지, `isFeasible: false`
- `targetAvg <= additionalPrice` → 매수가가 목표 평단보다 높아 달성 불가, `isFeasible: false`
- `requiredShares <= 0` → 이미 목표 도달, `isFeasible: false`

### 4.6 목표가 수익 — `targetPriceProfit` (라인 285~322)

물타기 전/후 목표가 도달 시 수익 비교:

```
현재: investedKrw = holdingShares × averagePrice × exchangeRate
      evalKrw     = holdingShares × targetPrice × exchangeRate
      profit      = evalKrw - investedKrw
      returnRate  = profit / investedKrw × 100

물타기 후: newAvg를 사용하여 동일 공식 적용
```

### 4.7 금액 → 수량 변환 — `sharesToBuy` (라인 330~337)

```dart
static double sharesToBuy({
  required double amountKrw,
  required double price,
  required double exchangeRate,
}) {
  if (price <= 0 || exchangeRate <= 0) return 0.0;
  return amountKrw / (price * exchangeRate);
}
```

### 4.8 전체 계산 — `calculateAll` (라인 350~459)

편의 메서드. 단일 물타기 라운드를 받아 위의 모든 계산을 한 번에 수행.

```dart
static AvgDownResult calculateAll({
  required double holdingShares,
  required double averagePrice,
  required double currentPrice,
  required double exchangeRate,
  required List<({double price, double shares})> additionalRounds,
  double? targetReturnRate,      // null이면 역산 생략
  double? targetPrice,           // null이면 목표가 생략
  List<double> dropPercents = const [-10, -20, -30, -50],
})
```

**참고**: `additionalRounds`는 `List<Record>` 타입이지만 실제 UI에서는 항상 단일 원소만 전달. `price > 0 && shares > 0`인 라운드만 유효 처리.

---

## 5. 파일 구조

신규/수정 파일 3개:

| 파일 | 설명 |
|------|------|
| `lib/domain/trading/average_down_calculator.dart` | 순수 계산 로직 + 결과 모델 4개 (461줄) |
| `lib/presentation/screens/tools/avg_down_screen.dart` | 단일 파일 전체 UI (1637줄) |
| `lib/presentation/widgets/common/calculator_button.dart` | 앱바 계산기 아이콘 버튼 (21줄) |

### `avg_down_screen.dart` 메서드 구성 (라인 범위)

| 범위 | 구성 |
|------|------|
| 0~17 | import, enum `_EditedField` |
| 22~93 | `_AvgDownScreenState` — 상태 변수, `initState`, `dispose` |
| 98~131 | 파싱 헬퍼 (`_parseDouble`, getters, `_fmtPrice`, `_fmtKrw`) |
| 136~275 | **3필드 연동 로직** (`_onSharesChanged`, `_onAmountChanged`, `_onTargetReturnChanged`, `_onAddPriceChanged`, `_syncFromShares`, `_syncFromAmount`, `_syncFromTargetReturn`, `_syncDependentFields`) |
| 281~305 | 계산 (`_recalculate`, `_onBasicInputChanged`) |
| 311~336 | 초기화 (`_resetHolding`, `_resetAdditional`, `_resetAll`) |
| 342~556 | 사이클/보유 불러오기 (`_showCyclePicker`, `_buildPickerSheet`, `_loadFromHolding`, `_loadFromCycle`) |
| 562~631 | 메모 저장 (`_saveToMemo` — 스크린샷 캡처 + 텍스트 생성) |
| 638~742 | 빌드 (`build`, `_buildNarrowLayout`, `_buildWideLayout`) |
| 749~888 | Section A+B 입력 UI (`_buildInputSection`) |
| 891~1034 | 가격 입력, 매수금액, 통화 토글 (`_buildPriceInput`, `_buildAmountField`, `_buildCurrencyToggle`, `_buildCurrencyChip`) |
| 1037~1182 | 목표손익률, 역산 안내, 초기화 버튼 (`_buildTargetReturnField`, `_buildReverseCalcInfo`, `_buildResetButton`) |
| 1188~1365 | Section C: 결과 카드 + MDD 카드 (`_buildResultCard`, `_buildMddCard`) |
| 1371~1470 | Section D: 하락 시나리오 테이블 (`_buildScenarioTable`) |
| 1476~1521 | Section E: 목표가 수익 (`_buildTargetPriceSection`) |
| 1527~1637 | 공통 위젯 (`_buildCard`, `_buildTextField`) |

---

## 6. 3필드 상호 연동 로직

### 6.1 개요

**매수수량**, **매수금액**, **목표손익률** 세 필드가 상호 연동. 사용자가 하나를 직접 수정하면 나머지 두 필드가 자동 업데이트.

### 6.2 추적 메커니즘

`_lastEditedField` (`_EditedField` enum)가 마지막으로 사용자가 직접 입력한 필드를 추적.

### 6.3 연동 흐름

| 사용자가 수정 | 호출 메서드 | 자동 계산되는 필드 |
|--------------|-----------|-----------------|
| 매수수량 | `_syncFromShares()` | 매수금액 = `shares × price × exchangeRate`, 목표손익률 = 새 MDD |
| 매수금액 | `_syncFromAmount()` | 매수수량 = `amount / (price × exchangeRate)`, 목표손익률 = 새 MDD |
| 목표손익률 | `_syncFromTargetReturn()` | `reverseCalc` 호출 → 매수수량, 매수금액 역산 |
| **매수가** | `_syncDependentFields()` | `_lastEditedField` 기준으로 위 3가지 중 해당 sync 메서드 재호출 |

### 6.4 순환 방지

`_isAutoUpdating` 플래그가 프로그래밍적 텍스트 업데이트 중 `true`로 설정. 각 `_onXxxChanged` 핸들러는 진입 시 이 플래그를 확인하여 순환 호출을 차단.

```dart
void _onSharesChanged(String _) {
  if (_isAutoUpdating) return;         // 순환 방지
  _lastEditedField = _EditedField.shares;
  _syncFromShares();                    // amount, targetReturn 자동 계산
  _recalculate();                       // 전체 결과 재계산
}
```

### 6.5 하이라이트 표시

현재 마스터 필드(사용자가 마지막으로 수정한 필드)는 `highlighted: true`로 표시되어 accent 색상 라벨 + 테두리 강조.

---

## 7. 사이클/보유 연동

### 7.1 불러오기 진입 (라인 342~368)

`_showCyclePicker()`:
- `cycleListProvider`에서 **활성 사이클** (`status == CycleStatus.active`) 필터
- `holdingListProvider`에서 **비아카이브 + 보유수량 > 0** 보유 필터
- 둘 다 비어있으면 SnackBar 표시, 아니면 BottomSheet 표시

### 7.2 BottomSheet 구성 (라인 370~498)

- 상단 drag handle + "보유 데이터 불러오기" 타이틀
- `📊 활성 사이클 (N)` 섹션: 각 사이클의 `displayTicker (nickname)`, `strategyLabel · 수량주 · 평단 $가격`
  - 전략 라벨: `alphaCycleV3` → "Smart", `infiniteBuy` → "Steady", `ladderCycle` → "Ladder"
  - **Ladder 전략**: `buyTicker`를 우선 사용 (`buyTicker.isNotEmpty ? buyTicker : ticker`)
  - **닉네임 표시**: `nickname.isNotEmpty`이면 `'$displayTicker ($nickname)'`
- `💼 일반 보유 (N)` 섹션: `ticker (name)`, `수량주 · 평단 $가격`
- 하단: "직접 입력으로 전환" 텍스트 버튼 → `_resetAll()` 호출

### 7.3 데이터 로드 (라인 500~556)

**`_loadFromHolding(Holding)`**: ticker, totalShares, averagePrice 채움. `stockQuoteProvider`에서 현재가 조회 → 현재가 + 매수가 자동 채움. 환율은 holding의 `exchangeRate` 또는 `currentExchangeRateProvider` 폴백.

**`_loadFromCycle(Cycle)`**: 동일 패턴. `exchangeRateAtEntry` 사용. Ladder 전략 시 `buyTicker` 우선.

---

## 8. USD/KRW 통화 전환

### 8.1 상태

`_isKrwMode` (bool): `false` = USD, `true` = KRW

### 8.2 토글 동작 (라인 976~1034)

Section A 타이틀 옆 `[USD|KRW]` 세그먼트 칩 (`_buildCurrencyToggle`):

| 항목 | USD 모드 (`_isKrwMode = false`) | KRW 모드 (`_isKrwMode = true`) |
|------|------|------|
| 가격 prefix | `$` | `₩` |
| 숫자 포맷 | 소수점 허용 (`0.00`) | 정수 + 쉼표 자동 (`1,234,567`) |
| 환율 필드 | 표시 (접이식) | **숨김** (`exchangeRate = 1`) |
| InputFormatter | `_decimalFilter` | `_commaDigitFilter` + `_autoFormatComma` |

### 8.3 전환 시 동작

통화 전환 시:
1. KRW → `_exchangeRateController.text = '1'`, `_showExchangeRate = false`
2. USD → `currentExchangeRateProvider`에서 실시간 환율 복원
3. **가격 필드 초기화**: `avgPrice`, `currentPrice`, `addPrice`, `targetPrice` 모두 `clear()`
4. `_recalculate()` 호출

---

## 9. 메모 저장 + 스크린샷

### 9.1 스크린샷 캡처 (라인 562~587)

```dart
final _screenshotKey = GlobalKey();

// build()에서:
body: RepaintBoundary(
  key: _screenshotKey,
  child: ColoredBox(                    // 배경색 포함 (투명 방지)
    color: context.appBackground,
    child: isWide ? _buildWideLayout() : _buildNarrowLayout(),
  ),
),
```

캡처 과정:
1. `_screenshotKey.currentContext?.findRenderObject()` → `RenderRepaintBoundary`
2. `boundary.toImage(pixelRatio: 1.5)` — **1.5로 제한** (3x 디바이스에서 base64 크기 폭발 방지)
3. `image.toByteData(format: ui.ImageByteFormat.png)`
4. `base64Encode(byteData.buffer.asUint8List())`
5. 캡처 실패해도 텍스트 메모는 저장 (try-catch)

### 9.2 텍스트 콘텐츠 (라인 589~608)

StringBuffer로 구성:
```
물타기 시뮬레이션 - TQQQ
현재: 100.0주 × $45.00 (MDD -33.3%)
현재가: $30.00 | 환율: ₩1400

추가 매수: $30.00 × 50.0주 (₩2,100,000)

결과:
평단: $45.00 → $40.00 (-11.1%)
MDD: -33.3% → -25.0%
총: 150.0주 | 투자 ₩8,400,000

[IMG:0]
```

### 9.3 메모 저장

```dart
final memo = Memo(
  id: 'memo_${now.millisecondsSinceEpoch}',
  title: '$ticker 물타기 계획 ($dateStr)',
  content: buf.toString(),
  category: MemoCategory.strategy,
  imageBase64List: imageBase64 != null ? [imageBase64] : null,
);
ref.read(memoListProvider.notifier).save(memo);
```

- `[IMG:0]` 마커: 메모 뷰어에서 `imageBase64List[0]`으로 치환
- 카테고리: `MemoCategory.strategy`

### 9.4 저장 버튼 표시 조건

AppBar의 💾 아이콘은 `_hasValidInput && _result != null`일 때만 표시 (라인 661~667).

---

## 10. 엣지 케이스

| 케이스 | 처리 | 상태 |
|--------|------|------|
| 평균단가 또는 보유수량 0 | `_hasValidInput = false` → 결과 영역 미표시 | ✅ |
| 추가매수 없이 결과 표시 | 현재 MDD만 표시, 물타기 후 MDD / 평단 변화 / 개선폭 숨김 | ✅ |
| 환율 미입력 | 폴백 `1400.0` 사용 (`_exchangeRate > 0 ? _exchangeRate : 1400.0`) | ✅ |
| 목표손익률 `-100%` 이하 | `reverseCalc`에서 guard 처리, `isFeasible: false` | ✅ |
| 매수가 > 목표 평단 | `reverseCalc`에서 `isFeasible: false`, 안내 텍스트 표시 | ✅ |
| 이미 목표 수익률 도달 | `requiredShares <= 0` → `isFeasible: false` | ✅ |
| 총수량 0 | `newAveragePrice`에서 `0.0` 반환 | ✅ |
| 통화 전환 시 가격값 | 가격 필드 모두 `clear()` (통화 변경 시 값 무의미) | ✅ |
| 스크린샷 캡처 실패 | try-catch로 무시, 텍스트 메모만 저장 | ✅ |
| KRW 모드에서 환율 | `exchangeRate = 1`, 환율 설정 행 숨김 | ✅ |
| 목표손익률 초기값 | `'-'` (마이너스 부호만, 숫자 없음) → `_parseDouble` 시 0.0 | ✅ |
| 불러올 데이터 없음 | SnackBar "불러올 데이터가 없습니다" | ✅ |
| 소수점 수량 (레버리지 ETF) | 소수점 4자리까지 표시 (`toStringAsFixed(4)`) | ✅ |

---

## 11. UI 상세

### 11.1 색상 규칙

| 요소 | 색상 |
|------|------|
| 수익(+) | `AppColors.red500` (한국 주식시장 관례) |
| 손실(-) | `AppColors.blue500` |
| 평단 하락 (긍정) | `context.appStockChangePlusFg` |
| 평단 상승 (부정) | `context.appStockChangeMinusFg` |
| 하이라이트 필드 | `context.appAccent` (라벨 + 테두리) |
| MDD 카드 배경 | `context.appStockChangeMinusBg` (손실) / `context.appStockChangePlusBg` (수익) |
| 시나리오 행 그라데이션 | `context.appStockChangeMinusFg.withValues(alpha: opacity)`, opacity = `(drop.abs() / 100).clamp(0.05, 0.5)` |
| +/- 토글 버튼 (마이너스) | `AppColors.blue500` 배경 0.15 + 테두리 0.4 |
| +/- 토글 버튼 (플러스) | `AppColors.red500` 배경 0.15 + 테두리 0.4 |

### 11.2 접이식 섹션

| 섹션 | 기본 상태 | 동작 |
|------|----------|------|
| 환율 설정 (Section A) | 접힘 (`_showExchangeRate = false`) | InkWell 탭으로 토글, 현재 환율 값 항상 표시 |
| 하락 시나리오 (Section D) | 접힘 (`_showScenario = false`) | "접기/펼치기" 텍스트 + 아이콘으로 토글 |

### 11.3 반응형 분기점

- `screenWidth >= 900`: 데스크톱 (좌 380px 고정 + 우 Expanded)
- `screenWidth < 900`: 모바일 (단일 컬럼 스크롤)

### 11.4 공통 카드 위젯 (`_buildCard`)

모든 Section이 사용하는 통일된 카드:
- `context.appCardBackground` 배경
- `borderRadius: 12`
- `border: appBorder (alpha 0.5)`
- `boxShadow: context.appCardShadow`
- 타이틀 행: `title` + `titleTrailing` (좌) | `trailing` (우)

### 11.5 공통 텍스트필드 (`_buildTextField`)

- 라벨 `SizedBox(width: 72)` 고정 너비
- `isDense: true`, `contentPadding: 12×10`
- `fillColor: context.appSurface`
- 하이라이트 시: accent 색상 라벨 + accent 테두리

---

## 12. 기술 결정 사항

### 12.1 StatefulWidget 선택 (설계 유지)

Riverpod Provider 대신 `ConsumerStatefulWidget` + `TextEditingController` 직접 관리. 이유:
- 10개 이상의 `TextEditingController`가 서로 연동 → Provider로 관리 시 복잡도 급증
- 3필드 연동의 `_isAutoUpdating` 플래그는 동기적 제어 필요 → Provider의 비동기 특성과 충돌
- 계산기 상태 영속화 불필요 → Hive 저장 없음

### 12.2 3필드 상호 연동 (v1.0에서 변경)

v1.0 설계: 매수금액/매수수량 **택 1 토글** 방식
현재 구현: 매수수량/매수금액/목표손익률 **3필드 동시 표시 + 상호 연동**

변경 이유:
- 사용자가 "100만원어치" 또는 "50주"를 자유롭게 입력 가능
- 목표손익률 입력 → 역산으로 필요 수량/금액 자동 계산 (핵심 기능)
- 마지막 입력 필드 추적으로 매수가 변경 시 적절한 재계산 보장

### 12.3 단일 파일 구조 (v1.0에서 변경)

v1.0 설계: 8개 파일로 분리 (calculator, input model, result model, screen, widgets 등)
현재 구현: **3개 파일** (calculator engine + screen + button)

변경 이유:
- 계산기는 독립 도구이므로 Provider 불필요 (StatefulWidget 내부 완결)
- 입력 모델 클래스 → `TextEditingController` 직접 사용으로 대체
- 위젯 분리 시 3필드 연동 로직의 controller/flag 공유가 복잡해짐
- 1637줄이지만 메서드 단위로 명확히 구분되어 가독성 유지

### 12.4 스크린샷 pixelRatio 1.5 (구현 시 결정)

`toImage(pixelRatio: 3.0)` 대신 `1.5`로 제한:
- 3x 디바이스에서 base64 크기가 수 MB로 폭발
- Hive에 저장되는 `Memo.imageBase64List`의 크기 최적화
- 1.5x로도 충분한 가독성 확보

### 12.5 다중 물타기 제거 (v1.0에서 변경)

v1.0 설계: `multiRoundAverage` 메서드로 다회차 지원 예정
현재 구현: **엔진에서 완전 제거**, `calculateAll`의 `additionalRounds`는 항상 단일 원소

변경 이유:
- UI 복잡도 대비 사용 빈도 낮음
- 단일 물타기로도 핵심 가치(MDD 개선 시뮬레이션) 충분
- 필요 시 여러 번 계산기를 사용하면 됨
