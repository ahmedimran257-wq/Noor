// Next.js hydrates through inline <script> tags. A plain `script-src 'self'`
// blocked every one of them, so the console never became interactive and each
// click was a full document reload. A per-request nonce keeps the policy
// strict (no 'unsafe-inline') while letting Next's own scripts run.
export function buildContentSecurityPolicy(nonce: string, isDev = process.env.NODE_ENV !== "production") {
  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL ?? "https://*.supabase.co";
  let supabaseOrigin = "https://*.supabase.co";
  try {
    supabaseOrigin = new URL(supabaseUrl).origin;
  } catch {
    // Keep the wildcard fallback.
  }

  return [
    "default-src 'self'",
    `script-src 'self' 'nonce-${nonce}'${isDev ? " 'unsafe-eval'" : ""}`,
    `style-src 'self' 'nonce-${nonce}'`,
    `img-src 'self' data: blob: ${supabaseOrigin}`,
    "font-src 'self'",
    `connect-src 'self' ${supabaseOrigin}`,
    "frame-ancestors 'none'",
    "object-src 'none'",
    "base-uri 'none'",
    "form-action 'self'",
  ].join("; ");
}

export function createNonce() {
  const bytes = new Uint8Array(16);
  crypto.getRandomValues(bytes);
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary);
}
