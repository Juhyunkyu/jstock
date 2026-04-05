/**
 * Finnhub API Rate Limiter (메모리 기반, Worker 인스턴스별)
 *
 * Worker는 여러 인스턴스에서 실행될 수 있으므로 완벽하지 않지만,
 * 한국 사용자 100명은 대부분 같은 리전이고 캐시 히트율이 높으면 충분.
 *
 * @exports canCall     - 현재 호출 가능 여부 확인
 * @exports recordCall  - 호출 기록
 */

const state = {
  calls: [],          // 최근 1분간 API 호출 timestamp
  maxPerMinute: 55,   // 60 한도에서 여유분 5 확보
};

export function canCall() {
  const now = Date.now();
  state.calls = state.calls.filter(t => now - t < 60_000);
  return state.calls.length < state.maxPerMinute;
}

export function recordCall() {
  state.calls.push(Date.now());
}
