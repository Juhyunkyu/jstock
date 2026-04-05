/**
 * RSS 시장 뉴스
 */

import { corsHeaders } from '../utils/cors.js';
import { jsonError } from '../utils/helpers.js';

export const GLOBAL_RSS_FEEDS = [
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

export const KOREA_RSS_FEEDS = [
  {
    url: 'https://www.yna.co.kr/rss/economy.xml',
    publisher: '연합뉴스',
  },
  {
    url: 'https://www.mk.co.kr/rss/30100041/',
    publisher: '매일경제',
  },
  {
    url: 'https://www.hankyung.com/feed/economy',
    publisher: '한국경제',
  },
  {
    url: 'https://www.sedaily.com/RSS/Economy',
    publisher: '서울경제',
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

/**
 * 뉴스 기사 중복 제거
 * 1단계: 완전 동일 제목 제거
 * 2단계: 유사 제목 제거 (핵심 키워드 70% 이상 겹치면 중복)
 *   - 같은 뉴스를 여러 언론사가 보도하는 경우 첫 번째만 유지
 */
function deduplicateArticles(articles) {
  const seen = new Set();
  const result = [];

  for (const article of articles) {
    // 제목 정규화: 특수문자/공백 제거, 소문자
    const normalized = normalizeTitle(article.title);

    // 1단계: 완전 동일 제목
    if (seen.has(normalized)) continue;

    // 2단계: 유사 제목 (키워드 70% 이상 겹침)
    let isDuplicate = false;
    for (const existing of seen) {
      if (similarity(normalized, existing) > 0.7) {
        isDuplicate = true;
        break;
      }
    }
    if (isDuplicate) continue;

    seen.add(normalized);
    result.push(article);
  }

  return result;
}

function normalizeTitle(title) {
  return (title || '')
    .replace(/\[.*?\]/g, '')       // [속보], [단독] 등 제거
    .replace(/[^\w가-힣]/g, ' ')   // 특수문자 → 공백
    .replace(/\s+/g, ' ')
    .trim()
    .toLowerCase();
}

function similarity(a, b) {
  const wordsA = new Set(a.split(' ').filter(w => w.length > 1));
  const wordsB = new Set(b.split(' ').filter(w => w.length > 1));
  if (wordsA.size === 0 || wordsB.size === 0) return 0;

  let overlap = 0;
  for (const word of wordsA) {
    if (wordsB.has(word)) overlap++;
  }

  const smaller = Math.min(wordsA.size, wordsB.size);
  return smaller > 0 ? overlap / smaller : 0;
}

export async function handleMarketNews(request, feeds, limit = 20) {
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

  // Collect articles from successful feeds + log failures
  let articles = [];
  const errors = [];
  for (let i = 0; i < results.length; i++) {
    const result = results[i];
    if (result.status === 'fulfilled') {
      articles = articles.concat(result.value);
    } else {
      const feedName = feeds[i]?.publisher || feeds[i]?.url || 'unknown';
      errors.push(`${feedName}: ${result.reason?.message || 'unknown error'}`);
      console.error(`[RSS] ${feedName} failed:`, result.reason?.message);
    }
  }

  // 중복 제거: 같은 제목 또는 유사 제목 필터링
  articles = deduplicateArticles(articles);

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
      ...(errors.length > 0 ? { errors } : {}),
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
