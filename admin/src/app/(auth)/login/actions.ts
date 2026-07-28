"use server";

import { createHash } from "node:crypto";
import { headers } from "next/headers";
import { redirect } from "next/navigation";
import { z } from "zod";
import { createOptionalAdminClient } from "@/lib/supabase/admin";
import { createClient } from "@/lib/supabase/server";

const credentialsSchema = z.object({
  email: z.string().trim().email(),
  password: z.string().min(8),
});

const secretSalt =
  process.env.ADMIN_LOGIN_HASH_SALT ?? process.env.SUPABASE_SERVICE_ROLE_KEY;

function hashValue(value: string) {
  if (!secretSalt) {
    throw new Error("Admin login hash salt is not configured.");
  }
  return createHash("sha256").update(`${secretSalt}:${value.toLowerCase().trim()}`).digest("hex");
}

async function requestIp() {
  const headerStore = await headers();
  // Cloudflare overwrites this header at the trusted edge. Never accept the
  // left-most X-Forwarded-For value supplied by the browser.
  return headerStore.get("cf-connecting-ip") ?? "unavailable";
}

async function beginLoginAttempt(emailHash: string, ipHash: string) {
  const adminClient = createOptionalAdminClient();
  if (!adminClient) throw new Error("Login protection is unavailable.");
  const { data, error } = await adminClient.rpc("begin_admin_login_attempt", {
    p_email_hash: emailHash,
    p_ip_hash: ipHash,
  });
  if (error || typeof data !== "string") {
    if (error?.message.includes("login_rate_limited")) return undefined;
    throw new Error("Login protection is unavailable.");
  }
  return data;
}

async function finishLoginAttempt(attemptId: string, success: boolean, reason: string) {
  const adminClient = createOptionalAdminClient();
  if (!adminClient) throw new Error("Login protection is unavailable.");
  const { error } = await adminClient.rpc("finish_admin_login_attempt", {
    p_attempt_id: attemptId,
    p_success: success,
    p_reason: reason,
  });
  if (error) throw new Error("Login protection is unavailable.");
}

export async function signIn(formData: FormData) {
  const parsed = credentialsSchema.safeParse({
    email: formData.get("email"),
    password: formData.get("password"),
  });
  if (!parsed.success) redirect("/login?error=Enter+a+valid+email+and+password.");

  let attemptId: string | undefined;
  try {
    const emailHash = hashValue(parsed.data.email);
    const ipHash = hashValue(await requestIp());
    attemptId = await beginLoginAttempt(emailHash, ipHash);
  } catch {
    redirect("/login?error=Secure+login+is+temporarily+unavailable.+Please+try+again.");
  }
  if (!attemptId) {
    redirect("/login?error=Too+many+attempts.+Please+wait+and+try+again.");
  }

  const supabase = await createClient();
  const { error } = await supabase.auth.signInWithPassword(parsed.data);
  if (error) {
    await finishLoginAttempt(attemptId, false, "invalid_credentials");
    redirect("/login?error=Invalid+email+or+password.");
  }
  await finishLoginAttempt(attemptId, true, "success");
  redirect("/dashboard");
}

export async function signOut() {
  const supabase = await createClient();
  await supabase.auth.signOut({ scope: "local" });
  redirect("/login");
}
