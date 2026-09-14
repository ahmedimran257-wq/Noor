// Owner-authorized, one-device soak of the existing signed release. No sends,
// account changes, network toggles, new server identities or paid configuration.
import { spawnSync } from 'node:child_process';
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { matchesIpv4Peer } from './android_connection_audit.mjs';

const backgroundResumeIndex = process.argv.indexOf('--resume-background-from');
const continuationIndex = backgroundResumeIndex >= 0 ? backgroundResumeIndex : process.argv.indexOf('--continue-remaining-from');
const continuation = continuationIndex >= 0;
if (!continuation && !process.argv.includes('--run-60-minutes')) {
  throw new Error('Explicit --run-60-minutes or --continue-remaining-from <run directory> required');
}
if (continuation && process.argv.includes('--run-60-minutes')) throw new Error('Choose one run mode');
let sourceRun;
let remainingBackgroundSeconds;
let resumePid;
if (continuation) {
  if (!process.argv[continuationIndex + 1]) throw new Error('Source run directory required');
  sourceRun = resolve(process.argv[continuationIndex + 1]);
  const prior = JSON.parse(readFileSync(join(sourceRun, 'run.json'), 'utf8'));
  const required = backgroundResumeIndex >= 0 ? ['chat-reentry-baseline'] : ['discovery-idle', 'chat-held'];
  if (prior.status !== 'interrupted' || prior.device !== 'd2e084e7' ||
      prior.expectedVersionCode !== 42038 ||
      !required.every(name => prior.phases.some(p => p.name === name && p.complete))) {
    throw new Error('Continuation requires saved completed Discovery/chat phases of the interrupted device run');
  }
  if (backgroundResumeIndex >= 0) {
    const background = prior.phases.at(-1);
    if (background.name !== 'chat-background' || background.complete || !background.chunks.length) {
      throw new Error('Expected interrupted background phase with saved measurements');
    }
    const last = background.chunks.at(-1);
    remainingBackgroundSeconds = Math.ceil(background.plannedSeconds - (Date.parse(last.at) - Date.parse(background.startedAt)) / 1000);
    if (remainingBackgroundSeconds <= 0 || remainingBackgroundSeconds > 600) throw new Error('Invalid remaining background duration');
    resumePid = JSON.parse(readFileSync(join(sourceRun, `${last.label}.json`), 'utf8')).samples.at(-1).pid;
  }
}
const device = 'd2e084e7';
const app = 'com.silarah.app';
const adb = join(process.env.LOCALAPPDATA, 'Android/Sdk/platform-tools/adb.exe');
const stamp = new Date().toISOString().replace(/[:.]/g, '-');
const out = resolve(`audit_artifacts/connection-soak-${stamp}`);
mkdirSync(out, { recursive: true });
const report = { startedAt: new Date().toISOString(), status: 'running', device,
  expectedVersionCode: 42038, plannedMinutes: remainingBackgroundSeconds ? (remainingBackgroundSeconds + 600) / 60 : continuation ? 21 : 60, phases: [], flags: [], outputDirectory: out,
  ...(continuation ? { sourceRun, uninterruptedHour: false,
    scope: 'Remaining lifecycle checks after interruption; not stitched into a 60-minute pass',
    ...(remainingBackgroundSeconds ? { remainingBackgroundSeconds, measurementGap: true } : {}) } : {}) };
const peers = ['0A261268', 'F69540AC'];
const wait = ms => new Promise(done => setTimeout(done, ms));
let chunk = 0;
let initialPid = resumePid;
function save() { writeFileSync(join(out, 'run.json'), JSON.stringify(report, null, 2)); }
function shell(...args) {
  const r = spawnSync(adb, ['-s', device, 'shell', ...args],
    { encoding: 'utf8', timeout: 20000, windowsHide: true, maxBuffer: 4e6 });
  if (r.status !== 0 || r.error) throw new Error('ADB failed; test interrupted, not passed');
  return r.stdout;
}
function nodes() {
  shell('uiautomator', 'dump', '/sdcard/silarah-audit.xml');
  return [...shell('cat', '/sdcard/silarah-audit.xml').matchAll(/<node\b[^>]+>/g)]
    .map(n => Object.fromEntries([...n[0].matchAll(/([\w-]+)="([^"]*)"/g)].map(m => [m[1], m[2]])))
    .filter(n => n.package === app);
}
const onScreen = (ns, screen) => screen === 'chat'
  ? ns.some(n => n['content-desc']?.includes('Private conversation'))
  : ns.some(n => n['content-desc'] === (screen === 'inbox' ? 'Messages' : 'SILARAH'));
async function verify(screen) {
  for (let i = 0; i < 4; i++) {
    const ns = nodes();
    if (onScreen(ns, screen)) return ns;
    await wait(750);
  }
  throw new Error(`Expected ${screen} not visible; no further navigation attempted`);
}
function tap(node) {
  if (!node || node.clickable !== 'true') throw new Error('Expected observed control unavailable');
  const b = node.bounds.match(/\d+/g).map(Number);
  shell('input', 'tap', String(Math.floor((b[0] + b[2]) / 2)), String(Math.floor((b[1] + b[3]) / 2)));
}
async function phase(name, seconds, screen) {
  const phase = { name, startedAt: new Date().toISOString(), plannedSeconds: seconds, chunks: [], complete: false };
  report.phases.push(phase);
  save();
  console.log(JSON.stringify({ phase: name, startedAt: phase.startedAt, plannedSeconds: seconds }));
  const started = Date.now();
  let nextUiCheck = 0;
  do {
    // Keep the owner-unlocked phone awake without changing its timeout/settings.
    shell('input', 'keyevent', 'KEYCODE_WAKEUP');
    if (Date.now() >= nextUiCheck) {
      if (screen === 'background') {
        if (/mResumedActivity:.*com\.silarah\.app/.test(shell('dumpsys', 'activity', 'activities'))) {
          throw new Error('App returned to foreground during planned background phase');
        }
      } else await verify(screen);
      nextUiCheck = Date.now() + 60000;
    }
    const remaining = Math.max(0, seconds - (Date.now() - started) / 1000);
    const duration = Math.min(20, remaining);
    const label = `${name}-${String(++chunk).padStart(4, '0')}`;
    const result = spawnSync(process.execPath,
      ['tool/android_connection_audit.mjs', 'watch', label, String(duration)],
      { encoding: 'utf8', timeout: 45000, windowsHide: true, maxBuffer: 2e6,
        env: { ...process.env, AUDIT_OUTPUT_DIR: out, AUDIT_ANDROID_DEVICE: device } });
    if (result.status !== 0 || result.error) throw new Error(`Measurement ${label} failed`);
    const measurements = JSON.parse(readFileSync(join(out, `${label}.json`), 'utf8'));
    if (measurements.versionCode !== 42038 || measurements.debuggable) throw new Error('Installed build changed');
    for (const sample of measurements.samples) {
      initialPid ??= sample.pid;
      if (!sample.pid || sample.pid !== initialPid) throw new Error('App exited/restarted; uninterrupted-soak criterion failed');
    }
    const last = measurements.samples.at(-1);
    const count = last.sockets.filter(s => s.state === 'ESTABLISHED' && matchesIpv4Peer(s.remote, peers)).length;
    phase.chunks.push({ label, at: last.at, supabase: count, total: last.established,
      closeWait: last.closeWait, pssKb: last.pssKb });
    save();
    console.log(JSON.stringify({ phase: name, elapsedSeconds: Math.round((Date.now() - started) / 1000),
      supabase: count, total: last.established, closeWait: last.closeWait, pssKb: last.pssKb }));
  } while (Date.now() - started < seconds * 1000);
  phase.complete = true;
  phase.finishedAt = new Date().toISOString();
  phase.elapsedSeconds = (Date.now() - started) / 1000;
  save();
}
try {
  if (remainingBackgroundSeconds) {
    if (shell('pidof', app).trim() !== resumePid) throw new Error('App process changed during measurement gap');
  } else {
  await verify('discovery');
  if (!continuation) await phase('discovery-idle', 300, 'discovery');
  tap((await verify('discovery')).find(n => n['content-desc'] === 'Chat'));
  const inbox = await verify('inbox');
  tap(inbox.find(n => n.clickable === 'true' && n['content-desc']?.startsWith('Imran Ahmed&#10;') && !n['content-desc'].includes('Ended by you')));
  await verify('chat');
  await phase(continuation ? 'chat-reentry-baseline' : 'chat-held', continuation ? 60 : 2100, 'chat');
  shell('input', 'keyevent', 'KEYCODE_HOME');
  }
  await phase('chat-background', remainingBackgroundSeconds ?? 600, 'background');
  shell('am', 'start', '-n', `${app}/.MainActivity`);
  await verify('chat');
  await phase('chat-resumed', 480, 'chat');
  shell('input', 'keyevent', 'KEYCODE_BACK');
  await verify('inbox');
  await phase('inbox-cleanup', 120, 'inbox');
  tap((await verify('inbox')).find(n => n['content-desc'] === 'Discover'));
  await verify('discovery');
  report.status = continuation ? 'continuation_complete_pending_review' : 'measurement_complete_pending_review';
  report.finishedAt = new Date().toISOString();
  report.elapsedSeconds = (Date.now() - Date.parse(report.startedAt)) / 1000;
  save();
  console.log(JSON.stringify({ status: report.status, outputDirectory: out, elapsedSeconds: report.elapsedSeconds }));
} catch (error) {
  report.status = 'interrupted';
  report.error = error.message;
  report.finishedAt = new Date().toISOString();
  save();
  console.error(JSON.stringify({ status: report.status, error: report.error, outputDirectory: out }));
  process.exitCode = 1;
}
