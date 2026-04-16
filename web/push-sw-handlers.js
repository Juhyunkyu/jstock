
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

  var options = {
    body: data.body || '',
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-maskable-192.png',
    data: { url: data.url || '/' },
    tag: data.tag || 'alert',
    renotify: true,
    requireInteraction: data.urgent || false,
  };

  event.waitUntil(
    self.registration.showNotification(data.title || 'Alpha Cycle', options)
  );
});

// ── 알림 클릭 → 앱 열기 ──
self.addEventListener('notificationclick', function(event) {
  event.notification.close();

  var url = event.notification.data && event.notification.data.url ? event.notification.data.url : '/';

  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then(function(clientList) {
      for (var i = 0; i < clientList.length; i++) {
        var client = clientList[i];
        if (client.url.indexOf('/jstock') !== -1 && 'focus' in client) {
          return client.focus();
        }
      }
      return clients.openWindow(url);
    })
  );
});
