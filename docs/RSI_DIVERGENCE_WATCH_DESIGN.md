# RSI Divergence Watch Point Design - RSI 다이버전스 감시점 설계서

> Version: 1.0 | Date: 2026-03-24

## 1. 개요

### 기능 설명

RSI 차트에서 사용자가 고점 또는 저점에 "감시점(Watch Point)"을 설정하면, 실시간 가격 모니터링을 통해 다이버전스 발생 가능성을 자동 감지하고 알림을 발생시키는 기능이다.

기존 목표가/변동률 알림이 **가격 단일 조건**을 감시하는 반면, 이 기능은 **가격 돌파 + RSI 비교**라는 2단계 복합 조건을 감시한다.

### 핵심 원칙

- 기존 알림 시스템(`watchlistAlertMonitorProvider` 패턴) 최대 활용
- WebSocket 가격 데이터 재활용 — 추가 WebSocket 연결 없음
- RSI 계산은 가격 돌파 확인 후에만 수행 (Twelve Data API 절약)
- Hive 영속화 — 앱 재시작 후에도 감시점 유지
- 다이버전스 확인 시 RSI 차트에 자동 드로잉 선 생성

### 사용 흐름 요약

```
1. 사용자: RSI 차트에서 고점/저점 탭 → 감시점 설정
2. 시스템: 해당 시점의 가격(P1)과 RSI(R1) 저장 (Hive)
3. 시스템: WebSocket 가격 업데이트마다 P1 돌파 여부 체크
4. 돌파 감지 시: Twelve Data API → 최근 종가 → RSI(R2) 계산
5. R1 vs R2 비교 → 다이버전스 확인 시 알림 + RSI 선 자동 그리기
```

---

## 2. 두 가지 감시 모드

### 모드 1: 하락 다이버전스 감시 (Bearish — 고점 감시)

가격은 신고점을 만들었지만 RSI는 이전 고점보다 낮아 모멘텀이 약해지는 패턴.

```
가격:   ╱╲        ╱╲ ← P2 > P1 (신고점)
       ╱  ╲      ╱  ╲
      P1   ╲    ╱
             ╲  ╱
              ╲╱

RSI:   ╱╲        ╱╲ ← R2 < R1 (RSI는 하락)
      R1  ╲    R2  ╲
           ╲  ╱
            ╲╱
```

| 항목 | 값 |
|------|------|
| 감시점 설정 | RSI 고점 (R1, P1) |
| 돌파 조건 | 현재가 > P1 (가격이 위로 돌파) |
| 다이버전스 판정 | R2 < R1 (RSI가 이전보다 낮음) |
| 알림 의미 | 상승 모멘텀 약화, 하락 전환 가능성 |

### 모드 2: 상승 다이버전스 감시 (Bullish — 저점 감시)

가격은 신저점을 만들었지만 RSI는 이전 저점보다 높아 하락 모멘텀이 약해지는 패턴.

```
가격:        ╱╲
            ╱  ╲    ╱
      P1   ╱    ╲  ╱
       ╲  ╱      ╲╱
        ╲╱        P2 ← P2 < P1 (신저점)

RSI:        ╱╲
           ╱  ╲
      R1  ╱    R2 ← R2 > R1 (RSI는 상승)
       ╲ ╱
        ╲╱
```

| 항목 | 값 |
|------|------|
| 감시점 설정 | RSI 저점 (R1, P1) |
| 돌파 조건 | 현재가 < P1 (가격이 아래로 이탈) |
| 다이버전스 판정 | R2 > R1 (RSI가 이전보다 높음) |
| 알림 의미 | 하락 모멘텀 약화, 상승 전환 가능성 |

---

## 3. 데이터 모델

### 3.1 RsiWatchPoint (Hive 모델)

**TypeId: 27** (다음 사용 가능 ID — 현재 0~26 사용 중)

```dart
@HiveType(typeId: 27)
class RsiWatchPoint extends HiveObject {
  /// 고유 ID (UUID v4)
  @HiveField(0)
  String id;

  /// 티커 심볼 (예: AAPL, TQQQ)
  @HiveField(1)
  String ticker;

  /// 감시 모드: 0 = bearish (고점 감시), 1 = bullish (저점 감시)
  @HiveField(2)
  int mode;

  /// 감시점 설정 시 가격 (P1)
  @HiveField(3)
  double watchPrice;

  /// 감시점 설정 시 RSI 값 (R1, 0~100)
  @HiveField(4)
  double watchRsi;

  /// 감시점 설정 시 날짜 (차트 캔들의 날짜)
  @HiveField(5)
  DateTime watchDate;

  /// 감시점 설정 시 차트 interval (예: '1day', '1week')
  @HiveField(6)
  String interval;

  /// 감시점 생성 시각 (사용자가 설정한 시각)
  @HiveField(7)
  DateTime createdAt;

  /// 활성 여부 (false = 이미 트리거됨 또는 사용자가 비활성화)
  @HiveField(8, defaultValue: true)
  bool isActive;

  /// 트리거 시 감지된 RSI 값 (R2) — null이면 미트리거
  @HiveField(9)
  double? triggeredRsi;

  /// 트리거 시 감지된 가격 (P2) — null이면 미트리거
  @HiveField(10)
  double? triggeredPrice;

  /// 트리거 시각 — null이면 미트리거
  @HiveField(11)
  DateTime? triggeredAt;

  /// RSI 기간 (기본 14)
  @HiveField(12, defaultValue: 14)
  int rsiPeriod;
}
```

**모드 상수 (enum 대신 int로 Hive 호환)**:

```dart
/// RSI 감시 모드 상수
abstract class RsiWatchMode {
  static const int bearish = 0; // 고점 감시 (하락 다이버전스)
  static const int bullish = 1; // 저점 감시 (상승 다이버전스)

  static String label(int mode) =>
      mode == bearish ? '하락 다이버전스' : '상승 다이버전스';

  static String shortLabel(int mode) =>
      mode == bearish ? '고점 감시' : '저점 감시';
}
```

### 3.2 Hive Box 등록

```dart
// hive_init.dart 에 추가
Hive.registerAdapter(RsiWatchPointAdapter());
await Hive.openBox<RsiWatchPoint>('rsiWatchPoints');
```

### 3.3 JSON 직렬화 (백업/복원 호환)

`toJson()` / `fromJson()` 구현하여 `data_management_service.dart`의 백업 v4에 포함.

---

## 4. UI 흐름

### 4.1 감시점 설정 (RSI 차트에서)

기존 `RsiDrawingOverlay`의 연필(드로잉) 모드를 확장한다.

**진입 방법**: RSI 차트 영역을 **롱프레스** → 해당 위치에 감시점 설정 바텀시트 표시

**자동 RSI 스냅 (핵심)**: 사용자가 정확한 Y좌표를 탭하지 않아도 됨.
탭 위치의 **X좌표 → 캔들 인덱스 → 해당 캔들의 실제 RSI 값으로 자동 스냅**.
Y좌표는 무시. 가격도 해당 캔들의 종가를 자동 사용.

```
사용자가 대충 탭:        시스템이 자동 보정:
    ╱╲                     ╱╲
   ╱  ╲    ← 여기 탭     ╱  ● ← 실제 RSI(72.3) 위치에 점
  ╱    ╲                 ╱    ╲
```

```
┌─────────────────────────────────────┐
│  RSI 다이버전스 감시점 설정           │
├─────────────────────────────────────┤
│                                     │
│  종목: AAPL                         │
│  날짜: 2026-03-20                   │
│  가격: $178.25  (자동)               │
│  RSI:  72.3     (자동)               │
│                                     │
│  ┌─────────────┬──────────────┐     │
│  │  고점 감시   │  저점 감시    │     │ ← SegmentedButton
│  │  (하락 div) │  (상승 div)  │     │
│  └─────────────┴──────────────┘     │
│                                     │
│  RSI 기간: 14 (고급 설정)            │
│                                     │
│  가격이 $178.25를 위로 돌파하면       │ ← 모드에 따라 문구 변경
│  RSI를 확인하여 다이버전스를 감지합니다 │
│                                     │
│  [설정하기]                          │
└─────────────────────────────────────┘
```

**자동 모드 추천**: RSI 값에 따라 기본 선택
- RSI >= 60 → 기본 "고점 감시" 선택
- RSI <= 40 → 기본 "저점 감시" 선택
- 그 외 → 선택 없음 (사용자 수동 선택)

### 4.2 감시점 표시 (RSI 차트 위)

활성 감시점이 있는 종목의 RSI 차트에 마커를 표시한다.

```
RSI 차트:
  100 ┤
   70 ┤─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─
      │         ▼ ← 고점 감시 마커 (빨강 역삼각형)
   50 ┤
   30 ┤─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─
      │    ▲ ← 저점 감시 마커 (파랑 삼각형)
    0 ┤
```

**마커 색상 규칙** (ThemeAwareColors 확장):
- 고점 감시 (bearish): `AppColors.red500` — 하락 경고이므로
- 저점 감시 (bullish): `AppColors.blue500` — 상승 기대이므로
- 트리거 완료: `context.appTextHint` (회색, 비활성)

**마커 탭 동작**: 감시점 마커 탭 → 상세 관리 바텀시트

```
┌─────────────────────────────────────┐
│  RSI 감시점 관리                      │
├─────────────────────────────────────┤
│                                     │
│  AAPL · 고점 감시 (하락 다이버전스)   │
│  설정일: 2026-03-20                  │
│  가격: $178.25  RSI: 72.3            │
│  차트: 일봉                          │
│                                     │
│  ┌─────────────┬──────────────┐     │
│  │  고점 감시   │  저점 감시    │     │ ← 모드 변경 가능
│  └─────────────┴──────────────┘     │
│                                     │
│  상태: 감시 중                       │
│                                     │
│  [일시정지]        [삭제]            │
└─────────────────────────────────────┘
```

- **모드 변경**: 고점 감시 ↔ 저점 감시 전환 가능
- **일시정지/재개**: 감시를 일시적으로 중단/재개 (삭제하지 않고)
- **삭제**: 감시점 완전 제거
- 트리거 완료된 감시점: "다이버전스 감지됨" 상태 표시 + 결과(R2, P2) 확인 가능

### 4.3 다이버전스 알림 시 자동 드로잉

다이버전스가 확인되면 RSI 차트에 **자동으로 추세선**을 그린다.

```
RSI 차트 (다이버전스 확인 후):
  100 ┤
   70 ┤─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─
      │         R1
      │        ╱  ╲        R2
      │       ╱    ╲      ╱╲
   50 ┤      ╱      ╲    ╱  ╲
      │               ╲ ╱
      │     [R1]------->[R2]      ← 빨간 점선 (R1 > R2, 하락 다이버전스)
   30 ┤─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─
    0 ┤
```

- 자동 생성된 선은 기존 `RsiDrawingLine` 모델을 재활용
- 색상: bearish = `0xFFFF6B6B` (빨강), bullish = `0xFF4D96FF` (파랑)
- `strokeWidth: 1.5`, 점선 스타일 (dashArray로 구분)
- 자동 생성 선은 `isLocked: true`로 설정 (실수로 이동 방지)

### 4.4 감시점 목록 (설정 or 관심종목 화면)

활성 감시점을 관리하는 UI. 관심종목 화면의 RSI 감시 탭 또는 종목 상세 화면에서 접근.

```
┌─────────────────────────────────────┐
│  RSI 감시점 (3개 활성)               │
├─────────────────────────────────────┤
│  AAPL  고점 감시  $178.25  RSI 72   │
│         2026-03-20  1day            │
│                            [삭제]   │
├─────────────────────────────────────┤
│  NVDA  저점 감시  $820.50  RSI 28   │
│         2026-03-18  1day            │
│                            [삭제]   │
├─────────────────────────────────────┤
│  TQQQ  고점 감시  $65.30   RSI 75   │
│         2026-03-15  1week           │
│                            [삭제]   │
└─────────────────────────────────────┘
```

---

## 5. 감시 로직 — 기존 알림 시스템과의 통합

### 5.1 아키텍처 흐름

```
WebSocket 가격 업데이트
       │
       ▼
stockQuoteProvider (기존)
       │
       ▼
watchlistAlertMonitorProvider (기존) ── 목표가/변동률 알림
       │
       ▼
rsiDivergenceMonitorProvider (신규) ── RSI 감시점 돌파 체크
       │
       ├── 돌파 미감지 → 대기 (API 호출 없음)
       │
       └── 돌파 감지 → Twelve Data API 호출
                │
                ▼
          TechnicalIndicatorService.calculateRSI()
                │
                ├── R2 vs R1 비교
                │
                ├── 다이버전스 → 알림 + 자동 드로잉
                │
                └── 다이버전스 아님 → 감시 계속 (쿨다운 후 재체크)
```

### 5.2 Provider 설계

```dart
/// RSI 감시점 저장소 Provider
final rsiWatchPointProvider =
    StateNotifierProvider<RsiWatchPointNotifier, RsiWatchPointState>((ref) {
  return RsiWatchPointNotifier();
});

/// RSI 다이버전스 감시 Provider (watchlistAlertMonitorProvider와 동일 패턴)
final rsiDivergenceMonitorProvider = Provider<List<RsiDivergenceAlert>>((ref) {
  final quoteState = ref.watch(stockQuoteProvider);
  final watchPoints = ref.watch(rsiWatchPointProvider);
  final checker = ref.read(rsiDivergenceCheckerProvider);

  // 활성 감시점이 없으면 빈 리스트
  final activePoints = watchPoints.points.where((p) => p.isActive).toList();
  if (activePoints.isEmpty) return [];
  if (quoteState.quotes.isEmpty) return [];

  return checker.checkBreakthroughs(quoteState.quotes, activePoints);
});
```

### 5.3 돌파 감지 + RSI 계산 흐름

`RsiDivergenceChecker` 클래스 설계:

```dart
class RsiDivergenceChecker {
  final Map<String, DateTime> _cooldowns = {};    // 종목별 RSI 체크 쿨다운
  final Map<String, double> _previousPrices = {}; // 이전 가격 (교차 감지)
  static const Duration _rsiCheckCooldown = Duration(minutes: 30);

  /// 1단계: 가격 돌파 체크 (WebSocket 데이터, API 호출 없음)
  List<RsiDivergenceAlert> checkBreakthroughs(
    Map<String, StockQuote> quotes,
    List<RsiWatchPoint> activePoints,
  ) {
    final alerts = <RsiDivergenceAlert>[];

    for (final point in activePoints) {
      final quote = quotes[point.ticker];
      if (quote == null || quote.currentPrice <= 0) continue;

      final currentPrice = quote.currentPrice;
      final previousPrice = _previousPrices[point.ticker];
      _previousPrices[point.ticker] = currentPrice;

      // 교차 감지 (관통 판정)
      final breached = _isBreached(point, currentPrice, previousPrice);
      if (!breached) continue;

      // 쿨다운 체크 (API 남용 방지)
      final cooldownKey = '${point.ticker}_${point.id}';
      if (_isInCooldown(cooldownKey)) continue;
      _cooldowns[cooldownKey] = DateTime.now();

      // 돌파 감지 → RSI 체크 요청 알림 생성
      alerts.add(RsiDivergenceAlert(
        watchPoint: point,
        currentPrice: currentPrice,
        status: RsiAlertStatus.breached,
      ));
    }

    return alerts;
  }

  /// 교차 감지: 가격이 감시 가격을 관통했는지 확인
  bool _isBreached(RsiWatchPoint point, double current, double? previous) {
    if (previous == null) return false; // 첫 체크는 스킵 (교차 판정 불가)

    if (point.mode == RsiWatchMode.bearish) {
      // 고점 감시: 가격이 아래에서 위로 관통
      return previous <= point.watchPrice && current > point.watchPrice;
    } else {
      // 저점 감시: 가격이 위에서 아래로 관통
      return previous >= point.watchPrice && current < point.watchPrice;
    }
  }

  bool _isInCooldown(String key) {
    final last = _cooldowns[key];
    if (last == null) return false;
    return DateTime.now().difference(last) < _rsiCheckCooldown;
  }
}
```

### 5.4 MainShell 통합

`main_shell.dart`의 `initState`에 기존 패턴과 동일하게 등록:

```dart
// 기존 알림 감시 (변경 없음)
ref.listenManual(watchlistAlertMonitorProvider, ...);
ref.listenManual(fearGreedAlertMonitorProvider, ...);

// RSI 다이버전스 감시 (신규 추가)
ref.listenManual(rsiDivergenceMonitorProvider, (prev, next) {
  if (next.isEmpty) return;
  _handleRsiDivergenceAlerts(next);
}, fireImmediately: true);
```

---

## 6. API 호출 — 돌파 감지 시 RSI 계산

### 6.1 호출 흐름

돌파가 감지되면 MainShell의 핸들러에서 비동기로 RSI를 계산한다.

```dart
Future<void> _handleRsiDivergenceAlerts(List<RsiDivergenceAlert> alerts) async {
  for (final alert in alerts) {
    if (alert.status != RsiAlertStatus.breached) continue;

    final point = alert.watchPoint;

    // 1. Twelve Data API로 차트 데이터 가져오기
    final twelveData = ref.read(twelveDataServiceProvider);
    final chartData = await twelveData.getChartData(
      point.ticker,
      interval: point.interval,
      outputsize: 50, // RSI(14) 계산에 최소 15개 필요, 여유분 포함
    );

    if (chartData.isEmpty) continue;

    // 2. RSI 계산
    final closes = chartData.map((d) => d.close).toList();
    final indicatorService = TechnicalIndicatorService();
    final rsiValues = indicatorService.calculateRSI(closes, period: point.rsiPeriod);

    // 3. 최신 RSI 값 추출
    final currentRsi = rsiValues.lastWhere((r) => r != null, orElse: () => null);
    if (currentRsi == null) continue;

    // 4. 다이버전스 판정
    final isDivergence = _checkDivergence(point, currentRsi);

    if (isDivergence) {
      // 5a. 알림 발생 + 감시점 업데이트 + 자동 드로잉
      _triggerDivergenceNotification(point, alert.currentPrice, currentRsi);
      _updateWatchPointAsTriggered(point, alert.currentPrice, currentRsi);
      _createAutoDrawingLine(point, currentRsi);
    }
    // 5b. 다이버전스 아님 → 쿨다운 후 다음 돌파 시 재체크 (자동)
  }
}

bool _checkDivergence(RsiWatchPoint point, double currentRsi) {
  if (point.mode == RsiWatchMode.bearish) {
    // 하락 다이버전스: 가격은 올랐는데 RSI는 내렸다
    return currentRsi < point.watchRsi;
  } else {
    // 상승 다이버전스: 가격은 내렸는데 RSI는 올랐다
    return currentRsi > point.watchRsi;
  }
}
```

### 6.2 API 절약 전략

| 조건 | 동작 |
|------|------|
| 가격 돌파 미감지 | API 호출 없음 (WebSocket만 사용) |
| 돌파 감지 | Twelve Data 1회 호출 (outputsize: 50) |
| 30분 쿨다운 | 같은 감시점에 대해 30분간 재호출 차단 |
| 장 폐장 시 | `marketState == 'CLOSED'` → 가격 업데이트 무시 (기존 보호 필터) |
| 다이버전스 확인 | 감시점 비활성화 → 더 이상 체크 안 함 |
| 다이버전스 미확인 | 감시 계속, 다음 돌파 시 재체크 |

**예상 API 사용량**: 감시점당 하루 최대 1~3회 (돌파 빈도 기준). 기존 차트 조회 캐시(30분 TTL)도 활용.

---

## 7. 알림 발생

### 7.1 알림 형식

기존 `NotificationRecord` 모델을 재활용하며, `type` 필드에 `'rsi_divergence'`를 사용.

**하락 다이버전스 알림**:
```
제목: AAPL 하락 다이버전스 감지!
본문: 가격 $178.25 → $182.50 (신고점) | RSI 72.3 → 65.1 (하락)
      모멘텀 약화 — 하락 전환 가능성에 주의하세요
```

**상승 다이버전스 알림**:
```
제목: NVDA 상승 다이버전스 감지!
본문: 가격 $820.50 → $795.30 (신저점) | RSI 28.5 → 35.2 (상승)
      하락 모멘텀 약화 — 반등 가능성에 주목하세요
```

### 7.2 알림 저장 흐름

```dart
void _triggerDivergenceNotification(
  RsiWatchPoint point, double currentPrice, double currentRsi,
) {
  final isBearish = point.mode == RsiWatchMode.bearish;
  final modeLabel = isBearish ? '하락' : '상승';
  final priceDir = isBearish ? '신고점' : '신저점';
  final rsiDir = isBearish ? '하락' : '상승';
  final advice = isBearish
      ? '모멘텀 약화 — 하락 전환 가능성에 주의하세요'
      : '하락 모멘텀 약화 — 반등 가능성에 주목하세요';

  final record = NotificationRecord(
    id: 'rsi_div_${DateTime.now().millisecondsSinceEpoch}',
    ticker: point.ticker,
    title: '${point.ticker} $modeLabel 다이버전스 감지!',
    body: '가격 \$${point.watchPrice.toStringAsFixed(2)} → '
        '\$${currentPrice.toStringAsFixed(2)} ($priceDir) | '
        'RSI ${point.watchRsi.toStringAsFixed(1)} → '
        '${currentRsi.toStringAsFixed(1)} ($rsiDir)\n$advice',
    type: 'rsi_divergence',
    triggeredAt: DateTime.now(),
  );

  ref.read(notificationHistoryProvider.notifier).addRecord(record);

  final muted = ref.read(settingsProvider).notificationMuted;
  if (!muted) {
    WebNotificationService.show(title: record.title, body: record.body);
  }
}
```

---

## 8. 파일 구조

### 8.1 신규 파일

| 파일 | 역할 |
|------|------|
| `lib/data/models/rsi_watch_point.dart` | Hive 모델 + TypeId 27 |
| `lib/data/models/rsi_watch_point.g.dart` | Hive 어댑터 (수동 작성 — 기존 패턴 따름, build_runner 미사용) |
| `lib/data/repositories/rsi_watch_point_repository.dart` | CRUD + Hive 박스 관리 |
| `lib/presentation/providers/rsi_divergence_providers.dart` | State/Notifier/Monitor Provider |
| `lib/presentation/widgets/index/rsi_watch_point_marker.dart` | RSI 차트 위 감시점 마커 CustomPainter |
| `lib/presentation/widgets/index/rsi_watch_point_sheet.dart` | 감시점 설정 바텀시트 |
| `lib/core/constants/rsi_watch_mode.dart` | 감시 모드 상수 + 헬퍼 |

### 8.2 수정 파일

| 파일 | 수정 내용 |
|------|----------|
| `lib/main.dart` | `Hive.registerAdapter(RsiWatchPointAdapter())` 등록 |
| `lib/presentation/providers/core/repository_providers.dart` | `_rsiWatchPointRepo.init()` 추가 (appInitializationProvider) |
| `lib/presentation/widgets/index/rsi_drawing_overlay.dart` | 롱프레스 핸들러 추가, 감시점 마커 렌더링, `displayData` + `scrollOffset` 파라미터 추가 |
| `lib/presentation/widgets/index/chart_sub_charts.dart` | `RsiDrawingOverlay`에 `displayData` + `scrollOffset` 전달 |
| `lib/presentation/widgets/common/main_shell.dart` | `rsiDivergenceMonitorProvider` 리스너 등록 |
| `lib/data/services/data_management_service.dart` | 백업 v4에 `rsiWatchPoints` 박스 추가 |
| `lib/core/theme/app_colors.dart` | 감시점 마커 색상 (필요 시 ThemeAwareColors 확장) |

---

## 9. 구현 Phase

### Phase 1: 데이터 레이어 (모델 + 저장소)

1. `rsi_watch_mode.dart` — 감시 모드 상수
2. `rsi_watch_point.dart` — Hive 모델 (TypeId 27) + toJson/fromJson
3. `rsi_watch_point.g.dart` — Hive 어댑터 **수동 작성** (build_runner 미사용 — 기존 패턴)
4. `rsi_watch_point_repository.dart` — CRUD (add, remove, update, getByTicker, getActive)
5. `main.dart` — `Hive.registerAdapter(RsiWatchPointAdapter())` 등록
6. `repository_providers.dart` — `_rsiWatchPointRepo.init()` 추가 (appInitializationProvider)

**검증**: 유닛 테스트 — 모델 직렬화, 저장소 CRUD

### Phase 2: Provider 레이어

1. `rsi_divergence_providers.dart`:
   - `RsiWatchPointState` + `RsiWatchPointNotifier` (StateNotifier)
   - `rsiWatchPointProvider` — 감시점 목록 관리
   - `RsiDivergenceChecker` — 돌파 감지 로직
   - `rsiDivergenceCheckerProvider` — 싱글톤
   - `rsiDivergenceMonitorProvider` — 가격 변동 시 돌파 체크
2. `main_shell.dart` — `rsiDivergenceMonitorProvider` 리스너 등록 + RSI 계산 핸들러

**검증**: Provider 단위 테스트 — 돌파 교차 감지, 다이버전스 판정

### Phase 3: UI — 감시점 설정

1. `chart_sub_charts.dart` 수정 — `RsiDrawingOverlay`에 `displayData` (List<OHLCData>) + `scrollOffset` (int) 파라미터 전달
2. `rsi_drawing_overlay.dart` 수정 — `displayData` + `scrollOffset` 파라미터 수신, 롱프레스 시 X좌표 → 캔들 인덱스 → `displayData[index].close`(가격) + `rsiValues[index]`(RSI) 자동 스냅
3. `rsi_watch_point_sheet.dart` — 설정 바텀시트 (모드 선택, 자동 스냅된 가격/RSI 표시)
4. RSI 차트에 감시점 위치의 가격/RSI 값 정확 추출 로직 — **Y좌표 무시, X좌표(캔들)만 사용**

**검증**: Playwright MCP — 롱프레스 → 바텀시트 표시 → 설정 저장 흐름

### Phase 4: UI — 감시점 마커 + 자동 드로잉

1. `rsi_watch_point_marker.dart` — 삼각형 마커 CustomPainter
2. `rsi_drawing_overlay.dart` 수정 — 마커 렌더링 + 탭 상세 바텀시트
3. 다이버전스 확인 시 `RsiDrawingLine` 자동 생성 로직 (점선, 잠금 상태)

**검증**: Playwright MCP — 마커 표시, 자동 드로잉 선 생성 확인

### Phase 5: 통합 + 백업

1. `data_management_service.dart` — 백업 v4에 `rsiWatchPoints` 추가
2. 전체 흐름 E2E 테스트: 감시점 설정 → 가격 변동 → 알림 발생
3. 엣지 케이스: 앱 재시작 후 감시 재개, 비활성 감시점 무시, API 실패 시 graceful degradation

**검증**: 통합 테스트 — 백업/복원 포함 감시점 영속화, 전체 알림 흐름

---

## 10. 엣지 케이스 및 제약 사항

### 10.1 엣지 케이스

| 상황 | 처리 |
|------|------|
| 앱 재시작 후 | Hive에서 활성 감시점 로드 → 즉시 감시 재개 |
| 장 폐장 시 | 기존 `marketState == 'CLOSED'` 필터로 WS 데이터 무시 |
| 동일 종목 복수 감시점 | 허용 (서로 다른 가격/RSI 조합 가능) |
| interval 불일치 | 감시점 설정 시의 interval로 RSI 계산 (일봉 감시점은 일봉으로 체크) |
| Twelve Data API 실패 | 만료 캐시 사용 또는 다음 돌파 시 재시도 (기존 getChartData 3회 재시도 로직 활용) |
| Rate Limit 도달 | 기존 TwelveDataService의 7/min 보호 적용 |
| RSI 값 변경 미미 | 임계값 없음 — R2 vs R1의 대소만 비교 (사용자가 판단) |

### 10.2 제약 사항

- **실시간 RSI 계산이 아님**: WebSocket은 가격만 제공하므로, RSI는 돌파 시점에 API 호출로 계산. 실시간 RSI 스트리밍은 지원하지 않음.
- **분봉 감시점은 유효기간 제한 권장**: 1min/5min 감시점은 며칠 후 의미가 퇴색하므로, 생성 후 7일 경과 시 자동 비활성화 고려.
- **최대 감시점 수**: 종목당 5개, 전체 20개 권장 (API 부하 방지).
- **차트 interval 변경 시 마커**: 감시점의 interval과 현재 보고 있는 차트 interval이 다르면 마커 위치가 부정확할 수 있음. 동일 interval일 때만 마커 표시.

---

## 11. 향후 확장 가능성

- **Hidden Divergence 감지**: 추세 지속 시그널 (현재 설계는 Regular Divergence만)
- **RSI 외 다른 지표**: MACD, Stochastic 다이버전스로 확장 가능 (모델에 `indicatorType` 필드 추가)
- **다이버전스 강도 표시**: R1-R2 차이를 백분율로 표시하여 신호 강도 시각화
- **자동 감시점 제안**: RSI 고점/저점을 자동 탐지하여 사용자에게 감시점 설정 제안
