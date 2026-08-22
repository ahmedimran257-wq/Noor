import { createClient } from "@supabase/supabase-js";
import { corsHeaders } from "../_shared/cors.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const FIREBASE_PROJECT_ID = Deno.env.get("FIREBASE_PROJECT_ID")!;
const FIREBASE_JWKS_URL =
  "https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com";

type FirebaseClaims = {
  aud?: string;
  iss?: string;
  sub?: string;
  exp?: number;
  iat?: number;
  auth_time?: number;
  phone_number?: string;
  firebase?: { sign_in_provider?: string };
};
type FirebaseJwk = JsonWebKey & { kid?: string };

let cachedKeys: Record<string, FirebaseJwk> | null = null;
let keysExpireAt = 0;

function response(status: number, payload: Record<string, unknown>) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function decodeBase64Url(value: string): Uint8Array<ArrayBuffer> {
  const normalized = value.replace(/-/g, "+").replace(/_/g, "/");
  const padded = normalized.padEnd(Math.ceil(normalized.length / 4) * 4, "=");
  const decoded = atob(padded);
  const bytes = new Uint8Array(new ArrayBuffer(decoded.length));
  for (let index = 0; index < decoded.length; index += 1) {
    bytes[index] = decoded.charCodeAt(index);
  }
  return bytes;
}

function decodeJson<T>(value: string): T {
  return JSON.parse(new TextDecoder().decode(decodeBase64Url(value))) as T;
}

async function firebaseKeys(): Promise<Record<string, FirebaseJwk>> {
  if (cachedKeys && Date.now() < keysExpireAt) return cachedKeys;
  const result = await fetch(FIREBASE_JWKS_URL, {
    signal: AbortSignal.timeout(8_000),
  });
  if (!result.ok) throw new Error("firebase_keys_unavailable");
  const body = await result.json() as { keys?: FirebaseJwk[] };
  const mapped: Record<string, FirebaseJwk> = {};
  for (const key of body.keys ?? []) {
    if (key.kid) mapped[key.kid] = key;
  }
  if (Object.keys(mapped).length === 0) {
    throw new Error("firebase_keys_unavailable");
  }
  const maxAge = Number(
    result.headers.get("cache-control")?.match(/max-age=(\d+)/)?.[1] ?? 3600,
  );
  cachedKeys = mapped;
  keysExpireAt = Date.now() + Math.max(300, maxAge - 60) * 1000;
  return mapped;
}

async function verifyFirebaseToken(token: string): Promise<FirebaseClaims> {
  const parts = token.split(".");
  if (parts.length !== 3) throw new Error("invalid_firebase_token");
  const header = decodeJson<{ alg?: string; kid?: string }>(parts[0]);
  const claims = decodeJson<FirebaseClaims>(parts[1]);
  if (header.alg !== "RS256" || !header.kid) {
    throw new Error("invalid_firebase_token");
  }

  const keys = await firebaseKeys();
  const jwk = keys[header.kid];
  if (!jwk) throw new Error("invalid_firebase_token");
  const key = await crypto.subtle.importKey(
    "jwk",
    jwk,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["verify"],
  );
  const valid = await crypto.subtle.verify(
    "RSASSA-PKCS1-v1_5",
    key,
    decodeBase64Url(parts[2]),
    new TextEncoder().encode(`${parts[0]}.${parts[1]}`),
  );
  if (!valid) throw new Error("invalid_firebase_token");

  const now = Math.floor(Date.now() / 1000);
  if (
    claims.aud !== FIREBASE_PROJECT_ID ||
    claims.iss !== `https://securetoken.google.com/${FIREBASE_PROJECT_ID}` ||
    !claims.sub || claims.sub.length > 128 ||
    !claims.exp || claims.exp <= now ||
    !claims.iat || claims.iat > now + 60 ||
    !claims.auth_time || now - claims.auth_time > 10 * 60 ||
    claims.firebase?.sign_in_provider !== "phone"
  ) {
    throw new Error("invalid_firebase_token");
  }
  return claims;
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return response(405, { error: "method_not_allowed" });
  }

  const authorization = request.headers.get("authorization");
  if (!authorization?.toLowerCase().startsWith("bearer ")) {
    return response(401, { error: "authentication_required" });
  }

  const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: authData, error: authError } = await userClient.auth.getUser();
  if (authError || !authData.user) {
    return response(401, { error: "authentication_required" });
  }

  let body: Record<string, unknown>;
  try {
    body = await request.json();
  } catch (_) {
    return response(400, { error: "invalid_request" });
  }
  const firebaseIdToken = String(body.firebase_id_token ?? "").trim();
  const purpose = body.purpose === "guardian" ? "guardian" : "premium";
  const countryCode = String(body.country_code ?? "").trim().toUpperCase();
  const invitationCode = String(body.invitation_code ?? "").trim()
    .toUpperCase();
  if (!firebaseIdToken || countryCode !== "IN") {
    return response(400, { error: "invalid_request" });
  }

  let claims: FirebaseClaims;
  try {
    claims = await verifyFirebaseToken(firebaseIdToken);
  } catch (_) {
    return response(401, { error: "phone_verification_invalid" });
  }
  const phone = claims.phone_number?.trim() ?? "";
  if (!/^\+91[6-9][0-9]{9}$/.test(phone)) {
    return response(400, { error: "india_mobile_required" });
  }

  if (purpose === "premium") {
    const { error } = await userClient.rpc(
      "assert_my_phone_verification_intent",
      {
        p_country_code: countryCode,
      },
    );
    if (error) {
      return response(403, { error: "phone_verification_intent_required" });
    }
  } else {
    const { data: allowed, error } = await userClient.rpc(
      "check_guardian_invitation_phone",
      {
        p_code: invitationCode,
        p_phone: phone,
      },
    );
    if (error || allowed !== true) {
      return response(403, { error: "guardian_invitation_unavailable" });
    }
  }

  const service = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  if (purpose === "premium") {
    const { error: completeError } = await service.rpc(
      "complete_paid_phone_verification",
      {
        p_user_id: authData.user.id,
        p_country_code: countryCode,
        p_phone: phone,
      },
    );
    if (completeError) {
      const duplicate = completeError.code === "23505";
      return response(duplicate ? 409 : 500, {
        error: duplicate ? "phone_already_in_use" : "phone_save_failed",
      });
    }
  } else {
    const { error: activationError } = await service.rpc(
      "complete_guardian_phone_and_accept",
      {
        p_guardian_id: authData.user.id,
        p_code: invitationCode,
        p_phone: phone,
      },
    );
    if (activationError) {
      const duplicate = activationError.code === "23505";
      const unavailable = activationError.message.includes("invitation");
      return response(duplicate ? 409 : unavailable ? 403 : 500, {
        error: duplicate
          ? "phone_already_in_use"
          : unavailable
          ? "guardian_invitation_unavailable"
          : "phone_save_failed",
      });
    }
  }

  return response(200, { verified: true, country_code: countryCode });
});
