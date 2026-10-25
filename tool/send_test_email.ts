// Sends one membership email through the production Brevo path, for an inbox
// placement check (for example to a fresh https://www.mail-tester.com address,
// or a Gmail and an Outlook.com inbox you own). The key is read from the
// environment and never printed.
//
//   $env:BREVO_API_KEY = "<server-side Brevo key>"
//   deno run --allow-env=BREVO_API_KEY --allow-net=api.brevo.com tool/send_test_email.ts you@example.com [EVENT]
//
// EVENT defaults to INITIAL_PURCHASE; any renderer event type works.
import {
  renderSubscriptionEmail,
  sendBrevoTransactionalEmail,
} from "../supabase/functions/_shared/transactional_email.ts";

const [to, eventType = "INITIAL_PURCHASE"] = Deno.args;
const apiKey = Deno.env.get("BREVO_API_KEY") ?? "";
if (!to || !to.includes("@")) {
  throw new Error("Usage: send_test_email.ts <recipient> [EVENT]");
}
if (!apiKey) throw new Error("Set BREVO_API_KEY first.");

const email = renderSubscriptionEmail({
  eventType,
  firstName: "Amina",
  productId: "silarah_three_month:three-month",
  currency: "INR",
  price: 1499,
  expiresAt: new Date(Date.now() + 90 * 86_400_000).toISOString(),
  store: "PLAY_STORE",
  transactionId: "GPA.0000-0000-0000-00000",
});
const messageId = await sendBrevoTransactionalEmail({
  apiKey,
  to,
  recipientName: "Amina",
  email: { ...email, subject: `[Test] ${email.subject}` },
  dedupeKey: `manual-test:${eventType}:${crypto.randomUUID()}`,
});
console.log(
  `Sent ${eventType} to ${to} (Brevo message ${messageId ?? "unknown"}).`,
);
