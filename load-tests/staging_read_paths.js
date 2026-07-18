import http from "k6/http";
import { check, fail } from "k6";
import { randomItem } from "https://jslib.k6.io/k6-utils/1.4.0/index.js";

const productionProjectRef = "jukpscfxzwttgtxvrbmj";
const targetEnvironment = (__ENV.TARGET_ENV || "").trim().toLowerCase();
const baseUrl = (__ENV.SUPABASE_URL || "").trim().replace(/\/$/, "");
const stagingProjectRef = (__ENV.STAGING_PROJECT_REF || "").trim();
const anonKey = (__ENV.SUPABASE_ANON_KEY || "").trim();
const tokens = (__ENV.TEST_USER_TOKENS || "")
  .split(",")
  .map((token) => token.trim())
  .filter(Boolean);
const maxVus = Math.min(Math.max(Number(__ENV.MAX_VUS || 25), 1), 50);

export const options = {
  scenarios: {
    authenticated_reads: {
      executor: "ramping-vus",
      startVUs: 0,
      stages: [
        { duration: "30s", target: Math.min(5, maxVus) },
        { duration: "2m", target: maxVus },
        { duration: "30s", target: 0 },
      ],
      gracefulRampDown: "15s",
    },
  },
  thresholds: {
    checks: ["rate>0.99"],
    http_req_failed: ["rate<0.01"],
    http_req_duration: ["p(95)<750", "p(99)<1500"],
  },
  noConnectionReuse: false,
  userAgent: "SilarahStagingLoadTest/1.0",
};

export function setup() {
  if (targetEnvironment !== "staging") {
    fail("Safety stop: TARGET_ENV must equal staging.");
  }
  if (!baseUrl || !anonKey || tokens.length === 0 || !stagingProjectRef) {
    fail(
      "Safety stop: SUPABASE_URL, STAGING_PROJECT_REF, SUPABASE_ANON_KEY and TEST_USER_TOKENS are required.",
    );
  }
  if (
    baseUrl.includes(productionProjectRef) ||
    baseUrl.includes("silarah.com") ||
    stagingProjectRef === productionProjectRef ||
    !baseUrl.includes(stagingProjectRef)
  ) {
    fail("Safety stop: production or mismatched project detected.");
  }
  return { baseUrl, anonKey, tokens };
}

export default function (config) {
  const token = randomItem(config.tokens);
  const headers = {
    apikey: config.anonKey,
    Authorization: `Bearer ${token}`,
    "Content-Type": "application/json",
  };

  const responses = http.batch([
    ["GET", `${config.baseUrl}/auth/v1/user`, null, {
      headers,
      tags: { route: "auth_user" },
    }],
    ["POST", `${config.baseUrl}/rest/v1/rpc/get_interest_quota`, "{}", {
      headers,
      tags: { route: "interest_quota" },
    }],
    ["POST", `${config.baseUrl}/rest/v1/rpc/get_profile_view_quota`, "{}", {
      headers,
      tags: { route: "profile_view_quota" },
    }],
  ]);

  check(responses[0], {
    "auth session is valid": (response) => response.status === 200,
  });
  check(responses[1], {
    "interest quota responds": (response) => response.status === 200,
  });
  check(responses[2], {
    "view quota responds": (response) => response.status === 200,
  });
}
