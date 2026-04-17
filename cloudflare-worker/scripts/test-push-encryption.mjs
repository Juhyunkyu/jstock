#!/usr/bin/env node
/**
 * RFC 8291 aes128gcm Web Push 암호화 검증 테스트
 *
 * 검증 대상: src/cron/push-crypto.js :: encryptPayloadDeterministic
 *
 * 검증 방법:
 *   1) RFC 8291 Appendix A 테스트 벡터와 중간값(IKM, PRK, CEK, NONCE) + 최종 body 전체 비교
 *   2) 랜덤 입력에 대해 http_ece (web-push가 내부적으로 쓰는 검증된 구현) 출력과 바이트 비교
 *
 * 실행:
 *   node scripts/test-push-encryption.mjs
 *
 * 환경: Node v22+ (WebCrypto 내장)
 */

import { webcrypto } from 'node:crypto';
import ece from 'http_ece';
import crypto from 'node:crypto';

// Node WebCrypto를 globalThis.crypto로 노출 — push-crypto.js는 global crypto 사용
if (!globalThis.crypto) {
  globalThis.crypto = webcrypto;
}
// btoa/atob shim (Node 22 이미 있음, 안전장치)
if (!globalThis.btoa) {
  globalThis.btoa = (b) => Buffer.from(b, 'binary').toString('base64');
}
if (!globalThis.atob) {
  globalThis.atob = (b) => Buffer.from(b, 'base64').toString('binary');
}

const {
  encryptPayloadDeterministic,
  base64UrlToArrayBuffer,
  hkdfExtract,
  hkdfExpand,
} = await import('../src/cron/push-crypto.js');

// ── 유틸 ─────────────────────────────────────────────────────────────────

function b64urlToBuf(s) {
  return Buffer.from(s.replace(/-/g, '+').replace(/_/g, '/'), 'base64');
}
function bufToHex(buf) {
  return Buffer.from(buf).toString('hex');
}
function bufToB64url(buf) {
  return Buffer.from(buf).toString('base64url');
}
function eqBytes(a, b) {
  const ba = Buffer.from(a);
  const bb = Buffer.from(b);
  return ba.length === bb.length && ba.equals(bb);
}

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
function assertEqBytes(name, actual, expected) {
  if (eqBytes(actual, expected)) ok(name);
  else {
    fail(
      name,
      `\n      expected: ${bufToHex(expected)}\n      actual:   ${bufToHex(actual)}`
    );
  }
}

// ── RFC 8291 Appendix A 벡터 ─────────────────────────────────────────────
// https://datatracker.ietf.org/doc/html/rfc8291#appendix-A
const RFC = {
  plaintext: 'When I grow up, I want to be a watermelon',

  // UA (구독자)
  ua_public: 'BCVxsr7N_eNgVRqvHtD0zTZsEc6-VV-JvLexhqUzORcxaOzi6-AYWXvTBHm4bjyPjs7Vd8pZGH6SRpkNtoIAiw4',
  ua_private: 'q1dXpw3UpT5VOmu_cf_v6ih07Aems3njxI-JWgLcM94',
  auth_secret: 'BTBZMqHH6r4Tts7J_aSIgg',

  // AS (발신 서버) — Appendix A는 고정 키 사용
  as_public: 'BP4z9KsN6nGRTbVYI_c7VJSPQTBtkgcy27mlmlMoZIIgDll6e3vCYLocInmYWAmS6TlzAC8wEqKK6PBru3jl7A8',
  as_private: 'yfWPiYE-n46HLnH0KqZOF1fJJU3MYrct3AELtAQ-oRw',

  salt: 'DGv6ra1nlYgDCS1FRnbzlw',

  // 예상 중간값 (RFC 8291 Appendix A)
  ecdh_secret_hex: 'fbcfc0c8e3654560ecb24d9ed7d2b4d1b897a52b96fd2f4bcfa18d75e3b27b8a'.toUpperCase(), // §A placeholder — 실제 값은 아래에서 확인
};

// RFC 8291 Appendix A "Intermediate Values for Encryption" (authoritative)
// https://www.rfc-editor.org/rfc/rfc8291#appendix-A
// 모든 값은 base64url로 RFC에 명시되어 있다. 바이트 단위 비교가 truth of ground.
const RFC_EXPECTED = {
  ecdh_secret_b64url: 'kyrL1jIIOHEzg3sM2ZWRHDRB62YACZhhSlknJ672kSs',
  prk_key_b64url:     'Snr3JMxaHVDXHWJn5wdC52WjpCtd2EIEGBykDcZW32k',
  ikm_b64url:         'S4lYMb_L0FxCeq0WhDx813KgSYqU26kOyzWUdsXYyrg',
  prk_b64url:         '09_eUZGrsvxChDCGRCdkLiDXrReGOEVeSCdCcPBSJSc',
  cek_b64url:         'oIhVW04MRdy2XN9CiKLxTg',
  nonce_b64url:       '4h_95klXJ5E_qnoN',
  // 최종 ciphertext (header 제외, AES-GCM output = padded||tag)
  ciphertext_b64url:
    '8pfeW0KbunFT06SuDKoJH9Ql87S1QUrdirN6GcG7sFz1y1sqLgVi1VhjVkHsUoEsbI_0LpXMuGvnzQ',
};

// ── 테스트 1: RFC 8291 Appendix A 벡터 ───────────────────────────────────

async function testRfcAppendixA() {
  console.log('\n[Test 1] RFC 8291 Appendix A 테스트 벡터');

  const clientPublicKey = new Uint8Array(b64urlToBuf(RFC.ua_public));
  const authSecret = new Uint8Array(b64urlToBuf(RFC.auth_secret));
  const salt = new Uint8Array(b64urlToBuf(RFC.salt));
  const serverPrivate = new Uint8Array(b64urlToBuf(RFC.as_private));
  const serverPublic = new Uint8Array(b64urlToBuf(RFC.as_public));

  const { body, debug } = await encryptPayloadDeterministic({
    payload: RFC.plaintext,
    clientPublicKey,
    authSecret,
    salt,
    serverPrivateKeyRaw: serverPrivate,
    serverPublicKeyRaw: serverPublic,
  });

  // 중간값 덤프
  console.log(`    ecdh_secret  (hex): ${bufToHex(debug.sharedSecret)}`);
  console.log(`    PRK_key      (hex): ${bufToHex(debug.prkKey)}`);
  console.log(`    IKM          (hex): ${bufToHex(debug.ikm)}`);
  console.log(`    PRK          (hex): ${bufToHex(debug.prk)}`);
  console.log(`    CEK          (hex): ${bufToHex(debug.cek)}`);
  console.log(`    NONCE        (hex): ${bufToHex(debug.nonce)}`);
  console.log(`    body        (b64u): ${bufToB64url(body)}`);

  // 모든 중간값을 RFC 8291 Appendix A와 바이트 비교
  assertEqBytes('ecdh_secret  == RFC §A', debug.sharedSecret, b64urlToBuf(RFC_EXPECTED.ecdh_secret_b64url));
  assertEqBytes('PRK_key      == RFC §A', debug.prkKey,       b64urlToBuf(RFC_EXPECTED.prk_key_b64url));
  assertEqBytes('IKM          == RFC §A', debug.ikm,          b64urlToBuf(RFC_EXPECTED.ikm_b64url));
  assertEqBytes('PRK          == RFC §A', debug.prk,          b64urlToBuf(RFC_EXPECTED.prk_b64url));
  assertEqBytes('CEK          == RFC §A', debug.cek,          b64urlToBuf(RFC_EXPECTED.cek_b64url));
  assertEqBytes('NONCE        == RFC §A', debug.nonce,        b64urlToBuf(RFC_EXPECTED.nonce_b64url));

  // 최종 ciphertext(AES-GCM output) 비교
  // body = header(21 + 65 = 86 bytes) || ciphertext
  const headerLen = 21 + 65;
  const ciphertext = body.slice(headerLen);
  assertEqBytes(
    'ciphertext  == RFC §A (AES-GCM output)',
    ciphertext,
    b64urlToBuf(RFC_EXPECTED.ciphertext_b64url)
  );
}

// ── 테스트 2: http_ece와의 상호 검증 (랜덤 입력) ─────────────────────────

async function testCrossValidationWithHttpEce() {
  console.log('\n[Test 2] http_ece와의 상호 검증 (랜덤 입력 5회)');

  for (let trial = 1; trial <= 5; trial++) {
    // 랜덤 subscription 생성 (ua)
    const uaEcdh = crypto.createECDH('prime256v1');
    const uaPublic = uaEcdh.generateKeys(); // Buffer 65B
    const uaPrivate = uaEcdh.getPrivateKey(); // Buffer 32B (0-padded)
    const uaPrivatePadded = Buffer.concat([
      Buffer.alloc(32 - uaPrivate.length),
      uaPrivate,
    ]);
    const authSecret = crypto.randomBytes(16);

    // 랜덤 서버 키쌍 (as)
    const asEcdh = crypto.createECDH('prime256v1');
    const asPublic = asEcdh.generateKeys();
    const asPrivate = asEcdh.getPrivateKey();
    const asPrivatePadded = Buffer.concat([
      Buffer.alloc(32 - asPrivate.length),
      asPrivate,
    ]);

    const salt = crypto.randomBytes(16);
    const payload = `trial-${trial}: Hello, RFC 8291! ${crypto.randomUUID()}`;

    // (a) http_ece.encrypt — reference
    ece.keylookup = undefined;
    const ref = ece.encrypt(Buffer.from(payload), {
      version: 'aes128gcm',
      dh: uaPublic.toString('base64url'),
      privateKey: asEcdh,
      salt: salt.toString('base64url'),
      authSecret: authSecret.toString('base64url'),
    });

    // (b) push-crypto.encryptPayloadDeterministic
    const { body } = await encryptPayloadDeterministic({
      payload,
      clientPublicKey: new Uint8Array(uaPublic),
      authSecret: new Uint8Array(authSecret),
      salt: new Uint8Array(salt),
      serverPrivateKeyRaw: new Uint8Array(asPrivatePadded),
      serverPublicKeyRaw: new Uint8Array(asPublic),
    });

    assertEqBytes(`trial ${trial}: body matches http_ece`, body, ref);
  }
}

// ── 테스트 3: UA 개인키로 실제 복호화 성공 여부 ──────────────────────────

async function testRoundtripDecryption() {
  console.log('\n[Test 3] UA 개인키로 복호화 round-trip');

  for (let trial = 1; trial <= 3; trial++) {
    const uaEcdh = crypto.createECDH('prime256v1');
    const uaPublic = uaEcdh.generateKeys();
    const uaPrivate = uaEcdh.getPrivateKey();
    const uaPrivatePadded = Buffer.concat([
      Buffer.alloc(32 - uaPrivate.length),
      uaPrivate,
    ]);
    const authSecret = crypto.randomBytes(16);

    const asEcdh = crypto.createECDH('prime256v1');
    const asPublic = asEcdh.generateKeys();
    const asPrivate = asEcdh.getPrivateKey();
    const asPrivatePadded = Buffer.concat([
      Buffer.alloc(32 - asPrivate.length),
      asPrivate,
    ]);
    const salt = crypto.randomBytes(16);
    const payload = `roundtrip-${trial}: ${crypto.randomUUID()}`;

    const { body } = await encryptPayloadDeterministic({
      payload,
      clientPublicKey: new Uint8Array(uaPublic),
      authSecret: new Uint8Array(authSecret),
      salt: new Uint8Array(salt),
      serverPrivateKeyRaw: new Uint8Array(asPrivatePadded),
      serverPublicKeyRaw: new Uint8Array(asPublic),
    });

    // http_ece.decrypt를 "구독자 쪽"에서 실행해 복호화
    const decrypted = ece.decrypt(Buffer.from(body), {
      version: 'aes128gcm',
      privateKey: uaEcdh,
      authSecret: authSecret.toString('base64url'),
    });

    if (decrypted.toString() === payload) {
      ok(`trial ${trial}: UA가 복호화 성공 ("${payload.slice(0, 40)}...")`);
    } else {
      fail(
        `trial ${trial}: UA 복호화 결과 불일치`,
        `\n      expected: ${payload}\n      actual:   ${decrypted.toString()}`
      );
    }
  }
}

// ── 테스트 4: HKDF 원시 연산 sanity check ────────────────────────────────

async function testHkdfSanity() {
  console.log('\n[Test 4] HKDF-Extract / HKDF-Expand sanity (RFC 5869 벡터)');

  // RFC 5869 §A.1 Test Case 1 (SHA-256)
  const ikm = Buffer.from('0b'.repeat(22), 'hex'); // 22 bytes of 0x0b
  const salt = Buffer.from('000102030405060708090a0b0c', 'hex');
  const info = Buffer.from('f0f1f2f3f4f5f6f7f8f9', 'hex');
  const expectedPRK = Buffer.from(
    '077709362c2e32df0ddc3f0dc47bba6390b6c73bb50f9c3122ec844ad7c2b3e5',
    'hex'
  );
  const expectedOKM42 = Buffer.from(
    '3cb25f25faacd57a90434f64d0362f2a2d2d0a90cf1a5a4c5db02d56ecc4c5bf34007208d5b887185865',
    'hex'
  );

  const prk = await hkdfExtract(new Uint8Array(salt), new Uint8Array(ikm));
  assertEqBytes('HKDF-Extract matches RFC 5869 TC1', prk, expectedPRK);

  // push-crypto.hkdfExpand는 1라운드(≤32)만 지원 — 32바이트만 검증
  const okm32 = await hkdfExpand(new Uint8Array(prk), new Uint8Array(info), 32);
  assertEqBytes(
    'HKDF-Expand(32) matches RFC 5869 TC1 first 32 bytes',
    okm32,
    expectedOKM42.slice(0, 32)
  );
}

// ── 실행 ─────────────────────────────────────────────────────────────────

async function main() {
  console.log('═══════════════════════════════════════════════════════');
  console.log('  RFC 8291 Web Push aes128gcm 암호화 검증');
  console.log('═══════════════════════════════════════════════════════');

  try {
    await testHkdfSanity();
    await testRfcAppendixA();
    await testCrossValidationWithHttpEce();
    await testRoundtripDecryption();
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
