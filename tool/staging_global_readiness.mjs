#!/usr/bin/env node

// Live, disposable verification of the staging project's global data and
// backend boundaries. This script refuses production and never creates fake
// members outside the staging project.

import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";

const KNOWN_PRODUCTION_REF = "jukpscfxzwttgtxvrbmj";
const required = [
  "STAGING_SUPABASE_URL",
  "STAGING_SUPABASE_ANON_KEY",
  "STAGING_SUPABASE_SERVICE_ROLE_KEY",
  "STAGING_PROJECT_REF",
  "PRODUCTION_PROJECT_REF",
];
for (const name of required) {
  if (!process.env[name]) throw new Error(`Missing ${name}`);
}

const env = process.env;
const baseUrl = env.STAGING_SUPABASE_URL.replace(/\/$/, "");
const stagingHost = new URL(baseUrl).hostname;
if (
  env.STAGING_PROJECT_REF === env.PRODUCTION_PROJECT_REF ||
  env.STAGING_PROJECT_REF === KNOWN_PRODUCTION_REF ||
  stagingHost !== `${env.STAGING_PROJECT_REF}.supabase.co`
) {
  throw new Error("Safety stop: global readiness may run only on staging");
}

const anon = env.STAGING_SUPABASE_ANON_KEY;
const service = env.STAGING_SUPABASE_SERVICE_ROLE_KEY;
const runId = `${Date.now()}-${Math.random().toString(36).slice(2, 9)}`;
const reportPath = resolve(
  env.STAGING_GLOBAL_REPORT_PATH ?? "build/staging-global-readiness.json",
);
const report = {
  runId,
  target: stagingHost,
  startedAt: new Date().toISOString(),
  status: "running",
  tests: [],
  externalGates: {
    devicePush: "requires a real Android and iOS FCM registration token",
    storePayments:
      "requires Play Store and App Store sandbox accounts in each pricing region",
    legalApproval:
      "requires the legal entity details and qualified counsel for each launch jurisdiction",
  },
};
const failures = [];
let fixture = null;

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function errorMessage(error) {
  return error instanceof Error ? error.message : String(error);
}

async function request(
  path,
  {
    apiKey = anon,
    token,
    method = "GET",
    body,
    prefer,
    expectedStatuses = [200],
  } = {},
) {
  const response = await fetch(`${baseUrl}${path}`, {
    method,
    headers: {
      apikey: apiKey,
      Authorization: `Bearer ${token ?? apiKey}`,
      "Content-Type": "application/json",
      ...(prefer ? { Prefer: prefer } : {}),
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await response.text();
  let data = null;
  if (text) {
    try {
      data = JSON.parse(text);
    } catch {
      data = text;
    }
  }
  if (!expectedStatuses.includes(response.status)) {
    throw new Error(
      `${method} ${path} returned ${response.status}: ${JSON.stringify(data)}`,
    );
  }
  return { status: response.status, data, headers: response.headers };
}

async function test(name, action) {
  const started = performance.now();
  try {
    const details = (await action()) ?? {};
    report.tests.push({
      name,
      status: "passed",
      durationMs: Math.round(performance.now() - started),
      ...details,
    });
    console.log(`PASS: ${name}`);
  } catch (error) {
    const failure = { name, error: errorMessage(error) };
    failures.push(failure);
    report.tests.push({
      ...failure,
      status: "failed",
      durationMs: Math.round(performance.now() - started),
    });
    console.error(`FAIL: ${name}: ${failure.error}`);
  }
}

async function createFixture() {
  const email = `global.${runId}@staging.silarah.invalid`;
  const password = `G-${crypto.randomUUID()}-aA7!`;
  const auth = await request("/auth/v1/admin/users", {
    apiKey: service,
    method: "POST",
    body: { email, password, email_confirm: true },
    expectedStatuses: [200],
  });
  fixture = { id: auth.data.id, email, password };
  await request("/rest/v1/users", {
    apiKey: service,
    method: "POST",
    prefer: "return=minimal",
    expectedStatuses: [201],
    body: {
      id: fixture.id,
      email,
      country_code: "US",
      gender: "male",
      timezone: "UTC",
      onboarding_step: 5,
      onboarding_completed: true,
    },
  });
  const session = await request("/auth/v1/token?grant_type=password", {
    method: "POST",
    body: { email, password },
  });
  fixture.token = session.data.access_token;
  assert(fixture.token, "Disposable user session was not created");
}

async function cleanupFixture() {
  if (!fixture) return;
  await request(`/rest/v1/users?id=eq.${fixture.id}`, {
    apiKey: service,
    method: "DELETE",
    prefer: "return=minimal",
    expectedStatuses: [204],
  }).catch(() => undefined);
  await request(`/auth/v1/admin/users/${fixture.id}`, {
    apiKey: service,
    method: "DELETE",
    expectedStatuses: [200],
  }).catch(() => undefined);
}

function localCountryCodes() {
  const source = readFileSync("lib/core/data/country_data.dart", "utf8");
  return [
    ...new Set(
      [...source.matchAll(/iso2:\s*'([A-Z]{2})'/g)].map((match) => match[1]),
    ),
  ].sort();
}

function verifyArbCatalog() {
  const locales = ["en", "ar", "bn", "de", "fr", "hi", "id", "ms", "tr", "ur"];
  const catalogs = Object.fromEntries(
    locales.map((locale) => {
      const data = JSON.parse(
        readFileSync(`lib/l10n/app_${locale}.arb`, "utf8"),
      );
      const keys = Object.keys(data).filter(
        (key) => !key.startsWith("@") && key !== "@@locale",
      );
      return [locale, { data, keys }];
    }),
  );
  const expected = catalogs.en.keys.sort();
  for (const locale of locales) {
    const actual = catalogs[locale].keys.sort();
    assert(
      JSON.stringify(actual) === JSON.stringify(expected),
      `${locale} ARB keys differ from English`,
    );
    for (const key of expected) {
      assert(
        typeof catalogs[locale].data[key] === "string" &&
          catalogs[locale].data[key].trim().length > 0,
        `${locale}.${key} is empty`,
      );
    }
  }
  return { locales: locales.length, translatedUiKeysPerLocale: expected.length };
}

try {
  await test("ten UI locale catalogs have complete key coverage", async () =>
    verifyArbCatalog());

  await test("all 198 app countries have complete server metadata", async () => {
    const codes = localCountryCodes();
    assert(codes.length === 198, `App catalog contains ${codes.length}, expected 198`);
    const response = await request(
      "/rest/v1/countries?select=iso_code,name,dialing_code,currency,default_lang,pricing_tier&limit=300",
      { apiKey: service },
    );
    const rows = response.data;
    assert(Array.isArray(rows), "Country response was not an array");
    const byCode = new Map(rows.map((row) => [row.iso_code, row]));
    const missing = codes.filter((code) => !byCode.has(code));
    assert(missing.length === 0, `Server is missing countries: ${missing.join(", ")}`);
    for (const code of codes) {
      const row = byCode.get(code);
      assert(row.name?.trim(), `${code} has no name`);
      assert(row.dialing_code?.trim(), `${code} has no dialing code`);
      assert(/^[A-Z]{3}$/.test(row.currency ?? ""), `${code} has invalid currency`);
      assert(row.default_lang?.trim(), `${code} has no default language`);
      assert(
        ["tier_1", "tier_2", "tier_3", "premium"].includes(row.pricing_tier),
        `${code} has invalid pricing tier`,
      );
    }
    return { appCountries: codes.length, serverCountries: rows.length };
  });

  await test("public health probe is live and branded", async () => {
    const response = await request("/functions/v1/health-probe");
    assert(response.data?.status === "ok", "Health body is not ok");
    assert(
      response.headers.get("x-silarah-health") === "ok",
      "Health header is missing",
    );
  });

  await test("protected and webhook functions reject unauthenticated calls", async () => {
    const probes = [
      ["location-search", {}, [401]],
      ["photo-verification", {}, [401]],
      ["translate-message", {}, [401]],
      ["validate-photo-upload", {}, [401]],
      ["get-signed-url", {}, [401]],
      // A missing vendor secret is a deployment blocker (503), never an auth
      // bypass. Once configured, an invalid token must return 401.
      ["revenuecat-webhook", { event: {} }, [401, 503]],
      ["dispatch-notifications", {}, [401]],
    ];
    for (const [name, body, expectedStatuses] of probes) {
      const response = await request(`/functions/v1/${name}`, {
        method: "POST",
        body,
        expectedStatuses,
      });
      assert(response.status !== 200, `${name} did not reject the request`);
    }
    return { guardedFunctions: probes.length };
  });

  await createFixture();

  await test("database workers target the current staging project", async () => {
    await request("/rest/v1/rpc/configure_backend_project_url", {
      apiKey: service,
      method: "POST",
      body: { p_url: baseUrl },
      expectedStatuses: [200, 204],
    });
    return { workerProject: env.STAGING_PROJECT_REF };
  });

  await test("global city provider returns signed results across regions", async () => {
    const samples = [
      ["New York", "US"],
      ["Delhi", "IN"],
      ["Lahore", "PK"],
      ["Istanbul", "TR"],
      ["London", "GB"],
      ["Toronto", "CA"],
      ["Cairo", "EG"],
      ["Jakarta", "ID"],
      ["Kuala Lumpur", "MY"],
      ["Sydney", "AU"],
    ];
    const resolved = [];
    for (const [query, countryCode] of samples) {
      const search = await request("/functions/v1/location-search", {
        token: fixture.token,
        method: "POST",
        body: { query, country_code: countryCode, mode: "city", limit: 15 },
      });
      const features = Array.isArray(search.data?.features)
        ? search.data.features
        : [];
      const feature = features.find(
        (candidate) =>
          candidate?.properties?.countrycode?.toUpperCase() === countryCode &&
          candidate?.silarah_resolution_token,
      );
      assert(feature, `${query}/${countryCode} returned no signed in-country result`);
      const resolution = await request("/functions/v1/location-search", {
        token: fixture.token,
        method: "POST",
        body: {
          mode: "resolve",
          resolution_token: feature.silarah_resolution_token,
        },
      });
      assert(Number.isInteger(resolution.data?.city_id), `${query} did not resolve`);
      resolved.push(countryCode);
    }
    return { samples: resolved };
  });

  await test("tokenless push queue completes as durable in-app delivery", async () => {
    const inserted = await request("/rest/v1/notifications?select=id", {
      apiKey: service,
      method: "POST",
      prefer: "return=representation",
      expectedStatuses: [201],
      body: {
        user_id: fixture.id,
        type: "profile_view",
        title: "Staging readiness",
        body: "Disposable notification delivery probe.",
        deep_link: "silarah://profile-views",
        // Avoid a client/server sub-second clock race in the statement trigger.
        scheduled_at: new Date(Date.now() - 60_000).toISOString(),
      },
    });
    const notificationId = inserted.data?.[0]?.id;
    assert(notificationId, "Notification fixture was not inserted");
    const deadline = Date.now() + 20_000;
    let row = null;
    while (Date.now() < deadline) {
      const result = await request(
        `/rest/v1/notifications?id=eq.${notificationId}&select=delivery_status,sent_at,last_error_code`,
        { apiKey: service },
      );
      row = result.data?.[0];
      if (row?.delivery_status === "in_app_only" && row?.sent_at) break;
      await new Promise((resolve) => setTimeout(resolve, 1_000));
    }
    assert(
      row?.delivery_status === "in_app_only" && row?.sent_at,
      `Notification did not complete: ${JSON.stringify(row)}`,
    );
    return { deliveryStatus: row.delivery_status };
  });
} finally {
  await cleanupFixture();
  report.finishedAt = new Date().toISOString();
  report.status = failures.length === 0 ? "passed" : "failed";
  report.failures = failures;
  mkdirSync(dirname(reportPath), { recursive: true });
  writeFileSync(reportPath, `${JSON.stringify(report, null, 2)}\n`);
  console.log(`Evidence: ${reportPath}`);
}

if (failures.length > 0) {
  throw new Error(`${failures.length} global readiness check(s) failed`);
}
