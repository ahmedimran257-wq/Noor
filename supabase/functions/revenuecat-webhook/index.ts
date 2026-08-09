import { createClient } from "@supabase/supabase-js";
import { corsHeaders } from "../_shared/cors.ts";
import {
  renderSubscriptionEmail,
  sendBrevoTransactionalEmail,
} from "../_shared/transactional_email.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const REVENUECAT_WEBHOOK_SECRET =
  Deno.env.get("REVENUECAT_WEBHOOK_SECRET")?.trim() ?? "";
const BREVO_API_KEY = Deno.env.get("BREVO_API_KEY") ?? "";
const REVENUECAT_EXPECTED_APP_ID = Deno.env.get("REVENUECAT_EXPECTED_APP_ID") ??
  "";
const REVENUECAT_EXPECTED_ENVIRONMENT =
  Deno.env.get("REVENUECAT_EXPECTED_ENVIRONMENT") ?? "PRODUCTION";
const REVENUECAT_EXPECTED_ENTITLEMENT_ID =
  Deno.env.get("REVENUECAT_EXPECTED_ENTITLEMENT_ID") ?? "";
const REVENUECAT_ALLOWED_PRODUCT_IDS = csvSet(
  Deno.env.get("REVENUECAT_ALLOWED_PRODUCT_IDS"),
);
const REVENUECAT_ALLOWED_STORES = csvSet(
  Deno.env.get("REVENUECAT_ALLOWED_STORES"),
);

function createAdminClient() {
  return createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
}
type AdminClient = ReturnType<typeof createAdminClient>;

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (REVENUECAT_WEBHOOK_SECRET.length < 32) {
    console.error("[revenuecat-webhook] Webhook secret is not configured.");
    return new Response("Service Unavailable", { status: 503 });
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
  if (!event || !validRevenueCatEvent(event)) {
    return new Response("Bad Request: missing event", { status: 400 });
  }
  if (
    !REVENUECAT_EXPECTED_APP_ID ||
    !REVENUECAT_EXPECTED_ENTITLEMENT_ID ||
    REVENUECAT_ALLOWED_PRODUCT_IDS.size === 0 ||
    REVENUECAT_ALLOWED_STORES.size === 0
  ) {
    console.error("[revenuecat-webhook] Production allowlist is incomplete.");
    return new Response("Service Unavailable", { status: 503 });
  }
  const productionValidation = validateProductionRevenueCatEvent(event);
  if (productionValidation != null) {
    console.warn(
      `[revenuecat-webhook] Rejected non-production event: ${productionValidation}`,
    );
    return new Response("Bad Request: event is outside the production app", {
      status: 400,
    });
  }

  const supabaseUserId = event.app_user_id;
  if (!supabaseUserId || !isUuid(supabaseUserId)) {
    console.error("[revenuecat-webhook] Invalid app_user_id in event.");
    return new Response("OK", { status: 200 });
  }

  const supabase = createAdminClient();

  const eventTimestampMs = event.event_timestamp_ms!;
  let newStatus: "active" | "none" | "grace";
  let newExpiresAt: string | null = null;

  const expiresAt = event.expiration_at_ms
    ? new Date(event.expiration_at_ms).toISOString()
    : null;
  const graceExpiresAt = event.grace_period_expiration_at_ms
    ? new Date(event.grace_period_expiration_at_ms).toISOString()
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
      if (!graceExpiresAt && !expiresAt) {
        return new Response("Bad Request: missing authoritative grace expiry", {
          status: 400,
        });
      }
      newStatus = "grace";
      newExpiresAt = graceExpiresAt ?? expiresAt;
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
      p_provider_event_id: event.id,
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

  if (
    !applyResult?.applied &&
    !["stale_event", "duplicate_event"].includes(
      String(applyResult?.reason ?? ""),
    )
  ) {
    console.log(
      `[revenuecat-webhook] Ignored event for ${supabaseUserId}: ${
        applyResult?.reason ?? "not_applied"
      }`,
    );
    return new Response("OK", { status: 200 });
  }

  // Duplicate RevenueCat deliveries are expected. Database state and in-app
  // notifications are changed only once, while a failed transactional email
  // remains claimable from the durable outbox on a webhook retry.
  if (applyResult?.applied) {
    await queueSubscriptionNotification(supabase, supabaseUserId, event.type);
  }

  const emailDedupeKey = applyResult?.email_dedupe_key ??
    `revenuecat:${supabaseUserId}:${event.type}:${eventTimestampMs}`;
  try {
    await deliverSubscriptionEmail(
      supabase,
      emailDedupeKey,
      event,
      expiresAt,
    );
  } catch (error) {
    console.error(
      `[revenuecat-webhook] Transactional email deferred for ${supabaseUserId}:`,
      error instanceof Error ? error.message : "unknown delivery error",
    );
    // RevenueCat retries non-2xx responses. The event ledger prevents a second
    // subscription mutation and the outbox prevents a duplicate email.
    return new Response("Email delivery deferred", { status: 500 });
  }

  console.log(
    `[revenuecat-webhook] Updated user ${supabaseUserId}: ${newStatus} (expires: ${newExpiresAt})`,
  );

  return new Response("OK", { status: 200 });
});

interface RevenueCatEvent {
  id: string;
  type: string;
  app_user_id: string;
  event_timestamp_ms?: number;
  expiration_at_ms?: number;
  grace_period_expiration_at_ms?: number;
  product_id?: string;
  period_type?: string;
  currency?: string;
  price?: number;
  store?: string;
  transaction_id?: string;
  original_transaction_id?: string;
  original_app_user_id?: string;
  aliases?: string[];
  app_id?: string;
  environment?: string;
  entitlement_ids?: string[];
  cancel_reason?: string;
}

function validRevenueCatEvent(event: RevenueCatEvent): boolean {
  const timestamp = event.event_timestamp_ms;
  const now = Date.now();
  return typeof event.id === "string" &&
    event.id.length >= 8 &&
    event.id.length <= 200 &&
    typeof event.type === "string" &&
    typeof event.app_user_id === "string" &&
    Number.isSafeInteger(timestamp) &&
    timestamp! >= Date.UTC(2018, 0, 1) &&
    timestamp! <= now + 5 * 60 * 1000 &&
    (event.expiration_at_ms == null ||
      Number.isSafeInteger(event.expiration_at_ms)) &&
    (event.grace_period_expiration_at_ms == null ||
      Number.isSafeInteger(event.grace_period_expiration_at_ms)) &&
    (event.price == null ||
      (Number.isFinite(event.price) && event.price >= 0));
}

function validateProductionRevenueCatEvent(
  event: RevenueCatEvent,
): string | null {
  if (event.app_id !== REVENUECAT_EXPECTED_APP_ID) return "app_id";
  if (event.environment !== REVENUECAT_EXPECTED_ENVIRONMENT) {
    return "environment";
  }
  if (
    !Array.isArray(event.entitlement_ids) ||
    !event.entitlement_ids.includes(REVENUECAT_EXPECTED_ENTITLEMENT_ID)
  ) return "entitlement";
  if (
    typeof event.product_id !== "string" ||
    !REVENUECAT_ALLOWED_PRODUCT_IDS.has(event.product_id)
  ) return "product";
  if (
    typeof event.store !== "string" ||
    !REVENUECAT_ALLOWED_STORES.has(event.store)
  ) return "store";
  if (
    event.original_app_user_id != null &&
    event.original_app_user_id !== event.app_user_id &&
    !event.aliases?.includes(event.app_user_id)
  ) return "original_identity";
  return null;
}

function csvSet(value: string | undefined): Set<string> {
  return new Set(
    String(value ?? "")
      .split(",")
      .map((item) => item.trim())
      .filter(Boolean),
  );
}

interface RevenueCatWebhookPayload {
  event?: RevenueCatEvent;
  api_version?: string;
}

async function deliverSubscriptionEmail(
  supabase: AdminClient,
  dedupeKey: string,
  event: RevenueCatEvent,
  expiresAt: string | null,
): Promise<void> {
  const { data: claimedRows, error: claimError } = await supabase.rpc(
    "claim_transactional_email",
    { p_dedupe_key: dedupeKey },
  );
  if (claimError) {
    throw new Error(
      `Could not claim transactional email: ${claimError.message}`,
    );
  }

  const claimed = Array.isArray(claimedRows) ? claimedRows[0] : claimedRows;
  if (!claimed) {
    // Already sent, currently being delivered by another invocation, exhausted,
    // or an event from before the outbox migration. All are safe no-op states.
    return;
  }

  try {
    if (!BREVO_API_KEY) {
      throw new Error("BREVO_API_KEY is not configured.");
    }

    const [{ data: user, error: userError }, { data: profile }] = await Promise
      .all([
        supabase
          .from("users")
          .select("email")
          .eq("id", event.app_user_id)
          .single(),
        supabase
          .from("profiles")
          .select("first_name")
          .eq("user_id", event.app_user_id)
          .maybeSingle(),
      ]);

    const emailAddress = user?.email?.toString().trim();
    if (userError || !emailAddress) {
      throw new Error("Verified billing email is unavailable for this user.");
    }

    const firstName = profile?.first_name?.toString().trim() || null;
    const email = renderSubscriptionEmail({
      eventType: event.type,
      firstName,
      productId: event.product_id,
      currency: event.currency,
      price: event.price,
      expiresAt,
      store: event.store,
      transactionId: event.transaction_id ?? event.original_transaction_id,
    });
    const messageId = await sendBrevoTransactionalEmail({
      apiKey: BREVO_API_KEY,
      to: emailAddress,
      recipientName: firstName,
      email,
      dedupeKey,
    });

    const { error: sentError } = await supabase
      .from("transactional_email_outbox")
      .update({
        status: "sent",
        sent_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
        provider_message_id: messageId,
        last_error: null,
      })
      .eq("id", claimed.id)
      .eq("status", "sending");
    if (sentError) {
      throw new Error(
        `Could not finalize email delivery: ${sentError.message}`,
      );
    }
  } catch (error) {
    const safeMessage = error instanceof Error
      ? error.message.slice(0, 300)
      : "Unknown transactional email failure";
    await supabase
      .from("transactional_email_outbox")
      .update({
        status: "failed",
        updated_at: new Date().toISOString(),
        last_error: safeMessage,
      })
      .eq("id", claimed.id);
    throw error;
  }
}

async function queueSubscriptionNotification(
  supabase: AdminClient,
  userId: string,
  eventType: string,
): Promise<void> {
  const copy: Record<string, [string, string, string]> = {
    INITIAL_PURCHASE: [
      "subscription_active",
      "Silarah Premium is active",
      "Your membership is ready across your supported devices.",
    ],
    RENEWAL: [
      "subscription_renewed",
      "Your membership renewed",
      "Your Premium access continues without interruption.",
    ],
    PRODUCT_CHANGE: [
      "subscription_updated",
      "Your membership plan changed",
      "Your latest plan is now reflected on your Silarah account.",
    ],
    CANCELLATION: [
      "subscription_cancelled",
      "Renewal cancelled",
      "Premium remains available until the end of your current paid period.",
    ],
    EXPIRATION: [
      "subscription_expired",
      "Your Silarah subscription has ended",
      "You can review membership options whenever you are ready.",
    ],
    REFUND: [
      "subscription_refunded",
      "Membership refund update",
      "Your Premium access was updated after a refund from your payment provider.",
    ],
    BILLING_ISSUE: [
      "billing_issue",
      "Payment issue - action required",
      "Please update your payment method to avoid losing Premium access.",
    ],
  };
  const notification = copy[eventType];
  if (!notification) return;
  const [type, title, body] = notification;
  const { error } = await supabase.rpc("queue_notification", {
    p_user_id: userId,
    p_type: type,
    p_title: title,
    p_body: body,
    p_deep_link: "silarah://subscription",
  });
  if (error) {
    console.error(
      `[revenuecat-webhook] In-app notification failed for ${userId}:`,
      error.message,
    );
  }
}

function isUuid(value: string): boolean {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
    .test(value);
}
