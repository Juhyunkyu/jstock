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
import { runCacheWarming } from './cron/warming.js';

export default {
  async fetch(request, env) {
    // Preflight
    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: corsHeaders(request) });
    }

    const url = new URL(request.url);

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
      return handleMarketNews(request, KOREA_RSS_FEEDS, 10);
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
