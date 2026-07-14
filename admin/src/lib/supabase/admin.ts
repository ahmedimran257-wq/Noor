import "server-only";

import { createClient } from "@supabase/supabase-js";

export function createAdminClient() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

  if (!url || !serviceRoleKey) {
    const missing = [
      ["NEXT_PUBLIC_SUPABASE_URL", url],
      ["SUPABASE_SERVICE_ROLE_KEY", serviceRoleKey],
    ]
      .filter(([, value]) => !value)
      .map(([name]) => name);
    throw new Error(
      `Silarah Admin is missing required server env: ${missing.join(", ")}. ` +
        "Set them in admin/.env.local and restart the admin dev server.",
    );
  }

  return createClient(url, serviceRoleKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
  });
}

export function createOptionalAdminClient() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

  if (!url || !serviceRoleKey) return null;

  return createClient(url, serviceRoleKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
  });
}
