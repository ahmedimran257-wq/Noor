// Offline review of this bounded, signed-device Guardian audit. No credentials,
// network calls, or universal no-leak claims.
import assert from 'node:assert/strict';
import { readFileSync, writeFileSync } from 'node:fs';
import { resolve, join } from 'node:path';
import { matchesIpv4Peer } from './android_connection_audit.mjs';

const dir = resolve('audit_artifacts/guardian-device-20260907');
const labels = [
  'guardian-transcript-steady', 'guardian-background', 'guardian-resumed',
  'guardian-cycle-one-settled', 'guardian-cycle-one-transcript',
  'guardian-cycle-two-dashboard', 'guardian-cycle-two-transcript',
  'guardian-cycle-three-dashboard', 'guardian-cycle-three-transcript',
  'guardian-revoked-listener', 'guardian-empty-dashboard',
  'guardian-truly-empty-dashboard', 'guardian-prelogout-20260909', 'guardian-logout',
  'guardian-logout-followup',
];
const peers = ['0A261268', 'F69540AC'];
const phases = labels.map(label => {
  const r = JSON.parse(readFileSync(join(dir, `${label}.json`), 'utf8'));
  assert.equal(r.versionCode, 42038);
  assert.equal(r.debuggable, false);
  assert.ok(r.samples.length);
  const samples = r.samples.map(s => ({
    at: s.at, pid: s.pid, total: s.established, closeWait: s.closeWait,
    supabaseInodes: s.sockets.filter(x => x.state === 'ESTABLISHED' && matchesIpv4Peer(x.remote, peers)).map(x => x.inode),
    pssMiB: s.pssKb / 1024,
  }));
  return { label, samples: samples.length, firstAt: samples[0].at,
    lastAt: samples.at(-1).at,
    maxEstablished: Math.max(...samples.map(s => s.total)),
    maxSupabase: Math.max(...samples.map(s => s.supabaseInodes.length)),
    maxCloseWait: Math.max(...samples.map(s => s.closeWait)),
    final: samples.at(-1),
  };
});
const byLabel = name => phases.find(p => p.label === name);
const cyclePhases = phases.filter(p => /guardian-cycle-/.test(p.label));
const intersection = cyclePhases[0].final.supabaseInodes.filter(inode =>
  cyclePhases.every(p => p.final.supabaseInodes.includes(inode)));
const empty = byLabel('guardian-truly-empty-dashboard');
const logout = byLabel('guardian-logout');
const prelogout = byLabel('guardian-prelogout-20260909');
const result = {
  reviewedAt: new Date().toISOString(), scope: 'One signed OnePlus, isolated staging Guardian accounts',
  phases,
  observations: {
    navigationCycles: 3, commonInodesAcrossNavigationSamples: intersection,
    backgroundFinalSupabase: byLabel('guardian-background').final.supabaseInodes.length,
    resumedFinalSupabase: byLabel('guardian-resumed').final.supabaseInodes.length,
    emptyDashboardFinalSupabase: empty.final.supabaseInodes.length,
    logoutFinalSupabase: logout.final.supabaseInodes.length,
    logoutFollowupFinalCloseWait: byLabel('guardian-logout-followup').final.closeWait,
    currentPrelogoutInodeRetainedAfterLogout: prelogout.final.supabaseInodes.some(i => logout.final.supabaseInodes.includes(i)),
  },
  findings: [
    'Guardian received a ward-message notification for its own Guardian-authored reply.',
    'Revoked transcript retains active/composer UI and cached messages after server denial.',
    'Back from revoked transcript can retain a stale dashboard card until a fresh unmarked read.',
    'Empty Guardian dashboard retains a Realtime connection despite no linked ward.',
    'Guardian resume runs common member refresh paths; request bursts warrant role-aware optimization.',
    'One non-classified-Supabase IPv6 CLOSE_WAIT socket persisted after logout; its owning SDK and eventual cleanup are not established by these samples.',
  ],
  limitations: [
    'TCP includes HTTPS keep-alive; a TCP count is not a Realtime channel count.',
    'Short samples and three navigation cycles do not prove absence of all leaks.',
    'The interrupted ordinary-member hour is not certified by this separate Guardian test.',
    'Logout was measured on 9 September after a day gap and new process; its inode comparison uses the same-day prelogout sample, not the previous-day process.',
    'Email delivery, token-refresh expiry, forced network failure and 1000 devices are not established here.',
  ],
};
writeFileSync(join(dir, 'connection-review.json'), JSON.stringify(result, null, 2));
console.log(JSON.stringify(result, null, 2));
