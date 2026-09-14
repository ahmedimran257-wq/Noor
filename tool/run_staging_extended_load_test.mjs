#!/usr/bin/env node

import { spawnSync } from "node:child_process";
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import path from "node:path";
import { verifyChatRetrySafety } from "./verify_chat_retry_safety.mjs";

const required = [
  "STAGING_SUPABASE_URL",
  "STAGING_SUPABASE_ANON_KEY",
  "STAGING_SUPABASE_SERVICE_ROLE_KEY",
  "STAGING_PROJECT_REF",
  "PRODUCTION_PROJECT_REF",
];
for (const name of required) {
  if (!process.env[name]) throw new Error(`Missing required environment variable: ${name}`);
}

const env = process.env;
const baseUrl = env.STAGING_SUPABASE_URL.replace(/\/$/, "");
const productionRef = "jukpscfxzwttgtxvrbmj";
if (
  env.STAGING_PROJECT_REF === env.PRODUCTION_PROJECT_REF ||
  env.STAGING_PROJECT_REF === productionRef ||
  new URL(baseUrl).hostname !== `${env.STAGING_PROJECT_REF}.supabase.co` ||
  new URL(baseUrl).hostname === `${productionRef}.supabase.co`
) {
  throw new Error("Refusing to run extended load automation against production");
}
if (env.EXTENDED_LOAD_ACK !== "I_UNDERSTAND_STAGING_EXTENDED_LOAD") {
  throw new Error("Extended staging load acknowledgement is missing");
}

const targetVus = Number(env.EXTENDED_TARGET_VUS || 1000);
if (![10, 150, 1000].includes(targetVus)) {
  throw new Error("EXTENDED_TARGET_VUS must be 10, 150, or 1000");
}
if (env.EXTENDED_VERIFY_CHAT_RECOVERY === "true" && targetVus !== 10) {
  throw new Error("Chat recovery verification is a bounded 10-client smoke only");
}
const service = env.STAGING_SUPABASE_SERVICE_ROLE_KEY;
const runId = `${Date.now()}-${Math.random().toString(36).slice(2, 10)}`;
const runTimestampMs = Date.now();
const fixtureDomain = "@staging.silarah.invalid";
const fixtureMetadataKey = "staging_extended_load_run";
// Ten smoke fixtures produce 25 independent cross-gender conversations, so a
// 10-client chat smoke does not serialize through only four locked match rows.
const fixtureCount = targetVus === 1000 ? 40 : 10;
const fixtures = [];
const bucket = `silarah-load-${runId}`.toLowerCase();
const reportDir = path.resolve(env.EXTENDED_REPORT_DIR || "build/staging-extended-load");
const reportPath = path.join(reportDir, `extended-${targetVus}-report.json`);
const supportedScenarios = ["realtime", "storage", "notifications", "chat", "billing"];
const scenarioNames = (env.EXTENDED_SCENARIOS || supportedScenarios.join(","))
  .split(",")
  .map((value) => value.trim().toLowerCase())
  .filter(Boolean);
if (
  scenarioNames.length === 0 ||
  scenarioNames.some((name) => !supportedScenarios.includes(name))
) {
  throw new Error("EXTENDED_SCENARIOS contains an unsupported scenario");
}
const scenarioResults = [];
let chatMatches = [];

async function request(
  requestPath,
  {
    token,
    apiKey,
    method = "GET",
    body,
    rawBody,
    contentType = "application/json",
    prefer,
    timeoutMs = 30_000,
    expectedStatuses,
  } = {},
) {
  const key = apiKey ?? env.STAGING_SUPABASE_ANON_KEY;
  const response = await fetch(`${baseUrl}${requestPath}`, {
    method,
    headers: {
      apikey: key,
      Authorization: `Bearer ${token ?? key}`,
      "Content-Type": contentType,
      ...(prefer ? { Prefer: prefer } : {}),
    },
    body: rawBody !== undefined
      ? rawBody
      : body === undefined
        ? undefined
        : JSON.stringify(body),
    signal: AbortSignal.timeout(timeoutMs),
  });
  const text = await response.text();
  let data = null;
  if (text) {
    try { data = JSON.parse(text); } catch { data = text; }
  }
  const accepted = expectedStatuses?.includes(response.status) ?? response.ok;
  if (!accepted) {
    const message = data?.message ?? data?.error_description ?? data?.error ??
      (typeof data === "string" ? data : `HTTP ${response.status}`);
    const error = new Error(message);
    error.status = response.status;
    throw error;
  }
  return { data, headers: response.headers, status: response.status };
}

async function retryTransient(action) {
  const delays = [0, 500, 1500, 3000, 6000];
  for (let attempt = 0; attempt < delays.length; attempt += 1) {
    if (delays[attempt]) await new Promise((resolve) => setTimeout(resolve, delays[attempt]));
    try {
      return await action();
    } catch (error) {
      const retryable = error instanceof TypeError || error?.status === 429 ||
        (Number(error?.status) >= 500 && Number(error?.status) < 600);
      if (!retryable || attempt === delays.length - 1) throw error;
    }
  }
}

async function createFixture(index) {
  const email = `extended.${runId}.${index}${fixtureDomain}`;
  const password = `E-${crypto.randomUUID()}-aA7!`;
  const result = await request("/auth/v1/admin/users", {
    apiKey: service,
    method: "POST",
    body: {
      email,
      password,
      email_confirm: true,
      user_metadata: { [fixtureMetadataKey]: runId },
    },
  });
  const fixture = { id: result.data.id, email, password };
  fixtures.push(fixture);
  return fixture;
}

async function signIn(fixture) {
  return retryTransient(() => request("/auth/v1/token?grant_type=password", {
    method: "POST",
    body: { email: fixture.email, password: fixture.password },
  }));
}

async function listAuthUsers() {
  const users = [];
  for (let page = 1; page <= 20; page += 1) {
    const result = await request(`/auth/v1/admin/users?page=${page}&per_page=1000`, {
      apiKey: service,
    });
    const batch = Array.isArray(result.data) ? result.data : (result.data?.users ?? []);
    users.push(...batch);
    if (batch.length < 1000) return users;
  }
  throw new Error("Auth fixture scan exceeded the 20,000-user safety bound");
}

function isExtendedFixture(user) {
  return Boolean(
    user?.id &&
    user?.email?.toLowerCase().endsWith(fixtureDomain) &&
    user?.user_metadata?.[fixtureMetadataKey],
  );
}

async function removeStaleFixtures() {
  const cutoff = Date.now() - 6 * 60 * 60 * 1000;
  const stale = (await listAuthUsers()).filter((user) =>
    isExtendedFixture(user) && Date.parse(user.created_at ?? "") < cutoff,
  );
  for (const user of stale) await deleteFixture(user);
}

async function deleteFixture(fixture) {
  await retryTransient(() => request(`/rest/v1/users?id=eq.${fixture.id}`, {
    apiKey: service,
    method: "DELETE",
    prefer: "return=minimal",
  }));
  await retryTransient(() => request(`/auth/v1/admin/users/${fixture.id}`, {
    apiKey: service,
    method: "DELETE",
  }));
}

async function listBucketObjects() {
  try {
    const result = await request(`/storage/v1/object/list/${bucket}`, {
      apiKey: service,
      method: "POST",
      body: {
        prefix: runId,
        limit: 1000,
        offset: 0,
        sortBy: { column: "name", order: "asc" },
      },
    });
    return Array.isArray(result.data) ? result.data : [];
  } catch (error) {
    if (error?.status === 400 || error?.status === 404) return [];
    throw error;
  }
}

async function cleanupBucket() {
  const objects = await listBucketObjects();
  const prefixes = objects.map((entry) =>
    entry.name.startsWith(`${runId}/`) ? entry.name : `${runId}/${entry.name}`,
  );
  for (let index = 0; index < prefixes.length; index += 100) {
    await retryTransient(() => request(`/storage/v1/object/${bucket}`, {
      apiKey: service,
      method: "DELETE",
      body: { prefixes: prefixes.slice(index, index + 100) },
      expectedStatuses: [200],
    }));
  }
  try {
    await retryTransient(() => request(`/storage/v1/bucket/${bucket}`, {
      apiKey: service,
      method: "DELETE",
      expectedStatuses: [200],
    }));
  } catch (error) {
    if (error?.status !== 400 && error?.status !== 404) throw error;
  }
}

async function registerSyntheticTokens(sessions) {
  for (let index = 0; index < sessions.length; index += 1) {
    await request("/rest/v1/rpc/register_my_fcm_token", {
      token: sessions[index].access_token,
      method: "POST",
      body: {
        p_device_id: `staging-extended-${runId}-${index}`,
        p_fcm_token: `staging-not-a-real-fcm-token-${runId}-${index}`,
        p_platform: "android",
      },
    });
  }
}

function metricValue(summary, name, field) {
  // k6 1.x exports metric fields directly; older releases nested them under
  // `values`. Supporting both keeps the evidence report complete.
  return summary?.metrics?.[name]?.values?.[field] ??
    summary?.metrics?.[name]?.[field] ??
    (field === "rate" ? summary?.metrics?.[name]?.value : null) ?? null;
}

function runK6Scenario(name, sessions) {
  const installedK6 = "C:\\Program Files\\k6\\k6.exe";
  const k6Path = env.K6_PATH || (existsSync(installedK6) ? installedK6 : "k6");
  const summaryPath = path.join(reportDir, `${name}-${targetVus}-summary.json`);
  const result = spawnSync(
    k6Path,
    ["run", "--quiet", `--summary-export=${summaryPath}`, path.resolve("load-tests/staging_extended_paths.js")],
    {
      cwd: process.cwd(),
      env: {
        ...env,
        TARGET_ENV: "staging",
        SUPABASE_URL: baseUrl,
        SUPABASE_ANON_KEY: env.STAGING_SUPABASE_ANON_KEY,
        SUPABASE_SERVICE_ROLE_KEY: service,
        EXTENDED_SCENARIO: name,
        EXTENDED_RUN_ID: runId,
        EXTENDED_STORAGE_BUCKET: bucket,
        EXTENDED_RUN_TIMESTAMP_MS: String(runTimestampMs),
        EXTENDED_TARGET_VUS: String(targetVus),
        EXTENDED_LOAD_ACK: env.EXTENDED_LOAD_ACK,
        REALTIME_HOLD_SECONDS: env.REALTIME_HOLD_SECONDS || (targetVus === 1000 ? "60" : "10"),
        REALTIME_RAMP_SECONDS: env.REALTIME_RAMP_SECONDS || (targetVus === 1000 ? "40" : "5"),
        CHAT_SPREAD_SECONDS: env.CHAT_SPREAD_SECONDS || (targetVus === 1000 ? "120" : "1"),
        TEST_USER_TOKENS: sessions.map((session) => session.access_token).join(","),
        TEST_USER_IDS: fixtures.map((fixture) => fixture.id).join(","),
        TEST_CHAT_MATCHES: JSON.stringify(chatMatches),
      },
      stdio: "inherit",
    },
  );
  if (result.error) throw result.error;
  const summary = existsSync(summaryPath)
    ? JSON.parse(readFileSync(summaryPath, "utf8"))
    : null;
  const outcome = {
    scenario: name,
    exitCode: result.status ?? 1,
    summaryPath,
    checksRate: metricValue(summary, "checks", "rate"),
    httpFailureRate: metricValue(summary, "http_req_failed", "rate"),
    httpP95Ms: metricValue(summary, "http_req_duration", "p(95)"),
    iterations: metricValue(summary, "iterations", "count"),
    realtimeUpgradeRate: metricValue(summary, "realtime_upgrade_success", "rate"),
    realtimeJoinRate: metricValue(summary, "realtime_join_success", "rate"),
    realtimeSubscribedRate: metricValue(summary, "realtime_subscribed_success", "rate"),
    realtimeSustainedRate: metricValue(summary, "realtime_sustained_success", "rate"),
    realtimeHeldConnections: metricValue(summary, "realtime_held_connections", "count"),
    realtimeFailures: metricValue(summary, "realtime_failures", "count"),
    ...(name === "realtime" ? {
      sharedHoldSeconds: Number(env.REALTIME_HOLD_SECONDS || (targetVus === 1000 ? "60" : "10")),
      rampSeconds: Number(env.REALTIME_RAMP_SECONDS || (targetVus === 1000 ? "40" : "5")),
      joinGraceSeconds: 20,
      distinctIdentities: sessions.length,
      webSocketConnectP95Ms: metricValue(summary, "ws_connecting", "p(95)"),
      failureReasons: Object.fromEntries(Object.keys(summary?.metrics || {})
        .filter((key) => key.startsWith("realtime_failures{reason:"))
        .map((key) => [key.slice("realtime_failures{reason:".length, -1), metricValue(summary, key, "count")])
        .filter(([, count]) => count > 0)),
    } : {}),
  };
  scenarioResults.push(outcome);
  return outcome;
}

async function verifyStorage() {
  const objects = await listBucketObjects();
  if (objects.length !== targetVus) {
    throw new Error(`Storage verification expected ${targetVus} objects, found ${objects.length}`);
  }
  return { objects: objects.length, bytes: objects.reduce((sum, item) => sum + Number(item.metadata?.size ?? 0), 0) };
}

async function verifyNotifications() {
  const title = encodeURIComponent(`Staging extended ${runId}`);
  const result = await request(`/rest/v1/notifications?title=eq.${title}&select=id&limit=1100`, {
    apiKey: service,
  });
  if (!Array.isArray(result.data) || result.data.length !== targetVus) {
    throw new Error(`Notification verification expected ${targetVus}, found ${result.data?.length ?? 0}`);
  }
  if (targetVus === 1000) {
    const now = new Date().toISOString();
    const heldUntil = new Date(Date.now() + (60 * 60 * 1000)).toISOString();
    const testIds = result.data.slice(0, 100).map((row) => row.id);
    const unrelated = await request(
      `/rest/v1/notifications?sent_at=is.null&scheduled_at=lte.${encodeURIComponent(now)}&title=neq.${title}&select=id&limit=1`,
      { apiKey: service },
    );
    if (unrelated.data.length > 0) {
      throw new Error("Notification lease test stopped: unrelated due staging rows exist");
    }
    // Isolate the concurrency check from the other 900 valid load fixtures.
    // Without this hold, checkout_notifications() may correctly lease older
    // rows from the same run before the sampled IDs, producing a false zero.
    await request(`/rest/v1/notifications?title=eq.${title}`, {
      apiKey: service,
      method: "PATCH",
      prefer: "return=minimal",
      body: { scheduled_at: heldUntil, next_attempt_at: heldUntil },
    });
    await request(`/rest/v1/notifications?id=in.(${testIds.join(",")})`, {
      apiKey: service,
      method: "PATCH",
      prefer: "return=minimal",
      body: { scheduled_at: now, next_attempt_at: now },
    });
    const dueState = await request(
      `/rest/v1/notifications?id=in.(${testIds.join(",")})&select=id,sent_at,delivery_status,attempt_count,scheduled_at,next_attempt_at`,
      { apiKey: service },
    );
    const duePending = dueState.data.filter((row) =>
      row.sent_at == null && row.delivery_status === "pending" &&
      Date.parse(row.scheduled_at) <= Date.now() &&
      Date.parse(row.next_attempt_at) <= Date.now()
    );
    if (duePending.length !== 100) {
      const states = dueState.data.reduce((counts, row) => {
        const key = `${row.delivery_status}:${row.sent_at == null ? "unsent" : "sent"}`;
        counts[key] = (counts[key] || 0) + 1;
        return counts;
      }, {});
      throw new Error(
        `Notification due-state verification expected 100 pending rows, found ${duePending.length}; states=${JSON.stringify(states)}`,
      );
    }
    const leased = [];
    const unique = new Set();
    let leaseRounds = 0;
    let firstWaveLeases = 0;
    while (unique.size < 100 && leaseRounds < 5) {
      leaseRounds += 1;
      const batches = await Promise.all(Array.from({ length: 10 }, () =>
        request("/rest/v1/rpc/checkout_notifications", {
          apiKey: service,
          method: "POST",
          body: { batch_size: 10 },
        }),
      ));
      const roundLeases = batches.flatMap((batch) => batch.data ?? [])
        .filter((row) => testIds.includes(row.id));
      if (leaseRounds === 1) firstWaveLeases = roundLeases.length;
      for (const row of roundLeases) {
        if (unique.has(row.id)) {
          throw new Error(`Notification ${row.id} received more than one active lease`);
        }
        unique.add(row.id);
        leased.push(row);
      }
      if (unique.size < 100) {
        await new Promise((resolve) => setTimeout(resolve, 250));
      }
    }
    if (leased.length !== 100 || unique.size !== 100) {
      throw new Error(`Notification lease integrity failed: ${leased.length} leases, ${unique.size} unique`);
    }
    for (const row of leased) {
      await request("/rest/v1/rpc/finish_notification_delivery", {
        apiKey: service,
        method: "POST",
        body: {
          p_notification_id: row.id,
          p_lease_token: row.lease_token,
          p_status: "in_app_only",
          p_error_code: "staging_load_test",
        },
      });
    }
    return {
      queued: result.data.length,
      leased: leased.length,
      uniqueLeases: unique.size,
      firstWaveLeases,
      leaseRounds,
    };
  }
  return { queued: result.data.length, leased: 0, uniqueLeases: 0 };
}

async function verifyChat() {
  const senderIds = fixtures
    .filter((_, index) => index % 2 === 1)
    .map((fixture) => fixture.id);
  const messages = await request(
    `/rest/v1/messages?sender_id=in.(${senderIds.join(",")})&created_at=gte.${encodeURIComponent(new Date(runTimestampMs).toISOString())}&select=id&limit=1100`,
    { apiKey: service },
  );
  if (!Array.isArray(messages.data) || messages.data.length !== targetVus) {
    throw new Error(
      `Chat verification expected ${targetVus} messages, found ${messages.data?.length ?? 0}`,
    );
  }
  const receiverIds = fixtures
    .filter((_, index) => index % 2 === 0)
    .map((fixture) => fixture.id);
  const notifications = await request(
    `/rest/v1/notifications?user_id=in.(${receiverIds.join(",")})&type=eq.new_message&created_at=gte.${encodeURIComponent(new Date(runTimestampMs).toISOString())}&select=id,deep_link,delivery_status&limit=1100`,
    { apiKey: service },
  );
  if (
    !Array.isArray(notifications.data) ||
    notifications.data.length !== targetVus ||
    notifications.data.some((row) =>
      !row.deep_link?.startsWith("silarah://chat/")
    )
  ) {
    throw new Error(
      `Chat notification verification expected ${targetVus} canonical rows, found ${notifications.data?.length ?? 0}`,
    );
  }
  return {
    messages: messages.data.length,
    notifications: notifications.data.length,
  };
}

async function verifyBilling() {
  const prefix = encodeURIComponent(`staging-extended-${runId}-`);
  const events = await request(
    `/rest/v1/subscription_events?provider_event_id=like.${prefix}*&select=id,user_id,provider_event_id,event_timestamp_ms&limit=1000`,
    { apiKey: service },
  );
  const expectedUnique = Math.ceil(targetVus / 2);
  const ids = new Set(events.data.map((row) => row.provider_event_id));
  if (events.data.length !== expectedUnique || ids.size !== expectedUnique) {
    throw new Error(
      `Billing idempotency expected ${expectedUnique} unique events, found ${events.data.length}/${ids.size}`,
    );
  }
  const outbox = await request(
    `/rest/v1/transactional_email_outbox?dedupe_key=like.${encodeURIComponent(`revenuecat:staging-extended-${runId}-`)}*&select=id,dedupe_key&limit=1000`,
    { apiKey: service },
  );
  const outboxIds = new Set(outbox.data.map((row) => row.dedupe_key));
  const providerEventIds = new Set(events.data.map((row) => row.provider_event_id));
  const outboxReferencesOnlyKnownEvents = outbox.data.every((row) =>
    providerEventIds.has(row.dedupe_key.replace(/^revenuecat:/, ""))
  );
  if (
    outboxIds.size !== outbox.data.length ||
    outbox.data.length < fixtures.length ||
    outbox.data.length > expectedUnique ||
    !outboxReferencesOnlyKnownEvents
  ) {
    throw new Error("Billing outbox idempotency verification failed");
  }
  const expectedLastTimestampByUser = new Map();
  for (const event of events.data) {
    const timestamp = Number(event.event_timestamp_ms);
    expectedLastTimestampByUser.set(
      event.user_id,
      Math.max(expectedLastTimestampByUser.get(event.user_id) ?? 0, timestamp),
    );
  }
  const users = await request(
    `/rest/v1/users?id=in.(${fixtures.map((fixture) => fixture.id).join(",")})&select=id,last_billing_event_ts,subscription_status`,
    { apiKey: service },
  );
  const monotonicEntitlements = users.data.length === fixtures.length &&
    users.data.every((user) =>
      user.subscription_status === "active" &&
      Number(user.last_billing_event_ts) === expectedLastTimestampByUser.get(user.id)
    );
  if (!monotonicEntitlements) {
    throw new Error("Billing entitlement ordering verification failed");
  }
  return {
    requests: targetVus,
    uniqueProviderEvents: ids.size,
    outboxRows: outbox.data.length,
    staleEventsSafelyIgnored: expectedUnique - outbox.data.length,
    monotonicEntitlements: true,
  };
}

async function assertCleanup() {
  const ids = fixtures.map((fixture) => fixture.id);
  if (ids.length > 0) {
    const publicRows = await request(`/rest/v1/users?id=in.(${ids.join(",")})&select=id`, {
      apiKey: service,
    });
    if (publicRows.data.length > 0) throw new Error("Extended public fixtures remain");
    const authIds = new Set((await listAuthUsers()).map((user) => user.id));
    if (ids.some((id) => authIds.has(id))) throw new Error("Extended Auth fixtures remain");
  }
  const remainingObjects = await listBucketObjects();
  if (remainingObjects.length > 0) throw new Error("Extended storage objects remain");
}

mkdirSync(reportDir, { recursive: true });
const report = {
  runId,
  targetEnvironment: "staging",
  stagingProjectRef: env.STAGING_PROJECT_REF,
  targetClients: targetVus,
  startedAt: new Date().toISOString(),
  scenarios: scenarioResults,
  verification: {},
  cleanup: { complete: false },
};
let primaryError = null;

try {
  await removeStaleFixtures();
  for (let index = 0; index < fixtureCount; index += 1) await createFixture(index);
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
  if (scenarioNames.includes("notifications")) {
    await request("/rest/v1/notification_prefs", {
      apiKey: service,
      method: "POST",
      prefer: "resolution=merge-duplicates,return=minimal",
      body: fixtures.map((fixture) => ({
        user_id: fixture.id,
        profile_view: true,
      })),
    });
  }
  if (scenarioNames.includes("chat")) {
    const cities = await request("/rest/v1/cities?select=id&limit=1", {
      apiKey: service,
    });
    const cityId = cities.data?.[0]?.id;
    if (!cityId) throw new Error("Staging needs a city for chat fixtures");
    const approvedAt = new Date().toISOString();
    await request("/rest/v1/profiles", {
      apiKey: service,
      method: "POST",
      prefer: "return=minimal",
      body: fixtures.map((fixture, index) => ({
        user_id: fixture.id,
        first_name: `Chat${index}`,
        last_name: "Staging",
        date_of_birth: `${1990 + (index % 10)}-01-01`,
        gender: index % 2 === 0 ? "male" : "female",
        country_code: "IN",
        city_id: cityId,
        sect: "Sunni",
        deen_level: "practicing",
        bio: `Disposable chat capacity member ${index}.`,
        visibility: "visible",
        onboarding_step: 14,
        onboarding_completed: true,
        completeness_score: 100,
        approved_at: approvedAt,
        last_active_at: approvedAt,
      })),
    });
    const pairs = [];
    for (let maleIndex = 0; maleIndex < fixtures.length; maleIndex += 2) {
      for (let femaleIndex = 1; femaleIndex < fixtures.length; femaleIndex += 2) {
        pairs.push({
          user_a: fixtures[maleIndex].id,
          user_b: fixtures[femaleIndex].id,
          status: "active",
          senderIndex: femaleIndex,
        });
      }
    }
    const inserted = await request("/rest/v1/matches?select=id,user_a,user_b", {
      apiKey: service,
      method: "POST",
      prefer: "return=representation",
      body: pairs.map(({ user_a, user_b, status }) => ({
        user_a,
        user_b,
        status,
      })),
    });
    if (!Array.isArray(inserted.data) || inserted.data.length !== pairs.length) {
      throw new Error("Disposable chat match population is incomplete");
    }
    const senderByFemale = new Map(
      pairs.map((pair) => [pair.user_b, pair.senderIndex]),
    );
    chatMatches = inserted.data.map((match) => ({
      matchId: match.id,
      senderIndex: senderByFemale.get(match.user_b),
    }));
  }
  const sessions = [];
  for (const fixture of fixtures) sessions.push((await signIn(fixture)).data);
  if (sessions.some((session) => !session.access_token)) {
    throw new Error("Disposable extended-load sessions are incomplete");
  }
  // Chat capacity verifies durable notification creation. Genuine FCM
  // transport is covered by the physical-device test, so fake tokens must not
  // cause needless outbound Google requests here.
  if (scenarioNames.includes("notifications") && !scenarioNames.includes("chat")) {
    await registerSyntheticTokens(sessions);
  }
  await request("/storage/v1/bucket", {
    apiKey: service,
    method: "POST",
    body: {
      id: bucket,
      name: bucket,
      public: false,
      file_size_limit: 1048576,
      allowed_mime_types: ["application/octet-stream"],
    },
    expectedStatuses: [200, 201],
  });

  const scenarioFailures = [];
  for (const name of scenarioNames) {
    const outcome = runK6Scenario(name, sessions);
    if (outcome.exitCode !== 0) {
      scenarioFailures.push(`${name} k6 scenario failed with exit code ${outcome.exitCode}`);
      continue;
    }
    if (name === "storage") report.verification.storage = await verifyStorage();
    if (name === "notifications") report.verification.notifications = await verifyNotifications();
    if (name === "chat") {
      report.verification.chat = await verifyChat();
      if (env.EXTENDED_VERIFY_CHAT_RECOVERY === "true") {
        report.verification.chatRetrySafety = await verifyChatRetrySafety({
          request, service, sessions, fixtures, chatMatches,
        });
      }
    }
    if (name === "billing") report.verification.billing = await verifyBilling();
  }
  if (scenarioFailures.length > 0) {
    throw new Error(scenarioFailures.join("; "));
  }
} catch (error) {
  primaryError = error;
  report.error = String(error?.stack ?? error);
} finally {
  try {
    await cleanupBucket();
    for (const fixture of fixtures) await deleteFixture(fixture);
    await assertCleanup();
    report.cleanup = { complete: true, fixtureCount: fixtures.length };
  } catch (cleanupError) {
    report.cleanup = { complete: false, error: String(cleanupError?.stack ?? cleanupError) };
    if (!primaryError) primaryError = cleanupError;
  }
  report.finishedAt = new Date().toISOString();
  writeFileSync(reportPath, JSON.stringify(report, null, 2));
}

if (primaryError) {
  console.error(`FAIL: ${primaryError.message}`);
  console.error(`Evidence: ${reportPath}`);
  process.exit(1);
}

console.log(`PASS: staging extended capacity test (${targetVus} clients)`);
console.log(`Evidence: ${reportPath}`);
