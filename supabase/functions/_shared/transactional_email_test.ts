import { renderSubscriptionEmail } from "./transactional_email.ts";

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
      !email.html.includes("SILARAH") ||
      !email.html.includes("Membership details")
    ) {
      throw new Error("HTML template is incomplete.");
    }
    if (!email.text.includes("Silarah Premium Annual")) {
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
