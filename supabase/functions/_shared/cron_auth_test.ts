import { assertEquals } from "@std/assert";

Deno.test("cron authentication fails closed and never trusts a bearer token", async () => {
  const envNames = ["SUPABASE_URL", "SUPABASE_SERVICE_ROLE_KEY"];
  const savedEnv = envNames.map((name) => Deno.env.get(name));
  const originalFetch = globalThis.fetch;
  const secret = "fixture-only-cron-secret-with-32-characters";
  const digest = Array.from(
    new Uint8Array(
      await crypto.subtle.digest("SHA-256", new TextEncoder().encode(secret)),
    ),
  ).map((byte) => byte.toString(16).padStart(2, "0")).join("");
  let lookupCount = 0;
  let storedHash: string | null = digest;
  let databaseFailure = false;
  try {
    Deno.env.set(envNames[0], "https://cron-auth.example.invalid");
    Deno.env.set(envNames[1], "fixture-only-service-key");
    globalThis.fetch = (input, init) => {
      const request = new Request(input, init);
      const url = new URL(request.url);
      assertEquals(url.origin, "https://cron-auth.example.invalid");
      assertEquals(url.pathname, "/rest/v1/internal_cron_credentials");
      assertEquals(request.method, "GET");
      assertEquals(url.searchParams.get("select"), "secret_hash");
      assertEquals(url.searchParams.get("name"), "eq.edge_cron");
      assertEquals(request.headers.get("x-cron-secret"), null);
      lookupCount++;
      return Promise.resolve(
        databaseFailure
          ? Response.json({ message: "fixture database failure" }, {
            status: 403,
          })
          : Response.json(
            storedHash === null ? [] : [{ secret_hash: storedHash }],
          ),
      );
    };
    const { isAuthorizedCronRequest } = await import("./cron_auth.ts");
    const invoke = (headers: HeadersInit) =>
      isAuthorizedCronRequest(
        new Request("https://worker.example.invalid", {
          method: "POST",
          headers,
        }),
      );

    const rejectedHeaders: HeadersInit[] = [
      {},
      { Authorization: "Bearer fixture-only-service-key" },
      { "x-cron-secret": "short" },
    ];
    for (const headers of rejectedHeaders) {
      assertEquals(await invoke(headers), false);
    }
    assertEquals(
      lookupCount,
      0,
      "missing credentials must not reach the database",
    );
    assertEquals(
      await invoke({ "x-cron-secret": "x".repeat(secret.length) }),
      false,
    );
    assertEquals(await invoke({ "x-cron-secret": secret }), true);
    storedHash = digest.slice(0, -1) + (digest.endsWith("0") ? "1" : "0");
    assertEquals(await invoke({ "x-cron-secret": secret }), false);
    storedHash = null;
    assertEquals(await invoke({ "x-cron-secret": secret }), false);
    databaseFailure = true;
    assertEquals(await invoke({ "x-cron-secret": secret }), false);
    assertEquals(lookupCount, 5);
  } finally {
    globalThis.fetch = originalFetch;
    envNames.forEach((name, i) => {
      if (savedEnv[i] === undefined) Deno.env.delete(name);
      else Deno.env.set(name, savedEnv[i]!);
    });
  }
});
