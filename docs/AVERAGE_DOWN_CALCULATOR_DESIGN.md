# 물타기 계산기 설계서

> **문서 버전**: 1.0
> **작성일**: 2026-04-02
> **라우트**: `/tools/avg-down`
> **진입점**: 홈/관심종목/My 앱바 계산기 아이콘 (알림 벨 좌측)

---

## 1. 개요

### 1.1 목적
레버리지 ETF 분할매수 전략에서 **"지금 물타면 평단이 얼마나 내려가고, 추가 하락 시 얼마나 버틸 수 있는가"**를 즉시 파악하는 계산기.

### 1.2 핵심 가치
1. **MDD 중심**: "내가 어느 정도 버틸 수 있냐" — 결과 영역에서 MDD가 가장 눈에 띄게
2. **실시간 계산**: 입력 변경 즉시 결과 업데이트 (계산 버튼 없음)
3. **사이클 연동**: 활성 사이클 데이터를 한 번에 불러오기
4. **직접 입력**: 국내주식 포함, 사이클 없이도 독립 사용 가능
5. **수익률 역산**: "현재 -15%인데 -5%로 만들려면 얼마 필요?"
6. **시나리오 테이블**: 추가 하락 시 MDD/손실금액 색상 그라데이션 시각화

### 1.3 범위 외 (구현하지 않음)
- Hive 영속화 (계산기 상태 저장 불필요)
- 다중 물타기 시뮬레이션 (2회 이상 연속 물타기)
- 레버리지 일간 추종 괴리 정밀 계산 (단순 배수 근사만 표시)
- 환율 변동 시나리오 (현재 환율 기준 고정)

---

## 2. UI 와이어프레임

### 2.1 메인 화면 (모바일 기준, < 600px)

```
┌─────────────────────────────────────┐
│ ←  물타기 계산기                     │  AppBar
├─────────────────────────────────────┤
│                                     │
│  ┌─ 현재 보유 ─────────────────┐    │  Section A: 입력
│  │ [사이클에서 불러오기 ▾]      │    │  (사이클 선택 또는 직접입력)
│  │                             │    │
│  │ 종목명      [TQQQ        ]  │    │
│  │ 보유수량    [100       주]  │    │
│  │ 평균단가    [$45.00      ]  │    │
│  │ 현재가      [$38.25      ]  │    │  (자동: WebSocket/REST)
│  │ 환율        [₩1,380      ]  │    │  (자동: exchangeRate)
│  └─────────────────────────────┘    │
│                                     │
│  ┌─ 추가 매수 ─────────────────┐    │  Section B: 물타기 입력
│  │ 매수가      [$38.25      ]  │    │  (기본값: 현재가)
│  │ 매수금액    [₩500,000    ]  │    │  (또는 수량 입력 토글)
│  │   → 예상수량  9.44주        │    │  (자동계산)
│  └─────────────────────────────┘    │
│                                     │
│  ══════════════════════════════════  │  구분선
│                                     │
│  ┌─ 결과 ──────────────────────┐    │  Section C: 핵심 결과
│  │                             │    │
│  │   현재 평단    $45.00       │    │
│  │   → 새 평단   $43.38       │    │  강조 (큰 글씨)
│  │                             │    │
│  │  ┌─ MDD ────────────────┐  │    │  MDD 카드 (최강조)
│  │  │  현재        -15.0%  │  │    │  손실 색상
│  │  │  물타기 후   -11.6%  │  │    │  개선 강조
│  │  │  개선폭       +3.4%p │  │    │  수익 색상
│  │  └──────────────────────┘  │    │
│  │                             │    │
│  │  총 투자금  ₩6,710,000     │    │
│  │  총 수량    109.44주        │    │
│  │  평가금액   ₩5,782,860     │    │
│  │  평가손익   -₩927,140      │    │
│  │  손익률      -13.8%        │    │
│  └─────────────────────────────┘    │
│                                     │
│  ┌─ 하락 시나리오 ─────────────┐    │  Section D: MDD 시나리오
│  │                             │    │
│  │  추가하락  │ 예상가 │  MDD  │ 손실금액  │
│  │  ─────────┼────────┼───────┼──────────│
│  │   -10%    │ $34.43 │ -20.6%│ -₩1.38M  │  연한 파랑
│  │   -20%    │ $30.60 │ -29.4%│ -₩1.97M  │  중간 파랑
│  │   -30%    │ $26.78 │ -38.3%│ -₩2.56M  │  진한 파랑
│  │   -50%    │ $19.13 │ -55.9%│ -₩3.74M  │  가장 진한
│  └─────────────────────────────┘    │
│                                     │
│  ┌─ 수익률 역산 ───────────────┐    │  Section E: 역산
│  │ 목표 손익률  [-5.0     %]   │    │
│  │                             │    │
│  │  필요 매수가  $38.25        │    │  (현재가 기본)
│  │  필요 금액    ₩1,920,000   │    │
│  │  필요 수량    36.8주        │    │
│  │  → 새 평단   $40.26        │    │
│  └─────────────────────────────┘    │
│                                     │
│  ┌─ 목표가 수익 ───────────────┐    │  Section F: 목표가
│  │ 목표가      [$50.00      ]  │    │
│  │                             │    │
│  │  현재 기준 수익  +₩652,800  │    │
│  │  물타기 후 수익  +₩996,960  │    │
│  │  수익률 비교  +9.7% → +14.9%│    │
│  └─────────────────────────────┘    │
│                                     │
└─────────────────────────────────────┘
```

### 2.2 데스크톱 레이아웃 (>= 900px)

```
┌──────────────────────────────────────────────────────────────────┐
│ ←  물타기 계산기                                                  │
├──────────────────────────┬───────────────────────────────────────┤
│                          │                                       │
│  Section A: 현재 보유     │  Section C: 핵심 결과                  │
│  Section B: 추가 매수     │  Section D: 하락 시나리오              │
│                          │  Section E: 수익률 역산                │
│                          │  Section F: 목표가 수익                │
│                          │                                       │
│  (입력 패널, 고정 폭)     │  (결과 패널, 스크롤)                   │
│                          │                                       │
└──────────────────────────┴───────────────────────────────────────┘
```

### 2.3 사이클 선택 시트

```
┌─────────────────────────────────────┐
│  활성 사이클에서 불러오기             │  BottomSheet 헤더
├─────────────────────────────────────┤
│                                     │
│  ┌─ TQQQ ──────────────────────┐   │
│  │ Smart Cycle · 시드 5,000만원  │   │
│  │ 45주 · 평단 $45.00 · -15.0% │   │
│  └──────────────────────────────┘   │
│                                     │
│  ┌─ SOXL ──────────────────────┐   │
│  │ Steady V1 · 시드 3,000만원   │   │
│  │ 120주 · 평단 $22.50 · -8.3% │   │
│  └──────────────────────────────┘   │
│                                     │
│  ┌─ TQQQ #2 ──────────────────┐   │
│  │ Ladder 공격형 · 시드 1억     │   │
│  │ 200주 · 평단 $50.00 · -23.5%│   │
│  └──────────────────────────────┘   │
│                                     │
│  (직접 입력으로 전환)               │  TextButton
└─────────────────────────────────────┘
```

---

## 3. 데이터 모델

### 3.1 입력 데이터 (UI State)

```dart
/// 물타기 계산기 입력 상태
/// StatefulWidget 로컬 관리 (Hive 저장 불필요)
class AvgDownInput {
  // === 현재 보유 ===
  String tickerName;       // 종목명 (표시용)
  double holdingShares;    // 보유수량
  double averagePrice;     // 평균단가 (USD)
  double currentPrice;     // 현재가 (USD)
  double exchangeRate;     // 현재 환율 (KRW/USD)

  // === 추가 매수 ===
  double additionalPrice;  // 추가 매수가 (USD, 기본값: currentPrice)
  double additionalAmount; // 추가 매수 금액 (KRW)
  // 또는
  double additionalShares; // 추가 매수 수량 (주)
  bool inputByAmount;      // true=금액입력, false=수량입력

  // === 수익률 역산 ===
  double targetReturnRate; // 목표 손익률 (%, 음수 가능)

  // === 목표가 수익 ===
  double targetPrice;      // 목표가 (USD)

  // === 사이클 연동 ===
  String? cycleId;         // 불러온 사이클 ID (null이면 직접입력)
}
```

### 3.2 출력 데이터 (계산 결과)

```dart
/// 물타기 계산 결과
class AvgDownResult {
  // === 핵심 결과 ===
  final double currentAvgPrice;     // 현재 평균단가
  final double newAvgPrice;         // 새 평균단가
  final double avgPriceReduction;   // 평단 하락률 (%)

  // === MDD ===
  final double currentMdd;          // 현재 MDD (%)
  final double newMdd;              // 물타기 후 MDD (%)
  final double mddImprovement;     // MDD 개선폭 (%p)

  // === 포지션 요약 ===
  final double totalShares;         // 총 수량
  final double totalInvestedKrw;    // 총 투자금 (KRW)
  final double evaluatedAmountKrw;  // 평가금액 (KRW)
  final double profitLossKrw;       // 평가손익 (KRW)
  final double returnRate;          // 손익률 (%)

  // === 시나리오 ===
  final List<ScenarioRow> scenarios; // 하락 시나리오 테이블

  // === 수익률 역산 ===
  final ReverseCalcResult? reverseCalc;

  // === 목표가 수익 ===
  final TargetPriceResult? targetPriceResult;
}

/// 하락 시나리오 행
class ScenarioRow {
  final double dropPercent;        // 추가 하락률 (%, 음수)
  final double projectedPrice;     // 예상가 (USD)
  final double mdd;                // 해당 시나리오 MDD (%)
  final double lossAmountKrw;      // 손실금액 (KRW)
}

/// 수익률 역산 결과
class ReverseCalcResult {
  final double requiredAmountKrw;  // 필요 금액 (KRW)
  final double requiredShares;     // 필요 수량
  final double newAvgPrice;        // 역산된 새 평단
  final bool isFeasible;           // 실현 가능 여부
  final String? infeasibleReason;  // 불가능 사유
}

/// 목표가 도달 시 수익 결과
class TargetPriceResult {
  final double currentProfit;      // 현재 포지션 기준 수익 (KRW)
  final double currentReturnRate;  // 현재 포지션 기준 수익률
  final double newProfit;          // 물타기 후 기준 수익 (KRW)
  final double newReturnRate;      // 물타기 후 기준 수익률
}
```

---

## 4. 계산 공식

### 4.1 파일: `lib/domain/trading/average_down_calculator.dart`

```dart
/// 물타기 계산기 — 순수 함수 모음 (외부 의존성 없음)
///
/// 기존 TradingMath와 역할 분리:
/// - TradingMath: 사이클 거래 중 실시간 평단/수익률 계산 (KRW VWAP)
/// - AverageDownCalculator: 물타기 시뮬레이션 전용 (순수 USD VWAP)
class AverageDownCalculator {
  AverageDownCalculator._();

  // ──────────────────────────────────────────
  // 1. 평균단가 (순수 USD VWAP)
  // ──────────────────────────────────────────

  /// 물타기 후 새 평균단가
  /// newAvg = (holdingShares × avgPrice + addShares × addPrice)
  ///        / (holdingShares + addShares)
  ///
  /// Zero-guard: 총수량이 0이면 0.0 반환
  static double newAveragePrice({
    required double holdingShares,
    required double averagePrice,
    required double additionalShares,
    required double additionalPrice,
  }) {
    final totalShares = holdingShares + additionalShares;
    if (totalShares <= 0) return 0.0;
    return (holdingShares * averagePrice + additionalShares * additionalPrice)
        / totalShares;
  }

  // ──────────────────────────────────────────
  // 2. MDD (Maximum Drawdown from Average)
  // ──────────────────────────────────────────

  /// MDD = (currentPrice - averagePrice) / averagePrice × 100
  ///
  /// 평단 대비 현재가의 하락률. 양수면 수익, 음수면 손실.
  /// Zero-guard: averagePrice가 0이면 0.0 반환
  static double mdd({
    required double currentPrice,
    required double averagePrice,
  }) {
    if (averagePrice <= 0) return 0.0;
    return (currentPrice - averagePrice) / averagePrice * 100;
  }

  /// 물타기 후 MDD
  static double newMdd({
    required double currentPrice,
    required double holdingShares,
    required double averagePrice,
    required double additionalShares,
    required double additionalPrice,
  }) {
    final newAvg = newAveragePrice(
      holdingShares: holdingShares,
      averagePrice: averagePrice,
      additionalShares: additionalShares,
      additionalPrice: additionalPrice,
    );
    return mdd(currentPrice: currentPrice, averagePrice: newAvg);
  }

  // ──────────────────────────────────────────
  // 3. 하락 시나리오
  // ──────────────────────────────────────────

  /// 추가 하락 시나리오별 MDD 및 손실금액 계산
  ///
  /// dropPercents: [-10, -20, -30, -50] 등
  /// 반환: 각 시나리오별 (예상가, MDD%, 손실금액KRW)
  static List<ScenarioRow> dropScenarios({
    required double currentPrice,
    required double averagePrice,
    required double totalShares,
    required double exchangeRate,
    required List<double> dropPercents,
  }) {
    return dropPercents.map((drop) {
      final projectedPrice = currentPrice * (1 + drop / 100);
      final scenarioMdd = mdd(
        currentPrice: projectedPrice,
        averagePrice: averagePrice,
      );
      final investedKrw = totalShares * averagePrice * exchangeRate;
      final evalKrw = totalShares * projectedPrice * exchangeRate;
      final lossKrw = evalKrw - investedKrw;
      return ScenarioRow(
        dropPercent: drop,
        projectedPrice: projectedPrice,
        mdd: scenarioMdd,
        lossAmountKrw: lossKrw,
      );
    }).toList();
  }

  // ──────────────────────────────────────────
  // 4. 수익률 역산
  // ──────────────────────────────────────────

  /// "목표 수익률을 달성하려면 얼마를 물타야 하는가"
  ///
  /// 목표평균단가 = currentPrice / (1 + targetReturnRate / 100)
  /// 필요수량 = (holdingShares × avgPrice - targetAvg × holdingShares)
  ///          / (targetAvg - additionalPrice)
  ///
  /// 제약: targetAvg > additionalPrice 이어야 함 (아래에서 사는 게 평단을 낮추므로)
  ///       targetReturnRate < currentMdd 이면 불가능
  static ReverseCalcResult reverseCalc({
    required double holdingShares,
    required double averagePrice,
    required double currentPrice,
    required double additionalPrice,
    required double exchangeRate,
    required double targetReturnRate,
  }) {
    // 목표 평균단가: currentPrice에서 targetReturnRate를 얻으려면
    // targetReturnRate = (currentPrice - targetAvg) / targetAvg × 100
    // targetAvg × (1 + targetReturnRate/100) = currentPrice
    final targetAvg = currentPrice / (1 + targetReturnRate / 100);

    // 실현 불가능 체크
    if (targetAvg <= additionalPrice) {
      return ReverseCalcResult(
        requiredAmountKrw: 0,
        requiredShares: 0,
        newAvgPrice: 0,
        isFeasible: false,
        infeasibleReason: '매수가가 목표 평단보다 높아 달성 불가능',
      );
    }

    // 필요수량 = (holdingShares × (avgPrice - targetAvg))
    //          / (targetAvg - additionalPrice)
    final requiredShares =
        (holdingShares * (averagePrice - targetAvg))
        / (targetAvg - additionalPrice);

    if (requiredShares <= 0) {
      return ReverseCalcResult(
        requiredAmountKrw: 0,
        requiredShares: 0,
        newAvgPrice: averagePrice,
        isFeasible: false,
        infeasibleReason: '이미 목표 수익률에 도달했거나 추가 매수 불필요',
      );
    }

    final requiredAmountKrw = requiredShares * additionalPrice * exchangeRate;
    final actualNewAvg = newAveragePrice(
      holdingShares: holdingShares,
      averagePrice: averagePrice,
      additionalShares: requiredShares,
      additionalPrice: additionalPrice,
    );

    return ReverseCalcResult(
      requiredAmountKrw: requiredAmountKrw,
      requiredShares: requiredShares,
      newAvgPrice: actualNewAvg,
      isFeasible: true,
      infeasibleReason: null,
    );
  }

  // ──────────────────────────────────────────
  // 5. 목표가 도달 시 예상 수익
  // ──────────────────────────────────────────

  /// 목표가에서의 수익 비교 (물타기 전 vs 후)
  static TargetPriceResult targetPriceProfit({
    required double holdingShares,
    required double averagePrice,
    required double additionalShares,
    required double additionalPrice,
    required double targetPrice,
    required double exchangeRate,
  }) {
    // 현재 포지션 기준
    final currentInvestedKrw = holdingShares * averagePrice * exchangeRate;
    final currentEvalKrw = holdingShares * targetPrice * exchangeRate;
    final currentProfit = currentEvalKrw - currentInvestedKrw;
    final currentReturn = currentInvestedKrw > 0
        ? (currentProfit / currentInvestedKrw * 100)
        : 0.0;

    // 물타기 후 기준
    final totalShares = holdingShares + additionalShares;
    final newAvg = newAveragePrice(
      holdingShares: holdingShares,
      averagePrice: averagePrice,
      additionalShares: additionalShares,
      additionalPrice: additionalPrice,
    );
    final newInvestedKrw = totalShares * newAvg * exchangeRate;
    final newEvalKrw = totalShares * targetPrice * exchangeRate;
    final newProfit = newEvalKrw - newInvestedKrw;
    final newReturn = newInvestedKrw > 0
        ? (newProfit / newInvestedKrw * 100)
        : 0.0;

    return TargetPriceResult(
      currentProfit: currentProfit,
      currentReturnRate: currentReturn,
      newProfit: newProfit,
      newReturnRate: newReturn,
    );
  }

  // ──────────────────────────────────────────
  // 6. 헬퍼: 금액 → 수량 변환
  // ──────────────────────────────────────────

  /// 매수금액(KRW)으로 매수 가능한 수량 계산
  /// Zero-guard: price 또는 exchangeRate가 0이면 0.0 반환
  static double sharesToBuy({
    required double amountKrw,
    required double price,
    required double exchangeRate,
  }) {
    if (price <= 0 || exchangeRate <= 0) return 0.0;
    return amountKrw / (price * exchangeRate);
  }
}
```

### 4.2 기존 TradingMath와의 관계

| 항목 | TradingMath | AverageDownCalculator |
|------|-------------|----------------------|
| 용도 | 실제 거래 기록 시 평단 재계산 | 물타기 시뮬레이션 |
| VWAP 방식 | KRW 기반 (환율 포함) | 순수 USD 기반 |
| 의존성 | 사이클/거래 모델 | 없음 (순수 함수) |
| 상태 변경 | Hive 저장 | 없음 (읽기 전용) |

중복 없음 — 역할이 명확히 분리됨.

---

## 5. 파일 구조

```
lib/
├── domain/trading/
│   ├── trading_math.dart              # 기존 (변경 없음)
│   └── average_down_calculator.dart   # [신규] 순수 계산 로직
│
├── presentation/
│   ├── screens/tools/
│   │   └── avg_down_screen.dart       # [신규] 계산기 메인 화면
│   │
│   └── widgets/tools/
│       ├── avg_down_input_section.dart   # [신규] Section A+B: 입력 영역
│       ├── avg_down_result_card.dart     # [신규] Section C: 핵심 결과
│       ├── mdd_scenario_table.dart       # [신규] Section D: 시나리오 테이블
│       ├── reverse_calc_section.dart     # [신규] Section E: 수익률 역산
│       ├── target_price_section.dart     # [신규] Section F: 목표가 수익
│       └── cycle_picker_sheet.dart       # [신규] 사이클 선택 BottomSheet
│
├── routes/
│   └── app_router.dart                # [수정] /tools/avg-down 라우트 추가
│
└── presentation/widgets/common/
    └── calculator_button.dart         # [신규] 앱바 계산기 아이콘 버튼
```

### 5.1 신규 파일 상세 (8개)

| 파일 | 책임 | 예상 LOC |
|------|------|----------|
| `average_down_calculator.dart` | 순수 계산 함수 + 결과 모델 클래스 | ~200 |
| `avg_down_screen.dart` | StatefulWidget, 입력 상태 관리, 레이아웃 | ~350 |
| `avg_down_input_section.dart` | 보유+추가매수 입력 폼 | ~200 |
| `avg_down_result_card.dart` | MDD 카드 + 포지션 요약 | ~150 |
| `mdd_scenario_table.dart` | 하락 시나리오 테이블 + 색상 그라데이션 | ~120 |
| `reverse_calc_section.dart` | 수익률 역산 입력+결과 | ~120 |
| `target_price_section.dart` | 목표가 수익 비교 | ~100 |
| `cycle_picker_sheet.dart` | 활성 사이클 BottomSheet | ~150 |
| `calculator_button.dart` | 앱바 아이콘 버튼 (3개 화면 공통) | ~30 |

### 5.2 수정 파일 (4개)

| 파일 | 변경 내용 |
|------|----------|
| `app_router.dart` | `/tools/avg-down` GoRoute 추가 |
| `home_screen.dart` | 앱바에 `CalculatorButton` 추가 |
| `watchlist_screen.dart` | 앱바에 `CalculatorButton` 추가 |
| `stocks_screen.dart` | 앱바에 `CalculatorButton` 추가 |

---

## 6. Phase별 구현 계획

### Phase 1: 계산 엔진 + 결과 모델 (독립 테스트 가능)
- `average_down_calculator.dart` 작성 (순수 함수 + 5개 결과 모델 클래스)
- 단위 테스트 가능 상태

### Phase 2: UI 기본 골격
- `avg_down_screen.dart` — StatefulWidget + 입력 상태 + 반응형 레이아웃
- `avg_down_input_section.dart` — 보유/추가매수 입력 폼
- `avg_down_result_card.dart` — MDD 카드 + 포지션 요약
- `calculator_button.dart` — 앱바 아이콘

### Phase 3: 시나리오 + 역산 + 목표가
- `mdd_scenario_table.dart` — 시나리오 테이블
- `reverse_calc_section.dart` — 수익률 역산
- `target_price_section.dart` — 목표가 수익

### Phase 4: 사이클 연동 + 라우터 + 마무리
- `cycle_picker_sheet.dart` — 활성 사이클 선택
- `app_router.dart` 수정 — 라우트 등록
- 3개 화면 앱바에 `CalculatorButton` 추가
- 현재가/환율 자동 로드 (기존 Provider 재사용)

---

## 7. 사이클 연동 방식

### 7.1 데이터 흐름

```
사이클 선택 시트
    │
    ▼
cycleListProvider (기존) → 활성 사이클 목록 필터
    │
    ▼
선택된 Cycle 객체에서 추출:
    - cycle.ticker → tickerName
    - cycle.totalShares → holdingShares
    - cycle.averagePrice → averagePrice
    - cycle.exchangeRateAtEntry → (참고용, 현재 환율은 별도)
    │
    ▼
현재가: stockQuoteProvider(ticker) → quote.currentPrice
환율: exchangeRateProvider → currentRate
```

### 7.2 Provider 의존성 (기존 재사용, 신규 생성 없음)

| 데이터 | Provider | 파일 |
|--------|----------|------|
| 활성 사이클 목록 | `cycleListProvider` | `cycle_providers.dart` |
| 실시간 시세 | `stockQuoteProvider` | `api_providers.dart` |
| 환율 | `exchangeRateProvider` | `market_data_providers.dart` |

### 7.3 직접 입력 모드

사이클 없이도 독립 사용 가능:
- 종목명: 자유 텍스트 입력 (검색/검증 없음)
- 보유수량, 평균단가, 현재가, 환율: 수동 입력
- 국내주식: 환율 1.0으로 설정하면 KRW 단독 계산 가능

---

## 8. 엣지 케이스

### 8.1 입력 검증

| 케이스 | 처리 |
|--------|------|
| 보유수량 = 0 | 결과 영역 비표시, "보유 수량을 입력하세요" 안내 |
| 평균단가 = 0 | 결과 영역 비표시 |
| 현재가 = 0 | 결과 영역 비표시 |
| 추가 매수금액 = 0 | 물타기 결과 비표시, 현재 MDD만 표시 |
| 환율 = 0 | 환율 필드 빨간 테두리, 결과 비표시 |
| 매수가 > 평균단가 | 평단 상승 경고 표시 (물타기 역효과) |
| 매수금액 < 최소 1주 가격 | "1주 미만" 경고 (소수점 매수는 허용) |

### 8.2 수익률 역산 불가능 케이스

| 케이스 | infeasibleReason |
|--------|-----------------|
| 매수가 >= 목표평단 | "매수가가 목표 평단보다 높아 달성 불가능" |
| 이미 목표 초과 | "이미 목표 수익률에 도달했거나 추가 매수 불필요" |
| 필요금액 > 10억원 | 결과는 표시하되 "대규모 자금 필요" 경고 |

### 8.3 숫자 포맷

| 항목 | 포맷 | 예시 |
|------|------|------|
| USD 가격 | 소수점 2자리 | $45.00 |
| KRW 금액 | 천 단위 콤마, 원 | ₩6,710,000 |
| KRW 축약 | 만/억 단위 | ₩671만, ₩1.2억 |
| 수량 | 소수점 2자리 | 109.44주 |
| 퍼센트 | 소수점 1자리 | -15.0% |
| 환율 | 소수점 0자리 | ₩1,380 |

### 8.4 레버리지 ETF 관련

- 시나리오 테이블은 **해당 ETF 가격 기준** 추가 하락률 적용 (기초지수 환산 아님)
- 레버리지 괴리는 표시하지 않음 (장기 보유 시 괴리 존재하나 정밀 계산 범위 밖)
- 시나리오 하락률 기본값: -10%, -20%, -30%, -50% (사용자 수정 불가, 고정)

---

## 9. UI 상세

### 9.1 색상 규칙

| 요소 | 색상 | 비고 |
|------|------|------|
| MDD 손실(음수) | `context.appStockChangeMinusFg` | 파란색 계열 (한국 관례) |
| MDD 수익(양수) | `context.appStockChangePlusFg` | 빨간색 계열 |
| MDD 개선폭 | `context.appStockChangePlusFg` | 항상 긍정 표시 |
| 시나리오 테이블 배경 | `context.appStockChangeMinusBg` | 하락폭에 따라 opacity 증가 |
| 카드 배경 | `context.appCardBackground` | |
| 구분선 | `context.appDivider` | |
| 입력 필드 | `context.appSurface` + `context.appBorder` | |
| 비활성/불가능 | `context.appTextHint` | |

### 9.2 MDD 카드 시각적 강조

```dart
// MDD 카드: 가장 큰 글씨 + 색상 배경 + 아이콘
Container(
  padding: EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: context.appStockChangeMinusBg, // 또는 PlusBg
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: context.appBorder),
  ),
  child: Column(
    children: [
      // "현재 MDD" 라벨 + 값 (24px, bold)
      // "물타기 후 MDD" 라벨 + 값 (28px, bold, 강조)
      // "개선폭" 라벨 + 값 (16px, 수익 색상)
    ],
  ),
);
```

### 9.3 시나리오 테이블 그라데이션

시나리오 행의 배경 opacity를 하락폭에 비례하여 증가:

```dart
// opacity: 0.1 → 0.2 → 0.3 → 0.5 (하락폭에 비례)
final opacity = (drop.abs() / 100).clamp(0.05, 0.5);
Container(
  color: context.appStockChangeMinusFg.withOpacity(opacity),
  // ...
);
```

### 9.4 반응형 레이아웃

| 화면 폭 | 레이아웃 |
|---------|---------|
| < 600px | 단일 컬럼 스크롤 (모바일) |
| 600~899px | 단일 컬럼, 넓은 패딩 (태블릿) |
| >= 900px | 2열 (좌: 입력 고정, 우: 결과 스크롤) |

---

## 10. 검증 방법

### 10.1 단위 테스트 (AverageDownCalculator)

```dart
// 테스트 케이스 예시
group('AverageDownCalculator', () {
  test('newAveragePrice - 기본 물타기', () {
    // 100주 × $45 + 50주 × $30 = $40
    final result = AverageDownCalculator.newAveragePrice(
      holdingShares: 100, averagePrice: 45,
      additionalShares: 50, additionalPrice: 30,
    );
    expect(result, closeTo(40.0, 0.01));
  });

  test('mdd - 손실 상태', () {
    // ($38 - $45) / $45 = -15.56%
    final result = AverageDownCalculator.mdd(
      currentPrice: 38, averagePrice: 45,
    );
    expect(result, closeTo(-15.56, 0.1));
  });

  test('reverseCalc - 목표 -5%', () {
    final result = AverageDownCalculator.reverseCalc(
      holdingShares: 100, averagePrice: 45,
      currentPrice: 38, additionalPrice: 38,
      exchangeRate: 1380, targetReturnRate: -5,
    );
    expect(result.isFeasible, true);
    expect(result.newAvgPrice, closeTo(40.0, 0.1));
  });

  test('reverseCalc - 불가능 케이스', () {
    final result = AverageDownCalculator.reverseCalc(
      holdingShares: 100, averagePrice: 45,
      currentPrice: 38, additionalPrice: 50, // 매수가 > 현재가
      exchangeRate: 1380, targetReturnRate: 5, // 수익 목표
    );
    expect(result.isFeasible, false);
  });

  test('zero-guard - 보유수량 0', () {
    final result = AverageDownCalculator.newAveragePrice(
      holdingShares: 0, averagePrice: 0,
      additionalShares: 50, additionalPrice: 30,
    );
    expect(result, closeTo(30.0, 0.01));
  });
});
```

### 10.2 Playwright 수동 검증

| 항목 | 검증 내용 |
|------|----------|
| 진입 | 홈/관심/My 앱바 계산기 아이콘 → `/tools/avg-down` 이동 |
| 직접 입력 | 수량/단가/현재가 입력 → 실시간 결과 갱신 확인 |
| 사이클 불러오기 | "사이클에서 불러오기" → 시트 → 선택 → 필드 자동 채움 |
| MDD 표시 | 현재 MDD, 물타기 후 MDD, 개선폭 정확성 |
| 시나리오 | 4단계 하락 시나리오 값 + 색상 그라데이션 |
| 역산 | 목표 수익률 입력 → 필요 금액/수량 표시 |
| 불가능 | 역산 불가능 시 사유 메시지 표시 |
| 목표가 | 목표가 입력 → 현재/물타기 후 수익 비교 |
| 반응형 | 375px(모바일), 1280px(데스크톱) 레이아웃 전환 |
| 다크모드 | 7개 테마에서 색상 정상 표시 |

---

## 11. 기술 결정 사항

### 11.1 StatefulWidget vs Riverpod StateNotifier

**결정: StatefulWidget 로컬 상태**

- 계산기는 일회성 시뮬레이션 도구, 영속화 불필요
- 다른 화면과 상태를 공유하지 않음
- TextEditingController 관리가 StatefulWidget에서 자연스러움
- Riverpod 오버헤드 불필요 (Provider 파일 추가 없음)

단, 사이클 목록/시세/환율 **읽기**는 기존 Riverpod Provider를 `ref.read()`로 사용.
→ 화면은 `ConsumerStatefulWidget`으로 선언.

### 11.2 금액 입력 vs 수량 입력

**결정: 금액 입력 기본, 토글로 수량 입력 전환**

- 한국 투자자는 "몇 원 넣을까"로 사고하는 경우가 대부분
- 수량 입력도 필요한 경우 있음 (이미 주수를 알고 있을 때)
- SegmentedButton 또는 Switch로 전환: `[₩금액] [수량]`

### 11.3 라우트 구조

**결정: ShellRoute 내부에 `/tools/avg-down` 추가**

- 하단 네비게이션 바 유지 (메인 탭에서 빠르게 돌아올 수 있도록)
- 앱바 뒤로가기(←)로 이전 탭 복귀
- 향후 다른 도구 추가 시 `/tools/*` 네임스페이스 활용 가능

```dart
// app_router.dart 추가
GoRoute(
  path: '/tools/avg-down',
  builder: (context, state) => const AvgDownScreen(),
),
```
