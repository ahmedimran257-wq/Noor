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

import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { corsHeaders } from "../_shared/cors.ts";
import { isAuthorizedCronRequest } from "../_shared/cron_auth.ts";
import {
  consumeDistributedRateLimit,
  rateLimitHeaders,
} from "../_shared/distributed_rate_limit.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

// Prefer base64 for structured credentials: it survives CLI, shell, and dashboard
// transport without JSON quoting or PEM newline corruption. The raw JSON secret
// remains a backwards-compatible fallback during secret rotation.
const FIREBASE_SERVICE_ACCOUNT_B64 = Deno.env.get(
  "FIREBASE_SERVICE_ACCOUNT_B64",
);
const FIREBASE_SERVICE_ACCOUNT_JSON = Deno.env.get(
  "FIREBASE_SERVICE_ACCOUNT",
);
const FIREBASE_PROJECT_ID = Deno.env.get("FIREBASE_PROJECT_ID")!;

const FCM_API_URL =
  `https://fcm.googleapis.com/v1/projects/${FIREBASE_PROJECT_ID}/messages:send`;
const BATCH_SIZE = 100;
const MAX_CONCURRENCY = 8;
const OUTBOUND_TIMEOUT_MS = 10_000;

interface DirectProfileLivePayload {
  user_id: string;
  type: "profile_live";
  title: string;
  body: string;
}

// ── Google OAuth2 Access Token (cached) ─────────────────────
let _cachedAccessToken: string | null = null;
let _tokenExpiresAt = 0;

async function getAccessToken(): Promise<string> {
  const now = Date.now();
  if (_cachedAccessToken && now < _tokenExpiresAt) {
    return _cachedAccessToken;
  }

  const serviceAccount = readFirebaseServiceAccount();

  // Create JWT for Google OAuth2
  const header = { alg: "RS256", typ: "JWT" };
  const iat = Math.floor(now / 1000);
  const exp = iat + 3600; // 1 hour
  const claimSet = {
    iss: serviceAccount.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat,
    exp,
  };

  const encodedHeader = base64urlEncode(JSON.stringify(header));
  const encodedClaims = base64urlEncode(JSON.stringify(claimSet));
  const signatureInput = `${encodedHeader}.${encodedClaims}`;

  // Import the private key and sign
  const pemKey = serviceAccount.private_key;
  const cryptoKey = await importPKCS8Key(pemKey);
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    cryptoKey,
    new TextEncoder().encode(signatureInput),
  );
  const encodedSignature = base64urlEncodeBuffer(signature);
  const jwt = `${signatureInput}.${encodedSignature}`;

  // Exchange JWT for access token
  const tokenRes = await fetchWithTimeout(
    "https://oauth2.googleapis.com/token",
    {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body:
        `grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer&assertion=${jwt}`,
    },
    OUTBOUND_TIMEOUT_MS,
  );

  if (!tokenRes.ok) {
    throw new Error(`google_oauth_${tokenRes.status}`);
  }

  const tokenData = await tokenRes.json();
  _cachedAccessToken = tokenData.access_token;
  _tokenExpiresAt = now + (tokenData.expires_in - 60) * 1000; // Refresh 1min early
  return _cachedAccessToken!;
}

// ── Main handler ────────────────────────────────────────────

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const directPayload = await authenticatedProfileLivePayload(req);
  if (!directPayload && !(await isAuthorizedCronRequest(req))) {
    console.warn("[dispatch-notifications] Unauthorized invocation blocked.");
    return new Response("Unauthorized", { status: 401 });
  }

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  if (directPayload) {
    const rateLimit = await consumeDistributedRateLimit(supabase, {
      scope: "profile_live_dispatch",
      subject: directPayload.user_id,
      maxRequests: 5,
      windowSeconds: 24 * 60 * 60,
    });
    if (!rateLimit.allowed) {
      return new Response(
        JSON.stringify({ error: "Notification request limit reached." }),
        {
          status: 429,
          headers: {
            ...corsHeaders,
            ...rateLimitHeaders(rateLimit),
            "Content-Type": "application/json",
          },
        },
      );
    }
    const { data: profile } = await supabase
      .from("profiles")
      .select("id, visibility, approved_at")
      .eq("user_id", directPayload.user_id)
      .single();
    const { data: primaryPhoto } = profile
      ? await supabase
        .from("photos")
        .select("id")
        .eq("profile_id", profile.id)
        .eq("order_index", 0)
        .eq("status", "active")
        .eq("admin_approved", true)
        .eq("nsfw_cleared", true)
        .maybeSingle()
      : { data: null };

    if (!profile || profile.visibility !== "visible" || !primaryPhoto) {
      return new Response(JSON.stringify({ error: "Profile is not live" }), {
        status: 409,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { error: insertError } = await supabase.from("notifications").insert({
      user_id: directPayload.user_id,
      type: directPayload.type,
      title: directPayload.title,
      body: directPayload.body,
      deep_link: "/home?tab=0",
      scheduled_at: new Date().toISOString(),
    });
    if (insertError) {
      console.error(
        "[dispatch-notifications] Direct insert failed:",
        insertError.message,
      );
      await recordDispatchResult(supabase, false, insertError.message);
      return new Response("Internal Server Error", { status: 500 });
    }
  }

  if (
    (!FIREBASE_SERVICE_ACCOUNT_B64 && !FIREBASE_SERVICE_ACCOUNT_JSON) ||
    !FIREBASE_PROJECT_ID
  ) {
    console.error(
      "[dispatch-notifications] Missing Firebase service account/project secrets.",
    );
    await recordDispatchResult(
      supabase,
      false,
      "Firebase configuration missing",
    );
    return new Response("Internal Server Error", { status: 500 });
  }

  // ── Checkout a batch of due notifications ──────────────────
  const { data: notifications, error: checkoutError } = await supabase
    .rpc("checkout_notifications", { batch_size: BATCH_SIZE });

  if (checkoutError) {
    console.error(
      "[dispatch-notifications] Checkout error:",
      checkoutError.message,
    );
    await recordDispatchResult(supabase, false, checkoutError.message);
    return new Response("Internal Server Error", { status: 500 });
  }

  if (!notifications || notifications.length === 0) {
    await recordDispatchResult(supabase, true, null, { dispatched: 0 });
    return new Response(JSON.stringify({ dispatched: 0 }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  console.log(
    `[dispatch-notifications] Dispatching ${notifications.length} notifications...`,
  );

  // ── Get Google access token ────────────────────────────────
  let accessToken: string;
  try {
    accessToken = await getAccessToken();
  } catch (e) {
    await finishCheckedOutNotifications(
      supabase,
      notifications as NotificationRow[],
      "retry",
      "fcm_oauth_unavailable",
    );
    console.error(
      "[dispatch-notifications] Failed to get FCM access token:",
      e,
    );
    await recordDispatchResult(
      supabase,
      false,
      e instanceof Error ? e.message : "FCM token exchange failed",
    );
    return new Response("Internal Server Error", { status: 500 });
  }

  // ── Resolve FCM tokens for all target users ────────────────
  const userIds = [
    ...new Set(notifications.map((n: NotificationRow) => n.user_id)),
  ];
  const { data: tokenRows, error: tokenError } = await supabase
    .from("user_fcm_tokens")
    .select("user_id, fcm_token")
    .in("user_id", userIds);

  if (tokenError) {
    await finishCheckedOutNotifications(
      supabase,
      notifications as NotificationRow[],
      "retry",
      "token_lookup_failed",
    );
    console.error(
      "[dispatch-notifications] Token lookup error:",
      tokenError.message,
    );
    await recordDispatchResult(supabase, false, tokenError.message);
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
  const outcomes = await mapWithConcurrency(
    notifications as NotificationRow[],
    MAX_CONCURRENCY,
    async (notification) => {
      try {
        return await deliverNotification(
          supabase,
          accessToken,
          notification,
          tokenMap.get(notification.user_id) ?? [],
        );
      } catch {
        try {
          await finishNotification(
            supabase,
            notification,
            "retry",
            "delivery_worker_failed",
          );
        } catch {
          // The database lease remains recoverable after five minutes even if
          // the completion call itself is unavailable.
        }
        return "retry" as const;
      }
    },
  );
  const succeeded = outcomes.filter((value) => value === "sent").length;
  const failed = outcomes.filter((value) => value === "retry").length;
  const noToken = outcomes.filter((value) => value === "in_app_only").length;

  console.log(
    `[dispatch-notifications] Sent: ${succeeded}, failed: ${failed}, in-app-only: ${noToken}`,
  );

  await recordDispatchResult(
    supabase,
    failed === 0,
    failed === 0 ? null : `${failed} notification deliveries failed`,
    { dispatched: succeeded, failed, in_app_only: noToken },
  );

  return new Response(
    JSON.stringify({ dispatched: succeeded, failed }),
    {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    },
  );
});

interface FirebaseServiceAccount {
  project_id: string;
  client_email: string;
  private_key: string;
}

function readFirebaseServiceAccount(): FirebaseServiceAccount {
  const encoded = FIREBASE_SERVICE_ACCOUNT_B64?.trim();
  const serialized = encoded
    ? new TextDecoder().decode(
      Uint8Array.from(atob(encoded), (character) => character.charCodeAt(0)),
    )
    : FIREBASE_SERVICE_ACCOUNT_JSON;

  if (!serialized) {
    throw new Error("Firebase service account is not configured");
  }

  const parsed = JSON.parse(serialized) as Partial<FirebaseServiceAccount>;
  if (
    !parsed.project_id ||
    !parsed.client_email ||
    !parsed.private_key ||
    parsed.project_id !== FIREBASE_PROJECT_ID
  ) {
    throw new Error("Firebase service account metadata is invalid");
  }

  return parsed as FirebaseServiceAccount;
}

async function recordDispatchResult(
  supabase: SupabaseClient,
  success: boolean,
  error: string | null,
  details: Record<string, unknown> = {},
): Promise<void> {
  const { error: healthError } = await supabase.rpc(
    "record_edge_function_result",
    {
      p_function_name: "dispatch-notifications",
      p_success: success,
      p_error: error,
      p_details: details,
    },
  );
  if (healthError) {
    console.error(
      "[dispatch-notifications] Unable to persist worker health:",
      healthError.message,
    );
  }
}

async function authenticatedProfileLivePayload(
  req: Request,
): Promise<DirectProfileLivePayload | null> {
  if (req.method !== "POST") return null;
  let body: Record<string, unknown>;
  try {
    body = await req.clone().json();
  } catch (_) {
    return null;
  }
  if (
    body.type !== "profile_live" ||
    typeof body.user_id !== "string" ||
    body.title !== "Your profile is now live! 🎉" ||
    body.body !== "Muslims in your area can now find you on Silarah."
  ) return null;

  const authHeader = req.headers.get("Authorization");
  if (!authHeader?.startsWith("Bearer ")) return null;
  const userClient = createClient(
    SUPABASE_URL,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    {
      global: { headers: { Authorization: authHeader } },
      auth: { autoRefreshToken: false, persistSession: false },
    },
  );
  const { data: { user }, error } = await userClient.auth.getUser();
  if (error || !user || user.id !== body.user_id) return null;

  return {
    user_id: user.id,
    type: "profile_live",
    title: body.title,
    body: body.body,
  };
}

// ── Send a single notification via FCM HTTP v1 API ────────────

async function sendFCM(
  accessToken: string,
  fcmToken: string,
  notif: NotificationRow,
): Promise<FcmResult> {
  const message: Record<string, unknown> = {
    message: {
      token: fcmToken,
      notification: {
        title: notif.title,
        body: notif.body,
      },
      data: {
        notification_id: notif.id,
        type: notif.type,
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

  const res = await fetchWithTimeout(FCM_API_URL, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${accessToken}`,
    },
    body: JSON.stringify(message),
  }, OUTBOUND_TIMEOUT_MS);

  if (res.ok) return { status: "sent", errorCode: null };
  const errorBody = await readTextLimited(res, 4096);
  const invalid = res.status === 404 || errorBody.includes("UNREGISTERED") ||
    errorBody.includes("registration-token-not-registered");
  return {
    status: invalid ? "invalid_token" : "retry",
    errorCode: invalid ? "fcm_token_invalid" : `fcm_http_${res.status}`,
  };
}

async function deliverNotification(
  supabase: SupabaseClient,
  accessToken: string,
  notification: NotificationRow,
  tokens: string[],
): Promise<DeliveryOutcome> {
  if (tokens.length === 0) {
    await finishNotification(supabase, notification, "in_app_only", "no_token");
    return "in_app_only";
  }
  let sent = false;
  let transientFailure = false;
  for (const token of tokens.slice(0, 5)) {
    let result: FcmResult;
    try {
      result = await sendFCM(accessToken, token, notification);
    } catch {
      result = { status: "retry", errorCode: "fcm_timeout" };
    }
    await supabase.rpc("record_notification_token_delivery", {
      p_notification_id: notification.id,
      p_lease_token: notification.lease_token,
      p_fcm_token: token,
      p_status: result.status,
      p_error_code: result.errorCode,
    });
    if (result.status === "sent") sent = true;
    if (result.status === "retry") transientFailure = true;
    if (result.status === "invalid_token") {
      await supabase.from("user_fcm_tokens").delete().eq("fcm_token", token);
    }
  }
  const outcome: DeliveryOutcome = sent
    ? "sent"
    : transientFailure
    ? "retry"
    : "in_app_only";
  await finishNotification(
    supabase,
    notification,
    outcome,
    outcome === "retry" ? "fcm_transient_failure" : null,
  );
  return outcome;
}

async function finishNotification(
  supabase: SupabaseClient,
  notification: NotificationRow,
  status: DeliveryOutcome,
  errorCode: string | null,
): Promise<void> {
  const { error } = await supabase.rpc("finish_notification_delivery", {
    p_notification_id: notification.id,
    p_lease_token: notification.lease_token,
    p_status: status,
    p_error_code: errorCode,
  });
  if (error) throw new Error("notification_lease_completion_failed");
}

async function finishCheckedOutNotifications(
  supabase: SupabaseClient,
  notifications: NotificationRow[],
  status: DeliveryOutcome,
  errorCode: string,
): Promise<void> {
  await mapWithConcurrency(
    notifications,
    MAX_CONCURRENCY,
    (notification) =>
      finishNotification(supabase, notification, status, errorCode),
  );
}

// ── Crypto helpers for JWT signing ────────────────────────────

async function mapWithConcurrency<T, R>(
  items: T[],
  concurrency: number,
  task: (item: T) => Promise<R>,
): Promise<R[]> {
  const results = new Array<R>(items.length);
  let cursor = 0;
  const workers = Array.from(
    { length: Math.min(concurrency, items.length) },
    async () => {
      while (true) {
        const index = cursor++;
        if (index >= items.length) return;
        results[index] = await task(items[index]);
      }
    },
  );
  await Promise.all(workers);
  return results;
}

async function fetchWithTimeout(
  input: string,
  init: RequestInit,
  timeoutMs: number,
): Promise<Response> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), timeoutMs);
  try {
    return await fetch(input, { ...init, signal: controller.signal });
  } finally {
    clearTimeout(timeout);
  }
}

async function readTextLimited(
  response: Response,
  maxBytes: number,
): Promise<string> {
  if (!response.body) return "";
  const reader = response.body.getReader();
  const decoder = new TextDecoder();
  let result = "";
  let bytes = 0;
  while (bytes < maxBytes) {
    const { value, done } = await reader.read();
    if (done || !value) break;
    const remaining = Math.min(value.byteLength, maxBytes - bytes);
    result += decoder.decode(value.slice(0, remaining), { stream: true });
    bytes += remaining;
  }
  await reader.cancel().catch(() => undefined);
  return result;
}

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
    ["sign"],
  );
}

// ── Type definitions ───────────────────────────────────────────

interface NotificationRow {
  id: string;
  user_id: string;
  type: string;
  title: string;
  body: string;
  deep_link: string | null;
  lease_token: string;
}

type DeliveryOutcome = "sent" | "retry" | "in_app_only";
type FcmResult = {
  status: "sent" | "retry" | "invalid_token";
  errorCode: string | null;
};
