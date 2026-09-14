import http from "k6/http";
import ws from "k6/ws";
import exec from "k6/execution";
import { Counter, Rate, Trend } from "k6/metrics";
import { check, fail, sleep } from "k6";
import { createRealtimeHoldGate } from "./realtime_hold_gate.js";

const productionProjectRef = "jukpscfxzwttgtxvrbmj";
const targetEnvironment = (__ENV.TARGET_ENV || "").trim().toLowerCase();
const baseUrl = (__ENV.SUPABASE_URL || "").trim().replace(/\/$/, "");
const stagingProjectRef = (__ENV.STAGING_PROJECT_REF || "").trim();
const anonKey = (__ENV.SUPABASE_ANON_KEY || "").trim();
const serviceKey = (__ENV.SUPABASE_SERVICE_ROLE_KEY || "").trim();
const scenario = (__ENV.EXTENDED_SCENARIO || "").trim().toLowerCase();
const acknowledgement = (__ENV.EXTENDED_LOAD_ACK || "").trim();
const runId = (__ENV.EXTENDED_RUN_ID || "").trim();
const bucket = (__ENV.EXTENDED_STORAGE_BUCKET || "").trim();
const runTimestampMs = Number(__ENV.EXTENDED_RUN_TIMESTAMP_MS || Date.now());
const targetVus = Number(__ENV.EXTENDED_TARGET_VUS || 1000);
const realtimeHoldSeconds = Number(__ENV.REALTIME_HOLD_SECONDS || 45);
const realtimeRampSeconds = Number(__ENV.REALTIME_RAMP_SECONDS || 40);
const realtimeJoinGraceSeconds = 20;
const chatSpreadSeconds = Number(__ENV.CHAT_SPREAD_SECONDS || 60);
const tokens = (__ENV.TEST_USER_TOKENS || "")
  .split(",")
  .map((value) => value.trim())
  .filter(Boolean);
const userIds = (__ENV.TEST_USER_IDS || "")
  .split(",")
  .map((value) => value.trim())
  .filter(Boolean);
const chatMatches = JSON.parse(__ENV.TEST_CHAT_MATCHES || "[]");

const realtimeUpgradeSuccess = new Rate("realtime_upgrade_success");
const realtimeJoinSuccess = new Rate("realtime_join_success");
const realtimeConnections = new Counter("realtime_connections");
const realtimeSubscribedSuccess = new Rate("realtime_subscribed_success");
const realtimeSustainedSuccess = new Rate("realtime_sustained_success");
const realtimeHeldConnections = new Counter("realtime_held_connections");
const realtimeFailures = new Counter("realtime_failures");
const storageUploadSuccess = new Rate("storage_upload_success");
const notificationQueueSuccess = new Rate("notification_queue_success");
const chatMessageSuccess = new Rate("chat_message_success");
const chatReadSuccess = new Rate("chat_read_success");
const billingEventSuccess = new Rate("billing_event_success");
const realtimeSessionDuration = new Trend("realtime_session_duration", true);

function selectedScenario() {
  if (scenario === "realtime") {
    return {
      realtime_socket_storm: {
        executor: "per-vu-iterations",
        vus: targetVus,
        iterations: 1,
        maxDuration: `${realtimeRampSeconds + realtimeJoinGraceSeconds + realtimeHoldSeconds + 30}s`,
        gracefulStop: "15s",
        exec: "realtimeSocketStorm",
      },
    };
  }
  if (scenario === "storage") {
    return {
      storage_upload_storm: {
        executor: "shared-iterations",
        vus: Math.min(targetVus, 250),
        iterations: targetVus,
        maxDuration: "4m",
        gracefulStop: "30s",
        exec: "storageUploadStorm",
      },
    };
  }
  if (scenario === "notifications") {
    return {
      notification_queue_storm: {
        executor: "shared-iterations",
        vus: Math.min(targetVus, 200),
        iterations: targetVus,
        maxDuration: "4m",
        gracefulStop: "30s",
        exec: "notificationQueueStorm",
      },
    };
  }
  if (scenario === "chat") {
    return {
      chat_and_notification_storm: {
        executor: "per-vu-iterations",
        vus: targetVus,
        iterations: 1,
        maxDuration: `${Math.ceil(chatSpreadSeconds) + 90}s`,
        gracefulStop: "30s",
        exec: "chatAndNotificationStorm",
      },
    };
  }
  if (scenario === "billing") {
    return {
      billing_idempotency_storm: {
        executor: "shared-iterations",
        vus: Math.min(targetVus, 200),
        iterations: targetVus,
        maxDuration: "4m",
        gracefulStop: "30s",
        exec: "billingIdempotencyStorm",
      },
    };
  }
  return {};
}

const scenarioThresholds = {
  realtime: {
    realtime_upgrade_success: ["rate==1"],
    realtime_join_success: ["rate==1"],
    realtime_subscribed_success: ["rate==1"],
    realtime_sustained_success: ["rate==1"],
    realtime_held_connections: [`count==${targetVus}`],
    realtime_failures: ["count==0"],
    // Materialize bounded reason counters in the JSON summary; no raw frames,
    // user identifiers, access tokens, or server error bodies are recorded.
    ...Object.fromEntries([
      "too_many_connections", "too_many_joins", "too_many_channels", "join_rejected",
      "postgres_subscription_error", "channel_closed", "transport_error",
      "not_ready_at_common_hold_start", "hold_health_lost", "early_disconnect",
      "hold_incomplete", "http_429", "upgrade_rejected",
    ].map((reason) => [`realtime_failures{reason:${reason}}`, ["count>=0"]])),
  },
  storage: {
    storage_upload_success: ["rate>0.99"],
    "http_req_duration{route:storage_upload}": ["p(95)<5000"],
  },
  notifications: {
    notification_queue_success: ["rate>0.99"],
    "http_req_duration{route:notification_queue}": ["p(95)<3000"],
  },
  chat: {
    chat_message_success: ["rate>0.99"],
    chat_read_success: ["rate>0.99"],
    "http_req_duration{route:chat_message}": ["p(95)<5000"],
    "http_req_duration{route:chat_read}": ["p(95)<5000"],
  },
  billing: {
    billing_event_success: ["rate>0.99"],
    "http_req_duration{route:billing_event}": ["p(95)<5000"],
  },
};

export const options = {
  scenarios: selectedScenario(),
  thresholds: scenarioThresholds[scenario] || {},
  // Billing failures retain their short PostgREST error body so a schema or
  // validation mismatch is diagnosable. Other high-volume scenarios discard
  // bodies to keep the load generator itself from becoming the bottleneck.
  discardResponseBodies: !["billing", "chat"].includes(scenario),
  noConnectionReuse: false,
  summaryTrendStats: ["avg", "min", "med", "max", "p(90)", "p(95)", "p(99)"],
  userAgent: "SilarahStagingExtendedLoadTest/1.0",
};

export function setup() {
  if (!Number.isFinite(realtimeHoldSeconds) || realtimeHoldSeconds < 10 || realtimeHoldSeconds > 120 ||
      !Number.isFinite(realtimeRampSeconds) || realtimeRampSeconds < 5 || realtimeRampSeconds > 60) {
    fail("Safety stop: bounded Realtime hold (10-120s) and ramp (5-60s) required.");
  }
  if (targetEnvironment !== "staging") {
    fail("Safety stop: TARGET_ENV must equal staging.");
  }
  if (!["realtime", "storage", "notifications", "chat", "billing"].includes(scenario)) {
    fail("Safety stop: unsupported extended scenario.");
  }
  if (![10, 150, 1000].includes(targetVus)) {
    fail("Safety stop: extended tests run only at 10-client smoke, 150 active chats, or 1,000-client target.");
  }
  if (acknowledgement !== "I_UNDERSTAND_STAGING_EXTENDED_LOAD") {
    fail("Safety stop: explicit extended-load acknowledgement is required.");
  }
  if (!baseUrl || !anonKey || !serviceKey || !stagingProjectRef || !runId) {
    fail("Safety stop: staging URL, keys, project ref and run id are required.");
  }
  if (tokens.length === 0 || tokens.length !== userIds.length) {
    fail("Safety stop: disposable staging sessions are incomplete.");
  }
  if (
    baseUrl.includes(productionProjectRef) ||
    baseUrl.includes("silarah.com") ||
    stagingProjectRef === productionProjectRef ||
    !baseUrl.includes(stagingProjectRef)
  ) {
    fail("Safety stop: production or mismatched project detected.");
  }
  if (scenario === "storage" && !bucket.startsWith("silarah-load-")) {
    fail("Safety stop: a dedicated disposable storage bucket is required.");
  }
  if (
    scenario === "chat" &&
    (chatMatches.length === 0 ||
      chatMatches.some((entry) =>
        !entry.matchId ||
        !Number.isInteger(entry.senderIndex) ||
        entry.senderIndex < 0 ||
        entry.senderIndex >= tokens.length
      ))
  ) {
    fail("Safety stop: disposable chat matches are incomplete.");
  }
  return {
    baseUrl,
    anonKey,
    serviceKey,
    tokens,
    userIds,
    runId,
    bucket,
    chatMatches,
  };
}

function serviceHeaders(route, contentType = "application/json") {
  return {
    headers: {
      apikey: serviceKey,
      Authorization: `Bearer ${serviceKey}`,
      "Content-Type": contentType,
    },
    tags: { route },
    timeout: "20s",
  };
}

export function realtimeSocketStorm(config) {
  // All clients share the same hold window. Ramp at <=25 joins/sec for the
  // 1,000-client gate so the join-rate quota cannot masquerade as socket capacity.
  const scenarioStart = exec.scenario.startTime;
  const holdStart = scenarioStart + (realtimeRampSeconds + realtimeJoinGraceSeconds) * 1000;
  const holdEnd = holdStart + realtimeHoldSeconds * 1000;
  const connectAt = scenarioStart + (__VU - 1) / targetVus * realtimeRampSeconds * 1000;
  sleep(Math.max(0, connectAt - Date.now()) / 1000);
  const fixtureIndex = (__VU - 1) % config.tokens.length;
  const accessToken = config.tokens[fixtureIndex];
  const userId = config.userIds[fixtureIndex];
  const socketUrl = config.baseUrl.replace(/^http/, "ws") +
    `/realtime/v1/websocket?apikey=${encodeURIComponent(config.anonKey)}&vsn=1.0.0`;
  const gate = createRealtimeHoldGate(holdStart, holdEnd);
  let intentionalClose = false;
  const startedAt = Date.now();
  const response = ws.connect(
    socketUrl,
    {
      headers: {
        apikey: config.anonKey,
        Authorization: `Bearer ${accessToken}`,
      },
      tags: { route: "realtime_socket" },
    },
    (socket) => {
      socket.on("open", () => {
        realtimeConnections.add(1);
        socket.send(JSON.stringify({
          topic: `realtime:load-${config.runId}-${__VU}`,
          event: "phx_join",
          payload: {
            config: {
              broadcast: { ack: false, self: false },
              presence: { key: "" },
              postgres_changes: [{
                event: "INSERT",
                schema: "public",
                table: "notifications",
                filter: `user_id=eq.${userId}`,
              }],
            },
            access_token: accessToken,
          },
          ref: "1",
          join_ref: "1",
        }));
      });
      socket.on("message", (raw) => {
        try {
          const message = JSON.parse(raw);
          gate.message(message, Date.now());
        } catch (_) {
          // Non-JSON transport messages are ignored; join state remains strict.
        }
      });
      socket.on("error", () => gate.fail("transport_error"));
      socket.setInterval(() => {
        socket.send(JSON.stringify({
          topic: "phoenix",
          event: "heartbeat",
          payload: {},
          ref: `hb-${Date.now()}`,
        }));
      }, 10000);
      socket.setTimeout(() => gate.begin(Date.now()), Math.max(1, holdStart - Date.now()));
      socket.setInterval(() => gate.sample(Date.now()), 5000);
      socket.setTimeout(() => {
        intentionalClose = true;
        socket.close();
      }, Math.max(1, holdEnd - Date.now()));
    },
  );
  const upgraded = check(response, {
    "Realtime WebSocket upgrades": (result) => result && result.status === 101,
  });
  const evidence = gate.finish(Date.now(), intentionalClose);
  realtimeUpgradeSuccess.add(upgraded);
  realtimeJoinSuccess.add(evidence.joined);
  realtimeSubscribedSuccess.add(evidence.subscribed);
  realtimeSustainedSuccess.add(upgraded && evidence.sustained);
  realtimeHeldConnections.add(upgraded && evidence.sustained ? 1 : 0);
  realtimeFailures.add(evidence.failure || !upgraded ? 1 : 0, {
    reason: !upgraded ? (response?.status === 429 ? "http_429" : "upgrade_rejected")
      : evidence.failure || "none",
  });
  realtimeSessionDuration.add(Date.now() - startedAt);
}

export function storageUploadStorm(config) {
  sleep(((__VU * 19 + __ITER * 7) % 1000) / 1000);
  const objectName = `${config.runId}/${__VU}-${__ITER}.bin`;
  const response = http.post(
    `${config.baseUrl}/storage/v1/object/${config.bucket}/${objectName}`,
    "S".repeat(1024),
    {
      ...serviceHeaders("storage_upload", "application/octet-stream"),
      headers: {
        ...serviceHeaders("storage_upload", "application/octet-stream").headers,
        "x-upsert": "false",
      },
    },
  );
  const ok = check(response, {
    "dedicated storage upload succeeds": (result) =>
      result.status === 200 || result.status === 201,
  });
  storageUploadSuccess.add(ok);
}

export function notificationQueueStorm(config) {
  sleep(((__VU * 11 + __ITER * 13) % 750) / 1000);
  const index = exec.scenario.iterationInTest;
  const userId = config.userIds[index % config.userIds.length];
  const response = http.post(
    `${config.baseUrl}/rest/v1/notifications`,
    JSON.stringify({
      user_id: userId,
      type: "profile_view",
      title: `Staging extended ${config.runId}`,
      body: `Disposable queue event ${index}`,
      deep_link: `silarah://notifications?load_run=${config.runId}&index=${index}`,
      scheduled_at: new Date(Date.now() + 60 * 60 * 1000).toISOString(),
      next_attempt_at: new Date(Date.now() + 60 * 60 * 1000).toISOString(),
    }),
    {
      ...serviceHeaders("notification_queue"),
      headers: {
        ...serviceHeaders("notification_queue").headers,
        Prefer: "return=minimal",
      },
    },
  );
  const ok = check(response, {
    "notification queue insert succeeds": (result) => result.status === 201,
  });
  notificationQueueSuccess.add(ok);
}

export function chatAndNotificationStorm(config) {
  // One authenticated member action per live VU. Four hundred independent
  // match rows avoid an artificial single-row lock bottleneck. The target run
  // spreads human actions across one minute; a sub-second 1,000-request burst
  // is retained as separate failure-boundary evidence, not launch traffic.
  const spreadMs = Math.max(1, Math.floor(chatSpreadSeconds * 1000));
  sleep(((__VU * 15485863) % spreadMs) / 1000);
  const index = exec.scenario.iterationInTest;
  const entry = config.chatMatches[index % config.chatMatches.length];
  const token = config.tokens[entry.senderIndex];
  const headers = {
    apikey: config.anonKey,
    Authorization: `Bearer ${token}`,
    "Content-Type": "application/json",
  };
  const write = http.post(
    `${config.baseUrl}/rest/v1/rpc/send_chat_message`,
    JSON.stringify({
      p_match_id: entry.matchId,
      p_content: "Assalamu alaikum. I hope you are well.",
    }),
    { headers, tags: { route: "chat_message" }, timeout: "20s" },
  );
  const writeOk = check(write, {
    "authorized chat message succeeds": (result) => result.status === 200,
  });
  if (!writeOk && index < 3) {
    console.error(`chat message rejected (${write.status}): ${write.body}`);
  }
  chatMessageSuccess.add(writeOk);

  const read = http.post(
    `${config.baseUrl}/rest/v1/rpc/get_chat_messages_v2`,
    JSON.stringify({
      p_match_id: entry.matchId,
      p_limit: 10,
      p_before_created_at: null,
      p_before_id: null,
    }),
    { headers, tags: { route: "chat_read" }, timeout: "20s" },
  );
  const readOk = check(read, {
    "authorized chat page succeeds": (result) => result.status === 200,
  });
  chatReadSuccess.add(readOk);
}

export function billingIdempotencyStorm(config) {
  sleep(((__VU * 23 + __ITER * 17) % 750) / 1000);
  // iterationInTest is global to this scenario; __ITER restarts at zero for
  // every VU and would collapse a shared-iteration storm into one event id.
  const pair = Math.floor(exec.scenario.iterationInTest / 2);
  const userId = config.userIds[pair % config.userIds.length];
  const eventTimestamp = runTimestampMs + pair;
  const response = http.post(
    `${config.baseUrl}/rest/v1/rpc/apply_revenuecat_subscription_event`,
    JSON.stringify({
      p_user_id: userId,
      p_provider_event_id: `staging-extended-${config.runId}-${pair}`,
      p_event_type: "INITIAL_PURCHASE",
      p_event_timestamp_ms: eventTimestamp,
      p_subscription_status: "active",
      p_subscription_expires_at: new Date(eventTimestamp + 30 * 86400000).toISOString(),
      p_product_id: "silarah_staging_load_monthly",
      p_currency: "INR",
      p_price: 300,
      p_event_expires_at: new Date(eventTimestamp + 30 * 86400000).toISOString(),
    }),
    serviceHeaders("billing_event"),
  );
  if (response.status !== 200 && __ITER === 0) {
    console.error(`billing event rejected (${response.status}): ${response.body}`);
  }
  const ok = check(response, {
    "billing core accepts or deduplicates event": (result) => result.status === 200,
  });
  billingEventSuccess.add(ok);
}
