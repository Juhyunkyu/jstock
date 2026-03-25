# 재무제표 기능 설계서

> 버전: v1.0 | 작성일: 2026-03-23

---

## 1. 아키텍처 개요

```
사용자 (Flutter Web)
  |
  v
financial_service.dart
  |
  |-- [프로덕션] AppConfig.useProxy == true
  |     |
  |     v
  |   Cloudflare Worker (/api/financials/*)
  |     |-- KV 캐시 확인 (TTL별)
  |     |-- 미스 -> Finnhub API 호출 (서버사이드 API 키)
  |     |-- 응답 KV에 저장 + 클라이언트 반환
  |
  |-- [개발] AppConfig.useProxy == false
  |     |
  |     v
  |   Finnhub API 직접 호출 (클라이언트 API 키)
  |
  v
financial_providers.dart (FutureProvider.autoDispose.family)
  |
  v
UI 위젯 (재무 탭 내 카드들)
```

---

## 2. Cloudflare Worker 프록시 설계

### 2.1 엔드포인트 매핑

| Worker 엔드포인트 | Finnhub API | 용도 | KV 캐시 TTL |
|---|---|---|---|
| `GET /api/financials/profile/:symbol` | `GET /stock/profile2?symbol=` | 기업 프로필 (이름, 산업, 시총, 직원수, IPO일 등) | 24시간 |
| `GET /api/financials/metrics/:symbol` | `GET /stock/metric?symbol=&metric=all` | 재무 비율 (PER, PBR, ROE, 배당수익률, 52주 고저 등) | 6시간 |
| `GET /api/financials/earnings/:symbol` | `GET /stock/earnings?symbol=&limit=8` | EPS 실적 (분기별 실제 vs 예상) | 12시간 |
| `GET /api/financials/reported/:symbol?freq=quarterly` | `GET /stock/financials-reported?symbol=&freq=` | 재무제표 원본 (IS, BS, CF) | 24시간 |

### 2.2 캐시 TTL 근거

- **profile (24h)**: 기업 기본정보는 거의 변하지 않음. IPO일, 산업, 시총 정도가 변동 요소이나 일 단위로 충분.
- **metrics (6h)**: PER, PBR 등은 주가 연동이므로 장중 변동 가능. 하루 4회 갱신이 적절.
- **earnings (12h)**: 분기 실적은 발표 시점에만 변경. 12시간이면 발표일에도 반나절 내 반영.
- **reported (24h)**: 분기/연간 재무제표는 분기 1회 변경. 24시간으로 충분.

### 2.3 Worker 구현 패턴

기존 Worker의 `/api/twelvedata/chart`, `/api/fred/*`, `/api/feargreed` 패턴과 동일하게 구현.

```
요청 수신
  -> URL 파싱 (/api/financials/{type}/{symbol})
  -> KV 키 생성: `fin:{type}:{symbol}` (reported는 `fin:reported:{symbol}:{freq}`)
  -> KV.get(key) 확인
     -> HIT: JSON 파싱 후 반환 (Cache-Control 헤더 포함)
     -> MISS:
        -> Finnhub API 호출 (FINNHUB_API_KEY는 Worker 환경변수)
        -> 응답 검증 (빈 응답, 에러 체크)
        -> KV.put(key, JSON, {expirationTtl: TTL초})
        -> 클라이언트에 반환
```

### 2.4 KV 키 설계

```
fin:profile:AAPL        -> TTL 86400s (24h)
fin:metrics:AAPL        -> TTL 21600s (6h)
fin:earnings:AAPL       -> TTL 43200s (12h)
fin:reported:AAPL:quarterly -> TTL 86400s (24h)
fin:reported:AAPL:annual    -> TTL 86400s (24h)
```

### 2.5 Rate Limit 보호

Finnhub 무료 플랜: 60 calls/min.

- Worker 레벨에서 KV 캐시가 1차 방어선 (캐시 히트 시 Finnhub 호출 없음)
- 재무 데이터 4개 엔드포인트를 한 종목에 대해 모두 호출해도 최대 4회/종목
- 기존 quote, search, company-news, profile2 호출과 합산 고려 필요
- Worker에 간단한 in-memory rate counter 추가 권장 (분당 40회 상한, 나머지 20회는 실시간 시세용)

### 2.6 에러 응답 형식

기존 Worker 패턴과 통일:

```json
{
  "error": true,
  "message": "Rate limit exceeded",
  "status": 429
}
```

---

## 3. Flutter 앱 구조 설계

### 3.1 파일 구조

```
lib/
  data/
    models/
      financial_data.dart          -- 데이터 모델 (4개 모델 클래스)
    services/
      api/
        financial_service.dart     -- Finnhub 재무 API 호출 서비스
  presentation/
    providers/
      financial_providers.dart     -- FutureProvider.autoDispose.family
    screens/
      index/
        index_detail_screen.dart   -- 기존 파일 수정 (탭 구조 추가)
    widgets/
      financials/                  -- 새 디렉토리
        financial_overview_card.dart   -- 기업 개요 (프로필 + 시총)
        financial_metrics_card.dart    -- 주요 비율 (PER, PBR, ROE 등)
        financial_earnings_chart.dart  -- EPS 실적 바 차트
        financial_statements_card.dart -- 재무제표 요약 (매출, 영업이익, 순이익)
        financial_tab_content.dart     -- 재무 탭 전체 레이아웃 (위 4개 조합)
```

### 3.2 데이터 모델: `financial_data.dart`

Hive 어노테이션 불필요 (영속 저장하지 않음, 메모리+서버 캐시로 충분).

```
CompanyProfile
  - name: String
  - ticker: String
  - exchange: String
  - industry: String (GICS 산업)
  - marketCap: double (시가총액, 백만 달러)
  - shareOutstanding: double (발행주식수)
  - employees: int? (직원수, null 가능)
  - ipoDate: String? (IPO 일자)
  - weburl: String?
  - description: String? (사업 설명, 영문)

FinancialMetrics
  - peRatio: double? (PER, 주가수익비율)
  - pbRatio: double? (PBR, 주가순자산비율)
  - psRatio: double? (PSR, 주가매출비율)
  - roe: double? (자기자본이익률)
  - roa: double? (총자산이익률)
  - grossMargin: double? (매출총이익률)
  - operatingMargin: double? (영업이익률)
  - netMargin: double? (순이익률)
  - debtToEquity: double? (부채비율)
  - currentRatio: double? (유동비율)
  - dividendYield: double? (배당수익률)
  - payoutRatio: double? (배당성향)
  - beta: double? (베타)
  - week52High: double? (52주 최고가)
  - week52Low: double? (52주 최저가)
  - revenueGrowthTTM: double? (매출 성장률)
  - epsGrowthTTM: double? (EPS 성장률)

EarningsData
  - quarters: List<QuarterEarnings>

QuarterEarnings
  - period: String (예: "2025-12-31")
  - actual: double? (실제 EPS)
  - estimate: double? (예상 EPS)
  - surprise: double? (서프라이즈 %)
  - year: int
  - quarter: int

FinancialStatements
  - reports: List<FinancialReport>

FinancialReport
  - period: String (예: "2025-12-31")
  - year: int
  - quarter: int? (연간이면 null)
  - revenue: double? (매출)
  - costOfRevenue: double? (매출원가)
  - grossProfit: double? (매출총이익)
  - operatingIncome: double? (영업이익)
  - netIncome: double? (순이익)
  - totalAssets: double? (총자산)
  - totalLiabilities: double? (총부채)
  - totalEquity: double? (자본총계)
  - operatingCashFlow: double? (영업활동CF)
  - capitalExpenditure: double? (자본적지출)
  - freeCashFlow: double? (잉여현금흐름)
```

### 3.3 서비스: `financial_service.dart`

기존 `FredService`, `TwelveDataService`의 프록시 패턴을 따름.

```
FinancialService
  - _proxyDio: Dio (baseUrl: AppConfig.proxyBaseUrl)
  - _directDio: Dio (baseUrl: AppConfig.finnhubBaseUrl)
  - _cache: CacheManager (앱 내 메모리 캐시, 기존 cacheManagerProvider 재사용)

  + getProfile(symbol) -> CompanyProfile
      프록시: GET /api/financials/profile/{symbol}
      직접:  GET /stock/profile2?symbol={symbol}&token={key}
      메모리 캐시 TTL: 1시간

  + getMetrics(symbol) -> FinancialMetrics
      프록시: GET /api/financials/metrics/{symbol}
      직접:  GET /stock/metric?symbol={symbol}&metric=all&token={key}
      메모리 캐시 TTL: 30분

  + getEarnings(symbol) -> EarningsData
      프록시: GET /api/financials/earnings/{symbol}
      직접:  GET /stock/earnings?symbol={symbol}&limit=8&token={key}
      메모리 캐시 TTL: 1시간

  + getReported(symbol, {freq = 'quarterly'}) -> FinancialStatements
      프록시: GET /api/financials/reported/{symbol}?freq={freq}
      직접:  GET /stock/financials-reported?symbol={symbol}&freq={freq}&token={key}
      메모리 캐시 TTL: 1시간
```

**폴백 전략** (기존 환율 서비스의 폴백 체인 패턴과 동일):
1. Worker 프록시 호출 시도
2. Worker 실패 (5xx, 타임아웃) -> Finnhub 직접 호출 (개발 환경과 동일 경로)
3. 둘 다 실패 -> null 반환 (UI에서 "데이터 없음" 표시)

**메모리 캐시 레이어 근거**: Worker KV 캐시(서버)와 별도로 앱 메모리 캐시를 두는 이유:
- 탭 전환 시 불필요한 네트워크 호출 방지 (차트 탭 -> 재무 탭 -> 차트 탭 -> 재무 탭)
- FutureProvider.autoDispose 사용 시 탭 이탈하면 Provider가 폐기되므로 서비스 레벨 캐시 필요
- TTL을 Worker보다 짧게 설정하여 적절한 갱신 보장

### 3.4 Provider: `financial_providers.dart`

```
// 서비스 Provider (싱글톤)
financialServiceProvider = Provider<FinancialService>

// 개별 데이터 Provider (autoDispose + family로 심볼별 독립 관리)
companyProfileProvider = FutureProvider.autoDispose.family<CompanyProfile?, String>
financialMetricsProvider = FutureProvider.autoDispose.family<FinancialMetrics?, String>
earningsDataProvider = FutureProvider.autoDispose.family<EarningsData?, String>
financialStatementsProvider = FutureProvider.autoDispose.family<FinancialStatements?, String>
```

**autoDispose 사용 근거**:
- 재무 데이터는 상세 페이지에서만 사용 -> 이탈 시 메모리 해제
- 서비스 레벨 메모리 캐시가 있으므로 재진입 시 네트워크 호출 없이 빠른 복원
- 기존 `tickerLogoUrlProvider` (FutureProvider.family) 패턴과 일관

**family 파라미터**: symbol 문자열 (예: "AAPL"). 지수 심볼(^NDX, ^GSPC)은 호출하지 않음 (UI에서 차단).

### 3.5 UI 위젯 설계

#### 3.5.1 `financial_tab_content.dart` (컨테이너)

재무 탭의 전체 레이아웃. `SingleChildScrollView` + `Column`으로 4개 카드를 세로 배치.

```
FinancialTabContent(symbol: String)
  |
  |-- CompanyProfile / FinancialMetrics 를 병렬 watch
  |-- EarningsData / FinancialStatements 를 병렬 watch
  |
  |-- 로딩: 스켈레톤 카드 4개
  |-- 에러: "재무 데이터를 불러올 수 없습니다" + 재시도 버튼
  |
  +-- FinancialOverviewCard (프로필)
  +-- FinancialMetricsCard (비율)
  +-- FinancialEarningsChart (EPS 차트)
  +-- FinancialStatementsCard (재무제표)
```

#### 3.5.2 `financial_overview_card.dart`

기업 기본 정보 카드.

```
표시 항목:
  - 회사명, 산업(GICS), 거래소
  - 시가총액 (단위 환산: M/B/T)
  - 직원수
  - IPO 일자
  - 사업 설명 (접기/펼치기, 영문)
스타일: 기존 DescriptionSection 패턴 참고
```

#### 3.5.3 `financial_metrics_card.dart`

주요 재무 비율 그리드.

```
그리드 레이아웃 (2열):
  +------------------+------------------+
  | Valuation        | Profitability    |
  | PER   25.3x      | ROE   45.2%     |
  | PBR    8.1x      | ROA   21.3%     |
  | PSR    7.2x      | 영업이익률 30.1% |
  +------------------+------------------+
  | Growth           | Financial Health |
  | 매출성장 12.3%    | 부채비율 120%   |
  | EPS성장  8.5%    | 유동비율  1.5x   |
  +------------------+------------------+
  | Dividend         | Price Range      |
  | 배당수익률 0.5%   | 52주고 $198     |
  | 배당성향  15%    | 52주저 $124      |
  +------------------+------------------+

null 값: "--" 표시 (ETF 등 일부 지표 없음)
스타일: 기존 cycle_info_card.dart의 InfoRow 패턴 활용
```

#### 3.5.4 `financial_earnings_chart.dart`

분기별 EPS 실적 vs 예상 바 차트.

```
최근 8분기 표시
바 차트: 실제 EPS (채움) vs 예상 EPS (테두리)
색상: Beat(실제>예상) = AppColors.red500, Miss = AppColors.blue500
하단 라벨: Q1'24, Q2'24, ... 형식
서프라이즈 %: 바 위에 +3.2%, -1.5% 등 표시
CustomPaint 또는 Container 기반 (외부 차트 라이브러리 미사용, 기존 캔들스틱 차트 패턴 유지)
```

#### 3.5.5 `financial_statements_card.dart`

재무제표 핵심 수치 요약.

```
탭: [분기] [연간] (ToggleButtons 또는 SegmentedButton)
테이블 형식 (최근 4기):
  항목          | Q3'25  | Q2'25  | Q1'25  | Q4'24
  매출           | 94.9B  | 85.8B  | 95.4B  | 124.3B
  영업이익       | 29.6B  | 25.3B  | 30.7B  | 42.0B
  순이익         | 24.8B  | 21.4B  | 23.6B  | 36.3B
  영업CF         | 26.8B  | 22.4B  | 28.0B  | 41.2B
  FCF           | 21.2B  | 18.1B  | 22.5B  | 35.0B

숫자 단위: K/M/B 자동 환산
가로 스크롤: 모바일에서 4열이 넘치면 SingleChildScrollView(horizontal)
```

---

## 4. index_detail_screen.dart 탭 구조 변경

### 4.1 현재 구조

```
IndexDetailScreen
  -> Scaffold
    -> AppBar (종목명 + 가격)
    -> SingleChildScrollView
      -> Column [차트, 수익률, 피봇, 설명, 뉴스]
```

### 4.2 변경 후 구조

```
IndexDetailScreen
  -> Scaffold
    -> AppBar (종목명 + 가격)
    -> Column
      -> [지수가 아닌 경우만] TabBar: [차트] [재무]
      -> Expanded
        -> TabBarView
          -> Tab 0: 기존 차트 콘텐츠 (SingleChildScrollView)
          -> Tab 1: FinancialTabContent(symbol) (지수 아닐 때만)
```

### 4.3 지수 심볼 처리

```
bool get _isIndex => widget.symbol.startsWith('^');
// 또는 symbol이 ^NDX, ^GSPC 등 지수인 경우

_isIndex == true:
  - TabBar 표시하지 않음
  - 기존 차트 뷰만 표시 (현재와 동일)

_isIndex == false:
  - TabBar 표시 (차트 | 재무)
  - DefaultTabController(length: 2)
```

### 4.4 상태 관리 고려사항

- 차트 탭의 기존 StatefulWidget 상태(`_chartData`, `_selectedPeriod` 등)는 유지
- `AutomaticKeepAliveClientMixin` 사용하여 탭 전환 시 차트 상태 보존
- 재무 탭은 FutureProvider.autoDispose로 관리되므로 별도 상태 불필요
- 드로잉 모드(`_isDrawingActive`)는 차트 탭 활성 시에만 적용

---

## 5. 데이터 흐름 상세

### 5.1 정상 흐름

```
1. 사용자가 종목 상세 진입 (차트 탭이 기본)
2. 재무 탭 클릭
3. FinancialTabContent 마운트
4. 4개 FutureProvider 동시 활성화 (ref.watch)
5. FinancialService.getProfile/getMetrics/getEarnings/getReported 병렬 호출
6. 각 메서드:
   a. 메모리 캐시 확인 -> HIT면 즉시 반환
   b. MISS -> Worker 프록시 호출
   c. Worker: KV 확인 -> HIT면 즉시 반환
   d. KV MISS -> Finnhub API 호출 -> KV 저장 -> 반환
   e. 앱: 응답을 메모리 캐시에 저장 -> Provider에 반환
7. UI 렌더링 (각 카드가 독립적으로 로딩 완료 순서대로 표시)
```

### 5.2 에러 흐름

```
Worker 타임아웃/5xx
  -> FinancialService: Finnhub 직접 호출 (폴백)
  -> 직접 호출도 실패 (429 Rate Limit 등)
  -> null 반환
  -> Provider: AsyncValue.data(null)
  -> UI: "재무 데이터를 불러올 수 없습니다" + [다시 시도] 버튼
```

### 5.3 캐시 계층 요약

```
Layer 1: Flutter 앱 메모리 캐시 (CacheManager)
  - TTL: 30분~1시간 (엔드포인트별)
  - 용도: 탭 전환, 같은 세션 내 재방문 시 즉시 응답
  - 소멸: 앱 새로고침 시 초기화

Layer 2: Cloudflare Worker KV 캐시
  - TTL: 6시간~24시간 (엔드포인트별)
  - 용도: Finnhub API 호출 횟수 절약, 빠른 응답
  - 소멸: TTL 만료 시 자동 삭제

Layer 3: Finnhub API (원본 데이터)
  - Rate Limit: 60 calls/min (무료)
  - Layer 1, 2 모두 미스일 때만 호출
```

Hive 영속 캐시는 사용하지 않음. 근거:
- 재무 데이터는 자주 변경될 수 있음 (분기 실적, 주가 연동 지표)
- Worker KV 캐시가 충분한 보호막 역할
- Hive 영속 캐시 추가 시 stale 데이터 표시 위험 + 캐시 무효화 로직 복잡도 증가
- 오프라인 시나리오는 PWA 웹앱 특성상 네트워크 필수이므로 우선순위 낮음

---

## 6. Finnhub API 응답 -> 모델 매핑

### 6.1 profile2 -> CompanyProfile

```
Finnhub: GET /stock/profile2?symbol=AAPL
응답:
{
  "country": "US",
  "currency": "USD",
  "exchange": "NASDAQ NMS - GLOBAL MARKET",
  "finnhubIndustry": "Technology",
  "ipo": "1980-12-12",
  "logo": "https://...",
  "marketCapitalization": 2800000,  // 백만 달러
  "name": "Apple Inc",
  "shareOutstanding": 15400,        // 백만 주
  "ticker": "AAPL",
  "weburl": "https://www.apple.com/"
}

매핑:
  name <- name
  ticker <- ticker
  exchange <- exchange (파싱하여 NASDAQ/NYSE 추출)
  industry <- finnhubIndustry
  marketCap <- marketCapitalization
  shareOutstanding <- shareOutstanding
  ipoDate <- ipo
  weburl <- weburl
  employees, description <- 이 API에 없음 (null)
```

**참고**: 기존 `FinnhubService.getExchange()`, `getCompanyLogo()`가 이미 profile2를 호출하고 있음. 재무 서비스에서 profile2를 호출하면 동일 데이터에 대해 중복 호출이 발생할 수 있으나, Worker KV 캐시가 이를 흡수함. 기존 메서드와 별도로 관리하여 관심사 분리 유지.

### 6.2 metric -> FinancialMetrics

```
Finnhub: GET /stock/metric?symbol=AAPL&metric=all
응답 (metric 필드 내부):
{
  "metric": {
    "peBasicExclExtraTTM": 25.3,
    "pbAnnual": 8.1,
    "psAnnual": 7.2,
    "roeTTM": 45.2,
    "roaRfy": 21.3,
    "grossMarginTTM": 46.2,
    "operatingMarginTTM": 30.1,
    "netProfitMarginTTM": 25.3,
    "totalDebt/totalEquityAnnual": 120.5,
    "currentRatioAnnual": 1.5,
    "dividendYieldIndicatedAnnual": 0.5,
    "payoutRatioAnnual": 15.2,
    "beta": 1.2,
    "52WeekHigh": 198.23,
    "52WeekLow": 124.17,
    "revenueGrowthTTMYoy": 12.3,
    "epsGrowthTTMYoy": 8.5
  }
}

매핑:
  peRatio <- metric.peBasicExclExtraTTM
  pbRatio <- metric.pbAnnual
  psRatio <- metric.psAnnual
  roe <- metric.roeTTM
  roa <- metric.roaRfy
  grossMargin <- metric.grossMarginTTM
  operatingMargin <- metric.operatingMarginTTM
  netMargin <- metric.netProfitMarginTTM
  debtToEquity <- metric["totalDebt/totalEquityAnnual"]
  currentRatio <- metric.currentRatioAnnual
  dividendYield <- metric.dividendYieldIndicatedAnnual
  payoutRatio <- metric.payoutRatioAnnual
  beta <- metric.beta
  week52High <- metric["52WeekHigh"]
  week52Low <- metric["52WeekLow"]
  revenueGrowthTTM <- metric.revenueGrowthTTMYoy
  epsGrowthTTM <- metric.epsGrowthTTMYoy
```

### 6.3 earnings -> EarningsData

```
Finnhub: GET /stock/earnings?symbol=AAPL&limit=8
응답:
[
  {
    "actual": 1.64,
    "estimate": 1.60,
    "period": "2025-12-31",
    "quarter": 1,
    "surprise": 2.5,
    "surprisePercent": 2.5,
    "symbol": "AAPL",
    "year": 2026
  },
  ...
]

매핑:
  quarters[i].period <- [i].period
  quarters[i].actual <- [i].actual
  quarters[i].estimate <- [i].estimate
  quarters[i].surprise <- [i].surprisePercent
  quarters[i].year <- [i].year
  quarters[i].quarter <- [i].quarter
```

### 6.4 financials-reported -> FinancialStatements

```
Finnhub: GET /stock/financials-reported?symbol=AAPL&freq=quarterly
응답:
{
  "data": [
    {
      "year": 2025,
      "quarter": 4,
      "report": {
        "ic": [  // Income Statement
          {"concept": "Revenues", "value": 124300000000, ...},
          {"concept": "CostOfGoodsAndServicesSold", "value": ...},
          {"concept": "GrossProfit", "value": ...},
          {"concept": "OperatingIncomeLoss", "value": ...},
          {"concept": "NetIncomeLoss", "value": ...}
        ],
        "bs": [  // Balance Sheet
          {"concept": "Assets", "value": ...},
          {"concept": "Liabilities", "value": ...},
          {"concept": "StockholdersEquity", "value": ...}
        ],
        "cf": [  // Cash Flow
          {"concept": "NetCashProvidedByUsedInOperatingActivities", "value": ...},
          {"concept": "PaymentsToAcquirePropertyPlantAndEquipment", "value": ...}
        ]
      }
    },
    ...
  ]
}

매핑: 각 report 내 concept 이름으로 값 검색 (회사마다 concept명이 다를 수 있으므로 복수 매칭 필요)
  revenue <- ic에서 "Revenue" 또는 "Revenues" 포함 항목
  costOfRevenue <- ic에서 "CostOfGoods" 또는 "CostOfRevenue" 포함
  grossProfit <- ic에서 "GrossProfit" 포함
  operatingIncome <- ic에서 "OperatingIncome" 포함
  netIncome <- ic에서 "NetIncome" 포함
  totalAssets <- bs에서 "Assets" (최상위)
  totalLiabilities <- bs에서 "Liabilities" (최상위)
  totalEquity <- bs에서 "Equity" 또는 "StockholdersEquity"
  operatingCashFlow <- cf에서 "OperatingActivities"
  capitalExpenditure <- cf에서 "PropertyPlantAndEquipment"
  freeCashFlow <- operatingCashFlow - abs(capitalExpenditure) (계산)
```

**주의**: `financials-reported` API의 concept 이름은 SEC XBRL 태그 기반으로 회사마다 다를 수 있음. 파싱 로직에 복수 매칭 + null 안전 처리 필수.

---

## 7. 트레이드오프 분석

### 7.1 Hive 영속 캐시 미사용

| 관점 | 판단 |
|---|---|
| 장점 | 구현 단순, stale 데이터 위험 없음, 캐시 무효화 불필요 |
| 단점 | 앱 새로고침 시 재요청 필요 (Worker KV가 흡수) |
| 결론 | Worker KV 캐시가 충분. 향후 오프라인 지원 필요 시 추가 고려 |

### 7.2 autoDispose vs 영구 Provider

| 관점 | 판단 |
|---|---|
| autoDispose | 메모리 효율, 탭 이탈 시 해제. 서비스 캐시가 재진입 비용 흡수 |
| 영구 | 탭 전환 시 즉시 표시. 하지만 메모리에 모든 종목 재무 데이터 축적 |
| 결론 | autoDispose 채택. 서비스 레벨 30분 캐시로 UX 손실 최소화 |

### 7.3 단일 API 호출 vs 4개 병렬 호출

| 관점 | 판단 |
|---|---|
| 단일 (BFF 패턴) | Worker에서 4개를 합쳐 반환. 클라이언트 1회 호출. 하지만 Worker 복잡도 증가, 부분 실패 처리 어려움 |
| 4개 병렬 | 각 카드가 독립 로딩/에러 표시. Worker 단순. 부분 성공 가능 |
| 결론 | 4개 병렬 채택. 각 카드가 독립적으로 데이터 표시하므로 UX 우수 |

### 7.4 외부 차트 라이브러리 vs CustomPaint

| 관점 | 판단 |
|---|---|
| fl_chart 등 | 빠른 구현, 풍부한 기능. 하지만 새 의존성 추가 |
| CustomPaint | 기존 캔들스틱 차트 패턴과 일관. 의존성 없음. EPS 바 차트는 단순 |
| 결론 | CustomPaint 채택. EPS 바 차트는 복잡도 낮아 직접 구현 적절 |

---

## 8. 구현 Phase 계획

### Phase 1: Worker 엔드포인트 (별도 레포)
- 4개 엔드포인트 추가
- KV 캐시 로직
- Rate limit 보호
- 배포 및 테스트

### Phase 2: 데이터 레이어
- `financial_data.dart` 모델 클래스
- `financial_service.dart` 서비스 (프록시 + 직접 + 폴백 + 메모리 캐시)

### Phase 3: Provider 레이어
- `financial_providers.dart` (서비스 Provider + 4개 FutureProvider)
- `api_providers.dart`에 financialServiceProvider 등록

### Phase 4: UI 레이어
- `index_detail_screen.dart` 탭 구조 변경
- `financial_tab_content.dart` 컨테이너
- `financial_overview_card.dart`
- `financial_metrics_card.dart`

### Phase 5: 차트 및 재무제표
- `financial_earnings_chart.dart` (EPS 바 차트)
- `financial_statements_card.dart` (재무제표 테이블)
- 스켈레톤 로딩, 에러 처리 마무리

### Phase 6: 통합 테스트
- Playwright MCP로 전체 흐름 검증
- 지수 심볼 재무 탭 비노출 확인
- 모바일/데스크톱 반응형 검증
- Worker KV 캐시 히트/미스 시나리오

---

## 9. API 키 및 환경변수

### Worker 환경변수 (신규)
```
FINNHUB_API_KEY  -- 기존 Worker에 이미 있을 수 있음, 확인 필요
FIN_KV           -- KV namespace binding (재무 데이터 전용 또는 기존 KV 재사용)
```

### Flutter 빌드 (변경 없음)
- 기존 `FINNHUB_API_KEY`, `PROXY_BASE_URL` 그대로 사용
- 새 API 키 추가 불필요 (Finnhub 기존 키로 모든 엔드포인트 접근 가능)

---

## 10. 리스크 및 제약사항

1. **Finnhub 무료 플랜 한계**: `financials-reported` API는 무료 플랜에서 제한될 수 있음. 테스트 필수. 제한 시 Phase 5의 재무제표 카드를 metrics 데이터로 대체하는 플랜 B 준비.

2. **SEC 보고 형식 불일치**: `financials-reported`의 concept 이름이 회사마다 다름. 주요 대형주(AAPL, MSFT, NVDA, GOOGL, AMZN, META, TSLA) 기준으로 매핑 테스트 후 범용 파싱 로직 구축.

3. **Rate Limit 경합**: 재무 데이터 4개 + 기존 호출(시세, 검색, 뉴스, 로고)이 동시 발생 시 60/min 한도 초과 가능. Worker KV 캐시가 핵심 방어선이나, 첫 조회 시(cold cache) 경합 주의.

4. **탭 전환 성능**: 차트 탭의 heavy CustomPaint와 재무 탭 전환 시 프레임 드롭 가능. `AutomaticKeepAliveClientMixin`으로 차트 상태 보존하여 재빌드 방지.
