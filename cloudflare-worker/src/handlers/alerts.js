/**
 * 알림 조건 관리 핸들러
 *
 * 엔드포인트:
 *   POST /api/alerts/sync    → 알림 조건 전체 동기화 (KV 저장)
 *   GET  /api/alerts/config  → 현재 알림 조건 조회
 */

import { corsHeaders } from '../utils/cors.js';
import { jsonError } from '../utils/helpers.js';

const KV_KEY = 'alerts:config';

function jsonResponse(data, request, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      'Content-Type': 'application/json',
      ...corsHeaders(request),
    },
  });
}

export async function handleAlerts(request, env, url) {
  const subPath = url.pathname.replace('/api/alerts/', '');

  // POST /api/alerts/sync — 알림 조건 전체 동기화
  if (subPath === 'sync' && request.method === 'POST') {
    let body;
    try {
      body = await request.json();
    } catch {
      return jsonError('Invalid JSON body', 400, request);
    }

    const { alerts } = body;
    if (!Array.isArray(alerts)) {
      return jsonError('Missing required field: alerts (array)', 400, request);
    }

    // 유효성 검증
    for (const alert of alerts) {
      if (!alert.type) {
        return jsonError('Each alert must have a "type" field', 400, request);
      }
      if (alert.type === 'target_price' && (!alert.ticker || alert.targetPrice == null)) {
        return jsonError('target_price alert requires "ticker" and "targetPrice"', 400, request);
      }
      if (alert.type === 'percent_change' && (!alert.ticker || alert.percent == null)) {
        return jsonError('percent_change alert requires "ticker" and "percent"', 400, request);
      }
      if (alert.type === 'fear_greed' && alert.threshold == null) {
        return jsonError('fear_greed alert requires "threshold"', 400, request);
      }
    }

    const config = {
      alerts,
      updatedAt: new Date().toISOString(),
    };

    await env.CACHE_KV.put(KV_KEY, JSON.stringify(config));

    return jsonResponse({ ok: true, count: alerts.length }, request);
  }

  // GET /api/alerts/config — 현재 알림 조건 조회
  if (subPath === 'config' && request.method === 'GET') {
    const config = await env.CACHE_KV.get(KV_KEY, 'json');
    return jsonResponse(config || { alerts: [], updatedAt: null }, request);
  }

  return jsonError('Not found', 404, request);
}
