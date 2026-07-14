// ============================================================
// SHARED: Firebase Token Verifier
// supabase/functions/_shared/firebase_verifier.ts
//
// Verifies a Firebase ID token against Firebase's public keys.
// Caches public keys in memory for 1 hour to avoid fetching
// on every request.
// ============================================================

interface FirebasePublicKeys {
  [kid: string]: JsonWebKey;
}

interface CachedKeys {
  keys: FirebasePublicKeys;
  expiresAt: number;
}

let keyCache: CachedKeys | null = null;

const FIREBASE_JWK_URL =
  "https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com";

async function getFirebasePublicKeys(): Promise<FirebasePublicKeys> {
  const now = Date.now();
  if (keyCache && keyCache.expiresAt > now) {
    return keyCache.keys;
  }

  const res = await fetch(FIREBASE_JWK_URL);
  if (!res.ok) {
    throw new Error(`Failed to fetch Firebase public keys: ${res.status}`);
  }

  // Parse Cache-Control max-age header to set cache expiry
  const cc = res.headers.get("cache-control") ?? "";
  const maxAgeMatch = cc.match(/max-age=(\d+)/);
  const ttlMs = maxAgeMatch ? parseInt(maxAgeMatch[1]) * 1000 : 3600_000;

  const data = await res.json();
  const keys: FirebasePublicKeys = {};

  // Convert JWK array to dictionary by kid
  if (data.keys && Array.isArray(data.keys)) {
    for (const key of data.keys) {
      if (key.kid) {
        keys[key.kid] = key;
      }
    }
  }

  keyCache = { keys, expiresAt: now + ttlMs };
  return keys;
}

export interface FirebaseClaims {
  uid: string;
  phone_number: string;
  firebase_project_id: string;
}

export async function verifyFirebaseToken(
  idToken: string,
  expectedProjectId: string,
): Promise<FirebaseClaims> {
  const keys = await getFirebasePublicKeys();

  // Decode JWT header to find which key ID was used
  const [headerB64, payloadB64, signatureB64] = idToken.split(".");
  if (!headerB64 || !payloadB64 || !signatureB64) {
    throw new Error("Malformed Firebase ID token.");
  }

  const header = JSON.parse(
    atob(headerB64.replace(/-/g, "+").replace(/_/g, "/")),
  );
  const payload = JSON.parse(
    atob(payloadB64.replace(/-/g, "+").replace(/_/g, "/")),
  );

  // Validate standard JWT claims
  const now = Math.floor(Date.now() / 1000);
  if (payload.exp < now) throw new Error("Firebase ID token has expired.");
  if (payload.iat > now + 300) {
    throw new Error("Firebase ID token issued in the future.");
  }
  if (payload.aud !== expectedProjectId) {
    throw new Error(
      `Token audience '${payload.aud}' does not match expected project '${expectedProjectId}'.`,
    );
  }
  if (payload.iss !== `https://securetoken.google.com/${expectedProjectId}`) {
    throw new Error(
      "Token issuer mismatch — possible cross-project token injection.",
    );
  }
  if (!payload.phone_number) {
    throw new Error("Firebase token does not contain a phone_number claim.");
  }

  // Verify RSA signature using the matched public key
  const jwk = keys[header.kid];
  if (!jwk) {
    throw new Error(`No Firebase public key found for kid '${header.kid}'.`);
  }

  const pubKey = await crypto.subtle.importKey(
    "jwk",
    jwk,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["verify"],
  );

  const signingInput = new TextEncoder().encode(`${headerB64}.${payloadB64}`);
  const signature = base64UrlToArrayBuffer(signatureB64);
  const valid = await crypto.subtle.verify(
    "RSASSA-PKCS1-v1_5",
    pubKey,
    signature,
    signingInput,
  );

  if (!valid) {
    throw new Error("Firebase ID token signature verification failed.");
  }

  return {
    uid: payload.sub,
    phone_number: payload.phone_number,
    firebase_project_id: expectedProjectId,
  };
}

// ── Utility functions ────────────────────────────────────────

function base64ToArrayBuffer(b64: string): ArrayBuffer {
  const binary = atob(b64);
  const buffer = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) buffer[i] = binary.charCodeAt(i);
  return buffer.buffer;
}

function base64UrlToArrayBuffer(b64url: string): ArrayBuffer {
  return base64ToArrayBuffer(b64url.replace(/-/g, "+").replace(/_/g, "/"));
}
