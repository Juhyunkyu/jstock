# 트러블슈팅 & 알려진 이슈

> **최종 업데이트**: 2026-02-20

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

## 알려진 이슈 (미해결)

### 코드 품질

| # | 심각도 | 이슈 | 설명 | 파일 |
|---|--------|------|------|------|
| BUG-1 | Medium | fearGreedAlertMonitorProvider 사이드이펙트 | Provider 본문에서 캐시 쓰기 → 리빌드마다 쿨다운 리셋 | `fear_greed_providers.dart` |
| BUG-2 | Medium | 목표가 알림 반복 발생 | `previousPrice` 파라미터 무시 → 가격이 목표 넘은 상태에서 매시간 반복 알림 | `watchlist_item.dart` |
| BUG-3 | Low | 소수점 여러 개 입력 가능 | `12.34.56` 입력 허용 (저장 시 무시됨) | `alert_settings_sheet.dart` |
| BUG-4 | Low | NotificationRepository init 실패 시 재시도 없음 | IndexedDB 오류 시 영구 비작동 | `notification_repository.dart` |

### 설계/호환성

| # | 심각도 | 이슈 | 설명 |
|---|--------|------|------|
| FUTURE-1 | Medium | 목표가 알림이 한번만 울려야 하는데 반복됨 | BUG-2 해결 필요 — 임계값 "교차" 시에만 알림 |
| FUTURE-3 | Low | `eval()` 사용 → CSP 헤더 추가 시 호환 불가 | `PWAUpdateService.applyUpdate()`를 index.html JS 함수로 리팩터링 |
| FUTURE-4 | Medium | iOS Safari (비PWA) 알림 미지원 안내 없음 | PWA 미설치 시 알림 불가인데 사용자에게 설명 없음 |

### 코드 유지보수

| # | 이슈 | 설명 |
|---|------|------|
| QUALITY-1 | 알림 레코드 생성 패턴 불일치 | Watchlist: `addFromAlert()`, F&G: 수동 `NotificationRecord` 생성 |
| QUALITY-2 | 방향 매직넘버 불일치 | target: 0=이상, F&G: 0=이하 (반대!) → enum 도입 권장 |
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
| GitHub Actions 실패 | Secrets 미설정 | `FINNHUB_API_KEY`, `TWELVE_DATA_API_KEY`, `MARKETAUX_API_KEY` 확인 |

### 배포 후 캐시 문제

| 증상 | 원인 | 해결 |
|------|------|------|
| 새 기능 안 보임 (PWA) | SW가 구버전 캐시 사용 | 앱 내 업데이트 배너 → "업데이트" 탭 |
| 업데이트 버튼 안 됨 | `caches.delete()` 미호출 (구버전) | 브라우저 사이트 데이터 삭제 후 재접속 |
| Playwright MCP 캐시 | `python3 -m http.server` 사용 | `serve_nocache.py` 사용 필수 |

### Dart JS Interop 패턴

| 패턴 | 용도 | 예시 |
|------|------|------|
| `@JS('functionName')` | index.html에 정의된 JS 함수 호출 | `_jsShowNotification()` |
| `@JS('variableName')` | window 전역 변수 읽기 | `_jsPwaUpdateAvailable` |
| `@JS('eval')` | 임의 JS 코드 실행 (CSP 주의) | `_jsEval(code.toJS)` |
| `.toDart` / `.toJS` | Dart ↔ JS 타입 변환 | `JSString`, `JSBoolean` |

---

*이 문서는 앱 운영 중 발견된 이슈와 해결 방법을 기록합니다. 새 이슈 발견 시 업데이트하세요.*
