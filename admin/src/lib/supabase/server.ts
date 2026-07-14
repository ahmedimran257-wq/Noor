import "server-only";

import { createServerClient } from "@supabase/ssr";
import { cookies } from "next/headers";

function requireSupabaseBrowserEnv() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const anonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

  const missing = [
    ["NEXT_PUBLIC_SUPABASE_URL", url],
    ["NEXT_PUBLIC_SUPABASE_ANON_KEY", anonKey],
  ]
    .filter(([, value]) => !value)
    .map(([name]) => name);

  if (missing.length > 0) {
    throw new Error(
      `Silarah Admin is missing required Supabase env: ${missing.join(", ")}. ` +
        "Set them in admin/.env.local and restart the admin dev server.",
    );
  }

  return { url: url!, anonKey: anonKey! };
}

export async function createClient() {
  const cookieStore = await cookies();
  const { url, anonKey } = requireSupabaseBrowserEnv();

  return createServerClient(
    url,
    anonKey,
    {
      cookies: {
        getAll() {
          return cookieStore.getAll();
        },
        setAll(values) {
          try {
            values.forEach(({ name, value, options }) =>
              cookieStore.set(name, value, options),
            );
          } catch {
            // Middleware refreshes auth cookies for Server Components.
          }
        },
      },
    },
  );
}
