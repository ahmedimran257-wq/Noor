// ============================================================
// EDGE FUNCTION: validate-photo-upload
// supabase/functions/validate-photo-upload/index.ts
//
// Fixes Audit Finding 9.1 (Medium):
//   Photo upload quota race condition. A user could request 4 URLs,
//   use them, delete a photo, and request another — bypassing quota.
//
// Registered as a Supabase Storage webhook on ObjectCreated events
// in the 'profile-photos' bucket. Validates the final file commit
// against the photos table count, rolling back if count > 4.
// ============================================================

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";
import { Image } from "https://deno.land/x/imagescript@1.2.15/mod.ts";
import { encode } from "https://esm.sh/blurhash@2.0.5";
import {
  type ClientPhotoModerationPayload,
  resolveClientModerationVerdict,
} from "./photo_moderation_policy.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;

const BUCKET_NAME = "profile-photos";
const MAX_PHOTOS = 4;

interface StorageWebhookPayload {
  type: "ObjectCreated" | "ObjectDeleted";
  record: {
    name: string; // e.g. "user-uuid/photo-uuid.webp"
    bucket_id: string;
    owner: string;
    metadata: Record<string, unknown>;
  };
}

interface DirectValidationPayload {
  storage_path: string;
  moderation: ClientPhotoModerationPayload;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const payload = await req.json() as
      | StorageWebhookPayload
      | DirectValidationPayload;

    let storagePath: string;
    let moderation: DirectValidationPayload["moderation"] | null = null;
    if ("record" in payload && payload.type === "ObjectCreated") {
      storagePath = payload.record.name;
    } else if ("storage_path" in payload) {
      const authHeader = req.headers.get("Authorization");
      if (!authHeader?.startsWith("Bearer ")) {
        return new Response(JSON.stringify({ error: "Unauthorized" }), {
          status: 401,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }
      const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
        global: { headers: { Authorization: authHeader } },
        auth: { autoRefreshToken: false, persistSession: false },
      });
      const { data: { user }, error: authError } = await userClient.auth
        .getUser();
      if (
        authError || !user || !payload.storage_path.startsWith(`${user.id}/`)
      ) {
        return new Response(JSON.stringify({ error: "Unauthorized" }), {
          status: 401,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }
      storagePath = payload.storage_path;
      moderation = payload.moderation ?? null;
    } else {
      return new Response(JSON.stringify({ action: "ignored" }), {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Ignore storage delete webhook events.
    if ("type" in payload && payload.type !== "ObjectCreated") {
      return new Response(JSON.stringify({ action: "ignored" }), {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Extract user_id from the storage path (format: {user_id}/{filename}.webp)
    const pathParts = storagePath.split("/");
    if (pathParts.length < 2) {
      console.warn(
        `[validate-photo-upload] Invalid storage path: ${storagePath}`,
      );
      return new Response(JSON.stringify({ action: "invalid_path" }), {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const userId = pathParts[0];

    const adminClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY, {
      auth: { autoRefreshToken: false, persistSession: false },
    });

    // Storage webhooks cannot prove that the on-device model ran. Keep those
    // rows pending; only the authenticated client validation path can activate.
    if (moderation === null) {
      return new Response(JSON.stringify({ action: "awaiting_client_scan" }), {
        status: 202,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const moderationAction = resolveClientModerationVerdict(moderation);

    if (moderationAction === "reject") {
      await adminClient.storage.from(BUCKET_NAME).remove([storagePath]);
      await adminClient.from("photos").delete().eq("storage_path", storagePath);
      await adminClient.from("admin_notifications").insert({
        type: "photo_moderation_rejected",
        message: `On-device NSFW moderation rejected photo ${storagePath}.`,
        related_user_id: userId,
      });
      return new Response(
        JSON.stringify({
          action: "rejected",
          reason: "photo_moderation_failed",
        }),
        {
          status: 422,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    // Get the user's profile
    const { data: profile, error: profileError } = await adminClient
      .from("profiles")
      .select("id")
      .eq("user_id", userId)
      .single();

    if (profileError || !profile) {
      console.error(
        `[validate-photo-upload] Profile not found for user ${userId}`,
      );
      // Delete the uploaded file — no valid profile
      await adminClient.storage.from(BUCKET_NAME).remove([storagePath]);
      return new Response(JSON.stringify({ action: "deleted_orphan" }), {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Count ALL photos for this profile (active + pending_upload)
    const { count, error: countError } = await adminClient
      .from("photos")
      .select("id", { count: "exact", head: true })
      .eq("profile_id", profile.id);

    if (countError) {
      console.error(
        `[validate-photo-upload] Count error: ${countError.message}`,
      );
      return new Response(JSON.stringify({ action: "count_error" }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    if ((count ?? 0) > MAX_PHOTOS) {
      console.warn(
        `[validate-photo-upload] ❌ Quota exceeded for user ${userId}: ` +
          `${count} photos (max ${MAX_PHOTOS}). Rolling back upload.`,
      );

      // Delete the uploaded file from storage
      await adminClient.storage.from(BUCKET_NAME).remove([storagePath]);

      // Delete the corresponding photos row
      await adminClient
        .from("photos")
        .delete()
        .eq("profile_id", profile.id)
        .eq("storage_path", storagePath);

      // Flag for admin review
      await adminClient.from("admin_notifications").insert({
        type: "quota_violation",
        message:
          `User ${userId} attempted to exceed photo quota (${count}/${MAX_PHOTOS}). Upload rolled back.`,
        related_user_id: userId,
      });

      return new Response(
        JSON.stringify({
          action: "rolled_back",
          reason: `Photo quota exceeded (${count}/${MAX_PHOTOS})`,
        }),
        {
          status: 200,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    // Quota OK — activate the photo if it's still in pending_upload
    const { error: updateError } = await adminClient
      .from("photos")
      .update({
        status: "active",
        admin_approved: false,
        nsfw_cleared: false,
        nsfw_score: moderation.confidence,
        nsfw_category: moderation.category,
        nsfw_scanned_at: new Date().toISOString(),
        moderation_source: "nsfw_detect_on_device",
        moderation_status: "pending",
      })
      .eq("profile_id", profile.id)
      .eq("storage_path", storagePath)
      .eq("status", "pending_upload");

    if (updateError) {
      console.warn(
        `[validate-photo-upload] Could not activate photo: ${updateError.message}`,
      );
    } else {
      console.log(
        `[validate-photo-upload] ✅ Photo activated for user ${userId}: ${storagePath}`,
      );

      // Generate BlurHash
      try {
        const { data: fileData, error: downloadError } = await adminClient
          .storage
          .from(BUCKET_NAME)
          .download(storagePath);

        if (downloadError) {
          console.error(
            `[validate-photo-upload] Failed to download image for BlurHash: ${downloadError.message}`,
          );
        } else if (fileData) {
          const arrayBuffer = await fileData.arrayBuffer();
          const uint8Array = new Uint8Array(arrayBuffer);
          const image = await Image.decode(uint8Array);
          const width = image.width;
          const height = image.height;

          // Scale down for speed/memory efficiency
          const scale = Math.min(32 / width, 32 / height, 1);
          const thumbWidth = Math.max(1, Math.round(width * scale));
          const thumbHeight = Math.max(1, Math.round(height * scale));
          const thumbnail = image.resize(thumbWidth, thumbHeight);

          const rgba = thumbnail.bitmap;
          const clamped = new Uint8ClampedArray(
            rgba.buffer,
            rgba.byteOffset,
            rgba.byteLength,
          );
          const hash = encode(clamped, thumbWidth, thumbHeight, 4, 3);

          const { error: dbUpdateError } = await adminClient
            .from("photos")
            .update({ blurhash: hash })
            .eq("profile_id", profile.id)
            .eq("storage_path", storagePath);

          if (dbUpdateError) {
            console.error(
              `[validate-photo-upload] Failed to save BlurHash to DB: ${dbUpdateError.message}`,
            );
          } else {
            console.log(
              `[validate-photo-upload] ✅ BlurHash generated and saved: ${hash}`,
            );
          }
        }
      } catch (err) {
        console.error(
          `[validate-photo-upload] Error generating BlurHash:`,
          err,
        );
      }
    }

    return new Response(
      JSON.stringify({ action: "pending_review", photo_count: count }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  } catch (err) {
    console.error("[validate-photo-upload] Error:", err);
    return new Response(
      JSON.stringify({
        error: err instanceof Error ? err.message : "Unknown error",
      }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  }
});
