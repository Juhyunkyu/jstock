/**
 * 공통 헬퍼 함수
 */

import { corsHeaders } from './cors.js';

export function jsonError(message, status, request) {
  return new Response(JSON.stringify({ error: message }), {
    status,
    headers: { 'Content-Type': 'application/json', ...corsHeaders(request) },
  });
}
