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

const secretSalt = process.env.ADMIN_LOGIN_HASH_SALT ?? process.env.SUPABASE_SERVICE_ROLE_KEY ?? "mithaq-admin";

function hashValue(value: string) {
  return createHash("sha256").update(`${secretSalt}:${value.toLowerCase().trim()}`).digest("hex");
}

async function requestIp() {
  const headerStore = await headers();
  return (
    headerStore.get("x-forwarded-for")?.split(",")[0]?.trim() ||
    headerStore.get("x-real-ip") ||
    "local"
  );
}

async function loginBlocked(emailHash: string, ipHash: string) {
  const adminClient = createOptionalAdminClient();
  if (!adminClient) return false;
  const cutoff = new Date(Date.now() - 15 * 60 * 1000).toISOString();
  const { count, error } = await adminClient
    .from("admin_login_attempts")
    .select("id", { count: "exact", head: true })
    .eq("success", false)
    .gte("created_at", cutoff)
    .or(`email_hash.eq.${emailHash},ip_hash.eq.${ipHash}`);
  if (error) return false;
  return (count ?? 0) >= 8;
}

async function recordLoginAttempt(emailHash: string, ipHash: string, success: boolean, reason: string) {
  const adminClient = createOptionalAdminClient();
  if (!adminClient) return;
  await adminClient.from("admin_login_attempts").insert({
    email_hash: emailHash,
    ip_hash: ipHash,
    success,
    reason,
  });
}

export async function signIn(formData: FormData) {
  const parsed = credentialsSchema.safeParse({
    email: formData.get("email"),
    password: formData.get("password"),
  });
  if (!parsed.success) redirect("/login?error=Enter+a+valid+email+and+password.");

  const emailHash = hashValue(parsed.data.email);
  const ipHash = hashValue(await requestIp());
  if (await loginBlocked(emailHash, ipHash)) {
    await recordLoginAttempt(emailHash, ipHash, false, "rate_limited");
    redirect("/login?error=Too+many+attempts.+Please+wait+and+try+again.");
  }

  const supabase = await createClient();
  const { error } = await supabase.auth.signInWithPassword(parsed.data);
  if (error) {
    await recordLoginAttempt(emailHash, ipHash, false, "invalid_credentials");
    redirect("/login?error=Invalid+email+or+password.");
  }
  await recordLoginAttempt(emailHash, ipHash, true, "success");
  redirect("/dashboard");
}

export async function signOut() {
  const supabase = await createClient();
  await supabase.auth.signOut({ scope: "local" });
  redirect("/login");
}
