# API 통합 가이드: Alpha Cycle

## 개요

알파 사이클 앱은 7개의 외부 API를 조합하여 실시간 시세, 차트, 환율, 뉴스, 시장 심리 데이터를 제공합니다. 모든 API는 CORS를 지원하며 프록시 서버 없이 직접 호출합니다.

| API | 역할 | 무료 한도 |
|-----|------|----------|
| **Finnhub** | 실시간 시세, WebSocket | 60회/분 |
| **Twelve Data** | 차트 데이터 (OHLC) | 800회/일 (8회/분) |
| **open.er-api.com** | 환율 (Primary) | 무제한 |
| **Frankfurter** | 환율 (Fallback) | 무제한 |
| **MarketAux** | 뉴스 데이터 | 무료 한도 내 |
| **MyMemory** | 뉴스 번역 (EN→KO) | 무제한 |
| **CNN Fear & Greed** | 공포탐욕지수 | 크롤링 기반 |

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
┌───────────────────────────────────────────────────────────────┐
│                       알파 사이클 앱                            │
├───────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐    │
│  │   Finnhub    │  │  Twelve Data │  │  open.er-api.com │    │
│  ├──────────────┤  ├──────────────┤  │  + Frankfurter   │    │
│  │ 실시간 시세    │  │ 차트 데이터   │  ├──────────────────┤    │
│  │ WebSocket    │  │ OHLC 캔들    │  │ USD/KRW 환율     │    │
│  │ 종목 검색     │  │              │  └──────────────────┘    │
│  └──────────────┘  └──────────────┘                          │
│         │                 │          ┌──────────────────┐    │
│         │                 │          │    MarketAux     │    │
│         │                 │          │   + MyMemory     │    │
│  ┌──────────────┐         │          ├──────────────────┤    │
│  │ CNN Fear &   │         │          │ 뉴스 + 한국어 번역 │    │
│  │ Greed Index  │         │          └──────────────────┘    │
│  └──────────────┘         │                   │              │
│         │                 │                   │              │
│         ▼                 ▼                   ▼              │
│  ┌───────────────────────────────────────────────────┐       │
│  │              통합 Provider Layer (Riverpod)        │       │
│  └───────────────────────────────────────────────────┘       │
│                                                               │
└───────────────────────────────────────────────────────────────┘
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
| CORS | ✅ 지원 |
| 키 위치 | `lib/core/config/app_config.dart` |

**담당 기능**:

| 기능 | 설명 | 사용량 |
|------|------|--------|
| 실시간 시세 | 현재가, 등락률, 거래량 | 주요 기능 |
| WebSocket | 실시간 가격 스트리밍 (관심종목 포함) | 무제한 |
| 종목 검색 | 티커 심볼 검색 | 낮음 |
| 종목 로고 | 기업 프로필 로고 URL + IndexedDB 캐싱 | 낮음 |

**참고**: WebSocket 무료 API 제한으로 간헐적 재연결이 발생하며, 자동 재연결이 정상 동작합니다.

**WebSocket 구독 라이프사이클** (2026-02-19 개선):
- 캐시된 심볼 → state 반영 즉시 WebSocket 구독
- 미캐시 심볼 → REST API 응답 후 WebSocket 구독 (race condition 방지)
- 화면 이탈 시 (`dispose()`) WebSocket 구독 해제 (무료 티어 ~10-15 심볼 제한 관리)
- WebSocket이 REST보다 먼저 도착 시 최소 StockQuote 자동 생성 (데이터 드롭 방지)
- 보호 필터: 장 마감(`CLOSED`) 시 WS 무시, 5% 이상 급변 시 비정상 데이터 필터링

### 2. Twelve Data (차트 데이터)

| 항목 | 내용 |
|------|------|
| 웹사이트 | https://twelvedata.com |
| 무료 한도 | 800회/일 (8회/분) |
| 차트 데이터 | ✅ 무료 (OHLC 캔들) |
| 지원 간격 | `1day`, `1week`, `1month` |
| CORS | ✅ 지원 |
| 키 위치 | `lib/core/config/app_config.dart` |

**담당 기능**:

| 기능 | 설명 | 사용량 |
|------|------|--------|
| 일봉 차트 | 일간 OHLC 데이터 | 주요 기능 |
| 주봉/월봉 | 장기 차트 데이터 | 보조 |

### 3. open.er-api.com + Frankfurter (환율)

| 항목 | 내용 |
|------|------|
| Primary | https://open.er-api.com (CORS 지원) |
| Fallback | https://api.frankfurter.app (CORS 지원) |
| 대상 | USD/KRW |
| 키 필요 | 없음 (무료) |

### 4. MarketAux + MyMemory (뉴스)

| 항목 | 내용 |
|------|------|
| 뉴스 소스 | MarketAux (https://www.marketaux.com) |
| 번역 | MyMemory (EN→KO, 무료, 키 불필요) |
| 제외 도메인 | `finance.yahoo.com` |
| 키 위치 | `lib/core/config/app_config.dart` (MarketAux만) |

### 5. CNN Fear & Greed Index (시장 심리)

| 항목 | 내용 |
|------|------|
| 소스 | CNN Fear & Greed Index |
| 방식 | 크롤링 기반 |
| 키 필요 | 없음 |
| 표시 | 게이지 차트 (0~100, 5단계) |

---

## 심볼 매핑

Twelve Data와 MarketAux는 지수 심볼 형식이 다르므로 매핑이 필요합니다.

| 앱 내부 심볼 | Twelve Data / MarketAux 심볼 | 설명 |
|-------------|----------------------------|------|
| `^NDX` | `QQQ` | NASDAQ 100 |
| `^GSPC` | `SPY` | S&P 500 |

---

## 구현 상태 (전체 완료)

- [x] Finnhub REST API 연동 (실시간 시세)
- [x] Finnhub WebSocket 서비스 (실시간 스트리밍)
- [x] Twelve Data 차트 데이터 연동 (일봉/주봉/월봉)
- [x] 환율 API 연동 (open.er-api.com + Frankfurter 폴백)
- [x] MarketAux 뉴스 연동 + MyMemory 한국어 번역
- [x] CNN Fear & Greed Index 연동 (게이지 차트)
- [x] 홈 화면 차트 표시 (NASDAQ 100, S&P 500 캔들스틱)
- [x] 종목 상세 차트 표시 (확대/축소/스크롤, 우측 끝 고정)
- [x] 기술 지표 (VOL, BB, RSI, MACD, STOCH, Ichimoku, OBV)
- [x] 이동평균선 (MA 5, 20, 60, 120일)
- [x] 피봇 포인트 (R2, R1, Pivot, S1, S2)
- [x] 기간 수익률 (1D, 1W, 1M, 3M, YTD, 1Y)
- [x] 관심종목 실시간 WebSocket 시세
- [x] 프록시 서버 제거 (직접 CORS 호출)

---

## 파일 구조

```
lib/
├── core/
│   └── config/
│       └── app_config.dart                # API 키 설정
├── data/
│   └── services/
│       ├── api/
│       │   ├── api_client.dart            # HTTP 클라이언트
│       │   ├── api_exception.dart         # API 예외 처리
│       │   ├── exchange_rate_service.dart  # 환율 (open.er-api.com + Frankfurter)
│       │   ├── fear_greed_service.dart     # CNN Fear & Greed Index
│       │   ├── finnhub_service.dart        # Finnhub REST API
│       │   ├── finnhub_websocket_service.dart  # Finnhub WebSocket
│       │   ├── news_service.dart           # MarketAux 뉴스 + MyMemory 번역
│       │   └── twelve_data_service.dart    # Twelve Data 차트 OHLC
│       ├── background/
│       │   ├── background_task_handler.dart
│       │   └── price_check_service.dart
│       ├── cache/
│       │   ├── cache_manager.dart
│       │   └── logo_cache_service.dart  # 종목 로고 IndexedDB 캐싱
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
        └── watchlist_alert_provider.dart  # 관심종목 알림 Provider
```

---

## API 사용량 예측

### 일일 사용량 (예상)

| 기능 | API | 예상 호출 | 한도 | 여유 |
|------|-----|----------|------|------|
| 시세 조회 | Finnhub | ~500회 | 86,400회/일 | 충분 |
| 차트 로딩 | Twelve Data | ~50회 | 800회/일 | 충분 |
| 환율 | open.er-api.com | ~10회 | 무제한 | 충분 |
| 뉴스 | MarketAux | ~20회 | 무료 한도 내 | 충분 |
| 번역 | MyMemory | ~20회 | 무제한 | 충분 |

### 사용 시나리오

1. **앱 시작**: 시장 지수 + 관심종목 시세 (Finnhub ~10회) + 환율 (1회) + Fear & Greed (1회)
2. **홈 화면 차트**: NASDAQ 100 + S&P 500 캔들스틱 (Twelve Data 2회)
3. **종목 상세**: 시세 + 차트 + 뉴스 (Finnhub 1회 + Twelve Data 1회 + MarketAux 1회)
4. **실시간 업데이트**: Finnhub WebSocket (무제한)
5. **뉴스 번역**: MyMemory (뉴스 건수만큼, 무제한)

---

## 주의사항

### Finnhub
- 차트 데이터 요청 시 403 에러 발생 (무료 미지원) -- Twelve Data로 대체
- WebSocket 연결 시 구독 메시지 필요
- 무료 API 제한으로 간헐적 재연결 발생 (자동 재연결 동작 정상)
- WebSocket 무료 티어 동시 구독 제한 (~10-15 심볼) → 탭 이탈 시 구독 해제 필수

### Twelve Data
- 8회/분 제한 주의 (연속 요청 시 지연 필요)
- 무료 티어는 US, Forex, Crypto만 지원
- 지수 심볼 매핑 필요 (`^NDX` → `QQQ`, `^GSPC` → `SPY`)

### 환율
- Primary(open.er-api.com) 실패 시 자동으로 Frankfurter 폴백
- `koreaexim`, `exchangerate.host`는 사용하지 않음 (완전 제거됨)

### 뉴스
- MarketAux에서 `finance.yahoo.com` 도메인 제외 설정
- 외부 뉴스 썸네일 이미지 CORS 차단은 정상 (코드 문제 아님)

### 공통
- API 키는 `app_config.dart` 또는 `--dart-define`으로 관리
- 프록시 서버 불필요 (모든 API가 CORS 직접 지원)
- 에러 발생 시 graceful degradation 처리

---

## 참고 링크

- Finnhub 문서: https://finnhub.io/docs/api
- Twelve Data 문서: https://twelvedata.com/docs
- open.er-api.com: https://open.er-api.com
- Frankfurter: https://api.frankfurter.app
- MarketAux 문서: https://www.marketaux.com/documentation
- MyMemory 문서: https://mymemory.translated.net/doc/

---

*최종 수정: 2026-02-19 (WebSocket 실시간 가격 업데이트 버그 수정, 구독 라이프사이클 문서화)*
