#!/usr/bin/env node

// Destructive-state-safe staging smoke test for the two-account contract:
// woman closes -> free man sees Premium -> Premium unlocks history read-only.
// It uses two dedicated staging accounts and restores the original match and
// subscription rows in a finally block.

const required = [
  "STAGING_SUPABASE_URL",
  "STAGING_SUPABASE_ANON_KEY",
  "STAGING_SUPABASE_SERVICE_ROLE_KEY",
  "STAGING_PROJECT_REF",
  "PRODUCTION_PROJECT_REF",
  "STAGING_FEMALE_EMAIL",
  "STAGING_FEMALE_PASSWORD",
  "STAGING_MALE_EMAIL",
  "STAGING_MALE_PASSWORD",
];

for (const name of required) {
  if (!process.env[name]) throw new Error(`Missing required environment variable: ${name}`);
}

const env = process.env;
if (env.STAGING_PROJECT_REF === env.PRODUCTION_PROJECT_REF) {
  throw new Error("Refusing to run lifecycle automation against production");
}
const baseUrl = env.STAGING_SUPABASE_URL.replace(/\/$/, "");
if (!new URL(baseUrl).hostname.startsWith(`${env.STAGING_PROJECT_REF}.`)) {
  throw new Error("STAGING_SUPABASE_URL does not match STAGING_PROJECT_REF");
}

async function request(path, { token, apiKey, method = "GET", body, prefer } = {}) {
  const response = await fetch(`${baseUrl}${path}`, {
    method,
    headers: {
      apikey: apiKey ?? env.STAGING_SUPABASE_ANON_KEY,
      Authorization: `Bearer ${token ?? apiKey ?? env.STAGING_SUPABASE_ANON_KEY}`,
      "Content-Type": "application/json",
      ...(prefer ? { Prefer: prefer } : {}),
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await response.text();
  const data = text ? JSON.parse(text) : null;
  if (!response.ok) {
    const message = data?.message ?? data?.error_description ?? `HTTP ${response.status}`;
    const error = new Error(message);
    error.status = response.status;
    throw error;
  }
  return data;
}

async function signIn(email, password) {
  return request("/auth/v1/token?grant_type=password", {
    method: "POST",
    body: { email, password },
  });
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

const service = env.STAGING_SUPABASE_SERVICE_ROLE_KEY;
let originalMatch;
let originalMaleSubscription;
let matchId;
let markerMessageId;

try {
  const [femaleSession, maleSession] = await Promise.all([
    signIn(env.STAGING_FEMALE_EMAIL, env.STAGING_FEMALE_PASSWORD),
    signIn(env.STAGING_MALE_EMAIL, env.STAGING_MALE_PASSWORD),
  ]);
  const femaleId = femaleSession.user.id;
  const maleId = maleSession.user.id;

  const accounts = await request(
    `/rest/v1/users?select=id,gender,subscription_status,subscription_expires_at&id=in.(${femaleId},${maleId})`,
    { apiKey: service },
  );
  const femaleAccount = accounts.find((row) => row.id === femaleId);
  const maleAccount = accounts.find((row) => row.id === maleId);
  assert(femaleAccount?.gender === "female", "Dedicated female account has the wrong gender");
  assert(maleAccount?.gender === "male", "Dedicated male account has the wrong gender");
  originalMaleSubscription = {
    subscription_status: maleAccount.subscription_status,
    subscription_expires_at: maleAccount.subscription_expires_at,
  };

  const pairFilter = encodeURIComponent(
    `and(user_a.eq.${femaleId},user_b.eq.${maleId}),and(user_a.eq.${maleId},user_b.eq.${femaleId})`,
  );
  const matches = await request(
    `/rest/v1/matches?select=id,status,closed_by,closed_at,closure_reason&or=(${pairFilter})&limit=1`,
    { apiKey: service },
  );
  assert(matches.length === 1, "Dedicated staging accounts must have an existing match");
  originalMatch = matches[0];
  matchId = originalMatch.id;

  await request(`/rest/v1/matches?id=eq.${matchId}`, {
    apiKey: service,
    method: "PATCH",
    prefer: "return=minimal",
    body: { status: "active", closed_by: null, closed_at: null, closure_reason: null },
  });
  await request(`/rest/v1/users?id=eq.${maleId}`, {
    apiKey: service,
    method: "PATCH",
    prefer: "return=minimal",
    body: { subscription_status: "none", subscription_expires_at: null },
  });

  const marker = `staging-lifecycle-${Date.now()}`;
  const sent = await request("/rest/v1/rpc/send_chat_message", {
    token: femaleSession.access_token,
    method: "POST",
    body: { p_match_id: matchId, p_content: marker },
  });
  markerMessageId = sent[0]?.message_id;
  assert(markerMessageId, "Female fixture message was not created");

  await request("/rest/v1/rpc/close_chat_match", {
    token: femaleSession.access_token,
    method: "POST",
    body: {
      p_match_id: matchId,
      p_closure_reason: "Staging lifecycle contract verification.",
    },
  });

  const freeAccess = await request("/rest/v1/rpc/can_open_chat", {
    token: maleSession.access_token,
    method: "POST",
    body: { p_match_id: matchId },
  });
  assert(
    freeAccess[0]?.allowed === false && freeAccess[0]?.reason === "subscription_required",
    "Free male did not receive the Premium gate after the female ended the match",
  );

  await request(`/rest/v1/users?id=eq.${maleId}`, {
    apiKey: service,
    method: "PATCH",
    prefer: "return=minimal",
    body: {
      subscription_status: "active",
      subscription_expires_at: new Date(Date.now() + 86_400_000).toISOString(),
    },
  });

  const premiumAccess = await request("/rest/v1/rpc/can_open_chat", {
    token: maleSession.access_token,
    method: "POST",
    body: { p_match_id: matchId },
  });
  assert(
    premiumAccess[0]?.allowed === true && premiumAccess[0]?.reason === "read_only",
    "Premium activation did not unlock the ended history as read-only",
  );

  const history = await request("/rest/v1/rpc/get_chat_messages", {
    token: maleSession.access_token,
    method: "POST",
    body: { p_match_id: matchId, p_limit: 100, p_before: null },
  });
  assert(history.some((message) => message.id === markerMessageId), "Unlocked history omitted the fixture message");

  let writeRejected = false;
  try {
    await request("/rest/v1/rpc/send_chat_message", {
      token: maleSession.access_token,
      method: "POST",
      body: { p_match_id: matchId, p_content: "This write must remain blocked." },
    });
  } catch {
    writeRejected = true;
  }
  assert(writeRejected, "Ended conversation accepted a new message after Premium unlock");

  console.log("PASS: female close -> free male Premium gate -> Premium read-only history");
} finally {
  if (markerMessageId) {
    await request(`/rest/v1/messages?id=eq.${markerMessageId}`, {
      apiKey: service,
      method: "DELETE",
      prefer: "return=minimal",
    }).catch(() => undefined);
  }
  if (matchId && originalMatch) {
    await request(`/rest/v1/matches?id=eq.${matchId}`, {
      apiKey: service,
      method: "PATCH",
      prefer: "return=minimal",
      body: {
        status: originalMatch.status,
        closed_by: originalMatch.closed_by,
        closed_at: originalMatch.closed_at,
        closure_reason: originalMatch.closure_reason,
      },
    }).catch(() => undefined);
  }
  if (originalMaleSubscription) {
    const maleSession = await signIn(
      env.STAGING_MALE_EMAIL,
      env.STAGING_MALE_PASSWORD,
    ).catch(() => null);
    if (maleSession) {
      await request(`/rest/v1/users?id=eq.${maleSession.user.id}`, {
        apiKey: service,
        method: "PATCH",
        prefer: "return=minimal",
        body: originalMaleSubscription,
      }).catch(() => undefined);
    }
  }
}
