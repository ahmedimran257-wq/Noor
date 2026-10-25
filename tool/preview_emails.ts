// Renders every Silarah email (membership + auth) into one preview page with
// light and forced-dark columns, plus each plain-text part.
// Run from the repository root:
//   deno run --allow-read=supabase --allow-write=<dir> tool/preview_emails.ts <dir>
import { renderSubscriptionEmail } from "../supabase/functions/_shared/transactional_email.ts";

const out = Deno.args[0];
if (!out) throw new Error("Pass an output directory.");

const sample = {
  firstName: "Amina",
  productId: "silarah_three_month:three-month",
  currency: "INR",
  price: 1499,
  expiresAt: "2027-01-25T00:00:00.000Z",
  store: "PLAY_STORE",
  transactionId: "GPA.3374-2955-6735-46248",
};
const events = [
  "INITIAL_PURCHASE",
  "RENEWAL",
  "PRODUCT_CHANGE",
  "CANCELLATION",
  "EXPIRATION",
  "REFUND",
  "BILLING_ISSUE",
];

const emails: { name: string; subject: string; html: string; text: string }[] =
  [];
for (
  const name of [
    "silarah_welcome_verification_code",
    "silarah_verification_code",
  ]
) {
  const html = (await Deno.readTextFile(
    `supabase/auth/email_templates/${name}.html`,
  )).replace("{{ .Token }}", "482916");
  emails.push({
    name,
    subject: name,
    html,
    text: "(HTML only: sent by Supabase Auth)",
  });
}
for (const eventType of events) {
  const email = renderSubscriptionEmail({ eventType, ...sample });
  emails.push({ name: eventType, ...email });
}

const forceDark = (html: string) =>
  html.replace("@media (prefers-color-scheme:dark)", "@media all");
const attr = (value: string) =>
  value.replaceAll("&", "&amp;").replaceAll('"', "&quot;");
const esc = (value: string) =>
  value.replaceAll("&", "&amp;").replaceAll("<", "&lt;");

const sections = emails.map((email) => `
<section>
  <h2>${esc(email.name)} <small>${esc(email.subject)}</small></h2>
  <div class="row">
    <iframe title="${attr(email.name)} light" srcdoc="${
  attr(email.html)
}"></iframe>
    <iframe title="${attr(email.name)} dark" srcdoc="${
  attr(forceDark(email.html))
}"></iframe>
    <pre>${esc(email.text)}</pre>
  </div>
</section>`).join("\n");

await Deno.mkdir(out, { recursive: true });
await Deno.writeTextFile(
  `${out}/index.html`,
  `<!doctype html><meta charset="utf-8"><title>Silarah email preview</title>
<style>body{margin:0;padding:24px;background:#ece7dc;font:14px system-ui}
h2{font:600 16px system-ui;margin:28px 0 10px}small{font-weight:400;color:#666;margin-left:8px}
.row{display:grid;grid-template-columns:1fr 1fr 360px;gap:14px}
iframe{width:100%;height:1250px;border:1px solid #ccc;background:#fff}
pre{white-space:pre-wrap;background:#fff;border:1px solid #ccc;padding:12px;margin:0;height:1226px;overflow:auto;font-size:12px}</style>
${sections}`,
);
for (const email of emails) {
  await Deno.writeTextFile(`${out}/${email.name}.html`, email.html);
}
console.log(`Wrote ${emails.length} previews to ${out}`);
