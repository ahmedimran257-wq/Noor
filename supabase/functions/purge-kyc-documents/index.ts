import { createClient } from "@supabase/supabase-js";
import { isAuthorizedCronRequest } from "../_shared/cron_auth.ts";

const responseHeaders = {
  "Content-Type": "application/json",
  "Cache-Control": "no-store",
};

type PurgeClaim = {
  id: string;
  selfie_storage_path: string | null;
  id_photo_storage_path: string | null;
  selfie_purge_status: string;
  id_photo_purge_status: string;
};

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return response({ error: "Method not allowed" }, 405);
  }
  if (!(await isAuthorizedCronRequest(req))) {
    return response({ error: "Unauthorized" }, 401);
  }

  const admin = createAdminClient();
  const { data, error } = await admin.rpc(
    "checkout_kyc_document_purges",
    { p_limit: 5 },
  );
  if (error) {
    console.error("[purge-kyc-documents] claim failed", error.message);
    return response({ error: "Unable to claim retention work" }, 500);
  }

  let purged = 0;
  let failed = 0;
  for (const claim of (data ?? []) as PurgeClaim[]) {
    try {
      const selfieDeleted = claim.selfie_purge_status === "deleted" ||
        await deleteObject(
          admin,
          claim.id,
          "selfie",
          claim.selfie_storage_path,
        );
      const idDeleted = claim.id_photo_purge_status === "deleted" ||
        await deleteObject(
          admin,
          claim.id,
          "id_photo",
          claim.id_photo_storage_path,
        );
      if (!selfieDeleted || !idDeleted) {
        failed += 1;
        continue;
      }

      const { data: completed, error: finishError } = await admin.rpc(
        "finish_kyc_document_purge",
        { p_submission_id: claim.id },
      );
      if (finishError || completed !== true) {
        throw new Error(finishError?.message ?? "purge_not_finalized");
      }
      purged += 1;
    } catch (error) {
      failed += 1;
      console.error("[purge-kyc-documents] item failed", {
        submissionId: claim.id,
        error: safeError(error),
      });
    }
  }

  return response({
    processed: (data ?? []).length,
    purged,
    failed,
  });
});

async function deleteObject(
  admin: ReturnType<typeof createAdminClient>,
  submissionId: string,
  kind: "selfie" | "id_photo",
  path: string | null,
): Promise<boolean> {
  let success = true;
  let failure: string | null = null;
  if (path) {
    const { error } = await admin.storage.from("kyc-documents").remove([path]);
    if (error) {
      success = false;
      failure = error.message;
    }
  }

  const { error: recordError } = await admin.rpc(
    "record_kyc_purge_object_result",
    {
      p_submission_id: submissionId,
      p_object_kind: kind,
      p_success: success,
      p_error: failure,
    },
  );
  if (recordError) {
    throw new Error(`purge_object_state_failed:${recordError.message}`);
  }
  return success;
}

function response(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: responseHeaders,
  });
}

function safeError(error: unknown): string {
  return error instanceof Error
    ? error.message.slice(0, 300)
    : "unknown_retention_error";
}

function createAdminClient() {
  return createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { autoRefreshToken: false, persistSession: false } },
  );
}
