import { corsHeaders } from "../_shared/cors.ts";
import { isAuthorizedCronRequest } from "../_shared/cron_auth.ts";

const BREVO_API_KEY = Deno.env.get("BREVO_API_KEY") ?? "";

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (!(await isAuthorizedCronRequest(request))) {
    console.warn("[brevo-key-keepalive] Unauthorized invocation blocked.");
    return new Response("Unauthorized", { status: 401 });
  }

  if (!BREVO_API_KEY) {
    console.error("[brevo-key-keepalive] BREVO_API_KEY is not configured.");
    return new Response("Email provider unavailable", { status: 503 });
  }

  // Brevo expires even a no-expiration API key after 90 days of inactivity.
  // This authenticated account lookup records safe API activity without
  // sending mail, reading contacts, or modifying provider data.
  let response: Response;
  try {
    response = await fetch("https://api.brevo.com/v3/account", {
      headers: { "api-key": BREVO_API_KEY },
      signal: AbortSignal.timeout(8_000),
    });
  } catch {
    console.error("[brevo-key-keepalive] Provider request timed out.");
    return new Response("Email provider unavailable", { status: 503 });
  }

  if (!response.ok) {
    console.error(
      `[brevo-key-keepalive] Provider health check failed: ${response.status}`,
    );
    return new Response("Email provider rejected the request", { status: 502 });
  }

  console.log("[brevo-key-keepalive] Provider credential remains active.");
  return Response.json({ healthy: true });
});
