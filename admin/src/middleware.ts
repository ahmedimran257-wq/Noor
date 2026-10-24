import type { NextRequest } from "next/server";

import { buildContentSecurityPolicy, createNonce } from "@/lib/csp";
import { updateSession } from "@/lib/supabase/middleware";

// Cloudflare Workers require the Edge middleware runtime. Next 16's newer
// proxy.ts convention is Node-only and cannot be bundled by OpenNext.
export async function middleware(request: NextRequest) {
  const nonce = createNonce();
  const csp = buildContentSecurityPolicy(nonce);
  const response = await updateSession(request, {
    "x-nonce": nonce,
    // Next reads the nonce from the request CSP and stamps it on its scripts.
    "content-security-policy": csp,
  });
  response.headers.set("Content-Security-Policy", csp);
  return response;
}

export const config = {
  // Every document needs a fresh nonce; hashed static assets keep the static
  // policy from next.config.mjs.
  matcher: ["/((?!_next/static|_next/image|favicon.ico|fonts/).*)"],
};
