/**
 * FRED 경제 데이터 프록시
 */

import { corsHeaders } from '../utils/cors.js';
import { jsonError } from '../utils/helpers.js';

export async function handleFRED(request, env, url) {
  if (request.method !== 'GET') {
    return jsonError('GET only', 405, request);
  }

  const apiKey = env.FRED_API_KEY;
  if (!apiKey) return jsonError('FRED_API_KEY not configured', 500, request);

  // /api/fred/series/observations?series_id=XXX&... → FRED API에 api_key 자동 추가
  const fredPath = url.pathname.replace(/^\/api\/fred/, '');
  const fredUrl = new URL(`https://api.stlouisfed.org/fred${fredPath}`);
  // 클라이언트 쿼리 파라미터 복사
  for (const [key, value] of url.searchParams) {
    fredUrl.searchParams.set(key, value);
  }
  // API 키 서버사이드 주입
  fredUrl.searchParams.set('api_key', apiKey);

  try {
    const resp = await fetch(fredUrl.toString(), {
      headers: { 'Accept': 'application/json' },
    });

    return new Response(resp.body, {
      status: resp.status,
      headers: {
        'Content-Type': resp.headers.get('Content-Type') || 'application/json',
        'Cache-Control': 'public, max-age=3600',
        ...corsHeaders(request),
      },
    });
  } catch (e) {
    return jsonError(`FRED error: ${e.message}`, 502, request);
  }
}
