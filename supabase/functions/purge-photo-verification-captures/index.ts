import { createClient } from "@supabase/supabase-js";
import { isAuthorizedCronRequest } from "../_shared/cron_auth.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const BUCKET = "photo-verification-captures";

Deno.serve(async (request: Request) => {
  if (request.method !== "POST") {
    return json(405, { error: "Method not allowed" });
  }
  if (!(await isAuthorizedCronRequest(request))) {
    return json(401, { error: "Unauthorized" });
  }
  const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const { data: rows, error } = await admin.rpc(
    "checkout_photo_verification_purges",
    { p_limit: 25 },
  );
  if (error) {
    console.error("[photo-verification-purge] checkout", error);
    return json(500, { error: "checkout_failed" });
  }

  let completed = 0;
  let failed = 0;
  for (const row of rows ?? []) {
    const paths = [row.neutral_path, row.smile_path, row.blink_path]
      .filter((path): path is string =>
        typeof path === "string" && path.length > 0
      );
    let success = true;
    let failure: string | null = null;
    if (paths.length > 0) {
      const { error: removeError } = await admin.storage.from(BUCKET).remove(
        paths,
      );
      if (removeError) {
        success = false;
        failure = removeError.message;
      }
    }
    const { error: finishError } = await admin.rpc(
      "finish_photo_verification_purge",
      {
        p_submission_id: row.submission_id,
        p_success: success,
        p_error: failure,
      },
    );
    if (finishError || !success) failed += 1;
    else completed += 1;
  }
  return json(200, { checked: (rows ?? []).length, completed, failed });
});

function json(status: number, body: Record<string, unknown>): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
