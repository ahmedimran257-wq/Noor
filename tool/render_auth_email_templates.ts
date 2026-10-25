// Writes the Supabase Auth email templates from the shared email layout.
// Run from the repository root:
//   deno run --allow-write=supabase/auth tool/render_auth_email_templates.ts
import {
  renderSignInCodeTemplate,
  renderWelcomeCodeTemplate,
} from "../supabase/functions/_shared/auth_email_templates.ts";

const dir = new URL("../supabase/auth/email_templates/", import.meta.url);
await Deno.writeTextFile(
  new URL("silarah_verification_code.html", dir),
  renderSignInCodeTemplate(),
);
await Deno.writeTextFile(
  new URL("silarah_welcome_verification_code.html", dir),
  renderWelcomeCodeTemplate(),
);
console.log("Auth email templates written.");
