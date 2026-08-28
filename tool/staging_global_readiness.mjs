#!/usr/bin/env node

// Live, disposable verification of the India-only staging release and backend
// boundaries. This script refuses production and never calls a worldwide city
// provider or creates synthetic members outside the staging project.

import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";

const KNOWN_PRODUCTION_REF = "jukpscfxzwttgtxvrbmj";
const FIXTURE_DOMAIN = "@staging.silarah.invalid";
const FIXTURE_METADATA_KEY = "staging_india_readiness_run";
const STALE_FIXTURE_AGE_MS = 6 * 60 * 60 * 1000;
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
  throw new Error("Safety stop: India readiness may run only on staging");
}

const anon = env.STAGING_SUPABASE_ANON_KEY;
const service = env.STAGING_SUPABASE_SERVICE_ROLE_KEY;
const runId = `${Date.now()}-${Math.random().toString(36).slice(2, 9)}`;
const reportPath = resolve(
  env.STAGING_INDIA_REPORT_PATH ??
    env.STAGING_GLOBAL_REPORT_PATH ??
    "build/staging-india-readiness.json",
);
const report = {
  runId,
  target: stagingHost,
  startedAt: new Date().toISOString(),
  status: "running",
  tests: [],
  externalGates: {
    devicePush: "requires a real Android FCM registration token",
    storePayments:
      "requires a Google Play licensed tester in the India billing region",
    legalApproval:
      "requires India release-policy and developer-identity approval",
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

function authUsers(data) {
  if (Array.isArray(data)) return data;
  return Array.isArray(data?.users) ? data.users : [];
}

function fixtureRun(user) {
  return (user?.user_metadata ?? user?.raw_user_meta_data ?? {})[
    FIXTURE_METADATA_KEY
  ];
}

async function listAuthUsers() {
  const users = [];
  for (let page = 1; page <= 20; page += 1) {
    const response = await request(
      `/auth/v1/admin/users?page=${page}&per_page=1000`,
      { apiKey: service },
    );
    const batch = authUsers(response.data);
    users.push(...batch);
    if (batch.length < 1000) return users;
  }
  throw new Error("Auth fixture scan exceeded the 20,000-user safety bound");
}

function isMarkedFixture(user) {
  return Boolean(
    user?.id &&
      user?.email?.toLowerCase().endsWith(FIXTURE_DOMAIN) &&
      fixtureRun(user),
  );
}

async function deleteMarkedFixture(user) {
  assert(isMarkedFixture(user), "Refused to delete an unmarked staging member");
  await request(`/rest/v1/users?id=eq.${user.id}`, {
    apiKey: service,
    method: "DELETE",
    prefer: "return=minimal",
    expectedStatuses: [204],
  });
  await request(`/auth/v1/admin/users/${user.id}`, {
    apiKey: service,
    method: "DELETE",
    expectedStatuses: [200],
  });
}

async function removeStaleFixtures() {
  const cutoff = Date.now() - STALE_FIXTURE_AGE_MS;
  const stale = (await listAuthUsers()).filter((user) => {
    const createdAt = Date.parse(user.created_at ?? "");
    return isMarkedFixture(user) && Number.isFinite(createdAt) && createdAt < cutoff;
  });
  for (const user of stale) await deleteMarkedFixture(user);
  const staleIds = new Set(stale.map((user) => user.id));
  const remaining = (await listAuthUsers()).filter((user) => staleIds.has(user.id));
  assert(remaining.length === 0, "Stale India-readiness fixtures remain after janitor");
  return stale.length;
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
  const email = `india-readiness.${runId}${FIXTURE_DOMAIN}`;
  const password = `G-${crypto.randomUUID()}-aA7!`;
  const auth = await request("/auth/v1/admin/users", {
    apiKey: service,
    method: "POST",
    body: {
      email,
      password,
      email_confirm: true,
      user_metadata: { [FIXTURE_METADATA_KEY]: runId },
    },
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
      country_code: "IN",
      gender: "male",
      timezone: "Asia/Kolkata",
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
  await deleteMarkedFixture({
    id: fixture.id,
    email: fixture.email,
    user_metadata: { [FIXTURE_METADATA_KEY]: runId },
  });
  const authLeft = (await listAuthUsers()).filter(
    (user) => fixtureRun(user) === runId,
  );
  const publicLeft = await request(
    `/rest/v1/users?id=eq.${fixture.id}&select=id`,
    { apiKey: service },
  );
  assert(authLeft.length === 0, "India-readiness Auth fixture was not removed");
  assert(publicLeft.data.length === 0, "India-readiness public fixture was not removed");
}

function verifyArbCatalog() {
  const locales = ["en", "ar", "bn", "de", "fr", "hi", "id", "ms", "tr", "ur"];
  const catalogs = Object.fromEntries(
    locales.map((locale) => {
      const data = JSON.parse(
        // Dart accepts a UTF-8 BOM in ARB files. Strip it so the Node release
        // gate validates the same catalogues instead of reporting a false
        // localization failure on Windows-generated files.
        readFileSync(`lib/l10n/app_${locale}.arb`, "utf8").replace(/^\uFEFF/, ""),
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
  await test("stale India-readiness fixtures are removed safely", async () => ({
    removed: await removeStaleFixtures(),
  }));

  await test("ten UI locale catalogs have complete key coverage", async () =>
    verifyArbCatalog());

  await test("India launch metadata and state catalogue are complete", async () => {
    const response = await request(
      "/rest/v1/countries?iso_code=eq.IN&select=iso_code,name,dialing_code,currency,default_lang,pricing_tier",
      { apiKey: service },
    );
    const rows = response.data;
    assert(Array.isArray(rows) && rows.length === 1, "India metadata is missing");
    const india = rows[0];
    assert(india.name === "India", "IN has an unexpected country name");
    assert(india.dialing_code === "+91", "India dialing code is not +91");
    assert(india.currency === "INR", "India currency is not INR");
    assert(india.default_lang?.trim(), "India has no default language");
    assert(india.pricing_tier?.trim(), "India has no pricing tier");
    const regions = await request(
      "/rest/v1/regions?country_code=eq.IN&select=id,name,country_code&limit=100",
      { apiKey: service },
    );
    assert(regions.data.length >= 36, `India has only ${regions.data.length} states/UTs`);
    assert(
      regions.data.every((region) => region.country_code === "IN" && region.name?.trim()),
      "India state/UT metadata is malformed",
    );
    return { launchCountry: "IN", statesAndUnionTerritories: regions.data.length };
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

  await test("cached India city metadata is usable without provider egress", async () => {
    const cities = await request(
      "/rest/v1/cities?select=id,name,region_id,latitude,longitude,regions!inner(country_code)&regions.country_code=eq.IN&limit=20",
      { apiKey: service },
    );
    assert(Array.isArray(cities.data) && cities.data.length > 0, "No cached India city exists");
    assert(
      cities.data.every((city) =>
        Number.isFinite(Number(city.latitude)) &&
        Number.isFinite(Number(city.longitude)) &&
        city.name?.trim()),
      "A cached India city is malformed",
    );
    return { cachedIndiaCitiesSampled: cities.data.length, providerCalls: 0 };
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
  try {
    await cleanupFixture();
  } catch (error) {
    failures.push({ name: "strict fixture cleanup", error: errorMessage(error) });
  }
  report.finishedAt = new Date().toISOString();
  report.status = failures.length === 0 ? "passed" : "failed";
  report.failures = failures;
  mkdirSync(dirname(reportPath), { recursive: true });
  writeFileSync(reportPath, `${JSON.stringify(report, null, 2)}\n`);
  console.log(`Evidence: ${reportPath}`);
}

if (failures.length > 0) {
  throw new Error(`${failures.length} India readiness check(s) failed`);
}
