// Supabase Auth Before User Created Hook.
//
// Deploy this function, then configure it in Supabase Dashboard:
// Authentication -> Hooks -> Before User Created -> HTTP Hook.
// The hook must run before public signups are accepted, because Flutter-side
// validation can be bypassed by direct Auth API calls.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const rejectedMessage =
  "Temporary or disposable email addresses are not allowed. Please use a real personal email address.";

type HookPayload = {
  email?: string;
  user?: { email?: string };
};

function response(body: Record<string, string>) {
  return new Response(JSON.stringify(body), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
}

function validEmail(email: string) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
}

Deno.serve(async (request) => {
  if (request.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  try {
    const payload = (await request.json()) as HookPayload;
    const email = (payload.user?.email ?? payload.email ?? "").trim().toLowerCase();
    if (!validEmail(email)) {
      return response({ decision: "abort", message: "Please enter a valid email address." });
    }

    const admin = createClient(supabaseUrl, serviceRoleKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    });
    const { data, error } = await admin
      .rpc("is_disposable_email_domain", { p_email: email });

    if (error) throw error;
    if (data == true) {
      return response({ decision: "abort", message: rejectedMessage });
    }

    return response({ decision: "continue" });
  } catch (error) {
    console.error("auth-before-user-created failed", error);
    // Fail closed: fake-account protections should not disappear during an
    // infrastructure outage. Supabase will surface this message to signup.
    return response({
      decision: "abort",
      message: "We could not validate this email address. Please try again.",
    });
  }
});
