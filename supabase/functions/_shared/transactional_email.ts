export interface SubscriptionEmailInput {
  eventType: string;
  firstName?: string | null;
  productId?: string | null;
  currency?: string | null;
  price?: number | null;
  expiresAt?: string | null;
  store?: string | null;
  transactionId?: string | null;
}

export interface RenderedTransactionalEmail {
  subject: string;
  html: string;
  text: string;
}

interface SubscriptionEmailCopy {
  eyebrow: string;
  heading: string;
  intro: string;
  statusLabel: string;
  statusValue: string;
  actionLabel: string;
  actionUrl: string;
  note: string;
}

const APP_URL = "https://silarah.com/app/";
const SUPPORT_URL = "https://silarah.com/help/";

export function renderSubscriptionEmail(
  input: SubscriptionEmailInput,
): RenderedTransactionalEmail {
  const firstName = cleanFirstName(input.firstName);
  const greeting = firstName
    ? `Assalamu alaikum ${firstName},`
    : "Assalamu alaikum,";
  const plan = planName(input.productId);
  const amount = formatAmount(input.price, input.currency);
  const effectiveDate = formatDate(input.expiresAt);
  const reference = shortReference(input.transactionId);
  const store = storeName(input.store);
  const copy = copyFor(input.eventType, effectiveDate, store);

  const details = [
    ["Membership", plan],
    ...(amount ? [["Amount", amount]] : []),
    ...(effectiveDate ? [[dateLabel(input.eventType), effectiveDate]] : []),
    ...(store ? [["Payment provider", store]] : []),
    ...(reference ? [["Reference", reference]] : []),
  ];

  const detailRows = details.map(([label, value]) => `
    <tr>
      <td style="padding:11px 0;border-bottom:1px solid #2a282f;color:#8f8a94;font-size:13px;line-height:20px;">${
    escapeHtml(label)
  }</td>
      <td align="right" style="padding:11px 0;border-bottom:1px solid #2a282f;color:#eee8de;font-size:13px;line-height:20px;font-weight:650;">${
    escapeHtml(value)
  }</td>
    </tr>`).join("");

  const subject = subjectFor(input.eventType, plan);
  const html = `<!doctype html>
<html lang="en" xmlns="http://www.w3.org/1999/xhtml">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <meta name="color-scheme" content="light dark">
  <meta name="supported-color-schemes" content="light dark">
  <title>${escapeHtml(subject)}</title>
</head>
<body style="margin:0;padding:0;background:#09090d;color:#f6f1e8;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;-webkit-text-size-adjust:100%;">
  <div style="display:none;max-height:0;overflow:hidden;opacity:0;color:transparent;">${
    escapeHtml(copy.intro)
  }</div>
  <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="width:100%;background:#09090d;">
    <tr><td align="center" style="padding:40px 16px;">
      <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="width:100%;max-width:600px;">
        <tr><td style="padding:0 8px 24px;text-align:left;">
          <div style="font-size:24px;line-height:30px;font-weight:750;letter-spacing:3px;color:#d9b965;"><span style="font-family:Tahoma,Arial,sans-serif;letter-spacing:0;">&#1587;&#1610;&#1604;&#1575;&#1585;&#1575;</span>&nbsp;&nbsp;SILARAH</div>
          <div style="padding-top:7px;font-size:11px;line-height:18px;letter-spacing:1.6px;text-transform:uppercase;color:#8d8992;">Membership services</div>
        </td></tr>
        <tr><td style="background:#141419;border:1px solid #343038;border-radius:20px;overflow:hidden;">
          <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0">
            <tr><td style="height:4px;background:#d9b965;font-size:0;line-height:0;">&nbsp;</td></tr>
            <tr><td style="padding:42px 44px 20px;">
              <div style="display:inline-block;padding:6px 11px;border:1px solid #51482f;border-radius:999px;background:#1c1a16;color:#d9b965;font-size:11px;line-height:16px;font-weight:700;letter-spacing:1.2px;text-transform:uppercase;">${
    escapeHtml(copy.eyebrow)
  }</div>
              <h1 style="margin:21px 0 12px;font-family:Georgia,'Times New Roman',serif;font-size:32px;line-height:39px;font-weight:600;letter-spacing:-0.45px;color:#f6f1e8;">${
    escapeHtml(copy.heading)
  }</h1>
              <p style="margin:0 0 14px;font-size:16px;line-height:26px;color:#d0cad3;">${
    escapeHtml(greeting)
  }</p>
              <p style="margin:0;font-size:15px;line-height:25px;color:#aaa5ae;">${
    escapeHtml(copy.intro)
  }</p>
            </td></tr>
            <tr><td style="padding:8px 44px 22px;">
              <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="background:#0d0d11;border:1px solid #4d4430;border-radius:15px;">
                <tr><td style="padding:22px 24px;">
                  <div style="font-size:10px;line-height:15px;font-weight:700;letter-spacing:1.35px;text-transform:uppercase;color:#88838d;">${
    escapeHtml(copy.statusLabel)
  }</div>
                  <div style="padding-top:6px;font-size:20px;line-height:28px;font-weight:700;color:#edcf7b;">${
    escapeHtml(copy.statusValue)
  }</div>
                </td></tr>
              </table>
            </td></tr>
            <tr><td style="padding:0 44px 29px;">
              <div style="margin-bottom:8px;font-size:10px;line-height:15px;font-weight:700;letter-spacing:1.35px;text-transform:uppercase;color:#88838d;">Membership details</div>
              <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0">${detailRows}</table>
            </td></tr>
            <tr><td align="center" style="padding:0 44px 35px;">
              <a href="${
    escapeHtml(copy.actionUrl)
  }" style="display:block;padding:15px 20px;border-radius:12px;background:#d9b965;color:#111116;text-decoration:none;font-size:15px;line-height:20px;font-weight:750;text-align:center;">${
    escapeHtml(copy.actionLabel)
  }</a>
              <p style="margin:16px 0 0;font-size:12px;line-height:19px;color:#77737f;">${
    escapeHtml(copy.note)
  }</p>
            </td></tr>
            <tr><td style="padding:21px 44px;background:#101014;border-top:1px solid #2b2930;font-size:12px;line-height:20px;color:#85818a;">This transactional message was sent because your Silarah membership changed. Payment collection, tax documents, and store receipts are issued by your payment provider.</td></tr>
          </table>
        </td></tr>
        <tr><td style="padding:25px 8px 0;text-align:center;font-size:12px;line-height:20px;color:#77737c;">
          <a href="${SUPPORT_URL}" style="color:#aaa4af;text-decoration:underline;">Membership support</a>
          <span style="padding:0 8px;color:#4e4b52;">&bull;</span>
          <a href="https://silarah.com/terms/" style="color:#aaa4af;text-decoration:underline;">Terms</a>
          <span style="padding:0 8px;color:#4e4b52;">&bull;</span>
          <a href="https://silarah.com/privacy/" style="color:#aaa4af;text-decoration:underline;">Privacy</a>
          <br><span style="display:inline-block;padding-top:9px;">Silarah &mdash; thoughtful introductions, handled privately.</span>
        </td></tr>
      </table>
    </td></tr>
  </table>
</body>
</html>`;

  const detailText = details.map(([label, value]) => `${label}: ${value}`).join(
    "\n",
  );
  const text =
    `SILARAH\n\n${copy.heading}\n\n${greeting}\n\n${copy.intro}\n\n${copy.statusLabel}: ${copy.statusValue}\n\n${detailText}\n\n${copy.actionLabel}: ${copy.actionUrl}\n\n${copy.note}\n\nMembership support: ${SUPPORT_URL}`;

  return { subject, html, text };
}

export async function sendBrevoTransactionalEmail(args: {
  apiKey: string;
  to: string;
  recipientName?: string | null;
  email: RenderedTransactionalEmail;
  dedupeKey: string;
}): Promise<string | null> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 10_000);
  let response: Response;
  try {
    response = await fetch("https://api.brevo.com/v3/smtp/email", {
      method: "POST",
      signal: controller.signal,
      headers: {
        accept: "application/json",
        "api-key": args.apiKey,
        "content-type": "application/json",
        "idempotency-key": args.dedupeKey,
      },
      body: JSON.stringify({
        sender: { name: "Silarah", email: "noreply@mail.silarah.com" },
        replyTo: { name: "Silarah Support", email: "support@silarah.com" },
        to: [{
          email: args.to,
          ...(args.recipientName ? { name: args.recipientName } : {}),
        }],
        subject: args.email.subject,
        htmlContent: args.email.html,
        textContent: args.email.text,
        tags: ["transactional", "subscription"],
        headers: { "X-Silarah-Dedupe-Key": args.dedupeKey },
      }),
    });
  } finally {
    clearTimeout(timeout);
  }

  if (!response.ok) {
    throw new Error(`Brevo rejected transactional email (${response.status}).`);
  }

  const responseText = await readResponseTextLimited(response, 64 * 1024);
  const payload = (() => {
    try {
      return JSON.parse(responseText) as { messageId?: string };
    } catch {
      return {};
    }
  })();
  return payload.messageId ?? null;
}

async function readResponseTextLimited(
  response: Response,
  maxBytes: number,
): Promise<string> {
  if (!response.body) return "";
  const reader = response.body.getReader();
  const decoder = new TextDecoder();
  let bytesRead = 0;
  let result = "";
  while (bytesRead < maxBytes) {
    const { value, done } = await reader.read();
    if (done || !value) break;
    const remaining = Math.min(value.byteLength, maxBytes - bytesRead);
    result += decoder.decode(value.slice(0, remaining), { stream: true });
    bytesRead += remaining;
  }
  await reader.cancel().catch(() => undefined);
  return result;
}

function copyFor(
  eventType: string,
  effectiveDate: string | null,
  store: string | null,
): SubscriptionEmailCopy {
  const manageUrl = store === "Apple App Store"
    ? "https://apps.apple.com/account/subscriptions"
    : store === "Google Play"
    ? "https://play.google.com/store/account/subscriptions"
    : APP_URL;

  switch (eventType) {
    case "INITIAL_PURCHASE":
      return {
        eyebrow: "Membership confirmed",
        heading: "Welcome to Silarah Premium.",
        intro:
          "Your membership is active. Premium access is now connected to your Silarah account across supported devices.",
        statusLabel: "Membership status",
        statusValue: "Active",
        actionLabel: "Open Silarah",
        actionUrl: APP_URL,
        note:
          "Your payment provider sends the official purchase receipt separately.",
      };
    case "RENEWAL":
      return {
        eyebrow: "Renewal confirmed",
        heading: "Your membership continues.",
        intro:
          "Your Silarah Premium membership renewed successfully, with no interruption to your access.",
        statusLabel: "Membership status",
        statusValue: "Renewed",
        actionLabel: "Open Silarah",
        actionUrl: APP_URL,
        note:
          "Your payment provider sends the official renewal receipt separately.",
      };
    case "PRODUCT_CHANGE":
      return {
        eyebrow: "Plan updated",
        heading: "Your membership plan changed.",
        intro:
          "Your requested plan change has been recorded. The membership details below reflect the latest information supplied by your payment provider.",
        statusLabel: "Membership status",
        statusValue: "Plan updated",
        actionLabel: "Review membership",
        actionUrl: APP_URL,
        note:
          "Any proration or credit is calculated and documented by your payment provider.",
      };
    case "CANCELLATION":
      return {
        eyebrow: "Cancellation confirmed",
        heading: "Your renewal has been stopped.",
        intro: effectiveDate
          ? `Your membership remains available until ${effectiveDate}. It will not renew automatically after that date.`
          : "Your automatic renewal has been stopped. Access remains available for the remainder of the paid period.",
        statusLabel: "Membership status",
        statusValue: "Ends after current period",
        actionLabel: "Manage subscription",
        actionUrl: manageUrl,
        note:
          "You can resume from your payment provider before the current period ends, where supported.",
      };
    case "EXPIRATION":
      return {
        eyebrow: "Membership ended",
        heading: "Your Premium access has ended.",
        intro:
          "Your paid membership period is complete. Your Silarah account and profile remain available under the standard experience.",
        statusLabel: "Membership status",
        statusValue: "Expired",
        actionLabel: "View membership options",
        actionUrl: APP_URL,
        note: "You can subscribe again at any time from the Silarah app.",
      };
    case "REFUND":
      return {
        eyebrow: "Refund update",
        heading: "Your membership was refunded.",
        intro:
          "Your payment provider reported a refund and Silarah Premium access has been updated accordingly.",
        statusLabel: "Membership status",
        statusValue: "Refunded",
        actionLabel: "Get membership support",
        actionUrl: SUPPORT_URL,
        note:
          "Refund timing and settlement details are controlled by your payment provider.",
      };
    case "BILLING_ISSUE":
      return {
        eyebrow: "Action required",
        heading: "There is a payment issue.",
        intro:
          "Your payment provider could not complete the latest membership charge. Please review your payment method to avoid losing Premium access.",
        statusLabel: "Membership status",
        statusValue: "Payment attention needed",
        actionLabel: "Update payment method",
        actionUrl: manageUrl,
        note:
          "Silarah never receives or stores your full card or bank details.",
      };
    default:
      throw new Error(`Unsupported subscription email event: ${eventType}`);
  }
}

function subjectFor(eventType: string, plan: string): string {
  switch (eventType) {
    case "INITIAL_PURCHASE":
      return "Your Silarah Premium membership is active";
    case "RENEWAL":
      return "Your Silarah Premium membership renewed";
    case "PRODUCT_CHANGE":
      return `Your ${plan} plan was updated`;
    case "CANCELLATION":
      return "Your Silarah renewal has been cancelled";
    case "EXPIRATION":
      return "Your Silarah Premium membership has ended";
    case "REFUND":
      return "Your Silarah membership refund update";
    case "BILLING_ISSUE":
      return "Action required: update your membership payment";
    default:
      return "Your Silarah membership update";
  }
}

function dateLabel(eventType: string): string {
  return eventType === "CANCELLATION"
    ? "Access until"
    : eventType === "INITIAL_PURCHASE" || eventType === "RENEWAL"
    ? "Renews on"
    : "Effective date";
}

function planName(productId?: string | null): string {
  const product = productId?.toLowerCase() ?? "";
  if (product.includes("annual") || product.includes("year")) {
    return "Silarah Premium Annual";
  }
  if (product.includes("month")) return "Silarah Premium Monthly";
  return "Silarah Premium";
}

function formatAmount(
  price?: number | null,
  currency?: string | null,
): string | null {
  if (price == null || !Number.isFinite(price) || !currency) return null;
  try {
    return new Intl.NumberFormat("en", {
      style: "currency",
      currency: currency.toUpperCase(),
      maximumFractionDigits: 2,
    }).format(price);
  } catch (_) {
    return `${currency.toUpperCase()} ${price.toFixed(2)}`;
  }
}

function formatDate(value?: string | null): string | null {
  if (!value) return null;
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return null;
  return new Intl.DateTimeFormat("en-GB", {
    day: "numeric",
    month: "long",
    year: "numeric",
    timeZone: "UTC",
  }).format(date);
}

function storeName(store?: string | null): string | null {
  switch (store?.toUpperCase()) {
    case "PLAY_STORE":
    case "GOOGLE_PLAY":
      return "Google Play";
    case "APP_STORE":
    case "MAC_APP_STORE":
      return "Apple App Store";
    case "STRIPE":
      return "Stripe";
    case "TEST_STORE":
      return "RevenueCat Test Store";
    default:
      return store?.trim() || null;
  }
}

function shortReference(value?: string | null): string | null {
  const reference = value?.trim();
  if (!reference) return null;
  if (reference.length <= 18) return reference;
  return `${reference.slice(0, 8)}...${reference.slice(-6)}`;
}

function cleanFirstName(value?: string | null): string | null {
  const cleaned = value?.trim().replace(/\s+/g, " ");
  if (!cleaned) return null;
  return cleaned.slice(0, 60);
}

function escapeHtml(value: string): string {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}
