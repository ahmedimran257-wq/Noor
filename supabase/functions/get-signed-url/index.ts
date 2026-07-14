// ============================================================
// EDGE FUNCTION: get-signed-url
// supabase/functions/get-signed-url/index.ts
//
// Issues a short-lived pre-signed upload URL for profile photos.
//
// Security architecture (from Blueprint Part 15):
//   1. Check photo quota (max 4) — 403 if exceeded
//   2. Rate-limit: max 100 URL requests/hour per user (anti-scraping)
//   3. Insert 'pending_upload' placeholder in photos table
//   4. Return the pre-signed upload URL to the client
//
// This prevents the bypass vulnerability where a malicious client
// hoards pre-signed URLs without the DB tracking rows,
// bypassing the photo quota entirely.
//
// Storage SELECT RLS is disabled on the bucket — all reads
// served via signed URLs from this function only.
// ============================================================

import {
  createClient,
  type SupabaseClient,
} from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, handleCors } from "../_shared/cors.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;

const BUCKET_NAME = "profile-photos";
const KYC_BUCKET_NAME = "kyc-documents";
const MAX_PHOTOS = 4;
const UPLOAD_URL_EXPIRES_IN = 300; // Upload tokens stay deliberately short-lived.
const READ_URL_EXPIRES_IN = 3600; // Read URLs are refreshed by the client on failure.
const RATE_LIMIT_WINDOW = 60 * 60; // 1 hour in seconds
const RATE_LIMIT_MAX = 100; // Max URL requests per user per hour

// In-memory rate limiter (per function instance)
// For production at scale, use Upstash Redis instead:
// https://upstash.com/docs/redis/sdks/deno
const rateLimitMap = new Map<string, { count: number; resetAt: number }>();

Deno.serve(async (req: Request) => {
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  try {
    // ── Authenticate caller ────────────────────────────────────
    const authHeader = req.headers.get("Authorization");
    if (!authHeader?.startsWith("Bearer ")) {
      return errorResponse(401, "Missing or invalid Authorization header.");
    }
    const userToken = authHeader.replace("Bearer ", "");

    // User-scoped client to get auth.uid()
    const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      global: { headers: { Authorization: `Bearer ${userToken}` } },
      auth: { autoRefreshToken: false, persistSession: false },
    });

    const { data: { user }, error: authError } = await userClient.auth
      .getUser();
    if (authError || !user) {
      return errorResponse(401, "Unauthorized.");
    }
    const userId = user.id;

    // ── Rate limiting (anti-scraping) ──────────────────────────
    const now = Math.floor(Date.now() / 1000);
    const rateEntry = rateLimitMap.get(userId);

    if (rateEntry && rateEntry.resetAt > now) {
      if (rateEntry.count >= RATE_LIMIT_MAX) {
        console.warn(`[get-signed-url] Rate limit exceeded for user ${userId}`);
        // Flag for admin review (potential scraper)
        await flagSuspiciousUser(userId, "rate_limit_exceeded_signed_url");
        return errorResponse(429, "Too many requests. Please try again later.");
      }
      rateEntry.count++;
    } else {
      rateLimitMap.set(userId, { count: 1, resetAt: now + RATE_LIMIT_WINDOW });
    }

    // ── Parse request ──────────────────────────────────────────
    const {
      order_index,
      file_extension,
      purpose,
      owner_user_id,
      owner_user_ids,
      storage_path,
    } = await req.json() as {
      order_index?: number;
      file_extension?: string;
      purpose?:
        | "kyc_selfie"
        | "kyc_id"
        | "read_profile_photo"
        | "read_profile_photos"
        | "delete_profile_photo"
        | "delete_replaced_profile_photo";
      owner_user_id?: string;
      owner_user_ids?: string[];
      storage_path?: string;
    };

    if (purpose === "read_profile_photo") {
      return await createAuthorizedProfilePhotoReadUrl(
        userClient,
        userId,
        owner_user_id,
        order_index ?? 0,
      );
    }
    if (purpose === "read_profile_photos") {
      return await createAuthorizedProfilePhotoReadUrls(
        userClient,
        userId,
        owner_user_ids,
        order_index ?? 0,
      );
    }
    if (purpose === "delete_profile_photo") {
      return await deleteOwnProfilePhoto(userId, order_index);
    }
    if (purpose === "delete_replaced_profile_photo") {
      return await deleteReplacedProfilePhotoObject(userId, storage_path);
    }

    const ext = (file_extension ?? "webp").toLowerCase();
    const allowedTypes = ["webp", "jpg", "jpeg", "png"];
    if (!allowedTypes.includes(ext)) {
      return errorResponse(400, "Only webp, jpg, jpeg, and png are allowed.");
    }

    // KYC uploads use a dedicated private bucket. They never create a public
    // photo record and are always scoped to the authenticated user's folder.
    if (purpose === "kyc_selfie" || purpose === "kyc_id") {
      return await createKycSignedUploadUrl(userId, purpose, ext);
    }

    if (order_index === undefined || order_index < 0 || order_index > 3) {
      return errorResponse(400, "order_index must be 0, 1, 2, or 3.");
    }

    // ── Service-role client for DB operations ──────────────────
    const adminClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY, {
      auth: { autoRefreshToken: false, persistSession: false },
    });

    // ── Get user's profile ID ──────────────────────────────────
    const { data: profile, error: profileError } = await adminClient
      .from("profiles")
      .select("id")
      .eq("user_id", userId)
      .single();

    if (profileError || !profile) {
      return errorResponse(
        404,
        "Profile not found. Complete onboarding first.",
      );
    }
    const profileId = profile.id;

    const { data: existingPhoto, error: existingPhotoError } =
      await adminClient
        .from("photos")
        .select("storage_path")
        .eq("profile_id", profileId)
        .eq("order_index", order_index)
        .maybeSingle();
    if (existingPhotoError) {
      throw new Error(
        `Existing photo query failed: ${existingPhotoError.message}`,
      );
    }

    // ── Check photo quota (BEFORE generating URL) ──────────────
    const { count: existingCount, error: countError } = await adminClient
      .from("photos")
      .select("id", { count: "exact", head: true })
      .eq("profile_id", profileId)
      .eq("status", "active"); // Only count successfully uploaded photos

    if (countError) {
      throw new Error(`Photo count query failed: ${countError.message}`);
    }

    if (!existingPhoto && (existingCount ?? 0) >= MAX_PHOTOS) {
      return errorResponse(
        403,
        `Maximum ${MAX_PHOTOS} photos allowed. Delete one before uploading.`,
      );
    }

    // ── Generate unique storage path ───────────────────────────
    const fileName = `${crypto.randomUUID()}.${ext}`;
    const storagePath = `${userId}/${fileName}`;

    // ── Insert 'pending_upload' placeholder (atomic gate) ──────
    // This row is inserted BEFORE the URL is returned.
    // If the upload never completes, a cleanup job removes stale pending_upload rows.
    const { error: insertError } = await adminClient
      .from("photos")
      .upsert({
        profile_id: profileId,
        storage_path: storagePath,
        status: "pending_upload",
        order_index,
        admin_approved: false,
        nsfw_cleared: false,
        moderation_status: "pending_upload",
      }, {
        onConflict: "profile_id,order_index", // Replaces existing pending for same slot
      });

    if (insertError) {
      throw new Error(`Failed to reserve photo slot: ${insertError.message}`);
    }

    // ── Generate the pre-signed upload URL ─────────────────────
    const { data: signedUrlData, error: urlError } = await adminClient
      .storage
      .from(BUCKET_NAME)
      .createSignedUploadUrl(storagePath);

    if (urlError || !signedUrlData?.signedUrl) {
      // Rollback the placeholder row since we can't provide the URL
      await adminClient.from("photos").delete()
        .eq("profile_id", profileId)
        .eq("storage_path", storagePath);
      throw new Error(`Failed to generate upload URL: ${urlError?.message}`);
    }

    console.log(
      `[get-signed-url] ✅ URL issued for user ${userId}, slot ${order_index}`,
    );

    return new Response(
      JSON.stringify({
        signed_url: signedUrlData.signedUrl,
        storage_path: storagePath,
        token: signedUrlData.token,
        replaced_storage_path: existingPhoto?.storage_path ?? null,
        expires_in: UPLOAD_URL_EXPIRES_IN,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  } catch (err) {
    console.error("[get-signed-url] Error:", err);
    const message = err instanceof Error
      ? err.message
      : "Failed to generate upload URL.";
    return errorResponse(500, message);
  }
});

async function deleteOwnProfilePhoto(
  userId: string,
  orderIndex: number | undefined,
): Promise<Response> {
  if (!Number.isInteger(orderIndex) || orderIndex! < 0 || orderIndex! > 3) {
    return errorResponse(400, "order_index must be 0, 1, 2, or 3.");
  }
  const adminClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const { data: profile, error: profileError } = await adminClient
    .from("profiles")
    .select("id")
    .eq("user_id", userId)
    .single();
  if (profileError || !profile) {
    return errorResponse(404, "Profile not found.");
  }
  const { data: photo, error: photoError } = await adminClient
    .from("photos")
    .select("id, storage_path")
    .eq("profile_id", profile.id)
    .eq("order_index", orderIndex!)
    .maybeSingle();
  if (photoError) {
    throw new Error(`Photo lookup failed: ${photoError.message}`);
  }
  if (!photo) {
    return new Response(JSON.stringify({ deleted: false }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const { error: deleteError } = await adminClient
    .from("photos")
    .delete()
    .eq("id", photo.id)
    .eq("profile_id", profile.id);
  if (deleteError) {
    throw new Error(`Photo deletion failed: ${deleteError.message}`);
  }
  const { error: storageError } = await adminClient.storage
    .from(BUCKET_NAME)
    .remove([photo.storage_path]);
  if (storageError) {
    console.warn(
      `[get-signed-url] orphaned deleted photo ${photo.storage_path}: ${storageError.message}`,
    );
  }
  return new Response(JSON.stringify({ deleted: true }), {
    status: 200,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

async function deleteReplacedProfilePhotoObject(
  userId: string,
  storagePath: string | undefined,
): Promise<Response> {
  if (!storagePath || !storagePath.startsWith(`${userId}/`)) {
    return errorResponse(400, "A valid replaced storage path is required.");
  }
  const adminClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const { count, error: referenceError } = await adminClient
    .from("photos")
    .select("id", { count: "exact", head: true })
    .eq("storage_path", storagePath);
  if (referenceError) {
    throw new Error(`Photo reference check failed: ${referenceError.message}`);
  }
  if ((count ?? 0) > 0) {
    return errorResponse(409, "The photo is still active and cannot be removed.");
  }
  const { error } = await adminClient.storage
    .from(BUCKET_NAME)
    .remove([storagePath]);
  if (error) {
    throw new Error(`Replaced photo cleanup failed: ${error.message}`);
  }
  return new Response(JSON.stringify({ deleted: true }), {
    status: 200,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

async function createKycSignedUploadUrl(
  userId: string,
  purpose: "kyc_selfie" | "kyc_id",
  extension: string,
): Promise<Response> {
  const adminClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const storagePath =
    `${userId}/${purpose}_${crypto.randomUUID()}.${extension}`;
  const { data, error } = await adminClient.storage
    .from(KYC_BUCKET_NAME)
    .createSignedUploadUrl(storagePath);
  if (error || !data?.signedUrl) {
    throw new Error(`Failed to generate KYC upload URL: ${error?.message}`);
  }
  return new Response(
    JSON.stringify({
      signed_url: data.signedUrl,
      storage_path: storagePath,
      token: data.token,
      expires_in: UPLOAD_URL_EXPIRES_IN,
    }),
    {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    },
  );
}

async function createAuthorizedProfilePhotoReadUrl(
  userClient: SupabaseClient,
  viewerUserId: string,
  ownerUserId: string | undefined,
  orderIndex: number,
): Promise<Response> {
  if (!ownerUserId || !isUuid(ownerUserId)) {
    return errorResponse(400, "owner_user_id is required.");
  }
  if (!Number.isInteger(orderIndex) || orderIndex < 0 || orderIndex > 3) {
    return errorResponse(400, "order_index must be 0, 1, 2, or 3.");
  }

  // This user-scoped query is intentional: photos RLS calls can_view_photo(),
  // so public, mutual_only, and request_only privacy are enforced before any
  // service-role signed URL is created. The client never supplies a storage path.
  const { data: photo, error: photoError } = await userClient
    .from("photos")
    .select("storage_path, profiles!inner(user_id)")
    .eq("profiles.user_id", ownerUserId)
    .eq("order_index", orderIndex)
    .eq("status", "active")
    .eq("admin_approved", true)
    .eq("nsfw_cleared", true)
    .maybeSingle();

  if (photoError) {
    throw new Error(`Photo authorization failed: ${photoError.message}`);
  }
  if (!photo?.storage_path) {
    return errorResponse(403, "You do not have access to this photo.");
  }

  const adminClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const { data, error } = await adminClient.storage
    .from(BUCKET_NAME)
    .createSignedUrl(photo.storage_path, READ_URL_EXPIRES_IN, {
      transform: {
        width: 768,
        height: 1024,
        resize: "cover",
        quality: 72,
      },
    } as never);

  if (error || !data?.signedUrl) {
    throw new Error(`Failed to generate read URL: ${error?.message}`);
  }

  console.log(
    `[get-signed-url] read URL issued for viewer ${viewerUserId}, owner ${ownerUserId}, slot ${orderIndex}`,
  );

  return new Response(
    JSON.stringify({
      signed_url: data.signedUrl,
      expires_in: READ_URL_EXPIRES_IN,
    }),
    {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    },
  );
}

async function createAuthorizedProfilePhotoReadUrls(
  userClient: SupabaseClient,
  viewerUserId: string,
  ownerUserIds: string[] | undefined,
  orderIndex: number,
): Promise<Response> {
  const uniqueOwnerIds = [
    ...new Set((ownerUserIds ?? []).filter((id) => isUuid(id))),
  ].slice(0, 50);
  if (uniqueOwnerIds.length === 0) {
    return errorResponse(400, "owner_user_ids is required.");
  }
  if (!Number.isInteger(orderIndex) || orderIndex < 0 || orderIndex > 3) {
    return errorResponse(400, "order_index must be 0, 1, 2, or 3.");
  }

  // User-scoped query enforces photos RLS/can_view_photo() for every owner.
  // The client supplies owner IDs only, never storage paths.
  const { data: photos, error: photoError } = await userClient
    .from("photos")
    .select("storage_path, profiles!inner(user_id)")
    .in("profiles.user_id", uniqueOwnerIds)
    .eq("order_index", orderIndex)
    .eq("status", "active")
    .eq("admin_approved", true)
    .eq("nsfw_cleared", true);

  if (photoError) {
    throw new Error(`Photo authorization failed: ${photoError.message}`);
  }

  const pathToOwner = new Map<string, string>();
  for (const photo of photos ?? []) {
    const row = photo as unknown as {
      storage_path?: unknown;
      profiles?: { user_id?: unknown } | Array<{ user_id?: unknown }>;
    };
    const storagePath = String(row.storage_path ?? "");
    const relation = row.profiles;
    const ownerId = Array.isArray(relation)
      ? relation[0]?.user_id
      : relation?.user_id;
    if (storagePath && typeof ownerId === "string") {
      pathToOwner.set(storagePath, ownerId);
    }
  }

  if (pathToOwner.size === 0) {
    return new Response(
      JSON.stringify({ urls: {}, expires_in: READ_URL_EXPIRES_IN }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  }

  const adminClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const storagePaths = [...pathToOwner.keys()];
  const { data, error } = await adminClient.storage
    .from(BUCKET_NAME)
    .createSignedUrls(storagePaths, READ_URL_EXPIRES_IN, {
      transform: {
        width: 768,
        height: 1024,
        resize: "cover",
        quality: 72,
      },
    } as never);

  if (error || !data) {
    throw new Error(`Failed to generate batch read URLs: ${error?.message}`);
  }

  const urls: Record<string, string> = {};
  for (const item of data) {
    const signedUrl = item.signedUrl;
    const path = item.path;
    const ownerId = path ? pathToOwner.get(path) : undefined;
    if (ownerId && signedUrl) {
      urls[ownerId] = signedUrl;
    }
  }

  console.log(
    `[get-signed-url] batch read URLs issued for viewer ${viewerUserId}, owners ${
      Object.keys(urls).length
    }`,
  );

  return new Response(
    JSON.stringify({
      urls,
      expires_in: READ_URL_EXPIRES_IN,
    }),
    {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    },
  );
}

function isUuid(value: string): boolean {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
    .test(value);
}

async function flagSuspiciousUser(
  userId: string,
  reason: string,
): Promise<void> {
  try {
    const adminClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY, {
      auth: { autoRefreshToken: false, persistSession: false },
    });
    await adminClient.from("admin_notifications").insert({
      type: "suspicious_activity",
      message: `User ${userId} flagged: ${reason}`,
      related_user_id: userId,
    });
  } catch (_) {
    // Non-critical — don't throw
  }
}

function errorResponse(status: number, message: string): Response {
  return new Response(
    JSON.stringify({ error: message }),
    { status, headers: { ...corsHeaders, "Content-Type": "application/json" } },
  );
}
