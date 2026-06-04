// ============================================================
// EDGE FUNCTION: dispatch-notifications
// supabase/functions/dispatch-notifications/index.ts
//
// Runs every minute via cron (or invoked on demand).
// Fetches due notifications from the queue and sends them
// via Firebase Cloud Messaging (FCM) HTTP v1 API.
// Uses FOR UPDATE SKIP LOCKED to prevent double-delivery
// under concurrent invocations.
//
// FCM targeting: by device FCM token stored in user_fcm_tokens
// table, saved from Flutter via FirebaseMessaging.instance.getToken().
// ============================================================

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";

const SUPABASE_URL         = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

// Firebase service account JSON (stored as a Supabase secret)
const FIREBASE_SERVICE_ACCOUNT_JSON = Deno.env.get("FIREBASE_SERVICE_ACCOUNT")!;
const FIREBASE_PROJECT_ID           = Deno.env.get("FIREBASE_PROJECT_ID")!;

const FCM_API_URL   = `https://fcm.googleapis.com/v1/projects/${FIREBASE_PROJECT_ID}/messages:send`;
const BATCH_SIZE    = 500;

// ── Google OAuth2 Access Token (cached) ─────────────────────
let _cachedAccessToken: string | null = null;
let _tokenExpiresAt = 0;

async function getAccessToken(): Promise<string> {
  const now = Date.now();
  if (_cachedAccessToken && now < _tokenExpiresAt) {
    return _cachedAccessToken;
  }

  const serviceAccount = JSON.parse(FIREBASE_SERVICE_ACCOUNT_JSON);

  // Create JWT for Google OAuth2
  const header = { alg: "RS256", typ: "JWT" };
  const iat = Math.floor(now / 1000);
  const exp = iat + 3600; // 1 hour
  const claimSet = {
    iss:   serviceAccount.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud:   "https://oauth2.googleapis.com/token",
    iat,
    exp,
  };

  const encodedHeader   = base64urlEncode(JSON.stringify(header));
  const encodedClaims   = base64urlEncode(JSON.stringify(claimSet));
  const signatureInput  = `${encodedHeader}.${encodedClaims}`;

  // Import the private key and sign
  const pemKey   = serviceAccount.private_key;
  const cryptoKey = await importPKCS8Key(pemKey);
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    cryptoKey,
    new TextEncoder().encode(signatureInput)
  );
  const encodedSignature = base64urlEncodeBuffer(signature);
  const jwt = `${signatureInput}.${encodedSignature}`;

  // Exchange JWT for access token
  const tokenRes = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: `grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer&assertion=${jwt}`,
  });

  if (!tokenRes.ok) {
    const errText = await tokenRes.text();
    throw new Error(`Failed to get Google access token: ${tokenRes.status} ${errText}`);
  }

  const tokenData = await tokenRes.json();
  _cachedAccessToken = tokenData.access_token;
  _tokenExpiresAt    = now + (tokenData.expires_in - 60) * 1000; // Refresh 1min early
  return _cachedAccessToken!;
}

// ── Main handler ────────────────────────────────────────────

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  // ── Checkout a batch of due notifications ──────────────────
  const { data: notifications, error: checkoutError } = await supabase
    .rpc("checkout_notifications", { batch_size: BATCH_SIZE });

  if (checkoutError) {
    console.error("[dispatch-notifications] Checkout error:", checkoutError.message);
    return new Response("Internal Server Error", { status: 500 });
  }

  if (!notifications || notifications.length === 0) {
    return new Response(JSON.stringify({ dispatched: 0 }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  console.log(`[dispatch-notifications] Dispatching ${notifications.length} notifications...`);

  // ── Get Google access token ────────────────────────────────
  let accessToken: string;
  try {
    accessToken = await getAccessToken();
  } catch (e) {
    console.error("[dispatch-notifications] Failed to get FCM access token:", e);
    return new Response("Internal Server Error", { status: 500 });
  }

  // ── Resolve FCM tokens for all target users ────────────────
  const userIds = [...new Set(notifications.map((n: NotificationRow) => n.user_id))];
  const { data: tokenRows, error: tokenError } = await supabase
    .from("user_fcm_tokens")
    .select("user_id, fcm_token")
    .in("user_id", userIds);

  if (tokenError) {
    console.error("[dispatch-notifications] Token lookup error:", tokenError.message);
    return new Response("Internal Server Error", { status: 500 });
  }

  // Build a map: user_id → [fcm_token, ...]
  const tokenMap = new Map<string, string[]>();
  for (const row of tokenRows ?? []) {
    const list = tokenMap.get(row.user_id) ?? [];
    list.push(row.fcm_token);
    tokenMap.set(row.user_id, list);
  }

  // ── Dispatch each notification via FCM ─────────────────────
  const results = await Promise.allSettled(
    notifications.flatMap((notif: NotificationRow) => {
      const tokens = tokenMap.get(notif.user_id);
      if (!tokens || tokens.length === 0) {
        console.warn(`[dispatch-notifications] No FCM token for user ${notif.user_id} — skipping.`);
        return [Promise.resolve()]; // Count as success (user has no registered device)
      }
      return tokens.map((token) => sendFCM(accessToken, token, notif));
    })
  );

  const succeeded = results.filter((r) => r.status === "fulfilled").length;
  const failed    = results.filter((r) => r.status === "rejected").length;

  if (failed > 0) {
    // Mark failed notifications as unsent (reset sent_at) so they retry
    const failedIds = results
      .map((r, i) => r.status === "rejected" ? notifications[i]?.id : null)
      .filter((id): id is string => id !== null);

    if (failedIds.length > 0) {
      await supabase
        .from("notifications")
        .update({ sent_at: null })
        .in("id", failedIds);
    }
  }

  console.log(
    `[dispatch-notifications] ✅ Sent: ${succeeded}, ❌ Failed: ${failed}`
  );

  return new Response(
    JSON.stringify({ dispatched: succeeded, failed }),
    {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    }
  );
});

// ── Send a single notification via FCM HTTP v1 API ────────────

async function sendFCM(
  accessToken: string,
  fcmToken: string,
  notif: NotificationRow
): Promise<void> {
  const message: Record<string, unknown> = {
    message: {
      token: fcmToken,
      notification: {
        title: notif.title,
        body:  notif.body,
      },
      data: {
        notification_id: notif.id,
        ...(notif.deep_link ? { deep_link: notif.deep_link } : {}),
      },
      // Android-specific: high priority for timely delivery
      android: {
        priority: "high",
      },
      // iOS-specific: use content-available for background delivery
      apns: {
        headers: { "apns-priority": "10" },
        payload: {
          aps: { sound: "default" },
        },
      },
    },
  };

  const res = await fetch(FCM_API_URL, {
    method: "POST",
    headers: {
      "Content-Type":  "application/json",
      Authorization:   `Bearer ${accessToken}`,
    },
    body: JSON.stringify(message),
  });

  if (!res.ok) {
    const err = await res.text();
    throw new Error(`FCM API error ${res.status}: ${err}`);
  }
}

// ── Crypto helpers for JWT signing ────────────────────────────

function base64urlEncode(str: string): string {
  return btoa(str)
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");
}

function base64urlEncodeBuffer(buffer: ArrayBuffer): string {
  const bytes = new Uint8Array(buffer);
  let binary = "";
  for (const byte of bytes) {
    binary += String.fromCharCode(byte);
  }
  return btoa(binary)
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");
}

async function importPKCS8Key(pem: string): Promise<CryptoKey> {
  const pemContents = pem
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\n/g, "")
    .replace(/\r/g, "");

  const binaryDer = Uint8Array.from(atob(pemContents), (c) => c.charCodeAt(0));

  return await crypto.subtle.importKey(
    "pkcs8",
    binaryDer.buffer,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"]
  );
}

// ── Type definitions ───────────────────────────────────────────

interface NotificationRow {
  id:        string;
  user_id:   string;
  title:     string;
  body:      string;
  deep_link: string | null;
}
