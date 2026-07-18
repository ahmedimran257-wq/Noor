import type { NextRequest } from "next/server";

import { updateSession } from "@/lib/supabase/middleware";

// Cloudflare Workers require the Edge middleware runtime. Next 16's newer
// proxy.ts convention is Node-only and cannot be bundled by OpenNext.
export async function middleware(request: NextRequest) {
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
