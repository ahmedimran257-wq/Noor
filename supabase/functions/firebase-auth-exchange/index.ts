// ============================================================
// EDGE FUNCTION: firebase-auth-exchange
// supabase/functions/firebase-auth-exchange/index.ts
//
// The bridge between Firebase Auth (OTP) and Supabase Auth.
//
// Flow:
//   1. Flutter sends Firebase ID Token after phone OTP success
//   2. This function verifies it cryptographically
//   3. Checks if this is a new device + old account (>30d) →
//      triggers secondary verification (DOB/PIN) if so
//   4. Finds or creates the Supabase user
//   5. Issues a Supabase session via admin.generateLink()
//   6. Returns the session to Flutter
//
// Security:
//   - Firebase project ID is verified in token claims
//   - Tokens from other Firebase projects are rejected
//   - Uses Supabase admin methods, NOT manual JWT signing
//   - New device on old account (>30d) triggers 2FA gate
// ============================================================

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { verifyFirebaseToken } from "../_shared/firebase_verifier.ts";
import { corsHeaders, handleCors } from "../_shared/cors.ts";

const SUPABASE_URL        = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_KEY= Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const FIREBASE_PROJECT_ID = Deno.env.get("FIREBASE_PROJECT_ID")!;

// How long before an account is considered "established" (new device check threshold)
const ACCOUNT_AGE_THRESHOLD_DAYS = 30;

Deno.serve(async (req: Request) => {
  // ── CORS preflight ─────────────────────────────────────────
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  try {
    // ── Parse request ──────────────────────────────────────────
    const { firebase_id_token, device_id, app_version } = await req.json() as {
      firebase_id_token: string;
      device_id: string;
      app_version?: string;
    };

    if (!firebase_id_token || !device_id) {
      return errorResponse(400, "firebase_id_token and device_id are required.");
    }

    // ── Verify Firebase token cryptographically ────────────────
    const claims = await verifyFirebaseToken(firebase_id_token, FIREBASE_PROJECT_ID);
    const phoneNumber = claims.phone_number; // e.g. "+919876543210"

    // ── Supabase admin client (service role) ───────────────────
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY, {
      auth: { autoRefreshToken: false, persistSession: false },
    });

    // ── Find or create Supabase user ───────────────────────────
    let supabaseUserId: string;
    let isNewUser = false;
    let accountAgeHours = 0;

    // Search for existing user by phone
    const { data: existingUsers, error: listError } =
      await supabase.auth.admin.listUsers();

    // Note: In production with large user bases, use a custom
    // users table lookup instead of listUsers() to avoid pagination issues.
    const existingUser = existingUsers?.users?.find(
      (u) => u.phone === phoneNumber
    );

    if (listError && !existingUser) {
      // Fallback: search in our public.users table
      const { data: publicUser } = await supabase
        .from("users")
        .select("id, created_at")
        .eq("phone", phoneNumber)
        .single();

      if (publicUser) {
        supabaseUserId = publicUser.id;
        accountAgeHours =
          (Date.now() - new Date(publicUser.created_at).getTime()) / 3_600_000;
      } else {
        // Truly new user — create in Supabase Auth
        const { data: newUser, error: createError } =
          await supabase.auth.admin.createUser({
            phone: phoneNumber,
            phone_confirm: true,
            app_metadata: { firebase_uid: claims.uid },
          });

        if (createError || !newUser.user) {
          throw new Error(`Failed to create user: ${createError?.message}`);
        }
        supabaseUserId = newUser.user.id;
        isNewUser = true;
      }
    } else if (existingUser) {
      supabaseUserId = existingUser.id;
      accountAgeHours =
        (Date.now() - new Date(existingUser.created_at).getTime()) / 3_600_000;
    } else {
      // First time: create the Supabase Auth user
      const { data: newUser, error: createError } =
        await supabase.auth.admin.createUser({
          phone: phoneNumber,
          phone_confirm: true,
          app_metadata: { firebase_uid: claims.uid },
        });

      if (createError || !newUser.user) {
        throw new Error(`Failed to create user: ${createError?.message}`);
      }
      supabaseUserId = newUser.user.id;
      isNewUser = true;
    }

    // ── New-device circuit-breaker ─────────────────────────────
    // If the account is >30 days old and this is an unrecognized device,
    // pause the session and require secondary verification (DOB or PIN).
    // This protects against SIM-swap / telecom number recycling attacks.
    if (!isNewUser) {
      const accountAgeDays = accountAgeHours / 24;
      const isEstablishedAccount = accountAgeDays > ACCOUNT_AGE_THRESHOLD_DAYS;

      if (isEstablishedAccount) {
        // Check if device_id is in the user's known devices
        const { data: knownDevice } = await supabase
          .from("user_devices")
          .select("id")
          .eq("user_id", supabaseUserId)
          .eq("device_id", device_id)
          .maybeSingle();

        if (!knownDevice) {
          // Unknown device on an established account — require 2FA verification
          return new Response(
            JSON.stringify({
              status: "secondary_verification_required",
              message:
                "New device detected. Please verify your identity to continue.",
              user_id: supabaseUserId,
              // Flutter shows a DOB or PIN entry screen
            }),
            {
              status: 200,
              headers: { ...corsHeaders, "Content-Type": "application/json" },
            }
          );
        }
      }

      // Known device or young account — register device if not tracked
      await supabase.from("user_devices").upsert({
        user_id: supabaseUserId,
        device_id,
        last_seen_at: new Date().toISOString(),
        app_version: app_version ?? "unknown",
      }, { onConflict: "user_id,device_id" });
    } else {
      // New user: register this as their first device
      await supabase.from("user_devices").upsert({
        user_id: supabaseUserId,
        device_id,
        last_seen_at: new Date().toISOString(),
        app_version: app_version ?? "unknown",
      }, { onConflict: "user_id,device_id" });
    }

    // ── Issue Supabase session via admin link ──────────────────
    // Using generateLink avoids manual JWT signing vulnerabilities.
    // We generate a magiclink token and immediately exchange it for a session.
    const { data: linkData, error: linkError } =
      await supabase.auth.admin.generateLink({
        type: "magiclink",
        email: `${supabaseUserId}@noor.internal`, // Dummy email for phone-based users
      });

    if (linkError || !linkData?.properties?.hashed_token) {
      // Fallback: generate a short-lived sign-in token directly
      // This is acceptable since we've already verified the Firebase token
      const { data: sessionData, error: sessionError } =
        await supabase.auth.admin.createSession({ userId: supabaseUserId });

      if (sessionError || !sessionData?.session) {
        throw new Error(`Failed to create session: ${sessionError?.message}`);
      }

      return new Response(
        JSON.stringify({
          status: "authenticated",
          is_new_user: isNewUser,
          access_token:  sessionData.session.access_token,
          refresh_token: sessionData.session.refresh_token,
          expires_in:    sessionData.session.expires_in,
          user_id:       supabaseUserId,
        }),
        {
          status: 200,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // Exchange hashed_token for an actual session
    const { data: verifyData, error: verifyError } =
      await supabase.auth.verifyOtp({
        token_hash: linkData.properties.hashed_token,
        type: "magiclink",
      });

    if (verifyError || !verifyData.session) {
      throw new Error(`Session exchange failed: ${verifyError?.message}`);
    }

    // ── Return session to Flutter ──────────────────────────────
    return new Response(
      JSON.stringify({
        status: "authenticated",
        is_new_user: isNewUser,
        access_token:  verifyData.session.access_token,
        refresh_token: verifyData.session.refresh_token,
        expires_in:    verifyData.session.expires_in,
        user_id:       supabaseUserId,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  } catch (err) {
    console.error("[firebase-auth-exchange] Error:", err);
    const message = err instanceof Error ? err.message : "Authentication failed.";
    return errorResponse(401, message);
  }
});

function errorResponse(status: number, message: string): Response {
  return new Response(
    JSON.stringify({ status: "error", message }),
    { status, headers: { ...corsHeaders, "Content-Type": "application/json" } }
  );
}
