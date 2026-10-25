// Supabase Auth (GoTrue) sends these HTML-only templates through Brevo SMTP.
// They are generated from the shared layout so sign-in mail matches the
// membership mail. Regenerate the committed files with:
//   deno run --allow-write=supabase/auth tool/render_auth_email_templates.ts
// from the repository root. `{{ .Token }}` is a GoTrue placeholder and must
// appear exactly once in each template.

import {
  BRAND,
  footerBand,
  note,
  panel,
  paragraph,
  renderEmailLayout,
  steps,
  SUPPORT_EMAIL,
} from "./email_layout.ts";

const TOKEN = "{{ .Token }}";

const SENDER_REASON =
  "Sent by noreply@mail.silarah.com because a code was requested for this address in the Silarah app.";

const supportLink =
  `<a class="link" href="mailto:${SUPPORT_EMAIL}" style="color:${BRAND.emerald};text-decoration:underline;">${SUPPORT_EMAIL}</a>`;

const safetyNotes = [
  note(
    "<strong>Expires in 10 minutes.</strong> Requesting a new code replaces this one.",
  ),
  note(
    "Silarah staff will never ask for this code, whether by phone, message or email.",
  ),
];

export function renderSignInCodeTemplate(): string {
  return renderEmailLayout({
    title: "Your Silarah sign-in code",
    preheader:
      "Your one-time Silarah code is inside. It expires in 10 minutes, so please keep it to yourself.",
    eyebrow: "Sign in",
    heading: "Your sign-in code",
    reason: SENDER_REASON,
    body: [
      paragraph(
        "Assalamu alaikum. Enter this code in the Silarah app to continue where you left off. It works once, and only for the next 10 minutes.",
      ),
      panel("Your code", TOKEN, { mono: true }),
      ...safetyNotes,
      `<tr><td style="padding:30px 0 0;font-size:0;line-height:0;">&nbsp;</td></tr>`,
      footerBand(
        `Didn&rsquo;t ask to sign in? You can ignore this email and your account stays protected. If it keeps happening, write to ${supportLink}.`,
      ),
    ].join("\n"),
  });
}

export function renderWelcomeCodeTemplate(): string {
  return renderEmailLayout({
    title: "Welcome to Silarah",
    preheader:
      "Welcome to Silarah. Confirm your email with this one-time code, then begin your private profile.",
    eyebrow: "Welcome to Silarah",
    heading: "Confirm your email",
    reason: SENDER_REASON,
    body: [
      paragraph(
        "Assalamu alaikum, and welcome. Enter this code in the app to confirm this email is yours. Then you can begin your profile, privately and at your own pace.",
      ),
      panel("Your code", TOKEN, { mono: true }),
      ...safetyNotes,
      steps("After verification", [
        [
          "Create your private profile",
          "You choose what is shared, and nothing is visible until you decide.",
        ],
        [
          "Set meaningful preferences",
          "Shape introductions around faith, family and the things that matter to you.",
        ],
        [
          "Go live after a quick photo check",
          "Your profile appears once your main photo has been reviewed for everyone&rsquo;s safety.",
        ],
      ]),
      `<tr><td style="padding:30px 0 0;font-size:0;line-height:0;">&nbsp;</td></tr>`,
      footerBand(
        `Didn&rsquo;t start a Silarah profile? You can safely ignore this email; nothing further happens without this code. Questions are always welcome at ${supportLink}.`,
      ),
    ].join("\n"),
  });
}
