/**
 * CNN Fear & Greed Index — robust fetch helper.
 *
 * Strategy:
 *   1. Read KV cache (`fear_greed:latest`, 6h TTL). HIT → return {score, source: 'cache'}.
 *   2. On MISS, attempt CNN fetch with realistic browser headers + 3s timeout.
 *      - Retry once after 1500ms on 418/429/5xx/abort/network error. Never more than 2 tries.
 *   3. On success, persist both:
 *      - `fear_greed:latest` = full JSON (expirationTtl 21600) — legacy-compatible shape
 *        `{ fear_and_greed: { score: number, ... }, ... }` so existing readers still work.
 *      - `fear_greed:last_known` = `{ score, savedAt }` — no TTL, last-resort fallback.
 *   4. If both fetch attempts fail, read `fear_greed:last_known` and return with source 'fallback'.
 *   5. No silent skips: every failure path emits console.error('[FearGreed] ...').
 *
 * KV key contract:
 *   - `fear_greed:latest`: same as before (full CNN JSON via JSON.stringify). TTL raised 3600 → 21600.
 *   - `fear_greed:last_known`: new. `{ score, savedAt }` minimal shape, helper-internal use only.
 *
 * Return shape (stable):
 *   { score: number|null, source: 'cache'|'fresh'|'fallback', cachedAt?: number }
 *   - score === null  → callers MUST skip the F&G alert check.
 */

const CNN_URL = 'https://production.dataviz.cnn.io/index/fearandgreed/graphdata/';
const LATEST_KEY = 'fear_greed:latest';
const LAST_KNOWN_KEY = 'fear_greed:last_known';
const LATEST_TTL_SEC = 21600; // 6h
const FETCH_TIMEOUT_MS = 3000;
const RETRY_DELAY_MS = 1500;

const CNN_HEADERS = {
  'User-Agent':
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
  Referer: 'https://edition.cnn.com/',
  Accept: 'application/json, text/plain, */*',
  'Accept-Language': 'en-US,en;q=0.9',
  Origin: 'https://edition.cnn.com',
  'Cache-Control': 'no-cache',
};

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

/**
 * Single CNN fetch attempt with 3s AbortController timeout.
 * @returns {Promise<{ok: true, data: object} | {ok: false, retryable: boolean, reason: string}>}
 */
async function cnnFetchOnce() {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), FETCH_TIMEOUT_MS);
  try {
    const resp = await fetch(CNN_URL, {
      headers: CNN_HEADERS,
      signal: controller.signal,
    });
    clearTimeout(timer);

    // 418/429/5xx → retryable; other non-2xx → not retryable (unlikely, but bail fast)
    if (!resp.ok) {
      const retryable = resp.status === 418 || resp.status === 429 || resp.status >= 500;
      return { ok: false, retryable, reason: `HTTP ${resp.status}` };
    }

    const data = await resp.json();
    if (data?.fear_and_greed?.score == null) {
      return { ok: false, retryable: false, reason: 'Missing fear_and_greed.score' };
    }
    return { ok: true, data };
  } catch (e) {
    clearTimeout(timer);
    // AbortError (timeout) or network error → retryable
    const reason = e.name === 'AbortError' ? 'timeout' : `network: ${e.message}`;
    return { ok: false, retryable: true, reason };
  }
}

/**
 * Fetch F&G score with cache + fallback resilience.
 * @param {{CACHE_KV: KVNamespace}} env
 * @returns {Promise<{score: number|null, source: 'cache'|'fresh'|'fallback', cachedAt?: number}>}
 */
export async function fetchFearGreed(env) {
  // 1. Cache read
  try {
    const cached = await env.CACHE_KV.get(LATEST_KEY, 'json');
    if (cached?.fear_and_greed?.score != null) {
      return { score: Math.round(cached.fear_and_greed.score), source: 'cache' };
    }
  } catch (e) {
    console.error('[FearGreed] Cache read failed:', e.message);
    // Fall through to fetch
  }

  // 2. Fresh fetch with retry
  let attempt1 = await cnnFetchOnce();
  let result = attempt1;
  if (!attempt1.ok && attempt1.retryable) {
    console.error(`[FearGreed] Attempt 1 failed (${attempt1.reason}), retrying in ${RETRY_DELAY_MS}ms`);
    await sleep(RETRY_DELAY_MS);
    result = await cnnFetchOnce();
  }

  if (result.ok) {
    const score = Math.round(result.data.fear_and_greed.score);
    // Persist both KV keys. Failures here are logged but don't break the return.
    try {
      await env.CACHE_KV.put(LATEST_KEY, JSON.stringify(result.data), {
        expirationTtl: LATEST_TTL_SEC,
      });
    } catch (e) {
      console.error('[FearGreed] Cache write (latest) failed:', e.message);
    }
    try {
      await env.CACHE_KV.put(
        LAST_KNOWN_KEY,
        JSON.stringify({ score, savedAt: Date.now() }),
      );
    } catch (e) {
      console.error('[FearGreed] Cache write (last_known) failed:', e.message);
    }
    return { score, source: 'fresh' };
  }

  console.error(`[FearGreed] Fetch failed after retry: ${result.reason}`);

  // 3. Fallback to last_known
  try {
    const lastKnown = await env.CACHE_KV.get(LAST_KNOWN_KEY, 'json');
    if (lastKnown?.score != null) {
      console.error(
        `[FearGreed] Using last_known fallback: score=${lastKnown.score} savedAt=${lastKnown.savedAt}`,
      );
      return {
        score: Math.round(lastKnown.score),
        source: 'fallback',
        cachedAt: lastKnown.savedAt,
      };
    }
  } catch (e) {
    console.error('[FearGreed] last_known read failed:', e.message);
  }

  console.error('[FearGreed] No fallback available — returning null');
  return { score: null, source: 'fallback' };
}
