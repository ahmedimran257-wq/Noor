import { createClient } from "@supabase/supabase-js";
import { isAuthorizedCronRequest } from "../_shared/cron_auth.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const BUCKETS = ["profile-photos", "kyc-documents", "selfie-verifications"];
const CONCURRENCY = 3;

function createAdminClient() {
  return createClient(SUPABASE_URL, SERVICE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
}
type AdminClient = ReturnType<typeof createAdminClient>;

type PurgeJob = {
  user_id: string;
  phase: "storage" | "auth" | "database";
  lease_token: string;
};

Deno.serve(async (req) => {
  if (req.method !== "POST") return json(405, { error: "method_not_allowed" });
  if (!(await isAuthorizedCronRequest(req))) {
    return json(401, { error: "unauthorized" });
  }
  const admin = createAdminClient();
  const { data, error } = await admin.rpc("checkout_account_purge_jobs", {
    p_limit: 10,
  });
  if (error) return json(503, { error: "purge_queue_unavailable" });
  const jobs = (data ?? []) as PurgeJob[];
  const outcomes = await mapWithConcurrency(
    jobs,
    CONCURRENCY,
    (job) => processJob(admin, job),
  );
  return json(200, {
    processed: jobs.length,
    advanced: outcomes.filter(Boolean).length,
    failed: outcomes.filter((value) => !value).length,
  });
});

async function processJob(
  admin: AdminClient,
  job: PurgeJob,
): Promise<boolean> {
  try {
    if (job.phase === "storage") {
      for (const bucket of BUCKETS) {
        await purgeBucketPrefix(admin, bucket, job.user_id);
      }
      await finish(admin, job, true, "auth");
      return true;
    }
    if (job.phase === "auth") {
      const { error } = await admin.auth.admin.deleteUser(job.user_id);
      if (error && !error.message.toLowerCase().includes("not found")) {
        throw new Error("auth_delete_failed");
      }
      await finish(admin, job, true, "database");
      return true;
    }
    for (const bucket of BUCKETS) {
      await assertBucketPrefixEmpty(admin, bucket, job.user_id);
    }
    const { error: deleteError } = await admin.from("users")
      .delete().eq("id", job.user_id);
    if (deleteError) throw new Error("database_delete_failed");
    await finish(admin, job, true, "completed");
    return true;
  } catch (error) {
    console.error("[admin-purge]", {
      userId: job.user_id,
      phase: job.phase,
      error: error instanceof Error ? error.message : "unknown",
    });
    await finish(
      admin,
      job,
      false,
      null,
      error instanceof Error ? error.message : "purge_phase_failed",
    ).catch(() => undefined);
    return false;
  }
}

async function purgeBucketPrefix(
  admin: AdminClient,
  bucket: string,
  userId: string,
): Promise<void> {
  for (let page = 0; page < 100; page++) {
    const { data, error } = await admin.storage.from(bucket).list(userId, {
      limit: 100,
      offset: 0,
      sortBy: { column: "name", order: "asc" },
    });
    if (error) throw new Error(`storage_list_${bucket}`);
    if (!data || data.length === 0) return;
    const paths = data.map((item) => `${userId}/${item.name}`);
    const { error: removeError } = await admin.storage.from(bucket).remove(
      paths,
    );
    if (removeError) throw new Error(`storage_remove_${bucket}`);
  }
  throw new Error(`storage_pagination_limit_${bucket}`);
}

async function assertBucketPrefixEmpty(
  admin: AdminClient,
  bucket: string,
  userId: string,
): Promise<void> {
  const { data, error } = await admin.storage.from(bucket).list(userId, {
    limit: 1,
  });
  if (error || (data?.length ?? 0) > 0) {
    throw new Error(`storage_not_empty_${bucket}`);
  }
}

async function finish(
  admin: AdminClient,
  job: PurgeJob,
  success: boolean,
  nextPhase: string | null,
  errorCode: string | null = null,
) {
  const { error } = await admin.rpc("finish_account_purge_phase", {
    p_user_id: job.user_id,
    p_lease_token: job.lease_token,
    p_success: success,
    p_next_phase: nextPhase,
    p_error_code: errorCode,
  });
  if (error) throw new Error("purge_checkpoint_failed");
}

async function mapWithConcurrency<T, R>(
  items: T[],
  concurrency: number,
  task: (item: T) => Promise<R>,
): Promise<R[]> {
  const results = new Array<R>(items.length);
  let cursor = 0;
  const workers = Array.from(
    { length: Math.min(concurrency, items.length) },
    async () => {
      while (true) {
        const index = cursor++;
        if (index >= items.length) return;
        results[index] = await task(items[index]);
      }
    },
  );
  await Promise.all(workers);
  return results;
}

function json(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json",
      "Cache-Control": "no-store",
    },
  });
}
