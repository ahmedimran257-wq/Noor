import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, handleCors } from "../_shared/cors.ts";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
const clientId = Deno.env.get("DIGILOCKER_CLIENT_ID");
const clientSecret = Deno.env.get("DIGILOCKER_CLIENT_SECRET");
const tokenUrl = Deno.env.get("DIGILOCKER_TOKEN_URL");

Deno.serve(async (request) => {
  const corsResponse = handleCors(request);
  if (corsResponse) return corsResponse;
  if (!clientId || !clientSecret || !tokenUrl) {
    return response(503, { status: "unavailable", message: "DigiLocker is not configured." });
  }

  try {
    const authorization = request.headers.get("Authorization");
    if (!authorization?.startsWith("Bearer ")) return response(401, { message: "Authentication required." });
    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authorization } },
      auth: { autoRefreshToken: false, persistSession: false },
    });
    const { data: { user }, error } = await userClient.auth.getUser();
    if (error || !user) return response(401, { message: "Authentication required." });

    const { code, redirect_uri } = await request.json();
    if (typeof code !== "string" || typeof redirect_uri !== "string") {
      return response(400, { message: "Invalid authorization response." });
    }

    const tokenResponse = await fetch(tokenUrl, {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        grant_type: "authorization_code",
        code,
        client_id: clientId,
        client_secret: clientSecret,
        redirect_uri,
      }),
    });
    if (!tokenResponse.ok) return response(422, { message: "DigiLocker verification was not completed." });

    const admin = createClient(supabaseUrl, serviceRoleKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    });
    const { error: updateError } = await admin.from("profiles").update({
      kyc_verified: true,
      kyc_method: "digilocker_optional",
      verified_at: new Date().toISOString(),
      verification_status: "verified",
      is_verified: true,
    }).eq("user_id", user.id).eq("country_code", "IN");
    if (updateError) throw updateError;
    return response(200, { status: "verified" });
  } catch (error) {
    console.error("[digilocker-verify]", error);
    return response(500, { message: "Unable to complete DigiLocker verification." });
  }
});

function response(status: number, body: Record<string, unknown>): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
