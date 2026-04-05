# API 통합 가이드: Alpha Cycle

## 개요

알파 사이클 앱은 12개의 외부 API를 조합하여 실시간 시세, 차트, 환율, 뉴스, 시장 심리, 재무제표, 경제 데이터를 제공합니다. 대부분의 API 호출은 **Cloudflare Worker 프록시**(`alpha-cycle-proxy`)를 경유하며, API 키 보호와 KV 공유 캐시를 통해 무료 한도 내에서 다수 사용자를 지원합니다.

| API | 역할 | 무료 한도 | 호출 경로 |
|-----|------|----------|----------|
| **Finnhub** | 실시간 시세 (REST + WebSocket) | 60회/분 | Worker 프록시 (REST) / 직접 (WS) |
| **Twelve Data** | 차트 데이터 (OHLC) + 환율 | 800회/일 (8회/분) | Worker 프록시 |
| **FMP** | 재무제표, 기업 프로필 | 250회/일 | Worker 프록시 (KV 24hr 캐시) |
| **DeepL** | 뉴스 번역 (EN→KO) | 500K 문자/월 | Worker 프록시 (KV 공유 캐시) |
| **FRED** | 미국 연준 경제 데이터 (WTI, 10Y 등) | 120회/분 | Worker 프록시 |
| **open.er-api.com** | 환율 폴백 1 | 무제한 | Worker 프록시 (폴백 체인) |
| **Frankfurter** | 환율 폴백 2 | 무제한 | Worker 프록시 (폴백 체인) |
| **CNN Fear & Greed** | 공포탐욕지수 | 크롤링 기반 | Worker 프록시 |
| **RSS (글로벌/국내)** | 시장 뉴스 | 무제한 | Worker 프록시 |
| **TradingView** | 종목 스캐너 데이터 | 공개 API | 직접 호출 |
| **Finnhub WebSocket** | 실시간 가격 스트리밍 | 1 연결/브라우저 | 직접 연결 |
| **한국수출입은행** | 매매기준율/살때/팔때 | 무제한 (API키 필요) | 직접 호출 (CORS 프록시) |

---

## 왜 두 금융 API를 조합하는가?

### 단일 API의 한계

| API | 실시간 시세 | 차트 데이터 | 문제점 |
|-----|------------|------------|--------|
| Finnhub만 | ✅ 무료 | ❌ 유료만 | 차트 불가 |
| Twelve Data만 | ✅ 무료 | ✅ 무료 | 8회/분 제한 |

### 조합의 장점

- **Finnhub**: 실시간 시세에 최적화 (60회/분, WebSocket 무제한)
- **Twelve Data**: 차트 데이터 무료 제공 (800회/일이면 충분)
- 각 API의 강점만 활용하여 무료로 완전한 기능 구현

---

## 아키텍처

```
┌─────────────────────────────────────────────────────────────────┐
│                     Flutter Web App (Browser)                    │
│                                                                 │
│  ┌─────────────┐  ┌──────────────┐  ┌─────────────────────────┐ │
│  │ Memory Cache │  │  Hive Cache  │  │  API Services           │ │
│  │ (5~30min)   │  │ (translations)│  │  (ProxyConfig 라우팅)    │ │
│  └──────┬──────┘  └──────┬───────┘  └────────┬────────────────┘ │
│         └────────┬───────┘                   │                  │
│                  ▼                           │                  │
│         ┌────────────────┐                   │                  │
│         │  Riverpod      │                   │                  │
│         └────────────────┘                   │                  │
└──────────────────────────────────────────────┼──────────────────┘
                                               │
                    ┌──────────────────────────┼──────────────────────┐
                    │                          │                      │
          ┌─────────▼──────────┐    ┌──────────▼─────────┐           │
          │   직접 호출 (Direct) │    │  Worker 경유 (Proxy)│           │
          │                    │    │                    │           │
          │ - Finnhub WS      │    │ - Finnhub REST     │           │
          │   wss://ws.finnhub │    │   (7개 엔드포인트)  │           │
          │                    │    │ - TwelveData 차트   │           │
          │ - TradingView     │    │ - FMP 재무제표      │           │
          │   scanner API      │    │ - DeepL 번역       │           │
          │                    │    │ - Exchange Rate    │           │
          │ - 한국수출입은행    │    │   (3-API 폴백)     │           │
          │   (CORS proxy)     │    │ - Fear & Greed     │           │
          │                    │    │ - FRED 경제데이터   │           │
          └────────────────────┘    │ - RSS 뉴스         │           │
                    │               └────────┬───────────┘           │
                    ▼                        │                       │
          ┌────────────────┐       ┌─────────▼──────────┐           │
          │ 외부 API 서버들  │       │  Cloudflare Worker  │           │
          │ (공개/키 안전)   │       │  alpha-cycle-proxy  │           │
          └────────────────┘       │                     │           │
                                   │  KV 캐시 (영속)     │           │
                                   │  Cache API (빠름)   │           │
                                   │  Rate Limiter       │           │
                                   │  Cron 캐시 워밍     │           │
                                   └─────────┬──────────┘           │
                                             │                       │
                                   ┌─────────▼──────────┐           │
                                   │ 외부 API 서버들      │           │
                                   │ (키 보호됨)          │           │
                                   └────────────────────┘           │
                                                                     │
                    ┌────────────────────────────────────────────────┘
                    │ Finnhub WS (직접 연결, 브라우저당 1개)
                    ▼
          ┌────────────────┐
          │ wss://ws.finnhub│
          └────────────────┘
```

---

## API 상세

### 1. Finnhub (실시간 시세)

| 항목 | 내용 |
|------|------|
| 웹사이트 | https://finnhub.io |
| 무료 한도 | 60회/분 |
| 실시간 시세 | ✅ 무료 (현재가, 등락률, 거래량) |
| WebSocket | ✅ 무료 (무제한 종목 구독) |
| 차트 데이터 | ❌ 유료만 (403 에러) |
| 호출 경로 | **REST**: Worker 프록시 (`/api/finnhub/*`) / **WS**: 직접 연결 |
| 키 위치 | Worker 환경변수 `FINNHUB_API_KEY` (REST) / `--dart-define` (WS) |

**REST 엔드포인트 (Worker 프록시)**: 7개 엔드포인트가 Worker를 경유하며, API 키가 서버사이드에서 주입됩니다.

| Worker 경로 | Finnhub 원본 경로 | 캐시 전략 |
|-------------|-------------------|-----------|
| `/api/finnhub/quote` | `/api/v1/quote` | Cache API 5min |
| `/api/finnhub/search` | `/api/v1/search` | Cache API 1hr |
| `/api/finnhub/company-news` | `/api/v1/company-news` | Cache API 30min |
| `/api/finnhub/profile2` | `/api/v1/stock/profile2` | KV 7일 + Cache API 24hr |
| `/api/finnhub/metric` | `/api/v1/stock/metric` | KV 24hr + Cache API 24hr |
| `/api/finnhub/earnings` | `/api/v1/stock/earnings` | KV 7일 + Cache API 24hr |
| `/api/finnhub/news` | `/api/v1/news` | Cache API 30min |

**담당 기능**:

| 기능 | 설명 | 사용량 |
|------|------|--------|
| 실시간 시세 | 현재가, 등락률, 거래량 | 주요 기능 |
| WebSocket | 실시간 가격 스트리밍 (관심종목 포함) | 무제한 |
| 종목 검색 | 티커 심볼 검색 | 낮음 |
| 종목 로고 | 기업 프로필 로고 URL + IndexedDB 캐싱 | 낮음 |
| 재무 지표 | 기본 재무 메트릭 (metric=all) | 낮음 |
| 실적 데이터 | 분기별 EPS/매출 | 낮음 |

**참고**: WebSocket 무료 API 제한으로 간헐적 재연결이 발생하며, 자동 재연결이 정상 동작합니다.

**WebSocket 구독 라이프사이클** (2026-02-19 개선):
- 캐시된 심볼 → state 반영 즉시 WebSocket 구독
- 미캐시 심볼 → REST API 응답 후 WebSocket 구독 (race condition 방지)
- **전역 구독 유지**: `MainShell`(ConsumerStatefulWidget)이 앱 시작 시 관심종목 로드 + WS 구독, 탭 전환 시 해제 안 함
- WebSocket이 REST보다 먼저 도착 시 최소 StockQuote 자동 생성 (데이터 드롭 방지)
- 보호 필터: 장 마감(`CLOSED`) 시 WS 무시, 5% 이상 급변 시 비정상 데이터 필터링

### 2. Twelve Data (차트 데이터)

| 항목 | 내용 |
|------|------|
| 웹사이트 | https://twelvedata.com |
| 무료 한도 | 800회/일 (8회/분) |
| 차트 데이터 | ✅ 무료 (OHLC 캔들) |
| 지원 간격 | `1day`, `1week`, `1month` |
| 호출 경로 | Worker 프록시 (`/api/twelvedata/chart`) |
| 키 위치 | Worker 환경변수 `TWELVE_DATA_API_KEY` |

**담당 기능**:

| 기능 | 설명 | 사용량 |
|------|------|--------|
| 일봉 차트 | 일간 OHLC 데이터 | 주요 기능 |
| 주봉/월봉 | 장기 차트 데이터 | 보조 |

### 3. 환율 시스템 (2026-04-05 Worker 프록시 전환)

**Worker 환율 엔드포인트**: `/api/exchange-rate?from=USD&to=KRW`

Worker 내부에서 3-API 폴백 체인을 실행하고, KV 10min + Cache API 10min으로 공유 캐시합니다.

| 우선순위 | API | 특징 |
|----------|-----|------|
| Primary | Twelve Data Forex | 실시간 1분 갱신 |
| Fallback 1 | open.er-api.com | 하루 1회 갱신 (UTC 자정) |
| Fallback 2 | api.frankfurter.app | 하루 1회 갱신 |

프록시 미사용 시(`AppConfig.useProxy == false`) 기존 직접 호출 폴백 체인이 그대로 동작합니다.

**UI**: 홈 환율 칩 탭 → 바텀시트에서 실시간 환율 표시

### 4. FMP — Financial Modeling Prep (재무제표)

| 항목 | 내용 |
|------|------|
| 웹사이트 | https://financialmodelingprep.com |
| 무료 한도 | 250회/일 |
| 호출 경로 | Worker 프록시 (`/api/fmp/profile`, `/api/fmp/income-statement`) |
| 캐시 전략 | KV 7일 (profile) + Cache API 24hr |
| 키 위치 | Worker 환경변수 `FMP_API_KEY` |

**담당 기능**: 기업 프로필, 재무제표 (손익계산서)

### 5. DeepL (뉴스 번역)

| 항목 | 내용 |
|------|------|
| 웹사이트 | https://www.deepl.com |
| 무료 한도 | 500K 문자/월 |
| 호출 경로 | Worker 프록시 (`/api/deepl/translate`) |
| 캐시 전략 | KV 공유 캐시 (동일 텍스트 중복 번역 방지) + Hive 로컬 영속 |
| 키 위치 | Worker 환경변수 `DEEPL_API_KEY` |

**담당 기능**: 뉴스 제목/본문 EN→KO 번역 (MyMemory 대체)

### 6. FRED (미국 연준 경제 데이터)

| 항목 | 내용 |
|------|------|
| 웹사이트 | https://fred.stlouisfed.org |
| 무료 한도 | 120회/분 |
| 호출 경로 | Worker 프록시 (`/api/fred/*`) |
| 캐시 전략 | Header Cache 1hr |
| 키 위치 | Worker 환경변수 `FRED_API_KEY` |

**담당 기능**: WTI 유가 (`DCOILWTICO`), 미국 10년물 금리 (`DGS10`) 등 경제 지표

### 7. RSS 뉴스 (글로벌/국내)

| 항목 | 내용 |
|------|------|
| 호출 경로 | Worker 프록시 (`/api/news/market`, `/api/news/korea`) |
| 캐시 전략 | Header Cache 30min |
| 키 필요 | 없음 (공개 RSS) |

**담당 기능**: 글로벌 시장 뉴스 (20건), 국내 경제 뉴스 (10건)

### 8. CNN Fear & Greed Index (시장 심리)

| 항목 | 내용 |
|------|------|
| 소스 | CNN Fear & Greed Index |
| 방식 | 크롤링 기반 |
| 호출 경로 | Worker 프록시 (`/api/feargreed`) |
| 캐시 전략 | Header Cache 30min + Cron KV 워밍 (1hr) |
| 키 필요 | 없음 |
| 표시 | 게이지 차트 (0~100, 5단계) |

### 9. TradingView (종목 스캐너)

| 항목 | 내용 |
|------|------|
| 호출 경로 | 직접 호출 (`scanner.tradingview.com`) |
| 캐시 전략 | 메모리 5min |
| 키 필요 | 없음 (공개 API, CORS 지원) |

**담당 기능**: 종목 스캐너 데이터

---

## 심볼 매핑

Twelve Data와 MarketAux는 지수 심볼 형식이 다르므로 매핑이 필요합니다.

| 앱 내부 심볼 | Twelve Data / MarketAux 심볼 | 설명 |
|-------------|----------------------------|------|
| `^NDX` | `QQQ` | NASDAQ 100 |
| `^GSPC` | `SPY` | S&P 500 |

---

## 구현 상태

### API 연동

- [x] Finnhub REST API 연동 (Worker 프록시, 7개 엔드포인트)
- [x] Finnhub WebSocket 서비스 (직접 연결, 실시간 스트리밍)
- [x] Twelve Data 차트 데이터 연동 (Worker 프록시, 일봉/주봉/월봉)
- [x] 환율 API 연동 (Worker 프록시, 3-API 폴백 체인)
- [x] 한국수출입은행 매매기준율 연동 (매매기준/살때/팔때)
- [x] FMP 재무제표 연동 (Worker 프록시, KV 캐시)
- [x] DeepL 번역 연동 (Worker 프록시, KV 공유 캐시)
- [x] FRED 경제 데이터 연동 (Worker 프록시)
- [x] RSS 뉴스 연동 (Worker 프록시, 글로벌/국내)
- [x] CNN Fear & Greed Index 연동 (Worker 프록시, 게이지 차트)
- [x] TradingView 종목 스캐너 연동 (직접 호출)

### Cloudflare Worker 인프라

- [x] Worker 모듈화 구조 (`src/handlers/`, `src/utils/`, `src/cron/`)
- [x] KV 캐시 레이어 (`CACHE_KV` 바인딩)
- [x] Cache API + KV 이중 캐시 (`getCached`/`setCached`)
- [x] Finnhub Rate Limiter (60/min 보호)
- [x] Cron 캐시 워밍 (평일 개장 전/폐장 후 + 주말)
- [x] ProxyConfig 중앙화 라우팅 (`proxy_config.dart`)

### 차트 및 UI

- [x] 홈 화면 차트 표시 (NASDAQ 100, S&P 500 캔들스틱)
- [x] 종목 상세 차트 표시 (확대/축소/스크롤, 우측 끝 고정)
- [x] 기술 지표 (VOL, BB, RSI, MACD, STOCH, Ichimoku, OBV)
- [x] 이동평균선 (MA 5, 20, 60, 120일)
- [x] 피봇 포인트 (R2, R1, Pivot, S1, S2)
- [x] 기간 수익률 (1D, 1W, 1M, 3M, YTD, 1Y)
- [x] 관심종목 실시간 WebSocket 시세

---

## 파일 구조

```
cloudflare-worker/
├── wrangler.toml                           # Worker 설정 (KV 바인딩, Cron 스케줄)
└── src/
    ├── index.js                            # 라우터 진입점 (fetch + scheduled)
    ├── handlers/
    │   ├── finnhub.js                      # Finnhub REST 프록시 (7개 엔드포인트)
    │   ├── twelvedata.js                   # Twelve Data 차트 프록시
    │   ├── fmp.js                          # FMP 재무제표 프록시
    │   ├── deepl.js                        # DeepL 번역 프록시
    │   ├── exchange-rate.js                # 환율 3-API 폴백 프록시
    │   ├── feargreed.js                    # CNN Fear & Greed 프록시
    │   ├── fred.js                         # FRED 경제 데이터 프록시
    │   └── news.js                         # RSS 뉴스 (글로벌/국내)
    ├── utils/
    │   ├── cache.js                        # getCached/setCached (KV + Cache API)
    │   ├── cors.js                         # CORS 헤더
    │   ├── helpers.js                      # jsonError 등 유틸
    │   └── rate-limiter.js                 # Finnhub 60/min Rate Limiter
    └── cron/
        └── warming.js                      # Cron 캐시 워밍 (quotes, profiles, global)

lib/
├── core/
│   └── config/
│       └── app_config.dart                # API 키 + 프록시 URL 설정
├── data/
│   ├── repositories/
│   │   └── notification_repository.dart   # 알림 내역 CRUD (Hive)
│   └── services/
│       ├── api/
│       │   ├── proxy_config.dart           # 프록시 라우팅 중앙화 (Finnhub, FMP, ExchangeRate)
│       │   ├── api_client.dart            # HTTP 클라이언트
│       │   ├── api_exception.dart         # API 예외 처리
│       │   ├── exchange_rate_service.dart  # 환율 (Worker 프록시 or 직접 폴백)
│       │   ├── fear_greed_service.dart     # CNN Fear & Greed Index
│       │   ├── financial_service.dart      # Finnhub 재무 + FMP 재무제표
│       │   ├── finnhub_service.dart        # Finnhub REST API (Worker 프록시 경유)
│       │   ├── finnhub_websocket_service.dart  # Finnhub WebSocket (직접 연결)
│       │   ├── fred_service.dart           # FRED 경제 데이터
│       │   ├── news_service.dart           # RSS 뉴스 + DeepL 번역
│       │   ├── tradingview_service.dart    # TradingView 스캐너 (직접 호출)
│       │   └── twelve_data_service.dart    # Twelve Data 차트 OHLC
│       ├── background/
│       │   ├── background_task_handler.dart
│       │   └── price_check_service.dart
│       ├── cache/
│       │   ├── cache_manager.dart
│       │   └── logo_cache_service.dart     # 종목 로고 IndexedDB 캐싱
│       ├── notification/
│       │   ├── notification_channels.dart
│       │   ├── notification_service.dart
│       │   └── web_notification_service.dart
│       └── technical_indicator_service.dart  # RSI, MACD, BB, Stochastic, Ichimoku, OBV
└── presentation/
    └── providers/
        ├── api_providers.dart             # Finnhub Provider
        ├── logo_provider.dart             # 종목 로고 Provider
        ├── market_data_providers.dart     # 시장 데이터 Provider
        ├── fear_greed_providers.dart      # 공포탐욕지수 Provider
        ├── notification_history_provider.dart  # 알림 내역 Provider
        └── watchlist_alert_provider.dart  # 관심종목 알림 Provider + 내역 저장
```

---

## API 사용량 예측

Worker 캐시 덕분에 동일 데이터에 대한 중복 API 호출이 제거됩니다. 아래는 **Worker 캐시 적용 후** 실제 원본 API 호출 예상량입니다.

### 일일 사용량 (예상, Worker 캐시 후)

| 기능 | API | 예상 호출 (원본) | 한도 | 여유 |
|------|-----|-----------------|------|------|
| 시세 조회 | Finnhub | ~200회 (캐시 5min) | 86,400회/일 | 충분 |
| 차트 로딩 | Twelve Data | ~50회 | 800회/일 | 충분 |
| 환율 | Worker 폴백 체인 | ~144회 (10min 캐시) | 800회/일 | 충분 |
| 재무제표 | FMP | ~30회 (24hr 캐시) | 250회/일 | 충분 |
| 번역 | DeepL | ~100건 (KV 공유) | 500K 문자/월 | 충분 |
| 경제 데이터 | FRED | ~24회 (1hr 캐시) | 120회/분 | 충분 |
| 뉴스 | RSS | ~48회 (30min 캐시) | 무제한 | 충분 |
| 환율 (매매기준) | 한국수출입은행 | ~5회 | 무제한 | 충분 |

### 사용 시나리오

1. **앱 시작**: 시장 지수 + 관심종목 시세 (Worker Finnhub) + 환율 (Worker) + Fear & Greed (Worker)
2. **홈 화면 차트**: NASDAQ 100 + S&P 500 캔들스틱 (Worker Twelve Data)
3. **종목 상세**: 시세 + 차트 + 재무 + 뉴스 (Worker Finnhub + Twelve Data + FMP + RSS)
4. **실시간 업데이트**: Finnhub WebSocket (직접 연결, 무제한)
5. **뉴스 번역**: DeepL (Worker 프록시, KV 공유 캐시로 중복 제거)

---

## Cloudflare Worker 프록시

### 개요

`cloudflare-worker/` 디렉토리에 모듈화된 Cloudflare Worker가 배포되어 있습니다. Worker 이름은 `alpha-cycle-proxy`이며, 앱의 대부분의 API 호출을 중계합니다.

### 역할

1. **API 키 보호**: 모든 API 키가 Worker 환경변수에 저장되어 클라이언트에 노출되지 않음
2. **공유 캐시**: KV + Cache API 이중 캐시로 사용자 간 동일 데이터 공유
3. **Rate Limiting**: Finnhub 60/min 한도를 서버사이드에서 보호
4. **CORS 처리**: Worker가 CORS 헤더를 일괄 처리
5. **Cron 캐시 워밍**: 인기 종목 데이터를 사전 캐시하여 API 호출 최소화

### Worker 라우트 맵

| Worker 경로 | 핸들러 | 원본 API |
|-------------|--------|----------|
| `/api/finnhub/*` | `handlers/finnhub.js` | Finnhub REST (7개 엔드포인트) |
| `/api/twelvedata/chart` | `handlers/twelvedata.js` | Twelve Data OHLC |
| `/api/fmp/*` | `handlers/fmp.js` | FMP 재무제표 |
| `/api/deepl/translate` | `handlers/deepl.js` | DeepL 번역 |
| `/api/exchange-rate` | `handlers/exchange-rate.js` | 환율 3-API 폴백 |
| `/api/feargreed` | `handlers/feargreed.js` | CNN Fear & Greed |
| `/api/fred/*` | `handlers/fred.js` | FRED 경제 데이터 |
| `/api/news/market` | `handlers/news.js` | 글로벌 RSS 뉴스 |
| `/api/news/korea` | `handlers/news.js` | 국내 경제 RSS 뉴스 |

### 환경변수

Worker에 필요한 Secret은 `wrangler secret put`으로 설정합니다.

| 변수 | 용도 |
|------|------|
| `FINNHUB_API_KEY` | Finnhub REST 프록시 |
| `TWELVE_DATA_API_KEY` | Twelve Data 차트 + 환율 |
| `FMP_API_KEY` | FMP 재무제표 |
| `DEEPL_API_KEY` | DeepL 번역 |
| `FRED_API_KEY` | FRED 경제 데이터 |

### KV 바인딩

- **`CACHE_KV`**: 통합 캐시 네임스페이스 (quotes, profiles, translations, exchange rates 등)

### Cron 캐시 워밍

`wrangler.toml`에 설정된 스케줄로 자동 워밍이 실행됩니다.

| Cron | KST | 유형 | 워밍 대상 |
|------|-----|------|-----------|
| `0 13 * * 1-5` | 22:00 평일 | Pre-market | Finnhub quotes (100종목, 10개씩 배치) + Global |
| `0 22 * * 1-5` | 07:00 평일 | Post-market | Finnhub quotes + FMP profiles (신규/만료) + Global |
| `0 12 * * SUN` | 21:00 일요일 | Weekend | FMP profiles + Global |

**Global 워밍 대상**: Fear & Greed, USD/KRW 환율, FRED (WTI, 10Y)

워밍할 종목 리스트는 KV의 `warm:tickers` 키에 JSON 배열로 저장합니다.

### Flutter 앱 연동 — ProxyConfig

`lib/data/services/api/proxy_config.dart`가 프록시 라우팅을 중앙 관리합니다.

- `AppConfig.useProxy == true` (프로덕션): Worker 경유
- `AppConfig.useProxy == false` (로컬 개발): 직접 호출 (기존 방식)

`PROXY_BASE_URL`은 `--dart-define=PROXY_BASE_URL=https://xxx.workers.dev`로 빌드 시 주입합니다.

---

## 캐시 전략 요약

> 상세 설계: `docs/API_CACHE_STRATEGY.md` 참조

### 캐시 레이어

| 레이어 | 위치 | TTL | 특징 |
|--------|------|-----|------|
| **1차: Memory Cache** | 브라우저 (Provider) | 5~30min | 앱 내 즉시 응답 |
| **2차: KV** | Cloudflare Edge (영속) | 10min~7일 | 사용자 간 공유, 축출 없음 |
| **3차: Cache API** | Cloudflare Edge (CDN) | 5min~24hr | 빠르지만 임의 축출 가능 |
| **4차: API 원본** | 외부 서버 | - | 캐시 미스 시 호출 |

### 서비스별 캐시 TTL

| 서비스 | KV TTL | Cache API TTL | 비고 |
|--------|--------|---------------|------|
| Finnhub /quote | - | 5min | 실시간성 우선 |
| Finnhub /profile2 | 7일 | 24hr | 변경 빈도 낮음 |
| Finnhub /metric, /earnings | 24hr~7일 | 24hr | 변경 빈도 낮음 |
| Twelve Data 차트 | - | 5min~6hr | interval별 차등 |
| FMP 재무제표 | 7일 | 24hr | 분기별 갱신 |
| DeepL 번역 | 영속 | - | 동일 텍스트 영구 캐시 |
| 환율 | 10min | 10min | 실시간성 + 공유 |
| Fear & Greed | 1hr (Cron) | 30min | Cron 워밍 |
| FRED | 1hr (Cron) | 1hr | 일별 갱신 |
| RSS 뉴스 | - | 30min | Header Cache |

---

## 주의사항

### Finnhub
- 차트 데이터 요청 시 403 에러 발생 (무료 미지원) -- Twelve Data로 대체
- WebSocket 연결 시 구독 메시지 필요
- 무료 API 제한으로 간헐적 재연결 발생 (자동 재연결 동작 정상)
- WebSocket 무료 티어 동시 구독 제한 (~10-15 심볼) → 탭 이탈 시 구독 해제 필수
- REST는 Worker 프록시 경유, WS는 직접 연결 (Durable Objects 미도입 상태)

### Twelve Data
- 8회/분 제한 주의 (Worker 캐시로 완화)
- 무료 티어는 US, Forex, Crypto만 지원
- 지수 심볼 매핑 필요 (`^NDX` → `QQQ`, `^GSPC` → `SPY`)

### 환율
- Worker 프록시 사용 시: Worker 내부에서 3-API 폴백 체인 실행 (KV 10min 캐시)
- Worker 미사용 시: 앱이 직접 Twelve Data → open.er-api.com → Frankfurter 폴백
- 한국수출입은행은 별도 트랙 (매매기준율/살때/팔때, 12시간 캐시)
- 한국수출입은행 CORS 미지원 → `corsproxy.io` 프록시 사용

### 뉴스
- RSS 기반 뉴스로 전환 (글로벌 + 국내)
- DeepL 번역은 KV 공유 캐시로 중복 번역 방지
- 외부 뉴스 썸네일 이미지 CORS 차단은 정상 (코드 문제 아님)

### 공통
- **프로덕션**: API 키는 Worker 환경변수로 보호, 클라이언트에 노출 없음
- **로컬 개발**: API 키는 `app_config.dart` 또는 `--dart-define`으로 관리 (Worker 미사용)
- `PROXY_BASE_URL` 설정 여부로 프록시/직접 호출을 자동 전환
- 에러 발생 시 graceful degradation 처리

---

## 참고 링크

- Finnhub 문서: https://finnhub.io/docs/api
- Twelve Data 문서: https://twelvedata.com/docs
- FMP 문서: https://site.financialmodelingprep.com/developer/docs
- DeepL 문서: https://developers.deepl.com/docs
- FRED 문서: https://fred.stlouisfed.org/docs/api/fred/
- open.er-api.com: https://open.er-api.com
- Frankfurter: https://api.frankfurter.app
- Cloudflare Workers: https://developers.cloudflare.com/workers/
- 캐시 전략 상세: `docs/API_CACHE_STRATEGY.md`

---

*최종 수정: 2026-04-05 (Cloudflare Worker 프록시 아키텍처 반영 — Finnhub REST/환율 프록시 전환, 모듈화 구조, Cron 캐시 워밍)*
