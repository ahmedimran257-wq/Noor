// ============================================================
// EDGE FUNCTION: admin-purge-deleted-users
// supabase/functions/admin-purge-deleted-users/index.ts
//
// Safely purges accounts that have passed their 30-day
// deletion grace period.
//
// "Zombie Auth" Prevention:
//   NEVER delete from public.users directly from pg_cron.
//   This leaves orphaned auth.users records that can still
//   log in and receive OTPs even after "deletion".
//
// Correct order:
//   1. Find users with deletion_status = 'pending_deletion'
//      AND deleted_at < now() - 30 days
//   2. Call supabase.auth.admin.deleteUser(uid) — deletes
//      from auth.users AND invalidates all sessions
//   3. ONLY after Auth API returns 200, delete from public.users
//   4. The CASCADE foreign key deletes all related data
//   5. Clean up Supabase Storage via storage_cleanup_queue
//
// Called by pg_cron at 03:15 UTC via pg_net.http_post().
// ============================================================

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";

const SUPABASE_URL         = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const GRACE_PERIOD_DAYS = 30;
const BUCKET_NAME       = "profile-photos";
const BATCH_SIZE        = 50;             // Process max 50 deletions per run

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  // ── This endpoint is internal-only (cron-triggered) ────────
  // Verify the Authorization header is the service role key
  const authHeader = req.headers.get("Authorization") ?? "";
  if (!authHeader.includes(SUPABASE_SERVICE_KEY.slice(-12))) {
    // Note: In production, use a separate CRON_SECRET env var
    console.warn("[admin-purge] Unauthorized invocation blocked.");
    return new Response("Unauthorized", { status: 401 });
  }

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  // ── Fetch accounts ready for purge ────────────────────────
  const cutoff = new Date(Date.now() - GRACE_PERIOD_DAYS * 24 * 60 * 60 * 1000).toISOString();

  const { data: pendingUsers, error: fetchError } = await supabase
    .from("users")
    .select("id, phone, deleted_at")
    .eq("deletion_status", "pending_deletion")
    .lt("deleted_at", cutoff)
    .limit(BATCH_SIZE);

  if (fetchError) {
    console.error("[admin-purge] Fetch error:", fetchError.message);
    return new Response("Internal Server Error", { status: 500 });
  }

  if (!pendingUsers || pendingUsers.length === 0) {
    console.log("[admin-purge] No accounts due for purge.");
    return new Response(JSON.stringify({ purged: 0 }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  console.log(`[admin-purge] Processing ${pendingUsers.length} account(s) for purge...`);

  let purgedCount = 0;
  let failedCount = 0;

  for (const user of pendingUsers) {
    try {
      // ── Step 1: Delete from Supabase Auth FIRST ─────────────
      const { error: authDeleteError } = await supabase.auth.admin.deleteUser(user.id);

      if (authDeleteError) {
        // auth.users record may already not exist — log and continue
        console.error(
          `[admin-purge] Auth delete failed for ${user.id}:`,
          authDeleteError.message
        );
        // Fall through to DB delete only if auth user was already removed
        const isNotFound = authDeleteError.message.toLowerCase().includes("not found");
        if (!isNotFound) {
          failedCount++;
          continue;
        }
      }

      // ── Step 2: Purge Storage objects ───────────────────────
      await purgeUserStorage(supabase, user.id);

      // ── Step 3: Delete from public.users (CASCADE removes all) ─
      const { error: dbDeleteError } = await supabase
        .from("users")
        .delete()
        .eq("id", user.id);

      if (dbDeleteError) {
        console.error(
          `[admin-purge] DB delete failed for ${user.id}:`,
          dbDeleteError.message
        );
        failedCount++;
        continue;
      }

      // ── Step 4: Mark storage cleanup as done ─────────────────
      await supabase
        .from("storage_cleanup_queue")
        .update({ status: "done" })
        .eq("user_id", user.id);

      // ── Step 5: Log the purge ─────────────────────────────────
      await supabase.from("admin_audit_log").insert({
        admin_id:       "00000000-0000-0000-0000-000000000000", // System actor
        action_type:    "account_purged",
        target_user_id: user.id,
        details:        { phone_hash: await hashPhone(user.phone), deleted_at: user.deleted_at },
      });

      purgedCount++;
      console.log(`[admin-purge] ✅ Purged user ${user.id}`);

    } catch (err) {
      console.error(`[admin-purge] Unexpected error for ${user.id}:`, err);
      failedCount++;
    }
  }

  console.log(`[admin-purge] Complete. Purged: ${purgedCount}, Failed: ${failedCount}`);

  return new Response(
    JSON.stringify({ purged: purgedCount, failed: failedCount }),
    {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    }
  );
});

// ── Remove all Storage objects for a user ─────────────────────

async function purgeUserStorage(
  supabase: ReturnType<typeof createClient>,
  userId: string
): Promise<void> {
  try {
    // List all objects in the user's storage folder
    const { data: objects, error: listError } = await supabase.storage
      .from(BUCKET_NAME)
      .list(userId, { limit: 100 });

    if (listError) {
      console.warn(`[admin-purge] Storage list failed for ${userId}:`, listError.message);
      return;
    }

    if (!objects || objects.length === 0) return;

    const paths = objects.map((obj) => `${userId}/${obj.name}`);
    const { error: removeError } = await supabase.storage
      .from(BUCKET_NAME)
      .remove(paths);

    if (removeError) {
      console.warn(
        `[admin-purge] Storage remove failed for ${userId}:`,
        removeError.message
      );
    } else {
      console.log(`[admin-purge] 🗑️ Removed ${paths.length} storage object(s) for ${userId}`);
    }
  } catch (err) {
    console.warn(`[admin-purge] Storage purge exception for ${userId}:`, err);
    // Non-fatal — DB deletion still proceeds
  }
}

// One-way hash of phone for audit log (never store plaintext in logs)
async function hashPhone(phone: string): Promise<string> {
  const bytes = new TextEncoder().encode(phone);
  const hash  = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(hash))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("")
    .slice(0, 16); // Short hash for audit reference only
}
