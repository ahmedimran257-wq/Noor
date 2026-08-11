import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { corsHeaders, handleCors } from "../_shared/cors.ts";
import {
  consumeDistributedRateLimit,
  rateLimitHeaders,
} from "../_shared/distributed_rate_limit.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const BUCKET = "photo-verification-captures";
const MAX_CAPTURE_BYTES = 2 * 1024 * 1024;
const URL_TTL_SECONDS = 300;

type Action = "start" | "submit";
// The service-role client intentionally has no generated schema binding in
// Edge Functions; authorization is enforced by the private RPC boundary.
// deno-lint-ignore no-explicit-any
type AdminClient = SupabaseClient<any, "public", "public", any, any>;

Deno.serve(async (request: Request) => {
  const corsResponse = handleCors(request);
  if (corsResponse) return corsResponse;
  if (request.method !== "POST") {
    return response(405, { error: "Method not allowed." });
  }

  const correlationId = crypto.randomUUID();
  try {
    const bearer = request.headers.get("Authorization");
    if (!bearer?.startsWith("Bearer ")) {
      return response(401, { error: "Authentication is required." });
    }

    const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
      auth: { autoRefreshToken: false, persistSession: false },
    });
    const { data: authData, error: authError } = await admin.auth.getUser(
      bearer.slice("Bearer ".length),
    );
    const userId = authData.user?.id;
    if (authError || !userId || !isUuid(userId)) {
      return response(401, { error: "Authentication is required." });
    }

    const { data: account, error: accountError } = await admin.from("users")
      .select("is_banned, deleted_at")
      .eq("id", userId)
      .maybeSingle();
    if (
      accountError || !account || account.is_banned === true ||
      account.deleted_at != null
    ) {
      return response(403, {
        error: "This account cannot submit verification.",
      });
    }

    const body = await request.json() as {
      action?: Action;
      submission_id?: string;
      guidance_mode?: "smile_blink_v1" | "manual_accessibility_v1";
    };
    const action = body.action;
    if (action !== "start" && action !== "submit") {
      return response(400, { error: "Unsupported verification action." });
    }

    const limit = await consumeDistributedRateLimit(admin, {
      scope: `photo_verification_${action}`,
      subject: userId,
      maxRequests: action === "start" ? 5 : 10,
      windowSeconds: 60 * 60,
    });
    if (!limit.allowed) {
      return new Response(
        JSON.stringify({
          error: "Please wait before trying verification again.",
        }),
        {
          status: 429,
          headers: {
            ...corsHeaders,
            ...rateLimitHeaders(limit),
            "Content-Type": "application/json",
          },
        },
      );
    }

    if (action === "start") {
      return await startSubmission(
        admin,
        userId,
        body.guidance_mode ?? "smile_blink_v1",
      );
    }
    return await submitForReview(admin, userId, body.submission_id);
  } catch (error) {
    console.error(`[photo-verification] ${correlationId}`, error);
    return response(500, {
      error: "Photo verification is temporarily unavailable.",
      correlation_id: correlationId,
    });
  }
});

async function startSubmission(
  admin: AdminClient,
  userId: string,
  guidanceMode: "smile_blink_v1" | "manual_accessibility_v1",
): Promise<Response> {
  const paths = {
    neutral: `${userId}/${crypto.randomUUID()}.jpg`,
    smile: `${userId}/${crypto.randomUUID()}.jpg`,
    blink: `${userId}/${crypto.randomUUID()}.jpg`,
  };
  const { data: rows, error } = await admin.rpc(
    "start_photo_verification_submission",
    {
      p_user_id: userId,
      p_neutral_path: paths.neutral,
      p_smile_path: paths.smile,
      p_blink_path: paths.blink,
      p_guidance_mode: guidanceMode,
    },
  );
  const submission = Array.isArray(rows) ? rows[0] : rows;
  if (error || !submission?.submission_id) {
    if (String(error?.message ?? "").includes("already_in_progress")) {
      return response(409, {
        error: "A photo verification is already in progress.",
      });
    }
    if (String(error?.message ?? "").includes("already_approved")) {
      return response(409, {
        error: "Your current profile photo is already verified.",
      });
    }
    if (String(error?.message ?? "").includes("primary_photo")) {
      return response(409, {
        error: "Add an approved primary profile photo first.",
      });
    }
    throw new Error(`submission_start_failed:${error?.message ?? "empty"}`);
  }

  const uploads: Record<string, { path: string; token: string }> = {};
  for (const [kind, path] of Object.entries(paths)) {
    const { data, error: signedError } = await admin.storage.from(BUCKET)
      .createSignedUploadUrl(path);
    if (signedError || !data?.token) {
      throw new Error(`capture_upload_url_failed:${kind}`);
    }
    uploads[kind] = { path, token: data.token };
  }

  return response(200, {
    submission_id: submission.submission_id,
    review_deadline: submission.review_deadline,
    uploads,
    expires_in: URL_TTL_SECONDS,
  });
}

async function submitForReview(
  admin: AdminClient,
  userId: string,
  submissionId: string | undefined,
): Promise<Response> {
  if (!submissionId || !isUuid(submissionId)) {
    return response(400, { error: "A valid submission is required." });
  }
  const { data: submission, error } = await admin
    .from("photo_verification_submissions")
    .select(
      "status, review_deadline, neutral_storage_path, smile_storage_path, blink_storage_path",
    )
    .eq("id", submissionId)
    .eq("user_id", userId)
    .maybeSingle();
  if (error || !submission || submission.status !== "uploading") {
    return response(409, { error: "This verification cannot be submitted." });
  }

  const paths = [
    submission.neutral_storage_path,
    submission.smile_storage_path,
    submission.blink_storage_path,
  ].filter((path): path is string =>
    typeof path === "string" && path.length > 0
  );
  if (
    paths.length !== 3 || paths.some((path) => !path.startsWith(`${userId}/`))
  ) {
    throw new Error("capture_path_contract_failed");
  }

  // Downloading is deliberate here: it verifies the exact private objects,
  // MIME signature and bounded size before a submission enters the staff
  // queue. Captures are compressed on-device and never leave this boundary.
  for (const path of paths) {
    const { data, error: downloadError } = await admin.storage.from(BUCKET)
      .download(path);
    if (downloadError || !data) {
      return response(409, {
        error: "All three guided captures must finish uploading.",
      });
    }
    if (data.size < 10_000 || data.size > MAX_CAPTURE_BYTES) {
      return response(400, {
        error: "A verification capture has an invalid size.",
      });
    }
    if (data.type !== "image/jpeg") {
      return response(400, {
        error: "Verification captures must be JPEG images.",
      });
    }
    const header = new Uint8Array(await data.slice(0, 3).arrayBuffer());
    const footer = new Uint8Array(await data.slice(-2).arrayBuffer());
    const isJpeg = header.length === 3 && header[0] === 0xff &&
      header[1] === 0xd8 && header[2] === 0xff &&
      footer.length === 2 && footer[0] === 0xff && footer[1] === 0xd9;
    if (!isJpeg) {
      return response(400, {
        error: "Verification captures must be JPEG images.",
      });
    }
  }

  const { data: deadline, error: submitError } = await admin.rpc(
    "submit_photo_verification_for_review",
    { p_user_id: userId, p_submission_id: submissionId },
  );
  if (submitError) {
    return response(409, {
      error: "This verification can no longer be submitted.",
    });
  }
  return response(200, {
    status: "pending",
    review_deadline: deadline,
    retention: "deleted_after_review_or_within_48_hours",
  });
}

function response(status: number, body: Record<string, unknown>): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function isUuid(value: string): boolean {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
    .test(value);
}
