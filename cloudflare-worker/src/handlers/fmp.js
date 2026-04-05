/**
 * FMP 재무제표 프록시 (KV + Cache API 이중 캐시)
 *
 * KV TTL: profile 7일, income-statement 30일
 * Cache API TTL: 24시간
 * 폴백: KV → Cache API → FMP API
 */

import { corsHeaders } from '../utils/cors.js';
import { jsonError } from '../utils/helpers.js';
import { getCached, setCached } from '../utils/cache.js';

/**
 * FMP 엔드포인트별 KV 캐시 전략
 */
function getFMPKVConfig(fmpPath, url) {
  const symbol = (url.searchParams.get('symbol') || '').toUpperCase();

  if (fmpPath === '/profile' && symbol) {
    return {
      kvKey: `fmp_profile:${symbol}`,
      kvTTL: 604800, // 7일 (기업 프로필은 거의 불변)
    };
  }
  if (fmpPath === '/income-statement' && symbol) {
    const period = url.searchParams.get('period') || 'annual';
    return {
      kvKey: `income:${symbol}:${period}`,
      kvTTL: 2592000, // 30일 (손익계산서는 분기별 변경)
    };
  }
  // 기타 FMP 엔드포인트는 KV 미사용
  return { kvKey: null, kvTTL: null };
}

export async function handleFMP(request, env, url) {
  if (request.method !== 'GET') {
    return jsonError('GET only', 405, request);
  }

  const apiKey = env.FMP_API_KEY;
  if (!apiKey) return jsonError('FMP_API_KEY not configured', 500, request);

  const fmpPath = url.pathname.replace(/^\/api\/fmp/, '');
  if (!fmpPath || fmpPath === '/') return jsonError('FMP endpoint required', 400, request);

  // 캐시 키 설정
  const kvConfig = getFMPKVConfig(fmpPath, url);
  const cacheKey = new Request(
    `https://cache.fmp${fmpPath}?${url.searchParams.toString()}`,
    request
  );
  const cacheTTL = 86400; // 24시간

  // 1차: KV → 2차: Cache API 조회
  const { data: cached, source } = await getCached(env, kvConfig.kvKey, cacheKey);
  if (cached) {
    return new Response(cached, {
      status: 200,
      headers: {
        'Content-Type': 'application/json',
        'Cache-Control': `public, max-age=${cacheTTL}`,
        'X-Cache': source,
        ...corsHeaders(request),
      },
    });
  }

  // 3차: FMP API 호출
  const fmpUrl = new URL(`https://financialmodelingprep.com/stable${fmpPath}`);
  for (const [key, value] of url.searchParams) {
    fmpUrl.searchParams.set(key, value);
  }
  fmpUrl.searchParams.set('apikey', apiKey);

  try {
    const resp = await fetch(fmpUrl.toString(), {
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
    await setCached(env, kvConfig.kvKey, kvConfig.kvTTL, cacheKey, cacheTTL, data);

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
    return jsonError(`FMP error: ${e.message}`, 502, request);
  }
}
