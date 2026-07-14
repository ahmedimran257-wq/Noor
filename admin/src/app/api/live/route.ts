import { NextResponse } from "next/server";
import { createClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";

export async function GET() {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const { data: membership, error: membershipError } = await supabase
    .from("admin_memberships")
    .select("mfa_required")
    .eq("user_id", user.id)
    .eq("status", "active")
    .maybeSingle();

  if (membershipError || !membership) {
    return NextResponse.json({ error: "Forbidden" }, { status: 403 });
  }

  if (membership.mfa_required) {
    const { data: assurance } = await supabase.auth.mfa.getAuthenticatorAssuranceLevel();
    if (assurance?.currentLevel !== "aal2") {
      return NextResponse.json({ error: "MFA required" }, { status: 403 });
    }
  }

  const { data, error } = await supabase.rpc("admin_live_operations_snapshot");
  if (error) {
    return NextResponse.json({ error: error.message }, { status: 500 });
  }

  const { data: onlineUsers, error: onlineError } = await supabase.rpc(
    "admin_online_users",
    { p_limit: 25 },
  );
  if (onlineError) {
    return NextResponse.json({ error: onlineError.message }, { status: 500 });
  }

  return NextResponse.json({
    snapshot: data,
    onlineUsers: onlineUsers ?? [],
  }, {
    headers: {
      "Cache-Control": "no-store",
    },
  });
}
