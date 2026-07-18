import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { isAuthorizedCronRequest } from "../_shared/cron_auth.ts";

const corsHeaders = {
  "Content-Type": "application/json",
  "Cache-Control": "no-store",
};

type Submission = {
  id: string;
  user_id: string;
  profile_id: string;
  status: string;
  selfie_storage_path: string | null;
  id_photo_storage_path: string | null;
};

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return response({ error: "Method not allowed" }, 405);
  }
  if (!(await isAuthorizedCronRequest(req))) {
    return response({ error: "Unauthorized" }, 401);
  }

  const admin = createAdminClient();
  const { data, error } = await admin
    .from("kyc_review_submissions")
    .select(
      "id,user_id,profile_id,status,selfie_storage_path,id_photo_storage_path",
    )
    .is("documents_purged_at", null)
    .lte("purge_after", new Date().toISOString())
    .order("purge_after", { ascending: true })
    .limit(50);
  if (error) return response({ error: "Unable to load retention queue" }, 500);

  let purged = 0;
  let failed = 0;
  for (const submission of (data ?? []) as Submission[]) {
    try {
      const paths = [
        submission.selfie_storage_path,
        submission.id_photo_storage_path,
      ]
        .filter((path): path is string => Boolean(path));
      const [selfieHash, idHash] = await Promise.all([
        digestObject(admin, submission.selfie_storage_path),
        digestObject(admin, submission.id_photo_storage_path),
      ]);
      if (paths.length > 0) {
        const { error: removeError } = await admin.storage.from("kyc-documents")
          .remove(paths);
        if (removeError) throw removeError;
      }

      const expired = submission.status === "pending";
      const { error: updateError } = await admin.from("kyc_review_submissions")
        .update({
          status: expired ? "expired" : submission.status,
          review_reason: expired
            ? "The private evidence reached its retention limit before review."
            : undefined,
          selfie_sha256: selfieHash,
          id_photo_sha256: idHash,
          selfie_storage_path: null,
          id_photo_storage_path: null,
          documents_purged_at: new Date().toISOString(),
        }).eq("id", submission.id);
      if (updateError) throw updateError;

      const { data: profile } = await admin.from("profiles")
        .select("kyc_manual_review_id,has_verification_badge")
        .eq("id", submission.profile_id)
        .maybeSingle();
      if (profile?.kyc_manual_review_id === submission.id) {
        const profileUpdate = expired
          ? {
            kyc_verified: false,
            kyc_assurance_level: "none",
            verification_status: profile.has_verification_badge
              ? "verified"
              : "unverified",
            is_verified: Boolean(profile.has_verification_badge),
            kyc_selfie_storage_path: null,
            kyc_id_photo_storage_path: null,
          }
          : {
            // Purging raw images must never revoke a completed decision.
            kyc_selfie_storage_path: null,
            kyc_id_photo_storage_path: null,
          };
        await admin.from("profiles").update(profileUpdate).eq(
          "id",
          submission.profile_id,
        );
      }
      if (expired) {
        await admin.from("notifications").insert({
          user_id: submission.user_id,
          type: "kyc_rejected",
          title: "Submit your ID check again",
          body:
            "Your private identity images expired before review and were deleted. Please submit a new selfie and document.",
          deep_link: "silarah://verify-identity",
        });
      }
      purged += 1;
    } catch (error) {
      failed += 1;
      console.error("KYC retention item failed", {
        submissionId: submission.id,
        error: String(error),
      });
    }
  }
  return response({ processed: (data ?? []).length, purged, failed });
});

async function digestObject(
  admin: ReturnType<typeof createAdminClient>,
  path: string | null,
) {
  if (!path) return null;
  const { data, error } = await admin.storage.from("kyc-documents").download(
    path,
  );
  if (error || !data) return null;
  const digest = await crypto.subtle.digest(
    "SHA-256",
    await data.arrayBuffer(),
  );
  return Array.from(new Uint8Array(digest)).map((byte) =>
    byte.toString(16).padStart(2, "0")
  ).join("");
}

function response(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: corsHeaders });
}

function createAdminClient() {
  return createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { autoRefreshToken: false, persistSession: false } },
  );
}
