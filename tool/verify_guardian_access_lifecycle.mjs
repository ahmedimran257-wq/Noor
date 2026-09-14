// Staging-only, disposable integration proof for Guardian access revocation and
// self-notification suppression. Credentials and message text are never logged.
import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { spawnSync } from "node:child_process";
import { join } from "node:path";

const staging = "ykmgkrveucslglxvcyss";
const production = "jukpscfxzwttgtxvrbmj";
assert.notEqual(staging, production);
const base = `https://${staging}.supabase.co`;
const cli = join(process.env.LOCALAPPDATA, "Silarah/supabase/supabase.exe");
const keyResult = spawnSync(
  cli,
  ["projects", "api-keys", "--project-ref", staging, "--output", "json"],
  { encoding: "utf8", windowsHide: true, timeout: 30_000 },
);
assert.equal(keyResult.status, 0, "Staging key lookup failed");
const keys = JSON.parse(keyResult.stdout);
const anon = keys.find((key) => key.name === "anon")?.api_key;
const service = keys.find((key) => key.name === "service_role")?.api_key;
assert.ok(anon && service, "Staging keys unavailable");

async function request(path, {
  token,
  admin = false,
  method = "GET",
  body,
  expected,
  prefer,
} = {}) {
  const apiKey = admin ? service : anon;
  const response = await fetch(base + path, {
    method,
    headers: {
      apikey: apiKey,
      Authorization: `Bearer ${token ?? apiKey}`,
      "Content-Type": "application/json",
      ...(prefer ? { Prefer: prefer } : {}),
    },
    body: body === undefined ? undefined : JSON.stringify(body),
    signal: AbortSignal.timeout(20_000),
  });
  const data = await response.json().catch(() => null);
  if (!(expected ? expected.includes(response.status) : response.ok)) {
    throw new Error(
      `${method} ${path.split("?")[0]} failed (${response.status}; ${data?.code ?? "no-code"})`,
    );
  }
  return { status: response.status, data };
}

const rpc = (name, token, body, expected) => request(
  `/rest/v1/rpc/${name}`,
  { method: "POST", token, body, expected },
);

const runId = randomUUID();
const fixtures = [];
let proof;
async function createUser(role) {
  const email = `guardian.lifecycle.${runId}.${role}@staging.silarah.invalid`;
  const password = `G-${randomUUID()}-aA7!`;
  const result = await request("/auth/v1/admin/users", {
    admin: true,
    method: "POST",
    body: {
      email,
      password,
      email_confirm: true,
      user_metadata: { guardian_lifecycle_run: runId },
    },
  });
  const fixture = { role, id: result.data.id, email, password };
  fixtures.push(fixture);
  return fixture;
}

async function signIn(fixture) {
  const result = await request("/auth/v1/token?grant_type=password", {
    method: "POST",
    body: { email: fixture.email, password: fixture.password },
  });
  assert.equal(result.data.user.id, fixture.id);
  return result.data.access_token;
}

try {
  const ward = await createUser("ward");
  const counterpart = await createUser("counterpart");
  const guardian = await createUser("guardian");
  await request("/rest/v1/users", {
    admin: true,
    method: "POST",
    body: fixtures.map((fixture) => ({
      id: fixture.id,
      email: fixture.email,
      country_code: "IN",
      timezone: "Asia/Kolkata",
      gender: fixture.role === "counterpart" ? "male" : "female",
      onboarding_step: fixture.role === "guardian" ? 0 : 5,
      onboarding_completed: fixture.role !== "guardian",
    })),
  });
  const cities = await request(
    "/rest/v1/cities?select=id,regions!inner(country_code)&regions.country_code=eq.IN&limit=1",
    { admin: true },
  );
  assert.ok(cities.data?.[0]?.id, "Staging India city missing");
  const now = new Date().toISOString();
  await request("/rest/v1/profiles", {
    admin: true,
    method: "POST",
    body: [ward, counterpart].map((fixture) => ({
      user_id: fixture.id,
      first_name: fixture.role === "ward" ? "Amina" : "Yusuf",
      last_name: "Lifecycle QA",
      date_of_birth: "1996-01-01",
      gender: fixture.role === "ward" ? "female" : "male",
      country_code: "IN",
      city_id: cities.data[0].id,
      sect: "Sunni",
      deen_level: "practicing",
      bio: "Disposable staging Guardian lifecycle verification.",
      visibility: "visible",
      onboarding_step: 14,
      onboarding_completed: true,
      completeness_score: 100,
      approved_at: now,
      last_active_at: now,
    })),
  });
  const match = await request("/rest/v1/matches?select=id", {
    admin: true,
    method: "POST",
    prefer: "return=representation",
    body: { user_a: counterpart.id, user_b: ward.id, status: "active" },
  });
  const matchId = match.data[0].id;
  const wardToken = await signIn(ward);
  const guardianToken = await signIn(guardian);
  const invite = await rpc("save_my_guardian_configuration", wardToken, {
    p_enabled: true,
    p_can_reply: true,
    p_name: "Guardian Lifecycle QA",
    p_relationship: "sister",
    p_email: guardian.email,
  });
  const accepted = await rpc("accept_my_guardian_invitation", guardianToken, {
    p_code: invite.data.invitation_code,
  });
  assert.equal(accepted.data.status, "activated");
  assert.equal((await rpc("has_my_linked_wards", guardianToken)).data, true);
  const initialState = await request(
    "/rest/v1/guardian_access_state?select=revision",
    { token: guardianToken },
  );
  assert.equal(initialState.data.length, 1);
  const initialRevision = Number(initialState.data[0].revision);
  assert.ok(initialRevision >= 1);
  const dashboard = await rpc("get_guardian_dashboard_v2", guardianToken, {
    p_mark_seen_ward_id: null,
  });
  assert.equal(dashboard.data.length, 1);
  assert.equal(dashboard.data[0].match_id, matchId);
  await rpc("guardian_approve_match", guardianToken, { p_match_id: matchId });

  const guardianNotices = () => request(
    `/rest/v1/notifications?user_id=eq.${guardian.id}&type=eq.guardian_message_mirror&select=id,body`,
    { admin: true },
  );
  const noticeCount = (await guardianNotices()).data.length;
  await rpc("send_chat_message_idempotent", guardianToken, {
    p_match_id: matchId,
    p_content: "Guardian lifecycle verification reply.",
    p_operation_id: randomUUID(),
    p_as_guardian: true,
  });
  assert.equal((await guardianNotices()).data.length, noticeCount);
  await rpc("send_chat_message_idempotent", wardToken, {
    p_match_id: matchId,
    p_content: "Ward lifecycle verification reply.",
    p_operation_id: randomUUID(),
  });
  const wardMessageNotices = (await guardianNotices()).data;
  assert.equal(wardMessageNotices.length, noticeCount + 1);
  assert.equal(wardMessageNotices.at(-1).body, "Open Silarah to review the conversation.");

  await rpc("save_my_guardian_configuration", wardToken, { p_enabled: false });
  assert.equal((await rpc("has_my_linked_wards", guardianToken)).data, false);
  const revokedState = await request(
    "/rest/v1/guardian_access_state?select=revision",
    { token: guardianToken },
  );
  assert.ok(Number(revokedState.data[0].revision) > initialRevision);
  assert.deepEqual(
    (await rpc("get_guardian_dashboard_v2", guardianToken, {
      p_mark_seen_ward_id: null,
    })).data,
    [],
  );
  await rpc("get_guardian_match_messages", guardianToken, {
    p_match_id: matchId,
    p_before_created_at: null,
    p_before_id: null,
    p_limit: 50,
  }, [400, 403]);

  proof = {
    project: staging,
    disposableAccounts: fixtures.length,
    accessRevisionAdvanced: true,
    revokedDashboardEmpty: true,
    revokedTranscriptDenied: true,
    guardianSelfNotificationSuppressed: true,
    wardMessageNotificationRetained: true,
    notificationBodyContainsMessageText: false,
  };
} finally {
  for (const fixture of fixtures) {
    await request(`/rest/v1/users?id=eq.${fixture.id}`, {
      admin: true,
      method: "DELETE",
      expected: [200, 204],
    });
    await request(`/auth/v1/admin/users/${fixture.id}`, {
      admin: true,
      method: "DELETE",
      expected: [200, 404],
    });
    const remaining = await request(
      `/rest/v1/users?id=eq.${fixture.id}&select=id`,
      { admin: true },
    );
    assert.deepEqual(remaining.data, []);
    await request(`/auth/v1/admin/users/${fixture.id}`, {
      admin: true,
      expected: [404],
    });
  }
}
assert.ok(proof);
console.log(JSON.stringify({ ...proof, cleanupVerified: true }));
