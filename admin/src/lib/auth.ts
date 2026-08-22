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

  const { data: { session } } = await supabase.auth.getSession();
  const tokenPayload = session?.access_token
    ? decodeJwtPayload(session.access_token)
    : undefined;
  const sessionId = tokenPayload?.session_id;
  const { data: sessionAllowed, error: sessionBoundaryError } = sessionId
    ? await supabase.rpc("assert_admin_session_boundary", {
        p_session_id: sessionId,
      })
    : { data: false, error: null };
  if (sessionBoundaryError || sessionAllowed !== true) {
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

function decodeJwtPayload(token: string): { session_id?: string } | undefined {
  try {
    const payload = token.split(".")[1];
    if (!payload) return undefined;
    return JSON.parse(
      Buffer.from(payload.replace(/-/g, "+").replace(/_/g, "/"), "base64")
        .toString("utf8"),
    ) as { session_id?: string };
  } catch {
    return undefined;
  }
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
