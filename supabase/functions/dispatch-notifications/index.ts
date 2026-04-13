// ============================================================
// EDGE FUNCTION: dispatch-notifications
// supabase/functions/dispatch-notifications/index.ts
//
// Runs every minute via cron (or invoked on demand).
// Fetches due notifications from the queue and sends them
// via OneSignal. Uses FOR UPDATE SKIP LOCKED to prevent
// double-delivery under concurrent invocations.
//
// OneSignal targeting: by external_user_id (= Supabase user.id)
// Set this in Flutter with:
//   OneSignal.login(supabaseUserId);
// ============================================================

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";

const SUPABASE_URL          = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_KEY  = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const ONESIGNAL_APP_ID      = Deno.env.get("ONESIGNAL_APP_ID")!;
const ONESIGNAL_REST_API_KEY= Deno.env.get("ONESIGNAL_REST_API_KEY")!;

const ONESIGNAL_API_URL     = "https://onesignal.com/api/v1/notifications";
const BATCH_SIZE            = 500;

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

  // ── Dispatch each notification to OneSignal ────────────────
  const results = await Promise.allSettled(
    notifications.map((notif: NotificationRow) => sendOneSignal(notif))
  );

  const succeeded = results.filter((r) => r.status === "fulfilled").length;
  const failed    = results.filter((r) => r.status === "rejected").length;

  if (failed > 0) {
    // Mark failed notifications as unsent (reset sent_at) so they retry
    const failedIds = results
      .map((r, i) => r.status === "rejected" ? notifications[i].id : null)
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

// ── Send a single notification via OneSignal ──────────────────

async function sendOneSignal(notif: NotificationRow): Promise<void> {
  const body: Record<string, unknown> = {
    app_id:            ONESIGNAL_APP_ID,
    // Target by Supabase user ID (set via OneSignal.login() in Flutter)
    include_aliases:   { external_id: [notif.user_id] },
    target_channel:    "push",
    headings:          { en: notif.title },
    contents:          { en: notif.body },
  };

  if (notif.deep_link) {
    body.url = notif.deep_link;               // Deep link for notification tap
  }

  const res = await fetch(ONESIGNAL_API_URL, {
    method:  "POST",
    headers: {
      "Content-Type":  "application/json",
      Authorization:   `Basic ${ONESIGNAL_REST_API_KEY}`,
    },
    body: JSON.stringify(body),
  });

  if (!res.ok) {
    const err = await res.text();
    throw new Error(`OneSignal API error ${res.status}: ${err}`);
  }
}

interface NotificationRow {
  id:        string;
  user_id:   string;
  title:     string;
  body:      string;
  deep_link: string | null;
}
