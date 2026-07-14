import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, handleCors } from "../_shared/cors.ts";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
const likelyMatchThreshold = 0.65;
const manualReviewThreshold = 0.50;

Deno.serve(async (request) => {
  const corsResponse = handleCors(request);
  if (corsResponse) return corsResponse;

  try {
    const authHeader = request.headers.get("Authorization");
    if (!authHeader?.startsWith("Bearer ")) {
      return error(401, "Authentication required.");
    }

    const token = authHeader.slice("Bearer ".length);
    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
      auth: { autoRefreshToken: false, persistSession: false },
    });
    const { data: { user }, error: authError } = await userClient.auth.getUser(
      token,
    );
    if (authError || !user) return error(401, "Authentication required.");

    const body = await request.json();
    const userId = String(body.user_id ?? "");
    const similarity = Number(body.face_similarity);
    const dob = parseIsoDate(String(body.ocr_dob ?? ""));
    const idType = String(body.id_type ?? "").trim();
    const countryCode = String(body.country_code ?? "").toUpperCase();
    const selfiePath = String(body.selfie_storage_path ?? "");
    const idPath = String(body.id_photo_storage_path ?? "");

    if (userId !== user.id) {
      return error(403, "You may only verify your own profile.");
    }
    if (!dob || ageOn(dob) < 18) {
      return error(422, "You must be at least 18 years old.");
    }
    if (!Number.isFinite(similarity) || similarity < 0 || similarity > 1) {
      return error(400, "Invalid face similarity score.");
    }
    if (!idType || !/^[A-Z]{2}$/.test(countryCode)) {
      return error(400, "Invalid document details.");
    }
    if (
      !ownsKycPath(selfiePath, user.id, "kyc_selfie") ||
      !ownsKycPath(idPath, user.id, "kyc_id")
    ) {
      return error(403, "Invalid private document path.");
    }

    const admin = createClient(supabaseUrl, serviceRoleKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    });
    const common = {
      kyc_method: "on_device",
      face_similarity: similarity,
      kyc_id_type: idType,
      kyc_country_code: countryCode,
      kyc_selfie_storage_path: selfiePath,
      kyc_id_photo_storage_path: idPath,
    };

    if (similarity >= likelyMatchThreshold) {
      const { error: updateError } = await admin.from("profiles").update({
        ...common,
        kyc_verified: true,
        verified_at: new Date().toISOString(),
        verification_status: "verified",
        is_verified: true,
      }).eq("user_id", user.id);
      if (updateError) throw updateError;
      await queueIdentityNotification(
        admin,
        user.id,
        "kyc_approved",
        "Identity verified",
        "Your government ID and selfie check is complete. Your identity status is now verified.",
      );
      return json({
        status: "verified",
        message: "Your identity has been verified.",
      });
    }

    if (similarity >= manualReviewThreshold) {
      const { error: updateError } = await admin.from("profiles").update({
        ...common,
        kyc_verified: false,
        verification_status: "pending_review",
      }).eq("user_id", user.id);
      if (updateError) throw updateError;
      await queueIdentityNotification(
        admin,
        user.id,
        "kyc_pending",
        "Identity check submitted",
        "Your documents were received securely and are awaiting review.",
      );
      return json({
        status: "pending_review",
        message: "Your verification is pending review.",
      });
    }

    const { error: rejectionUpdateError } = await admin.from("profiles").update({
      ...common,
      kyc_verified: false,
      verification_status: "unverified",
    }).eq("user_id", user.id);
    if (rejectionUpdateError) throw rejectionUpdateError;
    await queueIdentityNotification(
      admin,
      user.id,
      "kyc_rejected",
      "Identity check needs attention",
      "The selfie did not match the document photo. Retake both images in clear lighting and try again.",
    );
    return error(422, "The selfie does not match the document photo.");
  } catch (cause) {
    console.error("[process-kyc]", cause);
    return error(500, "Unable to process verification.");
  }
});

async function queueIdentityNotification(
  admin: ReturnType<typeof createClient>,
  userId: string,
  type: string,
  title: string,
  body: string,
): Promise<void> {
  const { error: notificationError } = await admin.from("notifications").insert({
    user_id: userId,
    type,
    title,
    body,
    deep_link: type === "kyc_rejected" ? "silarah://verify-identity" : "silarah://profile",
  });
  if (notificationError) {
    console.error("[process-kyc] Unable to queue identity notification", {
      userId,
      type,
      message: notificationError.message,
    });
  }
}

function parseIsoDate(value: string): Date | null {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) return null;
  const date = new Date(`${value}T00:00:00.000Z`);
  return Number.isNaN(date.getTime()) ? null : date;
}

function ageOn(dob: Date): number {
  const today = new Date();
  let age = today.getUTCFullYear() - dob.getUTCFullYear();
  const beforeBirthday = today.getUTCMonth() < dob.getUTCMonth() ||
    (today.getUTCMonth() === dob.getUTCMonth() &&
      today.getUTCDate() < dob.getUTCDate());
  if (beforeBirthday) age--;
  return age;
}

function ownsKycPath(path: string, userId: string, prefix: string): boolean {
  return new RegExp(
    `^${escapeRegExp(userId)}/${prefix}_[0-9a-f-]+\\.(jpg|jpeg|png|webp)$`,
    "i",
  ).test(path);
}

function escapeRegExp(value: string): string {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

function json(payload: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function error(status: number, message: string): Response {
  return json({ status: "rejected", message }, status);
}
