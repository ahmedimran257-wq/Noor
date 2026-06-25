import type { NextRequest } from "next/server";
import { updateSession } from "@/lib/supabase/middleware";

export async function proxy(request: NextRequest) {
  return updateSession(request);
}

export const config = {
  matcher: [
    "/dashboard/:path*",
    "/users/:path*",
    "/kyc/:path*",
    "/moderation/:path*",
    "/matches/:path*",
    "/subscriptions/:path*",
    "/campaigns/:path*",
    "/content/:path*",
    "/stories/:path*",
    "/inbox/:path*",
    "/audit/:path*",
    "/security/:path*",
    "/staff/:path*",
    "/system/:path*",
    "/mfa/:path*",
    "/api/:path*",
  ],
};
