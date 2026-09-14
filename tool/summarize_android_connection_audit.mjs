// Recomputes this bounded audit from saved evidence; never contacts a device or server.
import { readFileSync, writeFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { join, resolve } from 'node:path';
import assert from 'node:assert/strict';
import { matchesIpv4Peer } from './android_connection_audit.mjs';

const directory = resolve('audit_artifacts/connection-audit-20260906');
const read = name => JSON.parse(readFileSync(join(directory, `${name}.json`), 'utf8'));
const peers = ['0A261268', 'F69540AC'];
const isPeer = socket => matchesIpv4Peer(socket.remote, peers);
function last(name) {
  const report = read(name);
  assert.equal(report.versionCode, 42038);
  assert.equal(report.debuggable, false);
  assert.ok(report.finishedAt && report.samples.length > 0);
  const sample = report.samples.at(-1);
  return { at: sample.at, pid: sample.pid,
    supabase: sample.sockets.filter(s => s.state === 'ESTABLISHED' && isPeer(s)).length,
    total: sample.established, connecting: sample.connecting,
    closeWait: sample.closeWait, pssKb: sample.pssKb };
}
const cycles = Array.from({ length: 5 }, (_, index) => {
  const number = index + 1;
  const open = read(`cycle-${number}-open`);
  const closed = read(`cycle-${number}-closed`);
  const originalIds = open.samples.at(-1).sockets.filter(isPeer).map(s => s.inode);
  const originalSocketRetained = closed.samples.some(s =>
    s.sockets.some(socket => originalIds.includes(socket.inode)));
  return { number, open: last(`cycle-${number}-open`), closed: last(`cycle-${number}-closed`), originalSocketRetained };
});
const background = [1, 2, 3].map(i => ({
  paused: last(`background-${i}-paused`), resumed: last(`background-${i}-resumed`),
}));
const rapidFinal = last('rapid-final-idle');
const photos = {
  firstOpen: last('sep7-photos-open-1'), firstBack: last('sep7-photos-closed-1'),
  secondOpen: last('sep7-photos-open-2'), paused: last('sep7-photos-background'),
  resumed: last('sep7-photos-resumed'), secondBack: last('sep7-photos-closed-2'),
};
const finalDiscovery = last('sep7-final-idle');
assert.equal(read('journey-chat').completedCycles, 5);
assert.equal(read('journey-rapid').completedCycles, 10);
assert.equal(read('journey-background').completedCycles, 3);
assert.ok(cycles.every(c => c.open.supabase === 1 && !c.originalSocketRetained));
assert.ok(background.every(c => c.paused.supabase === 0 && c.resumed.supabase === 1));
assert.equal(rapidFinal.total, 0);
assert.equal(photos.firstOpen.supabase, 1);
assert.equal(photos.secondOpen.supabase, 1);
assert.equal(photos.firstBack.supabase, 0);
assert.equal(photos.secondBack.supabase, 0);
assert.equal(photos.paused.supabase, 0);
assert.equal(photos.resumed.supabase, 1);
assert.equal(finalDiscovery.supabase, 0);
const fullTests = readFileSync(join(directory, 'full-tests.log'), 'utf8');
const targetedTests = readFileSync(join(directory, 'targeted-tests.log'), 'utf8');
assert.match(fullTests, /\+503: All tests passed!/);
assert.match(targetedTests, /\+46: All tests passed!/);
assert.match(readFileSync(join(directory, 'analyzer.log'), 'utf8'), /No issues found!/);
const apkSha256 = createHash('sha256').update(readFileSync(
  'build/app/outputs/flutter-apk/app-arm64-v8a-release.apk')).digest('hex');
assert.equal(apkSha256, '8a619f4539383f72aff07ab3b1d31784426c4acb1685511aa125442f9ae6640c');
const summary = {
  generatedAt: new Date().toISOString(), auditDates: ['2026-09-06', '2026-09-07'],
  device: 'OnePlus 8 / IN2011 / Android 13', androidVersionCode: 42038,
  flutterBaseBuildNumber: 40038, apkSha256,
  fullFlutterTestsPassed: 503, targetedTestsPassed: 46, targetedOverlapsFull: true,
  analyzer: 'No issues found', cycles, rapidCycles: 10, rapidFinal,
  backgroundCycles: 3, background, photos, finalDiscovery,
  verdict: 'No accumulating Supabase connections observed in the measured member journeys; not a universal leak, memory, cost or capacity certification.',
};
writeFileSync(join(directory, 'verified-summary.json'), JSON.stringify(summary, null, 2));
console.log(JSON.stringify(summary, null, 2));
