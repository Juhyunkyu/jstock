/**
 * Exchange Rate 프록시 (3-API 폴백 체인)
 *
 * 폴백: TwelveData Forex → open.er-api.com → Frankfurter
 * 캐시: KV 10min + Cache API 10min
 */

import { corsHeaders } from '../utils/cors.js';
import { jsonError } from '../utils/helpers.js';
import { getCached, setCached } from '../utils/cache.js';

export async function handleExchangeRate(request, env, url) {
  if (request.method !== 'GET') {
    return jsonError('GET only', 405, request);
  }

  const from = (url.searchParams.get('from') || 'USD').toUpperCase();
  const to = (url.searchParams.get('to') || 'KRW').toUpperCase();
  const kvKey = `exchange_rate:${from}_${to}`;
  const cacheKey = new Request(`https://cache.exchangerate/${from}/${to}`, request);
  const cacheTTL = 600; // 10분

  // 1차: KV → 2차: Cache API 조회
  const { data: cached, source } = await getCached(env, kvKey, cacheKey);
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

  // 3차: 폴백 체인으로 환율 조회
  let rateData = null;

  // 3a: Twelve Data Forex
  if (env.TWELVE_DATA_API_KEY) {
    try {
      const resp = await fetch(
        `https://api.twelvedata.com/exchange_rate?symbol=${from}/${to}&apikey=${env.TWELVE_DATA_API_KEY}`
      );
      if (resp.ok) {
        const data = await resp.json();
        if (data.rate) {
          rateData = JSON.stringify({
            rate: parseFloat(data.rate),
            timestamp: data.timestamp || Math.floor(Date.now() / 1000),
            source: 'Twelve Data',
          });
        }
      }
    } catch (e) { /* 다음 폴백 */ }
  }

  // 3b: open.er-api.com
  if (!rateData) {
    try {
      const resp = await fetch(`https://open.er-api.com/v6/latest/${from}`);
      if (resp.ok) {
        const data = await resp.json();
        if (data.result === 'success' && data.rates?.[to]) {
          rateData = JSON.stringify({
            rate: data.rates[to],
            timestamp: data.time_last_update_unix || Math.floor(Date.now() / 1000),
            source: 'ExchangeRate-API',
          });
        }
      }
    } catch (e) { /* 다음 폴백 */ }
  }

  // 3c: Frankfurter
  if (!rateData) {
    try {
      const resp = await fetch(
        `https://api.frankfurter.app/latest?from=${from}&to=${to}`
      );
      if (resp.ok) {
        const data = await resp.json();
        if (data.rates?.[to]) {
          rateData = JSON.stringify({
            rate: data.rates[to],
            timestamp: Math.floor(Date.now() / 1000),
            source: 'Frankfurter',
          });
        }
      }
    } catch (e) { /* 전부 실패 */ }
  }

  if (!rateData) {
    return jsonError('All exchange rate sources failed', 502, request);
  }

  // KV + Cache API 동시 저장
  await setCached(env, kvKey, cacheTTL, cacheKey, cacheTTL, rateData);

  return new Response(rateData, {
    status: 200,
    headers: {
      'Content-Type': 'application/json',
      'Cache-Control': `public, max-age=${cacheTTL}`,
      'X-Cache': 'MISS',
      ...corsHeaders(request),
    },
  });
}
