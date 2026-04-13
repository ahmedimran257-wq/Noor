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

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, handleCors } from "../_shared/cors.ts";

const SUPABASE_URL         = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const SUPABASE_ANON_KEY    = Deno.env.get("SUPABASE_ANON_KEY")!;

const BUCKET_NAME       = "profile-photos";
const MAX_PHOTOS        = 4;
const URL_EXPIRES_IN    = 300;           // 5 minutes — client must upload within this window
const RATE_LIMIT_WINDOW = 60 * 60;      // 1 hour in seconds
const RATE_LIMIT_MAX    = 100;          // Max URL requests per user per hour

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
      auth:   { autoRefreshToken: false, persistSession: false },
    });

    const { data: { user }, error: authError } = await userClient.auth.getUser();
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
    const { order_index, file_extension } = await req.json() as {
      order_index: number;
      file_extension?: string;
    };

    if (order_index === undefined || order_index < 0 || order_index > 3) {
      return errorResponse(400, "order_index must be 0, 1, 2, or 3.");
    }

    const ext = file_extension ?? "webp";
    const allowedTypes = ["webp", "jpg", "jpeg"];
    if (!allowedTypes.includes(ext.toLowerCase())) {
      return errorResponse(400, "Only webp, jpg, and jpeg are allowed.");
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
      return errorResponse(404, "Profile not found. Complete onboarding first.");
    }
    const profileId = profile.id;

    // ── Check photo quota (BEFORE generating URL) ──────────────
    const { count: existingCount, error: countError } = await adminClient
      .from("photos")
      .select("id", { count: "exact", head: true })
      .eq("profile_id", profileId)
      .eq("status", "active");             // Only count successfully uploaded photos

    if (countError) throw new Error(`Photo count query failed: ${countError.message}`);

    if ((existingCount ?? 0) >= MAX_PHOTOS) {
      return errorResponse(403, `Maximum ${MAX_PHOTOS} photos allowed. Delete one before uploading.`);
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
        profile_id:     profileId,
        storage_path:   storagePath,
        status:         "pending_upload",
        order_index,
        admin_approved: false,
        nsfw_cleared:   false,
      }, {
        onConflict: "profile_id,order_index",   // Replaces existing pending for same slot
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

    console.log(`[get-signed-url] ✅ URL issued for user ${userId}, slot ${order_index}`);

    return new Response(
      JSON.stringify({
        signed_url:   signedUrlData.signedUrl,
        storage_path: storagePath,
        token:        signedUrlData.token,
        expires_in:   URL_EXPIRES_IN,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  } catch (err) {
    console.error("[get-signed-url] Error:", err);
    const message = err instanceof Error ? err.message : "Failed to generate upload URL.";
    return errorResponse(500, message);
  }
});

// ── Generate a read URL for a photo (separate endpoint) ────────
// Called by Flutter when displaying photos, not included in quota.
export async function getPhotoReadUrl(storagePath: string): Promise<string> {
  const adminClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  const { data, error } = await adminClient.storage
    .from(BUCKET_NAME)
    .createSignedUrl(storagePath, 3600); // 1-hour read URL

  if (error || !data?.signedUrl) {
    throw new Error(`Failed to generate read URL: ${error?.message}`);
  }

  return data.signedUrl;
}

async function flagSuspiciousUser(userId: string, reason: string): Promise<void> {
  try {
    const adminClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY, {
      auth: { autoRefreshToken: false, persistSession: false },
    });
    await adminClient.from("admin_notifications").insert({
      type:            "suspicious_activity",
      message:         `User ${userId} flagged: ${reason}`,
      related_user_id: userId,
    });
  } catch (_) {
    // Non-critical — don't throw
  }
}

function errorResponse(status: number, message: string): Response {
  return new Response(
    JSON.stringify({ error: message }),
    { status, headers: { ...corsHeaders, "Content-Type": "application/json" } }
  );
}
