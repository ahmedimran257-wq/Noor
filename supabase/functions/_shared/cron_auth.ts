import { createClient } from "@supabase/supabase-js";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

/// Verifies the secret stored in Supabase Vault and sent only by pg_cron.
/// These functions use --no-verify-jwt because pg_net cannot mint a user JWT.
export async function isAuthorizedCronRequest(req: Request): Promise<boolean> {
  const supplied = req.headers.get("x-cron-secret");
  if (!supplied || supplied.length < 32) return false;

  const digest = await sha256(supplied);
  const admin = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const { data, error } = await admin
    .from("internal_cron_credentials")
    .select("secret_hash")
    .eq("name", "edge_cron")
    .maybeSingle();

  if (error || !data?.secret_hash) return false;
  return constantTimeEqual(digest, data.secret_hash as string);
}

async function sha256(value: string): Promise<string> {
  const hash = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(value),
  );
  return Array.from(new Uint8Array(hash))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

function constantTimeEqual(left: string, right: string): boolean {
  if (left.length !== right.length) return false;
  let difference = 0;
  for (let index = 0; index < left.length; index += 1) {
    difference |= left.charCodeAt(index) ^ right.charCodeAt(index);
  }
  return difference === 0;
}
