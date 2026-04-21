#!/usr/bin/env node
/**
 * CNN Fear & Greed fetch helper 회귀 테스트
 *
 * 검증 대상: src/lib/fearGreed.js :: fetchFearGreed(env)
 *
 * 검증 항목:
 *   1) 캐시 HIT 경로 (source='cache', Math.round)
 *   2) 캐시 MISS → fetch 성공 경로 (source='fresh', KV 이중 저장 + TTL 옵션)
 *   3) 418 → retry → 200 (재시도 1회 정상 동작)
 *   4) 418 → 418 → fallback (재시도 소진 후 last_known 사용)
 *   5) 429 → 503 → fallback (모든 retryable 상태 확인)
 *   6) timeout → retry → timeout → null (fallback 없을 때 null 반환)
 *   7) malformed JSON → 즉시 fallback (non-retryable 처리)
 *   8) score === 0 edge case (falsy 버그 방지, != null 검증)
 *   9) KV write 실패는 return에 영향 없음
 *  10) KV read 예외 시 fetch로 fall through
 *
 * 실행:
 *   node scripts/test-fear-greed.mjs
 *
 * 환경: Node v18+ (AbortController/AbortSignal 내장)
 *
 * Note: setTimeout을 import 전에 monkey-patch해서 RETRY_DELAY_MS(1500ms) 대기를
 *       스킵한다. helper 안 sleep()이 patched setTimeout을 캡처하도록
 *       반드시 dynamic import 전에 덮어써야 한다.
 */

// ── setTimeout monkey-patch (import 전에 필수) ──────────────────────────
// helper의 sleep()이 globalThis.setTimeout을 캡처하므로, 이 파일 안에서는
// 모든 delay를 0ms로 처리해 전체 실행 시간을 짧게 유지한다.
// AbortController 타임아웃도 setTimeout을 쓰지만, 우리는 fetch를 직접 mock하므로
// 실제 타임아웃이 실행되는 일은 없다 (mock이 먼저 resolve/reject한다).
const _origSetTimeout = globalThis.setTimeout;
globalThis.setTimeout = (fn, _ms, ...args) => _origSetTimeout(fn, 0, ...args);

const { fetchFearGreed } = await import('../src/lib/fearGreed.js');

// ── 유틸 ─────────────────────────────────────────────────────────────────

let PASS = 0;
let FAIL = 0;
function ok(name) {
  PASS++;
  console.log(`  PASS  ${name}`);
}
function fail(name, extra = '') {
  FAIL++;
  console.log(`  FAIL  ${name}${extra ? '  — ' + extra : ''}`);
}
function assert(name, cond, extra = '') {
  if (cond) ok(name);
  else fail(name, extra);
}
function assertEq(name, actual, expected) {
  if (actual === expected) ok(name);
  else fail(name, `expected=${JSON.stringify(expected)}  actual=${JSON.stringify(actual)}`);
}

// console.error를 silence (helper가 실패 경로에서 의도적으로 로깅한다)
const _origConsoleError = console.error;
console.error = () => {};

// ── Mock 헬퍼 ───────────────────────────────────────────────────────────

/**
 * 메모리 기반 KV mock.
 * - get(key, type): type==='json'이면 JSON.parse 후 반환
 * - put(key, value, opts): opts.expirationTtl 기록
 * - throwOnGet / throwOnPut: 예외 유도 플래그
 */
function makeKv({ throwOnGet = false, throwOnPut = false } = {}) {
  const store = new Map();
  const putCalls = []; // {key, value, opts}
  return {
    store,
    putCalls,
    async get(key, type) {
      if (throwOnGet) throw new Error('simulated KV.get failure');
      const raw = store.get(key);
      if (raw === undefined) return null;
      if (type === 'json') {
        try { return JSON.parse(raw); }
        catch { return null; }
      }
      return raw;
    },
    async put(key, value, opts) {
      putCalls.push({ key, value, opts });
      if (throwOnPut) throw new Error('simulated KV.put failure');
      store.set(key, value);
    },
  };
}

/**
 * fetch mock 생성. responses는 순차적으로 소비되는 배열.
 * 각 원소는 다음 중 하나:
 *   { status: 200, body: object }
 *   { status: 418 | 429 | 503 }
 *   { abort: true }           → AbortError throw
 *   { networkError: 'msg' }   → 일반 Error throw
 */
function makeFetch(responses) {
  let callCount = 0;
  const calls = [];
  const fn = async (_url, _opts) => {
    calls.push({ url: _url, opts: _opts });
    const spec = responses[callCount++];
    if (!spec) throw new Error(`fetch mock exhausted at call ${callCount}`);

    if (spec.abort) {
      const e = new Error('The operation was aborted');
      e.name = 'AbortError';
      throw e;
    }
    if (spec.networkError) {
      throw new Error(spec.networkError);
    }

    const status = spec.status;
    const ok = status >= 200 && status < 300;
    return {
      ok,
      status,
      async json() {
        if (spec.body === undefined) {
          throw new Error('no body configured');
        }
        return spec.body;
      },
    };
  };
  fn._calls = calls;
  fn._count = () => callCount;
  return fn;
}

// 각 테스트 사이에 globalThis.fetch를 갈아끼운다
function withFetch(fn) {
  globalThis.fetch = fn;
}

// ── 테스트 1: 캐시 HIT ────────────────────────────────────────────────────

async function test1CacheHit() {
  console.log('\n[Test 1] Cache HIT → source=cache, fetch 호출 안 됨');

  const kv = makeKv();
  // legacy 포맷: full CNN JSON
  kv.store.set('fear_greed:latest', JSON.stringify({ fear_and_greed: { score: 65.3 } }));
  const fetchMock = makeFetch([]); // 호출되면 즉시 exhausted 에러
  withFetch(fetchMock);

  const result = await fetchFearGreed({ CACHE_KV: kv });

  assertEq('score === 65 (Math.round(65.3))', result.score, 65);
  assertEq("source === 'cache'", result.source, 'cache');
  assert('fetch 호출 횟수 === 0', fetchMock._count() === 0, `got ${fetchMock._count()}`);
}

// ── 테스트 2: Cache MISS → fresh 성공 ───────────────────────────────────

async function test2FreshSuccess() {
  console.log('\n[Test 2] Cache MISS → fetch 200 → source=fresh, KV 이중 저장');

  const kv = makeKv();
  const fetchMock = makeFetch([
    { status: 200, body: { fear_and_greed: { score: 42.7 } } },
  ]);
  withFetch(fetchMock);

  const beforeTs = Date.now();
  const result = await fetchFearGreed({ CACHE_KV: kv });
  const afterTs = Date.now();

  assertEq('score === 43 (Math.round(42.7))', result.score, 43);
  assertEq("source === 'fresh'", result.source, 'fresh');

  // fear_greed:latest put 검증
  const latestPut = kv.putCalls.find((c) => c.key === 'fear_greed:latest');
  assert('fear_greed:latest put 호출됨', !!latestPut);
  if (latestPut) {
    // legacy full JSON 형식 유지
    const parsed = JSON.parse(latestPut.value);
    assertEq(
      'fear_greed:latest 값이 full CNN JSON (score 보존)',
      parsed?.fear_and_greed?.score,
      42.7,
    );
    assertEq(
      'fear_greed:latest expirationTtl === 21600',
      latestPut.opts?.expirationTtl,
      21600,
    );
  }

  // fear_greed:last_known put 검증
  const lastPut = kv.putCalls.find((c) => c.key === 'fear_greed:last_known');
  assert('fear_greed:last_known put 호출됨', !!lastPut);
  if (lastPut) {
    const parsed = JSON.parse(lastPut.value);
    assertEq('last_known.score === 43', parsed.score, 43);
    assert(
      'last_known.savedAt은 최근 timestamp',
      typeof parsed.savedAt === 'number' &&
        parsed.savedAt >= beforeTs &&
        parsed.savedAt <= afterTs,
      `savedAt=${parsed.savedAt}, window=[${beforeTs}, ${afterTs}]`,
    );
    // 무기한(TTL 없음) 검증: expirationTtl 미설정 (undefined 또는 opts 자체가 없음)
    const ttl = lastPut.opts?.expirationTtl;
    assert(
      'last_known은 expirationTtl 없음 (무기한)',
      ttl === undefined,
      `got expirationTtl=${ttl}`,
    );
  }
}

// ── 테스트 3: 418 → retry → 200 ─────────────────────────────────────────

async function test3RetryThenSuccess() {
  console.log('\n[Test 3] 418 → 재시도 → 200 (재시도 1회 동작)');

  const kv = makeKv();
  const fetchMock = makeFetch([
    { status: 418 },
    { status: 200, body: { fear_and_greed: { score: 55.0 } } },
  ]);
  withFetch(fetchMock);

  const result = await fetchFearGreed({ CACHE_KV: kv });

  assertEq('score === 55', result.score, 55);
  assertEq("source === 'fresh' (retry 성공)", result.source, 'fresh');
  assertEq('fetch 호출 횟수 === 2', fetchMock._count(), 2);
}

// ── 테스트 4: 418 → 418 → fallback ──────────────────────────────────────

async function test4RetryExhaustedWithFallback() {
  console.log('\n[Test 4] 418 → 418 → fallback (last_known 사용)');

  const kv = makeKv();
  const savedAt = Date.now() - 7200_000; // 2h ago
  kv.store.set(
    'fear_greed:last_known',
    JSON.stringify({ score: 50, savedAt }),
  );
  const fetchMock = makeFetch([{ status: 418 }, { status: 418 }]);
  withFetch(fetchMock);

  const result = await fetchFearGreed({ CACHE_KV: kv });

  assertEq('score === 50 (fallback)', result.score, 50);
  assertEq("source === 'fallback'", result.source, 'fallback');
  assertEq('cachedAt === savedAt', result.cachedAt, savedAt);
  assertEq('fetch 호출 횟수 === 2 (retry 후 중단)', fetchMock._count(), 2);
}

// ── 테스트 5: 429 → 503 → fallback ──────────────────────────────────────

async function test5MixedRetryableFallback() {
  console.log('\n[Test 5] 429 → 503 → fallback');

  const kv = makeKv();
  const savedAt = Date.now() - 3600_000;
  kv.store.set(
    'fear_greed:last_known',
    JSON.stringify({ score: 77, savedAt }),
  );
  const fetchMock = makeFetch([{ status: 429 }, { status: 503 }]);
  withFetch(fetchMock);

  const result = await fetchFearGreed({ CACHE_KV: kv });

  assertEq('score === 77', result.score, 77);
  assertEq("source === 'fallback'", result.source, 'fallback');
  assertEq('fetch 호출 횟수 === 2', fetchMock._count(), 2);
}

// ── 테스트 6: timeout → retry → timeout, no fallback → null ─────────────

async function test6TimeoutNoFallback() {
  console.log('\n[Test 6] timeout → retry → timeout, fallback 없음 → score=null');

  const kv = makeKv();
  const fetchMock = makeFetch([{ abort: true }, { abort: true }]);
  withFetch(fetchMock);

  const result = await fetchFearGreed({ CACHE_KV: kv });

  assertEq('score === null', result.score, null);
  assertEq("source === 'fallback'", result.source, 'fallback');
  assertEq('fetch 호출 횟수 === 2', fetchMock._count(), 2);
  assert('cachedAt 미포함', result.cachedAt === undefined, `got ${result.cachedAt}`);
}

// ── 테스트 7: malformed JSON → non-retryable → 즉시 fallback ────────────

async function test7MalformedNonRetryable() {
  console.log('\n[Test 7] malformed JSON → non-retryable → 재시도 없이 fallback');

  const kv = makeKv();
  const savedAt = Date.now() - 1000;
  kv.store.set(
    'fear_greed:last_known',
    JSON.stringify({ score: 30, savedAt }),
  );
  // 200 OK지만 필수 필드 누락 → non-retryable
  const fetchMock = makeFetch([
    { status: 200, body: { unexpected: 'shape' } },
  ]);
  withFetch(fetchMock);

  const result = await fetchFearGreed({ CACHE_KV: kv });

  assertEq('score === 30 (fallback)', result.score, 30);
  assertEq("source === 'fallback'", result.source, 'fallback');
  assertEq('fetch 호출 횟수 === 1 (재시도 없음)', fetchMock._count(), 1);
}

// ── 테스트 8: score === 0 edge case ─────────────────────────────────────

async function test8ScoreZero() {
  console.log('\n[Test 8] score === 0 edge case (falsy 버그 방지)');

  const kv = makeKv();
  const fetchMock = makeFetch([
    { status: 200, body: { fear_and_greed: { score: 0 } } },
  ]);
  withFetch(fetchMock);

  const result = await fetchFearGreed({ CACHE_KV: kv });

  assertEq('score === 0 (truthy check가 아닌 != null 사용 확인)', result.score, 0);
  assertEq("source === 'fresh'", result.source, 'fresh');
}

// ── 테스트 9: KV write 실패는 return에 영향 없음 ────────────────────────

async function test9KvWriteFailure() {
  console.log('\n[Test 9] KV.put 예외 시에도 score는 정상 반환');

  const kv = makeKv({ throwOnPut: true });
  const fetchMock = makeFetch([
    { status: 200, body: { fear_and_greed: { score: 88.2 } } },
  ]);
  withFetch(fetchMock);

  let threw = false;
  let result;
  try {
    result = await fetchFearGreed({ CACHE_KV: kv });
  } catch (e) {
    threw = true;
  }

  assert('fetchFearGreed가 throw하지 않음', !threw);
  if (!threw) {
    assertEq('score === 88', result.score, 88);
    assertEq("source === 'fresh'", result.source, 'fresh');
  }
}

// ── 테스트 10: KV read 예외 → fetch로 fall through ──────────────────────

async function test10KvReadFailure() {
  console.log('\n[Test 10] KV.get 예외 시 fetch로 fall through');

  const kv = makeKv({ throwOnGet: true });
  const fetchMock = makeFetch([
    { status: 200, body: { fear_and_greed: { score: 25.0 } } },
  ]);
  withFetch(fetchMock);

  let threw = false;
  let result;
  try {
    result = await fetchFearGreed({ CACHE_KV: kv });
  } catch (e) {
    threw = true;
  }

  assert('fetchFearGreed가 throw하지 않음', !threw);
  if (!threw) {
    assertEq('score === 25', result.score, 25);
    assertEq("source === 'fresh'", result.source, 'fresh');
  }
}

// ── 실행 ─────────────────────────────────────────────────────────────────

async function main() {
  console.log('═══════════════════════════════════════════════════════');
  console.log('  Fear & Greed fetch helper 회귀 테스트');
  console.log('═══════════════════════════════════════════════════════');

  try {
    await test1CacheHit();
    await test2FreshSuccess();
    await test3RetryThenSuccess();
    await test4RetryExhaustedWithFallback();
    await test5MixedRetryableFallback();
    await test6TimeoutNoFallback();
    await test7MalformedNonRetryable();
    await test8ScoreZero();
    await test9KvWriteFailure();
    await test10KvReadFailure();
  } catch (e) {
    console.error = _origConsoleError;
    console.error('\n[FATAL] 테스트 실행 중 예외:');
    console.error(e);
    process.exit(2);
  }

  console.error = _origConsoleError;
  console.log('\n═══════════════════════════════════════════════════════');
  console.log(`  Results:  PASS=${PASS}   FAIL=${FAIL}`);
  console.log('═══════════════════════════════════════════════════════\n');
  process.exit(FAIL === 0 ? 0 : 1);
}

main();
