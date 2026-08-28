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
if (
  env.STAGING_PROJECT_REF === env.PRODUCTION_PROJECT_REF ||
  new URL(baseUrl).hostname !== `${env.STAGING_PROJECT_REF}.supabase.co`
) {
  throw new Error("Refusing to run load automation against production");
}

const maxVus = Math.min(Math.max(Number(env.LOAD_TEST_MAX_VUS || 1), 1), 50);
const fixtureCount = Math.min(Math.max(maxVus, 2), 10);
const service = env.STAGING_SUPABASE_SERVICE_ROLE_KEY;
const runId = `${Date.now()}-${Math.random().toString(36).slice(2, 10)}`;
const fixtureDomain = "@staging.silarah.invalid";
const fixtureMetadataKey = "staging_load_run";
const staleFixtureAgeMs = 6 * 60 * 60 * 1000;
const fixtures = [];
const summaryPath = path.resolve(
  env.STAGING_LOAD_REPORT_PATH || "build/staging-load-summary.json",
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
    throw new Error(message);
  }
  return data;
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
  await request(`/rest/v1/users?id=eq.${fixture.id}`, {
    apiKey: service,
    method: "DELETE",
    prefer: "return=minimal",
    timeoutMs: 30_000,
  });
  await request(`/auth/v1/admin/users/${fixture.id}`, {
    apiKey: service,
    method: "DELETE",
    timeoutMs: 30_000,
  });
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
try {
  await removeStaleLoadFixtures();
  // At most ten fixtures are needed. Sequential creation prevents an early
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

  const sessions = await Promise.all(
    fixtures.map((fixture) =>
      request("/auth/v1/token?grant_type=password", {
        method: "POST",
        body: { email: fixture.email, password: fixture.password },
      }),
    ),
  );
  const tokens = sessions.map((session) => session.access_token);
  if (tokens.some((token) => !token)) {
    throw new Error("A disposable load-test session was not created");
  }

  const installedK6 = "C:\\Program Files\\k6\\k6.exe";
  const k6Path = env.K6_PATH || (existsSync(installedK6) ? installedK6 : "k6");
  const scriptPath = path.resolve("load-tests/staging_read_paths.js");
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
        MAX_VUS: String(maxVus),
        SMOKE_MODE: env.LOAD_TEST_SMOKE_MODE || "true",
        ITERATION_SLEEP_SECONDS: env.LOAD_TEST_ITERATION_SLEEP_SECONDS || "1",
      },
      stdio: "inherit",
    },
  );
  if (result.error) throw result.error;
  k6ExitCode = result.status ?? 1;
} finally {
  await Promise.all(fixtures.map(deleteFixture));
  await assertFixtureCleanup();
}

if (k6ExitCode !== 0) {
  throw new Error(`k6 staging load test failed with exit code ${k6ExitCode}`);
}

console.log(
  `PASS: staging read-path load test (${maxVus} VUs) with disposable accounts`,
);
console.log(`Evidence: ${summaryPath}`);
