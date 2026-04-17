#!/usr/bin/env node
/**
 * VAPID JWT 서명 검증 테스트
 *
 * 검증 대상: src/cron/alert-check.js :: createVapidJWT
 *
 * 검증 항목:
 *   1) JWK 경유 ECDSA P-256 private key import가 throw 없이 성공하는지
 *   2) JWT 구조(header.payload.signature)가 올바른지
 *   3) header/payload 디코드 시 alg=ES256, typ=JWT, aud/exp/sub가 의도대로 들어있는지
 *   4) signature가 raw r||s 64바이트 형식인지 (ES256 VAPID 사양)
 *   5) 동일 공개키로 crypto.subtle.verify가 true를 반환하는지 (실제 Push Service 수용 조건과 동일)
 *   6) 기존 'raw' import 방식이 실제로 throw하는지 (회귀 방지)
 *
 * 실행:
 *   node scripts/test-vapid-jwt.mjs
 *
 * 환경: Node v22+ (WebCrypto 내장)
 */

import { webcrypto } from 'node:crypto';
import crypto from 'node:crypto';

// Node WebCrypto를 globalThis.crypto로 노출 (createVapidJWT는 global crypto 사용)
if (!globalThis.crypto) globalThis.crypto = webcrypto;
if (!globalThis.btoa) globalThis.btoa = (b) => Buffer.from(b, 'binary').toString('base64');
if (!globalThis.atob) globalThis.atob = (b) => Buffer.from(b, 'base64').toString('binary');

const { createVapidJWT } = await import('../src/cron/alert-check.js');
const { arrayBufferToBase64Url } = await import('../src/cron/push-crypto.js');

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

function b64urlDecodeToString(b64url) {
  return Buffer.from(b64url.replace(/-/g, '+').replace(/_/g, '/'), 'base64').toString('utf8');
}
function b64urlDecodeToBytes(b64url) {
  return new Uint8Array(Buffer.from(b64url.replace(/-/g, '+').replace(/_/g, '/'), 'base64'));
}

// ── VAPID 키쌍 생성 (raw 32바이트 private, 65바이트 uncompressed public) ──

function generateVapidKeyPairRaw() {
  // Node의 createECDH로 결정론적 raw 추출 (Cloudflare Worker 런타임의 secrets와 동일 형태)
  const ecdh = crypto.createECDH('prime256v1');
  const publicRaw = ecdh.generateKeys(); // Buffer 65B (uncompressed, starts with 0x04)
  let privateRaw = ecdh.getPrivateKey(); // Buffer, 보통 32B (가끔 leading-zero trim으로 <32)
  if (privateRaw.length < 32) {
    privateRaw = Buffer.concat([Buffer.alloc(32 - privateRaw.length), privateRaw]);
  }
  return {
    publicBase64Url: Buffer.from(publicRaw).toString('base64url'),
    privateBase64Url: Buffer.from(privateRaw).toString('base64url'),
    publicRaw: new Uint8Array(publicRaw),
    privateRaw: new Uint8Array(privateRaw),
  };
}

// ── 테스트 1: 수정된 createVapidJWT가 throw 없이 JWT를 반환하는지 ─────────

async function testJwtGenerationSucceeds() {
  console.log('\n[Test 1] createVapidJWT: JWK import로 throw 없이 JWT 반환');

  const { publicBase64Url, privateBase64Url } = generateVapidKeyPairRaw();
  const audience = 'https://fcm.googleapis.com';
  const subject = 'mailto:sekang1984@gmail.com';

  let jwt;
  try {
    jwt = await createVapidJWT(audience, subject, privateBase64Url, publicBase64Url);
    ok('createVapidJWT returned a value');
  } catch (e) {
    fail('createVapidJWT threw', `${e.name}: ${e.message}`);
    return null;
  }

  // JWT 구조: header.payload.signature (3 parts, base64url)
  const parts = jwt.split('.');
  assert('JWT has 3 parts (header.payload.signature)', parts.length === 3,
    `got ${parts.length} parts`);

  return { jwt, publicBase64Url, privateBase64Url, audience, subject };
}

// ── 테스트 2: JWT payload/header 구조 검증 ───────────────────────────────

function testJwtStructure({ jwt, audience, subject }) {
  console.log('\n[Test 2] JWT header/payload 구조 검증');

  const [headerB64, payloadB64, sigB64] = jwt.split('.');

  const header = JSON.parse(b64urlDecodeToString(headerB64));
  const payload = JSON.parse(b64urlDecodeToString(payloadB64));

  assert('header.alg === ES256', header.alg === 'ES256', `got ${header.alg}`);
  assert('header.typ === JWT', header.typ === 'JWT', `got ${header.typ}`);
  assert('payload.aud === audience', payload.aud === audience, `got ${payload.aud}`);
  assert('payload.sub === subject', payload.sub === subject, `got ${payload.sub}`);

  const now = Math.floor(Date.now() / 1000);
  assert('payload.exp is in the future', payload.exp > now, `exp=${payload.exp}, now=${now}`);
  assert('payload.exp <= now + 24h', payload.exp <= now + 86400 + 5,
    `exp=${payload.exp}, max=${now + 86400 + 5}`);

  // Signature: ES256 raw r||s = 64바이트
  const sigBytes = b64urlDecodeToBytes(sigB64);
  assert('signature length === 64 bytes (ES256 raw r||s)', sigBytes.length === 64,
    `got ${sigBytes.length} bytes`);

  return { headerB64, payloadB64, sigB64, sigBytes };
}

// ── 테스트 3: 공개키로 서명 검증 (Push Service 수용 조건과 동일) ─────────

async function testSignatureVerifiable({ jwt, publicBase64Url }) {
  console.log('\n[Test 3] crypto.subtle.verify로 서명 유효성 확인');

  const [headerB64, payloadB64, sigB64] = jwt.split('.');
  const unsigned = `${headerB64}.${payloadB64}`;
  const sigBytes = b64urlDecodeToBytes(sigB64);

  // 공개키 import: 'raw' format + ECDSA는 spec상 허용됨 (public key only)
  const pubRaw = b64urlDecodeToBytes(publicBase64Url);
  assert('public key is 65 bytes uncompressed', pubRaw.length === 65 && pubRaw[0] === 0x04,
    `len=${pubRaw.length}, prefix=0x${pubRaw[0]?.toString(16)}`);

  let publicKey;
  try {
    publicKey = await crypto.subtle.importKey(
      'raw',
      pubRaw,
      { name: 'ECDSA', namedCurve: 'P-256' },
      false,
      ['verify']
    );
    ok('public key import (raw + verify) succeeded');
  } catch (e) {
    fail('public key import failed', `${e.name}: ${e.message}`);
    return;
  }

  const valid = await crypto.subtle.verify(
    { name: 'ECDSA', hash: 'SHA-256' },
    publicKey,
    sigBytes,
    new TextEncoder().encode(unsigned)
  );
  assert('signature verifies against public key', valid === true, `verify returned ${valid}`);
}

// ── 테스트 4: 기존 'raw' private import가 실제로 throw하는지 (회귀 방지) ──

async function testOldRawImportStillFails() {
  console.log("\n[Test 4] 회귀 방지: 'raw' + ECDSA + private (sign) 조합은 여전히 throw");

  const { privateRaw } = generateVapidKeyPairRaw();
  let threw = false;
  let errMsg = '';
  try {
    await crypto.subtle.importKey(
      'raw',
      privateRaw,
      { name: 'ECDSA', namedCurve: 'P-256' },
      false,
      ['sign']
    );
  } catch (e) {
    threw = true;
    errMsg = `${e.name}: ${e.message}`;
  }
  assert("importKey('raw', ECDSA, ['sign']) throws — spec-enforced", threw,
    threw ? '' : 'DID NOT THROW (WebCrypto spec violation detected)');
  if (threw) console.log(`      observed: ${errMsg}`);
}

// ── 테스트 5: 여러 랜덤 키쌍으로 반복 검증 ─────────────────────────────

async function testMultipleRandomKeys() {
  console.log('\n[Test 5] 여러 랜덤 VAPID 키쌍으로 반복 검증 (5회)');

  for (let i = 1; i <= 5; i++) {
    const { publicBase64Url, privateBase64Url } = generateVapidKeyPairRaw();
    const aud = `https://push.example-${i}.com`;
    const sub = `mailto:test-${i}@example.com`;

    let jwt;
    try {
      jwt = await createVapidJWT(aud, sub, privateBase64Url, publicBase64Url);
    } catch (e) {
      fail(`trial ${i}: createVapidJWT threw`, `${e.name}: ${e.message}`);
      continue;
    }

    const [h, p, s] = jwt.split('.');
    const sigBytes = b64urlDecodeToBytes(s);
    if (sigBytes.length !== 64) {
      fail(`trial ${i}: signature length`, `got ${sigBytes.length}`);
      continue;
    }

    const pubRaw = b64urlDecodeToBytes(publicBase64Url);
    const publicKey = await crypto.subtle.importKey(
      'raw', pubRaw,
      { name: 'ECDSA', namedCurve: 'P-256' },
      false, ['verify']
    );
    const valid = await crypto.subtle.verify(
      { name: 'ECDSA', hash: 'SHA-256' },
      publicKey,
      sigBytes,
      new TextEncoder().encode(`${h}.${p}`)
    );
    if (valid) ok(`trial ${i}: JWT signs + verifies (sig=64B, aud=${aud})`);
    else fail(`trial ${i}: verify returned false`);
  }
}

// ── 실행 ─────────────────────────────────────────────────────────────────

async function main() {
  console.log('═══════════════════════════════════════════════════════');
  console.log('  VAPID JWT (ES256) 서명 검증');
  console.log('═══════════════════════════════════════════════════════');

  try {
    const ctx1 = await testJwtGenerationSucceeds();
    if (ctx1) {
      testJwtStructure(ctx1);
      await testSignatureVerifiable(ctx1);
    }
    await testOldRawImportStillFails();
    await testMultipleRandomKeys();
  } catch (e) {
    console.error('\n[FATAL] 테스트 실행 중 예외:');
    console.error(e);
    process.exit(2);
  }

  console.log('\n═══════════════════════════════════════════════════════');
  console.log(`  Results:  PASS=${PASS}   FAIL=${FAIL}`);
  console.log('═══════════════════════════════════════════════════════\n');
  process.exit(FAIL === 0 ? 0 : 1);
}

main();
