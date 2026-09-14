import http from "k6/http";
import { check, fail, sleep } from "k6";

const productionProjectRef = "jukpscfxzwttgtxvrbmj";
const targetEnvironment = (__ENV.TARGET_ENV || "").trim().toLowerCase();
const baseUrl = (__ENV.SUPABASE_URL || "").trim().replace(/\/$/, "");
const stagingProjectRef = (__ENV.STAGING_PROJECT_REF || "").trim();
const anonKey = (__ENV.SUPABASE_ANON_KEY || "").trim();
const tokens = (__ENV.TEST_USER_TOKENS || "")
  .split(",")
  .map((value) => value.trim())
  .filter(Boolean);
const userIds = (__ENV.TEST_USER_IDS || "")
  .split(",")
  .map((value) => value.trim())
  .filter(Boolean);
const peakVus = Number(__ENV.MAX_VUS || 600);
const scaleAcknowledgement = (__ENV.SCALE_LOAD_ACK || "").trim();

function scaleStages(peak) {
  const stages = [
    { duration: "30s", target: 50 },
    { duration: "1m", target: 150 },
    { duration: "90s", target: 300 },
    { duration: "2m", target: 600 },
    { duration: "3m", target: 600 },
  ];
  if (peak >= 800) {
    stages.push(
      { duration: "90s", target: 800 },
      { duration: "3m", target: 800 },
    );
  }
  if (peak >= 1000) {
    stages.push(
      { duration: "90s", target: 1000 },
      { duration: "3m", target: 1000 },
    );
  }
  stages.push({ duration: "90s", target: 0 });
  return stages;
}

export const options = {
  scenarios: {
    realistic_member_sessions: {
      executor: "ramping-vus",
      startVUs: 0,
      stages: scaleStages(peakVus),
      gracefulRampDown: "30s",
      gracefulStop: "30s",
    },
  },
  thresholds: {
    // Stop a scale run rather than spending quota while the service is
    // materially unhealthy. The latency gate permits brief warm-up variance
    // on the staging Nano tier while retaining a strict steady-state SLO.
    checks: [
      { threshold: "rate>0.99", abortOnFail: true, delayAbortEval: "1m" },
    ],
    http_req_failed: [
      { threshold: "rate<0.01", abortOnFail: true, delayAbortEval: "1m" },
    ],
    http_req_duration: [
      { threshold: "p(95)<2500", abortOnFail: true, delayAbortEval: "2m" },
      "p(99)<5000",
    ],
    "http_req_duration{route:discovery_feed}": ["p(95)<3500"],
    "http_req_duration{route:notification_inbox}": ["p(95)<2500"],
    "http_req_duration{route:interest_quota}": ["p(95)<2500"],
    "http_req_duration{route:profile_view_quota}": ["p(95)<2500"],
    "http_req_duration{route:filter_access}": ["p(95)<2500"],
    "http_req_duration{route:country_catalog}": ["p(95)<2500"],
  },
  discardResponseBodies: true,
  noConnectionReuse: false,
  summaryTrendStats: ["avg", "min", "med", "max", "p(90)", "p(95)", "p(99)"],
  userAgent: "SilarahStagingScaleTest/1.0",
};

export function setup() {
  if (targetEnvironment !== "staging") {
    fail("Safety stop: TARGET_ENV must equal staging.");
  }
  if (![600, 800, 1000].includes(peakVus)) {
    fail("Safety stop: scale peak must be 600, 800, or 1000 VUs.");
  }
  if (scaleAcknowledgement !== "I_UNDERSTAND_STAGING_SCALE_LOAD") {
    fail("Safety stop: explicit scale acknowledgement is required.");
  }
  if (!baseUrl || !anonKey || !stagingProjectRef || tokens.length === 0) {
    fail("Safety stop: staging URL, ref, key and sessions are required.");
  }
  if (tokens.length !== userIds.length) {
    fail("Safety stop: every disposable token requires its matching user id.");
  }
  if (
    baseUrl.includes(productionProjectRef) ||
    baseUrl.includes("silarah.com") ||
    stagingProjectRef === productionProjectRef ||
    !baseUrl.includes(stagingProjectRef)
  ) {
    fail("Safety stop: production or mismatched project detected.");
  }
  return { baseUrl, anonKey, tokens, userIds };
}

function requestParams(config, route) {
  const fixtureIndex = (__VU - 1) % config.tokens.length;
  return {
    fixtureIndex,
    headers: {
      apikey: config.anonKey,
      Authorization: `Bearer ${config.tokens[fixtureIndex]}`,
      "Content-Type": "application/json",
    },
    tags: { route },
    timeout: "15s",
  };
}

function executeMemberAction(config) {
  // The deterministic mix avoids synchronized bursts and resembles an active
  // session: Discovery dominates, while quotas, notifications, filters and
  // shared catalogue reads occur less often. Each iteration performs one
  // bounded request rather than an artificial six-request batch.
  const choice = (__VU * 17 + __ITER * 29) % 100;
  let response;
  let label;

  if (__ITER === 0) {
    label = "auth_user";
    const params = requestParams(config, label);
    response = http.get(`${config.baseUrl}/auth/v1/user`, params);
  } else if (choice < 35) {
    label = "discovery_feed";
    const params = requestParams(config, label);
    response = http.post(
      `${config.baseUrl}/rest/v1/rpc/get_discovery_feed`,
      JSON.stringify({
        p_viewer_id: config.userIds[params.fixtureIndex],
        p_cursor_score: null,
        p_cursor_id: null,
        p_page_size: 10,
        p_filters: {},
      }),
      params,
    );
  } else if (choice < 55) {
    label = "notification_inbox";
    const params = requestParams(config, label);
    response = http.get(
      `${config.baseUrl}/rest/v1/notifications?select=id,type,created_at&order=created_at.desc&limit=20`,
      params,
    );
  } else if (choice < 68) {
    label = "interest_quota";
    const params = requestParams(config, label);
    response = http.post(
      `${config.baseUrl}/rest/v1/rpc/get_interest_quota`,
      "{}",
      params,
    );
  } else if (choice < 81) {
    label = "profile_view_quota";
    const params = requestParams(config, label);
    response = http.post(
      `${config.baseUrl}/rest/v1/rpc/get_profile_view_quota`,
      "{}",
      params,
    );
  } else if (choice < 91) {
    label = "filter_access";
    const params = requestParams(config, label);
    response = http.post(
      `${config.baseUrl}/rest/v1/rpc/get_discovery_filter_access`,
      "{}",
      params,
    );
  } else {
    label = "country_catalog";
    const params = requestParams(config, label);
    response = http.get(
      `${config.baseUrl}/rest/v1/countries?select=iso_code,name,pricing_tier&limit=250`,
      params,
    );
  }

  check(response, {
    [`${label} responds successfully`]: (result) => result.status === 200,
  });
}

export default function (config) {
  executeMemberAction(config);
  // Stable per-VU jitter spreads requests across 8–16 seconds. At 1,000 VUs
  // this represents roughly 83 requests/second instead of a wasteful 6,000
  // request/second synthetic burst that no human-operated app would produce.
  sleep(8 + ((__VU * 7 + __ITER * 3) % 9));
}
