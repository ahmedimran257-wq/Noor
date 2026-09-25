import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import vm from "node:vm";
import ts from "typescript";

// Execute the real middleware with only its network/framework edges mocked.
const source = readFileSync(
  new URL("../src/lib/supabase/middleware.ts", import.meta.url), "utf8",
);
const { outputText } = ts.transpileModule(source, {
  compilerOptions: { module: ts.ModuleKind.CommonJS },
});

for (const refresh of [false, true]) {
  const responseCookies = new Map();
  const requestCookies = new Map();
  let createdResponses = 0;
  const exports = {};
  vm.runInNewContext(outputText, {
    exports,
    process: { env: {
      NEXT_PUBLIC_SUPABASE_URL: "https://example.invalid",
      NEXT_PUBLIC_SUPABASE_ANON_KEY: "fixture-public-key",
    } },
    require(name) {
      if (name === "next/server") return { NextResponse: { next() {
        createdResponses++;
        return {
          headers: new Headers(),
          cookies: { set: (key, value) => responseCookies.set(key, value) },
        };
      } } };
      if (name === "@supabase/ssr") return { createServerClient(_url, _key, options) {
        return { auth: { async getUser() {
          if (refresh) options.cookies.setAll([
            { name: "fixture-auth", value: "refreshed", options: {} },
          ]);
          return { data: { user: null } };
        } } };
      } };
      throw new Error(`Unexpected dependency: ${name}`);
    },
  });
  const response = await exports.updateSession({ cookies: {
    getAll: () => [],
    set: (key, value) => requestCookies.set(key, value),
  } });
  assert.equal(response.headers.get("cache-control"), "private, no-store, max-age=0");
  assert.equal(response.headers.get("pragma"), "no-cache");
  assert.equal(response.headers.get("expires"), "0");
  assert.equal(createdResponses, refresh ? 2 : 1);
  assert.equal(responseCookies.get("fixture-auth"), refresh ? "refreshed" : undefined);
  assert.equal(requestCookies.get("fixture-auth"), refresh ? "refreshed" : undefined);
}

const routes = readFileSync(new URL("../src/middleware.ts", import.meta.url), "utf8");
for (const route of ["/login/:path*", "/privacy/:path*", "/mfa/:path*", "/api/:path*"]) {
  assert.ok(routes.includes(JSON.stringify(route)), `${route} needs the session middleware`);
}
console.log("PASS: private cache headers survive auth-cookie refresh; auth/privacy/API routes covered.");
