/**
 * CNN Fear & Greed 프록시
 */

import { corsHeaders } from '../utils/cors.js';
import { jsonError } from '../utils/helpers.js';

export async function handleFearGreed(request) {
  if (request.method !== 'GET') {
    return jsonError('GET only', 405, request);
  }

  const resp = await fetch(
    'https://production.dataviz.cnn.io/index/fearandgreed/graphdata/',
    {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Referer': 'https://edition.cnn.com/',
      },
      redirect: 'follow',
    },
  );

  return new Response(resp.body, {
    status: resp.status,
    headers: {
      'Content-Type': resp.headers.get('Content-Type') || 'application/json',
      'Cache-Control': 'public, max-age=1800',
      ...corsHeaders(request),
    },
  });
}
