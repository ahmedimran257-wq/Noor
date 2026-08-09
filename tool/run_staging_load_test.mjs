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
const fixtures = [];
const summaryPath = path.resolve(
  env.STAGING_LOAD_REPORT_PATH || "build/staging-load-summary.json",
);

async function request(
  requestPath,
  { token, apiKey, method = "GET", body, prefer } = {},
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
  const email = `load.${runId}.${index}@staging.silarah.invalid`;
  const password = `L-${crypto.randomUUID()}-aA7!`;
  const authUser = await request("/auth/v1/admin/users", {
    apiKey: service,
    method: "POST",
    body: { email, password, email_confirm: true },
  });
  const fixture = { id: authUser.id, email, password };
  fixtures.push(fixture);
  return fixture;
}

async function deleteFixture(fixture) {
  await request(`/rest/v1/users?id=eq.${fixture.id}`, {
    apiKey: service,
    method: "DELETE",
    prefer: "return=minimal",
  }).catch(() => undefined);
  await request(`/auth/v1/admin/users/${fixture.id}`, {
    apiKey: service,
    method: "DELETE",
  }).catch(() => undefined);
}

let k6ExitCode = 1;
try {
  await Promise.all(
    Array.from({ length: fixtureCount }, (_, index) => createFixture(index)),
  );
  await request("/rest/v1/users", {
    apiKey: service,
    method: "POST",
    prefer: "return=minimal",
    body: fixtures.map((fixture, index) => ({
      id: fixture.id,
      email: fixture.email,
      country_code: "IN",
      gender: index % 2 === 0 ? "male" : "female",
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
}

if (k6ExitCode !== 0) {
  throw new Error(`k6 staging load test failed with exit code ${k6ExitCode}`);
}

console.log(
  `PASS: staging read-path load test (${maxVus} VUs) with disposable accounts`,
);
console.log(`Evidence: ${summaryPath}`);
