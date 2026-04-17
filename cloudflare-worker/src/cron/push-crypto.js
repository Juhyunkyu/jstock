/**
 * RFC 8291 Web Push 페이로드 암호화 (aes128gcm)
 *
 * 사양:
 *   - RFC 8291 §3.3 Step 1: UA/AS 공개키를 포함한 key_info로 IKM 도출
 *   - RFC 8188 §2.2: aes128gcm Content-Encoding
 *   - Padding: RFC 8188 §2 — plaintext || 0x02 (last record delimiter)
 *
 * 참고:
 *   - 구버전 "Content-Encoding: auth\0"는 aesgcm draft (deprecated)
 *   - 현재 aes128gcm은 UA/AS 공개키를 key_info에 직접 포함
 *
 * 공개 API:
 *   - encryptPayload(payload, p256dhBase64, authBase64)
 *       → 프로덕션용. ephemeral 키쌍과 salt를 내부에서 랜덤 생성.
 *   - encryptPayloadDeterministic({ payload, clientPublicKey, authSecret, salt, serverPrivateKeyRaw, serverPublicKeyRaw })
 *       → 테스트용. 모든 입력을 고정하여 결정론적 출력 보장.
 */

// ── 공개 API ─────────────────────────────────────────────────────────────

/**
 * 프로덕션 암호화: ephemeral 서버 키쌍과 salt를 랜덤 생성한다.
 * @param {string} payload UTF-8 평문
 * @param {string} p256dhBase64 클라이언트 공개키 (base64url, 65바이트)
 * @param {string} authBase64 클라이언트 auth secret (base64url, 16바이트)
 * @returns {Promise<ArrayBuffer>} aes128gcm body (header + ciphertext)
 */
export async function encryptPayload(payload, p256dhBase64, authBase64) {
  const clientPublicKey = base64UrlToArrayBuffer(p256dhBase64);
  const authSecret = base64UrlToArrayBuffer(authBase64);

  const serverKeys = await crypto.subtle.generateKey(
    { name: 'ECDH', namedCurve: 'P-256' },
    true,
    ['deriveBits']
  );
  const serverPublicKeyRaw = await crypto.subtle.exportKey('raw', serverKeys.publicKey);
  // 서버 개인키는 deriveBits로만 쓰므로 CryptoKey 참조 유지. 결정론 경로에서는 raw private도 사용.

  const clientKey = await crypto.subtle.importKey(
    'raw',
    clientPublicKey,
    { name: 'ECDH', namedCurve: 'P-256' },
    false,
    []
  );
  const sharedSecret = await crypto.subtle.deriveBits(
    { name: 'ECDH', public: clientKey },
    serverKeys.privateKey,
    256
  );

  const salt = crypto.getRandomValues(new Uint8Array(16));

  return await encryptCore({
    payload,
    clientPublicKey: new Uint8Array(clientPublicKey),
    authSecret: new Uint8Array(authSecret),
    sharedSecret: new Uint8Array(sharedSecret),
    salt,
    serverPublicKeyRaw: new Uint8Array(serverPublicKeyRaw),
  });
}

/**
 * 결정론적 암호화 (테스트용). RFC 8291 Appendix A 벡터 검증에 사용.
 *
 * @param {object} params
 * @param {string} params.payload UTF-8 평문
 * @param {Uint8Array} params.clientPublicKey 65바이트 uncompressed P-256 공개키
 * @param {Uint8Array} params.authSecret 16바이트 auth secret
 * @param {Uint8Array} params.salt 16바이트 salt
 * @param {Uint8Array} params.serverPrivateKeyRaw 32바이트 서버 개인키 (d)
 * @param {Uint8Array} params.serverPublicKeyRaw 65바이트 서버 공개키
 * @returns {Promise<{ ciphertext: Uint8Array, body: Uint8Array, debug: object }>}
 */
export async function encryptPayloadDeterministic({
  payload,
  clientPublicKey,
  authSecret,
  salt,
  serverPrivateKeyRaw,
  serverPublicKeyRaw,
}) {
  // Node(WebCrypto)와 Cloudflare Workers 모두에서 raw private P-256을 importKey하려면
  // PKCS#8 또는 JWK 형태가 필요하다. JWK가 이식성 높음.
  const serverPrivateJwk = rawP256PrivateToJwk(serverPrivateKeyRaw, serverPublicKeyRaw);
  const serverPrivate = await crypto.subtle.importKey(
    'jwk',
    serverPrivateJwk,
    { name: 'ECDH', namedCurve: 'P-256' },
    false,
    ['deriveBits']
  );

  const clientKey = await crypto.subtle.importKey(
    'raw',
    clientPublicKey,
    { name: 'ECDH', namedCurve: 'P-256' },
    false,
    []
  );
  const sharedSecret = new Uint8Array(
    await crypto.subtle.deriveBits({ name: 'ECDH', public: clientKey }, serverPrivate, 256)
  );

  return await encryptCore({
    payload,
    clientPublicKey,
    authSecret,
    sharedSecret,
    salt,
    serverPublicKeyRaw,
    emitDebug: true,
  });
}

// ── 내부 구현 ────────────────────────────────────────────────────────────

async function encryptCore({
  payload,
  clientPublicKey,
  authSecret,
  sharedSecret,
  salt,
  serverPublicKeyRaw,
  emitDebug = false,
}) {
  // RFC 8291 §3.3 Step 1
  //   PRK_key = HKDF-Extract(salt=auth_secret, IKM=ecdh_shared_secret)
  //   key_info = "WebPush: info" || 0x00 || ua_public(65) || as_public(65)
  //   IKM = HKDF-Expand(PRK_key, key_info, 32)
  const webPushInfoPrefix = new TextEncoder().encode('WebPush: info\0'); // 14 bytes
  const keyInfoPRK = new Uint8Array(webPushInfoPrefix.length + 65 + 65);
  keyInfoPRK.set(webPushInfoPrefix, 0);
  keyInfoPRK.set(clientPublicKey, webPushInfoPrefix.length);
  keyInfoPRK.set(serverPublicKeyRaw, webPushInfoPrefix.length + 65);

  const prkKey = await hkdfExtract(authSecret, sharedSecret);
  const ikm = await hkdfExpand(prkKey, keyInfoPRK, 32);

  // RFC 8188 §2.2 (aes128gcm)
  //   PRK = HKDF-Extract(salt=random_salt, IKM)
  //   CEK = HKDF-Expand(PRK, "Content-Encoding: aes128gcm\0", 16)
  //   NONCE = HKDF-Expand(PRK, "Content-Encoding: nonce\0", 12)
  const keyInfo = new TextEncoder().encode('Content-Encoding: aes128gcm\0');
  const nonceInfo = new TextEncoder().encode('Content-Encoding: nonce\0');

  const prk = await hkdfExtract(salt, ikm);
  const cek = await hkdfExpand(prk, keyInfo, 16);
  const nonce = await hkdfExpand(prk, nonceInfo, 12);

  // AES-128-GCM
  const paddedPayload = addPadding(new TextEncoder().encode(payload));
  const aesKey = await crypto.subtle.importKey('raw', cek, { name: 'AES-GCM' }, false, ['encrypt']);
  const encrypted = new Uint8Array(
    await crypto.subtle.encrypt({ name: 'AES-GCM', iv: nonce }, aesKey, paddedPayload)
  );

  // aes128gcm header: salt(16) || rs(4, big-endian) || idlen(1) || keyid(=as_public, 65)
  const header = new Uint8Array(21 + serverPublicKeyRaw.byteLength);
  header.set(salt, 0);
  // rs = 4096 as uint32 big-endian
  header[16] = 0x00;
  header[17] = 0x00;
  header[18] = 0x10;
  header[19] = 0x00;
  header[20] = serverPublicKeyRaw.byteLength;
  header.set(serverPublicKeyRaw, 21);

  const body = new Uint8Array(header.length + encrypted.length);
  body.set(header, 0);
  body.set(encrypted, header.length);

  if (emitDebug) {
    return {
      ciphertext: encrypted,
      body,
      debug: {
        sharedSecret,
        prkKey,
        ikm,
        prk,
        cek,
        nonce,
        header,
        paddedPayload,
      },
    };
  }
  return body.buffer;
}

// ── HKDF 헬퍼 ────────────────────────────────────────────────────────────

export async function hkdfExtract(salt, ikm) {
  const key = await crypto.subtle.importKey(
    'raw',
    salt,
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign']
  );
  return new Uint8Array(await crypto.subtle.sign('HMAC', key, ikm));
}

export async function hkdfExpand(prk, info, length) {
  // 최대 32바이트(SHA-256 1라운드)까지만 지원 — Web Push에서 필요한 모든 길이 커버.
  if (length > 32) {
    throw new Error(`hkdfExpand length ${length} > 32 not supported`);
  }
  const key = await crypto.subtle.importKey(
    'raw',
    prk,
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign']
  );
  const infoWithCounter = new Uint8Array(info.length + 1);
  infoWithCounter.set(info, 0);
  infoWithCounter[info.length] = 1;
  const result = new Uint8Array(await crypto.subtle.sign('HMAC', key, infoWithCounter));
  return result.slice(0, length);
}

// ── 유틸 ─────────────────────────────────────────────────────────────────

export function addPadding(data) {
  // RFC 8188 §2: plaintext || 0x02 (last record delimiter)
  const padded = new Uint8Array(data.length + 1);
  padded.set(data, 0);
  padded[data.length] = 0x02;
  return padded;
}

export function base64UrlToArrayBuffer(base64) {
  const padding = '='.repeat((4 - base64.length % 4) % 4);
  const raw = atob(base64.replace(/-/g, '+').replace(/_/g, '/') + padding);
  const arr = new Uint8Array(raw.length);
  for (let i = 0; i < raw.length; i++) arr[i] = raw.charCodeAt(i);
  return arr.buffer;
}

export function arrayBufferToBase64Url(buffer) {
  const bytes = new Uint8Array(buffer);
  let binary = '';
  for (const b of bytes) binary += String.fromCharCode(b);
  return btoa(binary).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');
}

// raw P-256 public key (65 bytes, 0x04 || X(32) || Y(32))를 JWK x,y로 분해
export function rawP256PublicToJwkXY(raw) {
  if (raw.length !== 65 || raw[0] !== 0x04) {
    throw new Error('Expected uncompressed P-256 public key (65 bytes, 0x04 prefix)');
  }
  return {
    x: arrayBufferToBase64Url(raw.slice(1, 33)),
    y: arrayBufferToBase64Url(raw.slice(33, 65)),
  };
}

export function rawP256PrivateToJwk(privateRaw, publicRaw) {
  const { x, y } = rawP256PublicToJwkXY(publicRaw);
  return {
    kty: 'EC',
    crv: 'P-256',
    d: arrayBufferToBase64Url(privateRaw),
    x,
    y,
    ext: true,
  };
}
