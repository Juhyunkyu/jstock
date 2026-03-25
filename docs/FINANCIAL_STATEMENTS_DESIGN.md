# 재무제표 시각화 설계서

> 설계 전용 문서 — 코드 없음
> 대상: `/index/:symbol` 상세 페이지 하단 섹션으로 추가
> 기준: 모바일 375px 우선, 다크모드 대응, 한국어, CustomPainter 기반

---

## 목차

1. [데이터 소스 및 API 매핑](#1-데이터-소스-및-api-매핑)
2. [섹션 1: 기업 개요 카드](#2-섹션-1-기업-개요-카드)
3. [섹션 2: 핵심 투자 지표](#3-섹션-2-핵심-투자-지표)
4. [섹션 3: 실적 추이 차트](#4-섹션-3-실적-추이-차트)
5. [섹션 4: EPS Beat/Miss 차트](#5-섹션-4-eps-beatmiss-차트)
6. [섹션 5: 기업 분석 요약](#6-섹션-5-기업-분석-요약)
7. [색상 시스템](#7-색상-시스템)
8. [반응형 규칙](#8-반응형-규칙)
9. [구현 파일 구조](#9-구현-파일-구조)

---

## 1. 데이터 소스 및 API 매핑

### FMP (Financial Modeling Prep) — 무료 티어

| 엔드포인트 | 데이터 | 용도 |
|-----------|--------|------|
| `/api/v3/profile/{symbol}` | 시가총액, 섹터, 산업, CEO, 직원수, IPO일, 로고URL, 설명 | 섹션 1 |
| `/api/v3/income-statement/{symbol}?period=annual&limit=5` | 매출, 매출원가, 매출총이익, 영업이익, 순이익, EPS | 섹션 3 (연간) |
| `/api/v3/income-statement/{symbol}?period=quarter&limit=8` | 동일 (분기) | 섹션 3 (분기) |
| `/api/v3/balance-sheet-statement/{symbol}?limit=5` | 총자산, 총부채, 자본, 현금 | 섹션 2 보조 |
| `/api/v3/cash-flow-statement/{symbol}?limit=5` | 영업CF, 투자CF, 재무CF, FCF | 향후 확장 |

### Finnhub — 기존 사용 중

| 엔드포인트 | 데이터 | 용도 |
|-----------|--------|------|
| `/stock/metric?metric=all` | PER, PBR, ROE, ROA, 배당률, 부채비율, 마진율, 52주 고/저 | 섹션 2 |
| `/stock/earnings` | 분기별 actual EPS, estimate EPS, surprise, surprisePercent | 섹션 4 |

### 캐싱 전략

- 기업 프로필: 24시간 캐시 (거의 변하지 않음)
- 재무제표: 12시간 캐시 (분기 실적 발표 시에만 변경)
- 투자 지표: 6시간 캐시 (주가 연동 지표 존재)
- EPS 실적: 12시간 캐시

---

## 2. 섹션 1: 기업 개요 카드

### 디자인 컨셉

토스증권의 기업 개요 스타일 참고 — 로고를 좌측에 크게, 핵심 정보를 우측에 배치.
Yahoo Finance의 quote header처럼 한눈에 기업 아이덴티티를 파악할 수 있도록 구성.

### 와이어프레임 (375px 모바일)

```
+-----------------------------------------------+
|  기업 개요                                      |
+-----------------------------------------------+
|                                                 |
|  +------+  AAPL                                 |
|  | LOGO |  Apple Inc.                           |
|  | 48px |  Technology > Consumer Electronics    |
|  +------+                                       |
|                                                 |
|  +---------------------+---------------------+  |
|  | 시가총액             | CEO                 |  |
|  | $3.45T              | Tim Cook            |  |
|  +---------------------+---------------------+  |
|  | 직원수               | IPO                 |  |
|  | 164,000명            | 1980.12.12          |  |
|  +---------------------+---------------------+  |
|                                                 |
|  Apple Inc. designs, manufactures, and          |
|  markets smartphones, personal computers...     |
|  [더보기]                                        |
|                                                 |
+-----------------------------------------------+
```

### 레이아웃 스펙

| 요소 | 스펙 |
|------|------|
| 카드 | `appCardBackground`, borderRadius 12, padding 16 |
| 로고 | 48x48 원형, `ClipOval` + `Image.network(logoUrl)`, 실패 시 심볼 첫 글자 |
| 심볼 | 16px bold, `appTickerColor` |
| 회사명 | 14px semibold, `appTextPrimary` |
| 섹터 > 산업 | 12px, `appTextSecondary`, ">" 구분자 |
| 정보 그리드 | 2열 Grid, 세로 간격 12 |
| 라벨 | 12px, `appTextHint` |
| 값 | 14px semibold, `appTextPrimary` |
| 기업 설명 | 13px, `appTextSecondary`, maxLines: 3 + "더보기" 토글 |

### 금액 포맷 규칙

```
시가총액:
  >= 1T  -->  $X.XXT  (예: $3.45T)
  >= 1B  -->  $XXXB   (예: $892B)
  >= 1M  -->  $XXXM   (예: $450M)
  < 1M   -->  $X.XXM

직원수:
  >= 10000  -->  XXX,XXX명
  < 10000   -->  X,XXX명
```

### 데스크톱 (>= 768px) 변형

로고+회사명 영역과 정보 그리드를 좌우 배치 (Row).
기업 설명은 maxLines: 5로 확대.

---

## 3. 섹션 2: 핵심 투자 지표

### 디자인 컨셉

네이버증권의 투자지표 요약 + 토스증권의 "쉬운 설명" 조합.
각 지표를 카드 형태로 보여주되, 수치 + 컬러 도트(상태) + info 아이콘 구성.
초보자를 위해 info 아이콘 탭 시 한글 설명 BottomSheet 표시.

### 와이어프레임 (375px 모바일)

```
+-----------------------------------------------+
|  투자 지표                                      |
+-----------------------------------------------+
|                                                 |
|  +---------------------+---------------------+  |
|  | PER          (i)    | PBR          (i)    |  |
|  | [*] 28.5배          | [*] 45.2배          |  |
|  | ----[====]--------- | ----[============]- |  |
|  |    적정              |    다소 높음          |  |
|  +---------------------+---------------------+  |
|  | ROE          (i)    | ROA          (i)    |  |
|  | [*] 147.3%          | [*] 28.1%           |  |
|  | --------[========]- | ------[======]----- |  |
|  |    우수              |    양호              |  |
|  +---------------------+---------------------+  |
|  | 배당률         (i)    | 부채비율        (i)  |  |
|  | [*] 0.55%           | [*] 176.3%          |  |
|  | -[=]-------------- | ------[========]--- |  |
|  |    낮음              |    보통              |  |
|  +---------------------+---------------------+  |
|                                                 |
+-----------------------------------------------+

  [*] = 컬러 도트 (양호=green, 보통=amber, 주의=red)
  (i) = info 아이콘, 탭 시 설명 표시
  [====] = 미니 프로그레스 바 (범위 내 위치 표시)
```

### 지표별 평가 기준 및 색상 코딩

| 지표 | 양호 (green) | 보통 (amber) | 주의 (red) | 프로그레스 바 범위 |
|------|-------------|-------------|-----------|-----------------|
| PER | 0~15 | 15~25 | 25+ 또는 음수 | 0~50 |
| PBR | 0~1.5 | 1.5~3.0 | 3.0+ 또는 음수 | 0~10 |
| ROE | 15%+ | 5~15% | 5% 미만 또는 음수 | 0~50% |
| ROA | 10%+ | 3~10% | 3% 미만 또는 음수 | 0~30% |
| 배당률 | 2%+ | 0.5~2% | 0.5% 미만 | 0~8% |
| 부채비율 | 0~100% | 100~200% | 200%+ | 0~400% |

**주의**: 이 기준은 일반적 가이드라인이며, 섹터/산업별 차이가 큼.
섹션 5(기업 분석 요약)에서 "IT 섹터 평균 PER은 25~35로, 이 종목은 섹터 대비 적정합니다" 같은 맥락 제공.

### (i) 아이콘 탭 시 표시할 한글 설명

| 지표 | 초보자용 설명 |
|------|------------|
| PER (주가수익비율) | "현재 주가가 1년 순이익의 몇 배인지 보여줍니다. 낮을수록 현재 가격 대비 수익이 많다는 뜻이에요. 다만 성장주는 높은 PER이 자연스럽습니다." |
| PBR (주가순자산비율) | "주가가 회사의 순자산(자산-부채)의 몇 배인지 보여줍니다. 1배 미만이면 '자산 대비 저평가'로 볼 수 있어요." |
| ROE (자기자본이익률) | "주주가 투자한 돈으로 얼마나 이익을 냈는지 보여줍니다. 높을수록 돈을 잘 버는 회사예요. 워런 버핏이 가장 중시하는 지표입니다." |
| ROA (총자산이익률) | "회사의 모든 자산을 활용해 얼마나 이익을 냈는지 보여줍니다. 빚이 많은 회사는 ROE가 높아도 ROA가 낮을 수 있어요." |
| 배당률 | "주가 대비 1년간 받을 수 있는 배당금 비율입니다. 안정적인 배당을 원하는 투자자에게 중요한 지표예요." |
| 부채비율 | "자본 대비 부채가 얼마인지 보여줍니다. 100%면 빚과 자본이 같다는 뜻이에요. 너무 높으면 재무 위험이 커집니다." |

### 설명 표시 방식

`showModalBottomSheet` — 최소 높이, 아이콘 + 지표명 + 설명 텍스트.
기존 `NotificationSettingsSheet` 패턴 재사용.

### 미니 프로그레스 바 스펙

```
너비: 카드 내부 전체 (padding 제외)
높이: 4px
배경: appDivider
채움: 양호=green500, 보통=amber500, 주의=red500
모서리: borderRadius 2
마커: 현재 값 위치에 6px 원형 도트 (같은 색상)
```

### 데스크톱 (>= 768px) 변형

2열 -> 3열 그리드로 변경. 6개 지표를 2행 x 3열로 표시.

---

## 4. 섹션 3: 실적 추이 차트

### 디자인 컨셉

Yahoo Finance의 Financials 탭 + 토스증권의 매출/영업이익 막대 차트 스타일 참고.
가장 핵심적인 시각화로, CustomPainter로 직접 구현.
매출(Revenue), 영업이익(Operating Income), 순이익(Net Income) 3가지를 묶은 그룹 막대 차트.

### 와이어프레임 (375px 모바일)

```
+-----------------------------------------------+
|  실적 추이                    [연간] [분기]     |
+-----------------------------------------------+
|                                                 |
|  $400B +                                        |
|        |                                        |
|  $300B + ___                                    |
|        | |R|  ___                               |
|  $200B + |R| |R|  ___        ___        ___     |
|        | |R| |R| |R|  ___  |R|  ___  |R|       |
|  $100B + |R| |R| |R| |R|  |R| |R|  |R|  ___   |
|        | |R|O|R|O|R|O|R|  |R|O|R|O|R|O|R|    |
|    $0  +-|R|O|N|R|O|N|R|O|N|-|R|O|N|-|R|O|N|- |
|        | 2020  2021  2022    2023    2024        |
|                                                 |
|  [===] 매출  [===] 영업이익  [===] 순이익        |
|                                                 |
|  --- 영업이익률 (옵션)                            |
|                                                 |
+-----------------------------------------------+

  R = 매출 막대 (파란계열)
  O = 영업이익 막대 (녹색계열)
  N = 순이익 막대 (주황계열)
```

### 연간/분기 토글

```
+-----------------------------------------------+
|  실적 추이              +--------+--------+    |
|                         | 연간   | 분기   |    |
|                         +--------+--------+    |
+-----------------------------------------------+

  - SegmentedButton 또는 ToggleButtons 스타일
  - 선택된 탭: appAccent 배경 + white 텍스트
  - 비선택: appCardBackground + appTextSecondary
  - 연간: 최근 5년 (FMP annual, limit=5)
  - 분기: 최근 8분기 (FMP quarter, limit=8)
```

### CustomPainter 좌표 스펙

```
전체 위젯:
  높이: 220px (차트 영역) + 40px (범례) + 24px (X축 라벨) = 284px
  좌측 여백 (Y축 라벨): 52px
  우측 여백: 16px
  상단 여백: 16px
  하단 여백 (X축): 24px

차트 영역:
  plotLeft: 52px
  plotRight: width - 16px
  plotTop: 16px
  plotBottom: 220px

Y축:
  눈금 개수: 5단계 (0, 25%, 50%, 75%, 100%)
  라벨: 금액 포맷 (아래 참고), 11px, appTextHint
  가이드라인: 0.5px, appDivider, 점선

X축:
  라벨: 연도(연간) 또는 "Q1'24"(분기), 11px, appTextSecondary
  위치: 각 그룹 중앙 하단

막대 그룹 (연간 5그룹):
  availableWidth = plotRight - plotLeft
  groupWidth = availableWidth / groupCount (5 or 8)
  groupPadding = groupWidth * 0.2 (양쪽 합계)
  barAreaWidth = groupWidth - groupPadding
  barWidth = barAreaWidth / 3 (매출, 영업이익, 순이익)
  barGap = 1px (막대 간)
  barCornerRadius: 상단만 2px

막대 그룹 (분기 8그룹):
  동일 계산, groupCount=8
  barWidth가 좁아지므로 최소 8px 보장
  8px 미만이면 barGap 제거

음수 값 처리:
  Y축 0선을 기준으로 위(양수)/아래(음수) 모두 그리기
  음수 막대: 하단 모서리에 borderRadius 적용
  0선: 1px solid, appTextHint
```

### 막대 색상

| 항목 | Light | Dark | ThemeAwareColors getter |
|------|-------|------|----------------------|
| 매출 (Revenue) | `blue500` (#3B82F6) | `blue400` (#60A5FA) | `appChartRevenue` |
| 영업이익 (Operating Income) | `green500` (#10B981) | `green400` (#34D399) | `appChartOperatingIncome` |
| 순이익 (Net Income) | `amber500` (#F59E0B) | `amber400` (#FBBF24) | `appChartNetIncome` |

### 범례

```
+-----------------------------------------------+
|  [==] 매출  [==] 영업이익  [==] 순이익           |
+-----------------------------------------------+

  - Row, mainAxisAlignment: center
  - 각 항목: 12x12 색상 사각형 (borderRadius 2) + 4px gap + 11px 텍스트
  - 항목 간 간격: 16px
```

### 금액 축 포맷

```
formatFinancialAmount(double amount):
  abs >= 1,000,000,000,000  -->  $X.XXT    (조 달러)
  abs >= 1,000,000,000      -->  $X.XXB    (10억 달러)
  abs >= 1,000,000          -->  $XXXM     (백만 달러)
  abs >= 1,000              -->  $X.XK     (천 달러)
  음수면 앞에 - 붙임

Y축 라벨:
  최대값 기준으로 적절한 단위 선택
  5단계 균등 분할 (0 포함)
  예: 최대 $394B면 --> $0, $100B, $200B, $300B, $400B
```

### 터치 인터랙션

```
막대 탭/롱프레스 시:
  - 해당 기간의 상세 수치 표시 (오버레이 팝업)
  - 팝업 내용:
    2024년 (연간) 또는 Q3 2024 (분기)
    매출: $394.3B
    영업이익: $123.2B (마진 31.3%)
    순이익: $97.0B
  - 팝업 위치: 탭한 막대 위
  - 배경: appCardBackground, shadow, borderRadius 8
  - 다른 영역 탭 시 팝업 닫힘
```

### 영업이익률 라인 오버레이 (선택적)

```
토글 방식: 범례 영역에 "이익률" 토글 칩 추가
활성화 시:
  - 우측에 별도 Y축 (0%~50%, 11px, appTextHint)
  - 각 기간 중앙에 도트 + 연결 라인
  - 라인 색상: appAccent, 1.5px
  - 도트: 4px 원형, 같은 색상
비활성화 시: 라인 숨기고 우측 Y축 제거
```

### 데스크톱 (>= 768px) 변형

차트 높이 280px로 확대. barWidth 여유로워짐.
터치 대신 마우스 호버로 팝업 표시.

---

## 5. 섹션 4: EPS Beat/Miss 차트

### 디자인 컨셉

Yahoo Finance의 Earnings 탭 스타일 — 실제 EPS와 예상 EPS를 나란히 비교하는 그룹 막대 차트.
Beat/Miss를 직관적으로 색상 구분. 서프라이즈 %를 막대 위에 표시.

### 와이어프레임 (375px 모바일)

```
+-----------------------------------------------+
|  EPS 실적                                       |
+-----------------------------------------------+
|                                                 |
|  $7 +                                           |
|     |        +1.2%                              |
|  $6 +  E  A   E  A          +3.5%              |
|     | [E][A] [E][A]   E  A   E  A              |
|  $5 + [E][A] [E][A] [E][A] [E][A]    -0.8%    |
|     | [E][A] [E][A] [E][A] [E][A]  E  A        |
|  $4 + [E][A] [E][A] [E][A] [E][A] [E][A]      |
|     | [E][A] [E][A] [E][A] [E][A] [E][A]       |
|  $3 + [E][A] [E][A] [E][A] [E][A] [E][A]      |
|     |                                           |
|  $0 +--Q3'23--Q4'23--Q1'24--Q2'24--Q3'24---    |
|                                                 |
|  [==] 예상  [==] 실제(Beat)  [==] 실제(Miss)     |
|                                                 |
+-----------------------------------------------+

  E = 예상 EPS 막대 (회색)
  A = 실제 EPS 막대 (Beat=초록, Miss=빨강)
  +X.X% = 서프라이즈 비율 (막대 위 텍스트)
```

### CustomPainter 좌표 스펙

```
전체 위젯:
  높이: 200px (차트) + 36px (범례) + 24px (X축) = 260px
  좌측 여백: 40px (EPS 값이 짧으므로 52보다 작게)
  우측 여백: 16px

막대 그룹 (최근 4~8분기, Finnhub 데이터 양에 따라):
  groupCount: min(dataLength, 8)
  groupWidth = availableWidth / groupCount
  groupPadding = groupWidth * 0.25
  barAreaWidth = groupWidth - groupPadding
  barWidth = (barAreaWidth - barGap) / 2
  barGap = 2px

예상 막대:
  색상 Light: gray300 (#D1D5DB)
  색상 Dark: gray600 (#4B5563)
  getter: appChartEpsEstimate

실제 막대 (Beat):
  색상 Light: green500 (#10B981)
  색상 Dark: green400 (#34D399)
  getter: appChartEpsBeat

실제 막대 (Miss):
  색상 Light: red500 (#EF4444)
  색상 Dark: red400 (#F87171)
  getter: appChartEpsMiss

서프라이즈 % 텍스트:
  위치: 실제 막대 상단 위 4px
  폰트: 10px bold
  색상: Beat=green600/green400, Miss=red600/red400
  포맷: "+3.5%" 또는 "-0.8%"
  양수면 "+" 접두사
```

### X축 라벨 포맷

```
분기 표시: "Q{분기}'{연도 뒤 2자리}"
예시: Q1'24, Q2'24, Q3'24, Q4'24
Finnhub earnings 데이터의 period 필드에서 추출:
  "2024-03-31" -> 월 기준 분기 판별 -> Q1'24
```

### 터치 인터랙션

```
그룹 탭 시 오버레이 팝업:
  Q3 2024
  예상 EPS: $6.54
  실제 EPS: $6.61
  서프라이즈: +$0.07 (+1.07%)  [Beat 색상]

팝업 스타일: 섹션 3과 동일
```

### 음수 EPS 처리

```
적자 기업:
  EPS가 음수인 경우 0선 아래로 막대 그리기
  Y축: 최소값~최대값 범위로 자동 조정
  0선 강조 표시 (1px, appTextHint)
```

---

## 6. 섹션 5: 기업 분석 요약

### 디자인 컨셉

토스증권의 "AI 한줄평" + 네이버증권의 투자 의견 스타일.
데이터 기반으로 자동 생성하는 텍스트 요약. 주관적 판단이 아닌 팩트 기반 해석.

### 와이어프레임 (375px 모바일)

```
+-----------------------------------------------+
|  기업 분석 요약                                  |
+-----------------------------------------------+
|                                                 |
|  +-------------------------------------------+  |
|  | [chart icon] 실적 트렌드                    |  |
|  |                                             |  |
|  | * 매출이 3년 연속 성장 중입니다.              |  |
|  |   최근 1년 성장률: +8.5%                     |  |
|  |                                             |  |
|  | * 영업이익률이 전년 대비 상승했습니다.          |  |
|  |   30.8% -> 31.3% (+0.5%p)                  |  |
|  +-------------------------------------------+  |
|                                                 |
|  +-------------------------------------------+  |
|  | [scale icon] 재무 건전성                     |  |
|  |                                             |  |
|  | * 부채비율 176.3%로, IT 섹터 평균(120%)      |  |
|  |   대비 다소 높은 편입니다.                    |  |
|  |                                             |  |
|  | * 현금 보유: $29.9B                          |  |
|  +-------------------------------------------+  |
|                                                 |
|  +-------------------------------------------+  |
|  | [target icon] 밸류에이션                      |  |
|  |                                             |  |
|  | * PER 28.5배로 S&P 500 평균(22배) 대비       |  |
|  |   프리미엄이 있습니다.                        |  |
|  |                                             |  |
|  | * 최근 4분기 EPS가 모두 예상을 상회했습니다.   |  |
|  +-------------------------------------------+  |
|                                                 |
|  +-------------------------------------------+  |
|  | (i) 본 분석은 공개된 재무 데이터를 기반으로   |  |
|  | 자동 생성된 것이며, 투자 권유가 아닙니다.      |  |
|  | 투자 결정은 본인의 판단과 책임 하에            |  |
|  | 이루어져야 합니다.                             |  |
|  +-------------------------------------------+  |
|                                                 |
+-----------------------------------------------+
```

### 텍스트 자동 생성 규칙

#### 카테고리 1: 실적 트렌드

```yaml
매출 성장 판단:
  rule_consecutive_growth:
    condition: "최근 N년 연속 매출 YoY > 0"
    N >= 3: "매출이 {N}년 연속 성장 중입니다."
    N >= 2: "매출이 2년 연속 성장했습니다."
    N == 1: "매출이 전년 대비 성장으로 전환했습니다."
    N == 0: "매출이 전년 대비 감소했습니다."
    append: "최근 1년 성장률: {yoy}%"

  rule_consecutive_decline:
    condition: "최근 N년 연속 매출 YoY < 0"
    N >= 2: "매출이 {N}년 연속 감소 추세입니다."
    append: "최근 1년 변동률: {yoy}%"

영업이익률 변화:
  rule_margin_change:
    current vs previous 비교
    diff > 1%p: "영업이익률이 전년 대비 크게 개선되었습니다. {prev}% -> {curr}% (+{diff}%p)"
    diff > 0: "영업이익률이 전년 대비 소폭 상승했습니다. {prev}% -> {curr}% (+{diff}%p)"
    diff == 0: "영업이익률이 전년과 유사합니다. {curr}%"
    diff < -1%p: "영업이익률이 전년 대비 하락했습니다. {prev}% -> {curr}% ({diff}%p)"
    diff < 0: "영업이익률이 전년 대비 소폭 하락했습니다."

순이익 판단:
  rule_profitability:
    netIncome > 0: (별도 언급 안 함, 정상)
    netIncome < 0 && prevNetIncome > 0: "적자로 전환되었습니다."
    netIncome < 0 && prevNetIncome < 0: "적자가 지속되고 있습니다."
    netIncome > 0 && prevNetIncome < 0: "흑자로 전환에 성공했습니다."
```

#### 카테고리 2: 재무 건전성

```yaml
부채비율:
  rule_debt_ratio:
    ratio < 50%: "부채비율 {ratio}%로 재무구조가 매우 안정적입니다."
    ratio < 100%: "부채비율 {ratio}%로 양호한 재무구조입니다."
    ratio < 200%: "부채비율 {ratio}%로 보통 수준입니다."
    ratio >= 200%: "부채비율 {ratio}%로 다소 높은 편입니다."
    항상 append: "현금 보유: ${cash_formatted}"

현금 흐름 (향후 확장):
  rule_fcf:
    fcf > 0 && growing: "잉여현금흐름이 양호합니다."
    fcf < 0: "잉여현금흐름이 마이너스입니다."
```

#### 카테고리 3: 밸류에이션

```yaml
PER 평가:
  rule_per:
    per < 0: "현재 적자로 PER 산출이 불가합니다."
    per < 10: "PER {per}배로 저평가 영역입니다."
    per < 20: "PER {per}배로 적정 수준입니다."
    per < 30: "PER {per}배로 성장 프리미엄이 반영되어 있습니다."
    per >= 30: "PER {per}배로 높은 밸류에이션입니다."

EPS 실적:
  rule_eps_track:
    최근 4분기 중 beat 횟수 계산
    beat == 4: "최근 4분기 EPS가 모두 예상을 상회했습니다."
    beat == 3: "최근 4분기 중 3분기 EPS가 예상을 상회했습니다."
    beat <= 2: "최근 EPS 실적이 예상에 미치지 못하는 경우가 있습니다."

배당:
  rule_dividend:
    yield > 3%: "배당률 {yield}%로 배당 매력이 있습니다."
    yield > 0: "배당률 {yield}%입니다."
    yield == 0: "현재 배당을 지급하지 않습니다."
```

### 면책 문구 스타일

```
배경: appIconBg (연한 회색/다크)
borderRadius: 8
padding: 12
아이콘: Icons.info_outline, 14px, appTextHint
텍스트: 12px, appTextHint
고정 문구 (절대 변경 불가):
  "본 분석은 공개된 재무 데이터를 기반으로 자동 생성된 것이며,
   투자 권유가 아닙니다. 투자 결정은 본인의 판단과 책임 하에
   이루어져야 합니다."
```

### 각 카테고리 카드 스타일

```
배경: appCardBackground
borderRadius: 8
padding: 12
아이콘: 24px, 각 카테고리별 아이콘, appAccent
  - 실적 트렌드: Icons.show_chart
  - 재무 건전성: Icons.account_balance
  - 밸류에이션: Icons.analytics
제목: 14px semibold, appTextPrimary
본문: 13px, appTextSecondary
강조 수치: 13px semibold, appTextPrimary
양수 변화: AppColors.red500 (한국식 상승=빨강)
음수 변화: AppColors.blue500 (한국식 하락=파랑)
```

---

## 7. 색상 시스템

### 신규 ThemeAwareColors getter 목록

`app_colors.dart`의 `ThemeAwareColors` extension에 추가할 getter:

```dart
// 재무제표 차트 색상
Color get appChartRevenue       // 매출 막대
Color get appChartOperatingIncome  // 영업이익 막대
Color get appChartNetIncome     // 순이익 막대
Color get appChartEpsEstimate   // EPS 예상 막대
Color get appChartEpsBeat       // EPS Beat 막대
Color get appChartEpsMiss       // EPS Miss 막대

// 지표 상태 색상
Color get appMetricGood         // 양호 (green 계열)
Color get appMetricNeutral      // 보통 (amber 계열)
Color get appMetricBad          // 주의 (red 계열)
Color get appMetricGoodBg       // 양호 배경
Color get appMetricNeutralBg    // 보통 배경
Color get appMetricBadBg        // 주의 배경
```

### 색상 매핑표

| getter | Light | Dark |
|--------|-------|------|
| `appChartRevenue` | blue500 (#3B82F6) | blue400 (#60A5FA) |
| `appChartOperatingIncome` | green500 (#10B981) | green400 (#34D399) |
| `appChartNetIncome` | amber500 (#F59E0B) | amber400 (#FBBF24) |
| `appChartEpsEstimate` | gray300 (#D1D5DB) | gray600 (#4B5563) |
| `appChartEpsBeat` | green500 (#10B981) | green400 (#34D399) |
| `appChartEpsMiss` | red500 (#EF4444) | red400 (#F87171) |
| `appMetricGood` | green600 (#059669) | green400 (#34D399) |
| `appMetricNeutral` | amber600 (#D97706) | amber400 (#FBBF24) |
| `appMetricBad` | red600 (#DC2626) | red400 (#F87171) |
| `appMetricGoodBg` | green50 (#ECFDF5) | green600@0.15 |
| `appMetricNeutralBg` | amber50 (#FFFBEB) | amber600@0.15 |
| `appMetricBadBg` | red50 (#FEF2F2) | red600@0.15 |

모든 색상은 기존 `AppColors` 팔레트 내에서 선택. 신규 Color 값 없음.

---

## 8. 반응형 규칙

### 브레이크포인트 (기존 앱 규칙 준수)

| 구간 | 너비 | 적용 |
|------|------|------|
| 모바일 | < 600px | 기본 레이아웃, 2열 그리드 |
| 태블릿 | 600~1023px | 3열 그리드, 차트 확대 |
| 데스크톱 | >= 1024px | 3열 그리드, 호버 인터랙션 |

### 섹션별 반응형 변화

| 섹션 | 모바일 (<600) | 태블릿/데스크톱 (>=600) |
|------|--------------|----------------------|
| 기업 개요 | 세로 배치 (로고 위, 그리드 아래) | 가로 배치 (로고+정보 좌, 설명 우) |
| 투자 지표 | 2열 x 3행 | 3열 x 2행 |
| 실적 추이 | 높이 220px, 터치 팝업 | 높이 280px, 호버 팝업 |
| EPS 차트 | 높이 200px, 터치 팝업 | 높이 240px, 호버 팝업 |
| 기업 분석 | 세로 카드 나열 | 동일 (읽기 콘텐츠라 변경 불필요) |

---

## 9. 구현 파일 구조

### 예상 디렉토리

```
lib/
  data/
    models/
      financial_statement.dart      # 손익계산서 모델
      company_profile.dart          # 기업 프로필 모델
      financial_metric.dart         # 투자 지표 모델
      earnings_data.dart            # EPS 실적 모델
    services/
      api/
        fmp_service.dart            # FMP API 서비스

  domain/
    financial_analysis_engine.dart  # 섹션 5 텍스트 생성 로직

  presentation/
    providers/
      financial_providers.dart      # Riverpod providers
    widgets/
      financial/
        company_profile_card.dart   # 섹션 1
        financial_metrics_grid.dart # 섹션 2
        metric_info_sheet.dart      # 섹션 2 (i) 설명 시트
        earnings_chart.dart         # 섹션 3 위젯
        earnings_chart_painter.dart # 섹션 3 CustomPainter
        eps_chart.dart              # 섹션 4 위젯
        eps_chart_painter.dart      # 섹션 4 CustomPainter
        financial_summary_card.dart # 섹션 5
```

### 통합 위치

`index_detail_screen.dart`의 기존 섹션 목록:
1. 차트 (DetailChartSection)
2. 기간 수익률 (PeriodReturnsSection)
3. 피봇 포인트 (PivotPointSection)
4. 뉴스 (NewsSection)
5. 설명 (DescriptionSection)

재무제표 섹션 삽입 위치:
- 기간 수익률 아래, 피봇 포인트 위 (또는 별도 탭)
- 개별 종목(^가 아닌 심볼)에서만 표시
- 지수(^NDX, ^GSPC)에서는 숨김

### 로딩 전략

```
1단계 (즉시): 기존 차트+가격 로드 (현재 동작 유지)
2단계 (지연): 재무 데이터 lazy 로드
  - 스크롤이 재무 섹션 근처에 도달하면 로드 시작
  - 또는 "재무정보" 탭 탭 시 로드
  - Shimmer 스켈레톤 UI로 로딩 상태 표시
3단계: 캐시된 데이터 우선 표시, 백그라운드에서 최신 데이터 fetch
```

---

## 부록: 참고 자료 및 출처

### 리서치 기반

- 토스증권: 직관적 모바일 UI, 초보자 친화 설명, 재무제표 모바일 최적화
- Yahoo Finance: 2025 리디자인 — 수평 네비게이션, 풀스크린 차트, 커스터마이즈 가능한 dock
- 네이버증권: Financial Summary iframe 구조, 배당 정보 모바일 추가
- Fintech UI 원칙: 색상 인코딩으로 성과/변동성 레이어 추가, 일관된 색상 스킴, 명확한 라벨

### 제약 사항

- FMP 무료 티어: 일 250회 호출 제한 -> 캐싱 필수
- Finnhub 무료 티어: 분당 60회 -> 기존 WebSocket과 공유 주의
- 개별 종목만 지원 (지수 ^NDX, ^GSPC 는 재무제표 없음)
- ETF(QQQ, SPY 등)는 FMP에서 프로필은 가능하나 재무제표 없음 -> 해당 섹션 숨김 처리
