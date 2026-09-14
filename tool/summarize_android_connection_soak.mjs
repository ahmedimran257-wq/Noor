// Offline evidence only: no Android or server requests, no inferred pass from a
// timer finishing. Read every recorded socket sample and retain coverage limits.
import assert from 'node:assert/strict';
import { readFileSync, writeFileSync } from 'node:fs';
import { resolve, join } from 'node:path';
import { pathToFileURL } from 'node:url';
import { matchesIpv4Peer } from './android_connection_audit.mjs';

export function summarizeSoak(run, readChunk, { requireComplete = true, continuation = false } = {}) {
  const backgroundRemainder = continuation && run.remainingBackgroundSeconds !== undefined;
  if (backgroundRemainder) {
    assert.ok(Number.isInteger(run.remainingBackgroundSeconds) && run.remainingBackgroundSeconds > 0 && run.remainingBackgroundSeconds <= 600);
    assert.equal(run.measurementGap, true);
  }
  const expectedPlan = backgroundRemainder
    ? { 'chat-background': run.remainingBackgroundSeconds, 'chat-resumed': 480, 'inbox-cleanup': 120 }
    : continuation
    ? { 'chat-reentry-baseline': 60, 'chat-background': 600, 'chat-resumed': 480, 'inbox-cleanup': 120 }
    : { 'discovery-idle': 300, 'chat-held': 2100, 'chat-background': 600, 'chat-resumed': 480, 'inbox-cleanup': 120 };
  if (requireComplete) {
    assert.equal(run.status, continuation ? 'continuation_complete_pending_review' : 'measurement_complete_pending_review');
    assert.ok(run.elapsedSeconds >= Object.values(expectedPlan).reduce((a, b) => a + b, 0), 'Insufficient measured duration');
    if (continuation) {
      assert.equal(run.uninterruptedHour, false);
      assert.ok(run.sourceRun, 'Continuation needs its original evidence reference');
    }
    assert.deepEqual(run.phases.map(p => p.name), Object.keys(expectedPlan));
    assert.ok(run.phases.every(p => p.complete));
  }
  const peers = ['0A261268', 'F69540AC'];
  const median = values => {
    const a = values.filter(Number.isFinite).sort((a, b) => a - b);
    return a.length ? a[Math.floor(a.length / 2)] : null;
  };
  const byPhase = [];
  const all = [];
  const allPids = new Set();
  const seenLabels = new Set();
  for (const phase of run.phases) {
    const samples = [];
    for (const { label } of phase.chunks) {
      assert.ok(!seenLabels.has(label), 'Duplicate chunk would inflate coverage');
      seenLabels.add(label);
      const chunk = readChunk(label);
      assert.equal(chunk.versionCode, run.expectedVersionCode);
      assert.equal(chunk.debuggable, false);
      assert.ok(chunk.samples.length > 0, 'Missing measurements cannot mean zero');
      for (const s of chunk.samples) {
        assert.ok(s.pid && Array.isArray(s.sockets));
        assert.ok(Number.isFinite(Date.parse(s.at)));
        assert.ok(Number.isFinite(s.pssKb) && s.pssKb > 0, 'Missing memory data must not be represented as zero');
        allPids.add(s.pid);
        const established = s.sockets.filter(x => x.state === 'ESTABLISHED');
        const supabase = established.filter(x => matchesIpv4Peer(x.remote, peers));
        const closeWait = s.sockets.filter(x => x.state === 'CLOSE_WAIT');
        assert.equal(s.established, established.length);
        assert.equal(s.closeWait, closeWait.length);
        samples.push({ at: s.at, pid: s.pid, supabase: supabase.length,
          total: established.length, closeWait: closeWait.length,
          supabaseInodes: supabase.map(x => x.inode),
          closeWaitInodes: closeWait.map(x => x.inode), pssKb: s.pssKb });
      }
    }
    assert.ok(samples.length > 0, 'Phase has no evidence');
    const firstAt = Date.parse(samples[0].at);
    const lastAt = Date.parse(samples.at(-1).at);
    if (requireComplete) {
      const planned = expectedPlan[phase.name];
      assert.equal(phase.plannedSeconds, planned);
      assert.ok(phase.elapsedSeconds >= planned, 'Phase timer ended too early');
      assert.ok((lastAt - firstAt) / 1000 >= planned - 30,
        'Phase lacks full-duration raw measurement coverage');
      assert.ok(samples.length >= Math.floor(planned / 30), 'Too few samples for phase duration');
    }
    const histogram = {};
    const inodeSamples = {};
    const closeWaitLifetimes = {};
    for (const s of samples) {
      histogram[s.supabase] = (histogram[s.supabase] ?? 0) + 1;
      for (const inode of s.supabaseInodes) inodeSamples[inode] = (inodeSamples[inode] ?? 0) + 1;
      for (const inode of s.closeWaitInodes) {
        const item = closeWaitLifetimes[inode] ??= { firstSeenAt: s.at, lastSeenAt: s.at, samples: 0 };
        item.lastSeenAt = s.at;
        item.samples++;
      }
    }
    byPhase.push({ name: phase.name, complete: phase.complete,
      measuredSeconds: (lastAt - firstAt) / 1000, samples: samples.length,
      first: samples[0], last: samples.at(-1), supabaseHistogram: histogram,
      maxSupabase: Math.max(...samples.map(s => s.supabase)),
      maxTotal: Math.max(...samples.map(s => s.total)),
      maxCloseWait: Math.max(...samples.map(s => s.closeWait)),
      pssMiB: { min: Math.min(...samples.map(s => s.pssKb)) / 1024,
        max: Math.max(...samples.map(s => s.pssKb)) / 1024,
        firstFiveMinutesMedian: median(samples.filter(s => Date.parse(s.at) - firstAt <= 300000).map(s => s.pssKb)) / 1024,
        lastFiveMinutesMedian: median(samples.filter(s => lastAt - Date.parse(s.at) <= 300000).map(s => s.pssKb)) / 1024 },
      inodeSamples, closeWaitLifetimes });
    all.push(...samples.map(s => ({ ...s, phase: phase.name })));
  }
  assert.equal(allPids.size, 1, 'Process restart cannot be called an uninterrupted soak');
  const gaps = all.slice(1).map((s, i) => (Date.parse(s.at) - Date.parse(all[i].at)) / 1000);
  assert.ok(gaps.every(g => g >= 0), 'Out-of-order timestamps');
  const held = byPhase.find(p => p.name === (continuation ? 'chat-reentry-baseline' : 'chat-held'));
  const resumed = byPhase.find(p => p.name === 'chat-resumed');
  const cleanup = byPhase.find(p => p.name === 'inbox-cleanup');
  const background = all.filter(s => s.phase === 'chat-background');
  const cleanupSamples = all.filter(s => s.phase === 'inbox-cleanup');
  const residual = (oldPhase, nextSamples) => oldPhase && nextSamples.length > 0
    ? nextSamples.some(s => s.supabaseInodes.some(i => oldPhase.last.supabaseInodes.includes(i))) : null;
  return {
    status: requireComplete ? (continuation ? 'continuation-measurements-reviewed-not-uninterrupted-hour' : 'complete-measurements-reviewed') : 'partial-measurements-only',
    ...(continuation ? { sourceRun: run.sourceRun, uninterruptedHour: false, measurementGap: run.measurementGap ?? true } : {}),
    sourceRunStatus: run.status, elapsedSeconds: run.elapsedSeconds ?? null,
    processIds: [...allPids], sampleCount: all.length,
    maximumSampleGapSeconds: gaps.length ? Math.max(...gaps) : 0,
    phases: byPhase,
    cleanup: {
      heldChatInodeSeenInBackground: residual(held, background),
      backgroundMaximumSupabase: background.length ? Math.max(...background.map(s => s.supabase)) : null,
      resumedChatInodeSeenInInbox: residual(resumed, cleanupSamples),
      finalSupabase: cleanup?.last.supabase ?? null,
      finalCloseWait: cleanup?.last.closeWait ?? null,
    },
    limitations: [
      'UID TCP sockets include HTTP keep-alive; not every Supabase socket is Realtime.',
      'Sampling cannot rule out short-lived events between samples.',
      'PSS is not a heap-retention proof. No universal no-leak/perfect-optimization claim.',
      'One physical ordinary-member device; Guardian measured separately.',
      'No forced network failure, reboot, 1000-client capacity or payment-provider test.',
      'Token refresh needs separate event evidence; elapsed time alone does not prove it.',
    ],
  };
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  const dir = resolve(process.argv[2] ?? '');
  assert.ok(process.argv[2], 'Provide an exact evidence directory');
  const run = JSON.parse(readFileSync(join(dir, 'run.json'), 'utf8'));
  const partial = process.argv.includes('--partial');
  const continuation = process.argv.includes('--continuation');
  const result = summarizeSoak(run, label => JSON.parse(readFileSync(join(dir, `${label}.json`), 'utf8')),
    { requireComplete: !partial, continuation });
  if (!partial) writeFileSync(join(dir, 'verified-summary.json'), JSON.stringify(result, null, 2));
  console.log(JSON.stringify(result, null, 2));
}
