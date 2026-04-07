# 경제 캘린더 + 홈 화면 리디자인 설계서

**문서 버전**: 2.0  
**작성일**: 2026-04-06 (v2.0 업데이트: 2026-04-07)  
**목표**: 홈 화면에 글로벌 지표 마키(전광판) + 경제 캘린더 위젯 추가, 기존 GlobalIndicatorsCard/Grid 교체

> **v2.0 변경 사항**:
> - 전광판 지표 5개 → 10개 확장 (DXY, 구리, 천연가스, 은, NQ선물 추가)
> - 전광판 무한 루프 로직 개선 (끊김 해소)
> - FOMC 하드코딩 제거 → API 날짜 범위를 연말까지 확장하여 커버
> - 캘린더 목록 뷰: 월별 그룹핑 + 스크롤 가능
> - 캘린더 달력 뷰: 월 이동 네비게이션 추가
> - F&G + 캘린더 높이 매칭: IntrinsicHeight 제거 → 각 카드 자연 높이
> - 반응형 글씨 크기: fontScale(모바일 1.0, 태블릿 1.08, 데스크톱 1.16)

---

## 목차

1. [개요](#1-개요)
2. [현재 구조 분석](#2-현재-구조-분석)
3. [변경 요약](#3-변경-요약)
4. [글로벌 지표 마키 (전광판)](#4-글로벌-지표-마키-전광판)
5. [경제 캘린더 위젯](#5-경제-캘린더-위젯)
6. [반응형 레이아웃](#6-반응형-레이아웃)
7. [데이터 소스](#7-데이터-소스)
8. [Worker 변경 사항](#8-worker-변경-사항)
9. [데이터 모델](#9-데이터-모델)
10. [Flutter 앱 변경 사항](#10-flutter-앱-변경-사항)
11. [캐시 전략](#11-캐시-전략)
12. [엣지 케이스](#12-엣지-케이스)
13. [구현 순서](#13-구현-순서)
14. [관련 파일](#14-관련-파일)

---

## 1. 개요

### 문제 정의

현재 홈 화면의 글로벌 지표(WTI, 금, BTC, 10Y, VIX)는 정적인 카드/그리드 형태로 표시되어 화면 공간을 많이 차지하면서 정보 밀도가 낮다. 또한 한국 투자자에게 중요한 경제 일정(FOMC, CPI, 고용보고서 등)이 앱에 없어 별도 앱/사이트를 확인해야 한다.

### 해결 전략

1. **글로벌 지표 마키**: 기존 카드를 수평 스크롤 전광판으로 교체 → 공간 절약 + 정보 밀도 향상
2. **경제 캘린더 위젯**: 빈 공간에 경제 일정 + 실적 일정 위젯 배치 → 별도 앱 불필요
3. **레이아웃 리디자인**: Fear & Greed와 캘린더의 반응형 배치 최적화

---

## 2. 현재 구조 분석

### 홈 화면 레이아웃 (현재)

```
┌──────────────────────────────┐
│  AppBar (∞ Alpha Cycle + 🔔) │
├──────────────────────────────┤
│  "시장" + 환율칩 + 개장상태    │
├──────────────────────────────┤
│  IndexQuoteRow (NDX / SPX)   │
├──────────────────────────────┤
│  MarketIndexCard (차트 2개)   │
├──────────────────────────────┤
│  ┌────────────┬─────────┐    │  ← 데스크톱: 2:1 가로 배치
│  │ Fear&Greed │ 글로벌  │    │  ← 모바일: 세로 배치
│  │            │ 지표    │    │
│  └────────────┴─────────┘    │
├──────────────────────────────┤
│  MarketNewsSection           │
└──────────────────────────────┘
```

### 제거 대상

| 위젯 | 파일 | 사유 |
|------|------|------|
| `GlobalIndicatorsCard` | `global_indicators_panel.dart` | 마키로 교체 |
| `GlobalIndicatorsGrid` | `global_indicators_panel.dart` | 마키로 교체 |

> `GlobalIndicatorsPanel` (레거시)과 `_IndicatorRow`, `_CompactIndicatorTile` 등 관련 위젯은 마키 전환 후 제거. `_showIndicatorInfo`, `_showIndicatorDetail` BottomSheet는 마키 탭 시 재사용 가능.

---

## 3. 변경 요약

| 항목 | 현재 | 변경 후 |
|------|------|---------|
| 글로벌 지표 위치 | Fear&Greed 옆(데스크톱) / 아래(모바일) | **"시장" 헤더 아래, IndexQuoteRow 위** |
| 글로벌 지표 형태 | 카드/그리드 (정적) | **마키 전광판 (수평 스크롤 애니메이션)** |
| Fear&Greed 옆 공간 | 글로벌 지표 | **경제 캘린더 위젯** |
| 모바일 배치 순서 | Fear&Greed → 글로벌지표 | **캘린더 → Fear&Greed** (캘린더 우선) |

---

## 4. 글로벌 지표 마키 (전광판)

### 위치

"시장" 헤더와 `IndexQuoteRow` 사이.

```
"시장" + 환율칩 + 개장상태
────────────────────────────
 🛢️ WTI $61.23 ▲+1.2%  🥇 금 $3,035 ▼-0.3%  ₿ BTC $83,421 ▲+2.1% ...  →
────────────────────────────
IndexQuoteRow (NDX / SPX)
```

### 데이터

기존 `globalIndicatorsProvider`와 동일한 데이터를 사용:

| # | 심볼 | 라벨 | 소스 | 유형 |
|---|------|------|------|------|
| 1 | DCOILWTICO | WTI | FRED | 가격 (% 변동) |
| 2 | XAU/USD | 금 | Twelve Data | 가격 (% 변동) |
| 3 | BTC/USD | BTC | Twelve Data | 가격 (% 변동) |
| 4 | DGS10 | 10Y | FRED | 금리 (절대값 변동) |
| 5 | VIXCLS | VIX | FRED | 지수 (절대값 변동) |
| 6 | DTWEXBGS | DXY | FRED | 지수 (절대값 변동) |
| 7 | XCU/USD | 구리 | Twelve Data | 가격 (% 변동) |
| 8 | DHHNGSP | 천연가스 | FRED | 가격 (% 변동) |
| 9 | XAG/USD | 은 | Twelve Data | 가격 (% 변동) |
| 10 | NQ | NQ선물 | Twelve Data | 가격 (% 변동) |

> v2.0 추가 (6~10): DXY(달러인덱스), 구리(경기선행), 천연가스(에너지), 은(안전자산), NASDAQ선물(프리마켓)
> 각 지표 탭 시 상세 설명 BottomSheet 표시 (`_indicatorDetails` 맵에 정의)

### 동작

- **연속 스크롤**: `Ticker` 기반 프레임별 스크롤 (delta-time 보호 포함)
- **속도**: 초당 40px (사용자가 읽을 수 있는 속도)
- **터치/호버 시 일시정지**: `Listener.onPointerDown` / `MouseRegion.onEnter` → pause
- **탭**: 개별 지표 탭 시 `_showIndicatorDetail` BottomSheet 표시 (10개 모두 설명 포함)
- **높이**: 32px (컴팩트)
- **뷰포트 공통**: 모바일/태블릿/데스크톱 동일 레이아웃

### 구현 방식

```dart
class GlobalIndicatorsMarquee extends ConsumerStatefulWidget {
  // Ticker + SingleTickerProviderStateMixin (delta-time 기반)
  // 지표 목록을 4번 반복 렌더링하여 무한 루프 효과
  // ScrollController.jumpTo로 프레임별 이동
}
```

스크롤 로직 (v2.0 개선):
1. 지표 목록을 `Row`로 배치 (**4세트** 연결)
2. `Ticker._onTick()`에서 delta-time 기반 `jumpTo(offset + speed * dt)`
3. **1세트 너비** = `(maxScrollExtent + viewportDimension) / 4`
4. offset이 1세트 너비에 도달하면 `jumpTo(offset - oneSetWidth)` → **동일 화면 위치이므로 끊김 없음**
5. `Listener.onPointerDown` → pause, `onPointerUp` → resume
6. dt > 100ms 보호 (탭 복귀 시 큰 점프 방지)

---

## 5. 경제 캘린더 위젯

### 뷰 모드

`[목록 | 달력]` 토글 버튼으로 두 가지 뷰 전환:

#### 목록 (Timeline) — v2.0 월별 그룹핑

```
┌─────────────────────────────────┐
│  📅 주요 일정    [목록 | 달력]    │
├─────────────────────────────────┤
│  ── 4월 ──                       │
│  9  🔴 GDP 성장률         D-2   │
│  목     예상 2.1% (전월 1.6%)    │
│  9  🟠 PCE 개인소비지출    D-2   │
│  목                              │
│  10 🟠 CPI 소비자물가지수  D-3   │
│  목                              │
│  14 🟢 PPI 생산자물가지수  D-7   │
│  월                              │
│  ── 5월 ──                       │
│  2  🟢 비농업 고용지수     D-25  │
│  금                              │
│  ...                             │
└─────────────────────────────────┘
```

세부:
- **월별 그룹 헤더** (예: "── 4월 ──") 로 구분
- 오늘 이후의 **모든** 이벤트 표시 (기존 14일 → 연말까지)
- 스크롤 가능한 리스트 (`ConstrainedBox(maxHeight: 300)`)
- 카테고리 컬러 도트 (왼쪽)
- 이벤트명 + D-day 배지 (오른쪽)
- forecast/previous 값 (있을 때만)
- 실적: 티커 + bmo/amc 표시

#### 달력 (Mini Calendar C)

```
┌─────────────────────────────────┐
│  경제 일정      [목록 | 달력]     │
├─────────────────────────────────┤
│       ◀  2026년 4월  ▶          │
│  일  월  화  수  목  금  토      │
│           1   2   3   4   5     │
│   6   7   8   9  🔴 11  12     │
│                      10         │
│  13  14  15  16  17  18  19     │
│  20  21  22  23  24  25  26     │
│  27  28  29  30                 │
├─────────────────────────────────┤
│  4/10 (목) 선택됨:              │
│  🔴 FOMC 의사록 공개            │
│  🟠 CPI 소비자물가지수          │
└─────────────────────────────────┘
```

세부:
- **월 이동 네비게이션**: `◀ 2026년 4월 ▶` (현재 월 이전 불가, 12월까지)
- `_displayMonth` 상태로 표시 월 관리
- 월간 그리드 (7열)
- 이벤트 있는 날짜에 카테고리 컬러 도트 (날짜 아래)
- 같은 날 복수 이벤트 → 복수 도트 (최대 3개)
- 날짜 탭 → 아래에 해당 날짜 이벤트 목록 표시
- 기본 선택: 오늘 또는 가장 가까운 이벤트 날짜

### 카테고리 색상

| 카테고리 | 색상 | Hex | 한국어명 |
|----------|------|-----|---------|
| FOMC | 빨강 | `#F85149` | FOMC 관련 |
| Inflation (물가) | 주황 | `#F0883E` | CPI, PPI, PCE |
| Employment (고용) | 초록 | `#3FB950` | 비농업고용, 실업률 |
| Earnings (실적) | 파랑 | `#58A6FF` | 기업 실적 |
| GDP | 보라 | `#A371F7` | GDP, 소매판매 |
| Other | 회색 | `appTextHint` | 기타 |

> 다크 테마 기본 팔레트(GitHub Dark)와 조화를 이루는 색상. 라이트 테마에서도 충분한 대비.
> `app_colors.dart`에 `calendarFomc`, `calendarInflation` 등 정적 상수로 정의.

### D-day 배지 계산

```dart
String getDdayText(DateTime eventDate) {
  final today = DateTime.now();
  final diff = eventDate.difference(DateTime(today.year, today.month, today.day)).inDays;
  if (diff == 0) return 'D-DAY';
  if (diff > 0) return 'D-$diff';
  return 'D+${diff.abs()}'; // 지난 이벤트
}
```

- D-DAY: 빨간 배경
- D-1 ~ D-3: 주황 배경
- D-4+: 기본 배경

---

## 6. 반응형 레이아웃

### 모바일 (< 600px) — 세로 배치

```
┌──────────────────────────────┐
│  AppBar                       │
├──────────────────────────────┤
│  "시장" + 환율칩 + 개장상태    │
├──────────────────────────────┤
│  마키 (글로벌 지표 전광판)     │  ← NEW
├──────────────────────────────┤
│  IndexQuoteRow               │
├──────────────────────────────┤
│  MarketIndexCard (차트)       │
├──────────────────────────────┤
│  경제 캘린더 (full-width)     │  ← NEW (캘린더 먼저!)
├──────────────────────────────┤
│  Fear & Greed (full-width)    │  ← 캘린더 아래로 이동
├──────────────────────────────┤
│  MarketNewsSection           │
└──────────────────────────────┘
```

### 태블릿/데스크톱 (>= 600px) — 가로 배치

```
┌──────────────────────────────┐
│  AppBar                       │
├──────────────────────────────┤
│  "시장" + 환율칩 + 개장상태    │
├──────────────────────────────┤
│  마키 (글로벌 지표 전광판)     │  ← NEW
├──────────────────────────────┤
│  IndexQuoteRow               │
├──────────────────────────────┤
│  MarketIndexCard (차트)       │
├──────────────────────────────┤
│  ┌──────────┬──────────┐     │
│  │Fear&Greed│ 경제     │     │  ← 50:50 가로 배치
│  │  (50%)   │ 캘린더   │     │  ← 각 카드 자연 높이 (v2.0)
│  │          │  (50%)   │     │
│  └──────────┴──────────┘     │
├──────────────────────────────┤
│  MarketNewsSection           │
└──────────────────────────────┘
```

### 브레이크포인트

| 뷰포트 | 너비 | 레이아웃 |
|--------|------|---------|
| 모바일 | < 600px | 세로 (캘린더 → F&G) |
| 태블릿/데스크톱 | >= 600px | 가로 (F&G 50% + 캘린더 50%) |

> 기존 600px 브레이크포인트를 유지. Fear&Greed 비율을 기존 2:1에서 **1:1 (50:50)**로 변경 — 캘린더가 더 많은 정보를 표시해야 하므로 동일 공간 배분.

### 높이 매칭 (v2.0 변경)

- **v1.0**: `IntrinsicHeight` + `CrossAxisAlignment.stretch` → F&G 게이지 짤림 문제
- **v2.0**: `IntrinsicHeight` 제거, `CrossAxisAlignment.start` → 각 카드 자연 높이
  - F&G 게이지가 깨지지 않음
  - 캘린더는 내부 스크롤로 컨텐츠 표시

### 반응형 글씨 크기 (v2.0 추가)

캘린더 카드에 `_fontScale()` 적용:
| 뷰포트 | 너비 | fontScale |
|--------|------|-----------|
| 모바일 | < 600px | 1.0 |
| 태블릿 | 600~1024px | 1.08 |
| 데스크톱 | > 1024px | 1.16 |

모든 글씨 크기, 아이콘, 도트, 간격에 `* fs` 적용.

---

## 7. 데이터 소스

### 7.1 경제 캘린더 이벤트

#### FRED API (Release Dates)

기존 Worker에 FRED 핸들러(`src/handlers/fred.js`)가 있으므로 새 엔드포인트를 추가하는 것이 아니라, FRED의 **release/dates** API를 활용한다.

```
GET https://api.stlouisfed.org/fred/release/dates
  ?release_id=10       // CPI
  &sort_order=desc
  &limit=5
  &include_release_dates_with_no_data=true
  &api_key=XXX
  &file_type=json
```

응답 예시:
```json
{
  "release_dates": [
    { "release_id": 10, "date": "2026-04-10" },
    { "release_id": 10, "date": "2026-03-12" }
  ]
}
```

**주요 Release ID**:

| 지표 | FRED Release ID | 한국어명 | 카테고리 |
|------|----------------|---------|----------|
| CPI | 10 | 소비자물가지수 | inflation |
| Employment Situation | 50 | 고용보고서 (비농업고용) | employment |
| GDP | 53 | GDP 성장률 | gdp |
| PPI | 46 | 생산자물가지수 | inflation |
| Retail Sales | 9 | 소매판매 | gdp |
| PCE | 54 | 개인소비지출 | inflation |

#### TradingView Economic Calendar (Forecast/Previous 값)

```
POST https://economic-calendar.tradingview.com/events
Content-Type: application/x-www-form-urlencoded

from=2026-04-01&to=2026-04-30&countries=US
```

응답 예시:
```json
{
  "result": [
    {
      "title": "CPI m/m",
      "date": "2026-04-10T12:30:00Z",
      "actual": null,
      "forecast": 0.3,
      "previous": 0.4,
      "importance": 3,
      "category": "Prices",
      "country": "US"
    }
  ]
}
```

**병합 전략**: FRED dates (정확한 날짜) + TradingView (forecast/previous 값) → FRED 날짜를 기준으로 TradingView에서 같은 날짜+유사 이벤트 매칭하여 forecast/previous 보강.

#### FOMC 일정 (v2.0 변경)

~~v1.0: FOMC 하드코딩 + 연간 업데이트 방식~~

**v2.0**: FOMC 하드코딩 **제거**. Worker API(`/api/calendar/economic`)가 FRED release dates를 통해 FOMC 일정을 포함하여 반환하며, 요청 날짜 범위를 **연말(12/31)**까지 확장하여 연간 일정을 모두 커버.

- API 테스트 결과: `from=2026-04-07&to=2026-12-31` 요청 시 74개 이벤트 반환 (4월~12월)
- FOMC 관련 이벤트도 FRED release dates에 포함됨
- 하드코딩이 필요 없는 이유: 날짜가 매년 변동하며, API가 정확한 일정을 제공

### 7.2 실적 캘린더 (Earnings)

#### Finnhub Earnings Calendar

기존 Finnhub 핸들러(`src/handlers/finnhub.js`)에 earnings 엔드포인트 추가:

```
GET https://finnhub.io/api/v1/calendar/earnings
  ?from=2026-04-01
  &to=2026-04-30
  &token=XXX
```

응답 예시:
```json
{
  "earningsCalendar": [
    {
      "date": "2026-04-15",
      "epsActual": null,
      "epsEstimate": 0.89,
      "hour": "amc",
      "quarter": 1,
      "revenueActual": null,
      "revenueEstimate": 38000000000,
      "symbol": "NVDA",
      "year": 2026
    }
  ]
}
```

**필터링**: 사용자의 관심종목(watchlist) + 활성 사이클(cycle) 종목만 표시. 전체 실적 달력은 너무 방대.

---

## 8. Worker 변경 사항

### 8.1 새 핸들러: `src/handlers/calendar.js`

두 개의 엔드포인트:

#### `GET /api/calendar/economic?from=YYYY-MM-DD&to=YYYY-MM-DD`

처리 흐름:
1. KV에서 `calendar:economic:YYYY-MM` 캐시 확인
2. 캐시 미스 시:
   a. FRED release/dates 호출 (6개 Release ID 병렬)
   b. TradingView economic calendar 호출
   c. FRED 날짜 + TradingView forecast/previous 병합
   d. FOMC 하드코딩 일정 추가
   e. 날짜순 정렬 후 KV 저장
3. 응답 반환

```javascript
// calendar.js 핵심 로직 (의사코드)
export async function handleCalendar(request, env, url) {
  const subPath = url.pathname.replace('/api/calendar/', '');

  if (subPath === 'economic') {
    return handleEconomicCalendar(request, env, url);
  }
  if (subPath === 'earnings') {
    return handleEarningsCalendar(request, env, url);
  }
  return jsonError('Not found', 404, request);
}

async function handleEconomicCalendar(request, env, url) {
  const from = url.searchParams.get('from');
  const to = url.searchParams.get('to');
  const monthKey = from.substring(0, 7); // YYYY-MM
  const kvKey = `calendar:economic:${monthKey}`;

  // 1. KV 캐시 확인
  const cached = await env.CACHE_KV.get(kvKey, 'json');
  if (cached) return jsonResponse(cached, request);

  // 2. FRED release dates (병렬)
  const releaseIds = [10, 50, 53, 46, 9, 54]; // CPI, Employment, GDP, PPI, Retail, PCE
  const fredDates = await Promise.all(
    releaseIds.map(id => fetchFredReleaseDates(env, id, from, to))
  );

  // 3. TradingView events
  const tvEvents = await fetchTradingViewEvents(from, to);

  // 4. 병합 + FOMC 추가
  const merged = mergeCalendarData(fredDates.flat(), tvEvents, from, to);

  // 5. KV 저장 (30일 TTL)
  await env.CACHE_KV.put(kvKey, JSON.stringify(merged), { expirationTtl: 2592000 });

  return jsonResponse(merged, request);
}
```

#### `GET /api/calendar/earnings?from=YYYY-MM-DD&to=YYYY-MM-DD`

처리 흐름:
1. KV에서 `calendar:earnings:YYYY-MM` 캐시 확인
2. 캐시 미스 시 Finnhub earnings calendar 호출
3. KV 저장 후 응답 반환

```javascript
async function handleEarningsCalendar(request, env, url) {
  const from = url.searchParams.get('from');
  const to = url.searchParams.get('to');
  const monthKey = from.substring(0, 7);
  const kvKey = `calendar:earnings:${monthKey}`;

  const cached = await env.CACHE_KV.get(kvKey, 'json');
  if (cached) return jsonResponse(cached, request);

  const apiKey = env.FINNHUB_API_KEY;
  const resp = await fetch(
    `https://finnhub.io/api/v1/calendar/earnings?from=${from}&to=${to}&token=${apiKey}`
  );
  const data = await resp.json();

  await env.CACHE_KV.put(kvKey, JSON.stringify(data), { expirationTtl: 604800 }); // 7일

  return jsonResponse(data, request);
}
```

### 8.2 FRED Release Dates 헬퍼

FRED release/dates API 호출 + KV 캐시:

```javascript
async function fetchFredReleaseDates(env, releaseId, from, to) {
  const kvKey = `calendar:fred_dates:${releaseId}`;

  // KV 캐시 확인
  const cached = await env.CACHE_KV.get(kvKey, 'json');
  if (cached) return cached;

  const apiKey = env.FRED_API_KEY;
  const resp = await fetch(
    `https://api.stlouisfed.org/fred/release/dates?release_id=${releaseId}` +
    `&sort_order=desc&limit=12&include_release_dates_with_no_data=true` +
    `&api_key=${apiKey}&file_type=json`
  );
  const data = await resp.json();

  // 카테고리 매핑
  const category = RELEASE_CATEGORY_MAP[releaseId] || 'other';
  const name = RELEASE_NAME_MAP[releaseId] || `Release ${releaseId}`;
  const nameKo = RELEASE_NAME_KO_MAP[releaseId] || name;

  const dates = (data.release_dates || []).map(d => ({
    id: `fred-${releaseId}-${d.date}`,
    title: nameKo,
    titleEn: name,
    date: d.date,
    category,
    importance: RELEASE_IMPORTANCE[releaseId] || 2,
  }));

  // KV 저장 (30일 TTL)
  await env.CACHE_KV.put(kvKey, JSON.stringify(dates), { expirationTtl: 2592000 });

  return dates;
}
```

### 8.3 TradingView Economic Calendar 헬퍼

```javascript
async function fetchTradingViewEvents(from, to) {
  try {
    const resp = await fetch('https://economic-calendar.tradingview.com/events', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: `from=${from}T00:00:00Z&to=${to}T23:59:59Z&countries=US`,
    });
    if (!resp.ok) return [];
    const data = await resp.json();
    return data.result || [];
  } catch (e) {
    console.error('[Calendar] TradingView fetch failed:', e.message);
    return []; // TradingView 실패 시 FRED 날짜만으로 동작
  }
}
```

### 8.4 라우트 등록 (`src/index.js`)

```javascript
import { handleCalendar } from './handlers/calendar.js';

// index.js fetch 핸들러에 추가 (FRED 라우트 아래)
if (url.pathname.startsWith('/api/calendar/')) {
  return handleCalendar(request, env, url);
}
```

### 8.5 Cron 워밍 추가 (`src/cron/warming.js`)

`warmGlobalData()` 함수에 캘린더 워밍 추가:

```javascript
// warming.js — warmGlobalData() 끝에 추가

// Economic Calendar (월간 이벤트)
try {
  const now = new Date();
  const from = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-01`;
  const nextMonth = new Date(now.getFullYear(), now.getMonth() + 2, 0);
  const to = `${nextMonth.getFullYear()}-${String(nextMonth.getMonth() + 1).padStart(2, '0')}-${String(nextMonth.getDate()).padStart(2, '0')}`;

  // FRED release dates 워밍 (6개 Release ID)
  const releaseIds = [10, 50, 53, 46, 9, 54];
  await Promise.allSettled(
    releaseIds.map(id => fetchFredReleaseDates(env, id, from, to))
  );
  console.log('[Cron] Economic calendar FRED dates warmed');
} catch (e) {
  console.error('[Cron] Calendar warming failed:', e.message);
}
```

Cron 스케줄:
- **주말 Cron** (`0 12 * * SUN`): FRED release dates 워밍 (30일 TTL이므로 주 1회 충분)
- **Pre-market Cron** (`0 13 * * 1-5`): TradingView 이벤트 워밍 (forecast 값은 이벤트 직전에 나오므로 평일 워밍)

### 8.6 KV 스키마

| KV 키 | TTL | 설명 |
|--------|-----|------|
| `calendar:economic:YYYY-MM` | 30일 (2592000s) | 월간 경제 이벤트 (FRED + TradingView 병합) |
| `calendar:earnings:YYYY-MM` | 7일 (604800s) | 월간 실적 일정 (Finnhub) |
| `calendar:fred_dates:RELEASE_ID` | 30일 (2592000s) | FRED 개별 Release 일정 |
| `calendar:fomc_dates` | 365일 (31536000s) | FOMC 연간 일정 (수동 업데이트) |
| `calendar:tv_events:YYYY-MM` | 24시간 (86400s) | TradingView 원본 이벤트 (빈번 갱신) |

### 8.7 FRED Release 매핑 상수

```javascript
const RELEASE_CATEGORY_MAP = {
  10: 'inflation',    // CPI
  50: 'employment',   // Employment Situation
  53: 'gdp',          // GDP
  46: 'inflation',    // PPI
  9:  'gdp',          // Retail Sales
  54: 'inflation',    // PCE
};

const RELEASE_NAME_MAP = {
  10: 'CPI Consumer Price Index',
  50: 'Employment Situation (Nonfarm Payrolls)',
  53: 'GDP Growth Rate',
  46: 'PPI Producer Price Index',
  9:  'Retail Sales',
  54: 'PCE Personal Consumption Expenditures',
};

const RELEASE_NAME_KO_MAP = {
  10: 'CPI 소비자물가지수',
  50: '비농업 고용지수',
  53: 'GDP 성장률',
  46: 'PPI 생산자물가지수',
  9:  '소매판매',
  54: 'PCE 개인소비지출',
};

const RELEASE_IMPORTANCE = {
  10: 3,  // CPI — 최고 중요도
  50: 3,  // Employment — 최고 중요도
  53: 3,  // GDP — 최고 중요도
  46: 2,  // PPI
  9:  2,  // Retail Sales
  54: 2,  // PCE
};
```

---

## 9. 데이터 모델

### 9.1 EconomicEvent

```dart
/// 경제 캘린더 이벤트 모델
class EconomicEvent {
  final String id;           // "fred-10-2026-04-10" 또는 "earnings-NVDA-2026-04-15"
  final String title;        // "CPI 소비자물가지수"
  final String titleEn;      // "CPI Consumer Price Index"
  final DateTime date;
  final EventCategory category;
  final double? forecast;    // null = 아직 미발표
  final double? previous;
  final double? actual;      // null = 아직 미발표
  final String? unit;        // "%", "K", "$"
  final int importance;      // 0~3 (3 = 최고)
  final String? ticker;      // 실적 전용: "NVDA"
  final String? hour;        // 실적 전용: "bmo" (before market open) / "amc" (after market close)

  const EconomicEvent({
    required this.id,
    required this.title,
    required this.titleEn,
    required this.date,
    required this.category,
    this.forecast,
    this.previous,
    this.actual,
    this.unit,
    this.importance = 2,
    this.ticker,
    this.hour,
  });

  /// JSON 역직렬화
  factory EconomicEvent.fromJson(Map<String, dynamic> json) {
    return EconomicEvent(
      id: json['id'] as String,
      title: json['title'] as String,
      titleEn: json['titleEn'] as String? ?? json['title'] as String,
      date: DateTime.parse(json['date'] as String),
      category: EventCategory.fromString(json['category'] as String),
      forecast: (json['forecast'] as num?)?.toDouble(),
      previous: (json['previous'] as num?)?.toDouble(),
      actual: (json['actual'] as num?)?.toDouble(),
      unit: json['unit'] as String?,
      importance: json['importance'] as int? ?? 2,
      ticker: json['ticker'] as String?,
      hour: json['hour'] as String?,
    );
  }

  /// D-day 텍스트
  String get ddayText {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final eventDate = DateTime(date.year, date.month, date.day);
    final diff = eventDate.difference(todayDate).inDays;
    if (diff == 0) return 'D-DAY';
    if (diff > 0) return 'D-$diff';
    return 'D+${diff.abs()}';
  }

  /// 실적 이벤트 여부
  bool get isEarnings => category == EventCategory.earnings;

  /// 서프라이즈 여부 (actual 발표 후)
  String? get surprise {
    if (actual == null || forecast == null) return null;
    if (actual! > forecast!) return 'beat';
    if (actual! < forecast!) return 'miss';
    return 'inline';
  }
}
```

### 9.2 EventCategory

```dart
enum EventCategory {
  fomc,
  inflation,
  employment,
  earnings,
  gdp,
  other;

  /// Worker 응답 문자열 → enum 변환
  static EventCategory fromString(String value) {
    switch (value.toLowerCase()) {
      case 'fomc': return EventCategory.fomc;
      case 'inflation': return EventCategory.inflation;
      case 'employment': return EventCategory.employment;
      case 'earnings': return EventCategory.earnings;
      case 'gdp': return EventCategory.gdp;
      default: return EventCategory.other;
    }
  }

  /// 카테고리별 컬러 (app_colors.dart에 정의)
  Color get color {
    switch (this) {
      case EventCategory.fomc: return AppColors.calendarFomc;
      case EventCategory.inflation: return AppColors.calendarInflation;
      case EventCategory.employment: return AppColors.calendarEmployment;
      case EventCategory.earnings: return AppColors.calendarEarnings;
      case EventCategory.gdp: return AppColors.calendarGdp;
      case EventCategory.other: return AppColors.calendarOther;
    }
  }

  /// 카테고리 한국어명
  String get labelKo {
    switch (this) {
      case EventCategory.fomc: return 'FOMC';
      case EventCategory.inflation: return '물가';
      case EventCategory.employment: return '고용';
      case EventCategory.earnings: return '실적';
      case EventCategory.gdp: return 'GDP';
      case EventCategory.other: return '기타';
    }
  }
}
```

### 9.3 캘린더 색상 상수 (`app_colors.dart` 추가)

```dart
// EventCategory 색상 (GitHub Dark 팔레트 호환)
static const calendarFomc = Color(0xFFF85149);         // 빨강
static const calendarInflation = Color(0xFFF0883E);    // 주황
static const calendarEmployment = Color(0xFF3FB950);   // 초록
static const calendarEarnings = Color(0xFF58A6FF);     // 파랑 (darkAccent와 동일)
static const calendarGdp = Color(0xFFA371F7);          // 보라
static const calendarOther = Color(0xFF8B949E);        // 회색
```

> 라이트/다크 공용. 이 색상들은 배경 대비가 충분한 GitHub의 검증된 팔레트이므로 테마별 분기 불필요.

---

## 10. Flutter 앱 변경 사항

### 10.1 새 파일

| 파일 | 설명 |
|------|------|
| `lib/data/models/economic_event.dart` | `EconomicEvent` + `EventCategory` 모델 |
| `lib/data/services/api/calendar_service.dart` | Worker `/api/calendar/*` 호출 서비스 |
| `lib/presentation/providers/calendar_providers.dart` | 캘린더 Riverpod Provider |
| `lib/presentation/widgets/home/economic_calendar_card.dart` | 경제 캘린더 메인 위젯 (목록/달력 토글) |
| `lib/presentation/widgets/home/global_indicators_marquee.dart` | 마키 전광판 위젯 |

### 10.2 CalendarService

```dart
class CalendarService {
  final Dio _dio;

  CalendarService() : _dio = Dio() {
    ProxyConfig.addAuthInterceptor(_dio);
  }

  String get _baseUrl => ProxyConfig.useProxy
      ? '${ProxyConfig.proxyBase}/api/calendar'
      : throw UnsupportedError('Calendar requires proxy');

  /// 경제 이벤트 조회
  Future<List<EconomicEvent>> getEconomicEvents({
    required String from,
    required String to,
  }) async {
    final resp = await _dio.get('$_baseUrl/economic', queryParameters: {
      'from': from,
      'to': to,
    });
    final List<dynamic> events = resp.data['events'] ?? resp.data;
    return events.map((e) => EconomicEvent.fromJson(e)).toList();
  }

  /// 실적 이벤트 조회
  Future<List<EconomicEvent>> getEarningsEvents({
    required String from,
    required String to,
  }) async {
    final resp = await _dio.get('$_baseUrl/earnings', queryParameters: {
      'from': from,
      'to': to,
    });
    final List<dynamic> earnings = resp.data['earningsCalendar'] ?? [];
    return earnings.map((e) => _parseEarnings(e)).toList();
  }

  EconomicEvent _parseEarnings(Map<String, dynamic> json) {
    return EconomicEvent(
      id: 'earnings-${json['symbol']}-${json['date']}',
      title: '${json['symbol']} 실적발표',
      titleEn: '${json['symbol']} Earnings',
      date: DateTime.parse(json['date']),
      category: EventCategory.earnings,
      forecast: (json['epsEstimate'] as num?)?.toDouble(),
      actual: (json['epsActual'] as num?)?.toDouble(),
      unit: '\$',
      importance: 2,
      ticker: json['symbol'],
      hour: json['hour'],
    );
  }
}
```

### 10.3 ProxyConfig 추가 (`proxy_config.dart`)

```dart
// Calendar
static String? get calendarUrl =>
    useProxy ? '$proxyBase/api/calendar' : null;
```

### 10.4 Calendar Provider

```dart
/// CalendarService Provider
final calendarServiceProvider = Provider<CalendarService>((ref) {
  return CalendarService();
});

/// 캘린더 상태
class CalendarState {
  final List<EconomicEvent> events;
  final bool isLoading;
  final String? error;
  final DateTime selectedDate;

  const CalendarState({
    this.events = const [],
    this.isLoading = false,
    this.error,
    required this.selectedDate,
  });

  CalendarState copyWith({
    List<EconomicEvent>? events,
    bool? isLoading,
    String? error,
    DateTime? selectedDate,
  }) {
    return CalendarState(
      events: events ?? this.events,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      selectedDate: selectedDate ?? this.selectedDate,
    );
  }

  /// 선택 날짜의 이벤트
  List<EconomicEvent> get selectedDateEvents {
    return events.where((e) =>
      e.date.year == selectedDate.year &&
      e.date.month == selectedDate.month &&
      e.date.day == selectedDate.day
    ).toList();
  }

  /// 날짜별 이벤트 맵 (달력 뷰용)
  Map<DateTime, List<EconomicEvent>> get eventsByDate {
    final map = <DateTime, List<EconomicEvent>>{};
    for (final event in events) {
      final key = DateTime(event.date.year, event.date.month, event.date.day);
      (map[key] ??= []).add(event);
    }
    return map;
  }
}

/// CalendarNotifier — 경제 + 실적 이벤트 병합
class CalendarNotifier extends StateNotifier<CalendarState> {
  final CalendarService _service;
  final List<String> _watchlistTickers;

  CalendarNotifier(this._service, this._watchlistTickers)
      : super(CalendarState(selectedDate: DateTime.now()));

  /// 이벤트 로드 (현재 달 + 다음 달)
  Future<void> loadEvents() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final now = DateTime.now();
      final from = DateTime(now.year, now.month, 1);
      final to = DateTime(now.year, 12, 31); // v2.0: 연말까지 확장

      final fromStr = _dateStr(from);
      final toStr = _dateStr(to);

      // 경제 + 실적 병렬 로드
      final results = await Future.wait([
        _service.getEconomicEvents(from: fromStr, to: toStr),
        _service.getEarningsEvents(from: fromStr, to: toStr),
      ]);

      final economic = results[0];
      var earnings = results[1];

      // 실적: 관심종목/사이클 종목만 필터
      if (_watchlistTickers.isNotEmpty) {
        earnings = earnings.where(
          (e) => e.ticker != null && _watchlistTickers.contains(e.ticker)
        ).toList();
      }

      final allEvents = [...economic, ...earnings]
        ..sort((a, b) => a.date.compareTo(b.date));

      state = state.copyWith(events: allEvents, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: '일정 로드 실패');
    }
  }

  /// 날짜 선택 (달력 뷰)
  void selectDate(DateTime date) {
    state = state.copyWith(selectedDate: date);
  }

  String _dateStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

/// Calendar Provider
final calendarProvider =
    StateNotifierProvider<CalendarNotifier, CalendarState>((ref) {
  final service = ref.watch(calendarServiceProvider);
  // 관심종목 + 활성 사이클 종목 합산
  // (watchlist + cycle tickers)
  final watchlistTickers = <String>[]; // TODO: ref.watch(watchlistTickersProvider)
  return CalendarNotifier(service, watchlistTickers);
});
```

### 10.5 home_screen.dart 변경

```dart
// 변경 전:
//   SectionHeader → IndexQuoteRow → MarketIndexCard → F&G + GlobalIndicators → News

// 변경 후:
//   SectionHeader → Marquee → IndexQuoteRow → MarketIndexCard → (반응형: F&G + Calendar) → News
```

주요 변경:

1. `_loadMarketData()`에 `ref.read(calendarProvider.notifier).loadEvents()` 추가
2. `GlobalIndicatorsCard` / `GlobalIndicatorsGrid` 사용 부분 삭제
3. "시장" 헤더와 IndexQuoteRow 사이에 `GlobalIndicatorsMarquee()` 삽입
4. 하단 반응형 영역 재구성:

```dart
// 변경 후 반응형 영역
Builder(builder: (context) {
  final screenW = MediaQuery.sizeOf(context).width;
  final isDesktop = screenW >= 600;

  if (isDesktop) {
    // 데스크톱: Fear&Greed (50%) + Calendar (50%) 나란히
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: FearGreedCard(useOuterMargin: false, ...)),
            const SizedBox(width: 10),
            const Expanded(child: EconomicCalendarCard()),
          ],
        ),
      ),
    );
  }

  // 모바일: 캘린더 먼저 → Fear&Greed
  return Column(
    children: [
      const EconomicCalendarCard(),
      const SizedBox(height: 8),
      FearGreedCard(...),
    ],
  );
}),
```

---

## 11. 캐시 전략

### Worker 캐시 (KV)

| 데이터 | KV TTL | 갱신 주기 | 사유 |
|--------|--------|----------|------|
| FRED release dates | 30일 | 주말 Cron | 발표 일정은 거의 변경 안 됨 |
| TradingView events | 24시간 | Pre-market Cron | forecast 값은 이벤트 직전 업데이트 |
| Earnings calendar | 7일 | 주말 Cron | 실적 일정은 자주 변경되지 않음 |
| FOMC dates | 365일 | 수동 (연 1회) | 연초에 전체 일정 확정 |

### Flutter 앱 캐시 (메모리)

| 데이터 | 메모리 TTL | 사유 |
|--------|-----------|------|
| 경제 이벤트 목록 | 30분 | 홈 탭 재방문 시 빠른 표시 |
| 실적 이벤트 목록 | 30분 | 동일 |
| 마키 지표 | 기존 globalIndicatorsProvider 동일 | 변경 없음 |

### API 호출량 추정

| API | 일일 호출 (100명 기준) | 무료 한도 | 상태 |
|-----|----------------------|----------|------|
| FRED release/dates | 6회/주 (Cron) | 120회/분 | SAFE |
| TradingView calendar | 5~7회/일 (Cron) | 공개 API | SAFE |
| Finnhub earnings | 4~8회/주 | 60회/분 | SAFE |

> 모든 캘린더 API 호출은 Worker KV 캐시를 경유하므로, 사용자 수와 무관하게 원본 API 호출은 Cron 주기에만 발생.

---

## 12. 엣지 케이스

| 케이스 | 처리 |
|--------|------|
| 이번 주 예정 일정 없음 | "이번 주 예정된 일정이 없습니다" 메시지 + 빈 상태 아이콘 |
| forecast가 null | 날짜 + 이벤트명만 표시, 예상/이전 행 숨김 |
| actual 발표됨 | actual 값 표시 + 서프라이즈 표시 (beat: 초록, miss: 빨강, inline: 회색) |
| TradingView API 다운 | FRED 날짜만으로 동작 (forecast/previous 없이 날짜+이벤트명) |
| Worker 전체 장애 | 로딩 실패 UI + "새로고침" 버튼 |
| 로딩 중 | Skeleton shimmer 애니메이션 (기존 패턴 동일) |
| 달력에서 이벤트 없는 날 선택 | "이 날짜에 예정된 일정이 없습니다" |
| 같은 날 복수 이벤트 | 목록: 세로 스택, 달력: 복수 컬러 도트 (최대 3개, 초과 시 `+N`) |
| 달력에서 이벤트 없는 달 | 빈 달력 (도트 없음), 이벤트 목록 영역에 안내 메시지 |
| 실적: 관심종목 없음 | 실적 섹션 미표시 (경제 일정만) |
| 마키: 지표 로딩 중 | 마키 영역 높이 유지, 로딩 인디케이터 |
| 마키: 모든 지표 실패 | 마키 영역 숨김 (`SizedBox.shrink()`) |
| 프록시 미사용 모드 | 캘린더 기능 비활성화 (프록시 필수) |

---

## 13. 구현 순서

### Phase 1: Worker 백엔드 (캘린더 API)

| 작업 | 파일 | 예상 시간 |
|------|------|----------|
| 1-1. `calendar.js` 핸들러 생성 | `cloudflare-worker/src/handlers/calendar.js` | 60분 |
| 1-2. FRED release dates 조회 로직 | `calendar.js` 내부 | 30분 |
| 1-3. TradingView 프록시 로직 | `calendar.js` 내부 | 20분 |
| 1-4. Finnhub earnings 프록시 로직 | `calendar.js` 내부 | 15분 |
| 1-5. FRED + TradingView 병합 로직 | `calendar.js` 내부 | 30분 |
| 1-6. FOMC 하드코딩 일정 | `calendar.js` 내부 | 10분 |
| 1-7. KV 캐싱 레이어 | `calendar.js` 내부 | 20분 |
| 1-8. 라우트 등록 | `src/index.js` | 5분 |
| 1-9. Cron 워밍 추가 | `src/cron/warming.js` | 20분 |
| 1-10. 배포 + 수동 테스트 | `wrangler deploy` | 30분 |

**검증**:
- `curl https://alpha-cycle-proxy.xxx/api/calendar/economic?from=2026-04-01&to=2026-04-30`
- `curl https://alpha-cycle-proxy.xxx/api/calendar/earnings?from=2026-04-01&to=2026-04-30`
- KV 데이터 확인: `wrangler kv:key get --namespace-id=xxx "calendar:economic:2026-04"`

### Phase 2: Flutter 데이터 레이어

| 작업 | 파일 | 예상 시간 |
|------|------|----------|
| 2-1. `EconomicEvent` + `EventCategory` 모델 | `lib/data/models/economic_event.dart` | 30분 |
| 2-2. `CalendarService` 구현 | `lib/data/services/api/calendar_service.dart` | 30분 |
| 2-3. `ProxyConfig` calendar URL 추가 | `lib/data/services/api/proxy_config.dart` | 5분 |
| 2-4. `calendarProvider` 구현 | `lib/presentation/providers/calendar_providers.dart` | 40분 |
| 2-5. 캘린더 색상 상수 추가 | `lib/core/theme/app_colors.dart` | 5분 |

**검증**: Provider 단위 테스트 (데이터 파싱, 날짜 필터, D-day 계산)

### Phase 3: 글로벌 지표 마키

| 작업 | 파일 | 예상 시간 |
|------|------|----------|
| 3-1. `GlobalIndicatorsMarquee` 위젯 | `lib/presentation/widgets/home/global_indicators_marquee.dart` | 60분 |
| 3-2. AnimationController 연속 스크롤 | 위젯 내부 | (3-1에 포함) |
| 3-3. 터치/호버 일시정지 | 위젯 내부 | (3-1에 포함) |
| 3-4. 탭 시 상세 BottomSheet 연결 | 기존 `_showIndicatorDetail` 재사용 | 10분 |

**검증**: `./build.sh` 후 375px, 768px, 1280px 뷰포트에서 마키 스크롤 확인

### Phase 4: 경제 캘린더 위젯

| 작업 | 파일 | 예상 시간 |
|------|------|----------|
| 4-1. `EconomicCalendarCard` 메인 컨테이너 | `lib/presentation/widgets/home/economic_calendar_card.dart` | 30분 |
| 4-2. [목록/달력] 토글 버튼 | 위젯 내부 | 10분 |
| 4-3. Timeline 뷰 (목록 모드) | 위젯 내부 | 45분 |
| 4-4. Mini Calendar 뷰 (달력 모드) | 위젯 내부 | 60분 |
| 4-5. D-day 배지 | 위젯 내부 | 10분 |
| 4-6. 카테고리 컬러 도트 | 위젯 내부 | 10분 |
| 4-7. 실적 이벤트 bmo/amc 표시 | 위젯 내부 | 10분 |

**검증**: 목록/달력 모드 전환, 날짜 선택, D-day 계산, 빈 상태 처리

### Phase 5: 홈 화면 통합

| 작업 | 파일 | 예상 시간 |
|------|------|----------|
| 5-1. `GlobalIndicatorsCard`/`Grid` import 제거 | `home_screen.dart` | 5분 |
| 5-2. 마키 삽입 (시장 헤더 아래) | `home_screen.dart` | 10분 |
| 5-3. 하단 반응형 영역 재구성 | `home_screen.dart` | 30분 |
| 5-4. `_loadMarketData()`에 캘린더 로드 추가 | `home_screen.dart` | 5분 |
| 5-5. Fear&Greed 비율 1:1 변경 | `home_screen.dart` | 5분 |

**검증**: 3개 뷰포트(375, 768, 1280)에서 전체 레이아웃 확인

### Phase 6: 테스트 및 마무리

| 작업 | 설명 | 예상 시간 |
|------|------|----------|
| 6-1. 반응형 레이아웃 검증 | 375×812, 768×1024, 1280×800 | 30분 |
| 6-2. 다크 테마 검증 | 모든 색상이 `context.app*` 또는 정의된 상수 사용 확인 | 15분 |
| 6-3. 데이터 로딩/에러 상태 | 로딩 shimmer, 에러 메시지, 재시도 | 15분 |
| 6-4. 마키 성능 | 60fps 유지 확인, 메모리 누수 없음 | 15분 |
| 6-5. 레거시 위젯 정리 | `GlobalIndicatorsCard`, `Grid`, `Panel` 사용처 확인 후 제거 | 15분 |
| 6-6. 최종 빌드 + 배포 | `./build.sh` + GitHub Pages | 15분 |

### 총 예상 시간: ~13시간

---

## 14. 관련 파일

### 새 파일 (생성)

| 파일 | 설명 |
|------|------|
| `cloudflare-worker/src/handlers/calendar.js` | 캘린더 API 핸들러 |
| `lib/data/models/economic_event.dart` | 이벤트 데이터 모델 |
| `lib/data/services/api/calendar_service.dart` | 캘린더 API 서비스 |
| `lib/presentation/providers/calendar_providers.dart` | 캘린더 Riverpod Provider |
| `lib/presentation/widgets/home/economic_calendar_card.dart` | 경제 캘린더 위젯 |
| `lib/presentation/widgets/home/global_indicators_marquee.dart` | 마키 전광판 위젯 |

### 수정 파일

| 파일 | 변경 내용 |
|------|----------|
| `cloudflare-worker/src/index.js` | `/api/calendar/*` 라우트 추가 |
| `cloudflare-worker/src/cron/warming.js` | 캘린더 워밍 추가 |
| `lib/core/theme/app_colors.dart` | 캘린더 카테고리 색상 상수 추가 |
| `lib/data/services/api/proxy_config.dart` | `calendarUrl` getter 추가 |
| `lib/presentation/screens/home/home_screen.dart` | 레이아웃 리디자인 |

### 제거/미사용 전환 대상

| 파일/위젯 | 사유 |
|-----------|------|
| `GlobalIndicatorsCard` (in `global_indicators_panel.dart`) | 마키로 교체 |
| `GlobalIndicatorsGrid` (in `global_indicators_panel.dart`) | 마키로 교체 |

> `GlobalIndicatorsPanel`과 `_IndicatorRow`, `_showIndicatorInfo`, `_showIndicatorDetail`은 마키에서 재사용 가능하므로 파일 자체는 유지하되, 카드/그리드 위젯만 제거.

### 기존 유지 (변경 없음)

| 파일 | 이유 |
|------|------|
| `lib/presentation/providers/global_indicators_provider.dart` | 마키가 동일 Provider 사용 |
| `lib/data/services/api/fred_service.dart` | 기존 글로벌 지표 데이터 소스 유지 |
| `lib/data/services/api/twelve_data_service.dart` | 기존 금/BTC 데이터 소스 유지 |

### 참고 목업

| 파일 | 설명 |
|------|------|
| `claudedocs/calendar_mockup.html` | 초기 3가지 옵션 (A/B/C) |
| `claudedocs/calendar_mockup_v2.html` | 태블릿 레이아웃 + 마키 |
| `claudedocs/calendar_mockup_v3.html` | 반응형 전체 뷰포트 |
