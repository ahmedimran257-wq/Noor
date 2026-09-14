import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";

// Called only by the staging-only fixture runner; no credentials or message
// content are written to the resulting evidence report.
export async function verifyChatRetrySafety({ request, service, sessions, fixtures, chatMatches }) {
  const rpc = (name, token, body, expectedStatuses) => request(`/rest/v1/rpc/${name}`, {
    method: "POST", token, body, expectedStatuses,
  });
  const tokenFor = (index) => sessions[index].access_token;
  const send = (token, body, expectedStatuses) =>
    rpc("send_chat_message_idempotent", token, body, expectedStatuses);
  const match = chatMatches.find((m) => m.senderIndex === 1);
  assert.ok(match, "Need a disposable female sender and active match");
  const body = { p_match_id: match.matchId, p_content: "Assalamu alaikum, wishing you a good day.", p_operation_id: randomUUID() };
  const countMessages = async (matchId) => (await request(
    `/rest/v1/messages?match_id=eq.${matchId}&select=id,sender_id,sent_by_guardian&limit=1000`,
    { apiKey: service },
  )).data;
  const before = await countMessages(match.matchId);
  const retries = await Promise.all(Array.from({ length: 20 }, () => send(tokenFor(1), body)));
  const ids = new Set(retries.map((r) => r.data?.[0]?.message_id));
  assert.equal(ids.size, 1, "All concurrent retries must return one message ID");
  assert.ok(!ids.has(undefined));
  assert.equal((await countMessages(match.matchId)).length, before.length + 1);
  const repeated = await send(tokenFor(1), body);
  assert.equal(repeated.data[0].message_id, retries[0].data[0].message_id);
  const conflict = await send(tokenFor(1), { ...body, p_content: "A changed message." }, [400]);
  assert.equal(conflict.data.message, "message_request_conflict");
  const second = await send(tokenFor(1), { ...body, p_operation_id: randomUUID() });
  assert.notEqual(second.data[0].message_id, repeated.data[0].message_id,
    "Separate deliberate sends with identical content must both be kept");
  assert.equal((await countMessages(match.matchId)).length, before.length + 2);
  await send(undefined, body, [401, 403]);
  // Another female fixture is not a participant in this particular match.
  await send(tokenFor(3), { ...body, p_operation_id: randomUUID() }, [400, 403]);
  await send(tokenFor(3), { ...body, p_operation_id: randomUUID(), p_as_guardian: true }, [400, 403]);

  // Exercise the genuine consent/acceptance/approval RPCs, not a service-role
  // shortcut which might accidentally bypass the guardian authorization.
  const invite = await rpc("save_my_guardian_configuration", tokenFor(1), {
    p_enabled: true, p_can_reply: true, p_name: "Staging Guardian",
    p_relationship: "sister", p_email: fixtures[3].email,
  });
  assert.ok(invite.data.invitation_code);
  const accepted = await rpc("accept_my_guardian_invitation", tokenFor(3), {
    p_code: invite.data.invitation_code,
  });
  assert.equal(accepted.data.status, "activated");
  const guardianBody = { ...body, p_as_guardian: true, p_operation_id: randomUUID() };
  const unapproved = await send(tokenFor(3), guardianBody, [400]);
  assert.equal(unapproved.data.message, "guardian_approval_required");
  await rpc("guardian_approve_match", tokenFor(3), { p_match_id: match.matchId });
  const guardianBefore = await countMessages(match.matchId);
  const guardianRetries = await Promise.all(Array.from({ length: 10 }, () => send(tokenFor(3), guardianBody)));
  const guardianIds = new Set(guardianRetries.map((r) => r.data?.[0]?.message_id));
  assert.equal(guardianIds.size, 1);
  assert.ok(!guardianIds.has(undefined));
  const guardianAfter = await countMessages(match.matchId);
  assert.equal(guardianAfter.length, guardianBefore.length + 1);
  const guardianMessage = guardianAfter.find((m) => guardianIds.has(m.id));
  assert.equal(guardianMessage.sent_by_guardian, true);
  assert.equal(guardianMessage.sender_id, fixtures[1].id);
  await rpc("save_my_guardian_configuration", tokenFor(1), { p_enabled: false });
  await send(tokenFor(3), { ...guardianBody, p_operation_id: randomUUID() }, [400, 403]);

  // A banned sender cannot use either a fresh operation or a successful
  // receipt as a bypass. This fixture is deleted by the enclosing finally.
  await request(`/rest/v1/users?id=eq.${fixtures[1].id}`, {
    apiKey: service, method: "PATCH", body: { is_banned: true },
  });
  const banned = await send(tokenFor(1), body, [400]);
  assert.equal(banned.data.message, "account_restricted");

  // Start a fresh server minute so the preceding smoke messages do not alter
  // the exact limit assertion. Four concurrent requests keep the test bounded.
  const rateMatch = chatMatches.find((m) => m.senderIndex === 9);
  const timing = await request("/rest/v1/cities?select=id&limit=1", { apiKey: service });
  const serverTime = Date.parse(timing.headers.get("date"));
  assert.ok(Number.isFinite(serverTime));
  console.log("Chat retry safety passed; checking the per-account send cap in a fresh minute.");
  await new Promise((resolve) => setTimeout(resolve, 60000 - (serverTime % 60000) + 250));
  const rateResults = [];
  const rateStart = Date.now();
  for (let offset = 0; offset < 64; offset += 4) {
    rateResults.push(...await Promise.all(Array.from({ length: 4 }, (_, i) => {
      const rateBody = { p_match_id: rateMatch.matchId, p_content: `A respectful staging greeting ${offset + i}.` };
      // Mix legacy and new RPCs: an older installed client must not bypass it.
      return i % 2 === 0
        ? send(tokenFor(9), { ...rateBody, p_operation_id: randomUUID() }, [200, 400])
        : rpc("send_chat_message", tokenFor(9), rateBody, [200, 400]);
    })));
  }
  assert.ok(Date.now() - rateStart < 55000, "Send-cap check crossed its bounded time window");
  const allowed = rateResults.filter((r) => r.status === 200).length;
  const denied = rateResults.filter((r) => r.data?.message === "rate_limit_exceeded").length;
  assert.equal(allowed, 60);
  assert.equal(denied, 4);
  return {
    concurrentMemberRetries: 20, distinctMemberMessages: 1,
    concurrentGuardianRetries: 10, distinctGuardianMessages: 1,
    deliberateIdenticalMessagesPreserved: true, changedRetryRejected: true,
    anonymousRejected: true, outsiderRejected: true, guardianFlagCannotElevate: true,
    guardianAcceptanceApprovalRevocation: true, bannedRetryRejected: true,
    rateLimit: { perAccountPerMinute: 60, accepted: allowed, rejected: denied, legacyCovered: true },
  };
}
