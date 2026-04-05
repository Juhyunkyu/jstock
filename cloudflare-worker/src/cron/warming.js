/**
 * Cron 캐시 워밍
 *
 * 스케줄:
 *   0 13 * * 1-5  — Pre-market (KST 22:00, 미국 개장 전)
 *   0 21 * * 1-5  — Post-market (KST 06:00, 미국 폐장 후)
 *   0 12 * * 0    — Weekend (KST 21:00, 주말 갱신)
 *
 * 워밍 대상:
 *   - Finnhub quotes (100 tickers, 10개씩 배치)
 *   - FMP profiles (신규/만료만)
 *   - Global data (Fear&Greed, 환율, FRED)
 */

function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

function getCronType(cron) {
  if (cron.includes('13') && cron.includes('1-5')) return 'pre-market';
  if (cron.includes('21') && cron.includes('1-5')) return 'post-market';
  if (cron.includes('SUN') || cron.includes('0 12')) return 'weekend';
  return 'weekend';
}

export async function runCacheWarming(event, env) {
  const cronType = getCronType(event.cron);
  const startTime = Date.now();
  console.log(`[Cron] Cache warming started: ${cronType}`);

  // 1. 인기 종목 리스트 조회
  let tickers;
  try {
    tickers = await env.CACHE_KV.get('warm:tickers', 'json');
  } catch (e) {
    console.error('[Cron] Failed to read tickers from KV:', e.message);
    return;
  }
  if (!tickers || !Array.isArray(tickers)) {
    console.error('[Cron] No tickers found in KV');
    return;
  }

  // 2. Finnhub 시세 워밍 (주말 제외)
  if (cronType !== 'weekend') {
    await warmFinnhubQuotes(env, tickers);
  }

  // 3. FMP 프로필 워밍 (post-market 또는 주말)
  if (cronType === 'weekend' || cronType === 'post-market') {
    await warmFMPProfiles(env, tickers);
  }

  // 4. 글로벌 데이터 워밍 (항상)
  await warmGlobalData(env);

  // 5. 워밍 완료 기록
  try {
    await env.CACHE_KV.put('warm:last_run', JSON.stringify({
      type: cronType,
      timestamp: new Date().toISOString(),
      duration_ms: Date.now() - startTime,
      tickers_count: tickers.length,
    }));
  } catch (e) { /* 기록 실패 무시 */ }

  console.log(`[Cron] Cache warming completed in ${Date.now() - startTime}ms`);
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

async function warmFMPProfiles(env, tickers) {
  const apiKey = env.FMP_API_KEY;
  if (!apiKey) {
    console.error('[Cron] FMP_API_KEY not set, skipping profiles');
    return;
  }

  // KV에 이미 있으면 건너뜀 (TTL 자동 만료)
  const tickersToWarm = [];
  for (const symbol of tickers) {
    try {
      const existing = await env.CACHE_KV.get(`fmp_profile:${symbol}`);
      if (!existing) tickersToWarm.push(symbol);
    } catch (e) {
      tickersToWarm.push(symbol); // KV 에러 시 워밍 시도
    }
  }

  if (tickersToWarm.length === 0) {
    console.log('[Cron] All FMP profiles cached, skipping');
    return;
  }

  // 5개씩 배치, 배치 간 1초 대기
  const batchSize = 5;
  let totalSuccess = 0;

  for (let i = 0; i < tickersToWarm.length; i += batchSize) {
    const batch = tickersToWarm.slice(i, i + batchSize);

    const results = await Promise.allSettled(
      batch.map(async (symbol) => {
        const resp = await fetch(
          `https://financialmodelingprep.com/stable/profile?symbol=${encodeURIComponent(symbol)}&apikey=${apiKey}`
        );
        if (!resp.ok) throw new Error(`HTTP ${resp.status}`);
        const data = await resp.text();

        await env.CACHE_KV.put(`fmp_profile:${symbol}`, data, {
          expirationTtl: 604800, // 7일
        });
        return symbol;
      })
    );

    totalSuccess += results.filter(r => r.status === 'fulfilled').length;

    if (i + batchSize < tickersToWarm.length) {
      await sleep(1000);
    }
  }

  console.log(`[Cron] FMP profiles warmed: ${totalSuccess}/${tickersToWarm.length}`);
}

async function warmGlobalData(env) {
  // Fear & Greed Index
  try {
    const fgResp = await fetch(
      'https://production.dataviz.cnn.io/index/fearandgreed/graphdata/',
      {
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          'Referer': 'https://edition.cnn.com/',
        },
      }
    );
    if (fgResp.ok) {
      const data = await fgResp.text();
      await env.CACHE_KV.put('fear_greed:latest', data, { expirationTtl: 3600 });
      console.log('[Cron] Fear & Greed warmed');
    }
  } catch (e) { console.error('[Cron] Fear & Greed warming failed:', e.message); }

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
