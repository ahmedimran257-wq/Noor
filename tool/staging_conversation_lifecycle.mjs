#!/usr/bin/env node

// Self-contained, production-refusing staging contract for the complete
// two-account lifecycle. Every run creates disposable Auth/application rows
// and removes them in finally, so no shared fixture can become stale.

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
if (env.STAGING_PROJECT_REF === env.PRODUCTION_PROJECT_REF) {
  throw new Error("Refusing to run lifecycle automation against production");
}
const baseUrl = env.STAGING_SUPABASE_URL.replace(/\/$/, "");
if (!new URL(baseUrl).hostname.startsWith(`${env.STAGING_PROJECT_REF}.`)) {
  throw new Error("STAGING_SUPABASE_URL does not match STAGING_PROJECT_REF");
}

async function request(
  path,
  { token, apiKey, method = "GET", body, prefer } = {},
) {
  const key = apiKey ?? env.STAGING_SUPABASE_ANON_KEY;
  const response = await fetch(`${baseUrl}${path}`, {
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
    const error = new Error(message);
    error.status = response.status;
    error.data = data;
    throw error;
  }
  return data;
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

async function expectRejected(action, message) {
  let rejected = false;
  try {
    await action();
  } catch {
    rejected = true;
  }
  assert(rejected, message);
}

async function signIn(email, password) {
  return request("/auth/v1/token?grant_type=password", {
    method: "POST",
    body: { email, password },
  });
}

async function createAuthUser(email, password) {
  return request("/auth/v1/admin/users", {
    apiKey: service,
    method: "POST",
    body: { email, password, email_confirm: true },
  });
}

async function deleteWhere(table, query) {
  await request(`/rest/v1/${table}?${query}`, {
    apiKey: service,
    method: "DELETE",
    prefer: "return=minimal",
  }).catch(() => undefined);
}

const service = env.STAGING_SUPABASE_SERVICE_ROLE_KEY;
const runId = `${Date.now()}-${Math.random().toString(36).slice(2, 10)}`;
const femaleEmail = `female.${runId}@staging.silarah.invalid`;
const maleEmail = `male.${runId}@staging.silarah.invalid`;
const femalePassword = `F-${crypto.randomUUID()}-aA7!`;
const malePassword = `M-${crypto.randomUUID()}-aA7!`;

let femaleId;
let maleId;
let femaleProfileId;
let maleProfileId;

try {
  const country = await request(
    "/rest/v1/countries?iso_code=eq.IN&select=iso_code",
    { apiKey: service },
  );
  if (country.length === 0) {
    await request("/rest/v1/countries", {
      apiKey: service,
      method: "POST",
      prefer: "return=minimal",
      body: {
        iso_code: "IN",
        name: "India",
        dialing_code: "+91",
        currency: "INR",
        default_lang: "en",
        rtl: false,
        show_sect: true,
        show_sub_sect: true,
        wali_requirement: "recommended",
        pricing_tier: "tier_2",
        display_priority: 100,
      },
    });
  }

  const [femaleAuth, maleAuth] = await Promise.all([
    createAuthUser(femaleEmail, femalePassword),
    createAuthUser(maleEmail, malePassword),
  ]);
  femaleId = femaleAuth.id;
  maleId = maleAuth.id;
  assert(femaleId && maleId, "Disposable Auth users were not created");

  await request("/rest/v1/users", {
    apiKey: service,
    method: "POST",
    prefer: "return=minimal",
    body: [
      {
        id: femaleId,
        email: femaleEmail,
        country_code: "IN",
        gender: "female",
        onboarding_step: 5,
        onboarding_completed: true,
      },
      {
        id: maleId,
        email: maleEmail,
        country_code: "IN",
        gender: "male",
        onboarding_step: 5,
        onboarding_completed: true,
      },
    ],
  });

  const profiles = await request("/rest/v1/profiles", {
    apiKey: service,
    method: "POST",
    prefer: "return=representation",
    body: [
      {
        user_id: femaleId,
        first_name: "Staging Female",
        last_name: "Lifecycle",
        date_of_birth: "1998-01-01",
        gender: "female",
        country_code: "IN",
        visibility: "visible",
        onboarding_step: 14,
        onboarding_completed: true,
        completeness_score: 100,
        approved_at: new Date().toISOString(),
        marriage_timeline: "1_year",
        last_active_at: new Date().toISOString(),
      },
      {
        user_id: maleId,
        first_name: "Staging Male",
        last_name: "Lifecycle",
        date_of_birth: "1995-01-01",
        gender: "male",
        country_code: "IN",
        visibility: "visible",
        onboarding_step: 14,
        onboarding_completed: true,
        completeness_score: 100,
        approved_at: new Date().toISOString(),
        marriage_timeline: "1_year",
        last_active_at: new Date().toISOString(),
      },
    ],
  });
  femaleProfileId = profiles.find((row) => row.user_id === femaleId)?.id;
  maleProfileId = profiles.find((row) => row.user_id === maleId)?.id;
  assert(femaleProfileId && maleProfileId, "Disposable profiles were not created");

  await request("/rest/v1/photos", {
    apiKey: service,
    method: "POST",
    prefer: "return=minimal",
    body: [
      {
        profile_id: femaleProfileId,
        storage_path: `${femaleId}/staging-fixture.jpg`,
        status: "active",
        order_index: 0,
        admin_approved: true,
        nsfw_cleared: true,
        moderation_status: "approved",
      },
      {
        profile_id: maleProfileId,
        storage_path: `${maleId}/staging-fixture.jpg`,
        status: "active",
        order_index: 0,
        admin_approved: true,
        nsfw_cleared: true,
        moderation_status: "approved",
      },
    ],
  });

  const [femaleSession, maleSession] = await Promise.all([
    signIn(femaleEmail, femalePassword),
    signIn(maleEmail, malePassword),
  ]);
  const femaleToken = femaleSession.access_token;
  const maleToken = maleSession.access_token;

  // The repaired SECURITY INVOKER views preserve self-only and guardian-only
  // projections without granting direct SELECT on public.profiles.
  const femalePrivate = await request(
    "/rest/v1/my_profile_private?select=user_id,first_name",
    { token: femaleToken },
  );
  assert(
    femalePrivate.length === 1 && femalePrivate[0].user_id === femaleId,
    "Private profile view did not return exactly the signed-in member",
  );
  await request(`/rest/v1/profiles?user_id=eq.${femaleId}`, {
    apiKey: service,
    method: "PATCH",
    prefer: "return=minimal",
    body: { guardian_user_id: maleId },
  });
  const wards = await request(
    "/rest/v1/my_guardian_wards?select=id,user_id,first_name,last_name_initial,visibility",
    { token: maleToken },
  );
  assert(
    wards.length === 1 && wards[0].user_id === femaleId,
    "Guardian view did not return the authorized ward projection",
  );
  await request(`/rest/v1/profiles?user_id=eq.${femaleId}`, {
    apiKey: service,
    method: "PATCH",
    prefer: "return=minimal",
    body: { guardian_user_id: null },
  });
  console.log("PASS: private profile and guardian projection boundaries");

  const interestId = await request("/rest/v1/rpc/send_interest", {
    token: maleToken,
    method: "POST",
    body: { p_receiver_id: femaleId, p_note: "Staging lifecycle" },
  });
  await request("/rest/v1/rpc/respond_to_interest", {
    token: femaleToken,
    method: "POST",
    body: { p_interest_id: interestId, p_decision: "accepted" },
  });

  let pairMatches = await request(
    `/rest/v1/matches?select=id,status,created_at,closed_at&or=(and(user_a.eq.${femaleId},user_b.eq.${maleId}),and(user_a.eq.${maleId},user_b.eq.${femaleId}))&order=created_at.asc`,
    { apiKey: service },
  );
  assert(
    pairMatches.length === 1 && pairMatches[0].status === "active",
    "Interest acceptance did not create exactly one active match",
  );
  const firstMatchId = pairMatches[0].id;
  console.log("PASS: interest acceptance creates an active match");

  // Keep the visible fixture text intentionally number-free so chat safety
  // filters do not mistake the run identifier for contact information.
  const marker = "Staging lifecycle verification message";
  const sent = await request("/rest/v1/rpc/send_chat_message", {
    token: femaleToken,
    method: "POST",
    body: { p_match_id: firstMatchId, p_content: marker },
  });
  const markerMessageId = sent[0]?.message_id;
  assert(markerMessageId, "Female fixture message was not created");

  await request("/rest/v1/rpc/close_chat_match", {
    token: femaleToken,
    method: "POST",
    body: {
      p_match_id: firstMatchId,
      p_closure_reason: "Staging lifecycle contract verification.",
    },
  });
  const freeAccess = await request("/rest/v1/rpc/can_open_chat", {
    token: maleToken,
    method: "POST",
    body: { p_match_id: firstMatchId },
  });
  assert(
    freeAccess[0]?.allowed === false &&
      freeAccess[0]?.reason === "subscription_required",
    "Free male did not receive the Premium gate after female closure",
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
    token: maleToken,
    method: "POST",
    body: { p_match_id: firstMatchId },
  });
  assert(
    premiumAccess[0]?.allowed === true &&
      premiumAccess[0]?.reason === "read_only",
    "Premium activation did not unlock ended history as read-only",
  );
  const history = await request("/rest/v1/rpc/get_chat_messages", {
    token: maleToken,
    method: "POST",
    body: { p_match_id: firstMatchId, p_limit: 100, p_before: null },
  });
  assert(
    history.some((message) => message.id === markerMessageId),
    "Unlocked history omitted the fixture message",
  );
  await expectRejected(
    () =>
      request("/rest/v1/rpc/send_chat_message", {
        token: maleToken,
        method: "POST",
        body: {
          p_match_id: firstMatchId,
          p_content: "This write must remain blocked.",
        },
      }),
    "Ended conversation accepted a message after Premium unlock",
  );
  console.log("PASS: female close -> Premium gate -> read-only history");

  await expectRejected(
    () =>
      request("/rest/v1/rpc/send_interest", {
        token: maleToken,
        method: "POST",
        body: { p_receiver_id: femaleId, p_note: null },
      }),
    "Immediate rematch bypassed the seven-day cooldown",
  );
  await request(`/rest/v1/matches?id=eq.${firstMatchId}`, {
    apiKey: service,
    method: "PATCH",
    prefer: "return=minimal",
    body: { closed_at: new Date(Date.now() - 8 * 86_400_000).toISOString() },
  });

  const discovery = await request("/rest/v1/rpc/get_discovery_feed", {
    token: maleToken,
    method: "POST",
    body: {
      p_viewer_id: maleId,
      p_cursor_score: null,
      p_cursor_id: null,
      p_page_size: 20,
      p_filters: {},
    },
  });
  assert(
    discovery.some((row) => row.user_id === femaleId),
    "Cooled-down profile did not reappear in Discovery",
  );
  const priorContext = await request(
    "/rest/v1/rpc/get_prior_match_context",
    {
      token: maleToken,
      method: "POST",
      body: { p_candidate_user_ids: [femaleId] },
    },
  );
  assert(
    priorContext[0]?.candidate_user_id === femaleId &&
      priorContext[0]?.prior_match_count === 1,
    "Discovery did not disclose the previous match context",
  );

  const rematchInterestId = await request("/rest/v1/rpc/send_interest", {
    token: maleToken,
    method: "POST",
    body: { p_receiver_id: femaleId, p_note: "Respectful rematch" },
  });
  await request("/rest/v1/rpc/respond_to_interest", {
    token: femaleToken,
    method: "POST",
    body: { p_interest_id: rematchInterestId, p_decision: "accepted" },
  });
  pairMatches = await request(
    `/rest/v1/matches?select=id,status,created_at&or=(and(user_a.eq.${femaleId},user_b.eq.${maleId}),and(user_a.eq.${maleId},user_b.eq.${femaleId}))&order=created_at.asc`,
    { apiKey: service },
  );
  const secondMatch = pairMatches.find((match) => match.status === "active");
  assert(
    pairMatches.length === 2 && secondMatch && secondMatch.id !== firstMatchId,
    "Rematch did not create a separate active match cycle",
  );
  console.log("PASS: cooldown -> Discovery disclosure -> separate rematch cycle");

  const reportMarker = await request("/rest/v1/rpc/send_chat_message", {
    token: femaleToken,
    method: "POST",
    body: {
      p_match_id: secondMatch.id,
      p_content: "Staging report verification message",
    },
  });
  const reportMessageId = reportMarker[0]?.message_id;
  await request("/rest/v1/rpc/submit_user_report", {
    token: maleToken,
    method: "POST",
    body: {
      p_reported_user_id: femaleId,
      p_reason: "harassment",
      p_description: "Automated staging report contract.",
    },
  });
  await request("/rest/v1/rpc/report_chat_message", {
    token: maleToken,
    method: "POST",
    body: {
      p_message_id: reportMessageId,
      p_reason: "harassment",
      p_description: "Automated staging message report contract.",
    },
  });
  const reportedMatch = await request(
    `/rest/v1/matches?id=eq.${secondMatch.id}&select=status`,
    { apiKey: service },
  );
  const profileReports = await request(
    `/rest/v1/reports?reporter_id=eq.${maleId}&reported_user_id=eq.${femaleId}&select=id`,
    { apiKey: service },
  );
  assert(
    reportedMatch[0]?.status === "reported" && profileReports.length === 1,
    "Report flow did not preserve evidence and close the active match",
  );
  await expectRejected(
    () =>
      request("/rest/v1/rpc/send_interest", {
        token: maleToken,
        method: "POST",
        body: { p_receiver_id: femaleId, p_note: null },
      }),
    "Reported pair was allowed to match again",
  );
  console.log("PASS: profile/message reporting preserves evidence and prevents rematch");

  // Isolate the block contract from the report contract using service-only
  // fixture cleanup; this is never permitted against production.
  await deleteWhere("message_reports", `reporter_id=eq.${maleId}`);
  await deleteWhere(
    "reports",
    `reporter_id=eq.${maleId}&reported_user_id=eq.${femaleId}`,
  );
  await request(`/rest/v1/matches?id=eq.${secondMatch.id}`, {
    apiKey: service,
    method: "PATCH",
    prefer: "return=minimal",
    body: {
      status: "active",
      closed_by: null,
      closed_at: null,
      closure_reason: null,
    },
  });
  await request("/rest/v1/rpc/block_member", {
    token: femaleToken,
    method: "POST",
    body: { p_user_id: maleId, p_reason: "staging_contract" },
  });
  const blockedMatch = await request(
    `/rest/v1/matches?id=eq.${secondMatch.id}&select=status`,
    { apiKey: service },
  );
  const blocks = await request(
    `/rest/v1/blocks?blocker_id=eq.${femaleId}&blocked_id=eq.${maleId}&select=blocker_id`,
    { apiKey: service },
  );
  assert(
    blockedMatch[0]?.status === "blocked" && blocks.length === 1,
    "Block flow did not sever the active match",
  );
  await expectRejected(
    () =>
      request("/rest/v1/rpc/send_interest", {
        token: maleToken,
        method: "POST",
        body: { p_receiver_id: femaleId, p_note: null },
      }),
    "Blocked pair was allowed to match again",
  );
  console.log("PASS: blocking severs the match and permanently prevents rematch");

  console.log("PASS: complete disposable two-account staging lifecycle");
} finally {
  if (femaleId && maleId) {
    const pair = `(${femaleId},${maleId})`;
    await deleteWhere("message_reports", `reporter_id=in.${pair}`);
    await deleteWhere("reports", `reporter_id=in.${pair}`);
    await deleteWhere("blocks", `blocker_id=in.${pair}`);
    await deleteWhere("messages", `sender_id=in.${pair}`);
    await deleteWhere("interests", `sender_id=in.${pair}`);
    await deleteWhere("matches", `user_a=in.${pair}`);
    await deleteWhere("photos", `profile_id=in.(${femaleProfileId},${maleProfileId})`);
    await deleteWhere("profiles", `user_id=in.${pair}`);
    await deleteWhere("users", `id=in.${pair}`);
  }
  for (const userId of [femaleId, maleId]) {
    if (!userId) continue;
    await request(`/auth/v1/admin/users/${userId}`, {
      apiKey: service,
      method: "DELETE",
    }).catch(() => undefined);
  }
}
