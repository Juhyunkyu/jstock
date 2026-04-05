# API 캐시 전략 설계서

> **문서 버전**: v1.1  
> **작성일**: 2026-04-05  
> **목표**: 무료 API 한도 내에서 1~5명 → 100명 사용자 확장  
> **핵심 전략**: Cloudflare Worker 공유 캐시(Cache API + KV) + Cron 캐시 워밍  
> **v1.1 변경**: 섹션 4 모듈화 설계 추가 (Worker 14-파일 분할 + Flutter ProxyConfig 중앙화)

---

## 목차

1. [개요](#1-개요)
2. [현재 아키텍처](#2-현재-아키텍처)
3. [목표 아키텍처](#3-목표-아키텍처)
4. [모듈화 설계 (Modularization Architecture)](#4-모듈화-설계-modularization-architecture)
5. [Cloudflare 무료 한도](#5-cloudflare-무료-한도)
6. [개선 1: Finnhub REST 프록시](#6-개선-1-finnhub-rest-프록시)
7. [개선 2: FMP 캐시 TTL 최적화](#7-개선-2-fmp-캐시-ttl-최적화)
8. [개선 3: DeepL 번역 공유 캐시](#8-개선-3-deepl-번역-공유-캐시)
9. [개선 4: Cron 캐시 워밍](#9-개선-4-cron-캐시-워밍)
10. [개선 5: Finnhub WebSocket 중계 (미래)](#10-개선-5-finnhub-websocket-중계-미래)
11. [개선 6: Exchange Rate 프록시 추가](#11-개선-6-exchange-rate-프록시-추가)
12. [KV 스키마 설계](#12-kv-스키마-설계)
13. [Worker 코드 변경 사항](#13-worker-코드-변경-사항)
14. [Flutter 앱 코드 변경 사항](#14-flutter-앱-코드-변경-사항)
15. [무료 한도 계산](#15-무료-한도-계산)
16. [구현 순서](#16-구현-순서)
17. [롤백 계획](#17-롤백-계획)
18. [모니터링](#18-모니터링)
19. [엣지 케이스](#19-엣지-케이스)

---

## 1. 개요

### 문제 정의

현재 Alpha Cycle 앱은 **브라우저별 독립 캐시** 구조로 동작한다. 각 사용자의 브라우저가 개별적으로 API를 호출하고 메모리/Hive에 캐시하므로, 사용자 수가 증가하면 **동일한 데이터에 대해 중복 API 호출**이 발생한다.

```
현재: 100명 × 같은 NVDA 시세 요청 = Finnhub에 100번 호출
목표: 100명 × 같은 NVDA 시세 요청 = Finnhub에 1번 호출 (Worker 캐시)
```

### 100명 사용 시 병목 분석

| API | 100명 일일 추정 | 무료 한도 | 상태 |
|-----|-----------------|-----------|------|
| Finnhub REST | ~500/min 피크 | 60/min | EXCEED |
| Finnhub WS | 100 동시접속 | 1 공식 | EXCEED |
| Twelve Data | ~300/day | 800/day | OK (피크 8/min 위험) |
| FMP | ~3,000/day | 250/day | EXCEED |
| DeepL | ~300K chars/mo | 500K chars/mo | RISKY |
| FRED | ~200/day | 120/min | SAFE |
| TradingView | ~200/day | 공개 | SAFE |
| CNN F&G | ~100/day | 공개 | SAFE |

### 해결 전략

1. **Worker 공유 캐시**: 모든 API 호출을 Worker 경유로 전환, Cache API + KV로 사용자 간 캐시 공유
2. **Cron 캐시 워밍**: 인기 종목 데이터를 사전 캐시하여 API 호출 최소화
3. **KV 영속 캐시**: Cache API 축출 대비 KV 백업으로 캐시 안정성 확보

---

## 2. 현재 아키텍처

### 2.1 아키텍처 다이어그램

```
┌─────────────────────────────────────────────────────────────────┐
│                        Flutter Web App (Browser)                │
│                                                                 │
│  ┌─────────────┐  ┌──────────────┐  ┌─────────────────────────┐ │
│  │ Memory Cache │  │  Hive Cache  │  │  API Services           │ │
│  │ (5~30min)   │  │ (translations)│  │                         │ │
│  └──────┬──────┘  └──────┬───────┘  │  finnhub_service.dart   │ │
│         │                │          │  exchange_rate_service   │ │
│         └────────┬───────┘          │  financial_service      │ │
│                  │                  │  twelve_data_service     │ │
│                  ▼                  │  news_service            │ │
│         ┌────────────────┐          │  fear_greed_service      │ │
│         │  앱 상태관리    │          │  fred_service            │ │
│         │  (Riverpod)    │          │  tradingview_service     │ │
│         └────────────────┘          │  finnhub_ws_service      │ │
│                                     └────────┬────────────────┘ │
└──────────────────────────────────────────────┼──────────────────┘
                                               │
                    ┌──────────────────────────┼──────────────────────┐
                    │                          │                      │
          ┌─────────▼──────────┐    ┌──────────▼─────────┐           │
          │   직접 호출 (Direct) │    │  Worker 경유 (Proxy)│           │
          │                    │    │                    │           │
          │ - Finnhub REST     │    │ - TwelveData 차트  │           │
          │   /quote           │    │ - FMP 재무제표      │           │
          │   /search          │    │ - Fear & Greed     │           │
          │   /company-news    │    │ - DeepL 번역       │           │
          │   /stock/profile2  │    │ - FRED 경제데이터   │           │
          │   /stock/metric    │    │ - RSS 뉴스         │           │
          │   /stock/earnings  │    │                    │           │
          │   /news (general)  │    └────────┬───────────┘           │
          │                    │             │                       │
          │ - Finnhub WS      │    ┌────────▼───────────┐           │
          │   wss://ws.finnhub │    │ Cloudflare Worker  │           │
          │                    │    │ (worker.js)        │           │
          │ - Exchange Rate    │    │                    │           │
          │   TwelveData Forex │    │ Cache API:         │           │
          │   open.er-api.com  │    │  - TwelveData 차트 │           │
          │   Frankfurter      │    │    (5min~6hr TTL)  │           │
          │                    │    │  - FMP 재무제표     │           │
          │ - TradingView      │    │    (24hr TTL)      │           │
          │   scanner API      │    │                    │           │
          └────────────────────┘    │ Header Cache:      │           │
                    │               │  - F&G (30min)     │           │
                    ▼               │  - FRED (1hr)      │           │
          ┌────────────────┐        │  - News (30min)    │           │
          │ 외부 API 서버들  │        └────────┬───────────┘           │
          │ (각각 API 키    │                 │                       │
          │  노출 위험)     │                 ▼                       │
          └────────────────┘        ┌────────────────┐               │
                                    │ 외부 API 서버들  │               │
                                    │ (키 보호됨)     │               │
                                    └────────────────┘               │
                                                                     │
                    ┌────────────────────────────────────────────────┘
                    │ Finnhub WS (직접 연결)
                    ▼
          ┌────────────────┐
          │ wss://ws.finnhub│
          │ (1 connection   │
          │  per browser)   │
          └────────────────┘
```

### 2.2 현재 서비스별 호출 경로 및 캐시

| 서비스 | 파일 | 호출 경로 | 캐시 | API 키 위치 |
|--------|------|-----------|------|-------------|
| Finnhub Quote | `finnhub_service.dart` | 직접 → `finnhub.io/api/v1/quote` | 없음 (Provider 레벨 5min) | 클라이언트 쿼리 `token=` |
| Finnhub Search | `finnhub_service.dart` | 직접 → `finnhub.io/api/v1/search` | 없음 | 클라이언트 쿼리 `token=` |
| Finnhub News | `finnhub_service.dart` | 직접 → `finnhub.io/api/v1/company-news` | 없음 | 클라이언트 쿼리 `token=` |
| Finnhub Profile | `finnhub_service.dart` | 직접 → `finnhub.io/api/v1/stock/profile2` | 없음 | 클라이언트 쿼리 `token=` |
| Finnhub Metrics | `financial_service.dart` | 직접 → `finnhub.io/api/v1/stock/metric` | 메모리 30min | 클라이언트 쿼리 `token=` |
| Finnhub Earnings | `financial_service.dart` | 직접 → `finnhub.io/api/v1/stock/earnings` | 메모리 30min | 클라이언트 쿼리 `token=` |
| Finnhub General News | `news_service.dart` | 직접 → `finnhub.io/api/v1/news` | 없음 | 클라이언트 쿼리 `token=` |
| Finnhub WS | `finnhub_websocket_service.dart` | 직접 → `wss://ws.finnhub.io` | N/A (스트리밍) | URL 쿼리 `token=` |
| Exchange Rate | `exchange_rate_service.dart` | 직접 → TwelveData/open.er-api/Frankfurter | Provider 레벨 5min | TwelveData: 쿼리 `apikey=` |
| TwelveData Chart | `twelve_data_service.dart` | Worker → `/api/twelvedata/chart` | Worker Cache API (5min~6hr) + 메모리 | Worker 서버사이드 |
| FMP Profile | `financial_service.dart` | Worker → `/api/fmp/profile` | Worker Cache API 24hr + 메모리 30min | Worker 서버사이드 |
| FMP Income | `financial_service.dart` | Worker → `/api/fmp/income-statement` | Worker Cache API 24hr + 메모리 30min | Worker 서버사이드 |
| Fear & Greed | `fear_greed_service.dart` | Worker → `/api/feargreed` | Header Cache 30min | 불필요 (공개) |
| DeepL | `news_service.dart` | Worker → `/api/deepl/translate` | Hive 영속 (브라우저별) | Worker 서버사이드 |
| FRED | `fred_service.dart` | Worker → `/api/fred/*` | Header Cache 1hr | Worker 서버사이드 |
| RSS News | `news_service.dart` | Worker → `/api/news/market`, `/api/news/korea` | Header Cache 30min | 불필요 (공개) |
| TradingView | `tradingview_service.dart` | 직접 → `scanner.tradingview.com` | 메모리 5min | 불필요 (공개) |
| MarketAux | `news_service.dart` | 직접 → `api.marketaux.com` | 없음 | 클라이언트 쿼리 `api_token=` |

### 2.3 현재 병목 지점

**Finnhub REST (CRITICAL)**
- 모든 사용자가 동일한 API 키로 직접 호출
- 60/min 한도를 100명이 공유 → 피크 시간에 즉시 초과
- API 키가 클라이언트 JavaScript에 노출됨 (보안 문제)

**FMP (CRITICAL)**
- Worker Cache API는 24hr TTL이지만 Cloudflare가 임의 축출 가능
- 캐시 미스 시 250/day 한도를 빠르게 소진
- profile + income-statement를 종목마다 호출

**DeepL (WARNING)**
- 브라우저별 Hive 번역 캐시 → 사용자 간 공유 불가
- 100명이 같은 뉴스 제목을 각각 번역 요청

---

## 3. 목표 아키텍처

### 3.1 아키텍처 다이어그램

```
┌─────────────────────────────────────────────────────────────────┐
│                   Flutter Web App (Browser × 100)               │
│                                                                 │
│  ┌─────────────┐  ┌──────────────┐  ┌─────────────────────────┐ │
│  │ Memory Cache │  │  Hive Cache  │  │  API Services           │ │
│  │ (로컬 1차)   │  │ (로컬 영속)   │  │                         │ │
│  └──────┬──────┘  └──────┬───────┘  │  모든 서비스가            │ │
│         │                │          │  Worker를 경유            │ │
│         └────────┬───────┘          │  (직접 호출 제거)         │ │
│                  ▼                  └────────┬────────────────┘ │
│         ┌────────────────┐                   │                  │
│         │  Riverpod      │                   │                  │
│         └────────────────┘                   │                  │
└──────────────────────────────────────────────┼──────────────────┘
                                               │
                                    ┌──────────▼───────────┐
                                    │   Cloudflare Worker   │
                                    │   (src/ 모듈 구조)     │
                                    │                       │
                                    │ ┌───────────────────┐ │
                                    │ │ Rate Limiter       │ │
                                    │ │ (Finnhub 60/min)  │ │
                                    │ └─────────┬─────────┘ │
                                    │           │           │
                                    │ ┌─────────▼─────────┐ │
                                    │ │  Cache Layer       │ │
                                    │ │                    │ │
                                    │ │  1st: KV (영속)    │ │
                                    │ │  2nd: Cache API    │ │
                                    │ │  3rd: API 원본     │ │
                                    │ └─────────┬─────────┘ │
                                    │           │           │
                                    │ ┌─────────▼─────────┐ │
                                    │ │  KV Storage        │ │
                                    │ │                    │ │
                                    │ │  quotes, profiles, │ │
                                    │ │  translations,     │ │
                                    │ │  exchange rates,   │ │
                                    │ │  warm tickers...   │ │
                                    │ └───────────────────┘ │
                                    │                       │
                                    │ ┌───────────────────┐ │
                                    │ │  Cron Triggers     │ │
                                    │ │  UTC 13:30 (개장)  │ │
                                    │ │  UTC 17:00 (폐장)  │ │
                                    │ └───────────────────┘ │
                                    └───────────┬───────────┘
                                                │
                              ┌──────────────────┼──────────────────┐
                              ▼                  ▼                  ▼
                    ┌──────────────┐   ┌──────────────┐   ┌──────────────┐
                    │  Finnhub     │   │  FMP         │   │  TwelveData  │
                    │  (60/min)    │   │  (250/day)   │   │  (8/min)     │
                    └──────────────┘   └──────────────┘   └──────────────┘
                              ▼                  ▼                  ▼
                    ┌──────────────┐   ┌──────────────┐   ┌──────────────┐
                    │  DeepL       │   │  FRED        │   │  CNN/RSS     │
                    │  (500K/mo)   │   │  (120/min)   │   │  (공개)      │
                    └──────────────┘   └──────────────┘   └──────────────┘


        ※ 예외: Finnhub WebSocket은 당분간 직접 연결 유지
           (Durable Objects 유료 전환 시 중계 서버 도입)

        ※ 예외: TradingView Scanner는 직접 호출 유지
           (공개 API, 키 불필요, CORS 지원)
```

### 3.2 캐시 계층 구조

```
요청 흐름:

  Browser        Worker               KV              Cache API        외부 API
    │               │                  │                  │                │
    ├──GET /api/──▶│                  │                  │                │
    │               ├──KV.get()──────▶│                  │                │
    │               │◀──HIT───────────┤                  │                │
    │◀──200 JSON────┤                  │                  │                │
    │               │                  │                  │                │
    │  (KV MISS 시)  │                  │                  │                │
    │               ├──cache.match()──────────────────▶│                │
    │               │◀──HIT────────────────────────────┤                │
    │◀──200 JSON────┤                  │                  │                │
    │               │                  │                  │                │
    │  (Cache MISS 시) │                │                  │                │
    │               ├──fetch()──────────────────────────────────────▶│
    │               │◀──200 JSON────────────────────────────────────┤
    │               ├──KV.put()──────▶│  (영속 저장)      │                │
    │               ├──cache.put()────────────────────▶│  (TTL 저장)    │
    │◀──200 JSON────┤                  │                  │                │
```

**캐시 우선순위 (데이터 유형별)**:

| 데이터 유형 | 1차 (KV) | 2차 (Cache API) | 3차 (API) | 이유 |
|-------------|----------|-----------------|-----------|------|
| 주가 시세 (quote) | TTL 5min | TTL 5min | Finnhub | 실시간성 중요, KV 쓰기 절약을 위해 Cron에서만 KV 기록 |
| 기업 프로필 (profile) | TTL 7일 | TTL 24hr | FMP | 거의 불변, KV 영속이 핵심 |
| 손익계산서 (income) | TTL 30일 | TTL 24hr | FMP | 분기별 변경, KV 영속이 핵심 |
| 검색 (search) | - | TTL 1hr | Finnhub | 쿼리 다양, KV 쓰기 낭비 방지 |
| 종목 뉴스 (company-news) | - | TTL 30min | Finnhub | 빈번히 변경, Cache API로 충분 |
| 재무 지표 (metric) | TTL 24hr | TTL 24hr | Finnhub | 일 1회 변경, KV 안정 |
| EPS 실적 (earnings) | TTL 7일 | TTL 24hr | Finnhub | 분기별 변경 |
| 번역 (translate) | 무기한 | - | DeepL | 번역 불변, KV 영속이 핵심 |
| 환율 (exchange rate) | TTL 10min | TTL 10min | TwelveData | 장중 빈번 변동 |
| 차트 (chart) | - | TTL 5min~6hr | TwelveData | 기존 Cache API 유지 |
| F&G 지수 | TTL 1hr | TTL 30min | CNN | 하루 1회 변경 |
| FRED 데이터 | TTL 1hr | TTL 1hr | FRED | 하루 1회 변경 |
| RSS 뉴스 | - | TTL 30min | RSS | 빈번히 변경, Cache API로 충분 |

---

## 4. 모듈화 설계 (Modularization Architecture)

> **목적**: 현재 단일 `worker.js`(593줄)에 ~620줄을 추가하면 ~1,213줄이 되어 유지보수가 어려워진다. 모듈화하여 핸들러별 독립 파일로 분리하고, Flutter 앱 측에서도 프록시 URL 분기를 중앙화한다.  
> **원칙**: 각 핸들러는 독립적, 공유 유틸은 무의존성, 순환 참조 금지

### 4.1 Worker 모듈 구조

```
cloudflare-worker/
├── src/
│   ├── index.js              ← 엔트리 포인트: 라우터 + scheduled 핸들러 (~80줄)
│   ├── handlers/
│   │   ├── finnhub.js        ← handleFinnhub + getFinnhubCacheConfig (~180줄)
│   │   ├── fmp.js            ← handleFMP + getFMPKVConfig (~120줄)
│   │   ├── deepl.js          ← handleDeepL + hashText (~130줄)
│   │   ├── exchange-rate.js  ← handleExchangeRate + 3-API 폴백 체인 (~130줄)
│   │   ├── news.js           ← handleMarketNews + RSS 파싱 + 중복제거 (~200줄)
│   │   ├── twelvedata.js     ← handleTwelveData (~80줄)
│   │   ├── fred.js           ← handleFRED (~50줄)
│   │   └── feargreed.js      ← handleFearGreed (~50줄)
│   ├── cron/
│   │   └── warming.js        ← scheduled 핸들러 + warmFinnhubQuotes + warmFMPProfiles + warmGlobalData (~200줄)
│   └── utils/
│       ├── cors.js           ← ALLOWED_ORIGINS, corsHeaders(request) (~25줄)
│       ├── cache.js          ← getCached, setCached 통합 캐시 헬퍼 (~60줄)
│       ├── rate-limiter.js   ← canCall, recordCall (~30줄)
│       └── helpers.js        ← jsonError, sleep, hashText (~30줄)
├── wrangler.toml             ← KV 바인딩, cron 트리거, env vars
└── package.json              ← type: "module"
```

**총 줄 수 분산**:

| 디렉토리 | 파일 수 | 총 줄 수 | 평균 줄/파일 |
|----------|---------|----------|-------------|
| `src/` (index.js) | 1 | ~80 | 80 |
| `src/handlers/` | 8 | ~940 | ~118 |
| `src/cron/` | 1 | ~200 | 200 |
| `src/utils/` | 4 | ~145 | ~36 |
| **합계** | **14** | **~1,365** | **~98** |

> 단일 파일 1,213줄 → 14개 파일 평균 98줄. 가장 큰 파일도 200줄 이하.

### 4.2 공유 유틸리티 상세 (utils/)

#### `src/utils/cors.js`

```javascript
/**
 * CORS 허용 오리진 및 헤더 생성
 * 
 * @exports ALLOWED_ORIGINS - 허용된 오리진 배열
 * @exports corsHeaders     - 요청 기반 CORS 헤더 생성
 * @imports 없음 (외부 의존성 제로)
 */

const ALLOWED_ORIGINS = [
  'https://juhyunkyu.github.io',
  'http://localhost:8080',
  'http://localhost:3000',
];

/**
 * 요청의 Origin 헤더를 검사하여 CORS 응답 헤더를 생성한다.
 * 허용되지 않은 오리진이면 빈 객체를 반환한다.
 * 
 * @param {Request} request - 들어온 HTTP 요청
 * @returns {Object} CORS 헤더 객체 또는 빈 객체
 */
export function corsHeaders(request) {
  const origin = request.headers.get('Origin') || '';
  if (!ALLOWED_ORIGINS.includes(origin)) return {};
  return {
    'Access-Control-Allow-Origin': origin,
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
    'Access-Control-Max-Age': '86400',
  };
}

export { ALLOWED_ORIGINS };
```

#### `src/utils/cache.js`

> **핵심 모듈**: 모든 핸들러가 KV + Cache API를 독립 구현하면 버그가 발생한다. 이 모듈이 캐시 조회/저장 로직을 통합하여 일관성을 보장한다.

```javascript
/**
 * 통합 캐시 레이어 (KV + Cache API)
 *
 * @exports getCached  - KV → Cache API 순서로 캐시 조회
 * @exports setCached  - KV + Cache API에 동시 저장
 * @imports 없음 (외부 의존성 제로)
 */

/**
 * 통합 캐시 조회: KV 우선 → Cache API 차순
 * 
 * @param {Object} env       - Worker 환경 (env.CACHE_KV)
 * @param {string|null} kvKey    - KV 키 (null이면 KV 건너뜀)
 * @param {Request|null} cacheKey - Cache API 키 (null이면 Cache API 건너뜀)
 * @returns {Promise<{data: string|null, source: string}>}
 *   - data: 캐시 히트 시 JSON 문자열, 미스 시 null
 *   - source: 'KV-HIT' | 'HIT' | 'MISS'
 */
export async function getCached(env, kvKey, cacheKey) {
  // 1차: KV
  if (kvKey && env.CACHE_KV) {
    try {
      const kvData = await env.CACHE_KV.get(kvKey, 'text');
      if (kvData) return { data: kvData, source: 'KV-HIT' };
    } catch (e) { /* KV 실패 시 무시, 다음 레이어로 */ }
  }

  // 2차: Cache API
  if (cacheKey) {
    try {
      const cache = caches.default;
      const cachedResponse = await cache.match(cacheKey);
      if (cachedResponse) {
        const text = await cachedResponse.text();
        return { data: text, source: 'HIT' };
      }
    } catch (e) { /* Cache API 실패 시 무시 */ }
  }

  return { data: null, source: 'MISS' };
}

/**
 * 통합 캐시 저장: KV + Cache API에 동시 저장
 * 
 * @param {Object} env       - Worker 환경 (env.CACHE_KV)
 * @param {string|null} kvKey    - KV 키 (null이면 KV 저장 건너뜀)
 * @param {number|null} kvTTL    - KV TTL (초 단위)
 * @param {Request|null} cacheKey - Cache API 키 (null이면 Cache API 건너뜀)
 * @param {number} cacheTTL      - Cache API TTL (초 단위, Cache-Control max-age)
 * @param {string} data          - 저장할 JSON 문자열
 */
export async function setCached(env, kvKey, kvTTL, cacheKey, cacheTTL, data) {
  const promises = [];

  // KV 저장
  if (kvKey && env.CACHE_KV) {
    const kvPromise = env.CACHE_KV.put(kvKey, data, 
      kvTTL ? { expirationTtl: kvTTL } : undefined
    ).catch(e => console.error('[KV] Write failed:', e.message));
    promises.push(kvPromise);
  }

  // Cache API 저장
  if (cacheKey && cacheTTL) {
    const responseToCache = new Response(data, {
      status: 200,
      headers: {
        'Content-Type': 'application/json',
        'Cache-Control': `public, max-age=${cacheTTL}`,
      },
    });
    const cachePromise = caches.default.put(cacheKey, responseToCache)
      .catch(e => console.error('[Cache API] Write failed:', e.message));
    promises.push(cachePromise);
  }

  await Promise.allSettled(promises);
}
```

#### `src/utils/rate-limiter.js`

```javascript
/**
 * Finnhub API Rate Limiter (메모리 기반, Worker 인스턴스별)
 *
 * @exports canCall     - 현재 호출 가능 여부 확인
 * @exports recordCall  - 호출 기록
 * @imports 없음
 *
 * 참고: Worker는 여러 인스턴스에서 실행될 수 있으므로 완벽하지 않지만,
 * 한국 사용자 100명은 대부분 같은 리전이고 캐시 히트율이 높으면 충분함.
 */

const state = {
  calls: [],          // 최근 1분간 API 호출 timestamp
  maxPerMinute: 55,   // 60 한도에서 여유분 5 확보
};

/**
 * 최근 1분간 호출 횟수를 확인하여 추가 호출 가능 여부를 반환한다.
 * @returns {boolean}
 */
export function canCall() {
  const now = Date.now();
  state.calls = state.calls.filter(t => now - t < 60_000);
  return state.calls.length < state.maxPerMinute;
}

/**
 * API 호출 시각을 기록한다. fetch() 직전에 호출해야 한다.
 */
export function recordCall() {
  state.calls.push(Date.now());
}
```

#### `src/utils/helpers.js`

```javascript
/**
 * 범용 유틸리티 함수
 *
 * @exports jsonError  - JSON 형식 에러 응답 생성
 * @exports sleep      - 지정 시간 대기
 * @exports hashText   - SHA-256 해시 (번역 캐시 키용)
 * @imports corsHeaders from './cors.js'
 */

import { corsHeaders } from './cors.js';

/**
 * JSON 에러 응답을 생성한다.
 * @param {string} message - 에러 메시지
 * @param {number} status  - HTTP 상태 코드
 * @param {Request} request - 원본 요청 (CORS 헤더 생성용)
 * @returns {Response}
 */
export function jsonError(message, status, request) {
  return new Response(JSON.stringify({ error: message }), {
    status,
    headers: { 'Content-Type': 'application/json', ...corsHeaders(request) },
  });
}

/**
 * 지정 밀리초만큼 대기한다.
 * @param {number} ms - 대기 시간 (밀리초)
 * @returns {Promise<void>}
 */
export function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

/**
 * 텍스트의 SHA-256 해시를 생성한다 (hex 앞 16자).
 * 번역 캐시 키로 사용되며, 충돌 확률이 충분히 낮다.
 * @param {string} text - 해시할 텍스트
 * @returns {Promise<string>} 16자 hex 문자열
 */
export async function hashText(text) {
  const encoder = new TextEncoder();
  const data = encoder.encode(text);
  const hashBuffer = await crypto.subtle.digest('SHA-256', data);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  return hashArray.slice(0, 8).map(b => b.toString(16).padStart(2, '0')).join('');
}
```

### 4.3 index.js 라우터 설계

```javascript
/**
 * Alpha Cycle API Proxy — Cloudflare Worker (모듈화 버전)
 *
 * 엔트리 포인트: 라우터 + scheduled 핸들러
 * 모든 비즈니스 로직은 handlers/ 와 cron/ 에 위치한다.
 *
 * @imports handlers/* - 각 API 핸들러
 * @imports cron/warming.js - Cron 캐시 워밍
 * @imports utils/cors.js - CORS 처리
 * @imports utils/helpers.js - jsonError
 */

import { handleFinnhub } from './handlers/finnhub.js';
import { handleFMP } from './handlers/fmp.js';
import { handleDeepL } from './handlers/deepl.js';
import { handleExchangeRate } from './handlers/exchange-rate.js';
import { handleMarketNews, GLOBAL_RSS_FEEDS, KOREA_RSS_FEEDS } from './handlers/news.js';
import { handleTwelveData } from './handlers/twelvedata.js';
import { handleFRED } from './handlers/fred.js';
import { handleFearGreed } from './handlers/feargreed.js';
import { runCacheWarming } from './cron/warming.js';
import { corsHeaders } from './utils/cors.js';
import { jsonError } from './utils/helpers.js';

export default {
  async fetch(request, env) {
    // Preflight
    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: corsHeaders(request) });
    }

    const url = new URL(request.url);

    // ── 라우트 매칭 ──
    // Finnhub (NEW)
    if (url.pathname.startsWith('/api/finnhub/')) {
      return handleFinnhub(request, env, url);
    }
    // Exchange Rate (NEW)
    if (url.pathname === '/api/exchange-rate') {
      return handleExchangeRate(request, env, url);
    }
    // FMP (기존, KV 레이어 추가)
    if (url.pathname.startsWith('/api/fmp/')) {
      return handleFMP(request, env, url);
    }
    // TwelveData (기존)
    if (url.pathname === '/api/twelvedata/chart') {
      return handleTwelveData(request, env, url);
    }
    // DeepL (기존, KV 캐시 추가)
    if (url.pathname === '/api/deepl/translate') {
      return handleDeepL(request, env);
    }
    // Fear & Greed (기존, KV 체크 추가)
    if (url.pathname === '/api/feargreed') {
      return handleFearGreed(request, env);
    }
    // FRED (기존, KV 체크 추가)
    if (url.pathname.startsWith('/api/fred/')) {
      return handleFRED(request, env, url);
    }
    // RSS 뉴스 (기존)
    if (url.pathname === '/api/news/market') {
      return handleMarketNews(request, GLOBAL_RSS_FEEDS, 20);
    }
    if (url.pathname === '/api/news/korea') {
      return handleMarketNews(request, KOREA_RSS_FEEDS, 10);
    }

    return jsonError('Not found', 404, request);
  },

  async scheduled(event, env, ctx) {
    ctx.waitUntil(runCacheWarming(event, env));
  },
};
```

### 4.4 핸들러 인터페이스 통일

모든 핸들러는 동일한 시그니처와 패턴을 따른다:

```javascript
// ── 핸들러 시그니처 (모든 핸들러 동일) ──
export async function handleXxx(request, env, url) → Response
```

**각 핸들러의 import/export 명세**:

| 파일 | export | import from utils/ |
|------|--------|--------------------|
| `handlers/finnhub.js` | `handleFinnhub` | `corsHeaders`, `getCached`, `setCached`, `jsonError`, `canCall`, `recordCall` |
| `handlers/fmp.js` | `handleFMP` | `corsHeaders`, `getCached`, `setCached`, `jsonError` |
| `handlers/deepl.js` | `handleDeepL` | `corsHeaders`, `jsonError`, `hashText` |
| `handlers/exchange-rate.js` | `handleExchangeRate` | `corsHeaders`, `getCached`, `setCached`, `jsonError` |
| `handlers/news.js` | `handleMarketNews`, `GLOBAL_RSS_FEEDS`, `KOREA_RSS_FEEDS` | `corsHeaders`, `jsonError` |
| `handlers/twelvedata.js` | `handleTwelveData` | `corsHeaders`, `jsonError` |
| `handlers/fred.js` | `handleFRED` | `corsHeaders`, `getCached`, `setCached`, `jsonError` |
| `handlers/feargreed.js` | `handleFearGreed` | `corsHeaders`, `getCached`, `setCached`, `jsonError` |

**핸들러 공통 패턴**:

```javascript
// ── handlers/finnhub.js (예시, 다른 핸들러도 동일 구조) ──

import { corsHeaders } from '../utils/cors.js';
import { getCached, setCached } from '../utils/cache.js';
import { jsonError } from '../utils/helpers.js';
import { canCall, recordCall } from '../utils/rate-limiter.js';

/**
 * Finnhub REST 프록시 핸들러
 * 7개 엔드포인트를 하나의 핸들러로 통합 처리한다.
 *
 * @param {Request} request - HTTP 요청
 * @param {Object} env      - Worker 환경 (env.FINNHUB_API_KEY, env.CACHE_KV)
 * @param {URL} url         - 파싱된 URL
 * @returns {Promise<Response>}
 */
export async function handleFinnhub(request, env, url) {
  if (request.method !== 'GET') {
    return jsonError('GET only', 405, request);
  }

  const apiKey = env.FINNHUB_API_KEY;
  if (!apiKey) return jsonError('FINNHUB_API_KEY not configured', 500, request);

  // 1. 경로 매핑 + 캐시 전략 결정
  const subPath = url.pathname.replace(/^\/api\/finnhub/, '');
  const cacheConfig = getFinnhubCacheConfig(subPath, /* ... */);

  // 2. 통합 캐시 조회 (getCached → KV + Cache API)
  const cacheKey = new Request(`https://cache.finnhub${/* ... */}`, request);
  const { data: cached, source } = await getCached(
    env,
    cacheConfig.useKV ? cacheConfig.kvKey : null,
    cacheKey
  );
  if (cached) {
    return new Response(cached, {
      status: 200,
      headers: { 'Content-Type': 'application/json', 'X-Cache': source, ...corsHeaders(request) },
    });
  }

  // 3. Rate limit 확인 + API 호출
  if (!canCall()) {
    return jsonError('Rate limit exceeded. Try again shortly.', 429, request);
  }
  recordCall();
  // ... fetch + 응답 처리 ...

  // 4. 통합 캐시 저장 (setCached → KV + Cache API 동시)
  await setCached(
    env,
    cacheConfig.useKV ? cacheConfig.kvKey : null,
    cacheConfig.kvTTL,
    cacheKey,
    cacheConfig.cacheTTL,
    data
  );

  return new Response(data, {
    status: 200,
    headers: { 'Content-Type': 'application/json', 'X-Cache': 'MISS', ...corsHeaders(request) },
  });
}

/**
 * Finnhub 엔드포인트별 캐시 전략 결정
 * @param {string} subPath - /quote, /search, /profile2 등
 * @param {string} symbol  - 종목 심볼 (대문자)
 * @param {URL} url        - 파싱된 URL
 * @returns {{cacheTTL: number, useKV: boolean, kvKey: string|null, kvTTL: number|null}}
 */
function getFinnhubCacheConfig(subPath, symbol, url) {
  // ... 섹션 6.3의 코드와 동일 ...
}
```

> **통일성의 이점**: `getCached()`와 `setCached()`를 사용하면 모든 핸들러에서 KV → Cache API 순서 조회, 동시 저장 로직이 자동으로 보장된다. 개별 핸들러가 `env.CACHE_KV.get()` / `cache.match()` / `env.CACHE_KV.put()` / `cache.put()`을 직접 호출하지 않으므로, 캐시 관련 버그가 한 곳에서만 발생하고 한 곳에서만 수정하면 된다.

### 4.5 Flutter ProxyConfig 중앙화

현재 4개 서비스 파일에 `AppConfig.useProxy` 분기가 산재되어 있다. 이를 중앙 관리 클래스로 통합한다.

**파일 위치**: `lib/data/services/api/proxy_config.dart`

```dart
import 'package:alpha_cycle/core/config/app_config.dart';

/// 모든 API 서비스의 프록시/직접 호출 URL 생성을 중앙 관리한다.
///
/// Worker 프록시 사용 시: Worker URL + 경로 매핑
/// 직접 호출 시: 원본 API URL + API 키 주입
///
/// 사용처:
///   - finnhub_service.dart
///   - financial_service.dart
///   - news_service.dart
///   - exchange_rate_service.dart
class ProxyConfig {
  ProxyConfig._();

  /// 프록시 사용 여부 (AppConfig.useProxy 위임)
  static bool get useProxy => AppConfig.useProxy;

  /// 프록시 베이스 URL (AppConfig.proxyBaseUrl 위임)
  static String get proxyBase => AppConfig.proxyBaseUrl;

  // ── Finnhub ──

  /// Finnhub API의 베이스 URL을 반환한다.
  /// 프록시: Worker 경유 (/api/finnhub)
  /// 직접: finnhub.io/api/v1
  static String get finnhubBaseUrl => useProxy
      ? '$proxyBase/api/finnhub'
      : AppConfig.finnhubBaseUrl;

  /// Finnhub 엔드포인트 경로를 매핑한다.
  /// Worker는 /profile2 → /stock/profile2 매핑을 내부 처리하므로
  /// 프록시 시 /stock/ 접두어를 제거한다.
  static String finnhubPath(String directPath) {
    if (!useProxy) return directPath;
    // /stock/profile2 → /profile2
    // /stock/metric → /metric
    // /stock/earnings → /earnings
    // /quote, /search, /company-news, /news → 동일
    return directPath.replaceFirst('/stock/', '/');
  }

  /// Finnhub 쿼리 파라미터를 생성한다.
  /// 프록시 시 token 파라미터를 제거한다 (Worker가 서버사이드 주입).
  static Map<String, dynamic> finnhubParams(Map<String, dynamic> params) {
    if (useProxy) {
      final filtered = Map<String, dynamic>.from(params);
      filtered.remove('token');
      // metric 엔드포인트의 'metric' 파라미터도 Worker가 자동 주입
      filtered.remove('metric');
      return filtered;
    }
    return params;
  }

  // ── FMP ──

  /// FMP API URL을 생성한다.
  /// 프록시: Worker 경유 (/api/fmp/...)
  /// 직접: FMP 원본 URL
  static String fmpUrl(String endpoint) => useProxy
      ? '$proxyBase/api/fmp/$endpoint'
      : '${AppConfig.fmpBaseUrl}/$endpoint';

  /// FMP 쿼리 파라미터를 생성한다.
  /// 프록시 시 apikey 파라미터를 제거한다.
  static Map<String, dynamic> fmpParams(Map<String, dynamic> params) {
    if (useProxy) {
      final filtered = Map<String, dynamic>.from(params);
      filtered.remove('apikey');
      return filtered;
    }
    return params;
  }

  // ── Exchange Rate ──

  /// 환율 API URL을 생성한다.
  /// 프록시: Worker 경유 (/api/exchange-rate)
  /// 직접: null (기존 폴백 체인 사용)
  static String? get exchangeRateUrl => useProxy
      ? '$proxyBase/api/exchange-rate'
      : null;

  // ── Finnhub News ──

  /// Finnhub 뉴스 API URL을 생성한다.
  /// 프록시: Worker 경유 (/api/finnhub/company-news, /api/finnhub/news)
  /// 직접: finnhub.io/api/v1/company-news, finnhub.io/api/v1/news
  static String finnhubNewsUrl(String endpoint) => useProxy
      ? '$proxyBase/api/finnhub/$endpoint'
      : '${AppConfig.finnhubBaseUrl}/$endpoint';

  /// Finnhub 뉴스 쿼리 파라미터를 생성한다.
  static Map<String, dynamic> finnhubNewsParams(Map<String, dynamic> params) {
    return finnhubParams(params);
  }
}
```

**서비스 파일별 BEFORE/AFTER 비교**:

#### `finnhub_service.dart`

```dart
// ── BEFORE (프록시 분기 없음, 직접 호출만) ──
FinnhubService()
    : _dio = Dio(BaseOptions(
        baseUrl: AppConfig.finnhubBaseUrl,
        queryParameters: {
          'token': AppConfig.finnhubApiKey,
        },
      ));

// getExchange 등에서:
final response = await _dio.get('/stock/profile2', queryParameters: {
  'symbol': symbol,
});

// ── AFTER (ProxyConfig 사용) ──
FinnhubService()
    : _dio = Dio(BaseOptions(
        baseUrl: ProxyConfig.finnhubBaseUrl,
        queryParameters: ProxyConfig.useProxy
            ? {}
            : {'token': AppConfig.finnhubApiKey},
      ));

// getExchange 등에서:
final path = ProxyConfig.finnhubPath('/stock/profile2');
final response = await _dio.get(path, queryParameters: {
  'symbol': symbol,
});
```

#### `financial_service.dart`

```dart
// ── BEFORE (Finnhub 직접, FMP 프록시 각각 분기) ──
// getMetrics():
final response = await _dio.get(
  '${AppConfig.finnhubBaseUrl}/stock/metric',
  queryParameters: {
    'symbol': symbol.toUpperCase(),
    'metric': 'all',
    'token': AppConfig.finnhubApiKey,
  },
);

// getProfile():
if (AppConfig.useProxy) {
  url = '${AppConfig.proxyBaseUrl}/api/fmp/profile';
} else {
  url = '${AppConfig.fmpBaseUrl}/profile';
  queryParams['apikey'] = AppConfig.fmpApiKey;
}

// ── AFTER (ProxyConfig 사용) ──
// getMetrics():
final response = await _dio.get(
  '${ProxyConfig.finnhubBaseUrl}${ProxyConfig.finnhubPath('/stock/metric')}',
  queryParameters: ProxyConfig.finnhubParams({
    'symbol': symbol.toUpperCase(),
    'metric': 'all',
    'token': AppConfig.finnhubApiKey,
  }),
);

// getProfile():
url = ProxyConfig.fmpUrl('profile');
queryParams = ProxyConfig.fmpParams({
  'symbol': symbol.toUpperCase(),
  'apikey': AppConfig.fmpApiKey,
});
```

#### `news_service.dart`

```dart
// ── BEFORE (_fetchFinnhub에서 직접 분기) ──
final response = await _dio.get(
  '${AppConfig.finnhubBaseUrl}/company-news',
  queryParameters: {
    'token': AppConfig.finnhubApiKey,
    'symbol': symbol,
    'from': fromStr,
    'to': toStr,
  },
);

// _getGeneralNewsFromFinnhub:
final response = await _dio.get(
  '${AppConfig.finnhubBaseUrl}/news',
  queryParameters: {
    'token': AppConfig.finnhubApiKey,
    'category': 'general',
  },
);

// ── AFTER (ProxyConfig 사용) ──
final response = await _dio.get(
  ProxyConfig.finnhubNewsUrl('company-news'),
  queryParameters: ProxyConfig.finnhubNewsParams({
    'token': AppConfig.finnhubApiKey,
    'symbol': symbol,
    'from': fromStr,
    'to': toStr,
  }),
);

// _getGeneralNewsFromFinnhub:
final response = await _dio.get(
  ProxyConfig.finnhubNewsUrl('news'),
  queryParameters: ProxyConfig.finnhubNewsParams({
    'token': AppConfig.finnhubApiKey,
    'category': 'general',
  }),
);
```

#### `exchange_rate_service.dart`

```dart
// ── BEFORE (3-API 폴백 체인 직접 구현) ──
Future<ExchangeRate> getRate({required String from, required String to}) async {
  try { return await _getTwelveDataRate(from: from, to: to); } catch (e) {}
  try { return await _getOpenErApiRate(from: from, to: to); } catch (e) {}
  return _frankfurterFallback(from: from, to: to);
}

// ── AFTER (ProxyConfig 사용, Worker 우선) ──
Future<ExchangeRate> getRate({required String from, required String to}) async {
  // 1차: Worker 프록시 (서버에서 폴백 체인 처리)
  final proxyUrl = ProxyConfig.exchangeRateUrl;
  if (proxyUrl != null) {
    try {
      final response = await _dio.get(
        proxyUrl,
        queryParameters: {'from': from, 'to': to},
      );
      // ... 파싱 ...
    } catch (e) {
      // Worker 실패 시 기존 폴백으로
    }
  }

  // 2차: 기존 로컬 폴백 체인
  try { return await _getTwelveDataRate(from: from, to: to); } catch (e) {}
  try { return await _getOpenErApiRate(from: from, to: to); } catch (e) {}
  return _frankfurterFallback(from: from, to: to);
}
```

### 4.6 모듈 간 의존성 다이어그램

#### Worker 모듈 의존성

```
                        ┌─────────────┐
                        │  index.js   │  (엔트리 포인트)
                        └──────┬──────┘
                               │
                ┌──────────────┼──────────────┐
                │              │              │
                ▼              ▼              ▼
        ┌─────────────┐ ┌──────────┐  ┌──────────────┐
        │ handlers/*  │ │ cron/*   │  │ utils/*      │
        │             │ │          │  │              │
        │ finnhub.js  │ │warming.js│  │ cors.js      │
        │ fmp.js      │ │          │  │ cache.js     │
        │ deepl.js    │ └────┬─────┘  │ rate-limiter │
        │ exchange-   │      │        │ helpers.js   │
        │   rate.js   │      │        │              │
        │ news.js     │      │        └───────▲──────┘
        │ twelvedata  │      │                │
        │ fred.js     │      │                │
        │ feargreed   │      │                │
        └──────┬──────┘      │                │
               │             │                │
               └─────────────┴────────────────┘
                      import from utils/

  ✅ 의존성 규칙:
  ├── utils/  → 외부 의존성 ZERO (다른 모듈 import 금지)
  ├── handlers/* → utils/* 만 import 가능
  ├── handlers/* → 다른 handlers/* import 금지
  ├── cron/*  → utils/* 만 import 가능 (handlers는 import 안 함, API 직접 호출)
  └── index.js → handlers/* + cron/* + utils/* 모두 import 가능

  ❌ 순환 참조 금지:
  ├── utils/ ──✗──▶ handlers/
  ├── utils/ ──✗──▶ cron/
  ├── handlers/ ──✗──▶ handlers/ (핸들러 간 참조 금지)
  └── cron/ ──✗──▶ handlers/ (Cron은 외부 API를 직접 호출, 핸들러 재사용 안 함)
```

> **cron/warming.js가 handlers를 import하지 않는 이유**: Cron 워밍은 자체 `fetch()` + KV 직접 저장이다. 핸들러를 재사용하면 핸들러의 Rate Limiter, CORS, 응답 포맷팅 등 불필요한 로직이 따라오고 순환 의존성 위험이 생긴다. Cron은 `utils/cache.js`의 `setCached()`만 사용하여 KV에 직접 저장한다.

#### Flutter 모듈 의존성

```
  ┌───────────────────────┐
  │   app_config.dart     │  (환경 변수, API 키, URL 설정)
  └───────────▲───────────┘
              │
  ┌───────────┴───────────┐
  │  proxy_config.dart    │  (프록시 URL 분기 중앙화)
  │  유일한 의존성:        │
  │  app_config.dart      │
  └───────────▲───────────┘
              │
    ┌─────────┼─────────┬────────────────┐
    │         │         │                │
    ▼         ▼         ▼                ▼
  finnhub   financial  news_service  exchange_rate
  _service  _service   .dart         _service
  .dart     .dart                    .dart

  ✅ 변경 전: 4개 파일이 각각 AppConfig 분기 → 중복 로직 4벌
  ✅ 변경 후: ProxyConfig 1곳 변경 → 4개 파일 자동 반영
```

### 4.7 wrangler.toml 완성본

```toml
name = "alpha-cycle-proxy"
main = "src/index.js"
compatibility_date = "2024-01-01"

# ESM 모듈 시스템
# package.json에 "type": "module" 필수

[[kv_namespaces]]
binding = "CACHE_KV"
id = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"  # wrangler kv:namespace create CACHE_KV 로 생성

[triggers]
crons = [
  "0 13 * * 1-5",   # Pre-market warming (UTC 13:00, Mon-Fri)
  "0 21 * * 1-5",   # Post-market warming (UTC 21:00, Mon-Fri)
  "0 12 * * 0",     # Weekend warming (UTC 12:00, Sun)
]

[vars]
# 비밀이 아닌 설정값 (필요 시)

# Secrets (wrangler secret put 으로 등록):
# FINNHUB_API_KEY       — Finnhub REST 프록시
# TWELVE_DATA_API_KEY   — TwelveData 차트 + 환율
# FMP_API_KEY           — Financial Modeling Prep 재무제표
# DEEPL_API_KEY         — DeepL 번역
# FRED_API_KEY          — FRED 경제 데이터
```

**`package.json`**:

```json
{
  "name": "alpha-cycle-proxy",
  "version": "2.0.0",
  "type": "module",
  "private": true
}
```

### 4.8 마이그레이션 계획 (단일 파일 → 모듈)

현재 단일 `worker.js`(593줄)를 모듈 구조로 마이그레이션하는 단계별 계획이다. **기능 변경 없이 구조만 변경**한다.

#### 단계 1: 디렉토리 구조 생성

```bash
mkdir -p cloudflare-worker/src/handlers
mkdir -p cloudflare-worker/src/cron
mkdir -p cloudflare-worker/src/utils
```

#### 단계 2: utils/ 추출 (의존성 없는 모듈 먼저)

1. `corsHeaders()` + `ALLOWED_ORIGINS` → `src/utils/cors.js`
2. `jsonError()` → `src/utils/helpers.js` (cors.js import)
3. 테스트: `wrangler dev` → 기존 엔드포인트 모두 정상 응답 확인

#### 단계 3: 핸들러 추출 (하나씩, 각각 테스트)

추출 순서 (의존성이 적은 것부터):

| 순서 | 추출 대상 | 테스트 방법 |
|------|-----------|-------------|
| 1 | `handleFearGreed` → `src/handlers/feargreed.js` | `curl /api/feargreed` |
| 2 | `handleFRED` → `src/handlers/fred.js` | `curl /api/fred/series/observations?...` |
| 3 | `handleMarketNews` + RSS 피드 → `src/handlers/news.js` | `curl /api/news/market` |
| 4 | `handleDeepL` → `src/handlers/deepl.js` | `curl -X POST /api/deepl/translate` |
| 5 | `handleTwelveData` → `src/handlers/twelvedata.js` | `curl /api/twelvedata/chart?...` |
| 6 | `handleFMP` → `src/handlers/fmp.js` | `curl /api/fmp/profile?symbol=AAPL` |

> 각 추출 후 `wrangler dev`로 해당 엔드포인트 + 나머지 엔드포인트 모두 테스트. 하나라도 실패하면 즉시 롤백.

#### 단계 4: index.js 라우터 정리

- `worker.js`에 남은 코드(라우터 + `export default`)를 `src/index.js`로 이동
- `wrangler.toml`의 `main`을 `src/index.js`로 변경
- 기존 `worker.js`는 삭제 (git에서 이력 보존)

#### 단계 5: 전체 회귀 테스트

```bash
# 모든 엔드포인트 일괄 테스트
curl -s "WORKER_URL/api/feargreed" | jq .
curl -s "WORKER_URL/api/fred/series/observations?series_id=DCOILWTICO" | jq .
curl -s "WORKER_URL/api/news/market" | jq .
curl -s "WORKER_URL/api/news/korea" | jq .
curl -X POST "WORKER_URL/api/deepl/translate" \
  -H "Content-Type: application/json" \
  -d '{"text":["Hello"],"source_lang":"EN","target_lang":"KO"}' | jq .
curl -s "WORKER_URL/api/twelvedata/chart?symbol=QQQ&interval=1day&outputsize=30" | jq .
curl -s "WORKER_URL/api/fmp/profile?symbol=AAPL" | jq .
```

#### 단계 6: 배포

```bash
wrangler deploy
```

> **핵심 원칙**: 매 추출 단계마다 배포 가능한 상태를 유지한다. 중간에 문제가 발생하면 해당 파일만 `worker.js`로 되돌리면 된다.

### 4.9 구현 순서 업데이트

모듈화를 Phase 0으로 추가하고, 이후 Phase에서 개별 모듈 파일을 수정한다.

| Phase | 내용 | 대상 파일 | 시간 |
|-------|------|-----------|------|
| **Phase 0 (NEW)** | 모듈화 마이그레이션 | `worker.js` → `src/**/*.js` | ~1.5시간 |
| Phase 1 | FMP + DeepL KV 레이어 | `src/handlers/fmp.js`, `src/handlers/deepl.js`, `src/utils/cache.js` | ~2시간 |
| Phase 2 | Finnhub + 환율 프록시 | `src/handlers/finnhub.js`, `src/handlers/exchange-rate.js`, `src/utils/rate-limiter.js`, Flutter 4개 서비스 + `proxy_config.dart` | ~4시간 |
| Phase 3 | Cron 캐시 워밍 | `src/cron/warming.js` | ~3시간 |

> Phase 0은 기능 변경이 없으므로, 테스트는 "모든 기존 엔드포인트가 동일하게 동작하는가"만 확인하면 된다.

---

## 5. Cloudflare 무료 한도

### 5.1 Workers Free Tier

| 리소스 | 무료 한도 | 비고 |
|--------|-----------|------|
| 요청 수 | **100,000 요청/일** | 하루 기준 |
| CPU 시간 | **10ms/요청** | 벽시계 시간 아님, CPU 시간 |
| 스크립트 크기 | 1MB (압축 후) | worker.js 하나 |
| Cron Trigger | **5개** (무료) | 일정 기반 실행 |
| Cache API | **무제한** | 용량/요청 제한 없음 |

### 5.2 KV Free Tier

| 리소스 | 무료 한도 | 비고 |
|--------|-----------|------|
| 읽기 | **100,000 읽기/일** | get 호출 수 |
| 쓰기 | **1,000 쓰기/일** | put 호출 수 |
| 삭제 | **1,000 삭제/일** | delete 호출 수 |
| 리스트 | **1,000 리스트/일** | list 호출 수 |
| 저장 용량 | **1 GB** | 전체 네임스페이스 |
| 값 크기 | 25 MB/값 | 단일 값 상한 |
| 키 크기 | 512 바이트 | 단일 키 상한 |

### 5.3 100명 기준 예상 사용량

**Workers 요청 수 계산** (섹션 15에서 상세 계산):

```
일일 Worker 요청 예상:
  Finnhub proxy:     ~15,000 req/day  (100명 × 150 calls/day)
  FMP proxy:         ~1,000 req/day   (100명 × 10 calls/day)
  TwelveData proxy:  ~2,000 req/day   (100명 × 20 calls/day)
  기존 프록시:        ~5,000 req/day   (F&G, FRED, News, DeepL)
  Exchange Rate:     ~3,000 req/day   (100명 × 30 calls/day)
  Cron warming:      ~220 req/day     (2 cron × ~110 calls)
  ────────────────────────────────
  합계:              ~26,220 req/day
  한도:              100,000 req/day
  사용률:            ~26%  ✅ SAFE
```

**KV 사용량 계산**:

```
KV 읽기 (일일):
  quote 조회:        ~15,000 reads   (Finnhub quote 요청마다 KV 확인)
  profile 조회:      ~1,000 reads    (FMP profile 요청마다)
  income 조회:       ~500 reads
  translate 조회:    ~2,000 reads    (DeepL 전 KV 확인)
  exchange rate:     ~3,000 reads
  metric/earnings:   ~500 reads
  ────────────────────────────────
  합계:              ~22,000 reads/day
  한도:              100,000 reads/day
  사용률:            ~22%  ✅ SAFE

KV 쓰기 (일일):
  Cron quote 워밍:   ~100 writes     (100 tickers × 1)
  Cron profile:      ~100 writes     (100 tickers × 1)
  Cron global:       ~5 writes       (F&G, 환율, FRED)
  translate 신규:    ~50 writes      (신규 번역만)
  exchange rate:     ~144 writes     (10min TTL × 24hr)
  Cache miss writes: ~100 writes     (profile, income 신규)
  ────────────────────────────────
  합계:              ~499 writes/day
  한도:              1,000 writes/day
  사용률:            ~50%  ✅ SAFE

KV 저장 용량:
  100 tickers × quote (~500B):     ~50 KB
  500 tickers × profile (~2KB):    ~1 MB
  500 tickers × income (~5KB):     ~2.5 MB
  5,000 translations (~200B):      ~1 MB
  지표/환율/기타:                    ~100 KB
  ────────────────────────────────
  합계:              ~5 MB
  한도:              1 GB
  사용률:            ~0.5%  ✅ SAFE
```

---

## 6. 개선 1: Finnhub REST 프록시

> **우선순위**: CRITICAL (가장 먼저 구현)  
> **이유**: API 키 클라이언트 노출 + 60/min 한도 = 100명 시 즉시 장애

### 6.1 새로운 Worker 라우트

| 라우트 | 원본 API | 메서드 | 캐시 전략 |
|--------|----------|--------|-----------|
| `/api/finnhub/quote?symbol=AAPL` | `finnhub.io/api/v1/quote?symbol=AAPL` | GET | Cache API 5min |
| `/api/finnhub/search?q=apple&exchange=US` | `finnhub.io/api/v1/search?q=apple&exchange=US` | GET | Cache API 1hr |
| `/api/finnhub/company-news?symbol=AAPL&from=...&to=...` | `finnhub.io/api/v1/company-news?...` | GET | Cache API 30min |
| `/api/finnhub/profile2?symbol=AAPL` | `finnhub.io/api/v1/stock/profile2?symbol=AAPL` | GET | KV 7일 + Cache API 24hr |
| `/api/finnhub/metric?symbol=AAPL` | `finnhub.io/api/v1/stock/metric?symbol=AAPL&metric=all` | GET | KV 24hr + Cache API 24hr |
| `/api/finnhub/earnings?symbol=AAPL&limit=8` | `finnhub.io/api/v1/stock/earnings?...` | GET | KV 7일 + Cache API 24hr |
| `/api/finnhub/news?category=general` | `finnhub.io/api/v1/news?category=general` | GET | Cache API 30min |

### 6.2 Rate Limiting (Worker 측)

Finnhub 무료 한도: **60 calls/min**. Worker에서 실제 API 호출 수를 추적해야 한다.

```javascript
// Rate limiter — 메모리 기반 (Worker 인스턴스별)
// 참고: Worker는 여러 인스턴스에서 실행될 수 있으므로 완벽하지 않지만,
// 캐시 히트율이 높으면 실제 API 호출이 적어 충분함
const finnhubRateLimit = {
  calls: [],        // 최근 1분간 API 호출 timestamp
  maxPerMinute: 55, // 60 한도에서 여유분 5 확보
};

function canCallFinnhub() {
  const now = Date.now();
  // 1분 이전 기록 제거
  finnhubRateLimit.calls = finnhubRateLimit.calls.filter(
    t => now - t < 60_000
  );
  return finnhubRateLimit.calls.length < finnhubRateLimit.maxPerMinute;
}

function recordFinnhubCall() {
  finnhubRateLimit.calls.push(Date.now());
}
```

### 6.3 핸들러 구현 (Worker)

```javascript
// ─── Finnhub REST 프록시 ───
async function handleFinnhub(request, env, url) {
  if (request.method !== 'GET') {
    return jsonError('GET only', 405, request);
  }

  const apiKey = env.FINNHUB_API_KEY;
  if (!apiKey) return jsonError('FINNHUB_API_KEY not configured', 500, request);

  // /api/finnhub/quote → /quote
  // /api/finnhub/profile2 → /stock/profile2
  // /api/finnhub/metric → /stock/metric
  // /api/finnhub/earnings → /stock/earnings
  // /api/finnhub/company-news → /company-news
  // /api/finnhub/search → /search
  // /api/finnhub/news → /news
  const subPath = url.pathname.replace(/^\/api\/finnhub/, '');
  
  // Finnhub 내부 경로 매핑
  const pathMap = {
    '/quote': '/quote',
    '/search': '/search',
    '/company-news': '/company-news',
    '/profile2': '/stock/profile2',
    '/metric': '/stock/metric',
    '/earnings': '/stock/earnings',
    '/news': '/news',
  };
  
  const finnhubPath = pathMap[subPath];
  if (!finnhubPath) return jsonError('Unknown Finnhub endpoint', 400, request);

  // ── 캐시 전략 결정 ──
  const symbol = url.searchParams.get('symbol')?.toUpperCase() || '';
  const cacheConfig = getFinnhubCacheConfig(subPath, symbol, url);

  // 1차: KV 확인 (profile, metric, earnings만)
  if (cacheConfig.useKV && env.CACHE_KV) {
    try {
      const kvData = await env.CACHE_KV.get(cacheConfig.kvKey, 'json');
      if (kvData) {
        return new Response(JSON.stringify(kvData), {
          status: 200,
          headers: {
            'Content-Type': 'application/json',
            'X-Cache': 'KV-HIT',
            ...corsHeaders(request),
          },
        });
      }
    } catch (e) { /* KV 실패 시 무시 */ }
  }

  // 2차: Cache API 확인
  const cacheKey = new Request(
    `https://cache.finnhub${finnhubPath}?${url.searchParams.toString()}`,
    request
  );
  const cache = caches.default;
  let cachedResponse = await cache.match(cacheKey);
  if (cachedResponse) {
    const headers = new Headers(cachedResponse.headers);
    Object.entries(corsHeaders(request)).forEach(([k, v]) => headers.set(k, v));
    headers.set('X-Cache', 'HIT');
    return new Response(cachedResponse.body, {
      status: cachedResponse.status,
      headers,
    });
  }

  // 3차: Rate limit 확인 후 Finnhub API 호출
  if (!canCallFinnhub()) {
    return jsonError('Rate limit exceeded. Try again shortly.', 429, request);
  }

  try {
    const finnhubUrl = new URL(`https://finnhub.io/api/v1${finnhubPath}`);
    // 클라이언트 쿼리 파라미터 복사
    for (const [key, value] of url.searchParams) {
      finnhubUrl.searchParams.set(key, value);
    }
    // API 키 서버사이드 주입
    finnhubUrl.searchParams.set('token', apiKey);
    // metric 엔드포인트는 항상 metric=all
    if (subPath === '/metric') {
      finnhubUrl.searchParams.set('metric', 'all');
    }

    recordFinnhubCall();

    const resp = await fetch(finnhubUrl.toString(), {
      headers: { 'Accept': 'application/json' },
    });

    if (!resp.ok) {
      return new Response(resp.body, {
        status: resp.status,
        headers: { 'Content-Type': 'application/json', ...corsHeaders(request) },
      });
    }

    const data = await resp.text();

    // Cache API 저장
    const responseToCache = new Response(data, {
      status: 200,
      headers: {
        'Content-Type': 'application/json',
        'Cache-Control': `public, max-age=${cacheConfig.cacheTTL}`,
      },
    });
    await cache.put(cacheKey, responseToCache.clone());

    // KV 저장 (해당 엔드포인트만)
    if (cacheConfig.useKV && env.CACHE_KV) {
      try {
        await env.CACHE_KV.put(
          cacheConfig.kvKey,
          data,
          { expirationTtl: cacheConfig.kvTTL }
        );
      } catch (e) { /* KV 쓰기 실패 시 무시 */ }
    }

    return new Response(data, {
      status: 200,
      headers: {
        'Content-Type': 'application/json',
        'Cache-Control': `public, max-age=${cacheConfig.cacheTTL}`,
        'X-Cache': 'MISS',
        ...corsHeaders(request),
      },
    });
  } catch (e) {
    return jsonError(`Finnhub error: ${e.message}`, 502, request);
  }
}

function getFinnhubCacheConfig(subPath, symbol, url) {
  switch (subPath) {
    case '/quote':
      return {
        cacheTTL: 300,          // Cache API: 5분
        useKV: false,           // quote는 KV 쓰기 절약 (Cron에서만 KV 기록)
        kvKey: null,
        kvTTL: null,
      };
    case '/search':
      return {
        cacheTTL: 3600,         // Cache API: 1시간
        useKV: false,           // 쿼리 다양 → KV 쓰기 낭비
        kvKey: null,
        kvTTL: null,
      };
    case '/company-news':
      return {
        cacheTTL: 1800,         // Cache API: 30분
        useKV: false,
        kvKey: null,
        kvTTL: null,
      };
    case '/profile2':
      return {
        cacheTTL: 86400,        // Cache API: 24시간
        useKV: true,
        kvKey: `profile:${symbol}`,
        kvTTL: 604800,          // KV: 7일
      };
    case '/metric':
      return {
        cacheTTL: 86400,        // Cache API: 24시간
        useKV: true,
        kvKey: `metric:${symbol}`,
        kvTTL: 86400,           // KV: 24시간
      };
    case '/earnings':
      return {
        cacheTTL: 86400,        // Cache API: 24시간
        useKV: true,
        kvKey: `earnings:${symbol}`,
        kvTTL: 604800,          // KV: 7일
      };
    case '/news':
      return {
        cacheTTL: 1800,         // Cache API: 30분
        useKV: false,
        kvKey: null,
        kvTTL: null,
      };
    default:
      return {
        cacheTTL: 300,
        useKV: false,
        kvKey: null,
        kvTTL: null,
      };
  }
}
```

### 6.4 앱 변경 사항

**`finnhub_service.dart`** 변경:

```dart
// 변경 전
FinnhubService()
    : _dio = Dio(BaseOptions(
        baseUrl: AppConfig.finnhubBaseUrl,  // https://finnhub.io/api/v1
        queryParameters: {
          'token': AppConfig.finnhubApiKey,  // 키 노출!
        },
      ));

// 변경 후
FinnhubService()
    : _dio = Dio(BaseOptions(
        baseUrl: AppConfig.useProxy
            ? '${AppConfig.proxyBaseUrl}/api/finnhub'  // Worker 경유
            : AppConfig.finnhubBaseUrl,                // 로컬 개발 폴백
        queryParameters: AppConfig.useProxy
            ? {}                                       // 키 불필요
            : {'token': AppConfig.finnhubApiKey},      // 로컬만
      ));
```

**`finnhub_service.dart`** 엔드포인트 매핑 변경:

```dart
// 변경 전 (직접 Finnhub 경로)
await _dio.get('/quote', queryParameters: {'symbol': symbol});
await _dio.get('/search', queryParameters: {'q': query, 'exchange': 'US'});
await _dio.get('/stock/profile2', queryParameters: {'symbol': symbol});

// 변경 후 (Worker 경유 시 경로 단축)
// Worker가 /api/finnhub/profile2 → /stock/profile2 매핑
await _dio.get('/quote', queryParameters: {'symbol': symbol});      // 동일
await _dio.get('/search', queryParameters: {'q': query, 'exchange': 'US'});  // 동일
await _dio.get('/profile2', queryParameters: {'symbol': symbol});   // 변경!
```

`profile2`, `metric`, `earnings`의 경로가 변경되므로, `AppConfig.useProxy` 분기 처리가 필요하다:

```dart
/// 종목 거래소 조회 (profile2)
Future<String> getExchange(String symbol) async {
  try {
    // Worker 프록시: /profile2, 직접: /stock/profile2
    final path = AppConfig.useProxy ? '/profile2' : '/stock/profile2';
    final response = await _dio.get(path, queryParameters: {
      'symbol': symbol,
    });
    // ... 파싱 동일
  } catch (_) {}
  return 'US';
}
```

**`financial_service.dart`** 변경:

```dart
// 변경 전: Finnhub 직접 호출
final response = await _dio.get(
  '${AppConfig.finnhubBaseUrl}/stock/metric',
  queryParameters: {
    'symbol': symbol.toUpperCase(),
    'metric': 'all',
    'token': AppConfig.finnhubApiKey,  // 키 노출!
  },
);

// 변경 후: Worker 경유
final response = await _dio.get(
  AppConfig.useProxy
      ? '${AppConfig.proxyBaseUrl}/api/finnhub/metric'
      : '${AppConfig.finnhubBaseUrl}/stock/metric',
  queryParameters: {
    'symbol': symbol.toUpperCase(),
    if (!AppConfig.useProxy) ...{
      'metric': 'all',
      'token': AppConfig.finnhubApiKey,
    },
  },
);
```

`getEarnings()` 메서드도 동일한 패턴으로 변경.

**`news_service.dart`** 변경:

```dart
// _fetchFinnhub(), _getGeneralNewsFromFinnhub() 모두 동일 패턴
// 변경 전
final response = await _dio.get(
  '${AppConfig.finnhubBaseUrl}/company-news',
  queryParameters: {
    'token': AppConfig.finnhubApiKey,
    'symbol': symbol,
    ...
  },
);

// 변경 후
final response = await _dio.get(
  AppConfig.useProxy
      ? '${AppConfig.proxyBaseUrl}/api/finnhub/company-news'
      : '${AppConfig.finnhubBaseUrl}/company-news',
  queryParameters: {
    'symbol': symbol,
    'from': fromStr,
    'to': toStr,
    if (!AppConfig.useProxy) 'token': AppConfig.finnhubApiKey,
  },
);
```

### 6.5 예상 절감 효과

```
변경 전 (100명):
  Finnhub 직접 호출: 100명 × ~50 calls/day = ~5,000 calls/day
  피크: 100명이 동시 접속 시 수십~수백 calls/min → 60/min 초과

변경 후 (100명, Worker 공유 캐시):
  실제 Finnhub API 호출:
    quote cache miss:     ~288/day  (캐시 5분, 같은 종목은 공유)
    search cache miss:    ~50/day   (캐시 1hr)
    company-news miss:    ~48/day   (캐시 30min)
    profile KV miss:      ~10/day   (KV 7일, 신규 종목만)
    metric KV miss:       ~50/day   (KV 24hr)
    earnings KV miss:     ~10/day   (KV 7일)
    general news miss:    ~48/day   (캐시 30min)
    ────────────────────────────────
    합계:                 ~504 calls/day
    분당 평균:            ~0.35 calls/min  ✅ (한도 60/min)
    피크 (캐시 콜드스타트): ~10 calls/min ✅
```

---

## 7. 개선 2: FMP 캐시 TTL 최적화

> **우선순위**: HIGH  
> **이유**: 현재 Cache API 24hr이지만 Cloudflare 임의 축출 가능, 250/day 한도 위험

### 7.1 현재 문제

- FMP 프록시는 이미 `worker.js`에 구현되어 있음 (`handleFMP` 함수)
- Cache API 24hr TTL 설정이지만, Cloudflare는 저빈도 접근 캐시를 축출할 수 있음
- 캐시가 축출되면 250/day 한도를 빠르게 소진
- `profile`은 거의 변하지 않는데 24hr마다 재요청

### 7.2 변경 사항

기존 `handleFMP` 함수에 KV 레이어를 추가한다:

```javascript
async function handleFMP(request, env, url) {
  // ... 기존 유효성 검사 동일 ...

  const fmpPath = url.pathname.replace(/^\/api\/fmp/, '');
  const symbol = url.searchParams.get('symbol')?.toUpperCase() || '';

  // KV 캐시 키 및 TTL 결정
  const kvConfig = getFMPKVConfig(fmpPath, symbol, url);

  // 1차: KV 확인
  if (kvConfig.useKV && env.CACHE_KV) {
    try {
      const kvData = await env.CACHE_KV.get(kvConfig.kvKey, 'text');
      if (kvData) {
        return new Response(kvData, {
          status: 200,
          headers: {
            'Content-Type': 'application/json',
            'X-Cache': 'KV-HIT',
            ...corsHeaders(request),
          },
        });
      }
    } catch (e) { /* KV 실패 시 무시, 다음 레이어로 */ }
  }

  // 2차: Cache API (기존 로직 유지)
  // ... 기존 cache.match() 로직 ...

  // 3차: FMP API 호출 (기존 로직)
  // ... 기존 fetch 로직 ...

  // 응답 성공 시 KV에도 저장
  if (kvConfig.useKV && env.CACHE_KV) {
    try {
      await env.CACHE_KV.put(kvConfig.kvKey, data, {
        expirationTtl: kvConfig.kvTTL,
      });
    } catch (e) { /* KV 쓰기 실패 시 무시 */ }
  }

  // ... 기존 Cache API 저장 및 응답 반환 ...
}

function getFMPKVConfig(fmpPath, symbol, url) {
  if (fmpPath === '/profile') {
    return {
      useKV: true,
      kvKey: `fmp_profile:${symbol}`,
      kvTTL: 604800,  // 7일 (기업 프로필은 거의 불변)
    };
  }
  if (fmpPath === '/income-statement') {
    const period = url.searchParams.get('period') || 'annual';
    return {
      useKV: true,
      kvKey: `income:${symbol}:${period}`,
      kvTTL: 2592000,  // 30일 (손익계산서는 분기별 변경)
    };
  }
  // 기타 FMP 엔드포인트는 KV 미사용
  return { useKV: false, kvKey: null, kvTTL: null };
}
```

### 7.3 폴백 체인

```
FMP 요청 흐름:

  /api/fmp/profile?symbol=AAPL
    │
    ├── 1. KV.get("fmp_profile:AAPL")
    │     └── HIT → 즉시 반환 (7일 이내)
    │
    ├── 2. Cache API match
    │     └── HIT → 반환 + (KV 갱신 불필요, 이미 있을 것)
    │
    └── 3. FMP API fetch
          └── 성공 → KV.put(7일) + Cache.put(24hr) + 반환
          └── 실패 → 502 에러
```

### 7.4 예상 절감 효과

```
변경 전:
  FMP 호출: 캐시 축출 시 100명 × 30 calls/day = 3,000 calls/day
  한도: 250/day → 초과!

변경 후:
  KV 히트 시 FMP 호출 불필요
  실제 FMP API 호출:
    profile KV miss:      ~10/day  (신규 종목만)
    income KV miss:       ~20/day  (분기 업데이트 + 신규)
    ────────────────────────────────
    합계:                 ~30 calls/day
    한도:                 250/day
    사용률:               ~12%  ✅ SAFE
```

---

## 8. 개선 3: DeepL 번역 공유 캐시 (KV)

> **우선순위**: HIGH  
> **이유**: 동일 뉴스 제목을 100명이 각각 번역 = 100배 API 사용

### 8.1 현재 구조

```
현재 (브라우저별 독립):

  User A Browser          User B Browser
  ┌──────────────┐        ┌──────────────┐
  │ Hive 번역캐시 │        │ Hive 번역캐시 │
  │ "Apple..." →  │        │ (비어있음)    │
  │ "애플..."     │        │              │
  └──────┬───────┘        └──────┬───────┘
         │ HIT                   │ MISS → DeepL 호출
         ▼                       ▼
   캐시에서 반환          Worker → DeepL API → 번역 결과
                         (같은 제목을 또 번역!)
```

### 8.2 목표 구조

```
목표 (Worker KV 공유):

  User A Browser          User B Browser
       │                       │
       └───────────┬───────────┘
                   ▼
          Worker /api/deepl/translate
                   │
          ┌────────▼────────┐
          │ KV 번역 캐시     │
          │ translate:{hash} │
          │ → 번역 결과      │
          └────────┬────────┘
                   │
           HIT → 즉시 반환 (DeepL 호출 안 함)
           MISS → DeepL API → KV에 저장 → 반환
```

### 8.3 Worker 변경

```javascript
async function handleDeepL(request, env) {
  if (request.method !== 'POST') {
    return jsonError('POST only', 405, request);
  }

  const apiKey = env.DEEPL_API_KEY;
  if (!apiKey) return jsonError('DEEPL_API_KEY not configured', 500, request);

  // 요청 본문 파싱
  const body = await request.json();
  const texts = body.text; // string[]
  const sourceLang = body.source_lang || 'EN';
  const targetLang = body.target_lang || 'KO';

  if (!Array.isArray(texts) || texts.length === 0) {
    return jsonError('text array required', 400, request);
  }

  // KV 캐시 확인 (텍스트별)
  const results = [];
  const uncachedTexts = [];
  const uncachedIndices = [];

  if (env.CACHE_KV) {
    for (let i = 0; i < texts.length; i++) {
      const hash = await hashText(texts[i]);
      const kvKey = `translate:${sourceLang}:${targetLang}:${hash}`;

      try {
        const cached = await env.CACHE_KV.get(kvKey);
        if (cached) {
          results[i] = { text: cached };
          continue;
        }
      } catch (e) { /* KV 실패 시 번역 진행 */ }

      results[i] = null; // 아직 미번역
      uncachedTexts.push(texts[i]);
      uncachedIndices.push(i);
    }

    // 전부 캐시 히트면 즉시 반환
    if (uncachedTexts.length === 0) {
      return new Response(JSON.stringify({ translations: results }), {
        status: 200,
        headers: {
          'Content-Type': 'application/json',
          'X-Cache': 'KV-HIT',
          ...corsHeaders(request),
        },
      });
    }
  } else {
    // KV 없으면 전부 번역
    for (let i = 0; i < texts.length; i++) {
      results[i] = null;
      uncachedTexts.push(texts[i]);
      uncachedIndices.push(i);
    }
  }

  // 미캐시 텍스트만 DeepL 호출
  const resp = await fetch('https://api-free.deepl.com/v2/translate', {
    method: 'POST',
    headers: {
      'Authorization': `DeepL-Auth-Key ${apiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      text: uncachedTexts,
      source_lang: sourceLang,
      target_lang: targetLang,
    }),
  });

  if (!resp.ok) {
    return new Response(resp.body, {
      status: resp.status,
      headers: {
        'Content-Type': resp.headers.get('Content-Type') || 'application/json',
        ...corsHeaders(request),
      },
    });
  }

  const deeplResult = await resp.json();
  const translations = deeplResult.translations || [];

  // 결과 병합 + KV 저장
  for (let j = 0; j < uncachedIndices.length && j < translations.length; j++) {
    const idx = uncachedIndices[j];
    const translated = translations[j];
    results[idx] = translated;

    // KV에 저장 (무기한, 번역은 변하지 않음)
    if (env.CACHE_KV && translated?.text) {
      try {
        const hash = await hashText(texts[idx]);
        const kvKey = `translate:${sourceLang}:${targetLang}:${hash}`;
        // expirationTtl 생략 = 영구 저장
        await env.CACHE_KV.put(kvKey, translated.text);
      } catch (e) { /* KV 쓰기 실패 무시 */ }
    }
  }

  return new Response(JSON.stringify({ translations: results }), {
    status: 200,
    headers: {
      'Content-Type': 'application/json',
      'X-Cache': uncachedTexts.length < texts.length ? 'PARTIAL-HIT' : 'MISS',
      ...corsHeaders(request),
    },
  });
}

// 텍스트 해시 (Web Crypto API, SHA-256 → hex 앞 16자)
async function hashText(text) {
  const encoder = new TextEncoder();
  const data = encoder.encode(text);
  const hashBuffer = await crypto.subtle.digest('SHA-256', data);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  return hashArray.slice(0, 8).map(b => b.toString(16).padStart(2, '0')).join('');
}
```

### 8.4 앱 변경

앱 측 코드(`news_service.dart`)는 **변경 불필요**. Worker가 동일한 요청/응답 형식을 유지하므로 앱은 차이를 알 수 없다. 기존 Hive 번역 캐시도 유지하여 이중 캐시 역할을 한다:

```
요청 흐름:
  1. 앱: Hive 캐시 확인 → HIT면 네트워크 호출 안 함
  2. 앱: Hive MISS → Worker POST /api/deepl/translate
  3. Worker: KV 캐시 확인 → HIT면 DeepL 호출 안 함
  4. Worker: KV MISS → DeepL API → KV 저장 → 응답
  5. 앱: 응답 받아 Hive에 저장
```

### 8.5 예상 절감 효과

```
변경 전:
  100명 × 20 뉴스/day × ~100 chars/title = ~200,000 chars/day
  월간: ~6,000,000 chars → 500K 한도 초과!
  (실제로는 Hive 캐시로 완화되지만, 신규 사용자마다 전체 번역)

변경 후:
  같은 뉴스 제목 → Worker KV에서 공유
  신규 번역 (중복 제거 후): ~50 제목/day × ~100 chars = ~5,000 chars/day
  월간: ~150,000 chars
  한도: 500,000 chars/mo
  사용률: ~30%  ✅ SAFE
```

---

## 9. 개선 4: Cron 캐시 워밍

> **우선순위**: MEDIUM (개선 1, 2, 3 이후)  
> **이유**: 캐시 콜드스타트 시 burst 호출 방지, 피크 타임 API 부하 분산

### 9.1 Cron 스케줄

| Cron | UTC | KST | 목적 |
|------|-----|-----|------|
| `0 13 * * 1-5` | 13:00 (월~금) | 22:00 | 미국 시장 개장 30분 전, 최신 시세/뉴스 워밍 |
| `0 21 * * 1-5` | 21:00 (월~금) | 06:00 | 미국 시장 폐장 후, 최종 시세/재무 워밍 |
| `0 12 * * 0` | 12:00 (일) | 21:00 | 주말 프로필/재무 데이터 갱신 |

> **참고**: DST 기간(3월~11월)에는 미국 시장 개장이 EDT 09:30 = UTC 13:30.  
> 비-DST 기간에는 EST 09:30 = UTC 14:30.  
> Cron은 UTC 13:00으로 고정하여 DST 상관없이 개장 전에 워밍 완료.

### 9.2 인기 종목 리스트

KV에 `warm:tickers` 키로 관리. 초기값:

```json
[
  "TQQQ", "SOXL", "QQQ", "SPY", "NVDA", "AAPL", "TSLA", "MSFT", "AMZN",
  "META", "GOOGL", "AMD", "SQQQ", "SOXS", "UPRO", "PLTR", "AVGO", "MU",
  "INTC", "QCOM", "NFLX", "ADBE", "CRM", "ORCL", "CSCO", "NOW", "SNOW",
  "DDOG", "CRWD", "NET", "ARM", "MRVL", "ASML", "LRCX", "AMAT", "KLAC",
  "SNPS", "CDNS", "TXN", "ADI", "ON", "GFS", "IONQ", "SOFI", "COIN",
  "RIVN", "LCID", "NIO", "XPEV", "LI", "PLUG", "ENPH", "SEDG",
  "V", "MA", "PYPL", "JPM", "GS", "MS", "BAC", "BLK",
  "KO", "PEP", "MCD", "SBUX", "NKE", "WMT", "COST", "HD", "PG", "JNJ",
  "PFE", "MRNA", "UNH", "ABBV", "LLY", "NVO", "AMGN", "GILD", "ISRG",
  "DIS", "CMCSA", "TMUS", "SPOT",
  "BA", "LMT", "CAT", "RTX",
  "BRK.B",
  "GLD", "SLV", "USO", "TLT", "IBIT",
  "DIA", "IWM", "ARKK",
  "RBLX", "SOUN", "AI", "BBAI", "ZM", "PATH", "MDB"
]
```

**총 100개 종목** (한국 투자자 인기 종목 기준, `_koreanToEnglish` 매핑 참조)

### 9.3 워밍 시퀀스

```javascript
export default {
  // 기존 fetch 핸들러
  async fetch(request, env) { /* ... */ },

  // Cron 트리거 핸들러
  async scheduled(event, env, ctx) {
    const cronType = getCronType(event.cron);
    ctx.waitUntil(runCacheWarming(env, cronType));
  },
};

function getCronType(cron) {
  // '0 13 * * 1-5' → 'pre-market'
  // '0 21 * * 1-5' → 'post-market'
  // '0 12 * * 0'   → 'weekend'
  if (cron.includes('13') && cron.includes('1-5')) return 'pre-market';
  if (cron.includes('21') && cron.includes('1-5')) return 'post-market';
  return 'weekend';
}

async function runCacheWarming(env, cronType) {
  const startTime = Date.now();
  console.log(`[Cron] Cache warming started: ${cronType}`);

  // 1. 인기 종목 리스트 조회
  let tickers;
  try {
    tickers = await env.CACHE_KV.get('warm:tickers', 'json');
  } catch (e) {
    console.error('[Cron] Failed to read tickers from KV');
    return;
  }
  if (!tickers || !Array.isArray(tickers)) {
    console.error('[Cron] No tickers found in KV');
    return;
  }

  // 2. Finnhub 시세 워밍 (10개씩 배치, 배치 간 2초 대기)
  if (cronType !== 'weekend') {
    await warmFinnhubQuotes(env, tickers);
  }

  // 3. FMP 프로필 워밍 (주말 또는 post-market)
  if (cronType === 'weekend' || cronType === 'post-market') {
    await warmFMPProfiles(env, tickers);
  }

  // 4. 글로벌 데이터 워밍 (항상)
  await warmGlobalData(env);

  // 5. 워밍 완료 기록
  await env.CACHE_KV.put('warm:last_run', JSON.stringify({
    type: cronType,
    timestamp: new Date().toISOString(),
    duration_ms: Date.now() - startTime,
    tickers_count: tickers.length,
  }));

  console.log(`[Cron] Cache warming completed in ${Date.now() - startTime}ms`);
}

async function warmFinnhubQuotes(env, tickers) {
  const apiKey = env.FINNHUB_API_KEY;
  if (!apiKey) return;

  const batchSize = 10;
  const delayBetweenBatches = 2000; // 2초 (10 calls → 60/min 안전)

  for (let i = 0; i < tickers.length; i += batchSize) {
    const batch = tickers.slice(i, i + batchSize);

    // 배치 내 병렬 호출
    const results = await Promise.allSettled(
      batch.map(async (symbol) => {
        const resp = await fetch(
          `https://finnhub.io/api/v1/quote?symbol=${symbol}&token=${apiKey}`
        );
        if (!resp.ok) throw new Error(`HTTP ${resp.status}`);
        const data = await resp.json();

        // KV에 저장 (5분 TTL → Cron 간격에 맞춰 다음 Cron까지 유지)
        // post-market: 다음 pre-market까지 ~16시간
        // pre-market: 장중 5분 캐시는 Cache API가 담당
        await env.CACHE_KV.put(
          `quote:${symbol}`,
          JSON.stringify({ ...data, _cachedAt: new Date().toISOString() }),
          { expirationTtl: 57600 } // 16시간
        );

        return symbol;
      })
    );

    const succeeded = results.filter(r => r.status === 'fulfilled').length;
    console.log(`[Cron] Finnhub quotes batch ${Math.floor(i/batchSize)+1}: ${succeeded}/${batch.length}`);

    // 다음 배치 전 대기 (마지막 배치 제외)
    if (i + batchSize < tickers.length) {
      await sleep(delayBetweenBatches);
    }
  }
}

async function warmFMPProfiles(env, tickers) {
  const apiKey = env.FMP_API_KEY;
  if (!apiKey) return;

  // FMP는 250/day 한도이므로 100개만 신중하게
  // KV에 이미 있고 7일 이내면 건너뜀
  const tickersToWarm = [];
  for (const symbol of tickers) {
    const existing = await env.CACHE_KV.get(`fmp_profile:${symbol}`);
    if (!existing) {
      tickersToWarm.push(symbol);
    }
    // KV TTL은 자동 만료되므로, 존재하면 아직 유효
  }

  if (tickersToWarm.length === 0) {
    console.log('[Cron] All FMP profiles cached, skipping');
    return;
  }

  // 5개씩 배치, 배치 간 1초 대기
  const batchSize = 5;
  for (let i = 0; i < tickersToWarm.length; i += batchSize) {
    const batch = tickersToWarm.slice(i, i + batchSize);

    await Promise.allSettled(
      batch.map(async (symbol) => {
        const resp = await fetch(
          `https://financialmodelingprep.com/stable/profile?symbol=${symbol}&apikey=${apiKey}`
        );
        if (!resp.ok) throw new Error(`HTTP ${resp.status}`);
        const data = await resp.text();

        await env.CACHE_KV.put(`fmp_profile:${symbol}`, data, {
          expirationTtl: 604800, // 7일
        });
      })
    );

    if (i + batchSize < tickersToWarm.length) {
      await sleep(1000);
    }
  }

  console.log(`[Cron] FMP profiles warmed: ${tickersToWarm.length} tickers`);
}

async function warmGlobalData(env) {
  // Fear & Greed Index
  try {
    const fgResp = await fetch(
      'https://production.dataviz.cnn.io/index/fearandgreed/graphdata/',
      {
        headers: {
          'User-Agent': 'Mozilla/5.0',
          'Referer': 'https://edition.cnn.com/',
        },
      }
    );
    if (fgResp.ok) {
      const data = await fgResp.text();
      await env.CACHE_KV.put('fear_greed:latest', data, {
        expirationTtl: 3600, // 1시간
      });
    }
  } catch (e) { console.error('[Cron] Fear & Greed warming failed:', e); }

  // Exchange Rate USD/KRW (Twelve Data)
  if (env.TWELVE_DATA_API_KEY) {
    try {
      const erResp = await fetch(
        `https://api.twelvedata.com/exchange_rate?symbol=USD/KRW&apikey=${env.TWELVE_DATA_API_KEY}`
      );
      if (erResp.ok) {
        const data = await erResp.text();
        await env.CACHE_KV.put('exchange_rate:USD_KRW', data, {
          expirationTtl: 600, // 10분
        });
      }
    } catch (e) { console.error('[Cron] Exchange rate warming failed:', e); }
  }

  // FRED 지표 (WTI, 10Y)
  if (env.FRED_API_KEY) {
    for (const seriesId of ['DCOILWTICO', 'DGS10']) {
      try {
        const fredResp = await fetch(
          `https://api.stlouisfed.org/fred/series/observations?series_id=${seriesId}&file_type=json&sort_order=desc&limit=5&api_key=${env.FRED_API_KEY}`
        );
        if (fredResp.ok) {
          const data = await fredResp.text();
          await env.CACHE_KV.put(`global:${seriesId}`, data, {
            expirationTtl: 3600, // 1시간
          });
        }
      } catch (e) { console.error(`[Cron] FRED ${seriesId} warming failed:`, e); }
    }
  }

  console.log('[Cron] Global data warming completed');
}

function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}
```

### 9.4 Cron 리소스 사용량

```
Pre-market Cron (UTC 13:00, 매 평일):
  Finnhub quotes: 100 tickers (10 batches × 10, 각 2초 간격) = ~20초, 100 API calls
  Global data:    3 calls (F&G, 환율, FRED×2)
  KV writes:      100 (quotes) + 3 (global) = 103 writes
  실행 시간:      ~25초

Post-market Cron (UTC 21:00, 매 평일):
  Finnhub quotes: 100 tickers = 100 API calls
  FMP profiles:   최대 100 tickers (대부분 KV 캐시됨, 실제 ~10) = ~10 API calls
  Global data:    3 calls
  KV writes:      100 + 10 + 3 = ~113 writes
  실행 시간:      ~30초

Weekend Cron (UTC 12:00, 일요일):
  FMP profiles:   만료된 프로필만 (~15) = ~15 API calls
  Global data:    3 calls
  KV writes:      ~18 writes
  실행 시간:      ~10초

주간 합계:
  Cron Worker 요청:    10 cron/week (5+5 평일 + 1 주말) × 1 = 11 요청
  Finnhub API:         100 × 10 = 1,000 calls/week (Cron 경유)
  FMP API:             ~25 calls/week (Cron 경유)
  KV writes:           (103 + 113) × 5 + 18 = 1,098 writes/week
  일일 KV writes:      ~157 writes/day (Cron만)
```

### 9.5 wrangler.toml Cron 설정

```toml
[triggers]
crons = [
  "0 13 * * 1-5",   # Pre-market warming (UTC 13:00, Mon-Fri)
  "0 21 * * 1-5",   # Post-market warming (UTC 21:00, Mon-Fri)
  "0 12 * * 0",     # Weekend warming (UTC 12:00, Sun)
]
```

---

## 10. 개선 5: Finnhub WebSocket 중계 (미래)

> **우선순위**: FUTURE (유료 전환 시)  
> **상태**: 문서화만, 현재 구현하지 않음

### 10.1 현재 문제

- 각 브라우저가 `wss://ws.finnhub.io?token=KEY`에 직접 연결
- Finnhub 공식 한도: **1 WebSocket 연결** (무료 티어)
- 실제로는 느슨하게 적용되어 여러 연결이 되지만, 100명 시 불안정 예상
- API 키가 WebSocket URL에 노출

### 10.2 목표 아키텍처 (미래)

```
현재:
  Browser A ──WS──▶ Finnhub
  Browser B ──WS──▶ Finnhub
  Browser C ──WS──▶ Finnhub
  (100개 WS 연결 = 키 노출 + 한도 초과)

미래:
  Browser A ──SSE──▶ Durable Object ──WS──▶ Finnhub
  Browser B ──SSE──▶     (1개만)         (1개만)
  Browser C ──SSE──▶
  (1개 WS → SSE 팬아웃)
```

### 10.3 필요 조건

- **Durable Objects**: $0.15/million requests (Workers Paid plan $5/month 필요)
- **구현 복잡도**: WebSocket → SSE 변환, 구독 관리, 연결 풀링
- **트리거**: >20 동시 접속 사용자에서 WS 연결 실패율 >10% 관측 시

### 10.4 임시 대응 (현재)

- WebSocket 연결 유지 (직접 연결)
- `_rapidFailureThreshold` (3회) + exponential backoff로 장애 대응
- WS 연결 실패 시 REST polling 폴백 (기존 `StockQuoteNotifier` 로직)
- 모니터링: `connectionStatus` getter로 연결 상태 추적

---

## 11. 개선 6: Exchange Rate 프록시 추가

> **우선순위**: MEDIUM  
> **이유**: 3-API 폴백 체인이 클라이언트에서 실행됨, Twelve Data API 키 노출

### 11.1 현재 구조 (`exchange_rate_service.dart`)

```
현재:
  Browser → TwelveData Forex (직접, API 키 노출)
         → open.er-api.com (직접, 폴백)
         → Frankfurter (직접, 폴백)
```

100명이 각각 환율을 조회하면 TwelveData 8/min 한도에 영향을 줄 수 있다.

### 11.2 새로운 Worker 라우트

| 라우트 | 캐시 | 원본 |
|--------|------|------|
| `/api/exchange-rate?from=USD&to=KRW` | KV 10min + Cache API 10min | TwelveData → open.er-api → Frankfurter |

```javascript
async function handleExchangeRate(request, env, url) {
  if (request.method !== 'GET') {
    return jsonError('GET only', 405, request);
  }

  const from = (url.searchParams.get('from') || 'USD').toUpperCase();
  const to = (url.searchParams.get('to') || 'KRW').toUpperCase();
  const kvKey = `exchange_rate:${from}_${to}`;

  // 1차: KV 확인
  if (env.CACHE_KV) {
    try {
      const kvData = await env.CACHE_KV.get(kvKey, 'text');
      if (kvData) {
        return new Response(kvData, {
          status: 200,
          headers: {
            'Content-Type': 'application/json',
            'X-Cache': 'KV-HIT',
            ...corsHeaders(request),
          },
        });
      }
    } catch (e) { /* KV 실패 시 무시 */ }
  }

  // 2차: Cache API 확인
  const cacheKey = new Request(`https://cache.exchangerate/${from}/${to}`, request);
  const cache = caches.default;
  let cachedResponse = await cache.match(cacheKey);
  if (cachedResponse) {
    const headers = new Headers(cachedResponse.headers);
    Object.entries(corsHeaders(request)).forEach(([k, v]) => headers.set(k, v));
    headers.set('X-Cache', 'HIT');
    return new Response(cachedResponse.body, { status: cachedResponse.status, headers });
  }

  // 3차: 폴백 체인으로 환율 조회
  let rateData = null;

  // 3a: Twelve Data Forex
  if (env.TWELVE_DATA_API_KEY) {
    try {
      const resp = await fetch(
        `https://api.twelvedata.com/exchange_rate?symbol=${from}/${to}&apikey=${env.TWELVE_DATA_API_KEY}`
      );
      if (resp.ok) {
        const data = await resp.json();
        if (data.rate) {
          rateData = JSON.stringify({
            rate: parseFloat(data.rate),
            timestamp: data.timestamp || Math.floor(Date.now() / 1000),
            source: 'Twelve Data',
          });
        }
      }
    } catch (e) { /* 다음 폴백 */ }
  }

  // 3b: open.er-api.com
  if (!rateData) {
    try {
      const resp = await fetch(`https://open.er-api.com/v6/latest/${from}`);
      if (resp.ok) {
        const data = await resp.json();
        if (data.result === 'success' && data.rates?.[to]) {
          rateData = JSON.stringify({
            rate: data.rates[to],
            timestamp: data.time_last_update_unix || Math.floor(Date.now() / 1000),
            source: 'ExchangeRate-API',
          });
        }
      }
    } catch (e) { /* 다음 폴백 */ }
  }

  // 3c: Frankfurter
  if (!rateData) {
    try {
      const resp = await fetch(
        `https://api.frankfurter.app/latest?from=${from}&to=${to}`
      );
      if (resp.ok) {
        const data = await resp.json();
        if (data.rates?.[to]) {
          rateData = JSON.stringify({
            rate: data.rates[to],
            timestamp: Math.floor(Date.now() / 1000),
            source: 'Frankfurter',
          });
        }
      }
    } catch (e) { /* 전부 실패 */ }
  }

  if (!rateData) {
    return jsonError('All exchange rate sources failed', 502, request);
  }

  const cacheTTL = 600; // 10분

  // KV 저장
  if (env.CACHE_KV) {
    try {
      await env.CACHE_KV.put(kvKey, rateData, { expirationTtl: cacheTTL });
    } catch (e) { /* KV 쓰기 실패 무시 */ }
  }

  // Cache API 저장
  const responseToCache = new Response(rateData, {
    status: 200,
    headers: {
      'Content-Type': 'application/json',
      'Cache-Control': `public, max-age=${cacheTTL}`,
    },
  });
  await cache.put(cacheKey, responseToCache.clone());

  return new Response(rateData, {
    status: 200,
    headers: {
      'Content-Type': 'application/json',
      'Cache-Control': `public, max-age=${cacheTTL}`,
      'X-Cache': 'MISS',
      ...corsHeaders(request),
    },
  });
}
```

### 11.3 앱 변경 (`exchange_rate_service.dart`)

```dart
// 변경 전: 3-API 폴백 체인 (클라이언트)
Future<ExchangeRate> getRate({required String from, required String to}) async {
  try { return await _getTwelveDataRate(from: from, to: to); } catch (e) {}
  try { return await _getOpenErApiRate(from: from, to: to); } catch (e) {}
  return _frankfurterFallback(from: from, to: to);
}

// 변경 후: Worker 우선, 로컬 폴백
Future<ExchangeRate> getRate({required String from, required String to}) async {
  // 1차: Worker 프록시 (폴백 체인 서버에서 처리)
  if (AppConfig.useProxy) {
    try {
      final response = await _dio.get(
        '${AppConfig.proxyBaseUrl}/api/exchange-rate',
        queryParameters: {'from': from, 'to': to},
      );
      final data = response.data;
      return ExchangeRate(
        fromCurrency: from.toUpperCase(),
        toCurrency: to.toUpperCase(),
        rate: (data['rate'] as num).toDouble(),
        timestamp: DateTime.fromMillisecondsSinceEpoch(
          ((data['timestamp'] as num?)?.toInt() ?? 0) * 1000,
        ),
        source: data['source'] as String?,
      );
    } catch (e) {
      // Worker 실패 시 기존 폴백 체인으로
    }
  }

  // 2차: 기존 로컬 폴백 체인 (로컬 개발 또는 Worker 장애)
  try { return await _getTwelveDataRate(from: from, to: to); } catch (e) {}
  try { return await _getOpenErApiRate(from: from, to: to); } catch (e) {}
  return _frankfurterFallback(from: from, to: to);
}
```

### 11.4 예상 절감 효과

```
변경 전:
  100명 × ~30 환율 호출/day = ~3,000 calls/day (TwelveData에 집중)
  TwelveData: 8/min 한도에 환율까지 가산

변경 후:
  실제 TwelveData 환율 호출: ~144/day (10분 캐시, 24hr)
  100명 모두 Worker 공유 캐시 사용
  TwelveData 8/min 부담: 차트만 남음  ✅
```

---

## 12. KV 스키마 설계

### 12.1 키 네이밍 규칙

```
{namespace}:{identifier}[:{sub_identifier}]
```

### 12.2 전체 KV 키 목록

| 키 패턴 | 값 형식 | TTL | 쓰기 주체 | 예시 |
|---------|---------|-----|-----------|------|
| `quote:{SYMBOL}` | JSON (Finnhub quote 원본 + `_cachedAt`) | 57,600초 (16hr) | Cron만 | `quote:NVDA` |
| `profile:{SYMBOL}` | JSON (Finnhub profile2 원본) | 604,800초 (7일) | 요청 시 + Cron | `profile:AAPL` |
| `metric:{SYMBOL}` | JSON (Finnhub metric 원본) | 86,400초 (24hr) | 요청 시 | `metric:TSLA` |
| `earnings:{SYMBOL}` | JSON (Finnhub earnings 원본) | 604,800초 (7일) | 요청 시 | `earnings:MSFT` |
| `fmp_profile:{SYMBOL}` | JSON (FMP profile 원본) | 604,800초 (7일) | 요청 시 + Cron | `fmp_profile:NVDA` |
| `income:{SYMBOL}:{PERIOD}` | JSON (FMP income-statement 원본) | 2,592,000초 (30일) | 요청 시 | `income:AAPL:annual` |
| `translate:{LANG}:{LANG}:{HASH}` | 번역된 텍스트 (plain text) | 없음 (영구) | 요청 시 | `translate:EN:KO:a1b2c3d4` |
| `exchange_rate:{FROM}_{TO}` | JSON (`{rate, timestamp, source}`) | 600초 (10min) | 요청 시 + Cron | `exchange_rate:USD_KRW` |
| `fear_greed:latest` | JSON (CNN F&G 원본) | 3,600초 (1hr) | Cron | `fear_greed:latest` |
| `global:{SERIES_ID}` | JSON (FRED observations 원본) | 3,600초 (1hr) | Cron | `global:DCOILWTICO` |
| `warm:tickers` | JSON array (string[]) | 없음 (수동 관리) | 수동 | `warm:tickers` |
| `warm:last_run` | JSON (`{type, timestamp, duration_ms, tickers_count}`) | 없음 (덮어쓰기) | Cron | `warm:last_run` |

### 12.3 값 크기 추정

| 키 유형 | 단건 크기 | 예상 총 건수 | 총 용량 |
|---------|----------|-------------|---------|
| quote | ~500 B | 100 | ~50 KB |
| profile (Finnhub) | ~1 KB | 500 | ~500 KB |
| metric | ~3 KB | 200 | ~600 KB |
| earnings | ~2 KB | 200 | ~400 KB |
| fmp_profile | ~2 KB | 500 | ~1 MB |
| income | ~5 KB | 500 | ~2.5 MB |
| translate | ~200 B | 5,000 | ~1 MB |
| exchange_rate | ~100 B | 5 | ~500 B |
| fear_greed | ~50 KB | 1 | ~50 KB |
| global | ~2 KB | 5 | ~10 KB |
| warm:* | ~3 KB | 2 | ~6 KB |
| **합계** | | | **~6.1 MB** |

**저장 한도: 1 GB → 사용률 ~0.6%**

### 12.4 KV 네임스페이스 바인딩

`wrangler.toml`:

```toml
[[kv_namespaces]]
binding = "CACHE_KV"
id = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"  # wrangler kv:namespace create CACHE_KV
```

Worker 코드에서 `env.CACHE_KV`로 접근.

---

## 13. Worker 코드 변경 사항

### 13.1 새로 추가할 라우트

| 라우트 | 핸들러 함수 | 메서드 |
|--------|------------|--------|
| `/api/finnhub/quote` | `handleFinnhub` | GET |
| `/api/finnhub/search` | `handleFinnhub` | GET |
| `/api/finnhub/company-news` | `handleFinnhub` | GET |
| `/api/finnhub/profile2` | `handleFinnhub` | GET |
| `/api/finnhub/metric` | `handleFinnhub` | GET |
| `/api/finnhub/earnings` | `handleFinnhub` | GET |
| `/api/finnhub/news` | `handleFinnhub` | GET |
| `/api/exchange-rate` | `handleExchangeRate` | GET |

### 13.2 수정할 기존 라우트

| 라우트 | 변경 내용 |
|--------|-----------|
| `/api/deepl/translate` | KV 번역 캐시 레이어 추가 |
| `/api/fmp/*` | KV 캐시 레이어 추가 (profile 7일, income 30일) |
| `/api/feargreed` | KV 체크 추가 (Cron 워밍 데이터 우선) |
| `/api/fred/*` | KV 체크 추가 (Cron 워밍 데이터 우선) |

### 13.3 새로 추가할 함수 (모듈별)

> 각 함수의 위치는 섹션 4 모듈화 설계를 따른다.

| 함수 | 모듈 파일 | 목적 |
|------|-----------|------|
| `handleFinnhub(request, env, url)` | `src/handlers/finnhub.js` | Finnhub REST 프록시 (7개 엔드포인트 통합) |
| `getFinnhubCacheConfig(subPath, symbol, url)` | `src/handlers/finnhub.js` | Finnhub 엔드포인트별 캐시 전략 |
| `handleExchangeRate(request, env, url)` | `src/handlers/exchange-rate.js` | 환율 프록시 (3-API 폴백) |
| `getFMPKVConfig(fmpPath, symbol, url)` | `src/handlers/fmp.js` | FMP KV 캐시 전략 |
| `canCall()` | `src/utils/rate-limiter.js` | Rate limit 체크 (55/min) |
| `recordCall()` | `src/utils/rate-limiter.js` | Rate limit 호출 기록 |
| `getCached(env, kvKey, cacheKey)` | `src/utils/cache.js` | 통합 캐시 조회 (KV → Cache API) |
| `setCached(env, kvKey, kvTTL, cacheKey, cacheTTL, data)` | `src/utils/cache.js` | 통합 캐시 저장 (KV + Cache API) |
| `hashText(text)` | `src/utils/helpers.js` | SHA-256 해시 (번역 캐시 키) |
| `sleep(ms)` | `src/utils/helpers.js` | 유틸리티 |
| `runCacheWarming(event, env)` | `src/cron/warming.js` | Cron 메인 핸들러 |
| `warmFinnhubQuotes(env, tickers)` | `src/cron/warming.js` | Finnhub 시세 배치 워밍 |
| `warmFMPProfiles(env, tickers)` | `src/cron/warming.js` | FMP 프로필 워밍 |
| `warmGlobalData(env)` | `src/cron/warming.js` | 글로벌 데이터 워밍 (F&G, 환율, FRED) |

### 13.4 새 환경 변수

| 변수명 | 용도 | 현재 상태 |
|--------|------|-----------|
| `FINNHUB_API_KEY` | Finnhub REST 프록시 | **새로 추가** |
| `DEEPL_API_KEY` | DeepL 번역 | 기존 |
| `FRED_API_KEY` | FRED 경제 데이터 | 기존 |
| `TWELVE_DATA_API_KEY` | TwelveData 차트 + 환율 | 기존 |
| `FMP_API_KEY` | FMP 재무제표 | 기존 |

### 13.5 KV 네임스페이스 바인딩

| 바인딩 이름 | 용도 |
|-------------|------|
| `CACHE_KV` | 모든 영속 캐시 (quotes, profiles, translations...) |

### 13.6 Cron Trigger 설정

```
crons = ["0 13 * * 1-5", "0 21 * * 1-5", "0 12 * * 0"]
```

### 13.7 라우터 변경 (fetch 핸들러)

> 모듈화 후 라우터는 `src/index.js`에 위치한다. 전체 라우터 코드는 섹션 4.3을 참조.

```javascript
// src/index.js — 핸들러 import + 라우트 매칭
import { handleFinnhub } from './handlers/finnhub.js';
import { handleFMP } from './handlers/fmp.js';
import { handleDeepL } from './handlers/deepl.js';
import { handleExchangeRate } from './handlers/exchange-rate.js';
import { handleMarketNews, GLOBAL_RSS_FEEDS, KOREA_RSS_FEEDS } from './handlers/news.js';
import { handleTwelveData } from './handlers/twelvedata.js';
import { handleFRED } from './handlers/fred.js';
import { handleFearGreed } from './handlers/feargreed.js';
import { runCacheWarming } from './cron/warming.js';
import { corsHeaders } from './utils/cors.js';
import { jsonError } from './utils/helpers.js';

export default {
  async fetch(request, env) {
    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: corsHeaders(request) });
    }

    const url = new URL(request.url);

    // ── 새 라우트 ──
    if (url.pathname.startsWith('/api/finnhub/')) return handleFinnhub(request, env, url);
    if (url.pathname === '/api/exchange-rate') return handleExchangeRate(request, env, url);

    // ── 기존 라우트 (수정: KV 레이어 추가) ──
    if (url.pathname.startsWith('/api/fmp/')) return handleFMP(request, env, url);
    if (url.pathname === '/api/twelvedata/chart') return handleTwelveData(request, env, url);
    if (url.pathname === '/api/deepl/translate') return handleDeepL(request, env);
    if (url.pathname === '/api/feargreed') return handleFearGreed(request, env);
    if (url.pathname.startsWith('/api/fred/')) return handleFRED(request, env, url);
    if (url.pathname === '/api/news/market') return handleMarketNews(request, GLOBAL_RSS_FEEDS, 20);
    if (url.pathname === '/api/news/korea') return handleMarketNews(request, KOREA_RSS_FEEDS, 10);

    return jsonError('Not found', 404, request);
  },

  async scheduled(event, env, ctx) {
    ctx.waitUntil(runCacheWarming(event, env));
  },
};
```

### 13.8 코드 규모 추정

> 모듈화 후 총 줄 수는 동일하지만, 14개 파일로 분산되어 평균 ~98줄/파일이 된다.

| 모듈 파일 | 줄 수 | 내용 |
|-----------|-------|------|
| `src/index.js` | ~80 | 라우터 + scheduled 핸들러 |
| `src/handlers/finnhub.js` | ~180 | handleFinnhub + getFinnhubCacheConfig |
| `src/handlers/fmp.js` | ~120 | handleFMP + getFMPKVConfig |
| `src/handlers/deepl.js` | ~130 | handleDeepL (KV 캐시 추가) |
| `src/handlers/exchange-rate.js` | ~130 | handleExchangeRate + 3-API 폴백 |
| `src/handlers/news.js` | ~200 | handleMarketNews + RSS 파싱 |
| `src/handlers/twelvedata.js` | ~80 | handleTwelveData |
| `src/handlers/fred.js` | ~50 | handleFRED (KV 체크 추가) |
| `src/handlers/feargreed.js` | ~50 | handleFearGreed (KV 체크 추가) |
| `src/cron/warming.js` | ~200 | runCacheWarming + 3개 워밍 함수 |
| `src/utils/cors.js` | ~25 | ALLOWED_ORIGINS + corsHeaders |
| `src/utils/cache.js` | ~60 | getCached + setCached |
| `src/utils/rate-limiter.js` | ~30 | canCall + recordCall |
| `src/utils/helpers.js` | ~30 | jsonError + sleep + hashText |
| **총 합계** | **~1,365줄** | **14개 파일, 평균 ~98줄** |

> 단일 `worker.js` 1,213줄 대비 약 150줄 증가 (import/export 선언 오버헤드). 대신 가장 큰 파일이 200줄 이하로 유지된다.

---

## 14. Flutter 앱 코드 변경 사항

### 14.1 파일별 변경 목록

#### `lib/core/config/app_config.dart`

**변경 없음.** `useProxy`, `proxyBaseUrl`, `finnhubApiKey` 등 기존 구조 유지. Finnhub API 키는 로컬 개발 폴백용으로 유지하되, 프로덕션에서는 Worker가 서버사이드로 주입하므로 클라이언트에 노출되지 않는다.

> **참고**: `build.sh`에서 `FINNHUB_API_KEY`를 `--dart-define`으로 주입하는 것은 유지. 로컬 개발 + WebSocket 직접 연결에 필요.

#### `lib/data/services/api/finnhub_service.dart`

**변경 범위**: 생성자 + `getExchange()` + `getCompanyLogo()` 경로 변경

```
변경 사항:
1. 생성자: baseUrl을 useProxy 분기로 변경
2. queryParameters: useProxy 시 token 제거
3. getExchange(): '/stock/profile2' → useProxy 시 '/profile2'
4. getCompanyLogo(): '/stock/profile2' → useProxy 시 '/profile2'
5. getQuote(), searchStocks(), getNews(): 경로 동일 (변경 불필요)
```

#### `lib/data/services/api/financial_service.dart`

**변경 범위**: `getMetrics()` + `getEarnings()` 호출 경로

```
변경 사항:
1. getMetrics(): finnhubBaseUrl → useProxy 시 proxyBaseUrl/api/finnhub/metric
2. getEarnings(): finnhubBaseUrl → useProxy 시 proxyBaseUrl/api/finnhub/earnings
3. 두 메서드 모두 token 파라미터를 useProxy 분기로 처리
4. getProfile(), getIncomeStatements(): 변경 없음 (이미 Worker 경유)
```

#### `lib/data/services/api/exchange_rate_service.dart`

**변경 범위**: `getRate()` 메서드에 Worker 프록시 우선 호출 추가

```
변경 사항:
1. getRate(): Worker 프록시 우선 호출 추가 (섹션 11.3 참조)
2. 기존 폴백 체인은 유지 (로컬 개발 + Worker 장애 대응)
3. Worker 응답 형식에 맞는 파싱 로직 추가
```

#### `lib/data/services/api/news_service.dart`

**변경 범위**: `_fetchFinnhub()` + `_getGeneralNewsFromFinnhub()` 경로 변경

```
변경 사항:
1. _fetchFinnhub(): finnhubBaseUrl → useProxy 시 proxyBaseUrl/api/finnhub/company-news
2. _getGeneralNewsFromFinnhub(): finnhubBaseUrl → useProxy 시 proxyBaseUrl/api/finnhub/news
3. 두 메서드 모두 token 파라미터를 useProxy 분기로 처리
4. _translateTitles(): 변경 없음 (Worker가 동일 응답 형식 유지)
5. getGeneralNews(), getKoreaNews(): 변경 없음 (이미 Worker 경유)
```

### 14.2 변경하지 않는 파일

| 파일 | 이유 |
|------|------|
| `app_config.dart` | 기존 구조 유지 |
| `twelve_data_service.dart` | 이미 Worker 경유 |
| `fear_greed_service.dart` | 이미 Worker 경유 |
| `fred_service.dart` | 이미 Worker 경유 |
| `tradingview_service.dart` | 공개 API, 키 불필요, 변경 불필요 |
| `finnhub_websocket_service.dart` | 직접 연결 유지 (미래 과제) |
| `api_client.dart` | 공통 클라이언트, 변경 불필요 |
| `api_exception.dart` | 예외 모델, 변경 불필요 |

### 14.3 앱 코드 변경 규모

> `proxy_config.dart` 신규 파일로 프록시 분기 로직을 중앙화한다 (섹션 4.5 참조).

| 파일 | 변경 유형 | 변경 줄 수 | 난이도 |
|------|-----------|-----------|--------|
| `proxy_config.dart` | **신규** | ~80줄 | 낮음 |
| `finnhub_service.dart` | 수정 | ~15줄 | 낮음 |
| `financial_service.dart` | 수정 | ~15줄 | 낮음 |
| `exchange_rate_service.dart` | 수정 | ~25줄 | 중간 |
| `news_service.dart` | 수정 | ~15줄 | 낮음 |
| **합계** | | **~150줄** | |

> `proxy_config.dart` 80줄 추가로 총 줄 수는 늘어나지만, 각 서비스 파일의 `AppConfig.useProxy` 분기가 제거되어 **순 변경량은 감소**한다. 프록시 관련 로직이 한 파일에 집중되므로 향후 Worker URL 변경 시 1곳만 수정하면 된다.

---

## 15. 무료 한도 계산

### 15.1 Workers 요청 수 (100명 기준)

**사용자 행동 모델**:
- 평균 세션: 2회/일, 각 15분
- 앱 시작: 환율 + 시세 + F&G + 뉴스 = ~5 Worker 요청
- 홈 화면: 지수 차트 + 글로벌 지표 = ~5 Worker 요청
- 관심종목 탭: 10종목 시세 = ~10 Worker 요청
- 종목 상세: 차트 + 뉴스 + 재무 = ~8 Worker 요청
- 세션당 총: ~28 Worker 요청

```
일일 Worker 요청:
  사용자 요청:  100명 × 2 세션 × 28 req = 5,600 req/day
  Cron 워밍:    ~220 req/day (Finnhub + FMP + global)
  ────────────────────────────────────
  합계:         ~5,820 req/day
  한도:         100,000 req/day
  사용률:       ~6%  ✅ SAFE (여유 94%)

  보수적 추정 (피크일, 세션 3회):
  합계:         ~8,600 req/day
  사용률:       ~9%  ✅ SAFE
```

### 15.2 KV 읽기 (100명 기준)

```
KV 읽기 계산:
  Finnhub quote KV 조회:         5,600 × 40% quote 비중 = ~2,240 reads
  Finnhub profile/metric/earnings: 5,600 × 15% = ~840 reads
  FMP profile/income KV 조회:    5,600 × 10% = ~560 reads
  DeepL translate KV 조회:       5,600 × 15% = ~840 reads  (텍스트별 개별 조회)
  Exchange rate KV 조회:         5,600 × 10% = ~560 reads
  Fear & Greed KV 조회:         5,600 × 5% = ~280 reads
  FRED KV 조회:                 5,600 × 5% = ~280 reads
  ────────────────────────────────────
  합계:                          ~5,600 reads/day
  한도:                          100,000 reads/day
  사용률:                        ~6%  ✅ SAFE
```

### 15.3 KV 쓰기 (100명 기준)

```
KV 쓰기 계산:
  Cron 워밍 (평일):
    quote × 100:                  100 writes
    global (F&G, 환율, FRED):     4 writes
    FMP profile (신규만):          ~5 writes
    warm:last_run:                1 write
    소계:                         ~110 writes × 2 cron = 220 writes/day

  요청 시 캐시 미스 (추정):
    Finnhub profile miss:          ~5 writes
    Finnhub metric miss:           ~10 writes
    Finnhub earnings miss:         ~3 writes
    FMP profile miss:              ~3 writes
    FMP income miss:               ~5 writes
    DeepL translate 신규:          ~30 writes
    Exchange rate (10min TTL):     ~144 writes (24hr ÷ 10min)
    소계:                         ~200 writes/day

  ────────────────────────────────────
  합계:                          ~420 writes/day
  한도:                          1,000 writes/day
  사용률:                        ~42%  ✅ SAFE

  주말 (Cron 1회, 트래픽 감소):
  합계:                          ~100 writes/day
  사용률:                        ~10%  ✅ SAFE
```

### 15.4 실제 API 호출 (최적화 후)

| API | 최적화 전 (100명) | 최적화 후 | 무료 한도 | 상태 |
|-----|-------------------|-----------|-----------|------|
| Finnhub REST | ~500/min 피크 | ~0.35/min 평균, ~10/min 피크 | 60/min | ✅ SAFE |
| FMP | ~3,000/day | ~30/day | 250/day | ✅ SAFE |
| DeepL | ~300K chars/mo | ~150K chars/mo | 500K chars/mo | ✅ SAFE |
| Twelve Data | ~300/day | ~300/day (차트 동일) | 800/day, 8/min | ✅ OK |
| FRED | ~200/day | ~200/day (이미 프록시) | 120/min | ✅ SAFE |
| CNN F&G | ~100/day | ~48/day (캐시 30min) | 공개 | ✅ SAFE |

### 15.5 한도 요약 대시보드

```
┌─────────────────────────────────────────────────────────────────┐
│                    100명 기준 무료 한도 사용률                      │
├─────────────────────────┬──────────┬──────────┬─────────────────┤
│ 리소스                   │ 사용량    │ 한도      │ 사용률           │
├─────────────────────────┼──────────┼──────────┼─────────────────┤
│ Worker 요청/일           │ 5,820    │ 100,000  │ ██░░░░░░░░  6%  │
│ KV 읽기/일               │ 5,600    │ 100,000  │ ██░░░░░░░░  6%  │
│ KV 쓰기/일               │ 420      │ 1,000    │ ████░░░░░░ 42%  │
│ KV 저장                  │ 6 MB     │ 1 GB     │ █░░░░░░░░░  1%  │
│ Finnhub REST/min         │ <10 피크  │ 60       │ ██░░░░░░░░ 17%  │
│ FMP/day                  │ 30       │ 250      │ ██░░░░░░░░ 12%  │
│ DeepL chars/mo           │ 150K     │ 500K     │ ███░░░░░░░ 30%  │
│ Twelve Data/day          │ 300      │ 800      │ ████░░░░░░ 38%  │
└─────────────────────────┴──────────┴──────────┴─────────────────┘
  병목 지점: KV 쓰기 42% (exchange rate 10min TTL이 주 원인)
  여유분:    Worker 요청이 가장 넉넉 (94% 여유)
```

---

## 16. 구현 순서

### Phase 0: 모듈화 마이그레이션 (~1.5시간)

> **전제 조건**: 기존 `worker.js`가 정상 동작하는 상태에서 시작  
> **목표**: 단일 파일 → 모듈 구조 전환 (기능 변경 없음)

| 작업 | 상세 | 예상 시간 |
|------|------|-----------|
| 0-1. 디렉토리 구조 생성 | `src/handlers/`, `src/cron/`, `src/utils/` | 2분 |
| 0-2. package.json 생성 | `"type": "module"` 설정 | 2분 |
| 0-3. utils/ 추출 | `cors.js`, `helpers.js` 추출 | 15분 |
| 0-4. 핸들러 추출 (1/6) | `feargreed.js`, `fred.js` 추출 + 테스트 | 10분 |
| 0-5. 핸들러 추출 (2/6) | `news.js`, `deepl.js` 추출 + 테스트 | 15분 |
| 0-6. 핸들러 추출 (3/6) | `twelvedata.js`, `fmp.js` 추출 + 테스트 | 15분 |
| 0-7. index.js 라우터 정리 | 라우터를 `src/index.js`로 이동 | 10분 |
| 0-8. wrangler.toml 업데이트 | `main = "src/index.js"` | 2분 |
| 0-9. 전체 회귀 테스트 | 모든 엔드포인트 curl 검증 | 15분 |
| 0-10. 배포 | `wrangler deploy` | 5분 |

**검증**:
- 모든 기존 엔드포인트가 동일하게 응답하는지 확인
- `X-Cache` 헤더, 응답 형식, CORS 동작 모두 변경 없음
- 기존 `worker.js` 삭제 후 git에서 이력 보존

> **상세 마이그레이션 절차**: 섹션 4.8 참조

### Phase 1: 즉시 적용 가능 (Worker만 변경, ~2시간)

**목표**: FMP + DeepL 최적화 (앱 코드 변경 없음)

| 작업 | 상세 | 대상 파일 | 예상 시간 |
|------|------|-----------|-----------|
| 1-1. KV 네임스페이스 생성 | `wrangler kv:namespace create CACHE_KV` | wrangler CLI | 5분 |
| 1-2. warm:tickers 초기값 등록 | `wrangler kv:key put ...` | wrangler CLI | 5분 |
| 1-3. cache.js 유틸 작성 | `getCached()`, `setCached()` 통합 캐시 함수 | `src/utils/cache.js` | 20분 |
| 1-4. FMP 핸들러 KV 레이어 추가 | `getCached`/`setCached` 적용 | `src/handlers/fmp.js` | 25분 |
| 1-5. DeepL 핸들러 KV 캐시 추가 | 해시 기반 KV 캐시 | `src/handlers/deepl.js` | 40분 |
| 1-6. wrangler.toml 업데이트 | KV 바인딩 + env vars | `wrangler.toml` | 10분 |
| 1-7. 배포 및 테스트 | `wrangler deploy` + curl 검증 | - | 15분 |

**검증**:
- `curl Worker/api/fmp/profile?symbol=AAPL` → 첫 요청 `X-Cache: MISS`, 두 번째 `X-Cache: KV-HIT`
- `curl -X POST Worker/api/deepl/translate -d '{"text":["Hello"],...}'` → 첫 `X-Cache: MISS`, 두 번째 `X-Cache: KV-HIT`

### Phase 2: 핵심 프록시 (Worker + 앱 변경, ~4시간)

**목표**: Finnhub REST + Exchange Rate 프록시

| 작업 | 상세 | 대상 파일 | 예상 시간 |
|------|------|-----------|-----------|
| 2-1. FINNHUB_API_KEY env 추가 | `wrangler secret put` | Cloudflare | 5분 |
| 2-2. rate-limiter.js 작성 | `canCall()`, `recordCall()` | `src/utils/rate-limiter.js` | 10분 |
| 2-3. handleFinnhub 구현 | 7개 엔드포인트 + Rate limiter | `src/handlers/finnhub.js` | 60분 |
| 2-4. handleExchangeRate 구현 | 3-API 폴백 + 통합 캐시 | `src/handlers/exchange-rate.js` | 40분 |
| 2-5. index.js 라우터 업데이트 | 새 라우트 추가 | `src/index.js` | 5분 |
| 2-6. Worker 배포 + 테스트 | curl로 모든 엔드포인트 검증 | - | 20분 |
| 2-7. proxy_config.dart 작성 | ProxyConfig 중앙화 클래스 | `proxy_config.dart` | 20분 |
| 2-8. finnhub_service.dart 수정 | ProxyConfig 적용 | `finnhub_service.dart` | 15분 |
| 2-9. financial_service.dart 수정 | ProxyConfig 적용 | `financial_service.dart` | 15분 |
| 2-10. news_service.dart 수정 | ProxyConfig 적용 | `news_service.dart` | 10분 |
| 2-11. exchange_rate_service.dart 수정 | ProxyConfig 적용 | `exchange_rate_service.dart` | 15분 |
| 2-12. 빌드 + E2E 테스트 | `./build.sh` + Playwright 검증 | - | 30분 |

**검증**:
- 브라우저 DevTools에서 Finnhub 직접 호출이 없는지 확인
- Worker Analytics에서 `/api/finnhub/*` 요청 확인
- `X-Cache` 헤더로 캐시 히트율 확인

### Phase 3: 자동화 (Cron, ~3시간)

**목표**: Cron 캐시 워밍

| 작업 | 상세 | 대상 파일 | 예상 시간 |
|------|------|-----------|-----------|
| 3-1. warming.js 구현 | runCacheWarming + 3개 워밍 함수 | `src/cron/warming.js` | 80분 |
| 3-2. index.js scheduled 핸들러 | `import { runCacheWarming }` | `src/index.js` | 5분 |
| 3-3. wrangler.toml Cron 추가 | 3개 Cron 트리거 | `wrangler.toml` | 5분 |
| 3-4. 배포 | `wrangler deploy` | - | 5분 |
| 3-5. Cron 수동 테스트 | `wrangler dev` → Cron 탭에서 트리거 | - | 30분|
| 3-6. KV 데이터 검증 | `wrangler kv:key get` 으로 워밍 데이터 확인 | - | 15분|
| 3-7. 모니터링 설정 | Cloudflare Dashboard 확인 | - | 15분 |

**검증**:
- `wrangler kv:key get --namespace-id=xxx "warm:last_run"` → 타임스탬프 확인
- `wrangler kv:key get --namespace-id=xxx "quote:NVDA"` → 시세 데이터 확인
- Cloudflare Dashboard > Workers > Cron Triggers > 실행 이력 확인

### Phase 4: 미래 (필요 시)

| 작업 | 트리거 | 예상 비용 |
|------|--------|-----------|
| Finnhub WS 중계 | >20 동시접속, WS 실패율 >10% | Workers Paid $5/mo + DO 사용량 |
| MarketAux 프록시 | API 키 보호 필요 시 | Worker 요청 추가 (무료 범위 내) |
| TradingView 프록시 | CORS 문제 발생 시 | Worker 요청 추가 (무료 범위 내) |

---

## 17. 롤백 계획

### 17.1 Phase별 독립 롤백

각 Phase는 독립적으로 롤백 가능하다.

| Phase | 롤백 방법 | 영향 범위 |
|-------|-----------|-----------|
| Phase 0 (모듈화) | `wrangler.toml`의 `main`을 `worker.js`로 복원 후 배포 | 단일 파일로 복귀, 기능 동일 |
| Phase 1 (FMP/DeepL KV) | Worker를 이전 버전으로 배포 | KV 미사용, 기존 Cache API만 동작 |
| Phase 2 (Finnhub/환율 프록시) | 앱에서 `useProxy=false` 빌드 또는 Worker 이전 버전 | 직접 호출로 복귀 |
| Phase 3 (Cron) | wrangler.toml에서 crons 제거 후 배포 | Cron 중단, 온디맨드 캐시만 동작 |

### 17.2 앱 측 폴백 메커니즘

모든 서비스에 `AppConfig.useProxy` 분기가 이미 있거나 추가된다:

```dart
// 이미 존재하는 패턴 (financial_service.dart)
if (AppConfig.useProxy) {
  url = '${AppConfig.proxyBaseUrl}/api/fmp/profile';
} else {
  url = '${AppConfig.fmpBaseUrl}/profile';
  queryParams['apikey'] = AppConfig.fmpApiKey;
}
```

**Worker 장애 시 자동 폴백**:
- `financial_service.dart`: 이미 `_getProfileDirect()`, `_getIncomeStatementsDirect()` 폴백 구현
- `exchange_rate_service.dart`: Worker 실패 시 기존 3-API 폴백 체인 유지
- `news_service.dart`: Worker 실패 시 `_getGeneralNewsFromFinnhub()` 폴백 유지
- `fear_greed_service.dart`: Worker 실패 시 CORS 프록시 폴백 유지

**`finnhub_service.dart` 폴백 추가** (새로 필요):

```dart
// Worker 실패 시 직접 호출 폴백
Future<StockQuote> getQuote(String symbol) async {
  try {
    final response = await _dio.get('/quote', queryParameters: {
      'symbol': symbol.toUpperCase(),
    });
    return _parseQuoteResponse(symbol, response.data);
  } on DioException catch (e) {
    // Worker 장애 시 직접 호출 폴백
    if (AppConfig.useProxy && AppConfig.finnhubApiKey.isNotEmpty) {
      return _getQuoteDirect(symbol);
    }
    throw NetworkException(message: '시세 조회 실패: ${e.message}', originalError: e);
  }
}

Future<StockQuote> _getQuoteDirect(String symbol) async {
  final directDio = Dio(BaseOptions(
    baseUrl: AppConfig.finnhubBaseUrl,
    queryParameters: {'token': AppConfig.finnhubApiKey},
  ));
  final response = await directDio.get('/quote', queryParameters: {
    'symbol': symbol.toUpperCase(),
  });
  return _parseQuoteResponse(symbol, response.data);
}
```

### 17.3 롤백 절차

```
1. 문제 감지: Cloudflare Dashboard 또는 앱 에러 로그
2. 원인 파악:
   - Worker 에러 → Worker 이전 버전 배포
   - KV 한도 초과 → Cron 중지 + KV 쓰기 감소
   - API 한도 초과 → 캐시 TTL 늘리기
3. 롤백 실행:
   - Worker: wrangler rollback 또는 이전 코드 배포
   - 앱: PROXY_BASE_URL 빈 문자열로 빌드 (직접 호출 모드)
4. 검증: 앱 정상 동작 확인
```

---

## 18. 모니터링

### 18.1 Cloudflare Dashboard 기본 모니터링

- **Workers > Analytics**: 요청 수, 에러율, CPU 시간, 응답 시간
- **Workers > Cron Triggers**: Cron 실행 이력, 성공/실패
- **KV > Analytics**: 읽기/쓰기 수, 저장 용량

### 18.2 커스텀 모니터링 (Worker 코드)

```javascript
// 응답 헤더에 캐시 상태 포함 (이미 구현)
headers.set('X-Cache', 'HIT' | 'MISS' | 'KV-HIT' | 'PARTIAL-HIT');

// Cron 실행 결과를 KV에 기록 (이미 구현)
await env.CACHE_KV.put('warm:last_run', JSON.stringify({...}));
```

### 18.3 앱 측 모니터링

브라우저 콘솔에서 확인 가능한 정보:
- 네트워크 탭: Worker 요청의 `X-Cache` 헤더
- WebSocket 연결 상태: `connectionStatus` getter

### 18.4 알림 기준

| 지표 | 경고 | 위험 | 조치 |
|------|------|------|------|
| Worker 요청/일 | >50,000 (50%) | >80,000 (80%) | 캐시 TTL 늘리기 |
| KV 쓰기/일 | >700 (70%) | >900 (90%) | exchange rate TTL 늘리기 (10min → 30min) |
| KV 읽기/일 | >70,000 (70%) | >90,000 (90%) | Cache API 우선으로 전환 |
| Finnhub API/min | >40 (67%) | >50 (83%) | Rate limiter 강화 |
| FMP API/day | >150 (60%) | >200 (80%) | KV TTL 늘리기 |
| Worker 에러율 | >1% | >5% | 로그 확인, 롤백 검토 |

---

## 19. 엣지 케이스

### 19.1 Worker 장애

**시나리오**: Cloudflare Worker가 다운되거나 응답 시간 초과

**대응**:
- 앱의 모든 서비스에 `try-catch` + 직접 호출 폴백이 있거나 추가
- `financial_service.dart`: 이미 `_getProfileDirect()`, `_getIncomeStatementsDirect()` 구현
- `fear_greed_service.dart`: CORS 프록시 폴백 구현
- `news_service.dart`: Finnhub 폴백 구현
- `finnhub_service.dart`: 직접 호출 폴백 추가 필요 (섹션 17.2 참조)
- `exchange_rate_service.dart`: 기존 3-API 폴백 체인 유지

### 19.2 KV 할당량 초과

**시나리오**: KV 쓰기 1,000/day 또는 읽기 100,000/day 초과

**대응**:
- KV 접근은 항상 `try-catch`로 감싸여 있음
- KV 실패 시 Cache API로 폴백 (Cache API는 무제한)
- 쓰기 초과 방지: exchange rate TTL을 10min → 30min으로 동적 조정
- 읽기 초과 방지: Cache API를 KV보다 먼저 체크하도록 순서 변경 가능

```javascript
// KV 쓰기 실패 시 자동 처리
try {
  await env.CACHE_KV.put(key, data, { expirationTtl: ttl });
} catch (e) {
  // KV 쓰기 실패 = 무시, Cache API가 백업 역할
  console.error('[KV] Write failed:', e.message);
}
```

### 19.3 Cron 실패

**시나리오**: Cron 트리거가 실행되지 않거나 중간에 실패

**대응**:
- Cron이 실패해도 앱은 정상 동작 (온디맨드 캐시로 동작)
- 사용자 요청 시 KV 미스 → Cache API 미스 → API 직접 호출 → 캐시 저장
- 다음 Cron에서 자동 복구
- `warm:last_run` KV 키로 마지막 실행 시각 확인 가능

### 19.4 새 종목 (Warm 리스트 미포함)

**시나리오**: 사용자가 warm 리스트에 없는 종목을 조회

**대응**:
- KV 미스 + Cache API 미스 → 실시간 API 호출 → Cache API에 저장
- 다음 사용자가 같은 종목 조회 시 Cache API 히트
- 인기 상승 종목은 `warm:tickers` 리스트에 수동 추가

```
흐름:
  User A: GET /api/finnhub/quote?symbol=PLTR
    → KV MISS (warm 리스트에 없음)
    → Cache API MISS
    → Finnhub API 호출 → Cache API 저장 (5min)
    → 응답

  User B (3분 후): GET /api/finnhub/quote?symbol=PLTR
    → KV MISS
    → Cache API HIT (5min 이내)
    → 즉시 응답 (Finnhub 호출 안 함)
```

### 19.5 장중 vs 장외 캐시 전략

**시나리오**: 미국 시장 시간에 따라 데이터 신선도 요구가 다름

| 상태 | 시간 (EST) | Quote TTL | 차트 TTL | 환율 TTL |
|------|-----------|-----------|----------|----------|
| 프리마켓 | 04:00~09:30 | 5min | 5min | 10min |
| 정규 장 | 09:30~16:00 | 5min | 5min | 10min |
| 애프터마켓 | 16:00~20:00 | 5min | 5min | 10min |
| 폐장 | 20:00~04:00 | 16hr (Cron) | 6hr | 1hr |
| 주말 | 토~일 | 16hr (Cron) | 6hr | 1hr |

**구현**: 현재는 TTL이 고정이지만, Worker에서 시장 시간을 계산하여 동적 TTL을 적용할 수 있다. 초기 구현에서는 고정 TTL로 시작하고, 필요 시 동적 TTL을 추가한다.

### 19.6 동시 캐시 미스 (Thundering Herd)

**시나리오**: 캐시 만료 직후 100명이 동시에 같은 종목을 요청

**대응**:
- Cache API + KV의 이중 레이어로 완전 동시 미스 확률 감소
- Worker의 Rate Limiter가 Finnhub 60/min 초과 방지
- Rate limit 초과 시 `429` 응답 → 앱이 재시도 또는 캐시된 데이터 사용

**향후 개선** (필요 시):
- Request coalescing: 동일 키에 대한 동시 요청을 하나로 합치기
- Stale-while-revalidate: 만료된 캐시를 즉시 반환하면서 백그라운드 갱신

```javascript
// 향후: Request coalescing 패턴
const pendingRequests = new Map();

async function getWithCoalescing(key, fetchFn) {
  if (pendingRequests.has(key)) {
    return pendingRequests.get(key); // 이미 진행 중인 요청에 합류
  }
  const promise = fetchFn();
  pendingRequests.set(key, promise);
  try {
    return await promise;
  } finally {
    pendingRequests.delete(key);
  }
}
```

### 19.7 Rate Limit 동시성 문제

**시나리오**: Worker가 여러 인스턴스에서 실행되어 Rate Limiter가 정확하지 않음

**대응**:
- Cloudflare Workers는 리전별로 인스턴스가 분산되지만, 한국 사용자 100명은 대부분 같은 리전
- Rate Limiter의 `maxPerMinute`를 55로 여유 확보 (한도 60)
- 캐시 히트율이 높으면 실제 API 호출이 적어 문제 발생 확률 낮음
- 극단적 경우: KV에 글로벌 Rate Limit 카운터 저장 (KV 읽기/쓰기 증가 부담)

---

## 부록: 체크리스트

### 구현 전 확인사항

- [ ] Cloudflare 계정에 Workers Free 플랜 활성화 확인
- [ ] KV 네임스페이스 생성 (`wrangler kv:namespace create CACHE_KV`)
- [ ] FINNHUB_API_KEY를 Worker 환경 변수에 추가
- [ ] 현재 worker.js 백업 (git tag)
- [ ] warm:tickers 초기값 KV에 등록

### Phase별 완료 기준

**Phase 0**:
- [ ] `wrangler.toml`의 `main`이 `src/index.js`를 가리킴
- [ ] 모든 기존 엔드포인트가 동일하게 응답 (curl 검증)
- [ ] 기존 `worker.js` 삭제, git 이력 보존
- [ ] `package.json`에 `"type": "module"` 설정

**Phase 1**:
- [ ] FMP profile 요청: 첫 번째 `X-Cache: MISS`, 두 번째 `X-Cache: KV-HIT`
- [ ] DeepL 같은 텍스트 재요청: `X-Cache: KV-HIT`
- [ ] 기존 모든 라우트 정상 동작 확인

**Phase 2**:
- [ ] `/api/finnhub/quote?symbol=AAPL` 정상 응답
- [ ] `/api/exchange-rate?from=USD&to=KRW` 정상 응답
- [ ] 앱 빌드 후 Finnhub 직접 호출 없음 (브라우저 Network 탭 확인)
- [ ] Worker 장애 시 앱이 직접 호출로 폴백

**Phase 3**:
- [ ] `warm:last_run` KV에 Cron 실행 기록 존재
- [ ] `quote:NVDA` KV에 시세 데이터 존재
- [ ] Cloudflare Dashboard에서 Cron 실행 이력 확인

### 성능 목표

- [ ] 캐시 히트율 > 80% (1주일 운영 후 측정)
- [ ] Worker 평균 응답 시간 < 100ms (캐시 히트 시)
- [ ] Finnhub 실제 API 호출 < 10/min (피크 시)
- [ ] FMP 실제 API 호출 < 50/day
- [ ] 모든 무료 한도 사용률 < 80%
