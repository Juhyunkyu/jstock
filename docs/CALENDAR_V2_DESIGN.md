# 투자 캘린더 V2 설계서

> **버전**: 1.0
> **작성일**: 2026-04-11
> **목표**: FRED 중심 핵심 지표 캘린더 + 실적 발표일 + 특수 이벤트

---

## 1. 개요

### 1.1 현재 → 변경 후

| 항목 | 현재 | V2 |
|------|------|-----|
| 경제 지표 | FRED 6개 + TV 잡다한 이벤트 (~500건/년) | **FRED 10개 핵심만** (~130건/년) |
| 예상(forecast) | TV 매칭 (불안정) | TV 매칭 (forecast만, 구조 동일) |
| 실제/전월 | TV > FRED 혼합 | **FRED 우선** (공식 데이터) |
| FOMC | 하드코딩 (연 1회 수동) | **FRED Release 21 API** (자동) |
| 휴장일 | 없음 | **규칙 기반 계산** (자동, "크리스마스 🔴 휴장") |
| 네 마녀의 날 | 없음 | **계산** (3/6/9/12월 셋째 금요일) |
| 실적 발표 | 관심종목만 | **주요 25개 상시 + 관심종목** |
| 한국어 매핑 | ~170개 수동 | **~15개** (FRED 서버 설정) |
| 설명 | ~130개 | **~15개** (핵심만) |

### 1.2 핵심 원칙
- **데이터 신뢰**: FRED 공식 데이터 우선, TV는 forecast만
- **핵심만 표시**: 토스증권/Webull 패턴 (주 3~5건)
- **수동 유지보수 0**: 모든 날짜 자동 계산 또는 API
- **무료 API만**: FRED (무제한), Finnhub (60/분), TV (무료)

---

## 2. 경제 지표 (FRED 10개)

### 2.1 시리즈 구성

| # | Release ID | 지표 | Series ID | Units | Decimals | 카테고리 | TV 키워드 |
|---|-----------|------|-----------|-------|----------|---------|----------|
| 1 | 10 | CPI 소비자물가지수 | CPIAUCSL | pch | 1 | inflation | `['inflation rate']` |
| 2 | 46 | PPI 생산자물가지수 | PPIFIS | pch | 1 | inflation | `['ppi mom', 'ppi yoy']` |
| 3 | 53 | GDP 성장률 | (없음) | - | - | gdp | `['gdp', 'gross domestic']` |
| 4 | 50 | 고용보고서 | PAYEMS | chg | 0 | employment | `['nonfarm', 'payroll']` |
| 5 | 9 | 소매판매 | RSAFS | pch | 1 | other | `['retail sales']` |
| 6 | 54 | PCE 개인소비지출 | PCEPI | pch | 1 | inflation | `['pce price', 'core pce']` |
| 7 | 28 | ISM 제조업 PMI | NAPM | lin | 1 | other | `['ism manufacturing']` |
| 8 | 29 | ISM 서비스업 PMI | NMFCI | lin | 1 | other | `['ism services']` |
| 9 | 320 | 미시간 소비자심리지수 | UMCSENT | lin | 1 | other | `['michigan consumer sentiment']` |
| 10 | 86 | 내구재 주문 | DGORDER | pch | 1 | other | `['durable goods']` |

> GDP(53)는 FRED Series 없음 (분기 데이터 매칭 불가). TV forecast에만 의존.

### 2.2 데이터 우선순위
```
forecast(예상) → TradingView만 (FRED에 없음)
actual(실제)   → FRED 시계열 > TradingView (이미 구현됨)
previous(전월) → FRED 시계열 > TradingView (이미 구현됨)
```

### 2.3 연간 빈도
- 월간 지표 9개 × 12 = 108건
- 미시간 속보+확정 = 추가 12건
- GDP 분기 = ~8건
- **합계: ~128건/년 (주 약 2.5건)**

---

## 3. FOMC (자동화)

### 3.1 현재 → V2
- 현재: `FOMC_DATES_2026` 하드코딩 배열
- V2: FRED Release ID **21** (FOMC 성명서)로 API 자동 조회

### 3.2 구현
`FRED_RELEASES`에 추가:
```js
{ id: 21, title: 'FOMC 금리결정', titleEn: 'FOMC Rate Decision', category: 'fomc', unit: '%' },
```

- FRED Series: 추가 안 함 (금리 시계열은 별도 구조)
- TV 키워드: 추가 안 함 (FOMC는 forecast 불필요)
- **삭제**: `FOMC_DATES_2026`, `buildFomcEvents()`

### 3.3 연간 빈도: 8건

---

## 4. NYSE 휴장일 (계산, 자동)

### 4.1 규칙

| 휴일 | 규칙 | 날짜 예시 |
|------|------|----------|
| 신년 | 1월 1일 | 고정 |
| MLK의 날 | 1월 셋째 월요일 | 계산 |
| 대통령의 날 | 2월 셋째 월요일 | 계산 |
| 성금요일 | 부활절 -2일 | 부활절 알고리즘 |
| 현충일 | 5월 마지막 월요일 | 계산 |
| 준틴스 | 6월 19일 | 고정 |
| 독립기념일 | 7월 4일 | 고정 |
| 노동절 | 9월 첫째 월요일 | 계산 |
| 추수감사절 | 11월 넷째 목요일 | 계산 |
| 크리스마스 | 12월 25일 | 고정 |

### 4.2 표시 형태
- 제목: `"크리스마스"` (휴일 이름)
- 카테고리: `holiday`
- 부제: `"🔴 뉴욕증시 휴장"`
- 주말이어도 그대로 표시 (관찰 이동 안 함)

### 4.3 연간 빈도: 10건

---

## 5. 네 마녀의 날 (계산, 자동)

### 5.1 규칙
- 3월, 6월, 9월, 12월 **셋째 금요일**
- 주가지수 선물/옵션 + 개별주식 선물/옵션 동시 만기

### 5.2 표시 형태
- 제목: `"네 마녀의 날"`
- 부제: `"선물·옵션 동시 만기일 — 변동성 주의"`
- 카테고리: `other`, importance: 2

### 5.3 연간 빈도: 4건

---

## 6. 실적 발표일

### 6.1 현재 상태 (이미 구현됨)
- Worker: Finnhub `/v1/calendar/earnings` 호출, KV 7일 캐시
- Flutter: `CalendarNotifier`에서 경제+실적 병합, **관심종목만 필터**
- Model: `EconomicEvent`에 `ticker`, `hour`, `epsEstimate`, `epsActual`, `revenueEstimate` 있음

### 6.2 변경 사항

#### A. 주요 기업 상시 표시 (Flutter만 수정)
현재: 관심종목에 없으면 안 보임
V2: 주요 25개 + 관심종목

```dart
const kMajorEarningsTickers = {
  // Mag 7
  'AAPL', 'MSFT', 'GOOGL', 'AMZN', 'META', 'NVDA', 'TSLA',
  // 반도체 (한국 투자자 선호)
  'AMD', 'AVGO', 'INTC', 'QCOM', 'MU', 'MRVL', 'ARM',
  // 주요 테크
  'NFLX', 'CRM', 'ADBE', 'ORCL',
  // 금융/헬스케어/소비재
  'JPM', 'BAC', 'GS', 'UNH', 'JNJ', 'PG', 'KO',
};
```

#### B. 필터 로직 변경
`calendar_providers.dart` 라인 142-147:
```dart
// 현재: watchlist + cycle tickers만
// V2: watchlist + cycle + major tickers
final majorOrWatchlist = watchlistTickers.union(kMajorEarningsTickers);
```

#### C. revenueActual 필드 추가
- Worker: Finnhub 응답에서 `revenueActual` 파싱 추가
- Model: `EconomicEvent`에 `revenueActual` 필드 추가

#### D. 표시 형태
- 발표 전: `"AAPL 실적발표 | 장후 | EPS 예상 $2.45"`
- 발표 후: `"AAPL | EPS $2.67 Beat ✅ (예상 $2.45)"`

### 6.3 Finnhub 특성
- 확정 날짜: 보통 **2~4주 전** (SEC 공시 기반)
- 대형 기업: 1~2개월 전 확인 가능
- 무료 한도: 60 req/min → 충분
- `hour`: bmo(장전), amc(장후), dmh(장중)

---

## 7. 코드 정리 (삭제 목록)

### 7.1 Backend (calendar.js)

| 삭제 | 이유 |
|------|------|
| `FOMC_DATES_2026` 상수 | FRED Release 21로 대체 |
| `buildFomcEvents()` 함수 | FRED Release 21로 대체 |
| `buildUnmatchedTvEvents()` 함수 | TV 단독 이벤트 안 보여줌 |
| `TV_REDUNDANT_TITLES` 상수 | TV 이벤트 필터 불필요 |
| `mapTvCategory()` 함수 | TV 이벤트 카테고리 매핑 불필요 |

### 7.2 Frontend (economic_event.dart)

| 삭제/축소 | 현재 | V2 |
|----------|------|-----|
| `_titleKoMap` | ~170개 | **삭제 가능** (FRED는 서버에서 한국어 title 설정) |
| `_autoTranslate()` | 패턴 번역 | **삭제** (TV 이벤트 안 보여줌) |
| `_fedNamesMap` | 17개 | **삭제** |
| `_bondTypeMap` | 3개 | **삭제** |
| `displayTitle` | 복잡한 폴백 | **`title` 직접 사용** |

> 주의: 실적 이벤트(earnings)의 제목은 Finnhub에서 영어로 옴 (ticker명).
> 이건 `displayTitle`이 아니라 별도 표시 로직 사용 중.

### 7.3 Frontend (economic_calendar_card.dart)

| 삭제/축소 | 현재 | V2 |
|----------|------|-----|
| `_eventDescriptions` | ~130개 | **~15개** (10 지표 + FOMC + 특수일) |

---

## 8. 구현 순서

### Phase 1: 백엔드 리팩토링 (calendar.js)
1. FRED 4개 추가 (ISM, Michigan, 내구재)
2. FOMC → FRED Release 21 전환
3. NYSE 휴장 계산 함수 추가
4. 네 마녀의 날 계산 함수 추가
5. `buildUnmatchedTvEvents` 삭제 + 관련 코드 정리
6. 배포 + API 테스트

### Phase 2: 프론트엔드 정리
1. `EventCategory.holiday` 추가 + 색상/아이콘
2. `_titleKoMap` 삭제 (또는 최소화)
3. `_autoTranslate`, `_fedNamesMap`, `_bondTypeMap` 삭제
4. `displayTitle` 단순화
5. `_eventDescriptions` 15개로 축소
6. 휴장일 표시 UI ("크리스마스 🔴 휴장")

### Phase 3: 실적 캘린더 개선
1. `kMajorEarningsTickers` 상수 추가
2. 필터 로직 변경 (watchlist + major)
3. `revenueActual` 필드 추가
4. 실적 서프라이즈 UI 개선

---

## 9. 최종 캘린더 구성

```
┌─ 경제 지표 (FRED 10개) ──────────────────┐
│ CPI, PPI, GDP, 고용, 소매, PCE            │
│ ISM 제조업, ISM 서비스, 미시간, 내구재     │
│ → TV에서 forecast만 매칭                   │
│ → ~128건/년                                │
├─ FOMC (FRED API 자동) ───────────────────┤
│ → ~8건/년                                  │
├─ 특수 이벤트 (계산, 자동) ────────────────┤
│ NYSE 휴장 ~10건 + 네 마녀의 날 4건         │
├─ 실적 발표 (Finnhub) ────────────────────┤
│ 주요 25개 + 관심종목                       │
│ EPS 예상/실제 + Beat/Miss                  │
└──────────────────────────────────────────┘
 총: ~150건/년 (경제) + 실적 (동적)
 API 비용: $0
```
