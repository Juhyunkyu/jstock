/**
 * Cron 알림 체크
 *
 * 스케줄: * /2 14-20 * * 1-5 (정규장, 2분마다)
 *
 * 흐름:
 *   1. KV에서 알림 조건(alerts:config) + Push 구독(push:subscription) 읽기
 *   2. 조건별 가격 조회 (Finnhub REST) 또는 Fear&Greed 캐시 읽기
 *   3. 조건 매칭 시 Web Push 전송
 *   4. 쿨다운 기록 (KV, 1시간 TTL)
 */

import {
  encryptPayload,
  base64UrlToArrayBuffer,
  arrayBufferToBase64Url,
  rawP256PrivateToJwk,
} from './push-crypto.js';
import { fetchFearGreed } from '../lib/fearGreed.js';

const ALERTS_KV_KEY = 'alerts:config';
const PUSH_SUB_KV_KEY = 'push:subscription';

/**
 * 디버그 버전 — 진행 상황을 반환
 */
export async function runAlertCheckDebug(env) {
  const debug = { steps: [] };
  try {
    const [configRaw, subscription] = await Promise.all([
      env.CACHE_KV.get(ALERTS_KV_KEY, 'json'),
      env.CACHE_KV.get(PUSH_SUB_KV_KEY, 'json'),
    ]);
    debug.alertCount = configRaw?.alerts?.length ?? 0;
    debug.hasSubscription = !!subscription?.endpoint;

    if (!configRaw?.alerts?.length) { debug.steps.push('No alerts'); return debug; }
    if (!subscription?.endpoint) { debug.steps.push('No push subscription'); return debug; }

    // Fear&Greed — delegated to helper (cache → fetch(retry) → fallback).
    const hasFG = configRaw.alerts.some(a => a.type === 'fear_greed');
    if (hasFG) {
      // Peek cache first for the legacy `fgCached` debug field (back-compat).
      const cached = await env.CACHE_KV.get('fear_greed:latest', 'json');
      debug.fgCached = cached?.fear_and_greed?.score ?? 'MISS';

      const fg = await fetchFearGreed(env);
      debug.fgScore = fg.score;
      debug.fgSource = fg.source;
      if (fg.cachedAt) debug.fgCachedAt = fg.cachedAt;

      // Legacy fgFetchStatus semantics: populated only when we actually went to network.
      if (fg.source === 'fresh') {
        debug.fgFetchStatus = 200;
        debug.fgFetchScore = fg.score;
      } else if (fg.source === 'fallback') {
        debug.fgFetchStatus = 'failed';
      }
    }

    // Prices
    const tickers = [...new Set(configRaw.alerts.filter(a => a.ticker).map(a => a.ticker))];
    if (tickers.length && env.FINNHUB_API_KEY) {
      for (const t of tickers) {
        const r = await fetch(`https://finnhub.io/api/v1/quote?symbol=${t}&token=${env.FINNHUB_API_KEY}`);
        if (r.ok) { const d = await r.json(); debug[`price_${t}`] = d.c; }
      }
    }

    // States
    for (const a of configRaw.alerts) {
      if (a.type === 'target_price') {
        const s = await env.CACHE_KV.get(`alerts:state:target:${a.ticker}:${a.targetPrice}`);
        debug[`state_${a.ticker}_${a.targetPrice}`] = s;
      }
    }

    debug.steps.push('Debug complete — run actual check now');
    await runAlertCheck(env);
    debug.steps.push('runAlertCheck completed');

    // Post-check alerts
    const postConfig = await env.CACHE_KV.get(ALERTS_KV_KEY, 'json');
    debug.alertCountAfter = postConfig?.alerts?.length ?? 0;
  } catch (e) {
    debug.error = e.message;
    debug.stack = e.stack;
  }
  return debug;
}

/**
 * 알림 체크 메인 로직
 */
export async function runAlertCheck(env) {
  // 1. 알림 조건 + Push 구독 병렬 읽기
  const [configRaw, subscription] = await Promise.all([
    env.CACHE_KV.get(ALERTS_KV_KEY, 'json'),
    env.CACHE_KV.get(PUSH_SUB_KV_KEY, 'json'),
  ]);

  if (!configRaw || !configRaw.alerts || configRaw.alerts.length === 0) {
    return; // 알림 조건 없음
  }
  if (!subscription || !subscription.endpoint) {
    return; // Push 구독 없음
  }

  const alerts = configRaw.alerts;

  // 2. 티커 목록 수집 (중복 제거)
  const tickers = [...new Set(
    alerts
      .filter(a => a.type === 'target_price' || a.type === 'percent_change')
      .map(a => a.ticker)
      .filter(Boolean)
  )];

  // 3. 가격 조회 (배치, Finnhub REST)
  const prices = {};
  const finnhubKey = env.FINNHUB_API_KEY;
  if (finnhubKey && tickers.length > 0) {
    const results = await Promise.allSettled(
      tickers.map(async (ticker) => {
        const resp = await fetch(
          `https://finnhub.io/api/v1/quote?symbol=${ticker}&token=${finnhubKey}`
        );
        if (!resp.ok) return null;
        const data = await resp.json();
        return { ticker, price: data.c }; // c = current price
      })
    );
    for (const r of results) {
      if (r.status === 'fulfilled' && r.value && r.value.price > 0) {
        prices[r.value.ticker] = r.value.price;
      }
    }
  }

  // 4. Fear&Greed 값 조회 — helper가 cache → fetch(3s timeout + 1 retry) → last_known fallback 처리.
  let fearGreedValue = null;
  const hasFearGreedAlert = alerts.some(a => a.type === 'fear_greed');
  if (hasFearGreedAlert) {
    const fg = await fetchFearGreed(env);
    if (fg.score != null) {
      fearGreedValue = fg.score;
      if (fg.source === 'fallback') {
        const ageMin = Math.round((Date.now() - (fg.cachedAt ?? 0)) / 60000);
        console.warn(`[AlertCheck] Using F&G fallback (${ageMin}min stale)`);
      }
    }
  }

  // 5. 조건 매칭 + Push 전송
  //
  // 알림 패턴:
  //   목표가    → Crossing: 이전 상태(above/below)가 전환될 때만 발동
  //   등락률    → 1회 발동 → 자동 OFF (alerts 배열에서 제거)
  //   공포탐욕  → 1회 발동 → 자동 OFF (alerts 배열에서 제거)
  //
  const notifications = [];
  const alertsToRemove = []; // 1회 발동 후 제거할 알림 인덱스

  for (let i = 0; i < alerts.length; i++) {
    const alert = alerts[i];
    let triggered = false;
    let title = '';
    let body = '';
    let tag = '';

    // ── 목표가: Crossing 방식 ──
    if (alert.type === 'target_price') {
      const price = prices[alert.ticker];
      if (price == null) continue;

      const direction = alert.direction ?? 0; // 0=above, 1=below
      const stateKey = `alerts:state:target:${alert.ticker}:${alert.targetPrice}`;
      const prevState = await env.CACHE_KV.get(stateKey); // "above" | "below" | null

      let currentState;
      if (direction === 0) {
        // 이상 알림: above/below 판정
        currentState = price >= alert.targetPrice ? 'above' : 'below';
        triggered = prevState === 'below' && currentState === 'above';
      } else {
        // 이하 알림: above/below 판정
        currentState = price <= alert.targetPrice ? 'below' : 'above';
        triggered = prevState === 'above' && currentState === 'below';
      }

      // 상태 저장 (7일 TTL — 충분히 긴 기간)
      await env.CACHE_KV.put(stateKey, currentState, { expirationTtl: 604800 });

      if (triggered) {
        const dirLabel = direction === 0 ? '이상' : '이하';
        title = `${alert.ticker} 목표가 도달`;
        body = `현재 $${price.toFixed(2)} (목표 $${alert.targetPrice.toFixed(2)} ${dirLabel})`;
        tag = `target-${alert.ticker}`;
      }
    }

    // ── 등락률: 1회 발동 → 자동 OFF ──
    if (alert.type === 'percent_change') {
      const price = prices[alert.ticker];
      if (price == null || !alert.basePrice || !alert.percent) continue;

      const changePercent = ((price - alert.basePrice) / alert.basePrice) * 100;
      const absChange = Math.abs(changePercent);
      const direction = alert.direction ?? 0; // 0=both, 1=up, 2=down

      if (absChange >= alert.percent) {
        const isUp = changePercent > 0;
        if (direction === 0 || (direction === 1 && isUp) || (direction === 2 && !isUp)) {
          triggered = true;
          const arrow = isUp ? '▲' : '▼';
          title = `${alert.ticker} ${arrow}${absChange.toFixed(1)}% 변동`;
          body = `현재 $${price.toFixed(2)} (기준 $${alert.basePrice.toFixed(2)})`;
          tag = `percent-${alert.ticker}`;
          alertsToRemove.push(i); // 1회 발동 후 제거
        }
      }
    }

    // ── 공포탐욕: 1회 발동 → 자동 OFF ──
    if (alert.type === 'fear_greed' && fearGreedValue != null) {
      const direction = alert.direction ?? 0; // 0=below, 1=above
      if (direction === 0 && fearGreedValue <= alert.threshold) {
        triggered = true;
        title = '공포탐욕지수 알림';
        body = `현재 ${fearGreedValue} (${alert.threshold} 이하)`;
        tag = 'fear-greed';
        alertsToRemove.push(i); // 1회 발동 후 제거
      } else if (direction === 1 && fearGreedValue >= alert.threshold) {
        triggered = true;
        title = '공포탐욕지수 알림';
        body = `현재 ${fearGreedValue} (${alert.threshold} 이상)`;
        tag = 'fear-greed';
        alertsToRemove.push(i); // 1회 발동 후 제거
      }
    }

    if (triggered) {
      notifications.push({ title, body, tag });
    }
  }

  // 1회 발동 알림 제거 (등락률, 공포탐욕)
  if (alertsToRemove.length > 0) {
    const remaining = alerts.filter((_, idx) => !alertsToRemove.includes(idx));
    await env.CACHE_KV.put(ALERTS_KV_KEY, JSON.stringify({
      alerts: remaining,
      updatedAt: new Date().toISOString(),
    }));
    console.log(`[AlertCheck] Removed ${alertsToRemove.length} one-shot alert(s), ${remaining.length} remaining`);
  }

  // 6. Web Push 전송
  if (notifications.length > 0) {
    for (const notif of notifications) {
      await sendWebPush(env, subscription, notif);
    }
    console.log(`[AlertCheck] Sent ${notifications.length} push notification(s)`);
  }
}

// getCooldownKey 제거 — 목표가는 crossing 방식, 등락률/공포탐욕은 1회 발동 후 자동 제거

/**
 * Web Push 전송 (RFC 8291 — web-push 프로토콜)
 *
 * Cloudflare Worker에서는 Node.js의 web-push 라이브러리를 사용할 수 없으므로
 * Web Push Protocol을 직접 구현합니다.
 *
 * 단순화: 페이로드 암호화 없이 빈 push 전송 → SW에서 기본 알림 표시
 * 실제 페이로드가 필요하면 aes128gcm 암호화 구현이 필요하지만,
 * 현재는 제목/본문을 KV에 저장하고 SW에서 fetch하는 방식으로 우회합니다.
 */
async function sendWebPush(env, subscription, notification) {
  try {
    // 알림 데이터를 KV에 임시 저장 (SW가 fetch)
    const notifKey = `push:pending:${Date.now()}`;
    await env.CACHE_KV.put(notifKey, JSON.stringify(notification), {
      expirationTtl: 300, // 5분 후 자동 삭제
    });

    // VAPID 서명 생성 + 암호화된 Push 전송
    // Cloudflare Worker에서 web-push 프로토콜 직접 구현은 복잡하므로
    // 대안: fetch API로 push service endpoint에 직접 POST
    const vapidPublicKey = env.VAPID_PUBLIC_KEY;
    const vapidPrivateKey = env.VAPID_PRIVATE_KEY;
    const vapidSubject = env.VAPID_SUBJECT;

    if (!vapidPublicKey || !vapidPrivateKey) {
      console.error('[AlertCheck] VAPID keys not configured');
      return;
    }

    // JWT 생성 (VAPID)
    const audience = new URL(subscription.endpoint).origin;
    const jwt = await createVapidJWT(audience, vapidSubject, vapidPrivateKey, vapidPublicKey);

    // 페이로드 암호화 (aes128gcm)
    const payload = JSON.stringify(notification);
    const encrypted = await encryptPayload(
      payload,
      subscription.keys.p256dh,
      subscription.keys.auth
    );

    // Push Service에 전송
    const resp = await fetch(subscription.endpoint, {
      method: 'POST',
      headers: {
        'Authorization': `vapid t=${jwt}, k=${vapidPublicKey}`,
        'Content-Encoding': 'aes128gcm',
        'Content-Type': 'application/octet-stream',
        'TTL': '86400',
        'Urgency': 'high',
      },
      body: encrypted,
    });

    if (resp.status === 201 || resp.status === 200) {
      console.log(`[AlertCheck] Push sent: ${notification.title}`);
    } else if (resp.status === 410) {
      // Gone — 구독 만료, KV에서 삭제
      console.log('[AlertCheck] Push subscription expired, removing');
      await env.CACHE_KV.delete('push:subscription');
    } else {
      console.error(`[AlertCheck] Push failed: HTTP ${resp.status}`);
    }
  } catch (e) {
    console.error(`[AlertCheck] Push error: ${e.message}`);
  }
}

// ── VAPID JWT 생성 (ES256) ──
//
// WebCrypto spec: ECDSA private key는 'raw' 형식 import 불가 (공개키만 허용).
// 'jwk' 또는 'pkcs8' 형식 필요 → JWK 형식 사용 (이식성 높음).
// 공개키는 uncompressed P-256 (65바이트, 0x04 || X(32) || Y(32)) 형식의 base64url.
export async function createVapidJWT(audience, subject, privateKeyBase64, publicKeyBase64) {
  const header = { typ: 'JWT', alg: 'ES256' };
  const now = Math.floor(Date.now() / 1000);
  const payload = {
    aud: audience,
    exp: now + 86400,
    sub: subject,
  };

  const headerB64 = btoa(JSON.stringify(header)).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');
  const payloadB64 = btoa(JSON.stringify(payload)).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');
  const unsignedToken = `${headerB64}.${payloadB64}`;

  // Import private key (JWK 경유)
  // - d: 32바이트 private scalar (base64url)
  // - x, y: 32바이트 public 좌표 (uncompressed publicKey에서 추출)
  const privateRaw = new Uint8Array(base64UrlToArrayBuffer(privateKeyBase64));
  const publicRaw = new Uint8Array(base64UrlToArrayBuffer(publicKeyBase64));
  const jwk = rawP256PrivateToJwk(privateRaw, publicRaw);
  const key = await crypto.subtle.importKey(
    'jwk',
    jwk,
    { name: 'ECDSA', namedCurve: 'P-256' },
    false,
    ['sign']
  );

  // ES256 서명 생성. Web Crypto의 ECDSA sign output은 raw r||s (64바이트), VAPID 사양과 일치.
  const signature = await crypto.subtle.sign(
    { name: 'ECDSA', hash: 'SHA-256' },
    key,
    new TextEncoder().encode(unsignedToken)
  );

  const sigB64 = arrayBufferToBase64Url(signature);
  return `${unsignedToken}.${sigB64}`;
}

// 암호화 로직은 ./push-crypto.js 로 추출 (RFC 8291 aes128gcm).
// 여기서는 encryptPayload / base64UrlToArrayBuffer / arrayBufferToBase64Url 을 import해서 사용.
