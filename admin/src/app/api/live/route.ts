import { NextResponse } from "next/server";
import { createClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";

// One RPC per refresh. admin_dashboard_overview() enforces is_active_admin()
// (active membership, AAL2 and a live session under 12 hours) itself, so a
// separate user lookup and membership read would only repeat that check.
export async function GET() {
  const supabase = await createClient();
  const { data: { session } } = await supabase.auth.getSession();
  if (!session) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const { data, error } = await supabase.rpc("admin_dashboard_overview", {
    p_online_limit: 12,
  });
  if (error) {
    const forbidden = error.code === "42501";
    return NextResponse.json(
      { error: forbidden ? "Forbidden" : "Live operations are temporarily unavailable." },
      { status: forbidden ? 403 : 500, headers: { "Cache-Control": "no-store" } },
    );
  }

  return NextResponse.json(data, {
    headers: {
      "Cache-Control": "no-store",
    },
  });
}
