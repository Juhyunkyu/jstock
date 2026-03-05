# 트러블슈팅 & 알려진 이슈

> **최종 업데이트**: 2026-03-05

---

## 해결된 주요 이슈

### 1. 모바일 알림 미작동 (2026-02-20)

**증상**: 데스크톱 웹에서는 벨 배지 + OS 알림 모두 정상, 모바일(PWA/브라우저)에서는 둘 다 미작동

**원인 (5단계):**

| 단계 | 원인 | 수정 | 커밋 |
|------|------|------|------|
| 1 | `requestPermission()`이 유저 제스처 없이 호출 → 모바일 차단 | `_onSave()` 버튼 핸들러에서 호출 | `0db80eb` |
| 2 | `notifier.setTargetAlert()` async인데 `await` 누락 → state 업데이트 전 시트 닫힘 | `await` 추가 | `a15cd33` |
| 3 | SW 캐시 구버전 코드 유지 → `location.reload()`만으로 부족 | JS `caches.delete()` 후 리로드 | `f832d3e` |
| 4 | `WebNotificationService.show()` 모바일에서 throw → `addFromAlert()` 실행 안 됨 | 벨 배지 먼저 저장 + 별도 try/catch | `d2a3ab0` |
| 5 | `new Notification()` 모바일 미지원 | `ServiceWorkerRegistration.showNotification()` 사용 | `c141850` |

**핵심 교훈:**
- 모바일 알림 권한은 반드시 유저 제스처(버튼 탭) 컨텍스트에서 요청
- `new Notification()` ≠ 모바일 → `SW.showNotification()` 필수
- 중요 로직(벨 배지)은 실패 가능한 로직(브라우저 알림)보다 먼저 실행
- 시크릿 모드에서만 작동 = SW 캐시 또는 SW 관련 문제

> 상세 디버깅 기록: 프로젝트 memory `mobile-notification-debugging.md`

---

### 2. WebSocket 실시간 가격 미작동 (2026-02-19)

**증상**: 관심종목 현재가가 업데이트되지 않음

**원인 (3중 버그):**

| 원인 | 설명 | 수정 |
|------|------|------|
| REST 쿨다운 60초 | WS 데이터 도착해도 REST 쿨다운이 차단 | 쿨다운 제거 |
| subscribeAll race condition | REST 응답 전에 WS 구독 시도 | REST 응답 후 구독으로 이동 |
| dispose 시 구독 미해제 | 무료 티어 동시 구독 제한 초과 | dispose에서 WS 구독 해제 |

**핵심 교훈:**
- REST 쿨다운으로 WS 데이터를 억제하면 실시간 업데이트 불가
- `ConsumerStatefulWidget.dispose()`에서 `ref.read()` 불가 → `initState`에서 참조 저장

---

### 3. cycle_setup_screen 환율 버그 (2026-02-17)

**증상**: 사이클 설정 시 환율이 항상 1400원

**원인**: `_exchangeRate = 1400` 하드코딩

**수정**: 실시간 환율 API 값 사용

---

### 4. 목표가 알림 반복 발생 (2026-02-23, BUG-2 + FUTURE-1)

**증상**: 가격이 목표가 이상에 머무는 동안 매시간 반복 알림

**원인**: `isTargetAlertTriggered()`가 `previousPrice` 파라미터를 무시하고 단순 조건만 체크

**수정**: 교차 감지 로직으로 교체 — 이전 가격이 목표가 아래(위) → 현재 가격이 목표가 이상(이하)으로 "관통"했을 때만 트리거. `resetAlert()` 시 `_previousPrices`도 제거하여 교차 재감지 가능.

---

### 5. F&G 알림 쿨다운 리빌드마다 리셋 (2026-02-23, BUG-1)

**증상**: 공포탐욕지수 알림이 1시간 쿨다운을 무시하고 반복 발생

**원인**: `fearGreedAlertMonitorProvider` Provider 본문에서 `cache.set()` 사이드이펙트 → Provider 리빌드마다 쿨다운 타임스탬프가 갱신

**수정**: `FearGreedAlertChecker` 클래스 도입 (`WatchlistAlertChecker` 패턴). 인스턴스 상태(`_lastTriggeredAt`)로 쿨다운 관리, Provider 본문에서 사이드이펙트 제거.

---

### 6. 소수점 여러 개 입력 가능 (2026-02-23, BUG-3)

**증상**: 목표가/기준가 입력 필드에 `12.34.56` 같은 잘못된 소수 입력 가능

**원인**: `RegExp(r'[\d.]')`가 문자 단위 필터링만 수행 → 다중 소수점 허용

**수정**: `TextInputFormatter.withFunction`으로 교체, 정규식 `r'^\d*\.?\d{0,2}$'` 사용 (소수점 1개, 소수 2자리까지)

---

### 7. eval() 사용 CSP 비호환 (2026-02-23, FUTURE-3)

**증상**: `pwa_update_service.dart`에서 `@JS('eval')` 사용 → CSP 헤더 추가 시 차단

**수정**: `web/index.html`에 `window._clearCachesAndReload()` 명명 함수 추가, `@JS('_clearCachesAndReload')`로 직접 호출. `eval()` 완전 제거.

---

### 8. 방향 매직넘버 불일치 (2026-02-23, QUALITY-2)

**증상**: target `0=이상, 1=이하` vs F&G `0=이하, 1=이상` — 반대 매핑

**수정**: `AlertDirection` enum 도입 (`lib/core/constants/alert_direction.dart`). `fromTargetInt()`/`fromFearGreedInt()` 변환 메서드로 Hive 데이터 호환성 유지하면서 매직넘버 제거. 6개 파일 통일 적용.

---

### 9. PWA 이중 업데이트 배너 (2026-03-05)

**증상**: 업데이트 배너 클릭 → 리로드 → 배너가 다시 나타남 (무한 반복)

**원인 (2중):**

| 원인 | 설명 | 수정 |
|------|------|------|
| `justUpdated = false` 해제 | `controllerchange` 핸들러에서 가드 해제 → `statechange(activated)` 이벤트가 재트리거 | `justUpdated` 해제 코드 제거 (세션 수명 동안 유지) |
| 플래그 미초기화 | `_clearCachesAndReload()` 시작 시 `_pwaUpdateAvailable = false` 미설정 | 캐시 삭제 전 플래그 즉시 초기화 |

**추가 개선:**
- 업데이트 체크 주기: 30분 → 10분
- `visibilitychange` 리스너 추가: 탭 복귀 시 30초 쿨다운으로 즉시 체크

---

### 10. 상세 페이지 하단 탭 미표시 (2026-03-05)

**증상**: 종목 상세, 보유 상세 등 ShellRoute 내 상세 페이지에서 하단 네비게이션 탭이 사라짐

**원인**: `_isMainTabRoute()` 메서드가 5개 메인 탭 경로만 true 반환 → 나머지 경로에서 `bottomNavigationBar: null`

**수정**: `_isMainTabRoute()` 메서드 및 `isMainTab` 변수 완전 제거, `bottomNavigationBar: const _BottomNavBar()` 무조건 할당

---

### 11. 다크모드 "완료" 버튼 미표시 (2026-03-05)

**증상**: 전량 매도 후 "완료(기록)" 버튼과 아카이브 화면 "완료" 배지가 다크모드에서 보이지 않음

**원인**: `AppColors.primary` (#1A1A2E 다크 네이비)와 `AppColors.secondary` (#4A4A5A 그레이)가 다크 배경(#0D1117)에서 대비 부족

**수정**: `context.appAccent` 사용 (Light: `AppColors.primary`, Dark: `#58A6FF` 블루)

---

### 12. 매도 탭 수량 초과 바이패스 (2026-03-05)

**증상**: 매수 탭에서 10000 입력 → 저장 안 하고 매도 탭 전환 → 10000이 그대로 유지되어 100주 보유인데 10000주 매도 가능

**원인**: `_sharesController`가 매수/매도 탭에서 공유됨. 매도 수량 캡은 `onChanged` (타이핑) 시에만 동작 → 탭 전환은 `onChanged` 미트리거

**수정**: 매도 탭 전환(`_isBuy = false`) 시점에 보유 수량 초과 여부 확인 + 자동 캡핑 로직 추가

---

## 알려진 이슈 (미해결)

### 코드 품질

| # | 심각도 | 이슈 | 설명 | 파일 |
|---|--------|------|------|------|
| BUG-4 | Low | NotificationRepository init 실패 시 재시도 없음 | IndexedDB 오류 시 영구 비작동 | `notification_repository.dart` |

### 설계/호환성

| # | 심각도 | 이슈 | 설명 |
|---|--------|------|------|
| FUTURE-4 | Medium | iOS Safari (비PWA) 알림 미지원 안내 없음 | PWA 미설치 시 알림 불가인데 사용자에게 설명 없음 |

### 코드 유지보수

| # | 이슈 | 설명 |
|---|------|------|
| QUALITY-1 | 알림 레코드 생성 패턴 불일치 | Watchlist: `addFromAlert()`, F&G: 수동 `NotificationRecord` 생성 |
| QUALITY-3 | WebNotificationService 에러 삼킴 | 모든 catch 블록이 빈 상태 → `debugPrint` 추가 권장 |
| QUALITY-4 | 재귀 Future.delayed | PWA 업데이트 체크에 `Timer.periodic` + dispose 취소가 더 적합 |

---

## 플랫폼별 알림 지원 현황

| 플랫폼 | 벨 배지 | OS 알림 메시지 | 제한사항 |
|--------|---------|---------------|---------|
| 데스크톱 Chrome | ✅ | ✅ `new Notification()` | 없음 |
| 데스크톱 Firefox | ✅ | ✅ `new Notification()` | 없음 |
| Android Chrome (PWA) | ✅ | ✅ `SW.showNotification()` | 앱 열려 있을 때만 |
| Android Chrome (브라우저) | ✅ | ✅ `SW.showNotification()` | 앱 열려 있을 때만 |
| iOS Safari (PWA) | ✅ | ✅ `SW.showNotification()` | iOS 16.4+, 홈화면 추가 필수 |
| iOS Safari (브라우저) | ✅ | ❌ | Notification API 미지원 |

**공통 제한**: 앱이 열려 있을 때만 조건 체크 가능. 백그라운드 푸시는 FCM 서버 필요.

---

## 알려진 콘솔 에러 (정상)

| 에러 | 원인 | 대응 |
|------|------|------|
| investing.com 이미지 CORS | 외부 뉴스 썸네일 서버 CORS 정책 | 코드 문제 아님, 무시 |
| FinnhubWS 429/재연결 | 무료 API 동시 연결 제한 | 자동 재연결 정상 동작 |
| Service Worker warning | Flutter 빌드 시 SW 관련 경고 | 정상 동작에 영향 없음 |

---

## 빌드 & 배포 트러블슈팅

### 빌드 실패

| 증상 | 원인 | 해결 |
|------|------|------|
| API 키 빈 문자열 | `flutter build web` 직접 호출 | **반드시** `./build.sh` 사용 |
| intl 의존성 충돌 | Flutter 최신 버전 사용 | `3.29.2` 고정 (deploy.yml) |
| GitHub Actions 실패 | Secrets 미설정 | `FINNHUB_API_KEY`, `TWELVE_DATA_API_KEY`, `MARKETAUX_API_KEY`, `KOREAEXIM_API_KEY` 확인 |

### 배포 후 캐시 문제

| 증상 | 원인 | 해결 |
|------|------|------|
| 새 기능 안 보임 (PWA) | SW가 구버전 캐시 사용 | 앱 내 업데이트 배너 → "업데이트" 탭 |
| 업데이트 버튼 안 됨 | `caches.delete()` 미호출 (구버전) | 브라우저 사이트 데이터 삭제 후 재접속 |
| Playwright MCP 캐시 | `python3 -m http.server` 사용 | `serve_nocache.py` 사용 필수 |

### Dart JS Interop 패턴

| 패턴 | 용도 | 예시 |
|------|------|------|
| `@JS('functionName')` | index.html에 정의된 JS 함수 호출 | `_jsShowNotification()`, `_jsClearCachesAndReload()` |
| `@JS('variableName')` | window 전역 변수 읽기 | `_jsPwaUpdateAvailable` |
| `.toDart` / `.toJS` | Dart ↔ JS 타입 변환 | `JSString`, `JSBoolean` |

---

*이 문서는 앱 운영 중 발견된 이슈와 해결 방법을 기록합니다. 새 이슈 발견 시 업데이트하세요.*
