/**
 * Web Push 구독 관리 핸들러
 *
 * 엔드포인트:
 *   POST   /api/push/subscribe   → Push 구독 등록 (KV 저장)
 *   DELETE /api/push/subscribe   → Push 구독 해제 (KV 삭제)
 *   GET    /api/push/subscribe   → 구독 상태 확인
 */

import { corsHeaders } from '../utils/cors.js';
import { jsonError } from '../utils/helpers.js';

const KV_KEY = 'push:subscription';

function jsonResponse(data, request, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      'Content-Type': 'application/json',
      ...corsHeaders(request),
    },
  });
}

export async function handlePushSubscribe(request, env, url) {
  // GET — 구독 상태 확인
  if (request.method === 'GET') {
    const sub = await env.CACHE_KV.get(KV_KEY, 'json');
    return jsonResponse({
      subscribed: !!sub,
      createdAt: sub?.createdAt || null,
    }, request);
  }

  // POST — 구독 등록
  if (request.method === 'POST') {
    let body;
    try {
      body = await request.json();
    } catch {
      return jsonError('Invalid JSON body', 400, request);
    }

    const { endpoint, keys } = body;
    if (!endpoint || !keys?.p256dh || !keys?.auth) {
      return jsonError('Missing required fields: endpoint, keys.p256dh, keys.auth', 400, request);
    }

    const subscription = {
      endpoint,
      keys: {
        p256dh: keys.p256dh,
        auth: keys.auth,
      },
      createdAt: new Date().toISOString(),
    };

    await env.CACHE_KV.put(KV_KEY, JSON.stringify(subscription));

    return jsonResponse({ ok: true, message: 'Push subscription registered' }, request);
  }

  // DELETE — 구독 해제
  if (request.method === 'DELETE') {
    await env.CACHE_KV.delete(KV_KEY);
    return jsonResponse({ ok: true, message: 'Push subscription removed' }, request);
  }

  return jsonError('Method not allowed', 405, request);
}
