import { assertEquals } from "@std/assert";
import { corsHeaders, handleCors } from "./cors.ts";

Deno.test("private Edge Function responses are not cacheable by default", () => {
  for (const status of [200, 202, 400, 401, 403, 409, 429, 500]) {
    const response = new Response(JSON.stringify({ token: "test-only" }), {
      status,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
    assertEquals(response.headers.get("Cache-Control"), "no-store");
    assertEquals(response.headers.get("Access-Control-Allow-Origin"), "*");
  }
});

Deno.test("preflight remains supported without handling normal requests", async () => {
  const response = handleCors(
    new Request("https://example.test", { method: "OPTIONS" }),
  );
  assertEquals(response?.status, 200);
  assertEquals(response?.headers.get("Cache-Control"), "no-store");
  assertEquals(
    response?.headers.get("Access-Control-Allow-Methods"),
    "POST, OPTIONS",
  );
  assertEquals(await response?.text(), "ok");
  assertEquals(
    handleCors(new Request("https://example.test", { method: "POST" })),
    null,
  );
});

Deno.test("explicit private location caching can override the default", () => {
  const response = new Response("{}", {
    headers: { ...corsHeaders, "Cache-Control": "private, max-age=300" },
  });
  assertEquals(
    response.headers.get("Cache-Control"),
    "private, max-age=300",
  );
});
