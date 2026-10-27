import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import vm from "node:vm";
import ts from "typescript";
import * as zod from "zod";
import * as jsxRuntime from "react/jsx-runtime";
import { renderToStaticMarkup } from "react-dom/server";

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
  const forwarded = [];
  let createdResponses = 0;
  let sessionReads = 0;
  const exports = {};
  vm.runInNewContext(outputText, {
    exports,
    Headers,
    Object,
    process: { env: {
      NEXT_PUBLIC_SUPABASE_URL: "https://example.invalid",
      NEXT_PUBLIC_SUPABASE_ANON_KEY: "fixture-public-key",
    } },
    require(name) {
      if (name === "next/server") return { NextResponse: { next(init) {
        createdResponses++;
        forwarded.push(init?.request?.headers);
        return {
          headers: new Headers(),
          cookies: { set: (key, value) => responseCookies.set(key, value) },
        };
      } } };
      if (name === "@supabase/ssr") return { createServerClient(_url, _key, options) {
        return { auth: {
          async getUser() { throw new Error("middleware must not call GoTrue getUser on every request"); },
          async getSession() {
            sessionReads++;
            if (refresh) options.cookies.setAll([
              { name: "fixture-auth", value: "refreshed", options: {} },
            ]);
            return { data: { session: null } };
          },
        } };
      } };
      throw new Error(`Unexpected dependency: ${name}`);
    },
  });
  const response = await exports.updateSession({
    headers: new Headers({ cookie: "a=b" }),
    cookies: {
      getAll: () => [],
      set: (key, value) => requestCookies.set(key, value),
    },
  }, { "x-nonce": "fixture-nonce" });
  assert.equal(response.headers.get("cache-control"), "private, no-store, max-age=0");
  assert.equal(response.headers.get("pragma"), "no-cache");
  assert.equal(response.headers.get("expires"), "0");
  assert.equal(sessionReads, 1);
  assert.equal(createdResponses, refresh ? 2 : 1);
  for (const headers of forwarded) assert.equal(headers.get("x-nonce"), "fixture-nonce", "nonce survives a cookie refresh");
  assert.equal(responseCookies.get("fixture-auth"), refresh ? "refreshed" : undefined);
  assert.equal(requestCookies.get("fixture-auth"), refresh ? "refreshed" : undefined);
}

const routes = readFileSync(new URL("../src/middleware.ts", import.meta.url), "utf8");
assert.ok(routes.includes('"/((?!_next/static|_next/image|favicon.ico|fonts/).*)"'), "every document needs the session + nonce middleware");
assert.ok(routes.includes("Content-Security-Policy") && routes.includes("content-security-policy"), "CSP is sent to the browser and to Next for nonce stamping");

const cspCode = ts.transpileModule(readFileSync(new URL("../src/lib/csp.ts", import.meta.url), "utf8"), {
  compilerOptions: { module: ts.ModuleKind.CommonJS },
}).outputText;
const cspExports = {};
vm.runInNewContext(cspCode, { exports: cspExports, crypto: globalThis.crypto, btoa, Uint8Array, String, URL, process: { env: { NEXT_PUBLIC_SUPABASE_URL: "https://example.supabase.co" } } });
const nonce = cspExports.createNonce();
assert.notEqual(nonce, cspExports.createNonce(), "nonce is unique per request");
const policy = cspExports.buildContentSecurityPolicy(nonce, false);
for (const directive of ["default-src 'self'", "script-src 'self'", "style-src 'self'", "frame-ancestors 'none'", "object-src 'none'", "base-uri 'none'", "form-action 'self'"]) {
  assert.ok(policy.includes(directive), `CSP keeps ${directive}`);
}
assert.ok(policy.includes(`'nonce-${nonce}'`) && !policy.includes("unsafe-inline") && !policy.includes("unsafe-eval"));
console.log("PASS: private cache headers and the CSP nonce survive auth-cookie refresh; middleware skips GoTrue; every document is covered.");

const liveSource = readFileSync(new URL("../src/app/api/live/route.ts", import.meta.url), "utf8");
const liveCode = ts.transpileModule(liveSource, {
  compilerOptions: { module: ts.ModuleKind.CommonJS },
}).outputText;
let liveRpcCalls = 0;
for (const scenario of ["success", "server-error", "forbidden", "signed-out"]) {
  const exports = {};
  vm.runInNewContext(liveCode, { exports, require(name) {
    if (name === "next/server") return { NextResponse: { json: (body, options) => ({ body, ...options }) } };
    if (name === "@/lib/supabase/server") return { createClient: async () => ({
      auth: {
        getSession: async () => ({ data: { session: scenario === "signed-out" ? null : { access_token: "fixture" } } }),
        getUser: async () => { throw new Error("the live feed must not add a GoTrue round trip"); },
      },
      from: () => { throw new Error("the live feed must not re-read memberships"); },
      rpc: async (rpc, args) => {
        liveRpcCalls++;
        assert.equal(rpc, "admin_dashboard_overview");
        assert.equal(args.p_online_limit, 12);
        if (scenario === "server-error") return { error: { code: "XX000", message: "sensitive database diagnostic fixture" } };
        if (scenario === "forbidden") return { error: { code: "42501", message: "staff_authorization_required" } };
        return { data: { live: { ready: true }, onlineUsers: [] } };
      },
    }) };
    throw new Error(`Unexpected dependency: ${name}`);
  } });
  const response = await exports.GET();
  if (scenario === "signed-out") {
    assert.equal(response.status, 401);
  } else if (scenario === "server-error") {
    assert.equal(response.status, 500);
    assert.equal(response.body.error, "Live operations are temporarily unavailable.");
  } else if (scenario === "forbidden") {
    assert.equal(response.status, 403);
  } else {
    assert.equal(response.body.live.ready, true);
    assert.equal(response.body.onlineUsers.length, 0);
    assert.equal(response.headers["Cache-Control"], "no-store");
  }
}
assert.equal(liveRpcCalls, 3, "one RPC per live refresh, none when signed out");
console.log("PASS: live feed costs one RPC, hides backend diagnostics, and maps staff refusals to 403.");

const accessCode = ts.transpileModule(readFileSync(new URL("../src/lib/access.ts", import.meta.url), "utf8"), {
  compilerOptions: { module: ts.ModuleKind.CommonJS },
}).outputText;
const access = {};
vm.runInNewContext(accessCode, { exports: access });
const actionCode = ts.transpileModule(readFileSync(
  new URL("../src/app/(staff)/actions.ts", import.meta.url), "utf8",
), { compilerOptions: { module: ts.ModuleKind.CommonJS } }).outputText;
for (const scenario of ["rpc-error", "auth-error", "invalid-form", "success", "redirect", "role-denied", "member-page", "path-escape"]) {
  const exports = {};
  const revalidated = [];
  let writes = 0;
  const redirect = (url) => { throw Object.assign(new Error(url), { digest: "NEXT_REDIRECT", url }); };
  vm.runInNewContext(actionCode, { exports, URL, URLSearchParams, require(name) {
    if (name === "zod") return zod;
    if (name === "next/navigation") return { redirect };
    if (name === "next/cache") return { revalidatePath: (path) => revalidated.push(path) };
    if (name === "@/lib/auth") return { requireAdmin: async () => {
      if (scenario === "redirect") redirect("/login");
      if (scenario === "auth-error") throw new Error("private_table secret@example.invalid");
      return { role: scenario === "role-denied" ? "support" : "super_admin" };
    } };
    if (name === "@/lib/access") return access;
    if (name === "@/lib/supabase/admin") return {};
    if (name === "@/lib/supabase/server") return { createClient: async () => ({ rpc: async () => {
      writes++;
      return { error: scenario === "rpc-error" ? { message: "private_table secret@example.invalid" } : null };
    } }) };
    throw new Error(`Unexpected dependency: ${name}`);
  } });
  const form = new FormData();
  form.set("userId", "11111111-1111-4111-8111-111111111111");
  form.set("action", "suspend");
  if (scenario === "invalid-form") form.set("reason", "x".repeat(501));
  form.set("returnTo", scenario === "member-page"
    ? "/users/11111111-1111-4111-8111-111111111111?report=r1"
    : scenario === "path-escape" ? "/users/../dashboard?x=1" : "/users?q=kept&admin_error=stale");
  await assert.rejects(exports.accountAction(form), (error) => {
    assert.equal(error.digest, "NEXT_REDIRECT");
    const url = new URL(error.url, "https://admin.example.invalid");
    assert.ok(!error.url.includes("private_table") && !error.url.includes("secret"));
    if (scenario === "redirect") assert.equal(url.pathname, "/login");
    else if (scenario === "success") {
      assert.equal(url.searchParams.get("admin_success"), "Member updated.");
      assert.equal(url.searchParams.get("q"), "kept", "the operator's search survives the decision");
      assert.equal(url.searchParams.get("admin_error"), null, "stale notices are dropped");
    }
    else if (scenario === "member-page") {
      assert.equal(url.pathname, "/users/11111111-1111-4111-8111-111111111111", "a decision on a review page returns to it");
      assert.equal(url.searchParams.get("report"), "r1");
    }
    else if (scenario === "path-escape") {
      assert.equal(url.pathname, "/users", "dot segments cannot leave the action's own page");
      assert.equal(url.searchParams.get("x"), null);
    }
    else if (scenario === "role-denied") assert.equal(url.searchParams.get("admin_error"), "Your staff role cannot perform this action.");
    else if (scenario === "invalid-form") assert.match(url.searchParams.get("admin_error"), /500/);
    else assert.equal(url.searchParams.get("admin_error"), "The action could not be completed. Refresh and try again.");
    return true;
  });
  const succeeded = ["success", "member-page", "path-escape"].includes(scenario);
  assert.equal(writes, scenario === "rpc-error" || succeeded ? 1 : 0);
  assert.deepEqual(revalidated, succeeded ? ["/users"] : []);
}
console.log("PASS: staff failures hide backend diagnostics; validation, authorization, redirects and success are preserved.");

const errorCode = ts.transpileModule(readFileSync(
  new URL("../src/app/error.tsx", import.meta.url), "utf8",
), { compilerOptions: { module: ts.ModuleKind.CommonJS, jsx: ts.JsxEmit.ReactJSX } }).outputText;
const errorExports = {};
vm.runInNewContext(errorCode, { exports: errorExports, require(name) {
  if (name === "react/jsx-runtime") return jsxRuntime;
  if (name === "lucide-react") return { ShieldAlert: () => null };
  throw new Error(`Unexpected dependency: ${name}`);
} });
const errorHtml = renderToStaticMarkup(errorExports.default({
  error: Object.assign(new Error("private_table secret@example.invalid"), { digest: "fixture-digest" }),
  reset() {},
}));
assert.ok(!errorHtml.includes("private_table") && !errorHtml.includes("secret@example.invalid"));
assert.ok(errorHtml.includes("fixture-digest") && errorHtml.includes("Retry"));
console.log("PASS: rendered error boundary hides raw diagnostics and preserves support digest/retry.");
