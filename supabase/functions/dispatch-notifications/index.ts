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

import {
  createClient,
  type SupabaseClient,
} from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";
import { isAuthorizedCronRequest } from "../_shared/cron_auth.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

// Firebase service account JSON (stored as a Supabase secret)
const FIREBASE_SERVICE_ACCOUNT_JSON = Deno.env.get("FIREBASE_SERVICE_ACCOUNT")!;
const FIREBASE_PROJECT_ID = Deno.env.get("FIREBASE_PROJECT_ID")!;

const FCM_API_URL =
  `https://fcm.googleapis.com/v1/projects/${FIREBASE_PROJECT_ID}/messages:send`;
const BATCH_SIZE = 500;

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

  const serviceAccount = JSON.parse(FIREBASE_SERVICE_ACCOUNT_JSON);

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
  const tokenRes = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body:
      `grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer&assertion=${jwt}`,
  });

  if (!tokenRes.ok) {
    const errText = await tokenRes.text();
    throw new Error(
      `Failed to get Google access token: ${tokenRes.status} ${errText}`,
    );
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
        .eq("moderation_status", "approved")
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
      console.error("[dispatch-notifications] Direct insert failed:", insertError.message);
      return new Response("Internal Server Error", { status: 500 });
    }
  }

  if (!FIREBASE_SERVICE_ACCOUNT_JSON || !FIREBASE_PROJECT_ID) {
    console.error(
      "[dispatch-notifications] Missing Firebase service account/project secrets.",
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
    return new Response("Internal Server Error", { status: 500 });
  }

  if (!notifications || notifications.length === 0) {
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
    await releaseCheckedOutNotifications(
      supabase,
      notifications as NotificationRow[],
    );
    console.error(
      "[dispatch-notifications] Failed to get FCM access token:",
      e,
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
    await releaseCheckedOutNotifications(
      supabase,
      notifications as NotificationRow[],
    );
    console.error(
      "[dispatch-notifications] Token lookup error:",
      tokenError.message,
    );
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
  const attempts: DeliveryAttempt[] = [];
  let noToken = 0;
  for (const notif of notifications as NotificationRow[]) {
    const tokens = tokenMap.get(notif.user_id);
    if (!tokens || tokens.length === 0) {
      noToken += 1;
      console.warn(
        `[dispatch-notifications] No FCM token for user ${notif.user_id}; keeping notification in-app only.`,
      );
      continue;
    }
    for (const token of tokens) {
      attempts.push({ notificationId: notif.id, token, notif });
    }
  }

  const results = await Promise.allSettled(
    attempts.map((attempt) =>
      sendFCM(accessToken, attempt.token, attempt.notif)
    ),
  );

  const deliveredNotificationIds = new Set<string>();
  const failedNotificationIds = new Set<string>();
  results.forEach((result, index) => {
    const notificationId = attempts[index]?.notificationId;
    if (!notificationId) return;
    if (result.status === "fulfilled") {
      deliveredNotificationIds.add(notificationId);
    } else {
      failedNotificationIds.add(notificationId);
      console.error(
        `[dispatch-notifications] FCM delivery failed for notification ${notificationId}:`,
        result.reason,
      );
    }
  });

  for (const deliveredId of deliveredNotificationIds) {
    failedNotificationIds.delete(deliveredId);
  }

  if (failedNotificationIds.size > 0) {
    await supabase
      .from("notifications")
      .update({ sent_at: null })
      .in("id", [...failedNotificationIds]);
  }

  const succeeded = deliveredNotificationIds.size;
  const failed = failedNotificationIds.size;

  console.log(
    `[dispatch-notifications] Sent: ${succeeded}, failed: ${failed}, in-app-only: ${noToken}`,
  );

  return new Response(
    JSON.stringify({ dispatched: succeeded, failed }),
    {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    },
  );
});

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
  const userClient = createClient(SUPABASE_URL, Deno.env.get("SUPABASE_ANON_KEY")!, {
    global: { headers: { Authorization: authHeader } },
    auth: { autoRefreshToken: false, persistSession: false },
  });
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
): Promise<void> {
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

  const res = await fetch(FCM_API_URL, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${accessToken}`,
    },
    body: JSON.stringify(message),
  });

  if (!res.ok) {
    const err = await res.text();
    throw new Error(`FCM API error ${res.status}: ${err}`);
  }
}

async function releaseCheckedOutNotifications(
  supabase: SupabaseClient,
  notifications: NotificationRow[],
): Promise<void> {
  const ids = notifications.map((notification) => notification.id);
  if (ids.length === 0) return;

  const { error } = await supabase
    .from("notifications")
    .update({ sent_at: null })
    .in("id", ids);

  if (error) {
    console.error(
      "[dispatch-notifications] Failed to release checked-out notifications:",
      error.message,
    );
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
}

interface DeliveryAttempt {
  notificationId: string;
  token: string;
  notif: NotificationRow;
}
