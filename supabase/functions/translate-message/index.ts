// ============================================================
// EDGE FUNCTION: translate-message
// supabase/functions/translate-message/index.ts
//
// Performs server-side translation for messages in Silarah.
// Keyless translation using MyMemory API.
// ============================================================

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, handleCors } from "../_shared/cors.ts";
import { readResponseJson } from "../_shared/bounded_response.ts";
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

    const { message_id, target_lang } = await req.json() as {
      message_id?: string;
      target_lang?: string;
    };

    if (
      !message_id ||
      !/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
        .test(message_id)
    ) {
      return errorResponse(400, "invalid_message");
    }
    const allowedLocales = new Set([
      "en",
      "ar",
      "ur",
      "hi",
      "bn",
      "tr",
      "fr",
      "de",
      "es",
      "id",
      "ms",
    ]);
    if (!target_lang || !allowedLocales.has(target_lang)) {
      return errorResponse(400, "unsupported_locale");
    }

    const { data: message, error: messageError } = await userClient
      .from("messages")
      .select("id, content, translations")
      .eq("id", message_id)
      .maybeSingle();
    if (messageError || !message) {
      return errorResponse(404, "message_unavailable");
    }
    const existing = message.translations?.[target_lang];
    if (typeof existing === "string" && existing.length > 0) {
      return new Response(JSON.stringify({ translated_text: existing }), {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }
    const text = String(message.content ?? "").trim();
    if (text.length < 1 || text.length > 2000) {
      return errorResponse(400, "message_length_unsupported");
    }

    const langPair = `autodetect|${target_lang}`;
    const uri = new URL("https://api.mymemory.translated.net/get");
    uri.searchParams.set("q", text);
    uri.searchParams.set("langpair", langPair);

    const response = await fetch(uri.toString(), {
      headers: {
        "User-Agent": "SilarahApp/1.0 (contact@silarah.com; matrimonial app)",
      },
      signal: AbortSignal.timeout(8_000),
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

    const data = await readResponseJson(
      response,
      64 * 1024,
    ) as Record<string, unknown>;
    const responseData = data.responseData as Record<string, unknown> | null;
    const translatedText = responseData?.translatedText;
    if (typeof translatedText !== "string" || translatedText.length > 4000) {
      return errorResponse(
        502,
        "Downstream service returned invalid response format.",
      );
    }

    const { data: translations, error: storeError } = await userClient.rpc(
      "store_message_translation",
      {
        p_message_id: message_id,
        p_target_lang: target_lang,
        p_translation: translatedText,
      },
    );
    if (storeError || !translations) {
      console.error("[translate-message] translation persistence failed", {
        code: storeError?.code,
      });
      return errorResponse(503, "translation_store_failed");
    }

    return new Response(
      JSON.stringify({ translated_text: translatedText }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  } catch (err) {
    const correlationId = crypto.randomUUID();
    console.error("[translate-message] request failed", {
      correlationId,
      error: err instanceof Error ? err.name : "unknown",
    });
    return errorResponse(500, "translation_unavailable", correlationId);
  }
});

function errorResponse(
  status: number,
  message: string,
  correlationId?: string,
): Response {
  return new Response(
    JSON.stringify({ error: message, correlation_id: correlationId }),
    { status, headers: { ...corsHeaders, "Content-Type": "application/json" } },
  );
}
