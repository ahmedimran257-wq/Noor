// ============================================================
// EDGE FUNCTION: translate-message
// supabase/functions/translate-message/index.ts
//
// Performs server-side translation for messages in Silarah.
// Keyless translation using MyMemory API.
// ============================================================

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, handleCors } from "../_shared/cors.ts";
import {
  consumeDistributedRateLimit,
  rateLimitHeaders,
} from "../_shared/distributed_rate_limit.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

Deno.serve(async (req: Request) => {
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader?.startsWith("Bearer ")) {
      return errorResponse(401, "Missing or invalid Authorization header.");
    }
    const userToken = authHeader.replace("Bearer ", "");

    const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      global: { headers: { Authorization: `Bearer ${userToken}` } },
      auth: { autoRefreshToken: false, persistSession: false },
    });

    const { data: { user }, error: authError } = await userClient.auth
      .getUser();
    if (authError || !user) {
      return errorResponse(401, "Unauthorized.");
    }

    const admin = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY, {
      auth: { autoRefreshToken: false, persistSession: false },
    });
    const rateLimit = await consumeDistributedRateLimit(admin, {
      scope: "message_translation",
      subject: user.id,
      maxRequests: 60,
      windowSeconds: 60 * 60,
    });
    if (!rateLimit.allowed) {
      return new Response(
        JSON.stringify({
          error: "Translation limit reached. Please try again later.",
        }),
        {
          status: 429,
          headers: {
            ...corsHeaders,
            ...rateLimitHeaders(rateLimit),
            "Content-Type": "application/json",
          },
        },
      );
    }

    const { text, target_lang, source_lang } = await req.json() as {
      text?: string;
      target_lang?: string;
      source_lang?: string;
    };

    if (!text || text.trim() === "") {
      return errorResponse(
        400,
        "text parameter is required and cannot be empty.",
      );
    }
    if (!target_lang || target_lang.trim() === "") {
      return errorResponse(400, "target_lang parameter is required.");
    }

    const langPair = source_lang
      ? `${source_lang}|${target_lang}`
      : `autodetect|${target_lang}`;
    const uri = new URL("https://api.mymemory.translated.net/get");
    uri.searchParams.set("q", text);
    uri.searchParams.set("langpair", langPair);

    const response = await fetch(uri.toString(), {
      headers: {
        "User-Agent": "SilarahApp/1.0 (contact@silarah.com; matchmaking app)",
      },
    });

    if (!response.ok) {
      console.error(
        `[translate-message] API responded with status ${response.status}`,
      );
      return errorResponse(
        502,
        "Failed to get translation from downstream service.",
      );
    }

    const data = await response.json();
    const translatedText = data.responseData?.translatedText;
    if (!translatedText) {
      return errorResponse(
        502,
        "Downstream service returned invalid response format.",
      );
    }

    return new Response(
      JSON.stringify({ translated_text: translatedText }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  } catch (err) {
    console.error("[translate-message] Error:", err);
    const message = err instanceof Error
      ? err.message
      : "Internal Server Error";
    return errorResponse(500, message);
  }
});

function errorResponse(status: number, message: string): Response {
  return new Response(
    JSON.stringify({ error: message }),
    { status, headers: { ...corsHeaders, "Content-Type": "application/json" } },
  );
}
