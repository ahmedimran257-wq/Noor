// ============================================================
// EDGE FUNCTION: revenuecat-webhook
// supabase/functions/revenuecat-webhook/index.ts
//
// Handles RevenueCat subscription lifecycle events.
//
// Events handled:
//   INITIAL_PURCHASE   → status = 'active'
//   RENEWAL            → status = 'active'
//   CANCELLATION       → keep 'active' until expires_at
//   EXPIRATION         → status = 'none'
//   BILLING_ISSUE      → status = 'grace' (24h window)
//   REFUND             → status = 'none'
//   PRODUCT_CHANGE     → update expires_at
//
// Idempotency:
//   events are only applied if event_timestamp_ms >
//   users.last_billing_event_ts — prevents webhook replay
//   attacks from downgrading active subscriptions.
//
// Security:
//   RevenueCat webhook signature is verified using HMAC-SHA256
//   against the webhook secret stored in env vars.
// ============================================================

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";

const SUPABASE_URL         = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const REVENUECAT_WEBHOOK_SECRET = Deno.env.get("REVENUECAT_WEBHOOK_SECRET")!;

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  // ── Verify RevenueCat HMAC-SHA256 signature ────────────────
  const signature = req.headers.get("X-RevenueCat-Signature") ?? "";
  const rawBody = await req.text();

  const isValid = await verifyHmac(rawBody, signature, REVENUECAT_WEBHOOK_SECRET);
  if (!isValid) {
    console.warn("[revenuecat-webhook] Invalid signature — request rejected.");
    return new Response("Unauthorized", { status: 401 });
  }

  let payload: RevenueCatWebhookPayload;
  try {
    payload = JSON.parse(rawBody);
  } catch {
    return new Response("Bad Request: invalid JSON", { status: 400 });
  }

  const event = payload.event;
  if (!event) {
    return new Response("Bad Request: missing event", { status: 400 });
  }

  console.log(`[revenuecat-webhook] Received event: ${event.type} for app_user_id: ${event.app_user_id}`);

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  // ── Resolve the Supabase user ID ───────────────────────────
  // RevenueCat app_user_id is set to the Supabase user UUID in the Flutter app
  // via: await Purchases.logIn(supabaseUserId);
  const supabaseUserId = event.app_user_id;
  if (!supabaseUserId) {
    console.error("[revenuecat-webhook] No app_user_id in event.");
    return new Response("OK", { status: 200 }); // Acknowledge to prevent retries
  }

  // ── Idempotency check ──────────────────────────────────────
  const eventTimestampMs = event.event_timestamp_ms ?? Date.now();

  const { data: user, error: userError } = await supabase
    .from("users")
    .select("id, last_billing_event_ts, subscription_status")
    .eq("id", supabaseUserId)
    .single();

  if (userError || !user) {
    console.warn(`[revenuecat-webhook] User not found: ${supabaseUserId}`);
    return new Response("OK", { status: 200 }); // User deleted — no action needed
  }

  if (eventTimestampMs <= (user.last_billing_event_ts ?? 0)) {
    console.log(
      `[revenuecat-webhook] Stale event (ts: ${eventTimestampMs} <= stored: ${user.last_billing_event_ts}) — IGNORED.`
    );
    return new Response("OK", { status: 200 });
  }

  // ── Compute new subscription state ────────────────────────
  let newStatus: "active" | "none" | "grace" | null = null;
  let newExpiresAt: string | null = null;

  const expiresAt = event.expiration_at_ms
    ? new Date(event.expiration_at_ms).toISOString()
    : null;

  switch (event.type) {
    case "INITIAL_PURCHASE":
    case "RENEWAL":
    case "PRODUCT_CHANGE":
      newStatus    = "active";
      newExpiresAt = expiresAt;
      break;

    case "CANCELLATION":
      // Keep active until the paid period expires — do not downgrade immediately
      newStatus    = "active";
      newExpiresAt = expiresAt;
      break;

    case "EXPIRATION":
    case "REFUND":
      newStatus    = "none";
      newExpiresAt = null;
      break;

    case "BILLING_ISSUE":
      // Only grant grace on genuine billing issues — never on unknown events
      // Grace period: 24 hours from now (enforced in the DB trigger too)
      newStatus    = "grace";
      newExpiresAt = new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString();
      break;

    default:
      console.log(`[revenuecat-webhook] Unhandled event type: ${event.type} — no DB update.`);
      return new Response("OK", { status: 200 });
  }

  // ── Persist the new subscription state ────────────────────
  const { error: updateError } = await supabase
    .from("users")
    .update({
      subscription_status:     newStatus,
      subscription_expires_at: newExpiresAt,
      last_billing_event_ts:   eventTimestampMs,
    })
    .eq("id", supabaseUserId);

  if (updateError) {
    console.error(
      `[revenuecat-webhook] DB update failed for ${supabaseUserId}:`,
      updateError.message
    );
    return new Response("Internal Server Error", { status: 500 });
  }

  // ── Send push notification on key events ──────────────────
  if (event.type === "EXPIRATION") {
    await supabase.rpc("queue_notification", {
      p_user_id:  supabaseUserId,
      p_type:     "subscription_expired",
      p_title:    "Your NOOR subscription has ended",
      p_body:     "Renew today to keep messaging your connections.",
      p_deep_link:"noor://subscription",
    });
  }

  if (event.type === "BILLING_ISSUE") {
    await supabase.rpc("queue_notification", {
      p_user_id:  supabaseUserId,
      p_type:     "billing_issue",
      p_title:    "Payment issue — action required",
      p_body:     "Please update your payment method to continue messaging.",
      p_deep_link:"noor://subscription",
    });
  }

  console.log(
    `[revenuecat-webhook] ✅ Updated user ${supabaseUserId}: ${newStatus} (expires: ${newExpiresAt})`
  );

  return new Response("OK", { status: 200 });
});

// ── HMAC Signature Verification ───────────────────────────────

async function verifyHmac(body: string, signature: string, secret: string): Promise<boolean> {
  try {
    const encoder = new TextEncoder();
    const key = await crypto.subtle.importKey(
      "raw",
      encoder.encode(secret),
      { name: "HMAC", hash: "SHA-256" },
      false,
      ["verify"]
    );
    const sigBytes = hexToBytes(signature);
    return await crypto.subtle.verify("HMAC", key, sigBytes, encoder.encode(body));
  } catch {
    return false;
  }
}

function hexToBytes(hex: string): Uint8Array {
  const bytes = new Uint8Array(hex.length / 2);
  for (let i = 0; i < hex.length; i += 2) {
    bytes[i / 2] = parseInt(hex.substring(i, i + 2), 16);
  }
  return bytes;
}

// ── Type definitions ───────────────────────────────────────────

interface RevenueCatEvent {
  type: string;
  app_user_id: string;
  event_timestamp_ms?: number;
  expiration_at_ms?: number;
  product_id?: string;
  period_type?: string;
  currency?: string;
  price?: number;
}

interface RevenueCatWebhookPayload {
  event?: RevenueCatEvent;
  api_version?: string;
}
