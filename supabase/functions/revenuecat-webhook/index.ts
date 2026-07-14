import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const REVENUECAT_WEBHOOK_SECRET = Deno.env.get("REVENUECAT_WEBHOOK_SECRET")!;

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const authHeader = req.headers.get("Authorization") ?? "";
  if (authHeader !== `Bearer ${REVENUECAT_WEBHOOK_SECRET}`) {
    console.warn("[revenuecat-webhook] Invalid Authorization token.");
    return new Response("Unauthorized", { status: 401 });
  }

  let payload: RevenueCatWebhookPayload;
  try {
    payload = JSON.parse(await req.text());
  } catch {
    return new Response("Bad Request: invalid JSON", { status: 400 });
  }

  const event = payload.event;
  if (!event) {
    return new Response("Bad Request: missing event", { status: 400 });
  }

  const supabaseUserId = event.app_user_id;
  if (!supabaseUserId) {
    console.error("[revenuecat-webhook] No app_user_id in event.");
    return new Response("OK", { status: 200 });
  }

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  const eventTimestampMs = event.event_timestamp_ms ?? Date.now();
  let newStatus: "active" | "none" | "grace";
  let newExpiresAt: string | null = null;

  const expiresAt = event.expiration_at_ms
    ? new Date(event.expiration_at_ms).toISOString()
    : null;

  switch (event.type) {
    case "INITIAL_PURCHASE":
    case "RENEWAL":
    case "PRODUCT_CHANGE":
    case "CANCELLATION":
      newStatus = "active";
      newExpiresAt = expiresAt;
      break;
    case "EXPIRATION":
    case "REFUND":
      newStatus = "none";
      newExpiresAt = null;
      break;
    case "BILLING_ISSUE":
      newStatus = "grace";
      newExpiresAt = new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString();
      break;
    default:
      console.log(`[revenuecat-webhook] Unhandled event type: ${event.type}`);
      return new Response("OK", { status: 200 });
  }

  // Race fix: this RPC locks users.id, compares event_timestamp_ms, writes the
  // subscription state, and records the ledger row atomically. Stale concurrent
  // RevenueCat webhooks cannot overwrite newer state.
  const { data: applyResult, error: applyError } = await supabase.rpc(
    "apply_revenuecat_subscription_event",
    {
      p_user_id: supabaseUserId,
      p_event_type: event.type,
      p_event_timestamp_ms: eventTimestampMs,
      p_subscription_status: newStatus,
      p_subscription_expires_at: newExpiresAt,
      p_product_id: event.product_id ?? null,
      p_currency: event.currency ?? null,
      p_price: event.price ?? null,
      p_event_expires_at: expiresAt,
    },
  );

  if (applyError) {
    console.error(
      `[revenuecat-webhook] Atomic apply failed for ${supabaseUserId}:`,
      applyError.message,
    );
    return new Response("Internal Server Error", { status: 500 });
  }

  if (!applyResult?.applied) {
    console.log(
      `[revenuecat-webhook] Ignored event for ${supabaseUserId}: ${
        applyResult?.reason ?? "not_applied"
      }`,
    );
    return new Response("OK", { status: 200 });
  }

  if (event.type === "EXPIRATION") {
    await supabase.rpc("queue_notification", {
      p_user_id: supabaseUserId,
      p_type: "subscription_expired",
      p_title: "Your Silarah subscription has ended",
      p_body: "Renew today to keep messaging your connections.",
      p_deep_link: "silarah://subscription",
    });
  }

  if (event.type === "BILLING_ISSUE") {
    await supabase.rpc("queue_notification", {
      p_user_id: supabaseUserId,
      p_type: "billing_issue",
      p_title: "Payment issue - action required",
      p_body: "Please update your payment method to continue messaging.",
      p_deep_link: "silarah://subscription",
    });
  }

  console.log(
    `[revenuecat-webhook] Updated user ${supabaseUserId}: ${newStatus} (expires: ${newExpiresAt})`,
  );

  return new Response("OK", { status: 200 });
});

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
