# Web Push Notification Design

> Alpha Cycle: 서버 기반 실시간 알림 시스템

## 1. Overview

### 현재 문제
- 알림이 **앱이 열려있을 때만** 동작 (클라이언트 WebSocket 의존)
- 앱 종료 시 모든 감시 중단 → 목표가 도달해도 알림 없음

### 목표
- **앱이 꺼져있어도** 조건 충족 시 폰에 알림 수신
- 기존 3종 알림(목표가/등락률/공포탐욕) 모두 서버 감시로 전환
- 기존 앱 내 알림(브라우저 알림 + 벨 아이콘)과 공존

### 아키텍처 변경

```
[Before]
  앱 열림 → WebSocket → 클라이언트 감시 → 브라우저 알림 (앱 꺼지면 끝)

[After]
  앱 열림 → 기존 WebSocket 알림 유지 (즉시 반응)
  +
  앱 꺼짐 → Worker cron → Finnhub REST → 조건 체크 → Web Push → 폰 알림
```

## 2. Data Flow

```
[Client]                           [Server (Cloudflare Worker)]
   │                                        │
   ├── 알림 조건 등록/수정/삭제 ──────────→  KV 저장 (alerts:USER_ID)
   │   POST /api/alerts/sync                │
   │                                        │
   ├── Push 구독 등록 ──────────────────→   KV 저장 (push:subscription)
   │   POST /api/push/subscribe             │
   │                                        │
   │                              Cron (2~5분 간격, 시장 개장 시)
   │                                ├── KV에서 알림 조건 읽기
   │                                ├── Finnhub REST 가격 조회
   │                                ├── CNN Fear&Greed 조회 (이미 캐시됨)
   │                                ├── 조건 비교
   │                                ├── 매칭 시 Web Push 전송
   │                                └── 쿨다운 기록 (KV)
   │                                        │
   ←───── Web Push Notification ────────────┘
   Service Worker 수신 → showNotification()
```

## 3. 알림 조건 (Alert Conditions)

### 3.1 목표가 알림
```json
{
  "type": "target_price",
  "ticker": "AAPL",
  "targetPrice": 156.0,
  "direction": 0,           // 0=above(이상), 1=below(이하) — Hive alertTargetDirection과 동일
  "cooldownMinutes": 60
}
```
> `enabled` 필드 없음: `targetPrice != null`이면 활성 (Hive 패턴과 동일)

### 3.2 등락률 알림
```json
{
  "type": "percent_change",
  "ticker": "TSLA",
  "basePrice": 250.0,
  "percent": 5.0,
  "direction": 0,           // 0=both(양방향), 1=up(상승만), 2=down(하락만) — Hive alertDirection과 동일
  "cooldownMinutes": 60
}
```
> `enabled` 필드 없음: `alertPercent != null`이면 활성

### 3.3 공포탐욕지수 알림
```json
{
  "type": "fear_greed",
  "threshold": 25,
  "direction": 0,           // 0=below(이하), 1=above(이상) — Hive fearGreedAlertDirection과 동일
  "cooldownMinutes": 60
}
```
> `enabled` 필드 없음: 배열에 포함되면 활성, 비활성 시 배열에서 제거

**Direction 값 매핑**: Worker KV에 Hive int 값 그대로 저장 (문자열 변환 없음). 클라이언트와 서버가 동일한 int 규약 사용.

### 3.4 KV 저장 구조
```
Key: alerts:config
Value: { alerts: [...위 조건들], updatedAt: ISO8601 }
TTL: 없음 (영구)

Key: alerts:cooldown:<type>:<ticker|global>
Value: ISO8601 (마지막 발동 시각)
TTL: 3600 (1시간, 자동 만료)

Key: push:subscription
Value: { endpoint, keys: { p256dh, auth }, createdAt }
TTL: 없음 (영구, 만료 시 클라이언트가 재등록)
```

## 4. Worker API Endpoints (신규)

### 4.1 알림 조건 동기화
```
POST /api/alerts/sync
Body: { alerts: [...] }
→ KV 'alerts:config' 저장
→ 200 { ok: true }
```

### 4.2 Push 구독 등록
```
POST /api/push/subscribe
Body: { endpoint, keys: { p256dh, auth } }
→ KV 'push:subscription' 저장
→ 200 { ok: true }
```

### 4.3 Push 구독 해제
```
DELETE /api/push/subscribe
→ KV 'push:subscription' 삭제
→ 200 { ok: true }
```

### 4.4 알림 조건 조회 (디버깅용)
```
GET /api/alerts/config
→ 200 { alerts: [...], updatedAt }
```

## 5. Cron Schedule (알림 감시)

### 5.1 주기 설계

| 시간대 (ET) | 간격 | 이유 |
|---|---|---|
| 정규장 (09:30~16:00 ET = 14:30~21:00 UTC) | 2분 | 핵심 시간, 빠른 감지 필요 |
| 폐장/주말 | 감시 안 함 | 가격 변동 없음 |
| 공포탐욕지수 | 정규장 cron에서 함께 체크 | CNN 캐시 활용 |

**프리마켓/애프터마켓**: Finnhub 무료 플랜에서 정규장 외 시세 미제공 → 감시 불필요.

**Cron 시간 매핑**: ET 09:30~16:00 = UTC 14:30~21:00. Cron은 정수 시간만 지원하므로
UTC 14~20시 (ET 10:00~16:00)로 설정. 09:30~10:00 ET 30분은 미커버 (허용 가능한 트레이드오프).

### 5.2 Finnhub 쿼터 계산
- 무료: 60 calls/min
- 정규장 2분 간격: 알림 설정된 티커 수 ÷ 2분 = calls/min
- **최대 감시 가능 티커**: ~100개 (2분마다 50개 배치 × 2회)
- 실제 감시 티커: 관심종목 중 알림 설정된 것만 → 보통 5~15개 → 쿼터 충분

### 5.3 Cron 구현 방식
Cloudflare Worker cron trigger는 **최소 1분 간격**까지 지원.
기존 캐시 워밍 cron 옆에 알림 체크 cron 추가:

```toml
# wrangler.toml
[triggers]
crons = [
  "0 13 * * 1-5",          # 기존: 캐시 워밍 (프리마켓)
  "0 22 * * 1-5",          # 기존: 캐시 워밍 (포스트마켓)
  "0 12 * * SUN",          # 기존: 캐시 워밍 (주말)
  "*/2 14-20 * * 1-5",  # 신규: 정규장 알림 체크 (UTC 14~20 = ET 10:00~16:00, 2분마다)
]
```

**참고**: Cloudflare Free 플랜의 cron trigger는 **최대 5개**까지.
기존 3개 + 신규 1개 = **4개 (여유 1개 남음)**.

## 6. Web Push 설정

### 6.1 VAPID 키 생성 (1회)
```bash
npx web-push generate-vapid-keys
# → Public Key: BN3x...
# → Private Key: aB7...
```
- Public Key → Flutter 클라이언트에서 구독 시 사용 (dart-define)
- Private Key → Worker secret (wrangler secret put VAPID_PRIVATE_KEY)

### 6.2 Worker Secrets (신규)
```
VAPID_PUBLIC_KEY   → .env + GitHub Secret + dart-define
VAPID_PRIVATE_KEY  → Worker secret only (클라이언트 노출 금지)
VAPID_SUBJECT      → "mailto:dandyju03@gmail.com"
```

### 6.3 Service Worker Push Handler
**커스텀 Service Worker 파일** (`web/custom-sw.js`)을 생성하고,
Flutter의 `flutter_service_worker.js`를 import한 뒤 push 핸들러를 추가.
`web/index.html`의 SW 등록부에서 `custom-sw.js`로 변경:
```javascript
// web/index.html — 기존
navigator.serviceWorker.register('flutter_service_worker.js');
// ↓ 변경
navigator.serviceWorker.register('custom-sw.js');
```

> 주의: `index.html`은 window context이므로 push 핸들러를 넣을 수 없음.
> `self.addEventListener('push', ...)` 는 반드시 SW 파일 안에 있어야 함.

```javascript
// web/custom-sw.js — Service Worker scope
importScripts('flutter_service_worker.js'); // Flutter SW 기능 유지

self.addEventListener('push', function(event) {
  const data = event.data ? event.data.json() : {};
  event.waitUntil(
    self.registration.showNotification(data.title || 'Alpha Cycle', {
      body: data.body || '',
      icon: '/icons/Icon-192.png',
      badge: '/icons/Icon-maskable-192.png',
      data: { url: data.url || '/' },
      tag: data.tag || 'alert',         // 같은 tag는 대체 (중복 방지)
      renotify: true,
      requireInteraction: data.urgent || false,
    })
  );
});

self.addEventListener('notificationclick', function(event) {
  event.notification.close();
  const url = event.notification.data?.url || '/';
  event.waitUntil(clients.openWindow(url));
});
```

## 7. Flutter 클라이언트 변경

### 7.1 Push 구독 (신규)
```dart
/// lib/data/services/notification/push_subscription_service.dart

class PushSubscriptionService {
  /// Push API 구독 + 서버 등록
  Future<void> subscribe() async {
    // 1. Service Worker에서 push subscription 얻기
    // 2. POST /api/push/subscribe 로 Worker에 등록
  }

  /// 구독 해제
  Future<void> unsubscribe() async {
    // 1. pushSubscription.unsubscribe()
    // 2. DELETE /api/push/subscribe
  }
}
```

### 7.2 알림 조건 동기화 (신규)
알림 조건 변경 시 → Worker KV에도 동기화:

```dart
/// 기존 알림 설정 변경 로직에 추가
Future<void> _syncAlertsToServer() async {
  // 1. Hive에서 모든 알림 조건 수집
  //    - WatchlistItem.alertPrice != null → 목표가 조건
  //    - WatchlistItem.alertPercent != null → 등락률 조건
  //    - Settings.fearGreedAlertEnabled == true → 공포탐욕 조건
  //      ※ fearGreedAlertEnabled == false면 배열에서 제외 (서버 감시 비활성)
  // 2. POST /api/alerts/sync 호출
}
```

### 7.3 기존 알림과 공존
```
알림 이벤트 발생 시:
  앱 열림 → 기존 WebSocket 알림 (즉시) + 서버 감시 중복 방지 (skip)
  앱 닫힘 → Worker cron 감시 → Web Push (2~5분 지연)
```

- **중복 방지 전략**: Worker가 Push 전송 시 쿨다운 KV 기록 → 앱 열릴 때 쿨다운 동기화 → 클라이언트 알림 skip
- **또는 단순 전략**: 둘 다 울려도 OK (사용자가 알림 탭하면 앱으로 이동, 같은 내용이면 무해)

## 8. 구현 Phase

### Phase 1: 인프라 (VAPID + Push 구독)
- [ ] VAPID 키 생성 + Worker secret 등록
- [ ] Service Worker push/notificationclick 핸들러
- [ ] Worker: POST /api/push/subscribe 엔드포인트
- [ ] Flutter: Push 구독 로직 + 권한 요청
- [ ] 테스트: 수동 curl로 Push 전송 → 폰 알림 확인

### Phase 2: 알림 조건 동기화
- [ ] Worker: POST /api/alerts/sync 엔드포인트
- [ ] Worker: GET /api/alerts/config 엔드포인트
- [ ] Flutter: 알림 조건 변경 시 서버 동기화
- [ ] KV 스키마 구현

### Phase 3: 서버 감시 (Cron)
- [ ] Worker: cron에서 알림 체크 로직
- [ ] Finnhub REST 배치 호출 (감시 티커만)
- [ ] Fear&Greed 체크 (기존 캐시 활용)
- [ ] 조건 매칭 → Web Push 전송
- [ ] 쿨다운 관리 (KV TTL)

### Phase 4: 통합 테스트 + 배포
- [ ] 목표가 알림 E2E 테스트
- [ ] 등락률 알림 E2E 테스트
- [ ] 공포탐욕 알림 E2E 테스트
- [ ] 중복 알림 방지 확인
- [ ] 시장 개장/폐장 시간 감시 ON/OFF 확인
- [ ] GitHub Pages 배포 + Worker 배포

## 9. APK 전환 대비

나중에 APK + FCM으로 전환 시 변경 범위:

| 구성요소 | 변경 내용 |
|---|---|
| Worker Push 전송 | `web-push` → `FCM HTTP v1` API (1개 함수) |
| KV `push:subscription` | `{endpoint, keys}` → `{fcmToken}` (필드 변경) |
| Flutter 구독 | `PushManager.subscribe()` → `FirebaseMessaging.getToken()` |
| Service Worker | push 핸들러 제거 (FCM이 대체) |
| 나머지 (cron, 알림 조건, KV 스키마) | **변경 없음** |

## 10. 제약 및 리스크

| 항목 | 내용 | 대응 |
|---|---|---|
| Finnhub 무료 쿼터 | 60 calls/min | 감시 티커 수 제한 + 배치 호출. Cron 전용 예산 20 calls/min 확보 (rate-limiter에서 cron 호출은 별도 카운트) |
| Finnhub REST 에러 | cron 중 429/5xx 발생 가능 | 에러 시 해당 티커 skip + 다음 cron에서 재시도. 로그 기록. 재시도 무한루프 방지 (retry 없음, 자연 cron 주기로 대체) |
| Cloudflare Free cron | 최대 5개 | 기존 3개 + 신규 1개 = 4개 (여유 1개) |
| Push 구독 만료 | 브라우저 구독이 만료될 수 있음 | 앱 열 때마다 재구독 체크 |
| Android 배터리 최적화 | Chrome 백그라운드 Kill | 사용자 안내 (배터리 제한 없음 설정) |
| iOS 제한 | PWA Push는 iOS 16.4+ 필수 | 사용자 안내 |
| 개인 사용자 전용 | 다중 사용자 미지원 (KV에 단일 구독) | 확장 필요 시 user_id 키 추가 |
| Web Push 페이로드 제한 | 최대 4KB | 알림 메시지 간결하게 |
