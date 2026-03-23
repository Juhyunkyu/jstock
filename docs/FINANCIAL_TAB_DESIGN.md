# Financial Tab Design - 재무제표 시각화 설계서

> Version: 1.0 | Date: 2026-03-23

## 1. 개요

티커 상세 페이지에 [차트 | 재무] 탭을 추가하여, 기업의 재무 데이터를 시각적으로 표현한다.
초보 투자자도 한눈에 기업 상태를 파악할 수 있도록 그래프/차트 중심으로 설계한다.

### API 소스

| API | 용도 | 비용 | 한도 |
|-----|------|------|------|
| **Finnhub** (기존) | 기업 프로필, 재무 비율, EPS 실적 | 무료 | 60회/분 |
| **FMP** (신규) | 손익계산서 (매출/영업이익/순이익) | 무료 | 250회/일 |

### 지원 범위

- 미국 개별 종목만 (AAPL, TSLA, NVDA 등)
- 지수(^NDX, ^GSPC) 및 ETF(QQQ, SPY)는 재무 탭 비활성화
- 한국어 UI, 다크모드, 모바일/데스크톱 반응형
- **Hive 미사용** — 재무 데이터는 API 전용, Hive adapter/typeId 불필요

### ETF/지수 감지 규칙

지수(`^NDX`, `^GSPC`)는 `_chartSymbol`에서 QQQ/SPY로 변환되므로 `startsWith('^')`로 감지 불가.
대신 다음 방법으로 감지:
- **FMP `/profile` 응답의 `isEtf` 필드** 사용 (가장 정확)
- 또는 **하드코딩 목록**: `{'^NDX', '^GSPC', 'QQQ', 'SPY', 'TQQQ', 'SOXL', ...}` (폴백)
- `widget.symbol.startsWith('^')` → 지수 확정 (탭 자체 숨김)
- `isEtf == true` → ETF (재무 탭에서 "ETF는 재무제표가 없습니다" 안내)

---

## 2. 화면 구성 (5개 섹션)

```
[차트]  [재무] <-- 탭 구조

=== 재무 탭 (스크롤) ===

+----------------------------------+
| 섹션 1: 기업 개요                 |
+----------------------------------+
| 섹션 2: 핵심 투자 지표            |
+----------------------------------+
| 섹션 3: 실적 추이 차트            |
+----------------------------------+
| 섹션 4: EPS Beat/Miss 차트       |
+----------------------------------+
| 섹션 5: 기업 분석 요약            |
+----------------------------------+
```

---

## 3. 섹션별 상세 설계

### 섹션 1: 기업 개요 카드

**데이터 소스**: FMP `/profile/{symbol}`

```
+----------------------------------+
| [LOGO]  Apple Inc.               |
|         Technology > Consumer    |
|         Electronics              |
+----------------------------------+
| 시가총액      |  CEO             |
| $3.45T       |  Timothy Cook    |
|--------------|------------------|
| 직원수        |  IPO             |
| 164,000명    |  1980.12.12      |
+----------------------------------+
| Apple Inc. designs, manufactures |
| and markets smartphones...       |
| [더 보기]                         |
+----------------------------------+
```

**핵심 필드 (FMP /profile)**:
- `companyName`, `sector`, `industry`
- `mktCap` -> $3.45T / $892B / $450M 자동 포맷
- `ceo`, `fullTimeEmployees`, `ipoDate`
- `image` (로고), `description` (3줄 제한 + 더보기)

---

### 섹션 2: 핵심 투자 지표

**데이터 소스**: Finnhub `/stock/metric?metric=all` (Primary) — FMP `/key-metrics`는 폴백으로만 사용

```
+----------------------------------+
| 핵심 투자 지표                    |
+----------------------------------+
| PER          30.5   (i)          |
| [====------]  보통               |
|                                  |
| PBR          48.2   (i)          |
| [=========-]  주의               |
|                                  |
| ROE          156%   (i)          |
| [==========]  양호               |
|                                  |
| 배당률        0.5%   (i)          |
| [---------]  낮음               |
|                                  |
| 부채비율      187%   (i)          |
| [=========-]  주의               |
|                                  |
| 영업이익률    31.5%  (i)          |
| [========--]  양호               |
+----------------------------------+
| [더 보기: ROA, 순이익률, 유동비율] |
+----------------------------------+
```

**(i) 아이콘 탭 -> 설명 바텀시트**:
```
+----------------------------------+
| PER (주가수익비율)                |
|                                  |
| 주가를 주당순이익(EPS)으로 나눈   |
| 값입니다. 현재 주가가 기업의 이익 |
| 대비 몇 배인지를 나타냅니다.      |
|                                  |
| - 낮을수록: 저평가 가능성         |
| - 높을수록: 성장 기대감 반영      |
|                                  |
| 일반 기준:                        |
| 0~15: 저평가  15~25: 적정        |
| 25+: 고평가 (성장주는 예외)       |
+----------------------------------+
```

**색상 판정 기준**:

| 지표 | 양호 (초록) | 보통 (노랑) | 주의 (빨강) |
|------|-----------|-----------|-----------|
| PER | 0~15 | 15~25 | 25+ |
| PBR | 0~1.5 | 1.5~3 | 3+ |
| ROE | 15%+ | 5~15% | 0~5% |
| ROA | 10%+ | 3~10% | 0~3% |
| 배당률 | 3%+ | 1~3% | 0~1% |
| 부채비율 | 0~100% | 100~200% | 200%+ |
| 영업이익률 | 20%+ | 10~20% | 0~10% |

**프로그레스 바**: 지표값을 범위 내 위치로 시각화
- 최소~최대 범위를 설정 (예: PER 0~50)
- 현재 값의 위치를 바로 표시
- 색상: 양호=초록, 보통=노랑, 주의=빨강

---

### 섹션 3: 실적 추이 차트 (핵심 시각화)

**데이터 소스**: FMP `/income-statement/{symbol}?period=annual&limit=5`

```
+----------------------------------+
| 실적 추이          [연간] [분기]  |
+----------------------------------+
|                                  |
| $400B |                    ██    |
| $350B |              ██    ██    |
| $300B |        ██    ██    ██    |
| $250B |  ██    ██    ██    ██    |
| $200B |  ██    ██    ██    ██    |
|       |  ██    ██    ██    ██    |
| $100B |  ██ ▓▓ ██ ▓▓ ██ ▓▓ ██ ▓▓|
|  $50B |  ██ ▓▓ ██ ▓▓ ██ ▓▓ ██ ▓▓|
|    $0 +--+--+--+--+--+--+--+--+ |
|       '21  '22  '23  '24        |
|                                  |
| ██ 매출  ▓▓ 영업이익  -- 순이익  |
+----------------------------------+
```

**차트 스펙 (CustomPainter)**:
- 높이: 모바일 200px, 데스크톱 260px
- 그룹 막대: 매출(파랑), 영업이익(초록), 순이익(주황)
- Y축: 자동 스케일, $XXB / $XXM 포맷
- X축: 연간 'YY, 분기 Q1'YY
- 토글: SegmentedButton [연간 | 분기]
- 연간 5년 / 분기 최근 8분기
- 막대 탭 시 상세 금액 팝업

**금액 포맷**:
- >= $1T: `$1.23T`
- >= $1B: `$123B`
- >= $1M: `$450M`
- < $1M: `$123K`

---

### 섹션 4: EPS Beat/Miss 차트

**데이터 소스**: Finnhub `/stock/earnings?limit=8`

```
+----------------------------------+
| EPS 실적 vs 예상                  |
+----------------------------------+
|                                  |
| $2.0 |                          |
| $1.5 | ██ ▒▒ ██ ▒▒ ██ ▒▒ ██ ▒▒ |
| $1.0 | ██ ▒▒ ██ ▒▒ ██ ▒▒ ██ ▒▒ |
| $0.5 | ██ ▒▒ ██ ▒▒ ██ ▒▒ ██ ▒▒ |
|  $0  +--+--+--+--+--+--+--+--+ |
|       Q1  Q2  Q3  Q4  Q1  Q2   |
|       '24 '24 '24 '24 '25 '25  |
|       +2% +3% +1% -2% +4% +1%  |
|                                  |
| ██ 실제  ▒▒ 예상                 |
| 초록=Beat  빨강=Miss             |
+----------------------------------+
```

**차트 스펙**:
- 높이: 모바일 160px, 데스크톱 200px
- 그룹 막대: 실제(색상변동), 예상(회색)
- Beat: 실제 막대 초록 / Miss: 실제 막대 빨강
- 서프라이즈 %를 막대 위에 텍스트 표시
- X축: Q1'24 형태

---

### 섹션 5: 기업 분석 요약

**데이터 기반 자동 텍스트 생성 (템플릿)**

```
+----------------------------------+
| 기업 분석 요약                    |
+----------------------------------+
|                                  |
| [실적] 매출이 3년 연속 성장 중    |
| 입니다. 영업이익률 31.5%로 수익성 |
| 이 양호합니다.                    |
|                                  |
| [재무] 부채비율 187%로 다소 높은  |
| 편이나, 현금 보유가 충분합니다.   |
|                                  |
| [밸류에이션] PER 30.5로 업계     |
| 평균 대비 높은 편이며, 성장 기대  |
| 가 반영된 수준입니다.             |
|                                  |
| ---------------------------------------- |
| 본 정보는 투자 참고용이며 투자    |
| 권유가 아닙니다.                  |
+----------------------------------+
```

**자동 생성 규칙**:

| 조건 | 생성 텍스트 |
|------|-----------|
| 매출 YoY > 0 (3년 연속) | "매출이 N년 연속 성장 중입니다" |
| 매출 YoY < 0 | "매출이 전년 대비 감소했습니다" |
| 영업이익률 > 20% | "영업이익률 X%로 수익성이 양호합니다" |
| 영업이익률 < 10% | "영업이익률 X%로 수익성 개선이 필요합니다" |
| 부채비율 > 200% | "부채비율 X%로 재무 건전성에 주의가 필요합니다" |
| 부채비율 < 100% | "부채비율 X%로 재무 구조가 안정적입니다" |
| PER > 30 | "PER X로 성장 기대가 반영된 수준입니다" |
| PER < 15 | "PER X로 저평가 가능성이 있습니다" |
| EPS Beat 연속 4회+ | "최근 4분기 연속 EPS 서프라이즈를 기록했습니다" |

---

## 4. 아키텍처

### 데이터 흐름

```
사용자가 [재무] 탭 클릭
  |
  v
financialDataProvider(symbol) 활성화
  |
  v
FinancialService.getFinancialData(symbol)
  |
  +-- Finnhub /stock/profile2        --> CompanyProfile
  +-- Finnhub /stock/metric          --> FinancialMetrics
  +-- Finnhub /stock/earnings        --> List<EarningsResult>
  +-- FMP /income-statement (프록시)  --> List<IncomeStatement>
  |       |
  |       v
  |   Cloudflare Worker
  |       +-- KV 캐시 확인 (24시간)
  |       +-- 미스: FMP API 호출 + 캐시 저장
  |       +-- 응답 반환
  |
  v
FinancialData (통합 모델)
  |
  v
UI 렌더링 (5개 섹션)
```

### Cloudflare Worker 엔드포인트

```
GET /api/fmp/income-statement/:symbol?period=annual&limit=5
GET /api/fmp/profile/:symbol
GET /api/fmp/key-metrics/:symbol?period=annual&limit=5
```

- KV 캐시 키: `fmp:{endpoint}:{symbol}:{period}`
- KV TTL: 24시간 (재무제표는 분기별 변경)
- Worker가 FMP API 키를 서버사이드 주입

### 캐시 전략 (3단계)

| 레이어 | TTL | 위치 |
|--------|-----|------|
| **앱 메모리 캐시** | 30분 | FinancialService 내부 Map |
| **Cloudflare KV** | 24시간 | Worker |
| **FMP/Finnhub API** | 실시간 | 원본 |

---

## 5. 파일 구조

### 신규 파일

```
lib/data/models/financial_data.dart              -- 데이터 모델
lib/data/services/api/financial_service.dart      -- FMP + Finnhub API 호출
lib/presentation/providers/financial_providers.dart -- Provider
lib/presentation/widgets/financials/
  financial_screen.dart                           -- 재무 탭 전체 화면
  financial_overview_card.dart                    -- 기업 개요
  financial_metrics_card.dart                     -- 주요 지표 + (i) 설명
  financial_revenue_chart.dart                    -- 매출/영업이익 막대 차트
  financial_eps_chart.dart                        -- EPS Beat/Miss 차트
  financial_analysis_card.dart                    -- 기업 분석 요약
```

### 수정 파일

```
lib/core/config/app_config.dart                  -- FMP API 키 추가
build.sh                                         -- --dart-define=FMP_API_KEY 추가
.github/workflows/deploy.yml                     -- FMP_API_KEY secret 추가
lib/presentation/screens/index/index_detail_screen.dart -- 탭 구조 변경
```

---

## 6. 구현 Phase

### Phase 1: 인프라
- [ ] `app_config.dart`에 `fmpApiKey`, `fmpBaseUrl` 추가
- [ ] `build.sh`에 `--dart-define=FMP_API_KEY` 추가
- [ ] GitHub Actions secrets에 `FMP_API_KEY` 추가
- [ ] Cloudflare Worker에 `/api/fmp/*` 프록시 + KV 캐시 추가

### Phase 2: 데이터 레이어
- [ ] `financial_data.dart` 데이터 모델 (CompanyProfile, FinancialMetrics, IncomeStatement, EarningsResult, FinancialData)
- [ ] `financial_service.dart` API 서비스 (프록시/직접 호출 분기, 메모리 캐시)
- [ ] `financial_providers.dart` Riverpod Provider

### Phase 3: 탭 구조
- [ ] `index_detail_screen.dart`에 TabBar [차트 | 재무] 추가
- [ ] `ConsumerState` → `ConsumerState with TickerProviderStateMixin` 변경 (TabController 필요)
- [ ] 지수(`widget.symbol.startsWith('^')`) → 탭 없이 기존 레이아웃 유지
- [ ] ETF(`isEtf`) → 재무 탭에서 안내 메시지 표시
- [ ] 기존 차트 코드 변경 없음 (Tab 0에 래핑)

### Phase 4: UI - 기업 개요 + 투자 지표
- [ ] `financial_screen.dart` 전체 화면 (AsyncValue.when)
- [ ] `financial_overview_card.dart` 기업 개요
- [ ] `financial_metrics_card.dart` 투자 지표 + (i) 설명 바텀시트

### Phase 5: UI - 차트
- [ ] `financial_revenue_chart.dart` 매출/영업이익 막대 차트 (CustomPainter)
- [ ] `financial_eps_chart.dart` EPS Beat/Miss 차트 (CustomPainter)

### Phase 6: 마무리
- [ ] `financial_analysis_card.dart` 기업 분석 요약
- [ ] 다크모드 전체 검증
- [ ] 반응형 (모바일/태블릿/데스크톱)
- [ ] 로딩 스켈레톤, 에러 처리
- [ ] 면책 문구

---

## 7. 반응형 Breakpoint

| 화면 | 폭 | 지표 열 | 차트 높이 |
|------|-----|--------|----------|
| 모바일 | < 600px | 1열 | 200px |
| 태블릿 | 600~1023px | 2열 | 230px |
| 데스크톱 | >= 1024px | 3열 | 260px |

---

## 8. 색상 규칙

- **절대 하드코딩 금지** -- `context.app*` 또는 `AppColors` 사용
- 양호: `AppColors.green500` 계열
- 보통: `AppColors.amber500` 계열
- 주의: `AppColors.red500` 계열
- 수익/상승: `AppColors.red500` (한국 관례)
- 손실/하락: `AppColors.blue500`
- CustomPainter: `isDarkMode` 파라미터 전달

### 신규 ThemeAwareColors getter (app_colors.dart에 추가)

```dart
Color get appGoodColor => isDarkMode ? AppColors.green500 : const Color(0xFF059669);
Color get appCautionColor => isDarkMode ? AppColors.amber500 : const Color(0xFFD97706);
Color get appWarningColor => isDarkMode ? AppColors.red500 : const Color(0xFFDC2626);
```

---

## 9. FMP API 핵심 필드 매핑

### 손익계산서 (/income-statement)

| 한글명 | JSON 필드 | 용도 |
|--------|-----------|------|
| 매출 | `revenue` | 막대 차트 |
| 매출총이익 | `grossProfit` | 분석 |
| 영업이익 | `operatingIncome` | 막대 차트 |
| 순이익 | `netIncome` | 막대 차트 |
| EPS | `epsdiluted` | 참고 |
| 영업이익률 | `operatingIncomeRatio` | 지표 |
| 순이익률 | `netIncomeRatio` | 지표 |
| R&D비용 | `researchAndDevelopmentExpenses` | 분석 |

### 기업 프로필 (/profile)

| 한글명 | JSON 필드 |
|--------|-----------|
| 시가총액 | `mktCap` |
| 섹터 | `sector` |
| 산업 | `industry` |
| 직원수 | `fullTimeEmployees` |
| CEO | `ceo` |
| 설명 | `description` |
| 로고 | `image` |
| IPO | `ipoDate` |

### Finnhub 핵심 비율 (/stock/metric)

| 한글명 | JSON 필드 |
|--------|-----------|
| PER | `peTTM` |
| PBR | `pbQuarterly` |
| ROE | `roeTTM` |
| ROA | `roaTTM` |
| 배당률 | `dividendYieldIndicatedAnnual` |
| 부채비율 | `totalDebtToEquity` |
| 52주 최고 | `52WeekHigh` |
| 52주 최저 | `52WeekLow` |

### EPS 실적 (Finnhub /stock/earnings)

| 한글명 | JSON 필드 |
|--------|-----------|
| 실제 EPS | `actual` |
| 예상 EPS | `estimate` |
| 서프라이즈 | `surprise` |
| 서프라이즈% | `surprisePercent` |
| 분기 | `quarter` + `year` |
