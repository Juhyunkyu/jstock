/**
 * Alpha Cycle API Proxy — Cloudflare Worker
 *
 * CORS 우회 프록시: CNN Fear&Greed + DeepL 번역 + FRED 경제 데이터 + RSS 시장 뉴스 + FMP 재무제표
 *
 * 환경 변수 (Cloudflare Dashboard > Settings > Variables):
 *   DEEPL_API_KEY      — DeepL API 키
 *   FRED_API_KEY       — FRED API 키
 *   TWELVE_DATA_API_KEY — Twelve Data API 키
 *   FMP_API_KEY        — Financial Modeling Prep API 키
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

// ─── RSS 시장 뉴스 ───
const GLOBAL_RSS_FEEDS = [
  {
    url: 'https://search.cnbc.com/rs/search/combinedcms/view.xml?partnerId=wrss01&id=100003114',
    publisher: 'CNBC',
  },
  {
    url: 'https://finance.yahoo.com/news/rssindex',
    publisher: 'Yahoo Finance',
  },
  {
    url: 'https://feeds.bbci.co.uk/news/business/rss.xml',
    publisher: 'BBC Business',
  },
];

const KOREA_RSS_FEEDS = [
  {
    url: 'https://news.google.com/rss/topics/CAAqJggKIiBDQkFTRWdvSUwyMHZNRGx6TVdZU0FtdHZHZ0pMVWlnQVAB?hl=ko&gl=KR&ceid=KR:ko',
    publisher: 'Google News',
  },
];

const PAYWALL_DOMAINS = [
  'reuters.com',
  'bloomberg.com',
  'wsj.com',
  'ft.com',
  'barrons.com',
  'marketwatch.com',
  'investing.com',
];

function parseRSS(xmlText, publisherName) {
  const articles = [];
  const itemRegex = /<item[\s>]([\s\S]*?)<\/item>/gi;
  let match;

  while ((match = itemRegex.exec(xmlText)) !== null) {
    const block = match[1];

    const title = extractTag(block, 'title');
    const link = extractTag(block, 'link');
    const description = extractTag(block, 'description');
    const pubDate = extractTag(block, 'pubDate');

    // media:content or media:thumbnail url
    let thumbnail = null;
    const mediaMatch = block.match(/<media:(?:content|thumbnail)[^>]+url=["']([^"']+)["']/i);
    if (mediaMatch) {
      thumbnail = mediaMatch[1];
    }
    // fallback: enclosure with image type
    if (!thumbnail) {
      const encMatch = block.match(/<enclosure[^>]+type=["']image\/[^"']*["'][^>]+url=["']([^"']+)["']/i);
      if (!encMatch) {
        const encMatch2 = block.match(/<enclosure[^>]+url=["']([^"']+)["'][^>]+type=["']image\/[^"']*["']/i);
        if (encMatch2) thumbnail = encMatch2[1];
      } else {
        thumbnail = encMatch[1];
      }
    }

    if (!title || !link) continue;

    // Filter paywall domains
    if (PAYWALL_DOMAINS.some((d) => link.includes(d))) continue;

    let publishedAt = null;
    if (pubDate) {
      try {
        publishedAt = new Date(pubDate).toISOString();
      } catch {
        publishedAt = null;
      }
    }

    articles.push({
      title: stripHtml(title),
      link,
      summary: description ? stripHtml(description).slice(0, 300) : null,
      publishedAt,
      thumbnail,
      publisher: publisherName,
    });
  }

  return articles;
}

function extractTag(block, tagName) {
  // Try CDATA first, then plain content
  const cdataRegex = new RegExp(`<${tagName}[^>]*>\\s*<!\\[CDATA\\[([\\s\\S]*?)\\]\\]>\\s*</${tagName}>`, 'i');
  const cdataMatch = block.match(cdataRegex);
  if (cdataMatch) return cdataMatch[1].trim();

  const plainRegex = new RegExp(`<${tagName}[^>]*>([\\s\\S]*?)</${tagName}>`, 'i');
  const plainMatch = block.match(plainRegex);
  if (plainMatch) return plainMatch[1].trim();

  return null;
}

function stripHtml(text) {
  return text
    .replace(/<[^>]*>/g, '')
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/&nbsp;/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

async function handleMarketNews(request, feeds, limit = 20) {
  if (request.method !== 'GET') {
    return jsonError('GET only', 405, request);
  }

  // Fetch all RSS feeds in parallel — individual failures don't break others
  const results = await Promise.allSettled(
    feeds.map(async (feed) => {
      const resp = await fetch(feed.url, {
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
          'Accept': 'application/xml, text/xml, */*',
        },
      });
      if (!resp.ok) throw new Error(`${feed.publisher}: HTTP ${resp.status}`);
      const xml = await resp.text();
      return parseRSS(xml, feed.publisher);
    }),
  );

  // Collect articles from successful feeds
  let articles = [];
  for (const result of results) {
    if (result.status === 'fulfilled') {
      articles = articles.concat(result.value);
    }
  }

  // Sort by publishedAt (newest first), items without date go last
  articles.sort((a, b) => {
    if (!a.publishedAt && !b.publishedAt) return 0;
    if (!a.publishedAt) return 1;
    if (!b.publishedAt) return -1;
    return new Date(b.publishedAt) - new Date(a.publishedAt);
  });

  // Limit articles
  articles = articles.slice(0, limit);

  return new Response(
    JSON.stringify({
      articles,
      cachedAt: new Date().toISOString(),
    }),
    {
      status: 200,
      headers: {
        'Content-Type': 'application/json',
        'Cache-Control': 'public, max-age=1800',
        ...corsHeaders(request),
      },
    },
  );
}

// ─── Twelve Data 차트 데이터 프록시 (캐시) ───
async function handleTwelveData(request, env, url) {
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

// ─── FMP 재무제표 프록시 (캐시) ───
async function handleFMP(request, env, url) {
  if (request.method !== 'GET') {
    return jsonError('GET only', 405, request);
  }

  const apiKey = env.FMP_API_KEY;
  if (!apiKey) return jsonError('FMP_API_KEY not configured', 500, request);

  // /api/fmp/income-statement?symbol=AAPL&period=annual&limit=5
  // → https://financialmodelingprep.com/stable/income-statement?symbol=AAPL&period=annual&limit=5&apikey=KEY
  const fmpPath = url.pathname.replace(/^\/api\/fmp/, '');
  if (!fmpPath || fmpPath === '/') return jsonError('FMP endpoint required', 400, request);

  const fmpUrl = new URL(`https://financialmodelingprep.com/stable${fmpPath}`);
  // 클라이언트 쿼리 파라미터 복사
  for (const [key, value] of url.searchParams) {
    fmpUrl.searchParams.set(key, value);
  }
  // API 키 서버사이드 주입
  fmpUrl.searchParams.set('apikey', apiKey);

  // Cloudflare Cache API — 24시간 캐시 (재무제표는 분기별 변경)
  const cacheKey = new Request(
    `https://cache.fmp${fmpPath}?${url.searchParams.toString()}`,
    request
  );
  const cache = caches.default;

  let cachedResponse = await cache.match(cacheKey);
  if (cachedResponse) {
    const headers = new Headers(cachedResponse.headers);
    Object.entries(corsHeaders(request)).forEach(([k, v]) => headers.set(k, v));
    headers.set('X-Cache', 'HIT');
    return new Response(cachedResponse.body, {
      status: cachedResponse.status,
      headers,
    });
  }

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
    const cacheTTL = 86400; // 24시간

    const responseToCache = new Response(data, {
      status: 200,
      headers: {
        'Content-Type': 'application/json',
        'Cache-Control': `public, max-age=${cacheTTL}`,
      },
    });
    await cache.put(cacheKey, responseToCache.clone());

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

    // 글로벌 시장 뉴스
    if (url.pathname === '/api/news/market') {
      return handleMarketNews(request, GLOBAL_RSS_FEEDS, 20);
    }

    // 국내 경제 뉴스
    if (url.pathname === '/api/news/korea') {
      return handleMarketNews(request, KOREA_RSS_FEEDS, 10);
    }

    // Twelve Data 차트 데이터 (캐시 프록시)
    if (url.pathname === '/api/twelvedata/chart') {
      return handleTwelveData(request, env, url);
    }

    // FMP 재무제표 (캐시 프록시)
    if (url.pathname.startsWith('/api/fmp/')) {
      return handleFMP(request, env, url);
    }

    return jsonError('Not found', 404, request);
  },
};
