/**
 * 경제 캘린더 + 실적 캘린더 핸들러 (V2)
 *
 * 엔드포인트:
 *   GET /api/calendar/economic?from=YYYY-MM-DD&to=YYYY-MM-DD
 *     → FRED 10개 핵심 지표 + TV forecast 매칭 + NYSE 휴장일 + 네 마녀의 날
 *
 *   GET /api/calendar/earnings?from=YYYY-MM-DD&to=YYYY-MM-DD&symbols=NVDA,TSLA
 *     → Finnhub earnings calendar 프록시 (주요 25개 + 관심종목)
 *
 * 캐시 전략:
 *   calendar:fred_dates:RELEASE_ID   → KV 30일
 *   calendar:fred_series:SERIES_ID   → KV 24시간 (오늘 포함 시 바이패스)
 *   calendar:tv_events:FROM_TO       → KV 4시간 (오늘 포함 시 바이패스)
 *   calendar:earnings:YYYY-MM        → KV 7일
 */

import { corsHeaders } from '../utils/cors.js';
import { jsonError } from '../utils/helpers.js';
import { getCached, setCached } from '../utils/cache.js';

// ── FRED Release ID 매핑 ──

const FRED_RELEASES = [
  { id: 10, title: 'CPI 소비자물가지수', titleEn: 'Consumer Price Index', category: 'inflation', unit: '%' },
  { id: 50, title: '고용보고서', titleEn: 'Employment Situation', category: 'employment', unit: 'K' },
  { id: 53, title: 'GDP 성장률', titleEn: 'GDP Growth Rate', category: 'gdp', unit: '%' },
  { id: 46, title: 'PPI 생산자물가지수', titleEn: 'Producer Price Index', category: 'inflation', unit: '%' },
  { id: 9, title: '소매판매', titleEn: 'Retail Sales', category: 'other', unit: '%' },
  { id: 54, title: 'PCE 개인소비지출', titleEn: 'Personal Consumption Expenditures', category: 'inflation', unit: '%' },
  { id: 91, title: '미시간 소비자심리지수', titleEn: 'Michigan Consumer Sentiment', category: 'other', unit: '' },
  { id: 95, title: '내구재 주문', titleEn: 'Durable Goods Orders', category: 'other', unit: '%' },
  { id: 21, title: 'FOMC 금리결정', titleEn: 'FOMC Rate Decision', category: 'fomc', unit: '%' },
];

const FRED_RELEASE_MAP = Object.fromEntries(FRED_RELEASES.map(r => [r.id, r]));

// ── FRED Series ID 매핑 (actual/previous 값 조회용) ──
//
// 인플레이션 지표(CPI/PPI/PCE)는 MoM과 YoY 둘 다 표시하므로 두 단위를 각각 조회.
// units: 'pch' = 전월대비(%), 'pc1' = 전년동월대비(%), 'lin' = 원값, 'chg' = 절대 변화
//
// 구조: primary = 기본(보통 YoY, 뉴스 보도 기준), secondary = 보조(MoM)

const FRED_SERIES = {
  10: {
    seriesId: 'CPIAUCSL',
    primary: { units: 'pc1', decimals: 1, type: 'yoy' },  // CPI YoY % (뉴스 보도 기준)
    secondary: { units: 'pch', decimals: 1, type: 'mom' }, // CPI MoM %
  },
  50: {
    seriesId: 'PAYEMS',
    primary: { units: 'chg', decimals: 0, type: null },    // Nonfarm Payrolls 변동 (K)
  },
  // 53 (GDP) 제외: 분기 데이터는 advance/second/third 발표 주기와 관측값이 1:1 매칭 불가
  // GDP는 TradingView forecast/actual에만 의존
  46: {
    seriesId: 'PPIFIS',
    primary: { units: 'pc1', decimals: 1, type: 'yoy' },   // PPI YoY %
    secondary: { units: 'pch', decimals: 1, type: 'mom' }, // PPI MoM %
  },
  9: {
    seriesId: 'RSAFS',
    primary: { units: 'pch', decimals: 1, type: null },    // 소매판매 MoM %
  },
  54: {
    seriesId: 'PCEPI',
    primary: { units: 'pc1', decimals: 1, type: 'yoy' },   // PCE YoY %
    secondary: { units: 'pch', decimals: 1, type: 'mom' }, // PCE MoM %
  },
  91: {
    seriesId: 'UMCSENT',
    primary: { units: 'lin', decimals: 1, type: null },    // Michigan Consumer Sentiment
  },
  95: {
    seriesId: 'DGORDER',
    primary: { units: 'pch', decimals: 1, type: null },    // Durable Goods Orders MoM %
  },
};

// ── TradingView → FRED 매칭 키워드 ──
//
// 인플레이션 지표는 TV에 MoM/YoY 이벤트가 별도로 존재.
// primary(YoY) / secondary(MoM) 구조로 분리 매칭하여 각각 forecast를 가져옴.
// 단일 키워드 구조는 비인플레이션 지표용.

const TV_MATCH_KEYWORDS = {
  10: {
    yoy: ['inflation rate yoy', 'cpi yoy'],
    mom: ['inflation rate mom', 'cpi mom'],
  },
  46: {
    yoy: ['ppi yoy', 'producer price index yoy'],
    mom: ['ppi mom', 'producer price index mom'],
  },
  54: {
    yoy: ['pce price index yoy', 'core pce price index yoy'],
    mom: ['pce price index mom', 'core pce price index mom'],
  },
  // 비인플레이션: 단일 키워드 리스트
  50: ['nonfarm', 'non-farm', 'employment situation', 'payroll'],
  53: ['gdp', 'gross domestic'],
  9: ['retail sales'],
  91: ['michigan consumer sentiment'],
  95: ['durable goods'],
  21: ['fomc', 'fed interest rate', 'federal funds rate'],
};


// ── 라우터 ──

export async function handleCalendar(request, env, url, ctx) {
  if (request.method !== 'GET') {
    return jsonError('GET only', 405, request);
  }

  const subPath = url.pathname.replace('/api/calendar/', '');

  if (subPath === 'economic' || subPath.startsWith('economic?')) {
    return handleEconomicCalendar(request, env, url, ctx);
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
// 경제 캘린더 (FRED 10개 + TradingView forecast + 휴장일 + 네 마녀의 날)
// ════════════════════════════════════════════════════

async function handleEconomicCalendar(request, env, url, ctx) {
  const from = url.searchParams.get('from');
  const to = url.searchParams.get('to');

  if (!from || !to) {
    return jsonError('Missing required params: from, to (YYYY-MM-DD)', 400, request);
  }

  const today = new Date().toISOString().substring(0, 10);

  // 1. FRED release dates + FRED series + TradingView (모두 병렬)
  const [fredResults, tvEvents, seriesDataMap] = await Promise.all([
    Promise.allSettled(
      FRED_RELEASES.map(rel => fetchFredReleaseDates(env, rel, from, to))
    ),
    fetchTradingViewEvents(env, from, to),
    fetchAllFredSeries(env, from, to, today),
  ]);

  const fredEvents = fredResults
    .filter(r => r.status === 'fulfilled')
    .flatMap(r => r.value);

  const { events: mergedEvents } = mergeFredWithTradingView(fredEvents, tvEvents, seriesDataMap, today);

  // 4. NYSE 휴장일 + 네 마녀의 날 추가
  const holidayEvents = buildNYSEHolidays(from, to);
  const holidayDates = new Set(holidayEvents.map(e => e.date.substring(0, 10)));
  const witchingEvents = buildWitchingDays(from, to, holidayDates);

  // 5. 합치고 날짜순 정렬
  const liveEvents = [...mergedEvents, ...holidayEvents, ...witchingEvents]
    .sort((a, b) => a.date.localeCompare(b.date));

  // 6. 과거 날짜 KV 복원
  const allEvents = await restoreEvents(env, liveEvents, from, to, today);

  // 7. 오늘 이벤트 KV 영구 저장 (non-blocking)
  if (ctx) ctx.waitUntil(persistEvents(env, liveEvents, today));

  return jsonResponse(allEvents, request);
}

// ── FRED Release Dates 조회 (개별 KV 캐시, 30일 TTL) ──

async function fetchFredReleaseDates(env, release, from, to) {
  const kvKey = `calendar:fred_dates:${release.id}`;

  // KV 캐시 확인
  const { data: cached } = await getCached(env, kvKey, null);
  if (cached) {
    return JSON.parse(cached).filter(e => e.date >= `${from}T00:00:00.000Z` && e.date <= `${to}T23:59:59.999Z`);
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

    // KV 저장 (30일 TTL, fire-and-forget)
    setCached(env, kvKey, 2592000, null, 0, JSON.stringify(dates));

    // from~to 범위 필터
    return dates.filter(e => e.date >= `${from}T00:00:00.000Z` && e.date <= `${to}T23:59:59.999Z`);
  } catch (e) {
    console.error(`[Calendar] FRED release ${release.id} fetch failed:`, e.message);
    return [];
  }
}

// ── FRED Series 관측값 조회 (actual/previous 확보) ──

/**
 * 모든 FRED release의 시계열 데이터를 병렬로 가져옴
 * @returns {Map<releaseId, Map<releaseDateStr, {actual, previous}>>}
 */
async function fetchAllFredSeries(env, from, to, today) {
  const apiKey = env.FRED_API_KEY;
  if (!apiKey) return {};

  today = today || new Date().toISOString().substring(0, 10);
  const todayInRange = from <= today && to >= today;

  const releaseIds = Object.keys(FRED_SERIES).map(Number);
  const results = await Promise.allSettled(
    releaseIds.map(id => fetchFredSeriesForRelease(env, apiKey, id, todayInRange))
  );

  const seriesMap = {};
  for (let i = 0; i < releaseIds.length; i++) {
    if (results[i].status === 'fulfilled' && results[i].value) {
      seriesMap[releaseIds[i]] = results[i].value;
    }
  }

  return seriesMap;
}

/**
 * 개별 FRED series 관측값 조회 (KV 캐시, 24시간 TTL)
 * primary + secondary(있으면) 둘 다 가져와 각각 관측값 배열 반환
 * @returns {{primary: Array<{date,value}>, secondary?: Array<{date,value}>}}
 */
async function fetchFredSeriesForRelease(env, apiKey, releaseId, skipCache) {
  const config = FRED_SERIES[releaseId];
  if (!config) return null;

  const fetchVariant = async (variant) => {
    if (!variant) return null;
    const kvKey = `calendar:fred_series:${config.seriesId}:${variant.units}`;

    if (!skipCache) {
      const { data: cached } = await getCached(env, kvKey, null);
      if (cached) return JSON.parse(cached);
    }

    try {
      const url = `https://api.stlouisfed.org/fred/series/observations` +
        `?series_id=${config.seriesId}&api_key=${apiKey}&file_type=json` +
        `&sort_order=desc&limit=24&units=${variant.units}`;

      const resp = await fetch(url);
      if (!resp.ok) {
        console.error(`[Calendar] FRED series ${config.seriesId} (${variant.units}) HTTP ${resp.status}`);
        return null;
      }

      const data = await resp.json();
      const observations = (data.observations || [])
        .filter(obs => obs.value !== '.' && obs.value != null)
        .map(obs => ({
          date: obs.date,
          value: parseFloat(parseFloat(obs.value).toFixed(variant.decimals)),
        }));

      setCached(env, kvKey, 86400, null, 0, JSON.stringify(observations));
      return observations;
    } catch (e) {
      console.error(`[Calendar] FRED series ${config.seriesId} (${variant.units}) fetch failed:`, e.message);
      return null;
    }
  };

  const [primary, secondary] = await Promise.all([
    fetchVariant(config.primary),
    fetchVariant(config.secondary),
  ]);

  if (!primary && !secondary) return null;
  return { primary: primary || [], secondary: secondary || null };
}

/**
 * FRED release dates와 series observations를 매칭하여 actual/previous 반환
 * @param {Array} releaseDates - FRED release date 문자열 목록
 * @param {Array} observations - FRED series 관측값 (desc 정렬)
 * @param {string} today - YYYY-MM-DD
 * @returns {Map<releaseDateStr, {actual, previous}>}
 */
function matchReleaseDatesToObservations(releaseDates, observations, today) {
  if (!observations || !observations.length) return {};

  const sortedDates = [...releaseDates].sort((a, b) => b.localeCompare(a));
  const result = {};

  // 오늘/미래: FRED 시계열 지연 대비 actual=null (TV가 더 빨리 제공하면 merge에서 사용)
  let obsIdx = 0;
  for (const relDate of sortedDates) {
    if (relDate >= today) {
      result[relDate] = { actual: null, previous: observations[0]?.value ?? null };
    } else {
      result[relDate] = {
        actual: observations[obsIdx]?.value ?? null,
        previous: observations[obsIdx + 1]?.value ?? null,
      };
      obsIdx++;
    }
  }

  return result;
}

/**
 * primary + secondary 양쪽 관측값을 release date와 매칭
 * @returns {Map<releaseDateStr, {actual, previous, actualMom?, previousMom?}>}
 *
 * 인플레이션 지표처럼 primary=YoY, secondary=MoM인 경우:
 *   { actual, previous } = YoY (뉴스 보도 기준)
 *   { actualMom, previousMom } = MoM (보조 정보)
 */
function matchDualSeriesToReleaseDates(releaseDates, seriesResult, today) {
  if (!seriesResult) return {};
  const primaryMatch = matchReleaseDatesToObservations(releaseDates, seriesResult.primary, today);
  if (!seriesResult.secondary) return primaryMatch;

  const secondaryMatch = matchReleaseDatesToObservations(releaseDates, seriesResult.secondary, today);
  const merged = {};
  for (const date of Object.keys(primaryMatch)) {
    merged[date] = {
      ...primaryMatch[date],
      actualMom: secondaryMatch[date]?.actual ?? null,
      previousMom: secondaryMatch[date]?.previous ?? null,
    };
  }
  return merged;
}

// ── TradingView Economic Calendar 조회 (KV 캐시, 4시간 TTL / 오늘 포함 시 캐시 무시) ──

async function fetchTradingViewEvents(env, from, to) {
  const kvKey = `calendar:tv_events:${from}_${to}`;

  // 오늘 날짜가 요청 범위에 포함되면 캐시 건너뜀 (actual 값 즉시 반영)
  const today = new Date().toISOString().substring(0, 10);
  const todayInRange = from <= today && to >= today;

  // KV 캐시 확인 (오늘 포함 시 건너뜀)
  if (!todayInRange) {
    const { data: cached } = await getCached(env, kvKey, null);
    if (cached) return JSON.parse(cached);
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

    // KV 저장 (4시간 TTL, fire-and-forget)
    setCached(env, kvKey, 14400, null, 0, JSON.stringify(filtered));

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

/**
 * 이벤트 필드별 best-merge: incoming의 non-null 값만 덮어쓰고,
 * null인 필드는 기존 값을 보존한다.
 * 예: KV {forecast: 0.3, actual: null} + live {forecast: null, actual: 0.9}
 *   → {forecast: 0.3, actual: 0.9}
 */
function bestMergeEvent(existing, incoming) {
  return {
    ...existing,
    ...incoming,
    forecast:     incoming.forecast     ?? existing.forecast,
    previous:     incoming.previous     ?? existing.previous,
    actual:       incoming.actual       ?? existing.actual,
    forecastMom:  incoming.forecastMom  ?? existing.forecastMom,
    previousMom:  incoming.previousMom  ?? existing.previousMom,
    actualMom:    incoming.actualMom    ?? existing.actualMom,
  };
}

/**
 * 과거 날짜를 KV에서 복원하여 live 이벤트와 병합 (must be awaited)
 *
 * 핵심: 과거 날짜는 live 이벤트가 있더라도 항상 KV에서 복원한다.
 * TradingView 이벤트는 1~2일 후 사라지므로, FRED 이벤트만 남은 날짜에
 * KV에 보존된 TV 이벤트(actual 포함)를 병합해야 완전한 데이터를 제공.
 * id 기준 dedup — 필드별 non-null 값 보존 (best-merge).
 */
async function restoreEvents(env, liveEvents, from, to, today) {
  const yesterday = new Date(Date.now() - 86400000).toISOString().substring(0, 10);
  const restoreEnd = yesterday < to ? yesterday : to; // 어제까지만 복원

  // from~restoreEnd 범위의 모든 과거 날짜 생성
  const pastDates = [];
  const d = new Date(from + 'T00:00:00Z');
  const endD = new Date(restoreEnd + 'T00:00:00Z');
  while (d <= endD) {
    pastDates.push(d.toISOString().substring(0, 10));
    d.setUTCDate(d.getUTCDate() + 1);
  }

  // 과거 날짜를 KV에서 복원 (최대 90일분)
  const datesToRestore = pastDates.slice(-90);
  if (datesToRestore.length === 0) return liveEvents;

  const results = await Promise.allSettled(
    datesToRestore.map(d => env.CACHE_KV.get(`calendar:day:${d}`, 'json'))
  );

  // id 기준 병합: KV에서 FRED/holiday/witching 이벤트만 복원 (구 TV 이벤트 무시)
  // FRED는 현재 설정된 release id만 허용 (config에서 제거된 구 release는 KV에 남아있어도 무시)
  const isValidId = (id) => {
    if (id.startsWith('holiday-') || id.startsWith('witching-')) return true;
    if (id.startsWith('fred-')) {
      const releaseId = parseInt(id.split('-')[1]);
      return releaseId in FRED_RELEASE_MAP;
    }
    return false;
  };
  const byId = new Map();
  for (const result of results) {
    if (result.status === 'fulfilled' && result.value && Array.isArray(result.value)) {
      for (const e of result.value) {
        if (isValidId(e.id)) byId.set(e.id, e);
      }
    }
  }
  for (const e of liveEvents) {
    const kvEvent = byId.get(e.id);
    byId.set(e.id, kvEvent ? bestMergeEvent(kvEvent, e) : e);
  }

  return [...byId.values()].sort((a, b) => (a.date || '').localeCompare(b.date || ''));
}

/**
 * 오늘/과거 이벤트를 KV에 날짜별 영구 저장 — fire-and-forget via ctx.waitUntil
 */
async function persistEvents(env, liveEvents, today) {
  // 오늘 날짜의 이벤트만 보존 (과거는 이미 저장됨, 미래는 변동 가능)
  // 전체 과거 날짜를 매번 읽고 쓰면 KV 부하가 큼 → 오늘만 persist
  const byDate = {};
  for (const e of liveEvents) {
    const d = (e.date || '').substring(0, 10);
    if (d === today) {
      (byDate[d] ??= []).push(e);
    }
  }

  // 날짜별 KV 저장 (기존 데이터와 병합)
  const datesToSave = Object.keys(byDate);
  if (datesToSave.length === 0) return;

  // 기존 저장된 데이터 읽기
  const existingResults = await Promise.allSettled(
    datesToSave.map(d => env.CACHE_KV.get(`calendar:day:${d}`, 'json'))
  );

  const writeTasks = [];
  for (let i = 0; i < datesToSave.length; i++) {
    const dateKey = datesToSave[i];
    const newEvents = byDate[dateKey];
    const existing = existingResults[i].status === 'fulfilled' ? existingResults[i].value : null;

    // 기존 저장 이벤트와 새 이벤트 병합 (id 기준 dedup, 필드별 non-null 값 보존)
    let merged;
    if (existing && Array.isArray(existing)) {
      const byId = new Map();
      for (const e of existing) byId.set(e.id, e);
      for (const e of newEvents) {
        const existingEvent = byId.get(e.id);
        byId.set(e.id, existingEvent ? bestMergeEvent(existingEvent, e) : e);
      }
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

// ── FRED + TradingView + FRED Series 병합 ──
//
// 인플레이션 지표(CPI/PPI/PCE): YoY(기본) + MoM(보조) 둘 다 포함
//   - forecast/actual/previous = YoY (뉴스 보도 기준)
//   - forecastMom/actualMom/previousMom = MoM
// 기타 지표: 단일 단위 (actual/forecast/previous만 사용)

function findTvMatch(tvEvents, fredDateStr, keywords, today) {
  if (!keywords || !keywords.length || !tvEvents.length) return null;

  // 1차: 같은 날짜 + 키워드
  let matched = tvEvents.find(tv => {
    const tvDateStr = (tv.date || '').substring(0, 10);
    if (tvDateStr !== fredDateStr) return false;
    const tvTitle = (tv.title || '').toLowerCase();
    return keywords.some(kw => tvTitle.includes(kw));
  });

  // 2차: 날짜 실패 시, 과거 이벤트에 한해 키워드만
  if (!matched && fredDateStr <= today) {
    matched = tvEvents.find(tv => {
      const tvTitle = (tv.title || '').toLowerCase();
      return keywords.some(kw => tvTitle.includes(kw)) &&
             (tv.forecast != null || tv.previous != null);
    });
  }

  return matched;
}

function mergeFredWithTradingView(fredEvents, tvEvents, seriesDataMap, today) {
  const datesByRelease = {};
  for (const e of fredEvents) {
    const releaseId = parseInt(e.id.split('-')[1]);
    const dateStr = e.date.substring(0, 10);
    (datesByRelease[releaseId] ??= []).push(dateStr);
  }

  const seriesMatchMap = {};
  for (const [releaseIdStr, dates] of Object.entries(datesByRelease)) {
    const releaseId = parseInt(releaseIdStr);
    const seriesResult = seriesDataMap[releaseId];
    if (seriesResult && seriesResult.primary && seriesResult.primary.length) {
      seriesMatchMap[releaseId] = matchDualSeriesToReleaseDates(dates, seriesResult, today);
    }
  }

  const events = fredEvents.map(fredEvent => {
    const releaseId = parseInt(fredEvent.id.split('-')[1]);
    const fredDateStr = fredEvent.date.substring(0, 10);

    // ── TradingView 매칭 — MoM/YoY 분리 구조 지원 ──
    const kwEntry = TV_MATCH_KEYWORDS[releaseId];
    const isDualUnit = kwEntry && !Array.isArray(kwEntry); // {yoy, mom} 구조
    const keywordsYoy = isDualUnit ? kwEntry.yoy : (kwEntry || []);
    const keywordsMom = isDualUnit ? kwEntry.mom : null;

    const tvYoy = findTvMatch(tvEvents, fredDateStr, keywordsYoy, today);
    const tvMom = keywordsMom ? findTvMatch(tvEvents, fredDateStr, keywordsMom, today) : null;

    // ── FRED 시계열 매칭 ──
    const seriesMatch = seriesMatchMap[releaseId]?.[fredDateStr];

    // ── 병합 ──
    // primary (YoY for inflation, single-unit for others):
    //   forecast ← TV, actual/previous ← FRED series > TV
    const forecast = tvYoy?.forecast ?? null;
    const actual = seriesMatch?.actual ?? tvYoy?.actual ?? null;
    const previous = seriesMatch?.previous ?? tvYoy?.previous ?? null;

    // secondary (MoM, only for inflation dual-unit releases)
    const forecastMom = isDualUnit ? (tvMom?.forecast ?? null) : null;
    const actualMom = isDualUnit ? (seriesMatch?.actualMom ?? tvMom?.actual ?? null) : null;
    const previousMom = isDualUnit ? (seriesMatch?.previousMom ?? tvMom?.previous ?? null) : null;

    const importance = (tvYoy?.importance >= 3 || tvMom?.importance >= 3) ? 3 : fredEvent.importance;

    const hasAnyValue =
      forecast !== null || actual !== null || previous !== null ||
      forecastMom !== null || actualMom !== null || previousMom !== null ||
      importance !== fredEvent.importance;

    if (hasAnyValue) {
      return {
        ...fredEvent,
        forecast, actual, previous,
        ...(isDualUnit ? { forecastMom, actualMom, previousMom } : {}),
        importance,
      };
    }

    return fredEvent;
  });

  return { events };
}

// ── NYSE 휴장일 계산 ──

/**
 * 부활절 날짜 계산 (Anonymous Gregorian Easter algorithm)
 * @returns {Date} 부활절 일요일 UTC 날짜
 */
function getEasterSunday(year) {
  const a = year % 19;
  const b = Math.floor(year / 100);
  const c = year % 100;
  const d = Math.floor(b / 4);
  const e = b % 4;
  const f = Math.floor((b + 8) / 25);
  const g = Math.floor((b - f + 1) / 3);
  const h = (19 * a + b - d - g + 15) % 30;
  const i = Math.floor(c / 4);
  const k = c % 4;
  const l = (32 + 2 * e + 2 * i - h - k) % 7;
  const m = Math.floor((a + 11 * h + 22 * l) / 451);
  const month = Math.floor((h + l - 7 * m + 114) / 31); // 3=March, 4=April
  const day = ((h + l - 7 * m + 114) % 31) + 1;
  return new Date(Date.UTC(year, month - 1, day));
}

/**
 * Good Friday = Easter Sunday - 2 days
 */
function getGoodFriday(year) {
  const easter = getEasterSunday(year);
  easter.setUTCDate(easter.getUTCDate() - 2);
  return easter;
}

/**
 * N번째 특정 요일 찾기
 * @param {number} weekday - 0=Sun, 1=Mon, ..., 5=Fri
 * @param {number} n - 1-based (1=첫째, 2=둘째, ...)
 */
function nthWeekday(year, month, weekday, n) {
  const first = new Date(Date.UTC(year, month, 1));
  let day = 1 + ((weekday - first.getUTCDay() + 7) % 7);
  day += (n - 1) * 7;
  return new Date(Date.UTC(year, month, day));
}

/**
 * 해당 월의 마지막 특정 요일 찾기
 */
function lastWeekday(year, month, weekday) {
  const last = new Date(Date.UTC(year, month + 1, 0)); // 해당 월 마지막 날
  const diff = (last.getUTCDay() - weekday + 7) % 7;
  last.setUTCDate(last.getUTCDate() - diff);
  return last;
}

const NYSE_HOLIDAYS = [
  { name: '신년', nameEn: "New Year's Day", fixed: [0, 1],
    desc: '새해 첫날. 전 세계 금융시장 휴장.' },
  { name: 'MLK의 날', nameEn: 'MLK Day', nth: [0, 1, 3],
    desc: '마틴 루터 킹 주니어 기념일. 미국 민권 운동의 지도자를 기리는 연방 공휴일.' },
  { name: '대통령의 날', nameEn: "Presidents' Day", nth: [1, 1, 3],
    desc: '미국 역대 대통령을 기리는 연방 공휴일. 원래 조지 워싱턴 생일 기념.' },
  { name: '성금요일', nameEn: 'Good Friday', easter: true,
    desc: '부활절 전 금요일. 예수 그리스도의 수난을 기념하는 날. NYSE 휴장.' },
  { name: '현충일', nameEn: 'Memorial Day', last: [4, 1],
    desc: '미국 전몰장병 추모일. 여름 시작을 알리는 연방 공휴일.' },
  { name: '준틴스', nameEn: 'Juneteenth', fixed: [5, 19],
    desc: '미국 노예해방 기념일 (6월 19일). 1865년 텍사스에서 마지막 노예 해방 선언. 2021년부터 연방 공휴일.' },
  { name: '독립기념일', nameEn: 'Independence Day', fixed: [6, 4],
    desc: '미국 독립선언일 (7월 4일). 1776년 영국으로부터 독립을 선언한 날.' },
  { name: '노동절', nameEn: 'Labor Day', nth: [8, 1, 1],
    desc: '미국 노동자의 날. 여름 시즌 종료를 알리는 연방 공휴일.' },
  { name: '추수감사절', nameEn: 'Thanksgiving', nth: [10, 4, 4],
    desc: '미국 추수감사절. 연말 쇼핑 시즌(블랙프라이데이) 시작. 단축거래일(금)이 뒤따름.' },
  { name: '크리스마스', nameEn: 'Christmas', fixed: [11, 25],
    desc: '크리스마스. 전 세계 금융시장 휴장. 연말 유동성 감소 시기.' },
];

function buildNYSEHolidays(from, to) {
  const fromYear = parseInt(from.substring(0, 4));
  const toYear = parseInt(to.substring(0, 4));
  const events = [];

  for (let year = fromYear; year <= toYear; year++) {
    for (const h of NYSE_HOLIDAYS) {
      let date;
      if (h.fixed) {
        date = new Date(Date.UTC(year, h.fixed[0], h.fixed[1]));
      } else if (h.nth) {
        date = nthWeekday(year, h.nth[0], h.nth[1], h.nth[2]);
      } else if (h.last) {
        date = lastWeekday(year, h.last[0], h.last[1]);
      } else if (h.easter) {
        date = getGoodFriday(year);
      }

      const dateStr = date.toISOString().substring(0, 10);
      if (dateStr < from || dateStr > to) continue;

      events.push({
        id: `holiday-${dateStr}`,
        title: h.name,
        titleEn: h.nameEn,
        date: `${dateStr}T00:00:00.000Z`,
        category: 'holiday',
        forecast: null,
        previous: null,
        actual: null,
        unit: '',
        importance: 1,
        description: h.desc,
      });
    }
  }

  return events;
}

// ── 네 마녀의 날 (Quadruple Witching) ──

function buildWitchingDays(from, to, holidayDates = new Set()) {
  const fromYear = parseInt(from.substring(0, 4));
  const toYear = parseInt(to.substring(0, 4));
  const events = [];
  const witchingMonths = [2, 5, 8, 11]; // 0-indexed: Mar, Jun, Sep, Dec

  for (let year = fromYear; year <= toYear; year++) {
    for (const month of witchingMonths) {
      const date = nthWeekday(year, month, 5, 3); // 3rd Friday
      let dateStr = date.toISOString().substring(0, 10);

      // 휴장일과 겹치면 전 거래일(목요일)로 이동
      if (holidayDates.has(dateStr)) {
        const prev = new Date(date);
        prev.setUTCDate(prev.getUTCDate() - 1); // Thursday
        dateStr = prev.toISOString().substring(0, 10);
      }

      if (dateStr < from || dateStr > to) continue;

      events.push({
        id: `witching-${dateStr}`,
        title: '네 마녀의 날',
        titleEn: 'Quadruple Witching',
        date: `${dateStr}T00:00:00.000Z`,
        category: 'other',
        forecast: null,
        previous: null,
        actual: null,
        unit: '',
        importance: 2,
      });
    }
  }

  return events;
}

// ════════════════════════════════════════════════════
// 실적 캘린더 (Finnhub Earnings)
// ════════════════════════════════════════════════════

const MAJOR_EARNINGS_SYMBOLS = [
  'AAPL', 'MSFT', 'GOOGL', 'AMZN', 'NVDA', 'META', 'TSLA',
  'AMD', 'AVGO', 'INTC', 'NFLX', 'CRM', 'ADBE', 'ORCL',
  'QCOM', 'MU', 'MRVL', 'ARM',
  'JPM', 'BAC', 'GS', 'UNH', 'JNJ', 'PG', 'KO',
];

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
    const { data: cached } = await getCached(env, kvKey, null);
    if (cached) {
      const filtered = JSON.parse(cached).filter(e => {
        const d = e.date.substring(0, 10);
        return d >= from && d <= to;
      });
      return jsonResponse(filtered, request);
    }
  }

  // 2. Finnhub API 호출 (벌크 먼저 → 누락 심볼만 개별 조회)
  try {
    const userSymbols = symbolsParam
      ? symbolsParam.split(',').map(s => s.trim().toUpperCase()).filter(Boolean)
      : [];
    const wantedSymbols = new Set([...MAJOR_EARNINGS_SYMBOLS, ...userSymbols]);

    // 벌크 조회 (전체 earnings calendar)
    const bulkResp = await fetch(
      `https://finnhub.io/api/v1/calendar/earnings?from=${from}&to=${to}&token=${apiKey}`
    ).then(r => r.ok ? r.json() : null).catch(() => null);

    const allEarnings = new Map();
    const foundSymbols = new Set();

    if (bulkResp) {
      for (const item of (bulkResp.earningsCalendar || [])) {
        const key = `${item.symbol}-${item.date}`;
        if (!allEarnings.has(key)) {
          allEarnings.set(key, item);
          foundSymbols.add(item.symbol);
        }
      }
    }

    // 벌크에서 누락된 주요 심볼만 개별 조회
    const missingSymbols = [...wantedSymbols].filter(s => !foundSymbols.has(s));
    if (missingSymbols.length > 0) {
      const results = await Promise.allSettled(
        missingSymbols.slice(0, 20).map(symbol =>
          fetch(`https://finnhub.io/api/v1/calendar/earnings?from=${from}&to=${to}&symbol=${symbol}&token=${apiKey}`)
            .then(r => r.ok ? r.json() : null)
            .catch(() => null)
        )
      );
      for (const result of results) {
        if (result.status !== 'fulfilled' || !result.value) continue;
        for (const item of (result.value.earningsCalendar || [])) {
          const key = `${item.symbol}-${item.date}`;
          if (!allEarnings.has(key)) {
            allEarnings.set(key, item);
          }
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
      revenueActual: item.revenueActual ?? null,
    })).sort((a, b) => a.date.localeCompare(b.date));

    // 4. KV 저장 (symbols 없을 때만 — 전체 캘린더, 7일 TTL, fire-and-forget)
    if (!symbolsParam) {
      setCached(env, kvKey, 604800, null, 0, JSON.stringify(events));
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
    let tvEvents = [];
    try {
      tvEvents = await fetchTradingViewEvents(env, weekFrom, weekTo);
      console.log('[Cron] Calendar: TradingView events warmed (this week)');
    } catch (e) {
      console.error('[Cron] Calendar: TradingView warming failed:', e.message);
    }

    // 평일: FRED 시계열 워밍 — actual/previous 갱신 (발표일 대비)
    try {
      await fetchAllFredSeries(env, weekFrom, weekTo);
      console.log('[Cron] Calendar: FRED series data warmed');
    } catch (e) {
      console.error('[Cron] Calendar: FRED series warming failed:', e.message);
    }

    // post-market: 오늘 이벤트를 날짜별 KV에 영구 보존 (actual 값 포함)
    // TV는 1~2일 후 과거 이벤트를 삭제하므로, 장 마감 후 actual 확정된 상태로 저장
    if (cronType === 'post-market' && tvEvents.length > 0) {
      try {
        // FRED release dates + series도 가져와서 완전한 이벤트 목록 생성
        const [fredResults, seriesDataMap] = await Promise.all([
          Promise.allSettled(
            FRED_RELEASES.map(rel => fetchFredReleaseDates(env, rel, today, today))
          ),
          fetchAllFredSeries(env, today, today, today),
        ]);
        const fredEvents = fredResults
          .filter(r => r.status === 'fulfilled')
          .flatMap(r => r.value);
        const { events: mergedEvents } = mergeFredWithTradingView(fredEvents, tvEvents, seriesDataMap, today);
        const todayHolidays = buildNYSEHolidays(today, today);
        const todayHolidayDates = new Set(todayHolidays.map(e => e.date.substring(0, 10)));
        const allTodayEvents = [...mergedEvents, ...todayHolidays, ...buildWitchingDays(today, today, todayHolidayDates)];

        await persistEvents(env, allTodayEvents, today);
        console.log(`[Cron] Calendar: ${allTodayEvents.length} events persisted for ${today}`);
      } catch (e) {
        console.error('[Cron] Calendar: post-market persist failed:', e.message);
      }
    }
  }

  if (cronType === 'weekend') {
    // 주말: FRED release dates (3개월 분) + TradingView (2주) + FRED 시계열
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

    // 주말: FRED 시계열 워밍
    try {
      await fetchAllFredSeries(env, today, today);
      console.log('[Cron] Calendar: FRED series data warmed (weekend)');
    } catch (e) {
      console.error('[Cron] Calendar: FRED series warming failed:', e.message);
    }
  }
}
