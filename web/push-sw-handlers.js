
// ═══════════════════════════════════════════════════════════════
// Alpha Cycle — Web Push Notification Handlers
// 빌드 후 flutter_service_worker.js 끝에 append됨 (build.sh)
// ═══════════════════════════════════════════════════════════════

// ── Push 수신 ──
self.addEventListener('push', function(event) {
  if (!event.data) return;

  var data;
  try {
    data = event.data.json();
  } catch (e) {
    data = { title: 'Alpha Cycle', body: event.data.text() };
  }

  var title = data.title || 'Alpha Cycle';
  var options = {
    body: data.body || '',
    icon: 'icons/Icon-192.png',
    badge: 'icons/Icon-192.png',
    data: { url: data.url || '.' },
    tag: data.tag || 'alert',
    renotify: true,
    // 기본값 true — Worker에서 urgent:false 를 명시적으로 보낼 때만 auto-dismiss
    requireInteraction: data.urgent !== false,
    vibrate: [200, 100, 200],
    timestamp: Date.now(),
  };

  event.waitUntil(
    self.registration.showNotification(title, options).catch(function(e) {
      // Android/Chrome 일부 환경에서 옵션 조합에 의해 실패할 수 있어 최소 옵션으로 재시도
      console.error('[Push] showNotification failed:', e);
      return self.registration.showNotification(title, {
        body: options.body,
        icon: 'icons/Icon-192.png',
        tag: options.tag,
      }).catch(function(e2) {
        console.error('[Push] showNotification fallback also failed:', e2);
      });
    })
  );
});

// ── 알림 클릭 → 앱 열기 ──
self.addEventListener('notificationclick', function(event) {
  event.notification.close();

  var url = event.notification.data && event.notification.data.url ? event.notification.data.url : '.';
  var scope = self.registration.scope; // e.g. "https://juhyunkyu.github.io/jstock/"

  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then(function(clientList) {
      for (var i = 0; i < clientList.length; i++) {
        var client = clientList[i];
        if (client.url.indexOf(scope) === 0 && 'focus' in client) {
          return client.focus();
        }
      }
      return clients.openWindow(url);
    })
  );
});
