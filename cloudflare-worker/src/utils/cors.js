/**
 * CORS 설정 및 헤더 생성
 */

export const ALLOWED_ORIGINS = [
  'https://juhyunkyu.github.io',
  'http://localhost:8080',
  'http://localhost:3000',
];

export function corsHeaders(request) {
  const origin = request.headers.get('Origin') || '';
  if (!ALLOWED_ORIGINS.includes(origin)) return {};
  return {
    'Access-Control-Allow-Origin': origin,
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
    'Access-Control-Max-Age': '86400',
  };
}
