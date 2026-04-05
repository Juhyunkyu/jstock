/**
 * Finnhub REST 프록시 (7개 엔드포인트 통합)
 *
 * 엔드포인트별 캐시 전략:
 *   /quote         → Cache API 5min
 *   /search        → Cache API 1hr
 *   /company-news  → Cache API 30min
 *   /profile2      → KV 7일 + Cache API 24hr
 *   /metric        → KV 24hr + Cache API 24hr
 *   /earnings      → KV 7일 + Cache API 24hr
 *   /news          → Cache API 30min
 */

import { corsHeaders } from '../utils/cors.js';
import { jsonError } from '../utils/helpers.js';
import { getCached, setCached } from '../utils/cache.js';
import { canCall, recordCall } from '../utils/rate-limiter.js';

// /api/finnhub/xxx → Finnhub /xxx 경로 매핑
const PATH_MAP = {
  '/quote': '/quote',
  '/search': '/search',
  '/company-news': '/company-news',
  '/profile2': '/stock/profile2',
  '/metric': '/stock/metric',
  '/earnings': '/stock/earnings',
  '/news': '/news',
};

/**
 * Finnhub 엔드포인트별 캐시 전략 결정
 */
function getCacheConfig(subPath, symbol) {
  switch (subPath) {
    case '/quote':
      return { cacheTTL: 300, kvKey: null, kvTTL: null };           // 5min
    case '/search':
      return { cacheTTL: 3600, kvKey: null, kvTTL: null };          // 1hr
    case '/company-news':
      return { cacheTTL: 1800, kvKey: null, kvTTL: null };          // 30min
    case '/news':
      return { cacheTTL: 1800, kvKey: null, kvTTL: null };          // 30min
    case '/profile2':
      return {
        cacheTTL: 86400,                                            // Cache API 24hr
        kvKey: symbol ? `profile:${symbol}` : null,
        kvTTL: 604800,                                              // KV 7일
      };
    case '/metric':
      return {
        cacheTTL: 86400,
        kvKey: symbol ? `metric:${symbol}` : null,
        kvTTL: 86400,                                               // KV 24hr
      };
    case '/earnings':
      return {
        cacheTTL: 86400,
        kvKey: symbol ? `earnings:${symbol}` : null,
        kvTTL: 604800,                                              // KV 7일
      };
    default:
      return { cacheTTL: 300, kvKey: null, kvTTL: null };
  }
}

export async function handleFinnhub(request, env, url) {
  if (request.method !== 'GET') {
    return jsonError('GET only', 405, request);
  }

  const apiKey = env.FINNHUB_API_KEY;
  if (!apiKey) return jsonError('FINNHUB_API_KEY not configured', 500, request);

  // 경로 매핑
  const subPath = url.pathname.replace(/^\/api\/finnhub/, '');
  const finnhubPath = PATH_MAP[subPath];
  if (!finnhubPath) return jsonError('Unknown Finnhub endpoint', 400, request);

  // 캐시 전략
  const symbol = (url.searchParams.get('symbol') || '').toUpperCase();
  const config = getCacheConfig(subPath, symbol);

  // Cache API 키 생성 (token 제외한 sanitized 파라미터)
  const cacheParams = new URLSearchParams(url.searchParams);
  cacheParams.delete('token');
  const cacheKey = new Request(
    `https://cache.finnhub${finnhubPath}?${cacheParams.toString()}`,
    request
  );

  // 1차: KV → 2차: Cache API 조회
  const { data: cached, source } = await getCached(env, config.kvKey, cacheKey);
  if (cached) {
    return new Response(cached, {
      status: 200,
      headers: {
        'Content-Type': 'application/json',
        'Cache-Control': `public, max-age=${config.cacheTTL}`,
        'X-Cache': source,
        ...corsHeaders(request),
      },
    });
  }

  // Rate limit 확인
  if (!canCall()) {
    return jsonError('Rate limit exceeded. Try again shortly.', 429, request);
  }

  // Finnhub API 호출
  try {
    const finnhubUrl = new URL(`https://finnhub.io/api/v1${finnhubPath}`);
    // 클라이언트 쿼리 파라미터 복사
    for (const [key, value] of url.searchParams) {
      finnhubUrl.searchParams.set(key, value);
    }
    // API 키 서버사이드 주입
    finnhubUrl.searchParams.set('token', apiKey);
    // metric 엔드포인트는 항상 metric=all
    if (subPath === '/metric') {
      finnhubUrl.searchParams.set('metric', 'all');
    }

    recordCall();

    const resp = await fetch(finnhubUrl.toString(), {
      headers: { 'Accept': 'application/json' },
    });

    if (!resp.ok) {
      return new Response(resp.body, {
        status: resp.status,
        headers: { 'Content-Type': 'application/json', ...corsHeaders(request) },
      });
    }

    const data = await resp.text();

    // KV + Cache API 동시 저장
    await setCached(env, config.kvKey, config.kvTTL, cacheKey, config.cacheTTL, data);

    return new Response(data, {
      status: 200,
      headers: {
        'Content-Type': 'application/json',
        'Cache-Control': `public, max-age=${config.cacheTTL}`,
        'X-Cache': 'MISS',
        ...corsHeaders(request),
      },
    });
  } catch (e) {
    return jsonError(`Finnhub error: ${e.message}`, 502, request);
  }
}
