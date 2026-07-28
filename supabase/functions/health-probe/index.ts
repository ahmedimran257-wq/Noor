import { corsHeaders } from "../_shared/cors.ts";

Deno.serve((req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "GET" && req.method !== "HEAD") {
    return new Response(null, { status: 405, headers: corsHeaders });
  }
  return new Response(
    req.method === "HEAD"
      ? null
      : JSON.stringify({ status: "ok", service: "silarah" }),
    {
      status: 200,
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json",
        "Cache-Control": "no-store",
        "X-Silarah-Health": "ok",
      },
    },
  );
});
