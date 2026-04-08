/**
 * Alpha Cycle API Proxy — Cloudflare Worker (모듈화 v2)
 *
 * 환경 변수:
 *   FINNHUB_API_KEY     — Finnhub REST 프록시
 *   DEEPL_API_KEY       — DeepL 번역
 *   FRED_API_KEY        — FRED 경제 데이터
 *   TWELVE_DATA_API_KEY — Twelve Data 차트 + 환율
 *   FMP_API_KEY         — Financial Modeling Prep 재무제표
 *
 * KV 바인딩:
 *   CACHE_KV            — 통합 캐시 (quotes, profiles, translations...)
 *
 * 히트 카운터:
 *   사용자 조회 티커를 KV에 `hit:<SYMBOL>` 키로 카운트 (7일 TTL).
 *   주말 Cron에서 상위 50개를 워밍 리스트에 동적 병합.
 */

import { corsHeaders } from './utils/cors.js';
import { jsonError } from './utils/helpers.js';
import { handleFinnhub } from './handlers/finnhub.js';
import { handleFMP } from './handlers/fmp.js';
import { handleDeepL } from './handlers/deepl.js';
import { handleExchangeRate } from './handlers/exchange-rate.js';
import { handleFearGreed } from './handlers/feargreed.js';
import { handleFRED } from './handlers/fred.js';
import { handleMarketNews, GLOBAL_RSS_FEEDS, KOREA_RSS_FEEDS } from './handlers/news.js';
import { handleMarketAux } from './handlers/marketaux.js';
import { handleTwelveData } from './handlers/twelvedata.js';
import { handleCalendar } from './handlers/calendar.js';
import { runCacheWarming } from './cron/warming.js';

/**
 * 히트 카운터 — 티커 조회 횟수를 KV에 기록 (비차단)
 * @param {object} env - Worker 환경 바인딩
 * @param {string|null} symbol - 티커 심볼
 */
async function recordHit(env, symbol) {
  if (!symbol) return;
  const key = `hit:${symbol.toUpperCase()}`;
  const current = parseInt(await env.CACHE_KV.get(key) || '0');
  await env.CACHE_KV.put(key, String(current + 1), { expirationTtl: 604800 }); // 7일 TTL
}

export default {
  async fetch(request, env, ctx) {
    // Preflight
    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: corsHeaders(request) });
    }

    const url = new URL(request.url);

    // ── 히트 카운터 (비차단) ──
    const hitSymbol = url.searchParams.get('symbol');
    if (hitSymbol && (
      url.pathname.startsWith('/api/finnhub/') ||
      url.pathname.startsWith('/api/fmp/') ||
      url.pathname === '/api/twelvedata/chart'
    )) {
      ctx.waitUntil(recordHit(env, hitSymbol));
    }
    // 실적 캘린더 symbols 파라미터도 히트 카운터 기록
    if (url.pathname === '/api/calendar/earnings') {
      const symbols = url.searchParams.get('symbols');
      if (symbols) {
        for (const s of symbols.split(',').map(t => t.trim()).filter(Boolean)) {
          ctx.waitUntil(recordHit(env, s));
        }
      }
    }

    // ── App token verification (optional — skip if APP_TOKEN not set) ──
    const APP_TOKEN = env.APP_TOKEN;
    if (APP_TOKEN) {
      const clientToken = request.headers.get('X-App-Token');
      // Allow: OPTIONS (already handled above), public endpoints
      const isPublicPath =
        url.pathname === '/api/feargreed' ||
        url.pathname.startsWith('/api/news/');
      if (!isPublicPath && request.method !== 'OPTIONS' && clientToken !== APP_TOKEN) {
        return jsonError('Unauthorized', 401, request);
      }
    }

    // ── 경제/실적 캘린더 ──
    if (url.pathname.startsWith('/api/calendar/')) {
      return handleCalendar(request, env, url);
    }

    // ── Finnhub REST (NEW — 7개 엔드포인트 통합) ──
    if (url.pathname.startsWith('/api/finnhub/')) {
      return handleFinnhub(request, env, url);
    }

    // ── Exchange Rate (NEW — 3-API 폴백) ──
    if (url.pathname === '/api/exchange-rate') {
      return handleExchangeRate(request, env, url);
    }

    // ── 기존 라우트 ──

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
      return handleFRED(request, env, url);
    }

    // 글로벌 시장 뉴스
    if (url.pathname === '/api/news/market') {
      return handleMarketNews(request, GLOBAL_RSS_FEEDS, 20);
    }

    // 국내 경제 뉴스
    if (url.pathname === '/api/news/korea') {
      return handleMarketNews(request, KOREA_RSS_FEEDS, 20);
    }

    // Twelve Data 차트 데이터 (캐시 프록시)
    if (url.pathname === '/api/twelvedata/chart') {
      return handleTwelveData(request, env, url);
    }

    // FMP 재무제표 (KV + Cache API)
    if (url.pathname.startsWith('/api/fmp/')) {
      return handleFMP(request, env, url);
    }

    // MarketAux 뉴스 (API 키 서버사이드 주입)
    if (url.pathname === '/api/marketaux/news') {
      return handleMarketAux(request, env, url);
    }

    return jsonError('Not found', 404, request);
  },

  // Cron 캐시 워밍
  async scheduled(event, env, ctx) {
    ctx.waitUntil(runCacheWarming(event, env));
  },
};
