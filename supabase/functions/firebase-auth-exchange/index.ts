import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { verifyFirebaseToken } from "../_shared/firebase_verifier.ts";
import { corsHeaders, handleCors } from "../_shared/cors.ts";

// DEPRECATED: signup/signin no longer uses Firebase phone SMS.
// The app now uses Supabase auth.verifyOTP(type: email) directly.
// Keep this only for legacy/admin recovery paths until safely removed.

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const FIREBASE_PROJECT_ID = Deno.env.get("FIREBASE_PROJECT_ID")!;
const ACCOUNT_AGE_THRESHOLD_DAYS = 30;
const DIAL_COUNTRY_CODES: Array<[string, string]> = [
  ["+91", "IN"],
  ["+92", "PK"],
  ["+880", "BD"],
  ["+62", "ID"],
  ["+966", "SA"],
  ["+971", "AE"],
  ["+60", "MY"],
  ["+90", "TR"],
  ["+20", "EG"],
  ["+234", "NG"],
  ["+44", "GB"],
  ["+1", "US"],
  ["+49", "DE"],
  ["+33", "FR"],
];

type AuthMode = "signup" | "signin";
type SupabaseAdminClient = ReturnType<typeof createClient>;

Deno.serve(async (req: Request) => {
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  try {
    const {
      firebase_id_token,
      device_id,
      mode,
      country_code,
      app_version,
    } = await req.json() as {
      firebase_id_token?: string;
      device_id?: string;
      mode?: AuthMode;
      country_code?: string;
      app_version?: string;
    };

    if (!firebase_id_token || !device_id) {
      return errorResponse(
        400,
        "firebase_id_token and device_id are required.",
        "BAD_REQUEST",
      );
    }

    const authMode: AuthMode = mode === "signup" ? "signup" : "signin";
    const claims = await verifyFirebaseToken(
      firebase_id_token,
      FIREBASE_PROJECT_ID,
    );
    const phoneNumber = claims.phone_number;

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY, {
      auth: { autoRefreshToken: false, persistSession: false },
    });

    const existingUser = await findExistingUser(supabase, phoneNumber);
    let supabaseUserId: string;
    let isNewUser = false;
    let accountAgeHours = 0;

    if (existingUser) {
      if (authMode === "signup") {
        return errorResponse(
          409,
          "Phone number already registered. Please sign in instead.",
          "PHONE_ALREADY_REGISTERED",
        );
      }

      supabaseUserId = existingUser.id;
      accountAgeHours =
        (Date.now() - new Date(existingUser.created_at).getTime()) / 3_600_000;
    } else {
      if (authMode === "signin") {
        return errorResponse(
          404,
          "No account found with this phone number.",
          "PHONE_NOT_REGISTERED",
        );
      }

      const { data: newUser, error: createError } = await supabase.auth.admin
        .createUser({
          phone: phoneNumber,
          phone_confirm: true,
          app_metadata: { firebase_uid: claims.uid },
        });

      if (createError || !newUser.user) {
        if (
          createError?.message?.toLowerCase().includes(
            "phone number already registered",
          )
        ) {
          return errorResponse(
            409,
            "Phone number already registered. Please sign in instead.",
            "PHONE_ALREADY_REGISTERED",
          );
        }

        throw new Error(`Failed to create user: ${createError?.message}`);
      }

      supabaseUserId = newUser.user.id;
      isNewUser = true;
    }

    await ensurePublicUser(supabase, supabaseUserId, phoneNumber, country_code);

    if (!isNewUser) {
      const accountAgeDays = accountAgeHours / 24;
      const isEstablishedAccount = accountAgeDays > ACCOUNT_AGE_THRESHOLD_DAYS;

      if (isEstablishedAccount) {
        const { data: knownDevice } = await supabase
          .from("user_devices")
          .select("id")
          .eq("user_id", supabaseUserId)
          .eq("device_id", device_id)
          .maybeSingle();

        if (!knownDevice) {
          return new Response(
            JSON.stringify({
              status: "secondary_verification_required",
              message:
                "New device detected. Please verify your identity to continue.",
              user_id: supabaseUserId,
            }),
            {
              status: 200,
              headers: { ...corsHeaders, "Content-Type": "application/json" },
            },
          );
        }
      }
    }

    await supabase.from("user_devices").upsert({
      user_id: supabaseUserId,
      device_id,
      last_seen_at: new Date().toISOString(),
      app_version: app_version ?? "unknown",
    }, { onConflict: "user_id,device_id" });

    const dummyEmail = `${supabaseUserId}@silarah.internal`;
    const { error: updateError } = await supabase.auth.admin.updateUserById(
      supabaseUserId,
      {
        email: dummyEmail,
        email_confirm: true,
      },
    );

    if (updateError) {
      throw new Error(`Failed to prepare session user: ${updateError.message}`);
    }

    const { data: linkData, error: linkError } = await supabase.auth.admin
      .generateLink({
        type: "magiclink",
        email: dummyEmail,
      });

    if (linkError || !linkData?.properties?.hashed_token) {
      throw new Error(`Failed to generate admin link: ${linkError?.message}`);
    }

    const { data: sessionData, error: sessionError } = await supabase.auth
      .verifyOtp({
        token_hash: linkData.properties.hashed_token,
        type: "email",
      });

    if (sessionError || !sessionData?.session) {
      throw new Error(
        `Failed to exchange link for session: ${sessionError?.message}`,
      );
    }

    return new Response(
      JSON.stringify({
        status: "authenticated",
        is_new_user: isNewUser,
        access_token: sessionData.session.access_token,
        refresh_token: sessionData.session.refresh_token,
        expires_in: sessionData.session.expires_in,
        user_id: supabaseUserId,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  } catch (err) {
    console.error("[firebase-auth-exchange] Error:", err);
    const message = err instanceof Error
      ? err.message
      : "Authentication failed.";

    if (message.includes("Phone number already registered")) {
      return errorResponse(
        409,
        "Phone number already registered. Please sign in instead.",
        "PHONE_ALREADY_REGISTERED",
      );
    }

    return errorResponse(401, message, "AUTH_EXCHANGE_FAILED");
  }
});

function errorResponse(
  status: number,
  message: string,
  code = "AUTH_ERROR",
): Response {
  return new Response(
    JSON.stringify({ status: "error", code, message }),
    { status, headers: { ...corsHeaders, "Content-Type": "application/json" } },
  );
}

function normalizePhone(phone: string) {
  return phone.replace(/\D/g, "");
}

function countryCodeForPhone(phone: string, countryCode?: string) {
  const provided = countryCode?.trim().toUpperCase();
  if (provided && /^[A-Z]{2}$/.test(provided)) return provided;

  return DIAL_COUNTRY_CODES.find(([dial]) => phone.startsWith(dial))?.[1] ??
    "IN";
}

async function findExistingUser(supabase: SupabaseAdminClient, phone: string) {
  const normalized = normalizePhone(phone);
  const variants = [...new Set([phone, normalized, `+${normalized}`])];

  const { data: publicUser } = await supabase
    .from("users")
    .select("id, created_at, phone")
    .in("phone", variants)
    .maybeSingle();

  if (publicUser) {
    return { id: publicUser.id, created_at: publicUser.created_at };
  }

  let page = 1;
  while (true) {
    const { data: usersData, error } = await supabase.auth.admin.listUsers({
      page,
      perPage: 1000,
    });

    if (error || !usersData?.users || usersData.users.length === 0) break;

    const found = usersData.users.find((user) => {
      if (!user.phone) return false;
      const userPhone = normalizePhone(user.phone);
      return userPhone === normalized || variants.includes(user.phone);
    });

    if (found) {
      return { id: found.id, created_at: found.created_at };
    }

    if (usersData.users.length < 1000) break;
    page++;
  }

  return null;
}

async function ensurePublicUser(
  supabase: SupabaseAdminClient,
  userId: string,
  phone: string,
  countryCode?: string,
) {
  const normalized = normalizePhone(phone);
  const variants = [...new Set([phone, normalized, `+${normalized}`])];

  const { data: existingById } = await supabase
    .from("users")
    .select("id")
    .eq("id", userId)
    .maybeSingle();

  if (existingById) return;

  const { data: existingByPhone } = await supabase
    .from("users")
    .select("id")
    .in("phone", variants)
    .maybeSingle();

  if (existingByPhone && existingByPhone.id !== userId) {
    throw new Error("Phone number already registered by another user");
  }

  const { error } = await supabase.from("users").insert({
    id: userId,
    phone,
    country_code: countryCodeForPhone(phone, countryCode),
  });

  if (error) {
    throw new Error(`Failed to create public user row: ${error.message}`);
  }
}
