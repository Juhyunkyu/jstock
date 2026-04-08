/**
 * 경제 캘린더 + 실적 캘린더 핸들러
 *
 * 엔드포인트:
 *   GET /api/calendar/economic?from=YYYY-MM-DD&to=YYYY-MM-DD
 *     → FRED release dates + TradingView forecast/previous + FOMC 병합
 *
 *   GET /api/calendar/earnings?from=YYYY-MM-DD&to=YYYY-MM-DD&symbols=NVDA,TSLA
 *     → Finnhub earnings calendar 프록시
 *
 * 캐시 전략:
 *   calendar:fred_dates:RELEASE_ID  → KV 30일
 *   calendar:tv_events:FROM_TO      → KV 24시간
 *   calendar:earnings:YYYY-MM       → KV 7일
 */

import { corsHeaders } from '../utils/cors.js';
import { jsonError } from '../utils/helpers.js';

// ── FRED Release ID 매핑 ──

const FRED_RELEASES = [
  { id: 10, title: 'CPI 소비자물가지수', titleEn: 'Consumer Price Index', category: 'inflation', unit: '%' },
  { id: 50, title: '고용보고서', titleEn: 'Employment Situation', category: 'employment', unit: 'K' },
  { id: 53, title: 'GDP 성장률', titleEn: 'GDP Growth Rate', category: 'gdp', unit: '%' },
  { id: 46, title: 'PPI 생산자물가지수', titleEn: 'Producer Price Index', category: 'inflation', unit: '%' },
  { id: 9, title: '소매판매', titleEn: 'Retail Sales', category: 'other', unit: '%' },
  { id: 54, title: 'PCE 개인소비지출', titleEn: 'Personal Consumption Expenditures', category: 'inflation', unit: '%' },
];

const FRED_RELEASE_MAP = Object.fromEntries(FRED_RELEASES.map(r => [r.id, r]));

// ── FOMC 2026 일정 (연 1회 수동 업데이트) ──

const FOMC_DATES_2026 = [
  '2026-01-28', '2026-03-18', '2026-05-06', '2026-06-17',
  '2026-07-29', '2026-09-16', '2026-11-04', '2026-12-16',
];

// ── TradingView → FRED 매칭 키워드 ──

const TV_MATCH_KEYWORDS = {
  10: ['cpi', 'consumer price'],
  50: ['nonfarm', 'non-farm', 'employment situation', 'payroll'],
  53: ['gdp', 'gross domestic'],
  46: ['ppi', 'producer price'],
  9: ['retail sales'],
  54: ['pce', 'personal consumption', 'core pce'],
};

// ── 라우터 ──

export async function handleCalendar(request, env, url) {
  if (request.method !== 'GET') {
    return jsonError('GET only', 405, request);
  }

  const subPath = url.pathname.replace('/api/calendar/', '');

  if (subPath === 'economic' || subPath.startsWith('economic?')) {
    return handleEconomicCalendar(request, env, url);
  }
  if (subPath === 'earnings' || subPath.startsWith('earnings?')) {
    return handleEarningsCalendar(request, env, url);
  }

  return jsonError('Not found', 404, request);
}

// ── JSON 응답 헬퍼 ──

function jsonResponse(data, request, cacheControl = 'public, max-age=1800') {
  return new Response(JSON.stringify(data), {
    status: 200,
    headers: {
      'Content-Type': 'application/json',
      'Cache-Control': cacheControl,
      ...corsHeaders(request),
    },
  });
}

// ════════════════════════════════════════════════════
// 경제 캘린더 (FRED + TradingView + FOMC)
// ════════════════════════════════════════════════════

async function handleEconomicCalendar(request, env, url) {
  const from = url.searchParams.get('from');
  const to = url.searchParams.get('to');

  if (!from || !to) {
    return jsonError('Missing required params: from, to (YYYY-MM-DD)', 400, request);
  }

  // 1. FRED release dates (병렬, 개별 캐시)
  const fredResults = await Promise.allSettled(
    FRED_RELEASES.map(rel => fetchFredReleaseDates(env, rel, from, to))
  );
  const fredEvents = fredResults
    .filter(r => r.status === 'fulfilled')
    .flatMap(r => r.value);

  // 2. TradingView events (forecast/previous 보강용)
  const tvEvents = await fetchTradingViewEvents(env, from, to);

  // 3. FRED 이벤트에 TradingView forecast/previous 병합
  const mergedEvents = mergeFredWithTradingView(fredEvents, tvEvents);

  // 4. FOMC 일정 추가 (from~to 범위 내)
  const fomcEvents = buildFomcEvents(from, to);

  // 5. TradingView 중 FRED에 매칭 안 된 고중요도 이벤트 추가 (from~to 범위 필터)
  const unmatchedTvEvents = buildUnmatchedTvEvents(tvEvents, fredEvents, from, to);

  // 6. 합치고 날짜순 정렬
  const liveEvents = [...mergedEvents, ...fomcEvents, ...unmatchedTvEvents]
    .sort((a, b) => a.date.localeCompare(b.date));

  // 7. 오늘 기준 과거 이벤트 → KV에 날짜별 영구 저장 (1년 TTL)
  //    TradingView가 과거 이벤트를 삭제하므로, 매일 그날의 이벤트를 보존
  // 8. API에 없는 과거 날짜 → KV에서 복원하여 합침
  const allEvents = await syncAndRestoreEvents(env, liveEvents, from, to);

  return jsonResponse(allEvents, request);
}

// ── FRED Release Dates 조회 (개별 KV 캐시, 30일 TTL) ──

async function fetchFredReleaseDates(env, release, from, to) {
  const kvKey = `calendar:fred_dates:${release.id}`;

  // KV 캐시 확인
  try {
    const cached = await env.CACHE_KV.get(kvKey, 'json');
    if (cached) {
      // 캐시된 전체 목록에서 from~to 범위 필터
      return cached.filter(e => e.date >= `${from}T00:00:00.000Z` && e.date <= `${to}T23:59:59.999Z`);
    }
  } catch (e) {
    console.error(`[Calendar] KV read failed for ${kvKey}:`, e.message);
  }

  const apiKey = env.FRED_API_KEY;
  if (!apiKey) {
    console.error('[Calendar] FRED_API_KEY not configured');
    return [];
  }

  try {
    const resp = await fetch(
      `https://api.stlouisfed.org/fred/release/dates?release_id=${release.id}` +
      `&api_key=${apiKey}&file_type=json&sort_order=desc` +
      `&include_release_dates_with_no_data=true&limit=24`
    );
    if (!resp.ok) {
      console.error(`[Calendar] FRED release ${release.id} HTTP ${resp.status}`);
      return [];
    }

    const data = await resp.json();
    const dates = (data.release_dates || []).map(d => ({
      id: `fred-${release.id}-${d.date}`,
      title: release.title,
      titleEn: release.titleEn,
      date: `${d.date}T00:00:00.000Z`,
      category: release.category,
      forecast: null,
      previous: null,
      actual: null,
      unit: release.unit,
      importance: 2,
    }));

    // KV 저장 (30일 TTL)
    try {
      await env.CACHE_KV.put(kvKey, JSON.stringify(dates), { expirationTtl: 2592000 });
    } catch (e) {
      console.error(`[Calendar] KV write failed for ${kvKey}:`, e.message);
    }

    // from~to 범위 필터
    return dates.filter(e => e.date >= `${from}T00:00:00.000Z` && e.date <= `${to}T23:59:59.999Z`);
  } catch (e) {
    console.error(`[Calendar] FRED release ${release.id} fetch failed:`, e.message);
    return [];
  }
}

// ── TradingView Economic Calendar 조회 (KV 캐시, 4시간 TTL / 오늘 포함 시 캐시 무시) ──

async function fetchTradingViewEvents(env, from, to) {
  const kvKey = `calendar:tv_events:${from}_${to}`;

  // 오늘 날짜가 요청 범위에 포함되면 캐시 건너뜀 (actual 값 즉시 반영)
  const today = new Date().toISOString().substring(0, 10);
  const todayInRange = from <= today && to >= today;

  // KV 캐시 확인 (오늘 포함 시 건너뜀)
  if (!todayInRange) {
    try {
      const cached = await env.CACHE_KV.get(kvKey, 'json');
      if (cached) return cached;
    } catch (e) {
      console.error(`[Calendar] KV read failed for ${kvKey}:`, e.message);
    }
  }

  try {
    const resp = await fetch('https://economic-calendar.tradingview.com/events', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Origin': 'https://www.tradingview.com',
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      },
      body: JSON.stringify({
        from: `${from}T00:00:00.000Z`,
        to: `${to}T00:00:00.000Z`,
        countries: ['US'],
      }),
    });

    if (!resp.ok) {
      console.error(`[Calendar] TradingView HTTP ${resp.status}`);
      return [];
    }

    const data = await resp.json();
    // US 이벤트 중 forecast/previous가 있는 이벤트는 importance 무관 포함
    const filtered = (data.result || data || []).filter(
      e => e.country === 'US' && (
        (e.importance == null || e.importance >= 0) ||
        e.forecast != null || e.previous != null
      )
    );

    // KV 저장 (4시간 TTL — actual 값 빠른 갱신을 위해)
    try {
      await env.CACHE_KV.put(kvKey, JSON.stringify(filtered), { expirationTtl: 14400 });
    } catch (e) {
      console.error(`[Calendar] KV write failed for ${kvKey}:`, e.message);
    }

    return filtered;
  } catch (e) {
    console.error('[Calendar] TradingView fetch failed:', e.message);
    return []; // TradingView 실패 시 FRED 날짜만으로 동작
  }
}

// ── 이벤트 영구 저장 & 과거 복원 (1년 TTL) ──
//
// TradingView는 과거 이벤트를 빠르게 삭제 (당일~1일 후 사라짐).
// 매일 해당 날짜의 전체 이벤트 목록을 KV에 보존하면,
// 과거로 스크롤해도 어떤 발표가 있었고 결과가 어땠는지 확인 가능.
//
// 저장 단위: calendar:day:YYYY-MM-DD → 해당 날짜의 이벤트 배열 (1년 TTL)
// 복원: from~to 범위 중 API 응답에 없는 과거 날짜 → KV에서 복원

async function syncAndRestoreEvents(env, liveEvents, from, to) {
  const today = new Date().toISOString().substring(0, 10);

  // ── 1. 현재 API 응답의 이벤트를 날짜별로 KV에 저장 ──
  // 오늘 이전 날짜 + 오늘 날짜의 이벤트를 보존 (미래는 변동 가능하므로 저장 안 함)
  const byDate = {};
  for (const e of liveEvents) {
    const d = (e.date || '').substring(0, 10);
    if (d <= today) {
      (byDate[d] ??= []).push(e);
    }
  }

  // 날짜별 KV 저장 (기존 데이터와 병합)
  const datesToSave = Object.keys(byDate);
  if (datesToSave.length > 0) {
    // 기존 저장된 데이터 읽기
    const existingResults = await Promise.allSettled(
      datesToSave.map(d => env.CACHE_KV.get(`calendar:day:${d}`, 'json'))
    );

    const writeTasks = [];
    for (let i = 0; i < datesToSave.length; i++) {
      const dateKey = datesToSave[i];
      const newEvents = byDate[dateKey];
      const existing = existingResults[i].status === 'fulfilled' ? existingResults[i].value : null;

      // 기존 저장 이벤트와 새 이벤트 병합 (id 기준 dedup, 새 데이터 우선)
      let merged;
      if (existing && Array.isArray(existing)) {
        const byId = new Map();
        for (const e of existing) byId.set(e.id, e);
        for (const e of newEvents) byId.set(e.id, e); // 새 데이터가 덮어쓰기
        merged = [...byId.values()];
      } else {
        merged = newEvents;
      }

      writeTasks.push(
        env.CACHE_KV.put(`calendar:day:${dateKey}`, JSON.stringify(merged), { expirationTtl: 31536000 })
          .catch(err => console.error(`[Calendar] Day save failed for ${dateKey}:`, err.message))
      );
    }
    if (writeTasks.length > 0) {
      await Promise.allSettled(writeTasks);
    }
  }

  // ── 2. API 응답에 없는 과거 날짜 → KV에서 복원 ──
  // from~어제까지의 날짜 중 liveEvents에 없는 날짜를 찾아 KV에서 가져옴
  const liveDates = new Set(liveEvents.map(e => (e.date || '').substring(0, 10)));
  const yesterday = new Date(Date.now() - 86400000).toISOString().substring(0, 10);
  const restoreEnd = yesterday < to ? yesterday : to; // 어제까지만 복원

  // from~restoreEnd 범위의 날짜 생성
  const missingDates = [];
  const d = new Date(from + 'T00:00:00Z');
  const endD = new Date(restoreEnd + 'T00:00:00Z');
  while (d <= endD) {
    const ds = d.toISOString().substring(0, 10);
    if (!liveDates.has(ds)) {
      missingDates.push(ds);
    }
    d.setUTCDate(d.getUTCDate() + 1);
  }

  // 빠진 날짜를 KV에서 복원 (최대 90일분, 너무 많으면 성능 이슈)
  let restoredEvents = [];
  const datesToRestore = missingDates.slice(-90); // 최근 90일 우선
  if (datesToRestore.length > 0) {
    const results = await Promise.allSettled(
      datesToRestore.map(d => env.CACHE_KV.get(`calendar:day:${d}`, 'json'))
    );
    for (const result of results) {
      if (result.status === 'fulfilled' && result.value && Array.isArray(result.value)) {
        restoredEvents.push(...result.value);
      }
    }
  }

  // ── 3. live + restored 합치고 정렬 ──
  const allEvents = [...liveEvents, ...restoredEvents]
    .sort((a, b) => a.date.localeCompare(b.date));

  return allEvents;
}

// ── FRED + TradingView 병합 ──

function mergeFredWithTradingView(fredEvents, tvEvents) {
  if (!tvEvents.length) return fredEvents;

  const today = new Date().toISOString().substring(0, 10);

  return fredEvents.map(fredEvent => {
    // FRED release ID로 TradingView 키워드 매칭
    const releaseId = parseInt(fredEvent.id.split('-')[1]);
    const keywords = TV_MATCH_KEYWORDS[releaseId] || [];
    if (!keywords.length) return fredEvent;

    const fredDateStr = fredEvent.date.substring(0, 10); // YYYY-MM-DD

    // 1차: 같은 날짜 + 키워드 매칭
    let matched = tvEvents.find(tv => {
      const tvDateStr = (tv.date || '').substring(0, 10);
      if (tvDateStr !== fredDateStr) return false;
      const tvTitle = (tv.title || '').toLowerCase();
      return keywords.some(kw => tvTitle.includes(kw));
    });

    // 2차: 날짜 매칭 실패 시, 오늘/과거 이벤트에 한해 키워드만으로 매칭
    // (TradingView가 미래 날짜 데이터를 제공하지 않는 경우 대비)
    if (!matched && fredDateStr <= today) {
      matched = tvEvents.find(tv => {
        const tvTitle = (tv.title || '').toLowerCase();
        return keywords.some(kw => tvTitle.includes(kw)) &&
               (tv.forecast != null || tv.previous != null);
      });
    }

    if (matched) {
      return {
        ...fredEvent,
        forecast: matched.forecast ?? null,
        previous: matched.previous ?? null,
        actual: matched.actual ?? null,
        // TradingView importance가 더 세밀하면 반영 (3 = high)
        importance: matched.importance >= 3 ? 3 : fredEvent.importance,
      };
    }

    return fredEvent;
  });
}

// ── FOMC 일정 생성 (from~to 범위 필터) ──

function buildFomcEvents(from, to) {
  return FOMC_DATES_2026
    .filter(d => d >= from && d <= to)
    .map(d => ({
      id: `fomc-${d}`,
      title: 'FOMC 금리 결정',
      titleEn: 'FOMC Rate Decision',
      date: `${d}T00:00:00.000Z`,
      category: 'fomc',
      forecast: null,
      previous: null,
      actual: null,
      unit: '%',
      importance: 3,
    }));
}

// ── TradingView 중 FRED에 매칭 안 된 고중요도(importance >= 2) 이벤트 ──

function buildUnmatchedTvEvents(tvEvents, fredEvents, from, to) {
  if (!tvEvents.length) return [];

  const allKeywords = Object.values(TV_MATCH_KEYWORDS).flat();
  const fromDate = `${from}T00:00:00.000Z`;
  const toDate = `${to}T23:59:59.999Z`;

  return tvEvents
    .filter(tv => {
      // 요청 범위 밖 이벤트 제외 (TV API가 범위 밖 데이터를 반환하는 경우 대비)
      const tvDate = tv.date || '';
      if (tvDate < fromDate || tvDate > toDate) return false;
      const tvTitle = (tv.title || '').toLowerCase();
      const isFredMatched = allKeywords.some(kw => tvTitle.includes(kw));
      if (isFredMatched) return false;
      return (tv.importance || 0) >= 2 ||
             tv.forecast != null || tv.previous != null;
    })
    .map(tv => ({
      id: `tv-${(tv.date || '').substring(0, 10)}-${(tv.title || '').replace(/\s+/g, '_').substring(0, 30)}`,
      title: tv.title || '',
      titleEn: tv.title || '',
      date: tv.date || '',
      category: mapTvCategory(tv.category),
      forecast: tv.forecast ?? null,
      previous: tv.previous ?? null,
      actual: tv.actual ?? null,
      unit: '',
      importance: tv.importance >= 3 ? 3 : 2,
    }));
}

function mapTvCategory(tvCategory) {
  if (!tvCategory) return 'other';
  const cat = tvCategory.toLowerCase();
  if (cat.includes('price') || cat.includes('inflation')) return 'inflation';
  if (cat.includes('employ') || cat.includes('labor')) return 'employment';
  if (cat.includes('gdp') || cat.includes('growth')) return 'gdp';
  return 'other';
}

// ════════════════════════════════════════════════════
// 실적 캘린더 (Finnhub Earnings)
// ════════════════════════════════════════════════════

async function handleEarningsCalendar(request, env, url) {
  const from = url.searchParams.get('from');
  const to = url.searchParams.get('to');
  const symbolsParam = url.searchParams.get('symbols');

  if (!from || !to) {
    return jsonError('Missing required params: from, to (YYYY-MM-DD)', 400, request);
  }

  const apiKey = env.FINNHUB_API_KEY;
  if (!apiKey) return jsonError('FINNHUB_API_KEY not configured', 500, request);

  // KV 캐시 키 (월 단위)
  const monthKey = from.substring(0, 7); // YYYY-MM
  const kvKey = `calendar:earnings:${monthKey}`;

  // 1. KV 캐시 확인 (symbols 없을 때만 — symbols 있으면 항상 fresh)
  if (!symbolsParam) {
    try {
      const cached = await env.CACHE_KV.get(kvKey, 'json');
      if (cached) {
        // from~to 범위 필터
        const filtered = cached.filter(e => {
          const d = e.date.substring(0, 10);
          return d >= from && d <= to;
        });
        return jsonResponse(filtered, request);
      }
    } catch (e) {
      console.error(`[Calendar] KV read failed for ${kvKey}:`, e.message);
    }
  }

  // 2. Finnhub API 호출
  try {
    const fetchPromises = [];

    // 기본: 전체 earnings calendar
    fetchPromises.push(
      fetch(`https://finnhub.io/api/v1/calendar/earnings?from=${from}&to=${to}&token=${apiKey}`)
        .then(r => r.ok ? r.json() : null)
        .catch(() => null)
    );

    // symbols 파라미터가 있으면 개별 심볼도 조회
    if (symbolsParam) {
      const symbols = symbolsParam.split(',').map(s => s.trim().toUpperCase()).filter(Boolean);
      for (const symbol of symbols.slice(0, 20)) { // 최대 20개 제한
        fetchPromises.push(
          fetch(`https://finnhub.io/api/v1/calendar/earnings?from=${from}&to=${to}&symbol=${symbol}&token=${apiKey}`)
            .then(r => r.ok ? r.json() : null)
            .catch(() => null)
        );
      }
    }

    const results = await Promise.allSettled(fetchPromises);
    const allEarnings = new Map(); // symbol+date → event (중복 제거)

    for (const result of results) {
      if (result.status !== 'fulfilled' || !result.value) continue;
      const data = result.value;
      const calendar = data.earningsCalendar || [];
      for (const item of calendar) {
        const key = `${item.symbol}-${item.date}`;
        if (!allEarnings.has(key)) {
          allEarnings.set(key, item);
        }
      }
    }

    // 3. 응답 형식 매핑
    const events = Array.from(allEarnings.values()).map(item => ({
      id: `earn-${item.symbol}-${item.date}`,
      title: `${item.symbol} 실적 발표`,
      titleEn: `${item.symbol} Earnings`,
      date: `${item.date}T00:00:00.000Z`,
      category: 'earnings',
      forecast: item.epsEstimate ?? null,
      previous: null,
      actual: item.epsActual ?? null,
      unit: 'EPS',
      importance: 2,
      ticker: item.symbol,
      hour: item.hour || null,
      revenueEstimate: item.revenueEstimate ?? null,
    })).sort((a, b) => a.date.localeCompare(b.date));

    // 4. KV 저장 (symbols 없을 때만 — 전체 캘린더, 7일 TTL)
    if (!symbolsParam) {
      try {
        await env.CACHE_KV.put(kvKey, JSON.stringify(events), { expirationTtl: 604800 });
      } catch (e) {
        console.error(`[Calendar] KV write failed for ${kvKey}:`, e.message);
      }
    }

    return jsonResponse(events, request);
  } catch (e) {
    console.error('[Calendar] Finnhub earnings fetch failed:', e.message);
    return jsonError(`Earnings calendar error: ${e.message}`, 502, request);
  }
}

// ════════════════════════════════════════════════════
// Cron 워밍용 — 외부에서 호출 가능하도록 export
// ════════════════════════════════════════════════════

/**
 * 캘린더 데이터 워밍 (Cron에서 호출)
 * @param {object} env - Worker 환경 바인딩
 * @param {string} cronType - 'pre-market' | 'post-market' | 'weekend'
 */
export async function warmCalendarData(env, cronType) {
  const now = new Date();
  const today = now.toISOString().substring(0, 10);

  // 이번 주 시작(월)~끝(일) 계산
  const dayOfWeek = now.getDay(); // 0=Sun
  const monday = new Date(now);
  monday.setDate(now.getDate() - ((dayOfWeek + 6) % 7));
  const sunday = new Date(monday);
  sunday.setDate(monday.getDate() + 6);

  const weekFrom = monday.toISOString().substring(0, 10);
  const weekTo = sunday.toISOString().substring(0, 10);

  if (cronType === 'pre-market' || cronType === 'post-market') {
    // 평일: TradingView 이벤트 (이번 주) — forecast 값 갱신
    try {
      await fetchTradingViewEvents(env, weekFrom, weekTo);
      console.log('[Cron] Calendar: TradingView events warmed (this week)');
    } catch (e) {
      console.error('[Cron] Calendar: TradingView warming failed:', e.message);
    }
  }

  if (cronType === 'weekend') {
    // 주말: FRED release dates (3개월 분) + TradingView (2주)
    try {
      // FRED: 각 Release ID별 워밍
      const threeMonthsLater = new Date(now);
      threeMonthsLater.setMonth(now.getMonth() + 3);
      const fredFrom = today;
      const fredTo = threeMonthsLater.toISOString().substring(0, 10);

      await Promise.allSettled(
        FRED_RELEASES.map(rel => fetchFredReleaseDates(env, rel, fredFrom, fredTo))
      );
      console.log('[Cron] Calendar: FRED release dates warmed (3 months)');
    } catch (e) {
      console.error('[Cron] Calendar: FRED warming failed:', e.message);
    }

    try {
      // TradingView: 2주분
      const twoWeeksLater = new Date(now);
      twoWeeksLater.setDate(now.getDate() + 14);
      const tvTo = twoWeeksLater.toISOString().substring(0, 10);

      await fetchTradingViewEvents(env, today, tvTo);
      console.log('[Cron] Calendar: TradingView events warmed (2 weeks)');
    } catch (e) {
      console.error('[Cron] Calendar: TradingView warming failed:', e.message);
    }
  }
}
