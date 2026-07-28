import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";
import { readResponseJson } from "../_shared/bounded_response.ts";
import {
  consumeDistributedRateLimit,
  rateLimitHeaders,
} from "../_shared/distributed_rate_limit.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const PHOTON_URL = "https://photon.komoot.io/api";
const TIMEOUT_MS = 6_000;
const MAX_RESPONSE_BYTES = 512 * 1024;

type SearchPayload = {
  query?: unknown;
  country_code?: unknown;
  mode?: unknown;
  limit?: unknown;
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  const correlationId = crypto.randomUUID();
  try {
    if (req.method !== "POST") {
      return json(405, { error: "method_not_allowed" });
    }
    const authHeader = req.headers.get("Authorization") ?? "";
    if (!authHeader.startsWith("Bearer ")) {
      return json(401, { error: "unauthorized" });
    }

    const admin = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY, {
      auth: { autoRefreshToken: false, persistSession: false },
    });
    const { data: authData, error: authError } = await admin.auth.getUser(
      authHeader.slice("Bearer ".length),
    );
    const userId = authData.user?.id;
    if (authError || !userId) return json(401, { error: "unauthorized" });

    const payload = await req.json() as SearchPayload;
    const query = String(payload.query ?? "").trim();
    const countryCode = String(payload.country_code ?? "").trim().toUpperCase();
    const mode = payload.mode === "region" ? "region" : "city";
    const limit = Math.min(Math.max(Number(payload.limit) || 10, 1), 15);
    if (
      query.length < 2 || query.length > 80 ||
      !/^[A-Z]{2}$/.test(countryCode)
    ) {
      return json(400, { error: "invalid_location_query" });
    }

    const rateLimit = await consumeDistributedRateLimit(admin, {
      scope: "location_search",
      subject: userId,
      maxRequests: 60,
      windowSeconds: 60,
    });
    if (!rateLimit.allowed) {
      return new Response(
        JSON.stringify({ error: "location_search_limited" }),
        {
          status: 429,
          headers: {
            ...corsHeaders,
            ...rateLimitHeaders(rateLimit),
            "Content-Type": "application/json",
            "Cache-Control": "no-store",
          },
        },
      );
    }

    const url = new URL(PHOTON_URL);
    url.searchParams.set("q", query);
    url.searchParams.set("limit", String(limit));
    if (mode === "region") url.searchParams.append("osm_tag", "place:state");

    const response = await fetch(url, {
      headers: {
        "Accept": "application/json",
        "User-Agent": "Silarah/1.0 (contact@silarah.com)",
      },
      signal: AbortSignal.timeout(TIMEOUT_MS),
    });
    if (!response.ok) {
      console.warn(
        `[location-search] ${correlationId} provider_status=${response.status}`,
      );
      return json(response.status === 429 ? 503 : 502, {
        error: "location_provider_unavailable",
        correlation_id: correlationId,
      });
    }

    const data = await readResponseJson(response, MAX_RESPONSE_BYTES) as {
      features?: unknown[];
    };
    const features = Array.isArray(data.features)
      ? data.features.slice(0, limit)
      : [];
    return json(200, { features });
  } catch (error) {
    const code = error instanceof DOMException && error.name === "TimeoutError"
      ? "location_provider_timeout"
      : "location_search_failed";
    console.error(`[location-search] ${correlationId} ${code}`);
    return json(503, { error: code, correlation_id: correlationId });
  }
});

function json(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
      "Cache-Control": status === 200 ? "private, max-age=300" : "no-store",
    },
  });
}
