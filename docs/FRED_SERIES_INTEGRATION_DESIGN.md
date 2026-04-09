# FRED 시계열 데이터 통합 설계서

**문서 버전**: 1.0  
**작성일**: 2026-04-09  
**목표**: FRED 시계열 API로 actual/previous 값을 안정적으로 확보, TradingView 의존도 감소

---

## 1. 문제 정의

### 현재 상태
| 소스 | 역할 | forecast | previous | actual |
|------|------|----------|----------|--------|
| FRED API | 발표 날짜만 | null | null | null |
| TradingView | 예상/전월/실제 | 있거나 없음 | 있거나 없음 | 발표 후 |
| FOMC | 하드코딩 날짜 | null | null | null |

**문제**: TradingView가 유일한 수치 소스인데:
1. 키워드 매칭 실패 시 → 전부 null
2. 과거 이벤트를 빠르게 삭제 (당일~1일 후)
3. forecast도 없는 경우가 많음
4. → 대부분의 이벤트에 수치가 없음

### 목표 상태
| 소스 | 역할 | forecast | previous | actual |
|------|------|----------|----------|--------|
| FRED 날짜 | 발표 날짜 | - | - | - |
| **FRED 시계열** | **actual/previous** | - | **항상 있음** | **항상 있음** |
| TradingView | forecast 보강 | 있으면 사용 | 폴백 | 폴백 |

**결과**: actual/previous는 FRED가 보장 (100%), forecast는 TradingView에서 있으면 넣고 없으면 비워둠

---

## 2. FRED 시계열 API

### 엔드포인트
```
GET https://api.stlouisfed.org/fred/series/observations
  ?series_id=CPIAUCSL
  &api_key=KEY
  &file_type=json
  &sort_order=desc
  &limit=24
  &units=pch          ← percent change (MoM)
```

### `units` 파라미터
| 값 | 의미 | 용도 |
|----|------|------|
| `pch` | 전기 대비 % 변동 | CPI MoM, PPI MoM, PCE MoM, Retail Sales MoM |
| `pc1` | 전년 대비 % 변동 | (필요 시 확장) |
| `chg` | 전기 대비 변동량 | Nonfarm Payrolls (K 단위) |
| (없음) | 원본 값 그대로 | GDP (이미 성장률 %) |

### Release → Series 매핑

| Release ID | 지표명 | series_id | units | 소수점 | 설명 |
|------------|--------|-----------|-------|--------|------|
| 10 | CPI 소비자물가지수 | `CPIAUCSL` | `pch` | 1 | CPI MoM % |
| 50 | 고용보고서 | `PAYEMS` | `chg` | 0 | 비농업 고용 변동 (K) |
| 53 | GDP 성장률 | `A191RL1Q225SBEA` | (없음) | 1 | 실질 GDP 분기 성장률 |
| 46 | PPI 생산자물가지수 | `PPIACO` | `pch` | 1 | PPI MoM % |
| 9 | 소매판매 | `RSAFS` | `pch` | 1 | 소매판매 MoM % |
| 54 | PCE 개인소비지출 | `PCEPI` | `pch` | 1 | PCE 물가 MoM % |

---

## 3. 발표 날짜 ↔ 시계열 데이터 매칭 로직

### 핵심 원리
FRED 시계열의 `date` 필드는 **관측 기간** (예: 2026-03-01 = 3월 데이터)이고, **발표 날짜**가 아님.
→ 발표 날짜(release date)와 관측값(observation)을 매칭하는 전략이 필요.

### 매칭 전략: 월간 지표 (CPI, PPI, PCE, 고용, 소매판매)
월간 지표는 release date와 observation이 1:1 대응.
```
release_dates (desc):  [2026-04-10, 2026-03-12, 2026-02-12, ...]
observations (desc):   [{date: 2026-03, val: 0.3}, {date: 2026-02, val: 0.4}, {date: 2026-01, val: 0.2}, ...]
```

**알고리즘 (월간)**:
```js
const today = new Date().toISOString().substring(0, 10);
let obsIdx = 0;

for (const releaseDate of releaseDates) {  // desc 정렬
  if (releaseDate > today) {
    // 미래 발표: actual 없음, previous만 (가장 최근 관측값)
    result[releaseDate] = { actual: null, previous: observations[0]?.value ?? null };
    // obsIdx 전진 안 함 — 아직 발표 안 된 데이터
  } else {
    // 과거/오늘 발표: actual + previous
    result[releaseDate] = {
      actual: observations[obsIdx]?.value ?? null,
      previous: observations[obsIdx + 1]?.value ?? null,
    };
    obsIdx++;  // 다음 release는 그 다음 observation
  }
}
```

### 매칭 전략: 분기 지표 (GDP)
GDP는 한 분기에 advance/second/third 3번 발표 → release dates가 observations보다 많음.
**해결**: `realtime_start` 파라미터로 각 발표 시점의 값을 직접 조회.

```js
// GDP 전용: release date마다 해당 시점의 관측값 조회
// FRED API: &realtime_start=RELEASE_DATE&realtime_end=RELEASE_DATE
// → 해당 발표일에 공개된 GDP 값 (advance=초기치, second=수정치, third=최종치)
//
// 또는 단순화: 모든 GDP release에 최신 observations[0] 사용
// (advance/second/third 모두 같은 분기 → 최신 수정치가 가장 정확)
```

**실용적 접근**: GDP release dates에는 모두 최신 관측값(observations[0])을 actual로,
observations[1]을 previous로 매핑. 이유:
- 사용자 관점에서 "GDP 2.1%" 표시가 중요 (advance/second/third 구분은 불필요)
- 최신 수정치가 가장 정확
- FRED는 기본적으로 최신 수정치를 반환 (`realtime_end=9999-12-31`)

### 반올림 처리
각 시리즈별 소수점 자릿수(`decimals`)에 맞춰 Worker에서 반올림 후 전달:
```js
const value = parseFloat(obs.value);
const rounded = parseFloat(value.toFixed(series.decimals));
```

### 발표일 캐시 바이패스
오늘이 요청 범위에 포함되면 FRED 시계열 캐시도 건너뜀 (TradingView와 동일):
- 발표일 당일 FRED 데이터가 1~2시간 후 업데이트됨
- 캐시 바이패스로 최신 actual 즉시 반영

---

## 4. 변경 범위

### Worker (`calendar.js`) — 변경
1. `FRED_SERIES` 매핑 상수 추가 (`{seriesId, units, decimals}` per release ID)
2. `fetchFredSeriesData(env, releaseId)` 함수 추가
   - KV 캐시 24시간, **오늘이 요청 범위에 포함되면 캐시 바이패스** (TV와 동일)
   - 반환: `{ actual: number|null, previous: number|null }` per release date
3. `handleEconomicCalendar()` — FRED 시계열을 기존 호출과 **병렬**로 가져옴
4. `mergeFredWithTradingView()` 확장 — 세 번째 파라미터로 시계열 데이터 받음
   - 병합 우선순위: `forecast: TV만`, `actual: TV > FRED시계열`, `previous: TV > FRED시계열`
   - 시계열 데이터 형태: `Map<releaseId, Map<releaseDateStr, {actual, previous}>>`

### Flutter — 변경 없음
- `EconomicEvent` 모델: 이미 forecast/actual/previous 지원
- UI: 이미 값이 있으면 표시, 없으면 생략하는 로직 동작 중
- Provider/Service: Worker 응답 형식 변경 없음

---

## 5. 캐시 전략

| KV 키 | TTL | 설명 |
|--------|-----|------|
| `calendar:fred_series:SERIES_ID` | 24시간 | 시계열 관측값 (최근 24개) |
| `calendar:fred_dates:RELEASE_ID` | 30일 | 기존 유지 |
| `calendar:tv_events:FROM_TO` | 4시간 | 기존 유지 (오늘 포함 시 캐시 건너뜀) |
| `calendar:day:YYYY-MM-DD` | 1년 | 기존 유지 (영구 보존) |

시계열 캐시 24시간 근거: FRED 경제지표는 월 1회 발표 → 24시간이면 충분
**발표일 바이패스**: 오늘이 요청 범위에 포함되면 시계열 캐시도 건너뜀 (TV와 동일 패턴)

---

## 6. 데이터 흐름 (변경 후)

```
┌─ FRED Release Dates ──────┐
│  날짜만 (forecast=null)    │
├────────────────────────────┤
│                            │
│  ┌─ FRED Series Data ──┐  │     ┌─ TradingView ──────┐
│  │ actual + previous   │  │     │ forecast (있으면)   │
│  │ (시계열 관측값)      │  │     │ actual/previous    │
│  └──────────┬──────────┘  │     └────────┬───────────┘
│             │             │              │
└─────────────┼─────────────┘              │
              │                            │
              └──────────┬─────────────────┘
                         │
                    mergeAllSources()
                         │
              ┌──────────▼──────────┐
              │  병합 우선순위:      │
              │  forecast: TV > null │
              │  actual:   TV > FRED │
              │  previous: TV > FRED │
              └──────────┬──────────┘
                         │
                    최종 이벤트 목록
```

**병합 우선순위**: TradingView 값이 있으면 사용 (더 세밀한 지표별 데이터), 없으면 FRED 시계열로 폴백

---

## 7. 구현 순서

1. Worker `calendar.js`에 `FRED_SERIES` 매핑 + `fetchFredSeriesData()` 추가
2. `handleEconomicCalendar()`에서 시계열 병렬 fetch 추가
3. `mergeFredWithTradingView()` 확장 — 시계열 actual/previous 폴백
4. Cron 워밍에 시계열 워밍 추가 (pre-market + post-market, TV 이벤트와 동일)
5. 배포 후 실제 데이터 검증 (FRED API 응답 값 확인)

---

## 8. 리스크 & 엣지 케이스

| 리스크 | 대응 |
|--------|------|
| FRED API 일일 호출 제한 (120/분) | 시리즈 6콜 + 날짜 6콜 + 글로벌(DXY,10Y) 2콜 = 최대 14콜/요청, 24시간 캐시로 충분 |
| 시계열 데이터 지연 | FRED는 보통 발표일 당일 업데이트, 1~2시간 지연 가능 → 오늘 포함 시 캐시 건너뜀 |
| GDP 분기 데이터 매칭 불일치 | release dates가 observations보다 많을 수 있음 → 인덱스 범위 체크 |
| series_id 변경/폐지 | CPIAUCSL 등은 수십년 유지된 핵심 시리즈, 변경 가능성 극히 낮음 |

---

## 9. 관련 파일

| 파일 | 변경 |
|------|------|
| `cloudflare-worker/src/handlers/calendar.js` | FRED 시계열 fetch + 병합 로직 |
| Flutter 측 변경 없음 | - |
