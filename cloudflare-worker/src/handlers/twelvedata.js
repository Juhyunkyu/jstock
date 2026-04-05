/**
 * Twelve Data 차트 데이터 프록시 (캐시)
 */

import { corsHeaders } from '../utils/cors.js';
import { jsonError } from '../utils/helpers.js';

export async function handleTwelveData(request, env, url) {
  if (request.method !== 'GET') {
    return jsonError('GET only', 405, request);
  }

  const apiKey = env.TWELVE_DATA_API_KEY;
  if (!apiKey) return jsonError('TWELVE_DATA_API_KEY not configured', 500, request);

  const symbol = url.searchParams.get('symbol');
  const interval = url.searchParams.get('interval') || '1day';
  const outputsize = url.searchParams.get('outputsize') || '30';

  if (!symbol) return jsonError('symbol parameter required', 400, request);

  // Cloudflare Cache API로 5분 캐시
  const cacheKey = new Request(
    `https://cache.twelvedata/${symbol.toUpperCase()}/${interval}/${outputsize}`,
    request
  );
  const cache = caches.default;

  // 캐시 확인
  let cachedResponse = await cache.match(cacheKey);
  if (cachedResponse) {
    // 캐시 히트 — CORS 헤더 추가하여 반환
    const headers = new Headers(cachedResponse.headers);
    Object.entries(corsHeaders(request)).forEach(([k, v]) => headers.set(k, v));
    headers.set('X-Cache', 'HIT');
    return new Response(cachedResponse.body, {
      status: cachedResponse.status,
      headers,
    });
  }

  // interval별 캐시 TTL (초)
  const cacheTTLMap = {
    '1min': 300, '5min': 300, '15min': 300, '30min': 300,  // 분봉: 5분
    '1h': 900, '4h': 900,                                    // 시봉: 15분
    '1day': 1800,                                             // 일봉: 30분
    '1week': 7200,                                            // 주봉: 2시간
    '1month': 21600,                                          // 월봉: 6시간
  };
  const cacheTTL = cacheTTLMap[interval] || 300;

  // 캐시 미스 — Twelve Data API 호출
  try {
    const apiUrl = `https://api.twelvedata.com/time_series?symbol=${encodeURIComponent(symbol.toUpperCase())}&interval=${interval}&outputsize=${outputsize}&apikey=${apiKey}`;

    const resp = await fetch(apiUrl, {
      headers: { 'Accept': 'application/json' },
    });

    if (!resp.ok) {
      return new Response(resp.body, {
        status: resp.status,
        headers: {
          'Content-Type': 'application/json',
          ...corsHeaders(request),
        },
      });
    }

    const data = await resp.text();

    // 성공 응답을 캐시에 저장 (interval별 TTL)
    const responseToCache = new Response(data, {
      status: 200,
      headers: {
        'Content-Type': 'application/json',
        'Cache-Control': `public, max-age=${cacheTTL}`,
      },
    });
    await cache.put(cacheKey, responseToCache.clone());

    // 클라이언트에 반환
    return new Response(data, {
      status: 200,
      headers: {
        'Content-Type': 'application/json',
        'Cache-Control': `public, max-age=${cacheTTL}`,
        'X-Cache': 'MISS',
        ...corsHeaders(request),
      },
    });
  } catch (e) {
    return jsonError(`Twelve Data error: ${e.message}`, 502, request);
  }
}
