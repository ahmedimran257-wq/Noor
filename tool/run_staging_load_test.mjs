#!/usr/bin/env node

import { spawnSync } from "node:child_process";
import { existsSync, mkdirSync } from "node:fs";
import path from "node:path";

const required = [
  "STAGING_SUPABASE_URL",
  "STAGING_SUPABASE_ANON_KEY",
  "STAGING_SUPABASE_SERVICE_ROLE_KEY",
  "STAGING_PROJECT_REF",
  "PRODUCTION_PROJECT_REF",
];

for (const name of required) {
  if (!process.env[name]) {
    throw new Error(`Missing required environment variable: ${name}`);
  }
}

const env = process.env;
const baseUrl = env.STAGING_SUPABASE_URL.replace(/\/$/, "");
const knownProductionProjectRef = "jukpscfxzwttgtxvrbmj";
const loadProfile = (env.LOAD_TEST_PROFILE || "baseline").trim().toLowerCase();
if (!["baseline", "scale"].includes(loadProfile)) {
  throw new Error("LOAD_TEST_PROFILE must be baseline or scale");
}
if (
  env.STAGING_PROJECT_REF === env.PRODUCTION_PROJECT_REF ||
  env.STAGING_PROJECT_REF === knownProductionProjectRef ||
  new URL(baseUrl).hostname === `${knownProductionProjectRef}.supabase.co` ||
  new URL(baseUrl).hostname !== `${env.STAGING_PROJECT_REF}.supabase.co`
) {
  throw new Error("Refusing to run load automation against production");
}

const requestedMaxVus = Number(env.LOAD_TEST_MAX_VUS || 1);
if (!Number.isInteger(requestedMaxVus)) {
  throw new Error("LOAD_TEST_MAX_VUS must be an integer");
}
const maxVus = loadProfile === "scale"
  ? requestedMaxVus
  : Math.min(Math.max(requestedMaxVus, 1), 50);
if (loadProfile === "scale") {
  if (![600, 800, 1000].includes(maxVus)) {
    throw new Error("Scale load tests must peak at 600, 800, or 1000 VUs");
  }
  if (env.LOAD_TEST_SCALE_ACK !== "I_UNDERSTAND_STAGING_SCALE_LOAD") {
    throw new Error("Scale load test acknowledgement is missing");
  }
}
const fixtureCount = loadProfile === "scale"
  ? 40
  : Math.min(Math.max(maxVus, 2), 10);
const service = env.STAGING_SUPABASE_SERVICE_ROLE_KEY;
const runId = `${Date.now()}-${Math.random().toString(36).slice(2, 10)}`;
const fixtureDomain = "@staging.silarah.invalid";
const fixtureMetadataKey = "staging_load_run";
const staleFixtureAgeMs = 6 * 60 * 60 * 1000;
const fixtures = [];
const summaryPath = path.resolve(
  env.STAGING_LOAD_REPORT_PATH ||
    (loadProfile === "scale"
      ? `build/staging-scale-${maxVus}-summary.json`
      : "build/staging-load-summary.json"),
);

async function request(
  requestPath,
  { token, apiKey, method = "GET", body, prefer, timeoutMs = 20_000 } = {},
) {
  const key = apiKey ?? env.STAGING_SUPABASE_ANON_KEY;
  const response = await fetch(`${baseUrl}${requestPath}`, {
    method,
    headers: {
      apikey: key,
      Authorization: `Bearer ${token ?? key}`,
      "Content-Type": "application/json",
      ...(prefer ? { Prefer: prefer } : {}),
    },
    body: body === undefined ? undefined : JSON.stringify(body),
    signal: AbortSignal.timeout(timeoutMs),
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
  if (!response.ok) {
    const message =
      data?.message ?? data?.error_description ?? data?.error ??
      (typeof data === "string" ? data : `HTTP ${response.status}`);
    const error = new Error(message);
    error.status = response.status;
    throw error;
  }
  return data;
}

async function signInFixture(fixture) {
  // GoTrue intentionally rate-limits bursty password grants. Fixture setup is
  // not part of the measured workload, so create sessions sequentially and
  // retry only explicit throttling responses with a short bounded backoff.
  const retryDelaysMs = [0, 750, 1500, 3000, 6000];
  for (let attempt = 0; attempt < retryDelaysMs.length; attempt += 1) {
    if (retryDelaysMs[attempt] > 0) {
      await new Promise((resolve) => setTimeout(resolve, retryDelaysMs[attempt]));
    }
    try {
      return await request("/auth/v1/token?grant_type=password", {
        method: "POST",
        body: { email: fixture.email, password: fixture.password },
      });
    } catch (error) {
      if (error?.status !== 429 || attempt === retryDelaysMs.length - 1) {
        throw error;
      }
    }
  }
  throw new Error("A disposable load-test session could not be created");
}

async function createFixture(index) {
  const email = `load.${runId}.${index}${fixtureDomain}`;
  const password = `L-${crypto.randomUUID()}-aA7!`;
  const authUser = await request("/auth/v1/admin/users", {
    apiKey: service,
    method: "POST",
    body: {
      email,
      password,
      email_confirm: true,
      user_metadata: { [fixtureMetadataKey]: runId },
    },
  });
  const fixture = { id: authUser.id, email, password };
  fixtures.push(fixture);
  return fixture;
}

async function listAuthUsers() {
  const users = [];
  for (let page = 1; page <= 20; page += 1) {
    const data = await request(`/auth/v1/admin/users?page=${page}&per_page=1000`, {
      apiKey: service,
    });
    const batch = Array.isArray(data) ? data : (data?.users ?? []);
    users.push(...batch);
    if (batch.length < 1000) return users;
  }
  throw new Error("Auth fixture scan exceeded the 20,000-user safety bound");
}

function isLoadFixture(user) {
  return Boolean(
    user?.id &&
      user?.email?.toLowerCase().endsWith(fixtureDomain) &&
      user?.user_metadata?.[fixtureMetadataKey],
  );
}

async function removeStaleLoadFixtures() {
  const cutoff = Date.now() - staleFixtureAgeMs;
  const stale = (await listAuthUsers()).filter((user) => {
    const createdAt = Date.parse(user.created_at ?? "");
    return isLoadFixture(user) && Number.isFinite(createdAt) && createdAt < cutoff;
  });
  for (const user of stale) {
    await request(`/rest/v1/users?id=eq.${user.id}`, {
      apiKey: service,
      method: "DELETE",
      prefer: "return=minimal",
    });
    await request(`/auth/v1/admin/users/${user.id}`, {
      apiKey: service,
      method: "DELETE",
    });
  }
  const staleIds = new Set(stale.map((user) => user.id));
  const remaining = (await listAuthUsers()).filter((user) => staleIds.has(user.id));
  if (remaining.length > 0) throw new Error("Stale load fixtures remain");
}

async function deleteFixture(fixture) {
  const retryDelaysMs = [0, 500, 1500, 3000, 6000];
  const retryTransient = async (action) => {
    for (let attempt = 0; attempt < retryDelaysMs.length; attempt += 1) {
      if (retryDelaysMs[attempt] > 0) {
        await new Promise((resolve) => setTimeout(resolve, retryDelaysMs[attempt]));
      }
      try {
        return await action();
      } catch (error) {
        const retryable =
          error instanceof TypeError ||
          error?.status === 429 ||
          (Number(error?.status) >= 500 && Number(error?.status) < 600);
        if (!retryable || attempt === retryDelaysMs.length - 1) throw error;
      }
    }
  };
  await retryTransient(() =>
    request(`/rest/v1/users?id=eq.${fixture.id}`, {
      apiKey: service,
      method: "DELETE",
      prefer: "return=minimal",
      timeoutMs: 30_000,
    }),
  );
  await retryTransient(() =>
    request(`/auth/v1/admin/users/${fixture.id}`, {
      apiKey: service,
      method: "DELETE",
      timeoutMs: 30_000,
    }),
  );
}

async function cleanupAllLoadFixtures() {
  const loadFixtures = (await listAuthUsers()).filter(isLoadFixture);
  for (const fixture of loadFixtures) {
    await deleteFixture(fixture);
  }
  const remaining = (await listAuthUsers()).filter(isLoadFixture);
  if (remaining.length > 0) {
    throw new Error(`${remaining.length} load-test Auth fixtures remain`);
  }
  return loadFixtures.length;
}

async function assertFixtureCleanup() {
  if (fixtures.length === 0) return;
  const ids = fixtures.map((fixture) => fixture.id);
  const publicLeft = await request(
    `/rest/v1/users?id=in.(${ids.join(",")})&select=id`,
    { apiKey: service },
  );
  if (publicLeft.length > 0) throw new Error("Load-test public fixtures remain");
  const authUsers = await listAuthUsers();
  const idSet = new Set(ids);
  if (authUsers.some((user) => idSet.has(user.id))) {
    throw new Error("Load-test Auth fixtures remain");
  }
}

let k6ExitCode = 1;
if (env.LOAD_TEST_CLEANUP_ONLY === "true") {
  const removed = await cleanupAllLoadFixtures();
  console.log(`PASS: removed ${removed} staging load-test fixtures; zero remain`);
  process.exit(0);
}
try {
  await removeStaleLoadFixtures();
  // Sequential creation prevents an early
  // Promise rejection from racing the finally cleanup while other users are
  // still being created.
  for (let index = 0; index < fixtureCount; index += 1) {
    await createFixture(index);
  }
  await request("/rest/v1/users", {
    apiKey: service,
    method: "POST",
    prefer: "return=minimal",
    body: fixtures.map((fixture, index) => ({
      id: fixture.id,
      email: fixture.email,
      country_code: "IN",
      gender: index % 2 === 0 ? "male" : "female",
      timezone: "Asia/Kolkata",
      onboarding_step: 5,
      onboarding_completed: true,
    })),
  });

  // High-scale runs include a complete, mixed-gender member pool so the
  // personalized Discovery RPC is exercised instead of measuring only cheap
  // catalogue reads. Forty real sessions are rotated across virtual users;
  // this measures concurrent API capacity without manufacturing 1,000 MAUs.
  if (loadProfile === "scale") {
    const cities = await request(
      "/rest/v1/cities?select=id,region_id&limit=1",
      { apiKey: service },
    );
    const city = cities?.[0];
    if (!city?.id) {
      throw new Error("Staging needs at least one city for scale fixtures");
    }
    const approvedAt = new Date().toISOString();
    const profiles = await request("/rest/v1/profiles?select=id,user_id", {
      apiKey: service,
      method: "POST",
      prefer: "return=representation",
      body: fixtures.map((fixture, index) => ({
        user_id: fixture.id,
        static_rank_score: index % 10,
        first_name: `Scale${index % 2 === 0 ? "M" : "F"}${index}`,
        last_name: "Staging",
        date_of_birth: `${1990 + (index % 10)}-01-01`,
        gender: index % 2 === 0 ? "male" : "female",
        country_code: "IN",
        city_id: city.id,
        sect: ["Sunni", "Shia", "Just Muslim"][index % 3],
        deen_level: ["practicing", "moderate", "cultural"][index % 3],
        education_level: "Graduate",
        education_rank: 4,
        profession: ["Engineer", "Teacher", "Designer", "Doctor"][index % 4],
        family_type: ["nuclear", "joint", "extended"][index % 3],
        previously_married: "no",
        bio: `Disposable scale-test member ${index}.`,
        languages: ["English", index % 2 === 0 ? "Hindi" : "Urdu"],
        interests: ["Family", "Reading"],
        height_cm: 155 + (index % 30),
        photo_privacy: "public",
        visibility: "visible",
        onboarding_step: 14,
        onboarding_completed: true,
        completeness_score: 100,
        approved_at: approvedAt,
        last_active_at: approvedAt,
        mother_tongue: index % 2 === 0 ? "Hindi" : "Urdu",
        community: index % 2 === 0 ? "Sheikh" : "Ansari",
        marriage_timeline: "1_year",
        willing_to_relocate: "open_to_discussion",
        living_expectation: "open_to_discussion",
      })),
    });
    if (!Array.isArray(profiles) || profiles.length !== fixtureCount) {
      throw new Error("Scale profile population is incomplete");
    }
    await request("/rest/v1/profile_preferences?on_conflict=profile_id", {
      apiKey: service,
      method: "POST",
      prefer: "resolution=merge-duplicates,return=minimal",
      body: profiles.map((profile) => ({
        profile_id: profile.id,
        preferred_age_min: 18,
        preferred_age_max: 60,
        preferred_countries: ["IN"],
        sect_preference: "any",
        deen_preference: "any",
        min_education_rank: 1,
        open_to_divorced: true,
        open_to_widowed: true,
        open_to_has_children: true,
        open_to_diaspora: false,
      })),
    });
  }

  const sessions = [];
  for (const fixture of fixtures) {
    sessions.push(await signInFixture(fixture));
  }
  const tokens = sessions.map((session) => session.access_token);
  if (tokens.some((token) => !token)) {
    throw new Error("A disposable load-test session was not created");
  }

  const installedK6 = "C:\\Program Files\\k6\\k6.exe";
  const k6Path = env.K6_PATH || (existsSync(installedK6) ? installedK6 : "k6");
  const scriptPath = path.resolve(
    loadProfile === "scale"
      ? "load-tests/staging_scale_paths.js"
      : "load-tests/staging_read_paths.js",
  );
  mkdirSync(path.dirname(summaryPath), { recursive: true });
  const result = spawnSync(
    k6Path,
    ["run", `--summary-export=${summaryPath}`, scriptPath],
    {
      cwd: process.cwd(),
      env: {
        ...env,
        TARGET_ENV: "staging",
        SUPABASE_URL: baseUrl,
        SUPABASE_ANON_KEY: env.STAGING_SUPABASE_ANON_KEY,
        TEST_USER_TOKENS: tokens.join(","),
        TEST_USER_IDS: fixtures.map((fixture) => fixture.id).join(","),
        MAX_VUS: String(maxVus),
        SCALE_LOAD_ACK: env.LOAD_TEST_SCALE_ACK || "",
        SMOKE_MODE: env.LOAD_TEST_SMOKE_MODE || "true",
        ITERATION_SLEEP_SECONDS: env.LOAD_TEST_ITERATION_SLEEP_SECONDS || "1",
      },
      stdio: "inherit",
    },
  );
  if (result.error) throw result.error;
  k6ExitCode = result.status ?? 1;
} finally {
  // Cleanup is intentionally sequential. A concurrent delete burst can be
  // throttled or reset just after a high-scale run, which risks leaving test
  // accounts behind.
  for (const fixture of fixtures) {
    await deleteFixture(fixture);
  }
  await assertFixtureCleanup();
}

if (k6ExitCode !== 0) {
  throw new Error(`k6 staging load test failed with exit code ${k6ExitCode}`);
}

console.log(
  `PASS: staging ${loadProfile} load test (${maxVus} VUs) with disposable accounts`,
);
console.log(`Evidence: ${summaryPath}`);
