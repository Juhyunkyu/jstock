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

    // Fear&Greed
    const hasFG = configRaw.alerts.some(a => a.type === 'fear_greed');
    if (hasFG) {
      const cached = await env.CACHE_KV.get('fear_greed:latest', 'json');
      debug.fgCached = cached?.fear_and_greed?.score ?? 'MISS';
      if (debug.fgCached === 'MISS') {
        const fgResp = await fetch('https://production.dataviz.cnn.io/index/fearandgreed/graphdata/', {
          headers: { 'User-Agent': 'Mozilla/5.0', 'Referer': 'https://edition.cnn.com/' },
        });
        debug.fgFetchStatus = fgResp.status;
        if (fgResp.ok) {
          const data = await fgResp.json();
          debug.fgFetchScore = data?.fear_and_greed?.score;
        }
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

  // 4. Fear&Greed 값 조회 (KV 캐시 → 미스 시 CNN 직접 호출)
  let fearGreedValue = null;
  const hasFearGreedAlert = alerts.some(a => a.type === 'fear_greed');
  if (hasFearGreedAlert) {
    // KV 캐시 먼저 시도
    const cached = await env.CACHE_KV.get('fear_greed:latest', 'json');
    if (cached?.fear_and_greed?.score != null) {
      fearGreedValue = Math.round(cached.fear_and_greed.score);
    } else {
      // 캐시 미스 — CNN 직접 호출
      try {
        const fgResp = await fetch(
          'https://production.dataviz.cnn.io/index/fearandgreed/graphdata/',
          {
            headers: {
              'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
              'Referer': 'https://edition.cnn.com/',
            },
          }
        );
        if (fgResp.ok) {
          const data = await fgResp.json();
          if (data?.fear_and_greed?.score != null) {
            fearGreedValue = Math.round(data.fear_and_greed.score);
            // KV 캐시 갱신 (1시간 TTL)
            await env.CACHE_KV.put('fear_greed:latest', JSON.stringify(data), { expirationTtl: 3600 });
          }
        }
      } catch (e) {
        console.error('[AlertCheck] Fear&Greed fetch failed:', e.message);
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
    const jwt = await createVapidJWT(audience, vapidSubject, vapidPrivateKey);

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

async function createVapidJWT(audience, subject, privateKeyBase64) {
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

  // Import private key
  const keyData = base64UrlToArrayBuffer(privateKeyBase64);
  const key = await crypto.subtle.importKey(
    'raw',
    keyData,
    { name: 'ECDSA', namedCurve: 'P-256' },
  false,
    ['sign']
  );

  // ES256 서명 생성 (DER → raw r||s 변환은 Web Crypto가 자동 처리)
  // Web Crypto의 ECDSA sign은 raw format (r || s, 각 32바이트)
  const signature = await crypto.subtle.sign(
    { name: 'ECDSA', hash: 'SHA-256' },
    key,
    new TextEncoder().encode(unsignedToken)
  );

  const sigB64 = arrayBufferToBase64Url(signature);
  return `${unsignedToken}.${sigB64}`;
}

// ── AES-128-GCM 페이로드 암호화 (RFC 8291) ──

async function encryptPayload(payload, p256dhBase64, authBase64) {
  // 1. 클라이언트 공개키(p256dh)와 인증 시크릿(auth) 디코딩
  const clientPublicKey = base64UrlToArrayBuffer(p256dhBase64);
  const authSecret = base64UrlToArrayBuffer(authBase64);

  // 2. 서버 임시 ECDH 키쌍 생성
  const serverKeys = await crypto.subtle.generateKey(
    { name: 'ECDH', namedCurve: 'P-256' },
    true,
    ['deriveBits']
  );

  // 3. ECDH 공유 비밀 생성
  const clientKey = await crypto.subtle.importKey(
    'raw',
    clientPublicKey,
    { name: 'ECDH', namedCurve: 'P-256' },
    false,
    []
  );

  const sharedSecret = await crypto.subtle.deriveBits(
    { name: 'ECDH', public: clientKey },
    serverKeys.privateKey,
    256
  );

  // 4. 솔트 생성 (16바이트 랜덤)
  const salt = crypto.getRandomValues(new Uint8Array(16));

  // 5. PRK 생성 (HKDF)
  const authInfo = new TextEncoder().encode('Content-Encoding: auth\0');
  const ikm = await hkdfExtract(new Uint8Array(authSecret), new Uint8Array(sharedSecret));
  const prk = await hkdfExpand(ikm, combineInfo(authInfo, 32), 32);

  // 6. 콘텐츠 암호화 키 + nonce 도출
  const serverPublicKeyRaw = await crypto.subtle.exportKey('raw', serverKeys.publicKey);
  const keyInfo = createKeyInfo(new Uint8Array(clientPublicKey), new Uint8Array(serverPublicKeyRaw));
  const nonceInfo = createNonceInfo(new Uint8Array(clientPublicKey), new Uint8Array(serverPublicKeyRaw));

  const cekIkm = await hkdfExtract(salt, new Uint8Array(prk));
  const cek = await hkdfExpand(cekIkm, keyInfo, 16);
  const nonce = await hkdfExpand(cekIkm, nonceInfo, 12);

  // 7. AES-128-GCM 암호화
  const paddedPayload = addPadding(new TextEncoder().encode(payload));
  const key = await crypto.subtle.importKey(
    'raw',
    cek,
    { name: 'AES-GCM' },
    false,
    ['encrypt']
  );

  const encrypted = await crypto.subtle.encrypt(
    { name: 'AES-GCM', iv: nonce },
    key,
    paddedPayload
  );

  // 8. aes128gcm 헤더 + 암호문 조합
  const header = new Uint8Array(21 + serverPublicKeyRaw.byteLength);
  header.set(salt, 0);                                         // salt (16)
  header.set(new Uint8Array(new Uint32Array([4096]).buffer).reverse(), 16);  // rs (4)
  header[20] = serverPublicKeyRaw.byteLength;                  // idlen (1)
  header.set(new Uint8Array(serverPublicKeyRaw), 21);          // keyid

  const result = new Uint8Array(header.length + encrypted.byteLength);
  result.set(header, 0);
  result.set(new Uint8Array(encrypted), header.length);

  return result.buffer;
}

// ── 헬퍼 함수들 ──

function base64UrlToArrayBuffer(base64) {
  const padding = '='.repeat((4 - base64.length % 4) % 4);
  const raw = atob(base64.replace(/-/g, '+').replace(/_/g, '/') + padding);
  const arr = new Uint8Array(raw.length);
  for (let i = 0; i < raw.length; i++) arr[i] = raw.charCodeAt(i);
  return arr.buffer;
}

function arrayBufferToBase64Url(buffer) {
  const bytes = new Uint8Array(buffer);
  let binary = '';
  for (const b of bytes) binary += String.fromCharCode(b);
  return btoa(binary).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');
}

async function hkdfExtract(salt, ikm) {
  const key = await crypto.subtle.importKey('raw', salt, { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
  return new Uint8Array(await crypto.subtle.sign('HMAC', key, ikm));
}

async function hkdfExpand(prk, info, length) {
  const key = await crypto.subtle.importKey('raw', prk, { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
  const infoWithCounter = new Uint8Array(info.length + 1);
  infoWithCounter.set(info, 0);
  infoWithCounter[info.length] = 1;
  const result = new Uint8Array(await crypto.subtle.sign('HMAC', key, infoWithCounter));
  return result.slice(0, length);
}

function combineInfo(info, length) {
  return info;
}

function createKeyInfo(clientPublicKey, serverPublicKey) {
  const info = new TextEncoder().encode('Content-Encoding: aes128gcm\0');
  return info;
}

function createNonceInfo(clientPublicKey, serverPublicKey) {
  const info = new TextEncoder().encode('Content-Encoding: nonce\0');
  return info;
}

function addPadding(data) {
  // RFC 8188: delimiter byte (0x02) + data
  const padded = new Uint8Array(data.length + 1);
  padded.set(data, 0);
  padded[data.length] = 2; // delimiter
  return padded;
}
