/**
 * Alpha Cycle API Proxy — Cloudflare Worker
 *
 * CORS 우회 프록시: CNN Fear&Greed + DeepL 번역 + FRED 경제 데이터
 *
 * 환경 변수 (Cloudflare Dashboard > Settings > Variables):
 *   DEEPL_API_KEY  — DeepL API 키
 *   FRED_API_KEY   — FRED API 키
 *   (CNN은 키 불필요)
 *
 * 배포:
 *   1. Cloudflare Dashboard > Workers & Pages > Create
 *   2. worker.js 내용 붙여넣기
 *   3. 환경 변수 설정
 *   4. 배포 후 URL을 앱의 PROXY_BASE_URL에 설정
 */

const ALLOWED_ORIGINS = [
  'https://juhyunkyu.github.io',
  'http://localhost:8080',
  'http://localhost:3000',
];

function corsHeaders(request) {
  const origin = request.headers.get('Origin') || '';
  if (!ALLOWED_ORIGINS.includes(origin)) return {};
  return {
    'Access-Control-Allow-Origin': origin,
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
    'Access-Control-Max-Age': '86400',
  };
}

function jsonError(message, status, request) {
  return new Response(JSON.stringify({ error: message }), {
    status,
    headers: { 'Content-Type': 'application/json', ...corsHeaders(request) },
  });
}

// ─── DeepL 번역 프록시 ───
async function handleDeepL(request, env) {
  if (request.method !== 'POST') {
    return jsonError('POST only', 405, request);
  }

  const apiKey = env.DEEPL_API_KEY;
  if (!apiKey) return jsonError('DEEPL_API_KEY not configured', 500, request);

  const resp = await fetch('https://api-free.deepl.com/v2/translate', {
    method: 'POST',
    headers: {
      'Authorization': `DeepL-Auth-Key ${apiKey}`,
      'Content-Type': 'application/json',
    },
    body: request.body,
  });

  return new Response(resp.body, {
    status: resp.status,
    headers: {
      'Content-Type': resp.headers.get('Content-Type') || 'application/json',
      ...corsHeaders(request),
    },
  });
}

// ─── FRED 경제 데이터 프록시 ───
async function handleFRED(request, env, path) {
  if (request.method !== 'GET') {
    return jsonError('GET only', 405, request);
  }

  const apiKey = env.FRED_API_KEY;
  if (!apiKey) return jsonError('FRED_API_KEY not configured', 500, request);

  // /api/fred/series/observations?series_id=XXX&... → FRED API에 api_key 자동 추가
  const fredPath = path.replace(/^\/api\/fred/, '');
  const url = new URL(`https://api.stlouisfed.org/fred${fredPath}`);
  url.searchParams.set('api_key', apiKey);

  const resp = await fetch(url.toString(), {
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
}

// ─── CNN Fear & Greed 프록시 ───
async function handleFearGreed(request) {
  if (request.method !== 'GET') {
    return jsonError('GET only', 405, request);
  }

  const resp = await fetch(
    'https://production.dataviz.cnn.io/index/fearandgreed/graphdata/',
    {
      headers: {
        'Accept': 'application/json',
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
      },
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

// ─── 라우터 ───
export default {
  async fetch(request, env) {
    // Preflight
    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: corsHeaders(request) });
    }

    const url = new URL(request.url);
    const path = url.pathname + url.search;

    // CNN Fear & Greed
    if (url.pathname === '/api/feargreed') {
      return handleFearGreed(request);
    }

    // DeepL 번역
    if (url.pathname === '/api/deepl/translate') {
      return handleDeepL(request, env);
    }

    // FRED 경제 데이터
    if (url.pathname.startsWith('/api/fred/')) {
      return handleFRED(request, env, path);
    }

    return jsonError('Not found', 404, request);
  },
};
