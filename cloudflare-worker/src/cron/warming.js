/**
 * Cron 캐시 워밍
 *
 * 스케줄:
 *   0 13 * * 1-5  — Pre-market (KST 22:00, 미국 개장 전)
 *   0 22 * * 1-5  — Post-market (KST 07:00, 미국 폐장 후)
 *   0 12 * * SUN  — Weekend (KST 21:00, 주말 갱신)
 *
 * 워밍 대상:
 *   - Finnhub quotes (고정 + 동적 티커, 10개씩 배치)
 *   - Global data (Fear&Greed, 환율, FRED)
 *
 * 동적 티커 병합:
 *   - `hit:<SYMBOL>` KV 키로 사용자 조회 횟수 추적 (index.js에서 기록)
 *   - 주말 Cron 시 상위 50개를 고정 워밍 리스트에 병합
 *   - 병합 후 히트 카운터 초기화 (7일 TTL이지만 주말에 명시적 리셋)
 *   - 동적 리스트는 `warm:dynamic_tickers`에 별도 저장 (디버깅용)
 *
 * NOTE: FMP profiles are cached on-demand only (250/day limit).
 */

import { warmCalendarData } from '../handlers/calendar.js';
import { fetchFearGreed } from '../lib/fearGreed.js';

function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

function getCronType(cron) {
  if (cron.includes('13') && cron.includes('1-5')) return 'pre-market';
  if (cron.includes('22') && cron.includes('1-5')) return 'post-market';
  if (cron.includes('SUN') || cron.includes('0 12')) return 'weekend';
  return 'weekend';
}

/**
 * 동적 티커 병합 — 히트 카운터 기반 상위 50개를 고정 리스트에 합침
 * @param {object} env - Worker 환경 바인딩
 * @param {string[]} fixedTickers - KV `warm:tickers`에 저장된 고정 종목 리스트
 * @param {boolean} resetCounters - true이면 히트 카운터 초기화 (주말 전용)
 * @returns {Promise<{merged: string[], dynamicCount: number}>}
 */
async function getDynamicTickers(env, fixedTickers, resetCounters = false) {
  // KV list는 페이지네이션 가능 — cursor로 전체 조회
  let allKeys = [];
  let cursor = undefined;
  try {
    do {
      const listed = await env.CACHE_KV.list({ prefix: 'hit:', cursor });
      allKeys = allKeys.concat(listed.keys);
      cursor = listed.list_complete ? undefined : listed.cursor;
    } while (cursor);
  } catch (e) {
    console.error('[Cron] Failed to list hit keys:', e.message);
    return { merged: fixedTickers, dynamicCount: 0 };
  }

  if (!allKeys.length) {
    return { merged: fixedTickers, dynamicCount: 0 };
  }

  // 카운트 읽기 (병렬)
  const counts = await Promise.allSettled(
    allKeys.map(async (key) => {
      const count = parseInt(await env.CACHE_KV.get(key.name) || '0');
      return { symbol: key.name.replace('hit:', ''), count };
    })
  );

  // 상위 50개 추출
  const topDynamic = counts
    .filter(r => r.status === 'fulfilled')
    .map(r => r.value)
    .sort((a, b) => b.count - a.count)
    .slice(0, 50)
    .map(r => r.symbol);

  // 고정 리스트와 병합 (중복 제거)
  const fixedSet = new Set(fixedTickers);
  const merged = [...fixedTickers];
  for (const symbol of topDynamic) {
    if (!fixedSet.has(symbol)) {
      merged.push(symbol);
    }
  }

  // 동적 리스트 저장 (디버깅/참조용)
  try {
    await env.CACHE_KV.put('warm:dynamic_tickers', JSON.stringify(topDynamic));
  } catch (e) { /* 저장 실패 무시 */ }

  // 주말에만 히트 카운터 초기화
  if (resetCounters) {
    console.log(`[Cron] Resetting ${allKeys.length} hit counters`);
    await Promise.allSettled(
      allKeys.map(key => env.CACHE_KV.delete(key.name))
    );
  }

  console.log(`[Cron] Dynamic tickers: ${topDynamic.length} found, ${merged.length - fixedTickers.length} new merged`);
  return { merged, dynamicCount: topDynamic.length };
}

export async function runCacheWarming(event, env) {
  const cronType = getCronType(event.cron);
  const startTime = Date.now();
  console.log(`[Cron] Cache warming started: ${cronType}`);

  // 1. 고정 종목 리스트 조회
  let fixedTickers;
  try {
    fixedTickers = await env.CACHE_KV.get('warm:tickers', 'json');
  } catch (e) {
    console.error('[Cron] Failed to read tickers from KV:', e.message);
    return;
  }
  if (!fixedTickers || !Array.isArray(fixedTickers)) {
    console.error('[Cron] No tickers found in KV');
    return;
  }

  // 2. 동적 티커 병합 (주말이면 카운터 리셋)
  const isWeekend = cronType === 'weekend';
  const { merged: tickers, dynamicCount } = await getDynamicTickers(env, fixedTickers, isWeekend);

  // 3~4. 워밍 병렬 실행 (각각 다른 API를 호출하므로 동시 실행 안전)
  await Promise.all([
    !isWeekend ? warmFinnhubQuotes(env, tickers) : Promise.resolve(),
    warmGlobalData(env),
    warmCalendarData(env, cronType),
  ]);

  // 5. 워밍 완료 기록
  try {
    await env.CACHE_KV.put('warm:last_run', JSON.stringify({
      type: cronType,
      timestamp: new Date().toISOString(),
      duration_ms: Date.now() - startTime,
      fixed_count: fixedTickers.length,
      dynamic_count: dynamicCount,
      tickers_count: tickers.length,
    }));
  } catch (e) { /* 기록 실패 무시 */ }

  console.log(`[Cron] Cache warming completed in ${Date.now() - startTime}ms (${tickers.length} tickers)`);
}

async function warmFinnhubQuotes(env, tickers) {
  const apiKey = env.FINNHUB_API_KEY;
  if (!apiKey) {
    console.error('[Cron] FINNHUB_API_KEY not set, skipping quotes');
    return;
  }

  const batchSize = 10;
  const delayBetweenBatches = 2000; // 2초 (10 calls → 60/min 안전)
  let totalSuccess = 0;

  for (let i = 0; i < tickers.length; i += batchSize) {
    const batch = tickers.slice(i, i + batchSize);

    const results = await Promise.allSettled(
      batch.map(async (symbol) => {
        const resp = await fetch(
          `https://finnhub.io/api/v1/quote?symbol=${encodeURIComponent(symbol)}&token=${apiKey}`
        );
        if (!resp.ok) throw new Error(`HTTP ${resp.status}`);
        const data = await resp.json();

        // KV에 저장 (16시간 TTL — 다음 Cron까지 유지)
        await env.CACHE_KV.put(
          `quote:${symbol}`,
          JSON.stringify({ ...data, _cachedAt: new Date().toISOString() }),
          { expirationTtl: 57600 }
        );
        return symbol;
      })
    );

    const succeeded = results.filter(r => r.status === 'fulfilled').length;
    totalSuccess += succeeded;
    console.log(`[Cron] Finnhub quotes batch ${Math.floor(i / batchSize) + 1}: ${succeeded}/${batch.length}`);

    // 다음 배치 전 대기 (마지막 배치 제외)
    if (i + batchSize < tickers.length) {
      await sleep(delayBetweenBatches);
    }
  }

  console.log(`[Cron] Finnhub quotes total: ${totalSuccess}/${tickers.length}`);
}

async function warmGlobalData(env) {
  // Fear & Greed Index — helper writes both `fear_greed:latest` (6h TTL) and `fear_greed:last_known` (no TTL).
  const fg = await fetchFearGreed(env);
  console.log(`[Cron] Fear & Greed warmed: source=${fg.source} score=${fg.score ?? 'null'}`);

  // Exchange Rate USD/KRW (Twelve Data)
  if (env.TWELVE_DATA_API_KEY) {
    try {
      const erResp = await fetch(
        `https://api.twelvedata.com/exchange_rate?symbol=USD/KRW&apikey=${env.TWELVE_DATA_API_KEY}`
      );
      if (erResp.ok) {
        const data = await erResp.json();
        if (data.rate) {
          await env.CACHE_KV.put('exchange_rate:USD_KRW', JSON.stringify({
            rate: parseFloat(data.rate),
            timestamp: data.timestamp || Math.floor(Date.now() / 1000),
            source: 'Twelve Data',
          }), { expirationTtl: 600 });
          console.log('[Cron] Exchange rate warmed');
        }
      }
    } catch (e) { console.error('[Cron] Exchange rate warming failed:', e.message); }
  }

  // FRED 지표 (WTI, 10Y)
  if (env.FRED_API_KEY) {
    for (const seriesId of ['DCOILWTICO', 'DGS10']) {
      try {
        const fredResp = await fetch(
          `https://api.stlouisfed.org/fred/series/observations?series_id=${seriesId}&file_type=json&sort_order=desc&limit=5&api_key=${env.FRED_API_KEY}`
        );
        if (fredResp.ok) {
          const data = await fredResp.text();
          await env.CACHE_KV.put(`global:${seriesId}`, data, { expirationTtl: 3600 });
          console.log(`[Cron] FRED ${seriesId} warmed`);
        }
      } catch (e) { console.error(`[Cron] FRED ${seriesId} warming failed:`, e.message); }
    }
  }
}
