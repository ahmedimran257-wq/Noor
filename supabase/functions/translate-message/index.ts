// Retired endpoint for older releases. No message reads or external requests.
import { corsHeaders } from "../_shared/cors.ts";
Deno.serve((request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  return new Response(JSON.stringify({ error: "chat_translation_removed" }), {
    status: 410,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
});
