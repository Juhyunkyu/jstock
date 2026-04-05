/**
 * DeepL 번역 프록시 (KV 공유 캐시)
 *
 * 텍스트별 SHA-256 해시로 KV에 영구 저장.
 * 같은 텍스트는 DeepL 호출 없이 KV에서 반환.
 * KV 없거나 실패 시 기존 동작(직접 DeepL 호출)과 동일.
 */

import { corsHeaders } from '../utils/cors.js';
import { jsonError } from '../utils/helpers.js';

/**
 * 텍스트의 SHA-256 해시 (hex 앞 16자)
 */
async function hashText(text) {
  const encoder = new TextEncoder();
  const data = encoder.encode(text);
  const hashBuffer = await crypto.subtle.digest('SHA-256', data);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  return hashArray.slice(0, 8).map(b => b.toString(16).padStart(2, '0')).join('');
}

export async function handleDeepL(request, env) {
  if (request.method !== 'POST') {
    return jsonError('POST only', 405, request);
  }

  const apiKey = env.DEEPL_API_KEY;
  if (!apiKey) return jsonError('DEEPL_API_KEY not configured', 500, request);

  // 요청 본문 파싱
  let body;
  try {
    body = await request.json();
  } catch (e) {
    return jsonError('Invalid JSON body', 400, request);
  }

  const texts = body.text;
  const sourceLang = body.source_lang || 'EN';
  const targetLang = body.target_lang || 'KO';

  if (!Array.isArray(texts) || texts.length === 0) {
    return jsonError('text array required', 400, request);
  }

  // KV 캐시 확인 (텍스트별)
  const results = new Array(texts.length).fill(null);
  const uncachedTexts = [];
  const uncachedIndices = [];

  if (env.CACHE_KV) {
    for (let i = 0; i < texts.length; i++) {
      try {
        const hash = await hashText(texts[i]);
        const kvKey = `translate:${sourceLang}:${targetLang}:${hash}`;
        const cached = await env.CACHE_KV.get(kvKey);
        if (cached) {
          results[i] = { text: cached };
          continue;
        }
      } catch (e) { /* KV 실패 시 번역 진행 */ }

      uncachedTexts.push(texts[i]);
      uncachedIndices.push(i);
    }

    // 전부 캐시 히트면 즉시 반환
    if (uncachedTexts.length === 0) {
      return new Response(JSON.stringify({ translations: results }), {
        status: 200,
        headers: {
          'Content-Type': 'application/json',
          'X-Cache': 'KV-HIT',
          ...corsHeaders(request),
        },
      });
    }
  } else {
    // KV 없으면 전부 번역
    for (let i = 0; i < texts.length; i++) {
      uncachedTexts.push(texts[i]);
      uncachedIndices.push(i);
    }
  }

  // 미캐시 텍스트만 DeepL 호출
  const resp = await fetch('https://api-free.deepl.com/v2/translate', {
    method: 'POST',
    headers: {
      'Authorization': `DeepL-Auth-Key ${apiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      text: uncachedTexts,
      source_lang: sourceLang,
      target_lang: targetLang,
    }),
  });

  if (!resp.ok) {
    return new Response(resp.body, {
      status: resp.status,
      headers: {
        'Content-Type': resp.headers.get('Content-Type') || 'application/json',
        ...corsHeaders(request),
      },
    });
  }

  const deeplResult = await resp.json();
  const translations = deeplResult.translations || [];

  // 결과 병합 + KV 저장
  for (let j = 0; j < uncachedIndices.length && j < translations.length; j++) {
    const idx = uncachedIndices[j];
    const translated = translations[j];
    results[idx] = translated;

    // KV에 영구 저장 (번역은 변하지 않음)
    if (env.CACHE_KV && translated?.text) {
      try {
        const hash = await hashText(texts[idx]);
        const kvKey = `translate:${sourceLang}:${targetLang}:${hash}`;
        await env.CACHE_KV.put(kvKey, translated.text);
      } catch (e) { /* KV 쓰기 실패 무시 */ }
    }
  }

  return new Response(JSON.stringify({ translations: results }), {
    status: 200,
    headers: {
      'Content-Type': 'application/json',
      'X-Cache': uncachedTexts.length < texts.length ? 'PARTIAL-HIT' : 'MISS',
      ...corsHeaders(request),
    },
  });
}
