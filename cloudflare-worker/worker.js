/**
 * Alpha Cycle API Proxy — Cloudflare Worker
 *
 * CORS 우회 프록시: CNN Fear&Greed + DeepL 번역 + FRED 경제 데이터 + RSS 시장 뉴스
 *
 * 환경 변수 (Cloudflare Dashboard > Settings > Variables):
 *   DEEPL_API_KEY  — DeepL API 키
 *   FRED_API_KEY   — FRED API 키
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
const RSS_FEEDS = [
  {
    url: 'https://search.cnbc.com/rs/search/combinedcms/view.xml?partnerId=wrss01&id=100003114',
    publisher: 'CNBC',
  },
  {
    url: 'https://finance.yahoo.com/news/rssindex',
    publisher: 'Yahoo Finance',
  },
  {
    url: 'https://www.investing.com/rss/news.rss',
    publisher: 'Investing.com',
  },
  {
    url: 'https://feeds.bbci.co.uk/news/business/rss.xml',
    publisher: 'BBC Business',
  },
];

const PAYWALL_DOMAINS = [
  'reuters.com',
  'bloomberg.com',
  'wsj.com',
  'ft.com',
  'barrons.com',
  'marketwatch.com',
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

async function handleMarketNews(request) {
  if (request.method !== 'GET') {
    return jsonError('GET only', 405, request);
  }

  // Fetch all RSS feeds in parallel — individual failures don't break others
  const results = await Promise.allSettled(
    RSS_FEEDS.map(async (feed) => {
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

  // Limit to 20 articles
  articles = articles.slice(0, 20);

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

    // RSS 시장 뉴스
    if (url.pathname === '/api/news/market') {
      return handleMarketNews(request);
    }

    return jsonError('Not found', 404, request);
  },
};
