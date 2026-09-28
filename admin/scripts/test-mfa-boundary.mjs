import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import * as crypto from "node:crypto";
import vm from "node:vm";
import ts from "typescript";
import * as zod from "zod";
import * as jsxRuntime from "react/jsx-runtime";
import { renderToStaticMarkup } from "react-dom/server";
import { ResponseCookies } from "next/dist/compiled/@edge-runtime/cookies/index.js";

const userId = "11111111-1111-4111-8111-111111111111";
const oldFactor = "22222222-2222-4222-8222-222222222222";
const newFactor = "33333333-3333-4333-8333-333333333333";
const compile = (path) => ts.transpileModule(readFileSync(new URL(path, import.meta.url), "utf8"), {
  compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022, jsx: ts.JsxEmit.ReactJSX },
}).outputText;
const authCode = compile("../src/lib/auth.ts");
const mfaCode = compile("../src/app/(auth)/mfa/actions.ts");
const componentCode = compile("../src/components/mfa-enrollment.tsx");

function fixture({ expired = false, aal = "aal2", badCode = false } = {}) {
  const calls = [];
  const cookies = new ResponseCookies(new Headers());
  const user = { id: userId, email: "staff@example.invalid" };
  const client = {
    auth: {
      getUser: async () => ({ data: { user } }),
      getSession: async () => ({ data: { session: { access_token: `fixture.${Buffer.from(JSON.stringify({ session_id: userId })).toString("base64url")}.fixture` } } }),
      signOut: async () => { calls.push("signOut"); },
      mfa: {
        listFactors: async () => { calls.push("list"); return { data: { totp: [{ id: oldFactor, status: "verified" }] } }; },
        getAuthenticatorAssuranceLevel: async () => ({ data: { currentLevel: aal } }),
        enroll: async () => { calls.push("enroll"); return { data: { id: newFactor, totp: { uri: "otpauth://totp/fixture?secret=TESTONLY" } } }; },
        challenge: async () => { calls.push("challenge"); return { data: { id: oldFactor } }; },
        verify: async () => { calls.push("verify"); return { error: badCode ? { message: "invalid" } : null }; },
      },
    },
    rpc: async (name) => { assert.equal(name, "assert_admin_session_boundary"); calls.push("boundary"); return { data: !expired }; },
    from: () => ({ select() { return this; }, eq() { return this; }, maybeSingle: async () => ({ data: { role: "super_admin", mfa_required: true } }) }),
  };
  const authExports = {};
  const exports = {};
  const context = {
    Buffer, setTimeout, clearTimeout, process: { env: { ADMIN_MFA_COOKIE_SECRET: "fixture-only-signing-key", NODE_ENV: "production" } },
    require(name) {
      if (name === "server-only") return {};
      if (name === "node:crypto") return crypto;
      if (name === "zod") return zod;
      if (name === "next/headers") return { cookies: async () => cookies };
      if (name === "next/navigation") return { redirect: (url) => { throw Object.assign(new Error(url), { digest: "NEXT_REDIRECT", url }); } };
      if (name === "@/lib/auth") return authExports;
      if (name === "@/lib/supabase/server") return { createClient: async () => client };
      if (name === "@/lib/supabase/admin") return { createAdminClient: () => ({ auth: { admin: { mfa: { deleteFactor: async (args) => {
        assert.equal(args.id, oldFactor);
        assert.equal(args.userId, userId);
        calls.push("deleteOld");
        return { error: null };
      } } } } }) };
      throw new Error(`Unexpected dependency: ${name}`);
    },
  };
  vm.runInNewContext(authCode, { ...context, exports: authExports });
  vm.runInNewContext(mfaCode, { ...context, exports });
  return { exports, calls, cookies };
}

const form = (factorId = oldFactor) => {
  const data = new FormData();
  data.set("factorId", factorId);
  data.set("code", "123456");
  return data;
};
const redirectsTo = (promise, path) => assert.rejects(promise, (error) => {
  assert.equal(error.url, path);
  return true;
});

for (const [method, error] of [["enrollAuthenticatorForm", "setup"], ["replaceAuthenticatorForm", "replace"], ["verifyAuthenticatorForm", "verify"]]) {
  const f = fixture({ expired: true });
  const input = form();
  input.set("password", "old-unused-field");
  await redirectsTo(f.exports[method](input), `/mfa?error=${error}`);
  assert.deepEqual(f.calls, ["boundary", "signOut"], `${method} must stop before factor operations`);
}
const expiredRead = fixture({ expired: true });
assert.equal(await expiredRead.exports.getVerifiedMfaFactorId(), undefined);
assert.deepEqual(expiredRead.calls, ["boundary", "signOut"]);

const aal1 = fixture({ aal: "aal1" });
await redirectsTo(aal1.exports.replaceAuthenticatorForm(form()), "/mfa?error=replace");
assert.deepEqual(aal1.calls, ["boundary"]);
await redirectsTo(aal1.exports.enrollAuthenticatorForm(), "/mfa");
assert.ok(aal1.calls.includes("enroll"), "fresh staff may enroll their first factor");

for (const badCode of [false, true]) {
  const f = fixture({ badCode });
  await redirectsTo(f.exports.replaceAuthenticatorForm(form()), "/mfa");
  assert.deepEqual(f.calls, ["boundary", "enroll"]);
  const pending = f.cookies.get("silarah_admin_pending_mfa");
  assert.equal(pending.httpOnly, true);
  assert.equal(pending.secure, true);
  assert.equal(pending.sameSite, "strict");
  assert.equal((await f.exports.getPendingMfaFactor(userId)).previousFactorId, oldFactor);
  assert.equal(await f.exports.getPendingMfaFactor(oldFactor), undefined, "cookie is bound to its owner");
  await redirectsTo(f.exports.verifyAuthenticatorForm(form(newFactor)), badCode ? "/mfa?error=verify" : "/dashboard");
  assert.equal(f.calls.includes("deleteOld"), !badCode);
  if (!badCode) {
    assert.ok(f.calls.indexOf("deleteOld") > f.calls.indexOf("verify"));
    const cleared = f.cookies.get("silarah_admin_pending_mfa");
    assert.equal(cleared.path, "/mfa", "expire the cookie at its actual path");
    assert.equal(cleared.value, "");
    assert.equal(cleared.expires.getTime(), 0);
  }
}

const component = {};
vm.runInNewContext(componentCode, { exports: component, require(name) {
  if (name === "react/jsx-runtime") return jsxRuntime;
  if (name === "qrcode.react") return { QRCodeSVG: () => null };
  if (name.endsWith("/actions")) return {};
  throw new Error(`Unexpected dependency: ${name}`);
} });
const html = renderToStaticMarkup(component.MfaEnrollment({ initialFactorId: oldFactor, error: "replace" }));
assert.ok(!html.includes('type="password"') && !html.includes("Confirm your password"));
assert.ok(html.includes("another super administrator"));
console.log("PASS: MFA actions enforce staff session expiry, require AAL2 for replacement, preserve first enrollment and retire old factors only after successful verification; recovery copy is accurate.");
