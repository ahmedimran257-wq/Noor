import "server-only";

import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";

export type AdminRole = "super_admin" | "moderator" | "support";

export type CurrentAdmin = {
  id: string;
  email: string;
  role: AdminRole;
  mfaRequired: boolean;
};

export async function requireStaffSession(): Promise<CurrentAdmin> {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect("/login");

  const lastSignIn = user.last_sign_in_at ? new Date(user.last_sign_in_at).getTime() : Date.now();
  const maxSessionMs = 12 * 60 * 60 * 1000;
  if (Date.now() - lastSignIn > maxSessionMs) {
    await supabase.auth.signOut();
    redirect("/login?error=Session+expired.+Please+sign+in+again.");
  }

  const { data: membership } = await supabase
    .from("admin_memberships")
    .select("role, mfa_required")
    .eq("user_id", user.id)
    .eq("status", "active")
    .maybeSingle();

  if (!membership) redirect("/unauthorized");

  return {
    id: user.id,
    email: user.email ?? "Staff account",
    role: membership.role as AdminRole,
    mfaRequired: membership.mfa_required,
  };
}

export async function requireAdmin(): Promise<CurrentAdmin> {
  const admin = await requireStaffSession();
  if (admin.mfaRequired) {
    const supabase = await createClient();
    const { data: factors } = await supabase.auth.mfa.listFactors();
    const hasTotp = (factors?.totp ?? []).some(
      (factor) => factor.status === "verified",
    );
    const { data: assurance } =
      await supabase.auth.mfa.getAuthenticatorAssuranceLevel();
    if (!hasTotp || assurance?.currentLevel !== "aal2") redirect("/mfa");
  }

  return admin;
}
