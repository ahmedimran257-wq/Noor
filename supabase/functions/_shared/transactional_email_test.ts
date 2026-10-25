import { renderSubscriptionEmail } from "./transactional_email.ts";
import {
  renderSignInCodeTemplate,
  renderWelcomeCodeTemplate,
} from "./auth_email_templates.ts";

const eventTypes = [
  "INITIAL_PURCHASE",
  "RENEWAL",
  "PRODUCT_CHANGE",
  "CANCELLATION",
  "EXPIRATION",
  "REFUND",
  "BILLING_ISSUE",
];

for (const eventType of eventTypes) {
  Deno.test(`renders ${eventType} as a complete transactional email`, () => {
    const email = renderSubscriptionEmail({
      eventType,
      firstName: "Amina",
      productId: "silarah_premium_annual",
      currency: "GBP",
      price: 49.99,
      expiresAt: "2027-07-16T00:00:00.000Z",
      store: "PLAY_STORE",
      transactionId: "GPA.1234-5678-9012-34567",
    });

    if (
      !email.subject.startsWith("Your") && !email.subject.startsWith("Action")
    ) {
      throw new Error("Subject is missing transactional context.");
    }
    if (
      !email.html.includes(">Silarah</div>") ||
      !email.html.includes("Membership details") ||
      !email.html.includes("#F7F3EA") ||
      !email.html.includes("prefers-color-scheme:dark") ||
      !email.html.includes("v:roundrect")
    ) {
      throw new Error("HTML template is incomplete.");
    }
    if (
      !email.text.includes("Silarah Premium Annual") ||
      !email.text.includes("support@silarah.com") ||
      email.text.includes("<")
    ) {
      throw new Error("Plain-text alternative is incomplete.");
    }
  });
}

const planCases: [string | undefined, string][] = [
  ["silarah_monthly", "Silarah Premium Monthly"],
  ["silarah_monthly:monthly", "Silarah Premium Monthly"],
  ["silarah_three_month", "Silarah Premium 3 Months"],
  ["silarah_three_month:three-month", "Silarah Premium 3 Months"],
  ["silarah_six_month", "Silarah Premium"],
  [undefined, "Silarah Premium"],
];

for (const [productId, expected] of planCases) {
  Deno.test(`labels ${productId} as ${expected}`, () => {
    const email = renderSubscriptionEmail({
      eventType: "INITIAL_PURCHASE",
      firstName: "Amina",
      productId,
    });
    if (!email.text.includes(`Membership: ${expected}\n`)) {
      throw new Error(`Expected plan "${expected}" in:\n${email.text}`);
    }
  });
}

Deno.test("escapes account data before inserting it into HTML", () => {
  const email = renderSubscriptionEmail({
    eventType: "INITIAL_PURCHASE",
    firstName: "<script>alert('x')</script>",
  });
  if (email.html.includes("<script>")) {
    throw new Error("Untrusted profile data reached the HTML template.");
  }
});

Deno.test("keeps Google Play order IDs whole for refund requests", () => {
  const email = renderSubscriptionEmail({
    eventType: "RENEWAL",
    transactionId: "GPA.3374-2955-6735-46248",
  });
  if (!email.text.includes("Reference: GPA.3374-2955-6735-46248\n")) {
    throw new Error("Play order ID was shortened.");
  }
});

Deno.test("committed auth templates match the shared layout", async () => {
  const dir = new URL("../../auth/email_templates/", import.meta.url);
  const pairs: [string, string][] = [
    ["silarah_verification_code.html", renderSignInCodeTemplate()],
    ["silarah_welcome_verification_code.html", renderWelcomeCodeTemplate()],
  ];
  for (const [file, expected] of pairs) {
    const committed = (await Deno.readTextFile(new URL(file, dir)))
      .replace(/\r\n/g, "\n");
    if (committed !== expected) {
      throw new Error(
        `${file} is stale. Run: deno run --allow-write=supabase/auth tool/render_auth_email_templates.ts`,
      );
    }
    if (committed.split("{{ .Token }}").length !== 2) {
      throw new Error(`${file} must contain {{ .Token }} exactly once.`);
    }
  }
});
