import { createClient } from "@supabase/supabase-js";
import { isAuthorizedCronRequest } from "../_shared/cron_auth.ts";

type DeletionJob = {
  job_id: string;
  bucket_id: string;
  storage_path: string;
  lease_token: string;
};

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return response(405, { error: "method_not_allowed" });
  }
  if (!(await isAuthorizedCronRequest(req))) {
    return response(401, { error: "unauthorized" });
  }
  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { autoRefreshToken: false, persistSession: false } },
  );
  const { data: runId, error: runError } = await admin.rpc(
    "begin_worker_run",
    { p_job_name: "storage_lifecycle_worker" },
  );
  if (runError) return response(503, { error: "worker_unavailable" });
  if (!runId) return response(202, { skipped: true });

  let completed = 0;
  let failed = 0;
  try {
    const { error: expiryError } = await admin.rpc(
      "expire_upload_reservations",
      { p_limit: 100 },
    );
    if (expiryError) throw new Error("reservation_expiry_failed");
    const { data, error } = await admin.rpc("checkout_storage_deletions", {
      p_limit: 25,
    });
    if (error) throw new Error("checkout_failed");
    for (const job of (data ?? []) as DeletionJob[]) {
      const { error: removeError } = await admin.storage
        .from(job.bucket_id)
        .remove([job.storage_path]);
      const success = !removeError;
      const { error: finishError } = await admin.rpc(
        "finish_storage_deletion",
        {
          p_job_id: job.job_id,
          p_lease_token: job.lease_token,
          p_success: success,
          p_error_code: success ? null : "storage_remove_failed",
        },
      );
      if (finishError || !success) failed += 1;
      else completed += 1;
    }
    await admin.rpc("finish_worker_run", {
      p_run_id: runId,
      p_status: failed > 0 ? "failed" : "completed",
      p_rows_affected: completed,
      p_error_code: failed > 0 ? "partial_failure" : null,
    });
    return response(200, { processed: completed + failed, completed, failed });
  } catch (error) {
    console.error("[storage-lifecycle-worker]", {
      runId,
      error: String(error),
    });
    await admin.rpc("finish_worker_run", {
      p_run_id: runId,
      p_status: "failed",
      p_rows_affected: completed,
      p_error_code: "worker_failure",
    });
    return response(503, { error: "worker_failed", correlation_id: runId });
  }
});

function response(status: number, body: unknown) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json",
      "Cache-Control": "no-store",
    },
  });
}
