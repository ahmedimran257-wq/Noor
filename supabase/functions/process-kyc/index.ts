import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { Image } from "https://deno.land/x/imagescript@1.2.15/mod.ts";
import { corsHeaders, handleCors } from "../_shared/cors.ts";
import {
  consumeDistributedRateLimit,
  rateLimitHeaders,
} from "../_shared/distributed_rate_limit.ts";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
const bucket = "kyc-documents";
const maxFileBytes = 8 * 1024 * 1024;
const maxUploadAgeMs = 15 * 60 * 1000;
const supportedIdTypes = new Set([
  "government_id",
  "national_id",
  "passport",
  "driving_license",
]);

Deno.serve(async (request) => {
  const corsResponse = handleCors(request);
  if (corsResponse) return corsResponse;
  if (request.method !== "POST") return json(405, "Method not allowed.");

  const admin = createAdminClient();
  let uploadedPaths: string[] = [];
  let submissionPersisted = false;

  try {
    const authHeader = request.headers.get("Authorization");
    if (!authHeader?.startsWith("Bearer ")) {
      return json(401, "Authentication required.");
    }
    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
      auth: { autoRefreshToken: false, persistSession: false },
    });
    const { data: { user }, error: authError } = await userClient.auth
      .getUser();
    if (authError || !user) return json(401, "Authentication required.");

    const rateLimit = await consumeDistributedRateLimit(admin, {
      scope: "manual_kyc_submission",
      subject: user.id,
      maxRequests: 5,
      windowSeconds: 24 * 60 * 60,
    });
    if (!rateLimit.allowed) {
      return new Response(
        JSON.stringify({
          status: "rejected",
          message:
            "Identity verification attempt limit reached. Please try again later.",
        }),
        {
          status: 429,
          headers: { ...noStoreHeaders(), ...rateLimitHeaders(rateLimit) },
        },
      );
    }

    const body = await request.json();
    const requestedUserId = stringValue(body?.user_id);
    const idType = stringValue(body?.id_type);
    const countryCode = stringValue(body?.country_code).toUpperCase();
    const selfiePath = stringValue(body?.selfie_storage_path);
    const idPath = stringValue(body?.id_photo_storage_path);
    const clientOcrDob = optionalIsoDate(body?.ocr_dob);
    const clientFaceSimilarity = optionalScore(body?.face_similarity);
    uploadedPaths = [selfiePath, idPath].filter(Boolean);

    if (requestedUserId !== user.id) {
      return json(403, "You may only submit your own identity check.");
    }
    if (!supportedIdTypes.has(idType) || !/^[A-Z]{2}$/.test(countryCode)) {
      return json(400, "Invalid identity document details.");
    }
    if (
      !ownsKycPath(selfiePath, user.id, "kyc_selfie") ||
      !ownsKycPath(idPath, user.id, "kyc_id")
    ) {
      return json(403, "Invalid private document path.");
    }
    if (body?.face_similarity != null && clientFaceSimilarity == null) {
      return json(400, "Invalid optional face-match hint.");
    }
    if (body?.ocr_dob != null && stringValue(body.ocr_dob) && !clientOcrDob) {
      return json(400, "Invalid optional OCR date hint.");
    }

    const [selfieObject, idObject] = await Promise.all([
      inspectFreshPrivateImage(admin, selfiePath, user.id),
      inspectFreshPrivateImage(admin, idPath, user.id),
    ]);
    const { error: reservationError } = await admin.rpc(
      "consume_kyc_upload_reservations",
      {
        p_user_id: user.id,
        p_selfie_path: selfiePath,
        p_selfie_mime: selfieObject.mime,
        p_selfie_bytes: selfieObject.size,
        p_id_path: idPath,
        p_id_mime: idObject.mime,
        p_id_bytes: idObject.size,
      },
    );
    if (reservationError) {
      throw new Error("Identity upload reservation is invalid or expired.");
    }

    const { data, error: submitError } = await admin.rpc(
      "submit_manual_kyc_for_review",
      {
        p_user_id: user.id,
        p_country_code: countryCode,
        p_id_type: idType,
        p_selfie_storage_path: selfiePath,
        p_id_photo_storage_path: idPath,
        p_client_ocr_dob: clientOcrDob,
        p_client_face_similarity: clientFaceSimilarity,
      },
    );
    if (submitError) throw submitError;

    const payload = data && typeof data === "object"
      ? data as Record<string, unknown>
      : {};
    submissionPersisted = payload.accepted === true;
    if (!submissionPersisted) {
      // The user already has a pending review. These newly uploaded objects
      // are redundant and must not become hidden storage cost.
      await admin.storage.from(bucket).remove(uploadedPaths);
    } else {
      await queueIdentityNotification(
        admin,
        user.id,
        "kyc_pending",
        "Identity check received",
        "Your document and selfie are queued for private review. We will notify you when the review is complete.",
      );
    }

    return new Response(
      JSON.stringify({
        status: "pending_review",
        submission_id: payload.submission_id,
        message: stringValue(payload.message) ||
          "Your identity check is awaiting private review.",
      }),
      {
        status: 200,
        headers: noStoreHeaders(),
      },
    );
  } catch (cause) {
    console.error("[process-kyc] manual submission failed", safeError(cause));
    if (!submissionPersisted && uploadedPaths.length > 0) {
      await admin.storage.from(bucket).remove(uploadedPaths).catch(() => null);
    }
    const message =
      cause instanceof Error && cause.message.includes("Maximum 3")
        ? cause.message
        : "Unable to submit identity evidence. Please try again.";
    return json(422, message);
  }
});

async function inspectFreshPrivateImage(
  admin: ReturnType<typeof createAdminClient>,
  path: string,
  userId: string,
): Promise<{ size: number; mime: string }> {
  const name = path.slice(userId.length + 1);
  const { data, error } = await admin.storage.from(bucket).list(userId, {
    limit: 10,
    search: name,
  });
  if (error) throw new Error("Private identity upload could not be inspected.");
  const object = data?.find((item) => item.name === name);
  if (!object) throw new Error("Private identity upload was not found.");

  const metadata = object.metadata as Record<string, unknown> | null;
  const size = Number(metadata?.size ?? 0);
  const mime = stringValue(metadata?.mimetype ?? metadata?.contentType)
    .toLowerCase();
  const createdAt = Date.parse(object.created_at ?? "");
  if (!Number.isFinite(size) || size <= 0 || size > maxFileBytes) {
    throw new Error("Identity images must be between 1 byte and 8 MB.");
  }
  if (!new Set(["image/jpeg", "image/webp"]).has(mime)) {
    throw new Error("Identity evidence must be a supported image.");
  }
  if (!Number.isFinite(createdAt) || Date.now() - createdAt > maxUploadAgeMs) {
    throw new Error("Identity upload expired. Please capture new images.");
  }
  const { data: blob, error: downloadError } = await admin.storage.from(bucket)
    .download(path);
  if (downloadError || !blob) {
    throw new Error("Private identity upload could not be inspected.");
  }
  const bytes = new Uint8Array(await blob.arrayBuffer());
  if (bytes.byteLength !== size || !matchesMime(bytes, mime)) {
    throw new Error("Identity evidence format did not match its upload.");
  }
  try {
    const image = await Image.decode(bytes);
    if (
      image.width < 320 || image.height < 320 ||
      image.width * image.height > 32_000_000
    ) {
      throw new Error("invalid_dimensions");
    }
  } catch {
    throw new Error("Identity evidence is not a valid image.");
  }
  return { size, mime };
}

function matchesMime(bytes: Uint8Array, mime: string): boolean {
  if (mime === "image/jpeg") return bytes[0] === 0xff && bytes[1] === 0xd8;
  return new TextDecoder().decode(bytes.slice(0, 4)) === "RIFF" &&
    new TextDecoder().decode(bytes.slice(8, 12)) === "WEBP";
}

async function queueIdentityNotification(
  admin: ReturnType<typeof createAdminClient>,
  userId: string,
  type: string,
  title: string,
  body: string,
): Promise<void> {
  const { error } = await admin.from("notifications").insert({
    user_id: userId,
    type,
    title,
    body,
    deep_link: "silarah://profile",
  });
  if (error) {
    console.error("[process-kyc] notification queue failed", {
      type,
      message: error.message,
    });
  }
}

function ownsKycPath(path: string, userId: string, prefix: string): boolean {
  return new RegExp(
    `^${escapeRegExp(userId)}/${prefix}_[0-9a-f-]+\\.(jpg|jpeg|png|webp)$`,
    "i",
  ).test(path);
}

function optionalIsoDate(value: unknown): string | null {
  const input = stringValue(value);
  if (!input) return null;
  if (!/^\d{4}-\d{2}-\d{2}$/.test(input)) return null;
  const parsed = new Date(`${input}T00:00:00.000Z`);
  if (
    Number.isNaN(parsed.getTime()) ||
    parsed.toISOString().slice(0, 10) !== input
  ) {
    return null;
  }
  return input;
}

function optionalScore(value: unknown): number | null {
  if (value == null || value === "") return null;
  const score = Number(value);
  return Number.isFinite(score) && score >= 0 && score <= 1 ? score : null;
}

function escapeRegExp(value: string): string {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

function stringValue(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

function safeError(error: unknown): Record<string, string> {
  if (error instanceof Error) {
    return { name: error.name, message: error.message };
  }
  return { name: "UnknownError", message: "Unknown submission failure" };
}

function noStoreHeaders(): Record<string, string> {
  return {
    ...corsHeaders,
    "Content-Type": "application/json",
    "Cache-Control": "no-store",
  };
}

function json(status: number, message: string): Response {
  return new Response(JSON.stringify({ status: "rejected", message }), {
    status,
    headers: noStoreHeaders(),
  });
}

function createAdminClient() {
  return createClient(supabaseUrl, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
}
