# Ladder Cycle 설계서 v3.1

> **변경 이력**
> - v2.1 → v3.0: 디자인 리뷰 15건 반영 (C-1~C-7, I-1~I-6, M-1~M-2)
> - v3.0 → v3.1: 아키텍처 감사 11건 반영 (F-1~F-20 중 Critical 5건, Important 6건)

## 1. 개요

### 1.1 전략 개념
MDD(최대낙폭) 기반 N단계 가속 분할매수법. ATH(역사적 신고가) 대비 하락률에 따라 투입 비중을 기하급수적으로 높여 평단가를 극적으로 낮추는 마틴게일 기반 전략.

### 1.2 네이밍
- **UI 표시명**: Ladder Cycle
- **enum 값**: `StrategyType.ladderCycle` (HiveField: 2)
- **아이콘**: `Icons.stacked_bar_chart`
- **색상**: `AppColors.amber500` / Dark: `AppColors.amber400`
- **StrategyBadge 표시**: `⧈ Ladder 안정형` / `⧈ Ladder 공격형` / `⧈ Ladder 초공격형`

### 1.3 기존 전략과의 비교

| 항목 | Smart Cycle | Steady Cycle | **Ladder Cycle** |
|------|-------------|-------------|-----------------|
| 매수 트리거 | 수익률 기반 (자기 평단가) | 라운드 기반 (고정 분할) | **MDD 기반 (ATH 대비 하락률)** |
| 매수 비중 | 초기 20% + 가중 + 승부수 | 균등 분할 (1/N) | **가속형 1-1-2-3-4-5 (16분할, 기본)** |
| 매수 대상 | 단일 티커 | 단일 티커 | **단계별 복수 티커 추천 (안정형)** |
| 매도 | 동적 익절 목표 | LOC/지정가 | **가이드만 제공 (수동)** |
| 사이클 종료 | 익절 달성 | 전량 매도 | **신고점 도달 시** |

---

## 2. 데이터 모델 변경

### 2.1 StrategyType enum 확장

```dart
// cycle.dart — StrategyType enum
@HiveField(2)  // 새 값
ladderCycle,
```

### 2.2 Cycle 모델 신규 필드

기존 HiveField 마지막 번호: **42**

| HiveField | 필드명 | 타입 | 기본값 | 설명 |
|-----------|--------|------|--------|------|
| 43 | `athPrice` | double | 0.0 | ATH 가격 (USD, 수동 입력) |
| 44 | `ladderMode` | int | 1 | 모드 (0=안정형, 1=공격형, 2=초공격형) |
| 45 | `currentStep` | int | 0 | 현재 진행 단계 (0=대기, 1~N) |
| 46 | `ladderSteps` | int | 6 | 분할 단계 수 (3~6) |
| 47 | `ladderWeights` | String | '1,1,2,3,4,5' | 쉼표로 구분된 비중 |
| 48 | `ladderTriggers` | String | '-10,-19,-28,-37,-46,-55' | 쉼표로 구분된 MDD 트리거 |

**설계 근거:**
- `athPrice`: 사용자 수동 입력. API 자동화는 향후 확장.
- `ladderMode`: int로 저장 (enum 추가 시 TypeId 필요 → int로 단순화).
- `currentStep`: 거래 기록 시 자동 갱신. 0 = 아직 매수 없음.
- `ladderSteps`: 3~6 단계 가변 지원. 기본값 6으로 기존 호환.
- `ladderWeights`: String으로 저장하여 유연한 커스텀 비중 지원. 파싱은 `parseLadderWeights()` 헬퍼 사용 (**C-1** 방어적 파싱).
- `ladderTriggers`: String으로 저장하여 단계 수에 따른 가변 트리거 지원. 파싱은 `parseLadderTriggers()` 헬퍼 사용 (**C-1** 방어적 파싱).

#### 2.2.1 ladderWeights/ladderTriggers 방어적 파싱 헬퍼 (C-1, I-1)

**파일 배치: `lib/domain/trading/ladder_cycle_service.dart`** — 아래 모든 헬퍼 함수는 이 파일의 top-level function으로 배치한다.

```dart
/// ladderWeights 문자열을 안전하게 파싱
/// 빈 문자열, 잘못된 형식 → 기본값 [1,1,2,3,4,5] 반환
List<int> parseLadderWeights(String weightsStr, {int steps = 6}) {
  if (weightsStr.trim().isEmpty) {
    return _defaultWeights(steps);
  }
  try {
    final parts = weightsStr.split(',');
    final weights = parts
        .map((s) => int.tryParse(s.trim()) ?? 1)
        .toList();
    if (weights.isEmpty) return _defaultWeights(steps);
    return weights;
  } catch (_) {
    return _defaultWeights(steps);
  }
}

/// ladderTriggers 문자열을 안전하게 파싱
/// 빈 문자열, 잘못된 형식 → 기본 트리거값 반환
List<double> parseLadderTriggers(String triggersStr, {int steps = 6}) {
  if (triggersStr.trim().isEmpty) {
    return _defaultTriggers(steps);
  }
  try {
    final parts = triggersStr.split(',');
    final triggers = parts
        .map((s) => double.tryParse(s.trim()) ?? 0.0)
        .toList();
    if (triggers.isEmpty) return _defaultTriggers(steps);
    return triggers;
  } catch (_) {
    return _defaultTriggers(steps);
  }
}

/// 단계별 기본 비중
List<int> _defaultWeights(int steps) => switch (steps) {
  3 => [2, 3, 5],
  4 => [1, 2, 3, 4],
  5 => [1, 1, 2, 3, 3],
  _ => [1, 1, 2, 3, 4, 5],
};

/// 단계별 기본 MDD 트리거
List<double> _defaultTriggers(int steps) => switch (steps) {
  3 => [-15, -30, -50],
  4 => [-10, -22, -37, -55],
  5 => [-10, -20, -30, -42, -55],
  _ => [-10, -19, -28, -37, -46, -55],
};
```

### 2.3 Cycle 직렬화 — toJson/fromJson 확장 (C-2)

**기존 Cycle.toJson에 6개 필드 추가:**

```dart
// Cycle.toJson() — 기존 필드 뒤에 추가
Map<String, dynamic> toJson() => {
  // ... 기존 필드들 그대로 유지 (id, ticker, name, ... totalSellUsd) ...
  // Ladder Cycle 신규 필드 (C-2)
  'athPrice': athPrice,
  'ladderMode': ladderMode,
  'currentStep': currentStep,
  'ladderSteps': ladderSteps,
  'ladderWeights': ladderWeights,
  'ladderTriggers': ladderTriggers,
};
```

**기존 Cycle.fromJson에 6개 필드 추가 (기존 패턴 준수: `(json['field'] as num?)?.toDouble() ?? default`):**

```dart
factory Cycle.fromJson(Map<String, dynamic> json) {
  final cycle = Cycle(
    // ... 기존 파라미터들 그대로 유지 ...
    // Ladder Cycle 신규 필드 (C-2)
    // athPrice는 생성자 파라미터가 아니므로 아래에서 별도 설정
  );
  // 기존 mutable 필드 복원 (averagePrice, totalShares, remainingCash, status 등)
  // ... 기존 코드 그대로 ...

  // Ladder Cycle 필드 복원 (C-2)
  cycle.athPrice = (json['athPrice'] as num?)?.toDouble() ?? 0.0;
  cycle.ladderMode = (json['ladderMode'] as num?)?.toInt() ?? 1;
  cycle.currentStep = (json['currentStep'] as num?)?.toInt() ?? 0;
  cycle.ladderSteps = (json['ladderSteps'] as num?)?.toInt() ?? 6;
  cycle.ladderWeights = json['ladderWeights'] as String? ?? '1,1,2,3,4,5';
  cycle.ladderTriggers = json['ladderTriggers'] as String? ?? '-10,-19,-28,-37,-46,-55';
  return cycle;
}
```

**참고:** 생성자에 Ladder 필드를 named parameter로 추가하거나, 생성자 밖에서 mutable 설정하는 두 가지 방식 모두 가능. 기존 코드의 `averagePrice`, `totalShares` 복원 패턴(생성자 밖 대입)을 따른다.

**StrategyType fromJson 예외 처리 (I-2):**

기존 `_parseSteadyVersion` 패턴을 따라 StrategyType 파싱에도 try-catch 적용:

```dart
// Cycle.fromJson 내부
strategyType: _parseStrategyType(json['strategyType'] as String?),

// 헬퍼 메서드 (기존 _parseSteadyVersion 패턴 준수)
static StrategyType _parseStrategyType(String? value) {
  if (value == null) return StrategyType.alphaCycleV3;
  try {
    return StrategyType.values.byName(value);
  } catch (_) {
    return StrategyType.alphaCycleV3; // 알 수 없는 전략 → Smart 폴백
  }
}
```

### 2.4 Trade 모델 신규 필드

기존 HiveField 마지막 번호: **10**

| HiveField | 필드명 | 타입 | 기본값 | 설명 |
|-----------|--------|------|--------|------|
| 11 | `ticker` | String? | null | 거래 티커 (null이면 cycle.ticker 사용) |

**설계 근거:**
- Ladder Cycle 안정형에서 QQQ/QLD/TQQQ 중 선택한 티커를 Trade에 직접 기록.
- 기존 Smart/Steady는 null 유지 → 하위호환 완벽.

#### 2.4.1 Trade 직렬화 — toJson/fromJson 확장 (C-2)

**Trade.toJson에 ticker 추가:**

```dart
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
  'groupId': groupId,
  'ticker': ticker,  // (C-2) Ladder 안정형 멀티 티커용
};
```

**Trade.fromJson에 ticker 추가:**

```dart
factory Trade.fromJson(Map<String, dynamic> json) => Trade(
  id: json['id'] as String,
  cycleId: json['cycleId'] as String,
  action: TradeAction.values.byName(json['action'] as String),
  signal: _parseTradeSignal(json['signal'] as String),
  price: (json['price'] as num).toDouble(),
  shares: (json['shares'] as num).toDouble(),
  amountKrw: (json['amountKrw'] as num).toDouble(),
  exchangeRate: (json['exchangeRate'] as num).toDouble(),
  tradedAt: DateTime.parse(json['tradedAt'] as String),
  memo: json['memo'] as String?,
  groupId: json['groupId'] as String?,
  ticker: json['ticker'] as String?,  // (C-2) nullable — 기존 백업에 없으면 null
);
```

### 2.5 TradeSignal enum 확장

```dart
// trade.dart — TradeSignal enum
@HiveField(15)  ladderStep1,    // MDD 1단계
@HiveField(16)  ladderStep2,    // MDD 2단계
@HiveField(17)  ladderStep3,    // MDD 3단계
@HiveField(18)  ladderStep4,    // MDD 4단계
@HiveField(19)  ladderStep5,    // MDD 5단계
@HiveField(20)  ladderStep6,    // MDD 6단계
```

### 2.6 Hive TypeId/HiveField 요약

| 대상 | 변경 | 번호 |
|------|------|------|
| StrategyType | 새 enum 값 | HiveField 2 |
| Cycle | 6개 필드 추가 | HiveField 43~48 |
| Trade | 1개 필드 추가 | HiveField 11 |
| TradeSignal | 6개 enum 값 추가 | HiveField 15~20 |
| Settings | 1개 필드 추가 (ladderCycleChartColor) | **HiveField 22** |

### 2.7 백업 버전 업그레이드 (C-2)

**data_management_service.dart** 변경:

```dart
// createBackup()
'version': 6,  // 5 → 6 (Ladder Cycle 필드 추가)

// restoreFromBackup()
if (version > 6) {  // 5 → 6
  throw FormatException('지원하지 않는 백업 버전: $version');
}
// 기존 v5 이하 백업 파일에는 Ladder 필드가 없지만,
// Cycle.fromJson / Trade.fromJson에서 nullable 안전 파싱 → 기본값 사용
// → 별도 마이그레이션 로직 불필요
```

### 2.8 CSV 내보내기 ticker 컬럼 추가 (I-4)

```dart
// data_management_service.dart — exportToCsv()

// 기존:
// buffer.writeln('날짜,사이클ID,매매,신호,단가(USD),수량,금액(KRW),환율,메모');

// 변경 — "종목" 컬럼 추가:
buffer.writeln('날짜,사이클ID,종목,매매,신호,단가(USD),수량,금액(KRW),환율,메모');

// 기존 Trade 루프에서 종목 값 추가:
for (final trade in trades) {
  // 사이클 찾기 (ticker 폴백용)
  final cycle = cycleRepository.get(trade.cycleId);
  final tradeTicker = trade.ticker ?? cycle?.ticker ?? '';
  buffer.writeln(
    '${_formatCsvDate(trade.tradedAt)},'
    '${trade.cycleId.substring(0, 8)},'
    '$tradeTicker,'  // (I-4) 종목 컬럼
    '${trade.action == TradeAction.buy ? "매수" : "매도"},'
    '${trade.signal.name},'
    '${trade.price.toStringAsFixed(2)},'
    '${trade.shares.toStringAsFixed(4)},'
    '${trade.amountKrw.toStringAsFixed(0)},'
    '${trade.exchangeRate.toStringAsFixed(2)},'
    '${_escapeCsv(trade.memo ?? "")}',
  );
}
```

### 2.9 Settings 모델 — ladderCycleChartColor 추가 (F-7)

기존 Settings HiveField 마지막 번호: **21** (themeType)

**settings.dart 변경:**

```dart
/// Ladder Cycle 차트 색상 (0 = 기본색 사용, 양수 = Color.value)
@HiveField(22, defaultValue: 0)
int ladderCycleChartColor;
```

**생성자 기본값 추가:**
```dart
Settings({
  // ... 기존 파라미터들 ...
  this.ladderCycleChartColor = 0,  // (F-7)
});
```

**copyWith 확장:**
```dart
Settings copyWith({
  // ... 기존 파라미터들 ...
  int? ladderCycleChartColor,
}) {
  return Settings(
    // ... 기존 필드들 ...
    ladderCycleChartColor: ladderCycleChartColor ?? this.ladderCycleChartColor,
  );
}
```

**toJson 확장:**
```dart
Map<String, dynamic> toJson() => {
  // ... 기존 필드들 ...
  'ladderCycleChartColor': ladderCycleChartColor,  // (F-7)
};
```

**fromJson 확장:**
```dart
factory Settings.fromJson(Map<String, dynamic> json) => Settings(
  // ... 기존 필드들 ...
  ladderCycleChartColor: json['ladderCycleChartColor'] as int? ?? 0,  // (F-7)
);
```

**settings.g.dart 수동 수정 (F-16: 프로젝트 기존 관례대로 수동 수정):**

```dart
// read() — fields[22] 추가
ladderCycleChartColor: fields[22] == null ? 0 : fields[22] as int,

// write() — writeByte 카운트 22 → 23, field 22 추가
writer
  ..writeByte(23)  // 22 → 23
  // ... 기존 0~21 ...
  ..writeByte(22)
  ..write(obj.ladderCycleChartColor);
```

> **(F-16) .g.dart 수동 수정 패턴:** 이 프로젝트는 `build_runner`를 사용하지 않고 `.g.dart` 파일을 수동으로 관리한다. `settings.g.dart`, `cycle.g.dart`, `trade.g.dart` 모두 동일한 수동 수정 관례를 따른다.

---

## 3. N단계 매집 로직

### 3.1 단계별 정의 (기본: 6단계 가속형)

| 단계 | MDD 트리거 | 비중 (N/16) | 비중 (%) | 누적 | 전략적 상태 |
|------|-----------|-------------|---------|------|------------|
| 1 | -10% | 1/16 | 6.25% | 6.25% | 정찰대 |
| 2 | -19% | 1/16 | 6.25% | 12.5% | 심리적 완충 |
| 3 | -28% | 2/16 | 12.5% | 25% | 본격 매집 |
| 4 | -37% | 3/16 | 18.75% | 43.75% | 공포 대응 |
| 5 | -46% | 4/16 | 25% | 68.75% | 패닉 셀링 |
| 6 | -55% | 5/16 | 31.25% | 100% | 항복 전량 투입 |

### 3.2 단계별 MDD 트리거 테이블

**3단계:**

| 단계 | MDD 트리거 |
|------|-----------|
| 1 | -15% |
| 2 | -30% |
| 3 | -50% |

**4단계:**

| 단계 | MDD 트리거 |
|------|-----------|
| 1 | -10% |
| 2 | -22% |
| 3 | -37% |
| 4 | -55% |

**5단계:**

| 단계 | MDD 트리거 |
|------|-----------|
| 1 | -10% |
| 2 | -20% |
| 3 | -30% |
| 4 | -42% |
| 5 | -55% |

**6단계 (기본):**

| 단계 | MDD 트리거 |
|------|-----------|
| 1 | -10% |
| 2 | -19% |
| 3 | -28% |
| 4 | -37% |
| 5 | -46% |
| 6 | -55% |

### 3.3 비율 프리셋 테이블

**3단계:**

| 프리셋 | 비중 | 합계 |
|--------|------|------|
| 균등형 | 1 / 1 / 1 | 3 (각 33.3%) |
| 가속형 | 2 / 3 / 5 | 10 |
| 피보나치형 | 1 / 1 / 2 | 4 |

**4단계:**

| 프리셋 | 비중 | 합계 |
|--------|------|------|
| 균등형 | 1 / 1 / 1 / 1 | 4 (각 25%) |
| 가속형 | 1 / 2 / 3 / 4 | 10 |
| 피보나치형 | 1 / 1 / 2 / 3 | 7 |

**5단계:**

| 프리셋 | 비중 | 합계 |
|--------|------|------|
| 균등형 | 1 / 1 / 1 / 1 / 1 | 5 (각 20%) |
| 가속형 | 1 / 1 / 2 / 3 / 3 | 10 |
| 피보나치형 | 1 / 1 / 2 / 3 / 5 | 12 |

**6단계 (기본):**

| 프리셋 | 비중 | 합계 |
|--------|------|------|
| 균등형 | 1 / 1 / 1 / 1 / 1 / 1 | 6 (각 16.67%) |
| 가속형 | 1 / 1 / 2 / 3 / 4 / 5 | 16 |
| 피보나치형 | 1 / 1 / 2 / 3 / 5 / 8 | 20 |

> **(M-2) 균등형 반올림:** 균등형은 모든 비중을 1로 저장 (예: 6단계 = `'1,1,1,1,1,1'`, totalWeight=6). `stepAmount = seed * 1 / 6` → 자연스럽게 균등 분배, 반올림 이슈 없음. UI 표시 시 %는 `(1/6)*100 = 16.67%`로 표시.

> **(M-1) 커스텀 비율 도메인 방어:** `stepAmount()`에서 totalWeight 기반 나눗셈이므로, 사용자가 10/10/15/20/22/23 (합 100)이든 2/2/3/4/4/5 (합 20)이든 자동으로 비례 분배됨. 추가로 Cycle 생성 시 weights 합계가 0이면 기본값(`_defaultWeights(steps)`)으로 폴백.

### 3.4 MDD 계산

**파일 배치: `lib/domain/trading/ladder_cycle_service.dart`** (top-level function)

```dart
double calculateMDD(double athPrice, double currentPrice) {
  if (athPrice <= 0) return 0;
  return ((currentPrice - athPrice) / athPrice) * 100;
  // 예: ATH=$500, 현재=$400 → MDD = -20%
}
```

### 3.5 단계별 투입금 계산 (가변 단계/비율 지원)

**파일 배치: `lib/domain/trading/ladder_cycle_service.dart`** (top-level function)

```dart
/// 가변 단계/비율 지원 투입금 계산
/// (C-1) tryParse + 기본값 폴백 사용
/// (C-4) step 범위 검증
double stepAmount(double seedAmount, int step, Cycle cycle) {
  final weights = parseLadderWeights(cycle.ladderWeights, steps: cycle.ladderSteps);
  // (C-4) step 범위 미검증 방어
  if (step < 1 || step > weights.length) return 0;
  final totalWeight = weights.fold<int>(0, (sum, w) => sum + w);
  // (M-1) totalWeight가 0이면 방어
  if (totalWeight == 0) return seedAmount / weights.length;
  return seedAmount * weights[step - 1] / totalWeight;
}
```

### 3.6 모드별 티커 추천

**파일 배치: `lib/domain/trading/ladder_cycle_service.dart`** (top-level function)

| 모드 | 단계 1-2 | 단계 3-4 | 단계 5-6 |
|------|---------|---------|---------|
| 안정형 (0) | QQQ 강조 | QLD 강조 | TQQQ 강조 |
| 공격형 (1) | TQQQ | TQQQ | TQQQ |
| 초공격형 (2) | SOXL | SOXL | SOXL |

안정형은 항상 3개 뱃지 표시 (QQQ, QLD, TQQQ), 단계에 따라 강조 순서만 변경.

```dart
List<String> recommendedTickers(int ladderMode, int step) {
  if (ladderMode == 0) {
    if (step <= 2) return ['QQQ', 'QLD', 'TQQQ'];
    if (step <= 4) return ['QLD', 'QQQ', 'TQQQ'];
    return ['TQQQ', 'QQQ', 'QLD'];
  }
  if (ladderMode == 1) return ['TQQQ'];
  return ['SOXL'];
}
```

### 3.7 갭 하락 처리

**파일 배치: `lib/domain/trading/ladder_cycle_service.dart`** (top-level function)

```dart
double gapAmount(double seedAmount, int fromStep, int toStep, Cycle cycle) {
  double total = 0;
  for (int s = fromStep + 1; s <= toStep; s++) {
    total += stepAmount(seedAmount, s, cycle);
  }
  return total;
}
```

### 3.8 안정형 멀티 티커 계산

안정형에서 QQQ, QLD, TQQQ 3개 티커를 동시 보유할 수 있으므로:

**티커별 그룹핑:**
```dart
// Trade.ticker 기준으로 같은 사이클 내 거래를 티커별 분류
Map<String, List<Trade>> groupByTicker(List<Trade> trades, String cycleTicker) {
  final map = <String, List<Trade>>{};
  for (final t in trades) {
    final ticker = t.ticker ?? cycleTicker;
    map.putIfAbsent(ticker, () => []).add(t);
  }
  return map;
}
```

**티커별 VWAP 계산:**
```dart
// 각 티커의 가중평균매입가 별도 계산
double tickerVwap(List<Trade> buyTrades) {
  final totalCost = buyTrades.fold<double>(0, (s, t) => s + t.price * t.shares);
  final totalShares = buyTrades.fold<double>(0, (s, t) => s + t.shares);
  return totalShares > 0 ? totalCost / totalShares : 0;
}
```

**티커별 평가금:**
```dart
// 각 티커의 shares × currentPrice × exchangeRate
double tickerEvalAmount(double shares, double currentPrice, double exchangeRate) {
  return shares * currentPrice * exchangeRate;
}
```

**합산:** 전체 투자금/평가금/손익은 티커별 합계.

**티커별 매입환율:**
- 각 티커마다 독립적인 평균 매입환율 저장 (Trade.exchangeRate 기반 가중평균)
- 환차손익도 티커별로 개별 계산 후 합산

### 3.9 안정형 멀티 티커 데이터 전략 (C-5)

안정형에서 QQQ, QLD, TQQQ를 동시 보유할 수 있으므로 `Cycle.averagePrice`와 `Cycle.totalShares`의 의미를 명확히 정의한다.

#### Cycle.averagePrice (안정형)
- **안정형에서는 UI에서 사용하지 않음**: 서로 다른 티커(QQQ $450, QLD $72, TQQQ $68)의 가격을 가중평균하는 것은 의미 없음
- Cycle.averagePrice 필드는 기존 매수/매도 시 _recalculateCycleState()에서 계산되나, 안정형 상세 화면에서는 **표시하지 않음**
- **(F-20) _recalculateCycleState()에서 Ladder 안정형(ladderMode == 0)일 때 `cycle.averagePrice = 0`으로 설정** — 서로 다른 티커의 VWAP 혼합을 방지
  ```dart
  // _recalculateCycleState() 내부, VWAP 계산 직후 추가
  // Ladder 안정형: 멀티 티커 VWAP 혼합은 무의미하므로 0으로 고정
  // ⚠ 안정형 averagePrice는 UI에서 사용하지 않음 — buildTickerHoldings()로 티커별 VWAP 사용
  if (cycle.strategyType == StrategyType.ladderCycle && cycle.ladderMode == 0) {
    cycle.averagePrice = 0;
  }
  ```
- **공격형/초공격형은 기존대로** 단일 티커 VWAP으로 표시

#### Cycle.totalShares (안정형)
- **전체 합산 유지**: QQQ 2주 + QLD 14주 + TQQQ 9주 = totalShares 25
- **isPendingCompletion 판단용**: `totalShares == 0`으로 전량 매도 감지 (기존 로직 그대로)
- 안정형에서도 기존 _recalculateCycleState()의 VWAP/totalShares 계산 로직이 동작하되, averagePrice의 결과값이 무의미할 뿐

#### UI는 Trade 기반 groupByTicker 런타임 집계 사용

**파일 배치: `lib/domain/trading/ladder_cycle_service.dart`** — TickerHolding 클래스와 buildTickerHoldings() 함수를 이 파일에 배치한다. 볼륨이 커지면 `lib/domain/trading/ticker_holding.dart`로 분리 가능. (F-5)

```dart
/// 안정형 상세 화면에서 보유 현황 테이블 데이터 생성
/// Trade 목록에서 티커별 실시간 집계
class TickerHolding {
  final String ticker;
  final double shares;       // 매수 합 - 매도 합
  final double vwap;         // 해당 티커 매수 VWAP (USD)
  final double evalAmount;   // shares × currentPrice × exchangeRate
  final double avgExRate;    // 해당 티커 매수 가중평균 환율

  const TickerHolding({
    required this.ticker,
    required this.shares,
    required this.vwap,
    required this.evalAmount,
    required this.avgExRate,
  });

  // 환차손익 = (현재환율 - avgExRate) × shares × currentPrice
  double exchangePnl(double currentPrice, double liveExRate) =>
      (liveExRate - avgExRate) * shares * currentPrice;
}

/// Trade 목록에서 티커별 TickerHolding 생성
List<TickerHolding> buildTickerHoldings(
  List<Trade> trades,
  String cycleTicker,
  Map<String, double> currentPrices,  // {ticker: price}
  double liveExchangeRate,
) {
  final grouped = groupByTicker(trades, cycleTicker);
  return grouped.entries.map((entry) {
    final ticker = entry.key;
    final tickerTrades = entry.value;
    final buys = tickerTrades.where((t) => t.action == TradeAction.buy).toList();
    final sells = tickerTrades.where((t) => t.action == TradeAction.sell).toList();
    final buyShares = buys.fold<double>(0, (s, t) => s + t.shares);
    final sellShares = sells.fold<double>(0, (s, t) => s + t.shares);
    final shares = buyShares - sellShares;
    final vwap = tickerVwap(buys);

    // 티커별 평균 매입환율 (I-6)
    // = 매수 거래의 exchangeRate를 amountKrw 기준 가중평균
    final totalBuyKrw = buys.fold<double>(0, (s, t) => s + t.amountKrw);
    final totalBuyUsd = buys.fold<double>(0, (s, t) => s + t.shares * t.price);
    final avgExRate = totalBuyUsd > 0 ? totalBuyKrw / totalBuyUsd : liveExchangeRate;

    final currentPrice = currentPrices[ticker] ?? 0.0;
    final evalAmount = shares * currentPrice * liveExchangeRate;

    return TickerHolding(
      ticker: ticker,
      shares: shares,
      vwap: vwap,
      evalAmount: evalAmount,
      avgExRate: avgExRate,
    );
  }).where((h) => h.shares > 0).toList();
}
```

**예시 (QQQ 2주 + QLD 14주):**
```
QQQ: 2주 × $452.30 = $904.60, VWAP=$452.30, 평균환율=₩1,350
QLD: 14주 × $72.50 = $1,015.00, VWAP=$72.50, 평균환율=₩1,345
────────────────────────
합계: 16주 (Cycle.totalShares)
평가금(KRW): (2×452.30 + 14×72.50) × 1,350 = ₩2,591,430
```

### 3.10 안정형 환율 계산 경로 (I-6)

**티커별 평균 매입환율:**
```
avgExRate(ticker) = 해당 티커 매수 거래의 amountKrw 합계 / (shares합 × price합)
                  = totalBuyKrw / totalBuyUsd
```

**티커별 환차손익:**
```
exchangePnl(ticker) = (현재환율 - avgExRate(ticker)) × 티커 보유주수 × 티커 현재가(USD)
```

**전체 환차손익:**
```
totalExchangePnl = sum(exchangePnl(ticker) for each ticker with shares > 0)
```

---

## 4. 신호 시스템

### 4.1 매수 가이드 (cycleSignalProvider 확장)

**(C-3) StrategyEngine 인터페이스 시그니처 준수 — named parameter 형식:**

```dart
/// LadderCycleService — StrategyEngine 구현
class LadderCycleService implements StrategyEngine {
  const LadderCycleService();

  @override
  TradeSignal detectSignal({
    required Cycle cycle,
    required double currentPrice,
    required double liveExchangeRate,
  }) {
    if (cycle.athPrice <= 0) return TradeSignal.hold;
    final mdd = calculateMDD(cycle.athPrice, currentPrice);
    // (C-1) 방어적 파싱
    final triggers = parseLadderTriggers(
      cycle.ladderTriggers,
      steps: cycle.ladderSteps,
    );

    int targetStep = 0;
    for (int i = 0; i < triggers.length; i++) {
      if (mdd <= triggers[i]) targetStep = i + 1;
    }

    if (targetStep > cycle.currentStep) {
      return TradeSignal.values.firstWhere(
        (s) => s.name == 'ladderStep$targetStep',
        orElse: () => TradeSignal.hold,
      );
    }
    return TradeSignal.hold;
  }

  @override
  double? calculateAmount({
    required Cycle cycle,
    required TradeSignal signal,
    required double currentPrice,
    required double liveExchangeRate,
  }) {
    if (!signal.name.startsWith('ladderStep')) return null;
    // (C-1) tryParse 사용
    final targetStep = int.tryParse(
      signal.name.replaceAll('ladderStep', ''),
    ) ?? 0;
    if (targetStep <= 0) return null;
    return gapAmount(cycle.seedAmount, cycle.currentStep, targetStep, cycle);
  }
}
```

### 4.2 매도 가이드

매도는 자동 신호 없이 가이드 텍스트만 제공 (Ladder Cycle 정보 카드 안에 통합):
- +50% 시 원금 30% 현금화 고려
- RSI > 80 시 단계적 익절 고려
- 20MA 하향돌파 시 포지션 축소 고려
- 신고점 도달 시 사이클 종료 고려

### 4.3 SignalBadgeConfig 확장 (I-3)

**(I-3) 정적 라벨 사용으로 확정 — Cycle 정보 없이도 표시 가능:**

```dart
// signal_badge_config.dart
ladderStep1 → SignalBadgeConfig(label: "1단계", color: amber500)
ladderStep2 → SignalBadgeConfig(label: "2단계", color: amber600)
ladderStep3 → SignalBadgeConfig(label: "3단계", color: orange500)
ladderStep4 → SignalBadgeConfig(label: "4단계", color: orange600)
ladderStep5 → SignalBadgeConfig(label: "5단계", color: red400)
ladderStep6 → SignalBadgeConfig(label: "6단계", color: red600)
```

> **참고:** 구체적인 트리거값(예: "-10%", "-28%")은 SignalBadge에 표시하지 않음. Cycle 정보가 없는 맥락(거래내역 화면 등)에서도 뱃지가 정상 렌더링되어야 하기 때문. 트리거값은 **상세 화면의 매수 가이드 카드**와 **진행도 바**에서 별도 표시.

---

## 5. Provider 변경

### 5.1 신규 Provider

```dart
final ladderCyclesProvider = Provider<List<Cycle>>((ref) {
  return ref.watch(activeCyclesProvider)
      .where((c) => c.strategyType == StrategyType.ladderCycle)
      .toList();
});
```

### 5.2 기존 Provider 수정 — 상세 시그니처

#### 5.2.1 CycleListNotifier.addCycle() 확장

Ladder 파라미터는 모두 **선택적 + 기본값** → 기존 Smart/Steady 호출부 무영향:

```dart
Future<Cycle> addCycle({
  // 기존 필수 파라미터 (변경 없음)
  required String ticker,
  required String name,
  required double seedAmount,
  required double exchangeRate,
  required StrategyType strategyType,
  String nickname = '',
  // ... 기존 Smart/Steady 선택적 파라미터들 (변경 없음) ...

  // Ladder 파라미터 (신규, 모두 선택적)
  double athPrice = 0.0,
  int ladderMode = 1,
  int ladderSteps = 6,
  String ladderWeights = '1,1,2,3,4,5',
  String ladderTriggers = '-10,-19,-28,-37,-46,-55',
}) async {
  // (M-1) weights 합계 0 방어
  final parsedWeights = parseLadderWeights(ladderWeights, steps: ladderSteps);
  final totalWeight = parsedWeights.fold<int>(0, (s, w) => s + w);
  final safeWeights = totalWeight == 0
      ? _defaultWeights(ladderSteps).join(',')
      : ladderWeights;

  final cycle = Cycle(
    // ... 기존 파라미터 그대로 ...
    // Ladder 필드는 생성자 또는 생성 후 대입
  );
  // Ladder 필드 설정
  cycle.athPrice = athPrice;
  cycle.ladderMode = ladderMode;
  cycle.currentStep = 0;
  cycle.ladderSteps = ladderSteps;
  cycle.ladderWeights = safeWeights;
  cycle.ladderTriggers = ladderTriggers;

  await _repository.save(cycle);
  state = [...state, cycle];

  // (C-6) WebSocket 티커 등록 — 기준 티커만 (안정형: QQQ)
  // 안정형의 QLD/TQQQ는 상세 화면 진입 시 lazy 구독
  try {
    _ref.read(stockPriceProvider.notifier).loadSymbols([ticker]);
  } catch (_) {}

  return cycle;
}
```

#### 5.2.2 TradeListNotifier.recordBuy() 확장

`ticker`는 **String? (nullable)** → null이면 기존처럼 cycle.ticker 사용:

```dart
Future<Trade> recordBuy({
  // 기존 파라미터 (변경 없음)
  required String cycleId,
  required TradeSignal signal,
  required double price,
  required double amountKrw,
  required double exchangeRate,
  String? memo,
  String? groupId,
  DateTime? tradedAt,
  double extraFundingAmount = 0,

  // Ladder 파라미터 (신규, 선택적)
  String? ticker,  // null = cycle.ticker 사용
}) async {
  // Trade 생성 시 ticker 전달
  final trade = Trade(
    ...
    ticker: ticker,  // Trade.ticker에 저장
  );
}
```

recordSell()에도 동일하게 `String? ticker` 추가.

#### 5.2.3 _recalculateCycleState() — currentStep 갱신 및 안정형 averagePrice 처리

```dart
// _recalculateCycleState() 내부, 기존 계산 로직 끝에 추가
// Ladder Cycle: 거래 내역에서 최대 진행 단계 재계산
if (cycle.strategyType == StrategyType.ladderCycle) {
  int maxStep = 0;
  for (final trade in trades) {
    if (trade.action == TradeAction.buy &&
        trade.signal.name.startsWith('ladderStep')) {
      final step = int.tryParse(
        trade.signal.name.replaceAll('ladderStep', '')
      ) ?? 0;
      if (step > maxStep) maxStep = step;
    }
  }
  cycle.currentStep = maxStep;

  // (F-20) Ladder 안정형: 멀티 티커 VWAP 혼합은 무의미 → 0으로 고정
  // ⚠ 안정형 averagePrice는 UI에서 사용하지 않음 — buildTickerHoldings()로 티커별 VWAP 사용
  if (cycle.ladderMode == 0) {
    cycle.averagePrice = 0;
  }
}
```

**삭제 시에도 안전:** 거래 삭제 후 _recalculateCycleState() 호출 → max 단계 재계산 → currentStep 자동 조정.

#### 5.2.4 cycleSignalProvider 분기 추가

```dart
// 기존: alphaCycleV3 → AlphaCycleService, else → Steady/InfiniteBuy
// 변경: ladderCycle 분기 추가 (alphaCycleV3 다음에)
final StrategyEngine service;
if (cycle.strategyType == StrategyType.alphaCycleV3) {
  service = const AlphaCycleService();
} else if (cycle.strategyType == StrategyType.ladderCycle) {
  service = const LadderCycleService();  // 신규
} else if (cycle.steadyVersion != SteadyVersion.v1) {
  service = const SteadyService();
} else {
  service = const InfiniteBuyService();
}
```

cycleSignalAmountProvider도 동일 분기.

### 5.3 WebSocket 멀티 티커 구독 (C-6)

#### 5.3.1 addCycle() 시 — 기준 티커만 등록 (기존 패턴)

안정형에서 기준 티커(QQQ)만 WebSocket 구독. QLD/TQQQ는 초기 생성 시 아직 매수하지 않았으므로 구독 불필요.

#### 5.3.2 상세 화면 진입 시 — Trade에서 사용된 티커 lazy 구독

```dart
// cycle_detail_screen.dart — initState() 또는 build() 내
// 안정형: Trade에서 사용된 모든 티커를 추출하여 lazy 구독
if (cycle.strategyType == StrategyType.ladderCycle && cycle.ladderMode == 0) {
  final trades = ref.read(tradesByCycleProvider(cycle.id));
  final usedTickers = trades
      .map((t) => t.ticker ?? cycle.ticker)
      .toSet()
      .toList();
  // 기준 티커는 이미 구독 중이므로, 추가 티커만 구독
  final additionalTickers = usedTickers.where((t) => t != cycle.ticker).toList();
  if (additionalTickers.isNotEmpty) {
    ref.read(stockPriceProvider.notifier).loadSymbols(additionalTickers);
  }
}
```

#### 5.3.3 매수 가이드에서 추천 티커 현재가 조회

```dart
// ladder_buy_guide_card.dart
// 안정형 매수 가이드: 추천 3개 티커의 현재가를 stockQuoteProvider에서 조회
final recommended = recommendedTickers(cycle.ladderMode, nextStep);
for (final ticker in recommended) {
  // stockQuoteProvider는 이미 구독된 티커면 캐시 반환,
  // 미구독이면 REST 호출 후 WS 등록
  final quote = ref.watch(stockQuoteProvider(ticker));
  // quote.currentPrice로 매수 수량 계산
}
```

### 5.4 포트폴리오 집계

#### 5.4.1 UnifiedPortfolioSummary 필드 추가

```dart
// 기존 Smart/Steady 필드와 동일한 패턴
final double ladderCycleValue;
final double ladderCycleInvested;
final double ladderCycleProfit;
final int ladderCycleCount;
final double ladderCycleActualInvested;
final double ladderCycleEvalAmount;
```

#### 5.4.2 기존 합산 getter 확장

```dart
// 기존: cycleValue = smart + steady
// 변경: cycleValue = smart + steady + ladder
double get cycleValue => smartCycleValue + steadyCycleValue + ladderCycleValue;
double get cycleInvested => smartCycleInvested + steadyCycleInvested + ladderCycleInvested;
double get cycleProfit => smartCycleProfit + steadyCycleProfit + ladderCycleProfit;
int get cycleCount => smartCycleCount + steadyCycleCount + ladderCycleCount;

// totalValue, totalInvested, totalProfit도 자동으로 Ladder 포함 (cycleValue 사용)
```

#### 5.4.3 unifiedPortfolioProvider 루프 분기

```dart
for (final cycle in activeCycles) {
  ...
  if (cycle.strategyType == StrategyType.alphaCycleV3) {
    smartValue += cycleValue;
    smartInvested += cycleInvested;
    ...
  } else if (cycle.strategyType == StrategyType.ladderCycle) {
    ladderValue += cycleValue;      // 신규
    ladderInvested += cycleInvested; // 신규
    ...
  } else {
    steadyValue += cycleValue;
    steadyInvested += cycleInvested;
    ...
  }
}
```

#### 5.4.4 안정형 평가금 계산 경로 (F-15)

안정형은 멀티 티커를 보유하므로 기존 `TradingMath.evaluatedAmount()` (단일 티커 기반)를 사용할 수 없다. 전략별 분기를 추가한다:

```dart
// unifiedPortfolioProvider 내 평가금 계산 분기
for (final cycle in activeCycles) {
  double evalAmount;
  double actualInvested;

  if (cycle.strategyType == StrategyType.ladderCycle && cycle.ladderMode == 0) {
    // (F-15) 안정형: Trade 기반 buildTickerHoldings()로 티커별 평가금 합산
    final trades = ref.read(tradesByCycleProvider(cycle.id));
    final currentPrices = <String, double>{};
    // 안정형 사용 티커: QQQ, QLD, TQQQ — 각각 현재가 조회
    final usedTickers = trades.map((t) => t.ticker ?? cycle.ticker).toSet();
    for (final ticker in usedTickers) {
      final quote = ref.read(stockQuoteProvider(ticker));
      currentPrices[ticker] = quote.currentPrice;
    }
    final holdings = buildTickerHoldings(trades, cycle.ticker, currentPrices, liveExRate);
    evalAmount = holdings.fold<double>(0, (sum, h) => sum + h.evalAmount);
    actualInvested = cycle.seedAmount - cycle.remainingCash;
  } else {
    // 공격형/초공격형 및 기존 Smart/Steady: 기존 TradingMath.evaluatedAmount() 그대로
    evalAmount = TradingMath.evaluatedAmount(
      shares: cycle.totalShares,
      currentPrice: prices[cycle.ticker]?.currentPrice ?? 0,
      exchangeRate: liveExRate,
    );
    actualInvested = cycle.seedAmount - cycle.remainingCash;
  }

  // ... cycleValue, cycleInvested 계산은 기존과 동일 ...
}
```

**성능 고려:** 안정형만 Trade를 읽으므로 대부분의 사이클(Smart/Steady/공격형/초공격형)에 영향 없음. 안정형 사이클 수가 소수일 것이므로 성능 문제 없음.

---

## 6. UI 설계

### 6.1 My 탭 — 4탭 구조

```
[ Smart (N) | Steady (N) | Ladder (N) | 보유 (N) ]
```

**TabController 변경:** `length: 3 → 4`

**탭 index 매핑 (기존 → 변경):**

| index | 기존 (3탭) | 변경 (4탭) |
|-------|----------|----------|
| 0 | Smart | Smart |
| 1 | Steady | Steady |
| 2 | 보유 | **Ladder (신규)** |
| 3 | — | **보유 (이동)** |

**FAB 라우팅 분기 변경:**
```dart
// 기존: index==2 → 보유, index==1 → Steady, else → Smart
// 변경:
final isHoldingTab = _tabController.index == 3;  // 2 → 3
final isLadderTab = _tabController.index == 2;   // 신규
final isSteadyTab = _tabController.index == 1;   // 변경 없음

if (isHoldingTab) '/stocks/search?forHolding=true'
else if (isLadderTab) '/stocks/setup?strategy=ladderCycle'  // 신규
else if (isSteadyTab) '/stocks/setup?strategy=infiniteBuy'
else '/stocks/setup'  // Smart
```

**탭 색상:** `_getTabColors()`에 Ladder 색상(amber) 추가 → 4개 색상 반환

**StrategyBadge 확장:**
```dart
class StrategyBadge extends StatelessWidget {
  final StrategyType strategyType;
  final SteadyVersion? steadyVersion;
  final int? ladderMode;  // 신규 파라미터

  // _getConfig() switch에 ladderCycle 케이스 추가:
  case StrategyType.ladderCycle:
    final modeLabel = switch (ladderMode) {
      0 => 'Ladder 안정형',
      1 => 'Ladder 공격형',
      2 => 'Ladder 초공격형',
      _ => 'Ladder',
    };
    return _StrategyConfig(
      label: modeLabel,
      icon: Icons.stacked_bar_chart,
      color: isDark ? AppColors.amber400 : AppColors.amber500,
    );
}
```

- Ladder 탭: `ladderCyclesProvider`, 색상 amber
- FAB: "사이클 생성" → `/stocks/setup?strategy=ladderCycle`

### 6.2 도넛 차트 Ladder 세그먼트 (I-5)

**portfolio_allocation_chart.dart** — 기존 3분할 → 4분할:

```dart
// 기존 세그먼트: Smart(blue) + Steady(green) + 보유(purple)
// 변경: Smart(blue) + Steady(green) + Ladder(amber) + 보유(purple)

// 신규 상태 변수
Color? _ladderCycleColor;
static const Color _defaultLadderColor = Color(0xFFFBBF24); // amber/yellow

Color _getLadderColor() => _ladderCycleColor ?? _defaultLadderColor;

// hasData 체크 확장
final hasData = summary.smartCycleCount > 0 ||
    summary.steadyCycleCount > 0 ||
    summary.ladderCycleCount > 0 ||  // (I-5) 추가
    summary.holdingCount > 0;

// 도넛 차트 세그먼트 (4개)
// index 매핑:
// 0 = Smart, 1 = Steady, 2 = Ladder(신규), 3 = 보유
// _editingIndex도 0~3으로 확장

// Settings 영속화
ref.read(settingsProvider.notifier).updateChartColors(
  alphaColor: (_smartCycleColor?.value) ?? 0,
  steadyColor: (_steadyCycleColor?.value) ?? 0,
  ladderColor: (_ladderCycleColor?.value) ?? 0,  // (I-5) 신규
  holdingColor: (_holdingColor?.value) ?? 0,
);

// 범례 항목 4개
// Smart Cycle | Steady Cycle | Ladder Cycle | 일반 보유
```

> **Settings 모델 변경 (F-7):** `ladderCycleChartColor` HiveField 22 추가 — 2.9절 참조.

### 6.3 사이클 생성 (cycle_setup_screen)

```
┌──────────────────────────────────────────┐
│           새 사이클                    ✕  │
├══════════════════════════════════════════╡
│                                          │
│ 전략 선택                                │
│ [🛡 Smart | ♾ Steady | ⧈ Ladder]        │
│                                          │
│ ┌──────────────────────────────────────┐ │
│ │ ⧈  MDD 기반 가속 분할매수형       [?] │ │
│ │ ATH 대비 하락률에 따라                │ │
│ │ 6단계 가속 비중(1-1-2-3-4-5)으로     │ │
│ │ 하락할수록 공격적으로 매집합니다.      │ │
│ └──────────────────────────────────────┘ │
│                                          │
│ 매수 모드                                │
│ [ 안정형 | 공격형 | 초공격형 ]             │
│                                          │
│ 종목 선택                                │
│ ┌──────────────────────────────────────┐ │
│ │ QQQ  Invesco QQQ Trust           >   │ │
│ └──────────────────────────────────────┘ │
│ ※ MDD 기준 지수 — 안정형: QQQ/QLD/TQQQ  │
│   공격형: TQQQ 매수 / 초공격형: SOXL 매수│
│                                          │
│ ATH 가격 (USD)                           │
│ ┌──────────────────────────────────────┐ │
│ │ $ 542.85                             │ │
│ └──────────────────────────────────────┘ │
│                                          │
│ 별명 (선택)                              │
│ ┌──────────────────────────────────────┐ │
│ │ 예: 나스닥 하락 대비...              │ │
│ └──────────────────────────────────────┘ │
│                                          │
│ 시드 금액                                │
│ ┌──────────────────────────────────────┐ │
│ │ ₩ 10,000,000          1천만원       │ │
│ └──────────────────────────────────────┘ │
│                                          │
│ ┌──────────────────────────────────────┐ │
│ │ 자동 계산 — 6단계 투입 계획           │ │
│ │                                      │ │
│ │ 1단계 (-10%)    625,000원   (6.25%)  │ │
│ │ 2단계 (-19%)    625,000원   (6.25%)  │ │
│ │ 3단계 (-28%)  1,250,000원  (12.50%)  │ │
│ │ 4단계 (-37%)  1,875,000원  (18.75%)  │ │
│ │ 5단계 (-46%)  2,500,000원  (25.00%)  │ │
│ │ 6단계 (-55%)  3,125,000원  (31.25%)  │ │
│ └──────────────────────────────────────┘ │
│                                          │
│ ▶ 고급 설정                              │
│                                          │
│  ┌────────────────────────────────────┐  │
│  │         사이클 시작                 │  │
│  └────────────────────────────────────┘  │
│                                          │
└──────────────────────────────────────────┘
```

#### 6.3.1 고급 설정 (ExpansionTile 펼친 상태)

```
┌──────────────────────────────────────────┐
│ ▼ 고급 설정                              │
│                                          │
│ 분할 단계                                │
│ [ 3 | 4 | 5 | 6✓ ]                      │
│                                          │
│ 비율 프리셋                              │
│ [ 균등형 | 가속형✓ | 피보나치형 | 커스텀 ]  │
│                                          │
│ ┌──────────────────────────────────────┐ │
│ │ 투입 계획 미리보기                     │ │
│ │                                      │ │
│ │ 1단계 (-10%)    625,000원   (6.25%)  │ │
│ │ 2단계 (-19%)    625,000원   (6.25%)  │ │
│ │ 3단계 (-28%)  1,250,000원  (12.50%)  │ │
│ │ 4단계 (-37%)  1,875,000원  (18.75%)  │ │
│ │ 5단계 (-46%)  2,500,000원  (25.00%)  │ │
│ │ 6단계 (-55%)  3,125,000원  (31.25%)  │ │
│ └──────────────────────────────────────┘ │
│                                          │
│ ── 커스텀 선택 시 슬라이더 표시 ──        │
│ 1단계  ██████░░░░░░░░░░░░░░░░  10%     │
│ 2단계  ██████░░░░░░░░░░░░░░░░  10%     │
│ 3단계  ████████░░░░░░░░░░░░░░  15%     │
│ 4단계  ██████████░░░░░░░░░░░░  20%     │
│ 5단계  ████████████░░░░░░░░░░  22%     │
│ 6단계  ██████████████░░░░░░░░  23%     │
│                          합계: 100%     │
│                                          │
│ ⚠ 합계가 100%가 아닙니다 (현재 95%)      │
└──────────────────────────────────────────┘
```

**고급 설정 동작 규칙:**

1. **분할 단계 선택** (`SegmentedButton [3 | 4 | 5 | 6(기본)]`):
   - 선택 변경 시 MDD 트리거와 비율 프리셋 모두 자동 업데이트
   - 기본 투입 계획 미리보기도 즉시 반영

2. **비율 프리셋 선택** (`SegmentedButton [균등형 | 가속형(기본) | 피보나치형 | 커스텀]`):
   - 프리셋 선택 시 투입 계획 미리보기 즉시 업데이트
   - 커스텀 선택 시 슬라이더 UI 표시

3. **커스텀 비율**:
   - 각 단계별 Slider (0~50% 범위)
   - 합계 100% 실시간 검증
   - 합계 != 100%이면 경고 메시지 + 사이클 시작 버튼 비활성화

4. **저장 시 Cycle 모델 반영**:
   - `ladderSteps`: 선택된 단계 수
   - `ladderWeights`: 비율을 비중으로 변환하여 쉼표 구분 문자열 저장
   - `ladderTriggers`: 선택된 단계 수에 해당하는 MDD 트리거 쉼표 구분 문자열 저장

### 6.4 사이클 카드 (_ActiveCycleCard)

기존 패턴과 동일 구조:
```
┌──────────────────────────────────────┐
│ [TL] TQQQ  닉네임        [3단계 -28%] │
│      ProShares UltraPro              │
│                                      │
│  ₩2,450,000  +₩125,000 (+5.4%)      │
│                                      │
│  설정시드       잔여현금    진행 단계    │
│  10,000,000원  7,500,000원  3/6단계   │
└──────────────────────────────────────┘
```

### 6.5 사이클 상세 — 안정형 (멀티 티커)

```
┌──────────────────────────────────────────┐
│ ◀  TQQQ  닉네임        [⧈ Ladder 안정형] [⋮] │
│    ProShares UltraPro QQQ                │
├══════════════════════════════════════════╡
│                                          │
│ ┌──────────────────────────────────────┐ │
│ │ ▓▓▓▓▓▓ PnL 그라데이션 카드 ▓▓▓▓▓▓▓ │ │
│ │                                      │ │
│ │ 기준 시세 (QQQ)          ATH $542.85 │ │
│ │ 현재 시세       $452.30 (MDD -16.7%) │ │
│ │                       환율: ₩1,350   │ │
│ │ ─────────────────────────────────── │ │
│ │ 외화손익   [+1,234 USD]      +10.0%  │ │
│ │ 원화손익   [+1,665,900원]    +10.0%  │ │
│ │ 환차손익 [+1,715,900(+50,000)원] +10.8% │
│ │                                      │ │
│ │ ※ QQQ+QLD+TQQQ 보유 합산            │ │
│ └──────────────────────────────────────┘ │
│                                          │
│  -10%  -19%  -28%  -37%  -46%  -55%    │
│   ●━━━━●━━━━●━━━━○━━━━○━━━━○          │
│   ✓     ✓    ▶현재          3 / 6 단계  │
│                                          │
│ ┌──────────────────────────────────────┐ │
│ │ 📊 매수 가이드                   [?]  │ │
│ │                                      │ │
│ │ 3단계 매수 (MDD: -28.5%)             │ │
│ │                                      │ │
│ │ [QLD✓]  [QQQ]  [TQQQ]              │ │
│ │                                      │ │
│ │ 매수 주문              ₩1,250,000    │ │
│ │ • QLD: $72.50 × 12주 (12.7)   [📋]  │ │
│ └──────────────────────────────────────┘ │
│                                          │
│ ┌──────────────────────────────────────┐ │
│ │ 보유 현황                             │ │
│ │                                      │ │
│ │ 종목   현재가   수량   손익            │ │
│ │ ─────────────────────────────────── │ │
│ │ QQQ   $452.30  1주   +₩25K  (+4%)  │ │
│ │ QLD   $72.50   12주  +₩100K (+8%)  │ │
│ │ TQQQ  $68.40   9주   +₩125K (+20%) │ │
│ │ ─────────────────────────────────── │ │
│ │ 합계           22주  +₩250K (+10%) │ │
│ └──────────────────────────────────────┘ │
│                                          │
│ ┌──────────────────────────────────────┐ │
│ │ 평균 매입환율    ₩1,351.67 / $1 [✏️] │ │
│ │                                      │ │
│ │  ── ✏️ 클릭 시 확장 ──              │ │
│ │  QQQ   ₩1,350.00 / $1         [✏️]  │ │
│ │  QLD   ₩1,345.00 / $1         [✏️]  │ │
│ │  TQQQ  ₩1,360.00 / $1         [✏️]  │ │
│ │             [ 저장 ]                  │ │
│ │  → 저장 즉시 각 티커 환차 재계산       │ │
│ └──────────────────────────────────────┘ │
│                                          │
│ ┌──────────────────────────────────────┐ │
│ │ ── Ladder Cycle ──                   │ │
│ │ 설정 시드             ₩10,000,000    │ │
│ │ 잔여현금              ₩7,500,000    │ │
│ │ 총 매입금액           ₩2,500,000    │ │
│ │ 총 평가금             ₩2,750,000    │ │
│ │                                      │ │
│ │ ── 매도 가이드 ──                    │ │
│ │ • +50% 시 원금 30% 현금화 고려       │ │
│ │ • RSI > 80 시 단계적 익절 고려       │ │
│ │ • 20MA 하향돌파 시 포지션 축소 고려   │ │
│ │ • 신고점 도달 시 사이클 종료 고려     │ │
│ └──────────────────────────────────────┘ │
│                                          │
│ 거래 내역 (3건)                           │
│                                          │
│ ┌─ 3회차 · 2026.03.28 ──────────────┐   │
│ │                                    │   │
│ │ [매수] QLD 매수  $72.50 × 12주 $870.00│
│ │                            ₩1,250,000│
│ │                                    │   │
│ └────────────────────────────────────┘   │
│                                          │
│ ┌─ 2회차 · 2026.03.20 ──────────────┐   │
│ │                                    │   │
│ │ [매수] QQQ 매수  $440.50 × 1주 $440.50│
│ │                              ₩625,000│
│ │                                    │   │
│ └────────────────────────────────────┘   │
│                                          │
│ ┌─ 1회차 · 2026.03.15 ──────────────┐   │
│ │                                    │   │
│ │ [매수] QQQ 매수  $452.30 × 1주 $452.30│
│ │                              ₩625,000│
│ │                                    │   │
│ └────────────────────────────────────┘   │
│                                          │
│  ┌────────────────────────────────┐      │
│  │   사이클 완료               │          │
│  └────────────────────────────────┘      │
│                                          │
│              [FAB: 거래 기록]             │
└──────────────────────────────────────────┘
```

**⋮ 메뉴 항목 (F-13):** Ladder 사이클일 때 PopupMenu 항목:
- 시드 수정 (`editSeed`)
- ATH 수정 (`editAth`) — Ladder 전용
- 사이클 완료 (`complete`)
- 삭제 (`delete`)

> **"익절 처리" 항목 없음 (F-13):** Ladder는 자동 재시작 개념이 없으며, 매도는 FAB를 통해 수동으로 기록한다. Smart Cycle의 `completeTakeProfit()` (전량 매도 + 새 사이클 자동 생성)은 Ladder에 적용되지 않는다.

### 6.6 사이클 상세 — 공격형/초공격형 (단일 티커)

```
┌──────────────────────────────────────────┐
│ ◀  TQQQ  닉네임        [⧈ Ladder 공격형] [⋮] │
│    ProShares UltraPro QQQ                │
├══════════════════════════════════════════╡
│                                          │
│ ┌──────────────────────────────────────┐ │
│ │ ▓▓▓▓▓▓ PnL 그라데이션 카드 ▓▓▓▓▓▓▓ │ │
│ │                                      │ │
│ │ 기준 시세 (QQQ)          ATH $542.85 │ │
│ │ 현재 시세       $452.30 (MDD -16.7%) │ │
│ │                       환율: ₩1,350   │ │
│ │ ─────────────────────────────────── │ │
│ │                                      │ │
│ │ TQQQ 현재 시세                $68.40 │ │
│ │ ─────────────────────────────────── │ │
│ │ 외화손익   [+500 USD]        +8.5%   │ │
│ │ 원화손익   [+675,000원]      +8.5%   │ │
│ │ 환차손익 [+700,000(+25,000)원] +8.9% │ │
│ └──────────────────────────────────────┘ │
│                                          │
│  -10%  -19%  -28%  -37%  -46%  -55%    │
│   ●━━━━●━━━━●━━━━○━━━━○━━━━○          │
│   ✓     ✓    ▶현재          3 / 6 단계  │
│                                          │
│ ┌──────────────────────────────────────┐ │
│ │ 📊 매수 가이드                   [?]  │ │
│ │                                      │ │
│ │ 3단계 매수 (MDD: -28.5%)             │ │
│ │                                      │ │
│ │ 매수 주문              ₩1,250,000    │ │
│ │ • TQQQ: $68.40 × 13주 (13.5)  [📋]  │ │
│ └──────────────────────────────────────┘ │
│                                          │
│ ┌──────────────────────────────────────┐ │
│ │ ── 보유 정보 ──                      │ │
│ │ 보유 수량              45주          │ │
│ │ 매입가 (VWAP)          $63.20       │ │
│ │ 실제 투자금            ₩2,500,000   │ │
│ │ 평가금 (원)     [환차] ₩4,155,000   │ │
│ │ 평균 매입환율   ₩1,350 / $1   [✏️]  │ │
│ │                                      │ │
│ │ ── Ladder Cycle ──                   │ │
│ │ 설정 시드              ₩10,000,000   │ │
│ │ 잔여현금               ₩7,500,000   │ │
│ │ 총 매입금액            ₩2,500,000   │ │
│ │ 총 평가금              ₩4,155,000   │ │
│ │                                      │ │
│ │ ── 매도 가이드 ──                    │ │
│ │ • +50% 시 원금 30% 현금화 고려       │ │
│ │ • RSI > 80 시 단계적 익절 고려       │ │
│ │ • 20MA 하향돌파 시 포지션 축소 고려   │ │
│ │ • 신고점 도달 시 사이클 종료 고려     │ │
│ └──────────────────────────────────────┘ │
│                                          │
│ 거래 내역 (3건)                           │
│                                          │
│ ┌─ 3회차 · 2026.03.28 ──────────────┐   │
│ │                                    │   │
│ │ [매수] TQQQ 매수 $58.00 × 16주 $928.00│
│ │                            ₩1,250,000│
│ │                                    │   │
│ └────────────────────────────────────┘   │
│                                          │
│ ┌─ 2회차 · 2026.03.20 ──────────────┐   │
│ │                                    │   │
│ │ [매수] TQQQ 매수 $60.50 × 7주 $423.50│
│ │                              ₩625,000│
│ │                                    │   │
│ └────────────────────────────────────┘   │
│                                          │
│ ┌─ 1회차 · 2026.03.15 ──────────────┐   │
│ │                                    │   │
│ │ [매수] TQQQ 매수 $65.00 × 7주 $455.00│
│ │                              ₩625,000│
│ │                                    │   │
│ └────────────────────────────────────┘   │
│                                          │
│  ┌────────────────────────────────┐      │
│  │   사이클 완료               │          │
│  └────────────────────────────────┘      │
│                                          │
│              [FAB: 거래 기록]             │
└──────────────────────────────────────────┘
```

**공격형과 안정형 차이:**
- PnL 카드: 공격형은 기준 시세(QQQ) + 매수 티커(TQQQ) 현재가 두 줄 표시
- 보유 정보: 공격형은 기존 CycleInfoCard 패턴 (단일 티커), 안정형은 보유 현황 테이블
- 매입환율: 공격형은 기존 패턴 (한 줄), 안정형은 편집 클릭 시 티커별 확장

**⋮ 메뉴 (공격형/초공격형도 동일 — F-13):** 시드 수정 / ATH 수정 / 사이클 완료 / 삭제 ("익절 처리" 없음)

### 6.7 거래 기록 시트 (FAB → LadderTradeRecordSheet)

**별도 파일 신규 생성 (F-3):** `ladder_trade_record_sheet.dart`로 신규 파일 생성. 기존 `CycleTradeRecordSheet`와 구조는 유사하나 Ladder 전용 로직(종목 선택, 단계 신호, 추천 가이드)이 충분히 달라 별도 파일로 분리한다.

```
┌─────────────────────────────────────────────────────┐
│ [AppBar]                                            │
│ TQQQ 거래 기록                                      │
│ $68.40  +3.5%                                       │
├─────────────────────────────────────────────────────┤
│                                                     │
│ 1. [거래일] (인라인)                                │
│    거래일 ─────────────────── [📅 2026.03.30 (일)]  │
│                                                     │
│ 2. [매수/매도 토글]                                 │
│    [매수 (선택)] │ [매도]                           │
│                                                     │
│ 3. [신호 선택] (접이식 — 매수 시)                   │
│    신호: [3단계] ──────────────────────── [변경]    │
│    (펼치면: 칩 목록)                                │
│    [1단계] [2단계] [3단계✓] [4단계] [5단계] [6단계] [수동] │
│                                                     │
│ 4. [종목 선택] (안정형만, 매수 시)                  │
│    종목 선택                                        │
│    [QQQ $452.30]  [QLD✓ $72.50]  [TQQQ $68.40]   │
│                                                     │
│ 5. [매수 추천 가이드] (매수 시)                     │
│    💡 3단계 매수 추천                               │
│    매수금액: ₩1,250,000                             │
│    추천 수량: 12주 ≈ ₩1,250,000  [적용]            │
│                                                     │
│ 6. [단가/수량 입력]                                 │
│    단가 (USD) ─────── [$ 72.50]                     │
│    수량 (주)  보유: 12주  [─ 12 +]                  │
│                                                     │
│ 7. [거래 금액 + 잔여현금]                           │
│    거래 금액                                        │
│    ₩1,174,500                                      │
│    (환율: ₩1,350/$)                                │
│    ───────────────────────────────                 │
│    잔여현금: ₩7,500,000                             │
│                                                     │
│ 8. [메모]                                           │
│    [메모 입력...]                                   │
│                                                     │
│ 9. [저장 버튼]                                      │
│    [매수 기록 저장]                                  │
│                                                     │
│ ── 매도 탭 선택 시 ──                               │
│                                                     │
│ 3. [신호 선택] (매도 시)                            │
│    [수동]                                           │
│                                                     │
│ 4. [종목 선택] (안정형만, 매도 시)                  │
│    종목 선택 — 보유 종목만 표시                      │
│    [QQQ 1주]  [QLD✓ 12주]                          │
│                                                     │
│ 5. [단가/수량 입력]                                 │
│    단가 (USD) ─────── [$ 80.00]                     │
│    수량 (주)  보유: 12주  [─ 5 +]                   │
│                                                     │
│ 9. [매도 기록 저장]                                  │
└─────────────────────────────────────────────────────┘
```

**기존 CycleTradeRecordSheet와의 차이:**
- 종목 선택 추가 (안정형만): 3개 뱃지 중 선택, 현재가 표시
- 신호: ladderStep1~6 + manual (Smart의 initial/weightedBuy 대신)
- 매도 시 종목 선택: 보유 중인 티커만 표시 (수량 함께)
- 추천 가이드: 단계별 금액 + 추천 수량

**공격형/초공격형:** 종목 선택 섹션이 숨겨짐 (단일 티커니까). 나머지 동일.

**onSubmit 콜백:**
```dart
onSubmit({
  required bool isBuy,
  required TradeSignal signal,
  required double price,
  required double shares,
  required double exchangeRate,
  required DateTime date,
  String? memo,
  String? ticker,  // 안정형: 선택한 티커 (QQQ/QLD/TQQQ)
})
```

#### 6.7.1 거래 수정 모드 (editingTrade)

거래 카드의 ... → "수정" 탭 시 동일한 LadderTradeRecordSheet가 편집 모드로 열림.
기존 CycleTradeRecordSheet의 editingTrade 패턴 재사용.

```
┌─────────────────────────────────────────────────────┐
│ [AppBar]                                            │
│ TQQQ 매수 기록 수정                                  │
├─────────────────────────────────────────────────────┤
│                                                     │
│ 1. [거래일]                                         │
│    거래일 ─────────────────── [📅 2026.03.28 (토)]  │
│                                                     │
│ 2. [매수/매도 토글] (비활성 — 수정 시 변경 불가)    │
│    [매수 (선택·비활성)] │ [매도]                     │
│                                                     │
│ 3. [신호 선택]                                      │
│    신호: [3단계] ──────────────────────── [변경]    │
│                                                     │
│ 4. [종목 선택] (안정형만 — 기존 티커 프리필)        │
│    종목 선택                                        │
│    [QQQ]  [QLD✓]  [TQQQ]                          │
│    ※ 기존 거래의 Trade.ticker로 자동 선택           │
│                                                     │
│ 5. [단가/수량 입력] (기존값 프리필)                  │
│    단가 (USD) ─────── [$ 72.50]  ← 기존값           │
│    수량 (주)  보유: 12주  [─ 12 +]  ← 기존값        │
│                                                     │
│ 6. [거래 금액 + 잔여현금]                           │
│    거래 금액                                        │
│    ₩1,174,500                                      │
│    (환율: ₩1,350/$)                                │
│    ───────────────────────────────                 │
│    잔여현금: ₩7,500,000                             │
│                                                     │
│ 7. [메모] (기존값 프리필)                           │
│    [기존 메모 내용...]                              │
│                                                     │
│ 8. [수정 버튼]                                      │
│    [수정]                                           │
│    (단가=0 또는 수량=0이면 비활성)                   │
└─────────────────────────────────────────────────────┘
```

**수정 모드 동작 규칙:**

1. **프리필**: `editingTrade`의 값으로 모든 필드 자동 채움
   - `_isBuy` = editingTrade.action == TradeAction.buy
   - `_selectedSignal` = editingTrade.signal
   - `_selectedDate` = editingTrade.tradedAt
   - `_priceController` = editingTrade.price
   - `_sharesController` = editingTrade.shares
   - `_memoController` = editingTrade.memo
   - `_selectedTicker` = editingTrade.ticker (안정형)

2. **비활성 요소**:
   - 매수/매도 토글 (opacity 0.6, 변경 불가)
   - 현재가 표시 숨김
   - 매수 추천 가이드 숨김

3. **변경 가능 요소**:
   - 신호 (단계 변경 가능)
   - 종목 (안정형 — 다른 티커로 변경 가능)
   - 단가, 수량, 날짜, 메모

4. **저장**: 기존 Trade 객체를 업데이트 (새 Trade 생성 아님)
   - Trade.ticker도 함께 업데이트
   - `_recalculateCycleState()` 호출로 사이클 상태 재계산

#### 6.7.2 거래 삭제

거래 카드의 ... → "삭제" 탭 시:
- 확인 다이얼로그 표시
- 삭제 후 `_recalculateCycleState()` 호출
- currentStep도 재계산 (삭제로 인해 단계가 줄어들 수 있음)

### 6.8 cycle_detail_screen 전략별 body 위젯 분리 (F-2)

현재 `cycle_detail_screen.dart`는 **1141줄**이며, Ladder 안정형/공격형 분기가 추가되면 더 커진다. 전략별 body 위젯을 별도 파일로 분리하여 cycle_detail_screen.dart는 전략 분기 라우팅만 수행한다.

**cycle_detail_screen.dart의 build() 패턴:**

```dart
@override
Widget build(BuildContext context) {
  // ... cycle 조회, null 체크 ...

  if (cycle.status == CycleStatus.completed) {
    return _buildCompletedView(cycle);
  }
  if (cycle.isPendingCompletion) {
    return _buildPendingCompletionView(cycle);
  }

  // (F-2) 전략별 body 위젯 라우팅
  final Widget body;
  if (cycle.strategyType == StrategyType.ladderCycle) {
    body = LadderDetailBody(cycle: cycle);
  } else if (cycle.strategyType == StrategyType.alphaCycleV3) {
    body = _buildSmartBody(cycle);  // 기존 코드 (리팩터링은 향후)
  } else {
    body = _buildSteadyBody(cycle);  // 기존 코드 (리팩터링은 향후)
  }

  return Scaffold(
    appBar: _buildAppBar(cycle),
    body: body,
    floatingActionButton: _buildFab(cycle),
  );
}
```

**PopupMenu 분기 (F-13):**

```dart
// cycle_detail_screen.dart — PopupMenuButton itemBuilder 내
itemBuilder: (ctx) => [
  PopupMenuItem(value: 'editSeed', child: ...),

  // Ladder 전용: ATH 수정
  if (cycle.strategyType == StrategyType.ladderCycle)
    PopupMenuItem(value: 'editAth', child: Row(
      children: [
        Icon(Icons.trending_up, size: 20),
        SizedBox(width: 8),
        Text('ATH 수정'),
      ],
    )),

  // 익절 처리: Ladder가 아닌 경우에만 표시
  if (cycle.totalShares > 0 &&
      cycle.strategyType != StrategyType.ladderCycle)
    PopupMenuItem(value: 'takeProfit', child: Row(
      children: [
        Icon(Icons.celebration, size: 20, color: AppColors.green600),
        SizedBox(width: 8),
        Text('익절 처리', style: TextStyle(color: AppColors.green600)),
      ],
    )),

  PopupMenuItem(value: 'complete', child: ...),
  PopupMenuItem(value: 'delete', child: ...),
],
```

---

## 7. 라우터 변경 (C-7)

### 7.1 app_router.dart — strategy 파싱 코드 수정

```dart
// 기존 코드 (2가지만 처리):
GoRoute(
  path: stocksSetup,
  builder: (context, state) {
    final strategy = state.uri.queryParameters['strategy'];
    return CycleSetupScreen(
      initialStrategy: strategy == 'infiniteBuy'
          ? StrategyType.infiniteBuy
          : StrategyType.alphaCycleV3,
    );
  },
),

// 변경 — ladderCycle 추가:
GoRoute(
  path: stocksSetup,
  builder: (context, state) {
    final strategy = state.uri.queryParameters['strategy'];
    final StrategyType initialStrategy;
    switch (strategy) {
      case 'infiniteBuy':
        initialStrategy = StrategyType.infiniteBuy;
        break;
      case 'ladderCycle':
        initialStrategy = StrategyType.ladderCycle;
        break;
      default:
        initialStrategy = StrategyType.alphaCycleV3;
    }
    return CycleSetupScreen(initialStrategy: initialStrategy);
  },
),
```

---

## 8. 거래 내역 표시

### 8.1 거래 카드 형식

기존 `_TradeRoundSection` (fieldset 스타일 테두리) + `CycleTradeCard` 패턴 그대로 사용:

```
┌─ 3회차 · 2026.03.28 ──────────────┐
│                                    │
│ [매수] QLD 매수  $72.50 × 12주 $870.00
│                            ₩1,250,000
│                                    │
└────────────────────────────────────┘
```

- **테두리**: `_TradeRoundSection` — Stack + Border.all + borderRadius 12
- **회차 라벨**: Positioned(left:14, top:0) — `3회차 · 2026.03.28` (10pt w700)
- **거래 행**: `[매수배지 36×26]` + 신호라벨(QLD 매수) + `$가격 × N주` + 우측 `$USD` / `₩KRW`
- **신호라벨**: `Trade.ticker + " 매수"` 또는 `Trade.ticker + " 매도"` (기존의 SignalBadgeConfig.label 대신)

### 8.2 거래 카드의 Ladder 분기

```dart
// CycleTradeCard — 신호 라벨 결정
if (cycle.strategyType == StrategyType.ladderCycle) {
  final tradeTicker = trade.ticker ?? cycle.ticker;
  signalLabel = '$tradeTicker ${isBuy ? "매수" : "매도"}';
} else {
  signalLabel = SignalBadgeConfig.fromSignal(trade.signal).label;
}
```

---

## 9. 파일 변경 목록

### 9.1 모델 수정 (6파일)

| 파일 | 변경 |
|------|------|
| `lib/data/models/cycle.dart` | StrategyType.ladderCycle, HiveField 43~48, ladderMode 헬퍼, toJson/fromJson 확장 (C-2), _parseStrategyType (I-2) |
| `lib/data/models/cycle.g.dart` | 수동 수정 (field 43~48 read/write) — (F-16) 프로젝트 기존 관례대로 수동 수정 |
| `lib/data/models/trade.dart` | HiveField 11 ticker, TradeSignal ladderStep1~6, toJson/fromJson ticker 추가 (C-2) |
| `lib/data/models/trade.g.dart` | 수동 수정 (field 11 read/write, signal 15~20) — (F-16) 프로젝트 기존 관례대로 수동 수정 |
| `lib/data/models/settings.dart` | **(F-7)** HiveField 22 `ladderCycleChartColor`, 생성자/copyWith/toJson/fromJson 확장 |
| `lib/data/models/settings.g.dart` | **(F-7, F-16)** 수동 수정 (field 22 read/write, writeByte 22→23) — 프로젝트 기존 관례대로 수동 수정 |

### 9.2 도메인 신규 (1파일)

| 파일 | 설명 |
|------|------|
| `lib/domain/trading/ladder_cycle_service.dart` | **신규** — LadderCycleService (StrategyEngine 구현), parseLadderWeights/Triggers 헬퍼, calculateMDD, stepAmount, gapAmount, recommendedTickers (F-4), groupByTicker, tickerVwap, tickerEvalAmount, TickerHolding 클래스, buildTickerHoldings (F-5) |

### 9.3 Provider 수정 (4파일)

| 파일 | 변경 |
|------|------|
| `lib/presentation/providers/cycle_providers.dart` | ladderCyclesProvider, signal 분기, addCycle Ladder 파라미터, _recalculateCycleState currentStep 갱신 + 안정형 averagePrice=0 (F-20) |
| `lib/presentation/providers/trade_providers.dart` | recordBuy ticker, currentStep 갱신 |
| `lib/presentation/providers/portfolio_providers.dart` | Ladder 집계 필드, 안정형 평가금 계산 경로 (F-15) |
| `lib/presentation/providers/settings_providers.dart` | **(F-7)** updateChartColors에 `ladderColor` 파라미터 추가 |

### 9.4 데이터 서비스 수정 (1파일)

| 파일 | 변경 |
|------|------|
| `lib/data/services/data/data_management_service.dart` | 백업 version 5→6 (C-2), CSV "종목" 컬럼 추가 (I-4) |

### 9.5 UI 수정 (6파일)

| 파일 | 변경 |
|------|------|
| `lib/presentation/screens/stocks/stocks_screen.dart` | 4탭 구조, Ladder 탭 |
| `lib/presentation/screens/stocks/cycle_setup_screen.dart` | Ladder 설정 UI + 고급 설정 (단계/프리셋/커스텀) |
| `lib/presentation/screens/stocks/cycle_detail_screen.dart` | (F-2) 전략별 body 위젯 라우팅, (F-13) PopupMenu Ladder 분기 (익절 처리 숨김, ATH 수정 추가), WS lazy 구독 (C-6) |
| `lib/presentation/screens/stocks/widgets/cycle_trade_card.dart` | Ladder 신호라벨 분기 |
| `lib/presentation/widgets/home/portfolio_allocation_chart.dart` | 4분할 세그먼트 (I-5) |
| `lib/routes/app_router.dart` | strategy=ladderCycle 파싱 (C-7) |

### 9.6 UI 신규 (7파일)

| 파일 | 설명 |
|------|------|
| `lib/presentation/screens/stocks/widgets/ladder_buy_guide_card.dart` | **신규** — 매수 가이드 + 티커 뱃지 + 수량 추천 |
| `lib/presentation/screens/stocks/widgets/ladder_progress_bar.dart` | **신규** — N단계 진행도 바 |
| `lib/presentation/screens/stocks/widgets/ladder_detail_body.dart` | **(F-2) 신규** — Ladder 전용 상세 화면 body (PnL 카드 + 진행도 바 + 매수 가이드 + 보유현황 테이블 + 환율 편집 + 정보카드 + 거래내역) |
| `lib/presentation/screens/stocks/widgets/ladder_ticker_holdings.dart` | **(F-2) 신규** — 안정형 보유 현황 테이블 위젯 (TickerHolding 리스트 → DataTable/ListView) |
| `lib/presentation/screens/stocks/widgets/ladder_exchange_rate_editor.dart` | **(F-2) 신규** — 안정형 티커별 환율 편집 위젯 (펼침/접힘, 티커별 평균 매입환율 표시 및 수정) |
| `lib/presentation/screens/stocks/widgets/ladder_trade_record_sheet.dart` | **(F-3) 신규** — Ladder 전용 거래 기록 시트 (종목 선택, 단계 신호, 추천 가이드) |
| `lib/presentation/screens/stocks/widgets/ladder_advanced_settings.dart` | **(F-18) 신규** — Ladder 고급 설정 위젯 (분할 단계/비율 프리셋/커스텀 슬라이더) — cycle_setup_screen에서 분리 |

### 9.7 공유 위젯 수정 (2파일)

| 파일 | 변경 |
|------|------|
| `lib/presentation/widgets/cycle/strategy_badge.dart` | ladderCycle 케이스 (모드별 라벨) |
| `lib/presentation/widgets/shared/signal_badge_config.dart` | ladderStep1~6 매핑, 정적 라벨 (I-3) |

---

## 10. 구현 순서 (Phase)

### Phase 1: 데이터 모델 (cycle.dart, trade.dart, settings.dart, *.g.dart)
- StrategyType.ladderCycle, Cycle 필드 43~48, Trade 필드 11, TradeSignal 15~20
- Cycle.toJson/fromJson 확장 (C-2), _parseStrategyType (I-2)
- Trade.toJson/fromJson ticker 추가 (C-2)
- **(F-7)** Settings.ladderCycleChartColor (HiveField 22), toJson/fromJson
- **(F-16)** .g.dart 수동 수정 (프로젝트 기존 관례)

### Phase 2: 도메인 로직 (ladder_cycle_service.dart)
- LadderCycleService: detectSignal (C-3 named params), calculateAmount, MDD 계산
- parseLadderWeights/Triggers 방어적 파싱 (C-1, I-1)
- stepAmount 범위 검증 (C-4), totalWeight 0 방어 (M-1)
- 단계별 금액 (가변 N단계/비율), 티커 추천
- **(F-4)** 모든 헬퍼 함수 → ladder_cycle_service.dart top-level
- **(F-5)** TickerHolding, buildTickerHoldings → 같은 파일 배치

### Phase 3: Provider (cycle_providers, trade_providers, portfolio_providers, settings_providers)
- ladderCyclesProvider, signal 분기, recordBuy ticker, currentStep 갱신
- addCycle Ladder 파라미터, weights 합계 0 방어 (M-1)
- 포트폴리오 집계 (Ladder 필드)
- **(F-15)** 안정형 평가금 계산 경로 (buildTickerHoldings 기반)
- **(F-7)** settings_providers.dart updateChartColors에 ladderColor 추가
- **(F-20)** _recalculateCycleState() 안정형 averagePrice = 0

### Phase 4: 데이터 서비스 (data_management_service)
- 백업 version 5→6 (C-2)
- CSV "종목" 컬럼 추가 (I-4)

### Phase 5: UI — 생성 & 목록 (setup_screen, stocks_screen, router, strategy_badge, signal_badge_config)
- 3전략 SegmentedButton, Ladder 설정 UI + 고급 설정 (분할 단계/비율 프리셋/커스텀)
- **(F-18)** 고급 설정 → `ladder_advanced_settings.dart` 위젯 분리
- 4탭 구조, FAB, 뱃지
- 라우터 ladderCycle 파싱 (C-7)
- SignalBadge 정적 라벨 (I-3)
- 도넛 차트 4분할 (I-5)

### Phase 6: UI — 상세 (detail_screen, ladder_detail_body, ladder_progress_bar, ladder_buy_guide_card, ladder_ticker_holdings, ladder_exchange_rate_editor)
- **(F-2)** cycle_detail_screen → 전략별 body 위젯 라우팅
- **(F-2)** LadderDetailBody: PnL 카드 (기준시세+ATH+MDD), 진행도 바 (N단계 동적)
- 매수 가이드 카드, 추천 티커 현재가 조회 (C-6)
- **(F-2)** LadderTickerHoldings: 보유현황 테이블 (안정형 멀티 티커 — C-5, I-6)
- CycleInfoCard (공격형), **(F-2)** LadderExchangeRateEditor: 매입환율 편집 (안정형 3개 확장)
- 매도 가이드 텍스트
- WS lazy 구독 (C-6)
- **(F-13)** PopupMenu: Ladder에서 "익절 처리" 숨김, "ATH 수정" 추가

### Phase 7: UI — 거래 기록 시트 & 거래 카드 (cycle_trade_card, detail_screen FAB)
- **(F-3)** LadderTradeRecordSheet 신규 파일 생성
- 종목 선택 (안정형), 신호 선택 (ladderStep)
- 거래 카드 신호라벨 분기

---

## 11. 전량매도 대기 & 사이클 완료

### 11.1 전량매도 대기 (isPendingCompletion)

기존 `cycle.isPendingCompletion` 로직을 그대로 사용:
```dart
bool get isPendingCompletion =>
    totalShares == 0 && status == CycleStatus.active && seedAmount != remainingCash;
```

**안정형 특이사항:** QQQ, QLD, TQQQ 3개 보유 시 → 3개 **모두** 매도해야 `totalShares == 0`. 일부만 매도하면 나머지는 여전히 활성 상태. 기존 로직이 자동으로 처리 (C-5: totalShares는 전체 합산 유지).

#### My 탭 카드 (isPendingCompletion) — 기존 패턴 그대로

```
┌──────────────────────────────────────┐
│ [TL] TQQQ  닉네임         ✅ 전량매도 │
│      ProShares UltraPro              │
│                                      │
│  ✅ 전량 매도 · 35일 · 3회차          │
│  순수익 +₩200,000 (+8.0%)           │
│  투자 ₩2,500,000 → 회수 ₩2,700,000 │
└──────────────────────────────────────┘
```

기존 `_ActiveCycleCard`의 isPendingCompletion 분기 코드가 `strategyType`에 관계없이 동작하므로 Ladder에서도 별도 구현 불필요.

#### 상세 화면 (isPendingCompletion) — 기존 패턴 그대로

기존 `_buildPendingCompletionCard` 위젯을 그대로 사용:

```
┌──────────────────────────────────────────┐
│ ◀  TQQQ  닉네임        [⧈ Ladder 안정형] │
├══════════════════════════════════════════╡
│                                          │
│ ┌──────────────────────────────────────┐ │
│ │ ✅ 전량 매도 완료                     │ │
│ │                                      │ │
│ │ 설정 시드         ₩10,000,000        │ │
│ │ 총 투자금         ₩2,500,000         │ │
│ │ 총 회수금         ₩2,700,000         │ │
│ │                                      │ │
│ │ 외화손익  +1,234 USD                 │ │
│ │ 수익 (환차 미포함)   +₩200,000       │ │
│ │ 수익 (환차 포함)  □  +₩215,000       │ │
│ │                                      │ │
│ │ 평균 매수가       $65.50              │ │
│ │ 평균 매도가       $72.30              │ │
│ │ 평균 환율    ₩1,350 / $1       [✏️]  │ │
│ │                                      │ │
│ │ 운용 기간         35일               │ │
│ │ 총 회차           3회                │ │
│ └──────────────────────────────────────┘ │
│                                          │
│  ┌────────────────────────────────────┐  │
│  │       사이클 완료 (정산)            │  │
│  └────────────────────────────────────┘  │
│                                          │
│ 거래 내역 (5건)                           │
│ ┌─ 5회차 · 2026.04.20 ──────────────┐   │
│ │ [매도] QLD 매도 $80.00 × 12주 ...  │   │
│ └────────────────────────────────────┘   │
│ ...                                      │
└──────────────────────────────────────────┘
```

**안정형 전량매도 대기에서의 평균 환율:**
- 3개 티커 보유했던 경우: 전체 거래의 가중평균 환율 1개로 표시
- 편집 시 단일 환율 편집 (활성 상태의 티커별 3개 편집과 다름 — 이미 매도 완료)

### 11.2 사이클 완료

"사이클 완료 (정산)" 버튼 클릭 시:
1. `cycle.status = CycleStatus.completed` 으로 변경
2. `completedReturnRate` 기록
3. My 탭 Ladder 목록에서 제거
4. 거래내역 탭(`/history`)에 완료된 사이클로 이동
5. 포트폴리오 집계에서 제외 (completedCyclesProvider로 이동)

**Smart/Steady와의 차이:** 없음. 기존 `completeCycle()` 메서드 그대로 사용.

### 11.3 포트폴리오 집계 연동

`unifiedPortfolioProvider`에서:

```dart
// 활성 사이클만 순회 (activeCyclesProvider)
for (final cycle in activeCycles) {
  ...
  if (cycle.strategyType == StrategyType.ladderCycle) {
    // isPendingCompletion: totalBuyAmountKrw / totalSellAmountKrw 사용
    // 활성 (포지션 있음): actualInvested / evalAmt 사용
    // → 기존 Smart/Steady와 동일한 isPendingCompletion 분기 적용
    ladderValue += cycleValue;
    ladderInvested += cycleInvested;
    ...
  }
}
```

전량매도 대기 → 완료 전까지 포트폴리오 총투자/총손익에 포함. 완료 후 제거. 기존 로직 그대로.

---

## 12. 엣지 케이스

| 케이스 | 처리 |
|--------|------|
| ATH 가격 미입력 (0) | 신호 = hold, 가이드 "ATH 가격을 입력하세요" |
| 갭 하락 (2단계 이상 동시 돌파) | 미실행 단계 금액 합산 |
| N단계 이후 추가 하락 | 추가 매수 없음, 보유 유지 |
| ATH 갱신 (신고점) | 사용자가 athPrice 수동 업데이트 + 사이클 종료 가이드 |
| 안정형에서 매도 | 종목 선택 후 Trade.ticker에 기록 |
| 중간에 모드 변경 | 허용 안 함 (생성 시 고정) |
| 중간에 단계/비율 변경 | 허용 안 함 (생성 시 고정) |
| 안정형 보유 종목 0개 | 보유 현황 테이블 미표시, 초기 매수 가이드만 |
| 공격형에서 보유 0주 | 기존 CycleInitialBuyGuide 패턴 |
| 커스텀 비율 합계 != 100% | 경고 표시 + 사이클 시작 버튼 비활성화 |
| 균등형 6단계 반올림 | 비중 1/1/1/1/1/1 (totalWeight=6), 각 seed/6 — 반올림 이슈 없음 (M-2) |
| ladderWeights 빈 문자열 | parseLadderWeights → 기본값 반환 (C-1, I-1) |
| ladderTriggers 잘못된 형식 | parseLadderTriggers → tryParse 실패 시 0.0, 빈 결과 시 기본값 (C-1, I-1) |
| stepAmount의 step 범위 초과 | step < 1 또는 step > weights.length → return 0 (C-4) |
| weights 합계 0 | stepAmount → seed / weights.length 균등 분배 (M-1) |
| Cycle 생성 시 weights 합 0 | 기본값 폴백 (M-1) |
| 알 수 없는 StrategyType 복원 | _parseStrategyType → alphaCycleV3 폴백 (I-2) |

---

## 13. 향후 확장 (MVP 이후)

- ATH 자동 추적 (Finnhub/TwelveData API)
- RSI/20MA 기반 자동 매도 신호
- 과거 대입 시뮬레이션 ("2008년 이 전략이면 X% 수익")
- 진행도 바 인터랙티브 (탭하면 해당 단계 상세)
- SOXX 기준 지수 지원 (초공격형 전용)

### Tech Debt (F-1)

- **Cycle HiveField 48개 문제**: 현재 Cycle 모델은 HiveField 0~48까지 49개 필드를 보유한다. 전략 공통 필드와 전략 전용 필드가 단일 모델에 혼합되어 있어, 향후 전략이 추가될수록 모델이 비대해진다. 장기적으로 전략별 설정을 별도 Hive 모델(또는 JSON String 필드)로 분리하는 리팩터링을 고려해야 한다. 현재는 Hive의 `@HiveField(N, defaultValue: ...)` 마이그레이션 패턴으로 하위호환이 보장되므로 즉시 조치 불필요.

---

## 부록: 디자인 리뷰 이슈 반영 요약

| 이슈 | 심각도 | 설명 | 반영 위치 |
|------|--------|------|-----------|
| C-1 | Critical | String 파싱 무방어 → tryParse + 기본값 폴백 | 2.2.1, 3.5, 4.1 |
| C-2 | Critical | toJson/fromJson 누락 → 6+1 필드 추가, 백업 v6 | 2.3, 2.4.1, 2.7 |
| C-3 | Critical | detectSignal 시그니처 불일치 → named parameter | 4.1 |
| C-4 | Critical | stepAmount 범위 미검증 → 방어 코드 | 3.5 |
| C-5 | Critical | 안정형 멀티 티커 averagePrice/totalShares 정의 | 3.9 |
| C-6 | Critical | WebSocket 멀티 티커 구독 | 5.3 |
| C-7 | Critical | 라우터 ladderCycle 파싱 | 7.1 |
| I-1 | Important | 빈 문자열 파싱 폴백 | 2.2.1 |
| I-2 | Important | fromJson StrategyType 예외 처리 | 2.3 |
| I-3 | Important | SignalBadgeConfig 정적 라벨 | 4.3 |
| I-4 | Important | CSV 내보내기 ticker 컬럼 | 2.8 |
| I-5 | Important | 도넛 차트 Ladder 세그먼트 | 6.2 |
| I-6 | Important | 안정형 환율 계산 경로 | 3.10 |
| M-1 | Minor | 커스텀 비율 도메인 방어 | 3.5, 5.2.1 |
| M-2 | Minor | 균등형 반올림 | 3.3 |

### 아키텍처 감사 반영 요약 (v3.1)

| 이슈 | 심각도 | 설명 | 반영 위치 |
|------|--------|------|-----------|
| F-1 | Important | Cycle 48 HiveField Tech Debt 기록 | 13절 (향후 확장) |
| F-2 | Critical | cycle_detail_screen Ladder body 위젯 분리 | 6.8, 9.6 |
| F-3 | Important | LadderTradeRecordSheet 신규 확정 | 6.7, 9.6 |
| F-4 | Critical | 헬퍼 함수 파일 배치 명시 | 2.2.1, 3.4~3.7 |
| F-5 | Important | TickerHolding 파일 배치 | 3.9, 9.2 |
| F-7 | Critical | Settings.ladderCycleChartColor 추가 | 2.6, 2.9, 9.1, 9.3 |
| F-13 | Critical | Ladder 익절 처리 메뉴 숨김 | 6.5, 6.6, 6.8 |
| F-15 | Critical | unifiedPortfolioProvider 안정형 평가금 | 5.4.4 |
| F-16 | Important | .g.dart 수동 수정 관례 명시 | 2.9, 9.1 |
| F-18 | Important | Ladder 고급 설정 위젯 분리 | 9.6, Phase 5 |
| F-20 | Important | 안정형 averagePrice = 0 처리 | 3.9, 5.2.3 |
