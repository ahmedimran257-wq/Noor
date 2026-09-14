import test from 'node:test';
import assert from 'node:assert/strict';
import { summarizeSoak } from './summarize_android_connection_soak.mjs';

function fixture() {
  const names = ['discovery-idle', 'chat-held', 'chat-background', 'chat-resumed', 'inbox-cleanup'];
  const chunks = {};
  let at = 1700000000000;
  const phases = names.map((name, i) => {
    const planned = [300, 2100, 600, 480, 120][i];
    const sockets = i === 1 || i === 3
      ? [{ state: 'ESTABLISHED', remote: '0A261268:01BB', inode: `${i}` }] : [];
    const samples = Array.from({ length: planned / 5 + 1 }, (_, n) => ({
      pid: '123', at: new Date(at + n * 5000).toISOString(),
      sockets, established: sockets.length, closeWait: 0, pssKb: 204800,
    }));
    at += planned * 1000;
    chunks[name] = { versionCode: 42038, debuggable: false, samples };
    return { name, complete: true, plannedSeconds: planned, elapsedSeconds: planned,
      chunks: [{ label: name }] };
  });
  return { run: { status: 'measurement_complete_pending_review', elapsedSeconds: 3600,
    expectedVersionCode: 42038, phases }, chunks };
}
test('complete data distinguishes released chat socket from an idle inbox', () => {
  const { run, chunks } = fixture();
  const r = summarizeSoak(run, label => chunks[label]);
  assert.equal(r.cleanup.heldChatInodeSeenInBackground, false);
  assert.equal(r.cleanup.resumedChatInodeSeenInInbox, false);
  assert.equal(r.cleanup.finalSupabase, 0);
  assert.equal(r.sampleCount, 725);
});
test('an interrupted timer is not a completed hour', () => {
  const { run, chunks } = fixture();
  run.status = 'interrupted';
  assert.throws(() => summarizeSoak(run, label => chunks[label]));
  assert.equal(summarizeSoak(run, label => chunks[label], { requireComplete: false }).status,
    'partial-measurements-only');
});
test('missing samples, duplicate chunks and a process restart cannot pass', () => {
  for (const variant of ['empty', 'duplicate', 'pid']) {
    const { run, chunks } = fixture();
    if (variant === 'empty') chunks['chat-held'].samples = [];
    if (variant === 'duplicate') run.phases[0].chunks.push({ label: 'discovery-idle' });
    if (variant === 'pid') chunks['chat-held'].samples[0].pid = '456';
    assert.throws(() => summarizeSoak(run, label => chunks[label]));
  }
});
test('retained inode is reported rather than hidden by the phase ending', () => {
  const { run, chunks } = fixture();
  for (const sample of chunks['inbox-cleanup'].samples) {
    sample.sockets = chunks['chat-resumed'].samples[0].sockets;
    sample.established = 1;
  }
  const r = summarizeSoak(run, label => chunks[label]);
  assert.equal(r.cleanup.resumedChatInodeSeenInInbox, true);
  assert.equal(r.cleanup.finalSupabase, 1);
});
test('a completed timer without full-duration raw observations is rejected', () => {
  const { run, chunks } = fixture();
  chunks['chat-held'].samples = chunks['chat-held'].samples.slice(0, 10);
  assert.throws(() => summarizeSoak(run, label => chunks[label]));
});

test('continuation reviews remaining phases but cannot certify an uninterrupted hour', () => {
  const { run, chunks } = fixture();
  const baseline = run.phases[1];
  baseline.name = 'chat-reentry-baseline';
  baseline.plannedSeconds = baseline.elapsedSeconds = 60;
  chunks['chat-held'].samples = chunks['chat-held'].samples.slice(0, 13);
  run.phases = [baseline, ...run.phases.slice(2)];
  run.status = 'continuation_complete_pending_review';
  run.elapsedSeconds = 1260;
  run.sourceRun = '/saved/interrupted-run';
  run.uninterruptedHour = false;
  assert.throws(() => summarizeSoak(run, label => chunks[label]));
  const result = summarizeSoak(run, label => chunks[label], { continuation: true });
  assert.equal(result.uninterruptedHour, false);
  assert.equal(result.status, 'continuation-measurements-reviewed-not-uninterrupted-hour');
  run.phases[2].complete = false;
  assert.throws(() => summarizeSoak(run, label => chunks[label], { continuation: true }));
});

test('remaining background segment retains its measurement gap and rejects invalid duration', () => {
  const { run, chunks } = fixture();
  run.phases = run.phases.slice(2);
  run.status = 'continuation_complete_pending_review';
  run.sourceRun = '/saved/usb-interrupted-continuation';
  run.uninterruptedHour = false;
  run.measurementGap = true;
  run.remainingBackgroundSeconds = 300;
  run.elapsedSeconds = 900;
  run.phases[0].plannedSeconds = run.phases[0].elapsedSeconds = 300;
  chunks['chat-background'].samples = chunks['chat-background'].samples.slice(0, 61);
  const result = summarizeSoak(run, label => chunks[label], { continuation: true });
  assert.equal(result.measurementGap, true);
  assert.equal(result.uninterruptedHour, false);
  assert.throws(() => summarizeSoak(run, label => chunks[label]));
  run.remainingBackgroundSeconds = 0;
  assert.throws(() => summarizeSoak(run, label => chunks[label], { continuation: true }));
});
