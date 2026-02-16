# 알파 사이클 앱 개발 계획서

**문서 버전**: 2.2
**작성일**: 2026-02-17
**목적**: Flutter 앱 개발을 위한 단계별 실행 계획 및 핵심 로직 명세

---

## 1. 핵심 매매법 공식 (Alpha Cycle Formula)

> **중요**: 이 섹션의 공식은 앱의 핵심 로직입니다. 구현 시 반드시 이 공식을 따라야 합니다.

### 1.1 기본 용어 정의

| 용어 | 영문 | 정의 |
|------|------|------|
| **시드 금액** | Seed Amount | 해당 종목에 배정한 총 투자 금액 |
| **초기 진입금** | Initial Entry Amount | 시드의 20%, 첫 매수에 사용하는 금액 |
| **초기 진입가** | Initial Entry Price | 첫 매수 시점의 주가 (고정값, 변하지 않음) |
| **평균 단가** | Average Price | 보유 주식의 평균 매수 단가 (매수할 때마다 변동) |
| **잔여 현금** | Remaining Cash | 시드 중 아직 투자하지 않은 현금 |
| **손실률** | Loss Rate | 초기 진입가 대비 현재가의 하락률 |
| **수익률** | Return Rate | 평균 단가 대비 현재가의 상승률 |

---

### 1.2 초기 설정 공식

#### 초기 진입금 (Initial Entry Amount)
```
초기 진입금 = 시드 금액 × 0.20
```

#### 잔여 현금 (Initial Remaining Cash)
```
잔여 현금 = 시드 금액 × 0.80
```

#### 단위 금액 (Unit Amount) - 참고용
```
단위 금액 = 시드 금액 × 0.01
```

| 시드 금액 | 초기 진입금 (20%) | 잔여 현금 (80%) | 단위 금액 (1%) |
|-----------|-------------------|-----------------|----------------|
| 1억원 | 2,000만원 | 8,000만원 | 100만원 |
| 5,000만원 | 1,000만원 | 4,000만원 | 50만원 |
| 1,000만원 | 200만원 | 800만원 | 10만원 |

---

### 1.3 손실률 계산 (Loss Rate)

> **중요**: 손실률은 항상 **초기 진입가** 기준으로 계산합니다.
> 추가 매수를 해도 초기 진입가는 **절대 변하지 않습니다**.

```
손실률(%) = (현재가 - 초기진입가) ÷ 초기진입가 × 100
```

#### 예시
| 초기진입가 | 현재가 | 계산 | 손실률 |
|-----------|--------|------|--------|
| $100 | $100 | (100-100)/100×100 | 0% |
| $100 | $80 | (80-100)/100×100 | **-20%** |
| $100 | $78 | (78-100)/100×100 | **-22%** |
| $100 | $50 | (50-100)/100×100 | **-50%** |
| $100 | $120 | (120-100)/100×100 | +20% |

---

### 1.4 수익률 계산 (Return Rate)

> **중요**: 수익률은 항상 **평균 단가** 기준으로 계산합니다.
> 추가 매수를 하면 평균 단가가 낮아져서 익절이 빨라집니다.

```
수익률(%) = (현재가 - 평균단가) ÷ 평균단가 × 100
```

#### 평균 단가 계산
```
평균단가 = 총 매수 금액(원화) ÷ 총 보유 수량
```

---

### 1.5 가중 매수 공식 (Weighted Buy)

> **조건**: 손실률이 **-20% 이하**일 때 **매일** 매수

```
가중 매수 금액 = 초기진입금 × |손실률| ÷ 1000
```

#### 계산 예시 (시드 1억, 초기진입금 2,000만원)

| 손실률 | 절대값 | 계산 | 매수 금액 |
|--------|--------|------|-----------|
| -20% | 20 | 2,000만 × 20 ÷ 1000 | **40만원** |
| -22% | 22 | 2,000만 × 22 ÷ 1000 | **44만원** |
| -25% | 25 | 2,000만 × 25 ÷ 1000 | **50만원** |
| -30% | 30 | 2,000만 × 30 ÷ 1000 | **60만원** |
| -40% | 40 | 2,000만 × 40 ÷ 1000 | **80만원** |
| -50% | 50 | 2,000만 × 50 ÷ 1000 | **100만원** |

#### 계산 예시 (시드 5,000만원, 초기진입금 1,000만원)

| 손실률 | 절대값 | 계산 | 매수 금액 |
|--------|--------|------|-----------|
| -20% | 20 | 1,000만 × 20 ÷ 1000 | **20만원** |
| -25% | 25 | 1,000만 × 25 ÷ 1000 | **25만원** |
| -30% | 30 | 1,000만 × 30 ÷ 1000 | **30만원** |
| -50% | 50 | 1,000만 × 50 ÷ 1000 | **50만원** |

#### 매수 정지 조건
```
손실률 > -20% 이면 매수하지 않음

예: 손실률이 -18%, -15%, -10% 등일 때는 매수 정지
```

---

### 1.6 승부수 공식 (Panic Buy)

> **조건**: 손실률이 **-50% 이하**일 때 **1회만** 발동

```
승부수 매수 금액 = 초기진입금 × 0.50
```

| 시드 금액 | 초기진입금 | 승부수 금액 |
|-----------|-----------|-------------|
| 1억원 | 2,000만원 | **1,000만원** |
| 5,000만원 | 1,000만원 | **500만원** |
| 1,000만원 | 200만원 | **100만원** |

#### 승부수 발동일 총 매수 금액
```
승부수 날 총 매수 = 승부수 금액 + 가중 매수 금액

예: -50% 도달 시 (시드 1억)
   승부수: 1,000만원
   가중매수: 2,000만 × 50 ÷ 1000 = 100만원
   ─────────────────────────────
   총 매수: 1,100만원
```

#### 승부수 사용 후
```
- 승부수는 사이클당 1회만 사용 가능
- 사용 후에는 손실률이 -50% 이하여도 가중 매수만 진행
- 새 사이클 시작 시 승부수 초기화
```

---

### 1.7 익절 조건 (Take Profit)

> **조건**: 수익률이 **+20% 이상**일 때 전량 매도

```
익절 조건: 수익률 >= +20%

수익률 = (현재가 - 평균단가) ÷ 평균단가 × 100
```

#### 익절 후 처리
```
1. 보유 주식 전량 매도
2. 새 시드 = 매도 금액 + 잔여 현금
3. 새 사이클 시작 (사이클 번호 +1)
4. 승부수 사용 여부 초기화
```

---

### 1.8 손실률 vs 수익률 비교 요약

| 구분 | 손실률 (Loss Rate) | 수익률 (Return Rate) |
|------|-------------------|---------------------|
| **기준** | 초기 진입가 (고정) | 평균 단가 (변동) |
| **용도** | 가중 매수, 승부수 조건 | 익절 조건 |
| **특징** | 추가 매수해도 변하지 않음 | 추가 매수하면 개선됨 |
| **트리거** | -20% 이하 → 매수 | +20% 이상 → 매도 |

---

### 1.9 전체 매매 플로우

```
┌─────────────────────────────────────────────────────────────┐
│                    사이클 시작                               │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  1. 초기 진입                                                │
│     └─ 시드의 20%로 첫 매수                                   │
│     └─ 이때 가격 = 초기 진입가 (이후 고정)                     │
│                                                             │
│  2. 매일 체크                                                │
│     │                                                       │
│     ├─ 손실률 계산: (현재가 - 초기진입가) / 초기진입가         │
│     │                                                       │
│     ├─ 손실률 > -20%                                        │
│     │   └─ 아무것도 안함 (대기)                               │
│     │                                                       │
│     ├─ 손실률 <= -20% AND 손실률 > -50%                      │
│     │   └─ 가중 매수: 초기진입금 × |손실률| ÷ 1000            │
│     │                                                       │
│     ├─ 손실률 <= -50% AND 승부수 미사용                       │
│     │   └─ 승부수: 초기진입금 × 50%                          │
│     │   └─ 가중 매수: 초기진입금 × |손실률| ÷ 1000            │
│     │   └─ 승부수 사용 표시                                   │
│     │                                                       │
│     └─ 손실률 <= -50% AND 승부수 이미 사용                    │
│         └─ 가중 매수만: 초기진입금 × |손실률| ÷ 1000          │
│                                                             │
│  3. 익절 체크                                                │
│     │                                                       │
│     ├─ 수익률 계산: (현재가 - 평균단가) / 평균단가            │
│     │                                                       │
│     ├─ 수익률 >= +20%                                       │
│     │   └─ 전량 매도                                         │
│     │   └─ 새 사이클 시작                                    │
│     │                                                       │
│     └─ 수익률 < +20%                                        │
│         └─ 계속 보유                                         │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## 2. 개발 단계 계획

### Phase 1: 프로젝트 초기화 (1일) ✅ 완료

**목표**: Flutter 프로젝트 생성 및 기본 구조 설정
**완료일**: 2026-01-30

| 순서 | 작업 | 산출물 | 상태 |
|------|------|--------|------|
| 1-1 | Flutter 프로젝트 생성 | alpha_cycle/ | ✅ |
| 1-2 | 폴더 구조 설정 | lib/ 하위 디렉토리 | ✅ |
| 1-3 | 의존성 패키지 설정 | pubspec.yaml | ✅ |
| 1-4 | 테마 및 색상 정의 | app_theme.dart, app_colors.dart | ✅ |
| 1-5 | 매매법 공식 상수 정의 | formula_constants.dart | ✅ |
| 1-6 | 웹 빌드 테스트 | build/web/ | ✅ |

**프로젝트 구조** (2026-02-17 현재):
```
lib/
├── main.dart
├── app.dart
├── core/
│   ├── config/
│   │   └── app_config.dart
│   ├── constants/
│   │   ├── app_constants.dart
│   │   └── formula_constants.dart
│   ├── interfaces/
│   │   ├── strategy_position.dart
│   │   └── trading_position.dart
│   ├── theme/
│   │   ├── app_colors.dart              # ThemeAwareColors extension 포함
│   │   └── app_theme.dart               # lightTheme + darkTheme
│   └── utils/
│       └── symbol_name_resolver.dart    # 심볼→표시명 조회
├── data/
│   ├── models/
│   │   ├── models.dart
│   │   ├── cycle.dart (+.g.dart)
│   │   ├── holding.dart (+.g.dart)
│   │   ├── holding_transaction.dart (+.g.dart)
│   │   ├── ohlc_data.dart
│   │   ├── settings.dart (+.g.dart)
│   │   ├── stock.dart (+.g.dart)
│   │   ├── trade.dart (+.g.dart)
│   │   └── watchlist_item.dart (+.g.dart)
│   ├── repositories/
│   │   ├── repositories.dart
│   │   ├── cycle_repository.dart
│   │   ├── holding_repository.dart
│   │   ├── settings_repository.dart
│   │   ├── trade_repository.dart
│   │   └── watchlist_repository.dart
│   └── services/
│       ├── api/
│       │   ├── api_client.dart
│       │   ├── api_exception.dart
│       │   ├── exchange_rate_service.dart
│       │   ├── fear_greed_service.dart
│       │   ├── finnhub_service.dart
│       │   ├── finnhub_websocket_service.dart
│       │   ├── news_service.dart
│       │   └── twelve_data_service.dart
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
│       └── technical_indicator_service.dart
├── domain/
│   └── usecases/
│       ├── usecases.dart
│       ├── alpha_cycle_usecase.dart
│       ├── signal_detector.dart
│       └── calculators/
│           ├── calculators.dart
│           ├── average_price_calculator.dart
│           ├── loss_calculator.dart
│           ├── panic_buy_calculator.dart
│           ├── return_calculator.dart
│           └── weighted_buy_calculator.dart
└── presentation/
    ├── providers/
    │   ├── providers.dart
    │   ├── alpha_cycle_provider.dart
    │   ├── api_providers.dart
    │   ├── core/repository_providers.dart
    │   ├── cycle_providers.dart
    │   ├── fear_greed_providers.dart
    │   ├── holding_providers.dart
    │   ├── logo_provider.dart           # 종목 로고 Provider
    │   ├── market_data_providers.dart
    │   ├── notification_providers.dart
    │   ├── portfolio_providers.dart
    │   ├── settings_providers.dart
    │   ├── stock_providers.dart
    │   ├── trade_providers.dart
    │   ├── watchlist_alert_provider.dart
    │   └── watchlist_providers.dart
    ├── routes/
    │   └── app_router.dart
    ├── screens/
    │   ├── history/history_screen.dart
    │   ├── holdings/
    │   │   ├── archived_holding_detail_screen.dart  # 완료된 보유 상세
    │   │   ├── holding_detail_screen.dart
    │   │   ├── holding_setup_screen.dart
    │   │   └── widgets/                             # 보유 종목 하위 위젯
    │   │       ├── edit_holding_sheet.dart
    │   │       ├── edit_transaction_sheet.dart
    │   │       ├── holding_info_card.dart
    │   │       ├── holding_input_field.dart
    │   │       ├── profit_loss_section.dart
    │   │       ├── trade_record_sheet.dart           # 매수/매도 기록 시트
    │   │       ├── transaction_card.dart
    │   │       └── transaction_list.dart
    │   ├── home/home_screen.dart
    │   ├── index/index_detail_screen.dart
    │   ├── settings/settings_screen.dart
    │   ├── stocks/
    │   │   ├── cycle_detail_screen.dart
    │   │   ├── cycle_setup_screen.dart
    │   │   ├── search_screen.dart
    │   │   └── stocks_screen.dart
    │   └── watchlist/watchlist_screen.dart
    └── widgets/
        ├── charts/mini_candlestick_chart.dart
        ├── common/
        │   ├── app_title_logo.dart              # ∞ Alpha Cycle 브랜딩
        │   ├── date_picker_field.dart
        │   ├── main_shell.dart                  # 반응형 셸 (모바일/태블릿/데스크톱)
        │   └── responsive_grid.dart             # 반응형 2열 그리드
        ├── history/
        │   ├── archived_holding_card.dart       # 완료된 보유 카드
        │   ├── cycle_stats_card.dart
        │   └── trade_card.dart
        ├── holdings/
        │   ├── holding_card.dart
        │   ├── holding_transaction_card.dart
        │   └── holdings.dart
        ├── home/
        │   ├── active_cycle_card.dart
        │   ├── exchange_rate_card.dart
        │   ├── fear_greed_card.dart
        │   ├── market_index_card.dart
        │   ├── market_overview_card.dart
        │   ├── portfolio_allocation_chart.dart
        │   ├── portfolio_summary_card.dart
        │   └── unified_portfolio_card.dart
        ├── index/                               # 상세 페이지 모듈화 (7파일)
        │   ├── description_section.dart
        │   ├── detail_candlestick_painter.dart
        │   ├── detail_chart_section.dart
        │   ├── news_section.dart
        │   ├── period_returns_section.dart
        │   ├── pivot_point_section.dart
        │   └── sub_chart_painters.dart
        ├── settings/
        │   ├── backup_restore.dart
        │   ├── exchange_rate_dialog.dart
        │   ├── guide_sheet.dart                # 사용 가이드 시트
        │   ├── notification_settings.dart
        │   ├── settings_dialogs.dart           # 테마/언어/정보 다이얼로그
        │   └── settings_section.dart           # 설정 섹션/아이템 위젯
        ├── shared/                              # 공용 위젯
        │   ├── buy_signal_badge.dart
        │   ├── confirm_dialog.dart
        │   ├── return_badge.dart                # 전역 등락률 배지
        │   └── ticker_logo.dart                 # 종목 로고
        ├── stocks/
        │   ├── buy_amount_display.dart
        │   ├── cycle_setup_widgets.dart        # SectionCard, ConditionRow, SummaryRow, formatKrw
        │   ├── popular_etf_list.dart
        │   ├── profit_loss_gauge.dart
        │   └── stock_info_card.dart            # 종목 정보 카드 (실시간 시세)
        └── watchlist/
            ├── add_watchlist_sheet.dart        # 관심종목 추가 시트
            ├── alert_settings_sheet.dart
            ├── watchlist_helpers.dart          # 유틸리티 함수
            └── watchlist_tile.dart             # 관심종목 카드 타일
```

---

### Phase 2: 데이터 모델 구현 (1일) ✅ 완료

**목표**: 핵심 데이터 구조 정의 및 Hive 설정
**완료일**: 2026-01-30

| 순서 | 작업 | 산출물 | 상태 |
|------|------|--------|------|
| 2-1 | Stock 모델 정의 | stock.dart | ✅ |
| 2-2 | Cycle 모델 정의 | cycle.dart | ✅ |
| 2-3 | Trade 모델 정의 | trade.dart | ✅ |
| 2-4 | Settings 모델 정의 | settings.dart | ✅ |
| 2-5 | WatchlistItem 모델 정의 | watchlist_item.dart | ✅ |
| 2-6 | Holding 모델 정의 | holding.dart | ✅ |
| 2-7 | HoldingTransaction 모델 정의 | holding_transaction.dart | ✅ |
| 2-8 | OHLC 데이터 모델 정의 | ohlc_data.dart | ✅ |
| 2-9 | Hive 어댑터 생성 | *.g.dart | ✅ |
| 2-10 | Repository 구현 | *_repository.dart | ✅ |

**데이터 모델 명세**:

#### Stock (종목)
| 필드 | 타입 | 설명 |
|------|------|------|
| ticker | String | 종목 코드 (TQQQ) |
| name | String | 종목명 (나스닥100 3배) |
| currentPrice | double | 현재가 ($) |
| changePercent | double | 일간 변동률 (%) |

#### Cycle (사이클)
| 필드 | 타입 | 설명 |
|------|------|------|
| id | String | 고유 ID |
| ticker | String | 종목 코드 |
| cycleNumber | int | 사이클 번호 |
| seedAmount | double | 시드 금액 (원) |
| initialEntryAmount | double | 초기 진입금 (원) |
| initialEntryPrice | double | 초기 진입가 ($) - **고정값** |
| averagePrice | double | 평균 단가 ($) - **변동값** |
| totalShares | double | 보유 수량 |
| remainingCash | double | 잔여 현금 (원) |
| panicUsed | bool | 승부수 사용 여부 |
| status | String | 상태 (active/completed) |
| buyTrigger | double | 매수 시작점 (-20) |
| sellTrigger | double | 익절 목표 (+20) |
| panicTrigger | double | 승부수 발동점 (-50) |
| startDate | DateTime | 시작일 |
| endDate | DateTime? | 종료일 |

#### Trade (거래)
| 필드 | 타입 | 설명 |
|------|------|------|
| id | String | 고유 ID |
| cycleId | String | 사이클 ID |
| ticker | String | 종목 코드 |
| date | DateTime | 거래일 |
| action | String | 거래 유형 |
| price | double | 거래 단가 ($) |
| shares | double | 거래 수량 |
| recommendedAmount | double | 권장 금액 (원) |
| actualAmount | double? | 실투자 금액 (원) |
| isExecuted | bool | 체결 여부 |
| lossRate | double | 손실률 (%) |
| returnRate | double | 수익률 (%) |

**거래 유형 (action)**:
| 값 | 설명 |
|---|------|
| INITIAL_BUY | 초기 진입 (시드 20%) |
| WEIGHTED_BUY | 가중 매수 (-20% 이하) |
| PANIC_BUY | 승부수 (-50% 이하, 1회) |
| TAKE_PROFIT | 익절 매도 (+20% 이상) |

---

### Phase 3: 핵심 비즈니스 로직 구현 (2일) ✅ 완료

**목표**: 매매법 공식을 코드로 구현
**완료일**: 2026-01-30

| 순서 | 작업 | 산출물 | 상태 |
|------|------|--------|------|
| 3-1 | 손실률 계산 로직 | loss_calculator.dart | ✅ |
| 3-2 | 수익률 계산 로직 | return_calculator.dart | ✅ |
| 3-3 | 가중 매수 금액 계산 | weighted_buy_calculator.dart | ✅ |
| 3-4 | 승부수 금액 계산 | panic_buy_calculator.dart | ✅ |
| 3-5 | 매매 신호 판단 로직 | signal_detector.dart | ✅ |
| 3-6 | 평균 단가 계산 로직 | average_price_calculator.dart | ✅ |
| 3-7 | 통합 UseCase | alpha_cycle_usecase.dart | ✅ |
| 3-8 | 단위 테스트 작성 | calculators_test.dart, signal_detector_test.dart | ✅ (34개 통과) |

**로직 검증 테스트 케이스**: ✅ 모두 통과

| 테스트 | 입력 | 예상 출력 |
|--------|------|----------|
| 손실률 계산 | 초기가 $100, 현재가 $80 | -20% |
| 가중 매수 | 초기진입금 2,000만, 손실률 -25% | 50만원 |
| 승부수 | 초기진입금 2,000만 | 1,000만원 |
| 익절 판단 | 평균단가 $75, 현재가 $90 | +20% → 익절 |

---

### Phase 4: UI 구현 - 홈 화면 (2일) ✅ 완료

**목표**: 대시보드 UI 구현
**완료일**: 2026-01-30

| 순서 | 작업 | 산출물 | 상태 |
|------|------|--------|------|
| 4-1 | 하단 네비게이션 (5탭) | main_shell.dart | ✅ |
| 4-2 | 홈 화면 레이아웃 | home_screen.dart | ✅ |
| 4-3 | 시장 현황 위젯 (환율 칩 + 시장 상태) | market_overview_card.dart | ✅ |
| 4-4 | 포트폴리오 요약 카드 | portfolio_summary_card.dart | ✅ |
| 4-5 | 활성 종목 카드 | active_cycle_card.dart | ✅ |
| 4-6 | 매수 신호 표시 | buy_signal_badge.dart | ✅ |
| 4-7 | 시장 지수 캔들스틱 차트 (NASDAQ 100 / S&P 500) | market_index_card.dart | ✅ |
| 4-8 | Fear & Greed Index 게이지 차트 (CNN) | fear_greed_card.dart | ✅ |
| 4-9 | 환율 카드 | exchange_rate_card.dart | ✅ |
| 4-10 | 자산 배분 도넛 차트 | portfolio_allocation_chart.dart | ✅ |
| 4-11 | 통합 포트폴리오 카드 | unified_portfolio_card.dart | ✅ |
| 4-12 | 라우터 설정 | app_router.dart | ✅ |

---

### Phase 5: UI 구현 - 종목 관리 (2일) ✅ 완료

**목표**: 검색, 등록, 상세 화면 구현
**완료일**: 2026-01-30

| 순서 | 작업 | 산출물 | 상태 |
|------|------|--------|------|
| 5-1 | 종목 검색 화면 | search_screen.dart | ✅ |
| 5-2 | 인기 ETF 목록 | popular_etf_list.dart | ✅ |
| 5-3 | 사이클 설정 화면 | cycle_setup_screen.dart | ✅ |
| 5-4 | 사이클 상세 화면 | cycle_detail_screen.dart | ✅ |
| 5-5 | 손익 게이지 위젯 | profit_loss_gauge.dart | ✅ |
| 5-6 | 매수 금액 표시 | buy_amount_display.dart | ✅ |
| 5-7 | My/종목관리 화면 (알파 사이클 + 일반 보유 탭) | stocks_screen.dart | ✅ |
| 5-8 | 일반 보유 설정 화면 | holding_setup_screen.dart | ✅ |
| 5-9 | 일반 보유 상세 화면 | holding_detail_screen.dart | ✅ |
| 5-10 | 일반 보유 카드/위젯 | holding_card.dart, holding_transaction_card.dart | ✅ |

---

### Phase 6: UI 구현 - 거래 내역 및 설정 (2일) ✅ 완료

**목표**: 거래 기록 및 앱 설정 화면 구현
**완료일**: 2026-01-30

| 순서 | 작업 | 산출물 | 상태 |
|------|------|--------|------|
| 6-1 | 거래 내역 화면 (거래 기록 + 완료된 사이클 탭) | history_screen.dart | ✅ |
| 6-2 | 거래 카드 위젯 | trade_card.dart | ✅ |
| 6-3 | 사이클 통계 위젯 | cycle_stats_card.dart | ✅ |
| 6-4 | 설정 화면 | settings_screen.dart | ✅ |
| 6-5 | 알림 설정 섹션 | notification_settings.dart | ✅ |
| 6-6 | 데이터 백업/복원 | backup_restore.dart | ✅ |
| 6-7 | 환율 설정 다이얼로그 | exchange_rate_dialog.dart | ✅ |
| 6-8 | 매매조건 설정 다이얼로그 | exchange_rate_dialog.dart | ✅ |
| 6-9 | 사용 가이드 시트 | settings_screen.dart | ✅ |

---

### Phase 7: 상태 관리 연결 (2일) ✅ 완료

**목표**: Riverpod Provider 구현 및 UI 연결

| 순서 | 작업 | 산출물 | 상태 |
|------|------|--------|------|
| 7-1 | Core Repository Providers | repository_providers.dart | ✅ |
| 7-2 | Cycle Provider | cycle_providers.dart | ✅ |
| 7-3 | Trade Provider | trade_providers.dart | ✅ |
| 7-4 | Settings Provider | settings_providers.dart | ✅ |
| 7-5 | Stock Price Provider | stock_providers.dart | ✅ |
| 7-6 | Alpha Cycle UseCase Provider | alpha_cycle_provider.dart | ✅ |
| 7-7 | Market Data Provider | market_data_providers.dart | ✅ |
| 7-8 | Fear & Greed Provider | fear_greed_providers.dart | ✅ |
| 7-9 | Holding Provider | holding_providers.dart | ✅ |
| 7-10 | Portfolio Provider | portfolio_providers.dart | ✅ |
| 7-11 | Watchlist Provider + Alert Provider | watchlist_providers.dart, watchlist_alert_provider.dart | ✅ |
| 7-12 | UI-Provider 연결 | 전체 화면 | ✅ |
| 7-13 | 앱 초기화 스플래시 화면 | app.dart | ✅ |

---

### Phase 8: 외부 API 연동 (3일) ✅ 완료

**목표**: 실시간 주가 데이터 및 시장 정보 연동
**완료일**: 2026-01-30

| 순서 | 작업 | 산출물 | 상태 |
|------|------|--------|------|
| 8-1 | API 예외 클래스 | api_exception.dart | ✅ |
| 8-2 | API 클라이언트 (Dio) | api_client.dart | ✅ |
| 8-3 | Finnhub API 서비스 (WebSocket + REST) | finnhub_service.dart, finnhub_websocket_service.dart | ✅ |
| 8-4 | Twelve Data API 서비스 (차트 OHLC) | twelve_data_service.dart | ✅ |
| 8-5 | 환율 API 연동 (open.er-api.com + Frankfurter 폴백) | exchange_rate_service.dart | ✅ |
| 8-6 | Fear & Greed Index 서비스 (CNN) | fear_greed_service.dart | ✅ |
| 8-7 | 뉴스 서비스 (MarketAux + MyMemory 번역) | news_service.dart | ✅ |
| 8-8 | 기술적 지표 서비스 | technical_indicator_service.dart | ✅ |
| 8-9 | 데이터 캐싱 전략 | cache_manager.dart | ✅ |
| 8-10 | API Providers | api_providers.dart | ✅ |
| 8-11 | Playwright API 테스트 | 전체 API 검증 | ✅ |

**API 데이터 소스**:
- **Finnhub**: 실시간 WebSocket + REST API (종목 검색, 호가, 프로필)
- **Twelve Data**: 캔들스틱 차트 데이터 (1day, 1week, 1month)
- **open.er-api.com**: 환율 API (1차, CORS 지원)
- **api.frankfurter.app**: 환율 API (폴백, CORS 지원)
- **CNN Fear & Greed**: 공포탐욕지수
- **MarketAux**: 뉴스 피드 (exclude: finance.yahoo.com)
- **MyMemory**: 뉴스 번역 (무료, 키 불필요)

**심볼 매핑**:
- `^NDX` → `QQQ` (Twelve Data, MarketAux)
- `^GSPC` → `SPY` (Twelve Data, MarketAux)

---

### Phase 9: 백그라운드 및 알림 (2일) ✅ 완료

**목표**: 정기적 가격 체크 및 알림 시스템
**완료일**: 2026-01-30

| 순서 | 작업 | 산출물 | 상태 |
|------|------|--------|------|
| 9-1 | 알림 채널 설정 | notification_channels.dart | ✅ |
| 9-2 | 알림 서비스 구현 | notification_service.dart | ✅ |
| 9-3 | 웹 알림 서비스 | web_notification_service.dart | ✅ |
| 9-4 | 가격 체크 서비스 | price_check_service.dart | ✅ |
| 9-5 | 백그라운드 태스크 핸들러 | background_task_handler.dart | ✅ |
| 9-6 | 알림 Providers | notification_providers.dart | ✅ |
| 9-7 | 관심종목 WebSocket 실시간 알림 | watchlist_alert_provider.dart | ✅ |

**알림 기능**:
- 매수 신호 (가중 매수 -20% 이하)
- 승부수 신호 (-50% 이하, 긴급)
- 익절 신호 (+20% 이상)
- 일일 요약 알림
- 관심종목 목표가/변동률 알림 (WebSocket 실시간)

---

### Phase 10: 고급 기능 및 마무리 ✅ 완료

**목표**: 차트 고급 기능, 분석 도구, 브랜딩, 반응형 UI 완성

| 순서 | 작업 | 산출물 | 상태 |
|------|------|--------|------|
| 10-1 | 단위 테스트 | test/*.dart | ✅ |
| 10-2 | 통합 테스트 | integration_test/*.dart | ✅ |
| 10-3 | 매매법 공식 검증 | formula_test.dart | ✅ |
| 10-4 | UI 테스트 | widget_test/*.dart | ✅ |
| 10-5 | 버그 수정 및 성능 최적화 | - | ✅ |
| 10-6 | Fear & Greed Index (CNN 게이지 차트) | fear_greed_card.dart | ✅ |
| 10-7 | 보조지표: VOL, RSI, MACD, BB, Stochastic, 일목균형표, OBV | technical_indicator_service.dart | ✅ |
| 10-8 | 피봇 포인트 (R2, R1, Pivot, S1, S2) + 차트 토글 | index_detail_screen.dart | ✅ |
| 10-9 | 뉴스 피드 (MarketAux API + MyMemory 번역) | news_service.dart | ✅ |
| 10-10 | 캔들스틱 차트 줌/스크롤 (마우스 휠, 핀치줌, 드래그) | market_index_card.dart | ✅ |
| 10-11 | 반응형 레이아웃 (<600px 모바일, >=600px 데스크톱 가로) | 전체 화면 | ✅ |
| 10-12 | 브랜딩 리뉴얼: Alpha Cycle + Pacifico 폰트 + ∞ 아이콘 + 다크 네이비 그라데이션 | 앱바, 스플래시, 설정 푸터 | ✅ |
| 10-13 | 관심종목 (Watchlist) 기능 (드래그 정렬, 알림 설정) | watchlist_screen.dart, alert_settings_sheet.dart | ✅ |
| 10-14 | 지수 상세 페이지 (/index/:symbol) 종합 분석 | index_detail_screen.dart | ✅ |
| 10-15 | 기간 수익률 (1D, 1W, 1M, 3M, YTD, 1Y) | index_detail_screen.dart | ✅ |
| 10-16 | 일반 보유 (Holdings) 관리 | holding_setup_screen.dart, holding_detail_screen.dart | ✅ |
| 10-17 | 포트폴리오 요약 카드 + 자산 배분 도넛 차트 | portfolio_summary_card.dart, portfolio_allocation_chart.dart | ✅ |

---

### Phase 11: 다크 모드 및 UI 리뉴얼 ✅ 완료

**목표**: 다크 모드 구현, 전역 위젯 통일, 거래내역 리뉴얼, 상세 페이지 모듈화
**완료일**: 2026-02-16

| 순서 | 작업 | 산출물 | 상태 |
|------|------|--------|------|
| 11-1 | 다크 모드 (GitHub Dark 팔레트) | app_colors.dart, app_theme.dart | ✅ |
| 11-2 | ThemeAwareColors extension | app_colors.dart | ✅ |
| 11-3 | 상세 페이지 모듈화 (2382줄 → 8파일) | widgets/index/ (7파일) | ✅ |
| 11-4 | 종목 로고 (Finnhub + IndexedDB 캐싱) | ticker_logo.dart, logo_cache_service.dart | ✅ |
| 11-5 | ReturnBadge 전역 등락률 배지 위젯 | return_badge.dart | ✅ |
| 11-6 | 거래내역 페이지 리뉴얼 (섹션 기반) | history_screen.dart, archived_holding_card.dart | ✅ |
| 11-7 | 일반 보유 상세 위젯 분리 | screens/holdings/widgets/ (8파일) | ✅ |
| 11-8 | 매도 수량 초과 입력 방지 | trade_record_sheet.dart | ✅ |
| 11-9 | BottomSheet 스크롤 지원 (소형 화면) | trade_record_sheet.dart | ✅ |
| 11-10 | 라우팅 개선 (push → go, from 파라미터) | app_router.dart | ✅ |
| 11-11 | SymbolNameResolver 유틸리티 | symbol_name_resolver.dart | ✅ |
| 11-12 | 앱 전체 하드코딩 색상 제거 | 전체 파일 | ✅ |

---

### Phase 12: 코드 품질 개선 및 반응형 UI ✅ 완료

**목표**: 버그 수정, 다크모드 위반 일괄 수정, 대형 파일 모듈화, 반응형 레이아웃
**완료일**: 2026-02-17

| 순서 | 작업 | 산출물 | 상태 |
|------|------|--------|------|
| 12-1 | cycle_setup_screen 환율 버그 수정 (하드코딩 → 실시간) | cycle_setup_screen.dart | ✅ |
| 12-2 | AppColors.darkAccent 중앙화 + appAccent getter | app_colors.dart | ✅ |
| 12-3 | watchlist_screen 다크모드 위반 수정 (5곳) | watchlist_screen.dart | ✅ |
| 12-4 | settings_screen 다크모드 위반 수정 (4곳) | settings_screen.dart | ✅ |
| 12-5 | watchlist_screen 모듈화 (910→290줄) | watchlist_tile, add_watchlist_sheet, watchlist_helpers | ✅ |
| 12-6 | settings_screen 모듈화 (675→260줄) | settings_section, settings_dialogs, guide_sheet | ✅ |
| 12-7 | cycle_setup_screen 모듈화 (908→525줄) | cycle_setup_widgets, stock_info_card | ✅ |
| 12-8 | 반응형 레이아웃 (모바일/태블릿/데스크톱) | main_shell.dart | ✅ |
| 12-9 | 반응형 2열 그리드 | responsive_grid.dart | ✅ |
| 12-10 | 데스크톱 폰트/사이즈 반응형 개선 | market_index_card, fear_greed_card 등 | ✅ |
| 12-11 | 미사용 코드 제거 (_PresetButton 등) | cycle_setup_screen.dart | ✅ |

---

## 3. 체크리스트

### 매매법 공식 구현 검증

- [x] 초기 진입금 = 시드 × 0.20
- [x] 손실률 = (현재가 - 초기진입가) ÷ 초기진입가 × 100
- [x] 수익률 = (현재가 - 평균단가) ÷ 평균단가 × 100
- [x] 가중 매수 = 초기진입금 × |손실률| ÷ 1000
- [x] 승부수 = 초기진입금 × 0.50 (1회만)
- [x] 매수 조건: 손실률 <= -20%
- [x] 익절 조건: 수익률 >= +20%
- [x] 승부수 조건: 손실률 <= -50% AND 미사용

### 핵심 로직 검증

- [x] 초기 진입가는 추가 매수해도 변하지 않음
- [x] 평균 단가는 추가 매수하면 변경됨
- [x] 승부수는 사이클당 1회만 사용
- [x] 승부수 날에도 가중 매수 함께 실행
- [x] 익절 시 새 사이클 시작 및 승부수 초기화

### 앱 기능 완성도 검증

- [x] 5탭 네비게이션 (홈, 관심종목, My, 거래내역, 설정)
- [x] 실시간 WebSocket 주가 연동 (Finnhub)
- [x] 캔들스틱 차트 (일봉/주봉/월봉, 줌/스크롤)
- [x] 보조지표 7종 (VOL, RSI, MACD, BB, Stochastic, 일목균형표, OBV)
- [x] 피봇 포인트 (R2, R1, Pivot, S1, S2)
- [x] Fear & Greed Index 게이지 차트
- [x] 뉴스 피드 + 한국어 번역
- [x] 관심종목 실시간 알림
- [x] 포트폴리오 요약 + 자산 배분 도넛 차트
- [x] 데이터 백업/복원/내보내기(CSV)/초기화
- [x] 반응형 레이아웃 (모바일/데스크톱)
- [x] Alpha Cycle 브랜딩 (Pacifico + ∞ + 다크 네이비 그라데이션)
- [x] 다크 모드 (GitHub Dark 팔레트, ThemeAwareColors extension)
- [x] ReturnBadge 전역 등락률 배지 위젯 (greenRed/redBlue)
- [x] 종목 로고 (Finnhub API + IndexedDB 캐싱)
- [x] 거래내역 리뉴얼 (섹션 기반, ArchivedHoldingCard)
- [x] 상세 페이지 모듈화 (2382줄 → 8개 파일)
- [x] 매도 수량 초과 입력 방지 + BottomSheet 스크롤
- [x] 화면 모듈화 3개 (watchlist 910→290, settings 675→260, cycle_setup 908→525)
- [x] 반응형 레이아웃 (모바일 <768px / 태블릿 768-1199px / 데스크톱 ≥1200px)
- [x] 반응형 2열 그리드 (콘텐츠 ≥700px)
- [x] cycle_setup 환율 버그 수정 (하드코딩 → 실시간)
- [x] 다크모드 위반 일괄 수정 (watchlist 5곳, settings 4곳)

---

## 4. 위험 요소 및 대응

| 위험 | 영향 | 대응 방안 |
|------|------|----------|
| Finnhub 무료 한도 (60회/분, WebSocket 재연결) | API 호출 제한 | 캐싱 전략 + WebSocket 우선 사용 + 자동 재연결 |
| iOS 백그라운드 제한 | 알림 지연 | 푸시 알림 서버 고려 (향후 FCM 도입) |
| 환율 API 장애 | 원화 계산 오류 | open.er-api.com + Frankfurter 이중화로 해결됨 + 수동 환율 입력 옵션 |
| 레버리지 ETF 상장폐지 | 데이터 없음 | 종목 삭제 기능 구현 |
| 외부 이미지 CORS 차단 | 뉴스 썸네일 미표시 | 외부 이미지 정책 한계, 코드 문제 아님 |

---

## 5. 다음 단계

1. **Drawing tools on chart** (차트 위 그리기 도구) - 추후 개발 예정
2. **백엔드 푸시 알림 구현** (현재 클라이언트 전용 → 서버 기반 FCM + Service Worker)

---

## 6. 예상 일정 (완료)

| Phase | 내용 | 예상 기간 | 상태 |
|-------|------|----------|------|
| 1 | 프로젝트 초기화 | 1일 | ✅ |
| 2 | 데이터 모델 | 1일 | ✅ |
| 3 | 비즈니스 로직 | 2일 | ✅ |
| 4 | 홈 화면 UI | 2일 | ✅ |
| 5 | 종목 관리 UI | 2일 | ✅ |
| 6 | 거래/설정 UI | 2일 | ✅ |
| 7 | 상태 관리 | 2일 | ✅ |
| 8 | API 연동 | 3일 | ✅ |
| 9 | 백그라운드/알림 | 2일 | ✅ |
| 10 | 고급 기능/마무리 | 3일 | ✅ |
| 11 | 다크 모드/UI 리뉴얼 | 3일 | ✅ |
| 12 | 코드 품질/반응형 UI | 2일 | ✅ |

**총 개발 기간**: 약 5주 (25 영업일) - **전체 완료**

---

**문서 끝**
