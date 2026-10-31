// EDGE FUNCTION: staff-alert-email
//
// Emails active staff when an operational alert first fires: a free-plan
// limit reaching 70 % or 85 %, push dispatch failing, email failures and so
// on. The database queues one row per newly fired alert
// (private.set_operational_alert) and wakes this worker through pg_net; an
// hourly cron retries anything left behind. It only runs when an alert fires.
import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { corsHeaders } from "../_shared/cors.ts";
import { isAuthorizedCronRequest } from "../_shared/cron_auth.ts";
import {
  BRAND,
  paragraph,
  panel,
  renderEmailLayout,
} from "../_shared/email_layout.ts";
import { sendBrevoTransactionalEmail } from "../_shared/transactional_email.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const BREVO_API_KEY = Deno.env.get("BREVO_API_KEY") ?? "";
const ADMIN_URL = "https://admin.silarah.com/system";

interface QueuedAlert {
  id: number;
  alert_key: string;
  message: string;
  created_at: string;
  recipients: string[];
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (!(await isAuthorizedCronRequest(req))) {
    console.warn("[staff-alert-email] Unauthorized invocation blocked.");
    return new Response("Unauthorized", { status: 401 });
  }
  if (!BREVO_API_KEY) {
    console.error("[staff-alert-email] BREVO_API_KEY is not configured.");
    return new Response("Email provider unavailable", { status: 503 });
  }

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const { data, error } = await supabase.rpc("claim_staff_alert_emails", {
    p_limit: 10,
  });
  if (error) {
    console.error("[staff-alert-email] Claim failed:", error.message);
    return new Response("Internal Server Error", { status: 500 });
  }

  const alerts = (data ?? []) as QueuedAlert[];
  let sent = 0;
  for (const alert of alerts) {
    const recipients = (alert.recipients ?? []).filter((email) =>
      /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)
    );
    if (recipients.length === 0) {
      await complete(supabase, alert.id, false, "no_active_staff_email");
      continue;
    }
    const email = render(alert);
    try {
      for (const to of recipients) {
        await sendBrevoTransactionalEmail({
          apiKey: BREVO_API_KEY,
          to,
          email,
          dedupeKey: `staff-alert-${alert.id}-${to}`,
          tags: ["transactional", "staff-alert"],
        });
      }
      await complete(supabase, alert.id, true, null);
      sent++;
    } catch (sendError) {
      const message = sendError instanceof Error
        ? sendError.message
        : "send_failed";
      console.error("[staff-alert-email] Send failed:", message);
      await complete(supabase, alert.id, false, message);
    }
  }

  return Response.json({ claimed: alerts.length, sent });
});

async function complete(
  supabase: SupabaseClient,
  id: number,
  sentOk: boolean,
  error: string | null,
) {
  const { error: rpcError } = await supabase.rpc("complete_staff_alert_email", {
    p_id: id,
    p_sent: sentOk,
    p_error: error,
  });
  if (rpcError) {
    console.error("[staff-alert-email] Complete failed:", rpcError.message);
  }
}

function escapeHtml(value: string): string {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}

function render(alert: QueuedAlert) {
  const isLimit = /_(70|85)$/.test(alert.alert_key);
  const level = alert.alert_key.endsWith("_85") ? "85%" : "70%";
  const subject = isLimit
    ? `Silarah: free-plan limit at ${level}`
    : "Silarah: system alert";
  const when = new Date(alert.created_at).toUTCString();
  const message = escapeHtml(alert.message);
  const html = renderEmailLayout({
    title: subject,
    preheader: alert.message.slice(0, 120),
    eyebrow: "Staff alert",
    heading: isLimit ? `A free-plan limit reached ${level}` : "System alert",
    tone: "attention",
    body: [
      panel("What happened", message, { tone: "attention" }),
      paragraph(`Raised ${escapeHtml(when)}.`),
      paragraph(
        `Open <a href="${ADMIN_URL}" style="color:${BRAND.emeraldDeep};">System health</a> in the admin app for the current figures.`,
        { last: true },
      ),
    ].join("\n"),
    reason:
      "You receive this because you are active Silarah staff. One email is sent when an alert first fires.",
  });
  const text = [
    subject,
    "",
    alert.message,
    "",
    `Raised ${when}.`,
    `System health: ${ADMIN_URL}`,
    "",
    "You receive this because you are active Silarah staff.",
  ].join("\n");
  return { subject, html, text };
}
