/**
 * 통합 캐시 레이어 (KV + Cache API)
 *
 * 모든 핸들러가 이 모듈을 사용하여 캐시 조회/저장을 수행한다.
 * KV → Cache API 순서로 조회, 동시 저장으로 일관성을 보장한다.
 *
 * @exports getCached  - KV → Cache API 순서로 캐시 조회
 * @exports setCached  - KV + Cache API에 동시 저장
 * @imports 없음 (외부 의존성 제로)
 */

/**
 * 통합 캐시 조회: KV 우선 → Cache API 차순
 *
 * @param {Object} env           - Worker 환경 (env.CACHE_KV)
 * @param {string|null} kvKey    - KV 키 (null이면 KV 건너뜀)
 * @param {Request|null} cacheKey - Cache API 키 (null이면 Cache API 건너뜀)
 * @returns {Promise<{data: string|null, source: string}>}
 */
export async function getCached(env, kvKey, cacheKey) {
  // 1차: KV
  if (kvKey && env.CACHE_KV) {
    try {
      const kvData = await env.CACHE_KV.get(kvKey, 'text');
      if (kvData) return { data: kvData, source: 'KV-HIT' };
    } catch (e) { /* KV 실패 시 무시, 다음 레이어로 */ }
  }

  // 2차: Cache API
  if (cacheKey) {
    try {
      const cache = caches.default;
      const cachedResponse = await cache.match(cacheKey);
      if (cachedResponse) {
        const text = await cachedResponse.text();
        return { data: text, source: 'HIT' };
      }
    } catch (e) { /* Cache API 실패 시 무시 */ }
  }

  return { data: null, source: 'MISS' };
}

/**
 * 통합 캐시 저장: KV + Cache API에 동시 저장
 *
 * @param {Object} env           - Worker 환경 (env.CACHE_KV)
 * @param {string|null} kvKey    - KV 키 (null이면 KV 저장 건너뜀)
 * @param {number|null} kvTTL    - KV TTL (초 단위)
 * @param {Request|null} cacheKey - Cache API 키 (null이면 Cache API 건너뜀)
 * @param {number} cacheTTL      - Cache API TTL (초 단위)
 * @param {string} data          - 저장할 JSON 문자열
 */
export async function setCached(env, kvKey, kvTTL, cacheKey, cacheTTL, data) {
  const promises = [];

  // KV 저장
  if (kvKey && env.CACHE_KV) {
    const kvPromise = env.CACHE_KV.put(kvKey, data,
      kvTTL ? { expirationTtl: kvTTL } : undefined
    ).catch(e => console.error('[KV] Write failed:', e.message));
    promises.push(kvPromise);
  }

  // Cache API 저장
  if (cacheKey && cacheTTL) {
    const responseToCache = new Response(data, {
      status: 200,
      headers: {
        'Content-Type': 'application/json',
        'Cache-Control': `public, max-age=${cacheTTL}`,
      },
    });
    const cachePromise = caches.default.put(cacheKey, responseToCache)
      .catch(e => console.error('[Cache API] Write failed:', e.message));
    promises.push(cachePromise);
  }

  await Promise.allSettled(promises);
}
