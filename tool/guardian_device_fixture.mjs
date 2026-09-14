// Owner-authorized, three-account staging fixture. Never targets production.
// Credentials stay in a gitignored local manifest and are never printed.
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { createHash, randomUUID } from 'node:crypto';
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { join, resolve } from 'node:path';

const staging = 'ykmgkrveucslglxvcyss';
const production = 'jukpscfxzwttgtxvrbmj';
const base = `https://${staging}.supabase.co`;
const out = resolve('audit_artifacts/guardian-device-20260907');
const manifestPath = join(out, 'private-fixtures.json');
const evidencePath = join(out, 'evidence.json');
const cli = join(process.env.LOCALAPPDATA, 'Silarah/supabase/supabase.exe');
const adb = join(process.env.LOCALAPPDATA, 'Android/Sdk/platform-tools/adb.exe');
const action = process.argv[2];
assert.notEqual(staging, production);
assert.equal(new URL(base).hostname, `${staging}.supabase.co`);
const keyResult = spawnSync(cli, ['projects', 'api-keys', '--project-ref', staging, '--output', 'json'],
  { encoding: 'utf8', windowsHide: true, timeout: 30000 });
assert.equal(keyResult.status, 0, 'Staging key lookup failed');
const keys = JSON.parse(keyResult.stdout);
const anon = keys.find(k => k.name === 'anon')?.api_key;
const service = keys.find(k => k.name === 'service_role')?.api_key;
assert.ok(anon && service, 'Staging legacy keys unavailable');
mkdirSync(out, { recursive: true });
let manifest = existsSync(manifestPath) ? JSON.parse(readFileSync(manifestPath, 'utf8')) : null;
let evidence = existsSync(evidencePath) ? JSON.parse(readFileSync(evidencePath, 'utf8'))
  : { project: staging, createdAt: new Date().toISOString(), checks: [], cleanupComplete: false };
function persist() {
  if (manifest) writeFileSync(manifestPath, JSON.stringify(manifest, null, 2), { mode: 0o600 });
  writeFileSync(evidencePath, JSON.stringify(evidence, null, 2));
}
function checked(name, details) {
  evidence.checks.push({ name, at: new Date().toISOString(), ...details });
  persist();
  console.log(JSON.stringify({ check: name, ...details }));
}
async function request(path, { token, admin = false, method = 'GET', body, expected, prefer } = {}) {
  const key = admin ? service : anon;
  const response = await fetch(base + path, { method,
    headers: { apikey: key, Authorization: `Bearer ${token ?? key}`,
      'Content-Type': 'application/json', ...(prefer ? { Prefer: prefer } : {}) },
    body: body === undefined ? undefined : JSON.stringify(body), signal: AbortSignal.timeout(20000) });
  const data = await response.json().catch(() => null);
  if (!(expected ? expected.includes(response.status) : response.ok)) {
    // Never print server exception text or credential-bearing payloads.
    throw new Error(`${method} ${path.split('?')[0]} failed (${response.status}; ${data?.code ?? 'no-code'})`);
  }
  return { status: response.status, data };
}
const rpc = (name, token, body, expected) => request(`/rest/v1/rpc/${name}`,
  { method: 'POST', token, body, expected });
async function session(role) {
  const fixture = manifest?.fixtures.find(f => f.role === role);
  assert.ok(fixture, 'Expected exact run fixture missing');
  const result = await request('/auth/v1/token?grant_type=password', {
    method: 'POST', body: { email: fixture.email, password: fixture.password } });
  assert.equal(result.data.user.id, fixture.id);
  return result.data;
}
function requireManifest() {
  assert.equal(manifest?.project, staging);
  assert.equal(manifest?.fixtures.length, 3);
  assert.ok(manifest.fixtures.every(f => f.email.endsWith('@staging.silarah.invalid')));
  assert.ok(!evidence.cleanupComplete, 'Fixtures already removed');
}
function requireInstalledStagingArtifact() {
  const run = args => {
    const result = spawnSync(adb, ['-s', 'd2e084e7', 'shell', ...args],
      { encoding: 'utf8', windowsHide: true, timeout: 20000 });
    assert.equal(result.status, 0, 'Cannot identify installed staging APK');
    return result.stdout.trim();
  };
  const apk = run(['pm', 'path', 'com.silarah.app']).replace(/^package:/, '');
  assert.match(apk, /^\/data\/app\/[A-Za-z0-9_=/+~.-]+\/base\.apk$/);
  const installed = run(['sha256sum', apk]).split(/\s/)[0];
  const expected = createHash('sha256').update(readFileSync(join(out, 'staging-42038.apk'))).digest('hex');
  assert.equal(installed, expected, 'Refusing fixture credentials: installed app is not the verified staging artifact');
}

if (action === 'build-config') {
  const config = JSON.parse(readFileSync('config/prod.local.json', 'utf8').replace(/^\uFEFF/, ''));
  assert.equal(new URL(config.SUPABASE_URL).hostname, `${production}.supabase.co`);
  config.SUPABASE_URL = base;
  config.SUPABASE_ANON_KEY = anon;
  // This is not a billing test. No production store SDK/account is needed.
  for (const key of Object.keys(config)) if (key.startsWith('REVENUECAT_')) config[key] = '';
  const file = resolve('config/staging-device.local.json');
  writeFileSync(file, JSON.stringify(config, null, 2), { mode: 0o600 });
  console.log(JSON.stringify({ config: file, project: staging, billingKeysDisabled: true }));
} else if (action === 'prepare') {
  const resumeSeededUsers = process.argv.includes('--resume-seeded-users');
  if (resumeSeededUsers) {
    requireManifest();
    assert.ok(!manifest.matchId && !manifest.invitationCode, 'Cannot replay a completed fixture setup');
  } else {
    assert.ok(!manifest, 'Run manifest exists: inspect/reuse, never duplicate fixtures');
    manifest = { project: staging, run: `guardian-device-${randomUUID()}`, fixtures: [] };
    persist();
  }
  if (!resumeSeededUsers) {
  for (const role of ['ward', 'counterpart', 'guardian']) {
    const email = `guardian.${manifest.run}.${role}@staging.silarah.invalid`;
    const password = `G-${randomUUID()}-aA7!`;
    const result = await request('/auth/v1/admin/users', { admin: true, method: 'POST', body: {
      email, password, email_confirm: true, user_metadata: { guardian_device_run: manifest.run } } });
    assert.ok(result.data.id);
    manifest.fixtures.push({ role, id: result.data.id, email, password });
    persist();
  }
  await request('/rest/v1/users', { admin: true, method: 'POST', body: manifest.fixtures.map(f => ({
    id: f.id, email: f.email, country_code: 'IN', timezone: 'Asia/Kolkata',
    gender: f.role === 'counterpart' ? 'male' : 'female',
    onboarding_step: f.role === 'guardian' ? 0 : 5, onboarding_completed: f.role !== 'guardian',
  })) });
  }
  const cities = await request('/rest/v1/cities?select=id,regions!inner(country_code)&regions.country_code=eq.IN&limit=1', { admin: true });
  assert.ok(cities.data?.[0]?.id, 'India staging city required');
  const now = new Date().toISOString();
  await request('/rest/v1/profiles', { admin: true, method: 'POST', body:
    manifest.fixtures.filter(f => f.role !== 'guardian').map(f => ({
      user_id: f.id, first_name: f.role === 'ward' ? 'Amina' : 'Yusuf', last_name: 'QA',
      date_of_birth: '1996-01-01', gender: f.role === 'ward' ? 'female' : 'male',
      country_code: 'IN', city_id: cities.data[0].id, sect: 'Sunni', deen_level: 'practicing',
      bio: 'Isolated staging Guardian device test. Not a real member.',
      visibility: 'visible', onboarding_step: 14, onboarding_completed: true,
      completeness_score: 100, approved_at: now, last_active_at: now,
    })) });
  const ward = manifest.fixtures.find(f => f.role === 'ward');
  const counterpart = manifest.fixtures.find(f => f.role === 'counterpart');
  const guardian = manifest.fixtures.find(f => f.role === 'guardian');
  const match = await request('/rest/v1/matches?select=id', { admin: true, method: 'POST',
    prefer: 'return=representation', body: { user_a: counterpart.id, user_b: ward.id, status: 'active' } });
  manifest.matchId = match.data[0].id;
  persist();
  const wardSession = await session('ward');
  await rpc('send_chat_message_idempotent', wardSession.access_token, {
    p_match_id: manifest.matchId, p_content: 'Guardian test: initial respectful greeting.', p_operation_id: randomUUID(),
  });
  const invite = await rpc('save_my_guardian_configuration', wardSession.access_token, {
    p_enabled: true, p_can_reply: true, p_name: 'Guardian QA', p_relationship: 'sister', p_email: guardian.email,
  });
  assert.match(invite.data.invitation_code, /^[A-F0-9]{10}$/);
  manifest.invitationCode = invite.data.invitation_code;
  persist();
  const outsider = await session('counterpart');
  const denied = await rpc('accept_my_guardian_invitation', outsider.access_token, { p_code: manifest.invitationCode });
  assert.equal(denied.data.status, 'unavailable');
  checked('three-isolated-fixtures-prepared', { accounts: 3, profiles: 2, matches: 1,
    realAuthenticatedWardInvitation: true, wrongEmailAcceptanceRejected: true,
    productionWrites: 0, outboundEmailRequested: false });
} else if (action === 'preaccept-checks') {
  requireManifest();
  const auth = await session('guardian');
  const dashboard = await rpc('get_guardian_dashboard_v2', auth.access_token, { p_mark_seen_ward_id: null });
  assert.deepEqual(dashboard.data, []);
  const transcript = await rpc('get_guardian_match_messages', auth.access_token, {
    p_match_id: manifest.matchId, p_before_created_at: null, p_before_id: null, p_limit: 50,
  }, [400, 403]);
  const direct = await request(`/rest/v1/messages?match_id=eq.${manifest.matchId}&select=id`, { token: auth.access_token });
  assert.deepEqual(direct.data, []);
  checked('unlinked-guardian-cannot-read-conversation', { emptyDashboard: true,
    transcriptDenied: [400, 403].includes(transcript.status), directRlsEmpty: true });
} else if (action === 'verify-accepted') {
  requireManifest();
  const auth = await session('guardian');
  const dashboard = await rpc('get_guardian_dashboard_v2', auth.access_token, { p_mark_seen_ward_id: null });
  assert.equal(dashboard.data.length, 1);
  assert.equal(dashboard.data[0].match_id, manifest.matchId);
  assert.equal(dashboard.data[0].guardian_has_approved, false);
  const replay = await rpc('accept_my_guardian_invitation', auth.access_token, { p_code: manifest.invitationCode });
  assert.equal(replay.data.status, 'unavailable');
  const send = await rpc('send_chat_message_idempotent', auth.access_token, {
    p_match_id: manifest.matchId, p_content: 'Unapproved Guardian must not deliver this.',
    p_operation_id: randomUUID(), p_as_guardian: true,
  }, [400]);
  assert.equal(send.data.message, 'guardian_approval_required');
  checked('device-acceptance-backend-verified', { exactMirror: true,
    invitationReplayRejected: true, messagingBlockedBeforeApproval: true });
} else if (action === 'verify-ui-reply') {
  requireManifest();
  const auth = await session('guardian');
  const dashboard = await rpc('get_guardian_dashboard_v2', auth.access_token, { p_mark_seen_ward_id: null });
  assert.equal(dashboard.data[0].guardian_has_approved, true);
  assert.equal(dashboard.data[0].all_guardians_approved, true);
  const messages = await request(`/rest/v1/messages?match_id=eq.${manifest.matchId}&select=id,content,sender_id,sent_by_guardian&limit=100`, { admin: true });
  const reply = messages.data.filter(m => m.content === 'Guardian device reply.');
  assert.equal(reply.length, 1);
  assert.equal(reply[0].sent_by_guardian, true);
  assert.equal(reply[0].sender_id, manifest.fixtures.find(f => f.role === 'ward').id);
  checked('physical-guardian-reply-backend-verified', { singleMessage: true,
    approved: true, guardianLabelPersisted: true, correctWardSender: true });
} else if (action === 'status') {
  requireManifest();
  const guardian = manifest.fixtures.find(f => f.role === 'guardian');
  const ward = manifest.fixtures.find(f => f.role === 'ward');
  const user = await request(`/rest/v1/users?id=eq.${guardian.id}&select=account_role,onboarding_completed`, { admin: true });
  const profile = await request(`/rest/v1/profiles?user_id=eq.${ward.id}&select=guardian_user_id,guardian_mode`, { admin: true });
  const mirrors = await request(`/rest/v1/guardian_chat_mirrors?guardian_id=eq.${guardian.id}&select=match_id`, { admin: true });
  console.log(JSON.stringify({ role: user.data?.[0]?.account_role,
    onboardingCompleted: user.data?.[0]?.onboarding_completed,
    linkedToExpectedGuardian: profile.data?.[0]?.guardian_user_id === guardian.id,
    mode: profile.data?.[0]?.guardian_mode, mirrors: mirrors.data?.length }));
} else if (action === 'login-guardian') {
  requireManifest();
  assert.ok(process.argv.includes('--soak-finished'), 'Do not interrupt the production soak');
  requireInstalledStagingArtifact();
  const auth = await session('guardian');
  // Exercise the existing production callback handler with a genuine staging
  // session. No test bypass, private app-file editing or delivery to fake mail.
  const uri = `https://silarah.com/auth/callback#refresh_token=${encodeURIComponent(auth.refresh_token)}`;
  const result = spawnSync(adb, ['-s', 'd2e084e7', 'shell', 'am', 'start', '-a', 'android.intent.action.VIEW',
    '-d', `'${uri}'`, '-n', 'com.silarah.app/.MainActivity'],
    { encoding: 'utf8', windowsHide: true, timeout: 20000 });
  assert.equal(result.status, 0, 'Device callback failed');
  checked('genuine-staging-session-delivered-to-callback', { emailDeliveryTest: false });
} else if (action === 'type-invitation') {
  requireManifest();
  assert.ok(process.argv.includes('--soak-finished'), 'Do not interrupt the production soak');
  requireInstalledStagingArtifact();
  // Caller must first focus the observed Guardian invitation field.
  assert.match(manifest.invitationCode, /^[A-F0-9]{10}$/);
  const result = spawnSync(adb, ['-s', 'd2e084e7', 'shell', 'input', 'text', manifest.invitationCode],
    { encoding: 'utf8', windowsHide: true, timeout: 20000 });
  assert.equal(result.status, 0);
  console.log('Private invitation entered; not printed.');
} else if (action === 'send-ward') {
  requireManifest();
  const auth = await session('ward');
  // Numeric timestamps resemble phone numbers to the normal safety filter.
  // Use a unique alphabetic marker; never bypass message safety for fixtures.
  const marker = `Guardian live test ${randomUUID().replace(/[0-9-]/g, c => c === '-' ? '' : String.fromCharCode(103 + Number(c)))}`;
  const sent = await rpc('send_chat_message_idempotent', auth.access_token, {
    p_match_id: manifest.matchId, p_content: marker, p_operation_id: randomUUID(),
  });
  assert.ok(sent.data?.[0]?.message_id);
  checked('ward-message-sent', { marker, messageId: sent.data[0].message_id });
} else if (action === 'revoke') {
  requireManifest();
  const wardAuth = await session('ward');
  await rpc('save_my_guardian_configuration', wardAuth.access_token, { p_enabled: false });
  const guardianAuth = await session('guardian');
  const denied = await rpc('send_chat_message_idempotent', guardianAuth.access_token, {
    p_match_id: manifest.matchId, p_content: 'Revoked Guardian must not deliver this.',
    p_operation_id: randomUUID(), p_as_guardian: true,
  }, [400, 403]);
  assert.ok([400, 403].includes(denied.status));
  const transcript = await rpc('get_guardian_match_messages', guardianAuth.access_token, {
    p_match_id: manifest.matchId, p_before_created_at: null, p_before_id: null, p_limit: 50,
  }, [400, 403]);
  const dashboard = await rpc('get_guardian_dashboard_v2', guardianAuth.access_token, { p_mark_seen_ward_id: null });
  assert.deepEqual(dashboard.data, []);
  checked('ward-revoked-and-guardian-access-denied', { sendDenied: true,
    transcriptDenied: [400, 403].includes(transcript.status), emptyDashboard: true });
} else if (action === 'cleanup') {
  requireManifest();
  // Exactly these three run-owned Auth/public rows, after checking ownership.
  for (const f of manifest.fixtures) {
    const user = await request(`/auth/v1/admin/users/${f.id}`, { admin: true });
    assert.equal(user.data.email, f.email);
    assert.equal(user.data.user_metadata.guardian_device_run, manifest.run);
  }
  for (const f of manifest.fixtures) {
    await request(`/rest/v1/users?id=eq.${f.id}`, { admin: true, method: 'DELETE' });
    await request(`/auth/v1/admin/users/${f.id}`, { admin: true, method: 'DELETE' });
  }
  for (const f of manifest.fixtures) {
    const rows = await request(`/rest/v1/users?id=eq.${f.id}&select=id`, { admin: true });
    assert.equal(rows.data.length, 0);
    await request(`/auth/v1/admin/users/${f.id}`, { admin: true, expected: [404] });
    delete f.password;
  }
  delete manifest.invitationCode;
  evidence.cleanupComplete = true;
  checked('exact-fixture-cleanup-verified', { authAccountsRemoved: 3 });
} else throw new Error('Unknown fixture action; consult this test tool source');
