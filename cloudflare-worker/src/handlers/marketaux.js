/**
 * MarketAux 뉴스 프록시
 *
 * 클라이언트에서 API 키 노출 없이 MarketAux API를 호출합니다.
 * env.MARKETAUX_API_KEY를 서버사이드에서 주입합니다.
 */

import { corsHeaders } from '../utils/cors.js';
import { jsonError } from '../utils/helpers.js';

export async function handleMarketAux(request, env, url) {
  if (request.method !== 'GET') {
    return jsonError('GET only', 405, request);
  }

  const apiKey = env.MARKETAUX_API_KEY;
  if (!apiKey) {
    return jsonError('MARKETAUX_API_KEY not configured', 500, request);
  }

  // Forward allowed query params from client
  const allowedParams = [
    'symbols',
    'search',
    'filter_entities',
    'language',
    'limit',
    'published_after',
    'sort',
    'sort_order',
    'exclude_domains',
  ];

  const upstreamUrl = new URL('https://api.marketaux.com/v1/news/all');

  // Inject API key server-side
  upstreamUrl.searchParams.set('api_token', apiKey);

  // Forward client query params
  for (const param of allowedParams) {
    const value = url.searchParams.get(param);
    if (value) {
      upstreamUrl.searchParams.set(param, value);
    }
  }

  // Check Cache API first (30min TTL)
  const cacheKey = new Request(upstreamUrl.toString(), { method: 'GET' });
  const cache = caches.default;
  let cached = await cache.match(cacheKey);
  if (cached) {
    // Return cached response with CORS headers
    const body = await cached.text();
    return new Response(body, {
      status: 200,
      headers: {
        'Content-Type': 'application/json',
        'Cache-Control': 'public, max-age=1800',
        'X-Cache': 'HIT',
        ...corsHeaders(request),
      },
    });
  }

  try {
    const response = await fetch(upstreamUrl.toString(), {
      headers: { Accept: 'application/json' },
    });

    if (!response.ok) {
      return jsonError(
        `MarketAux API error: ${response.status}`,
        response.status,
        request,
      );
    }

    const data = await response.json();
    const body = JSON.stringify(data);

    // Store in Cache API (30min)
    const cacheResponse = new Response(body, {
      status: 200,
      headers: {
        'Content-Type': 'application/json',
        'Cache-Control': 'public, max-age=1800',
      },
    });
    // Non-blocking cache put
    cache.put(cacheKey, cacheResponse.clone());

    return new Response(body, {
      status: 200,
      headers: {
        'Content-Type': 'application/json',
        'Cache-Control': 'public, max-age=1800',
        'X-Cache': 'MISS',
        ...corsHeaders(request),
      },
    });
  } catch (err) {
    return jsonError(`MarketAux proxy error: ${err.message}`, 502, request);
  }
}
