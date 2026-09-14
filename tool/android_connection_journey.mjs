// Bounded device QA using an existing, owner-authorized conversation. No sends,
// new accounts, settings changes, private app files or provider load generation.
import { spawnSync } from 'node:child_process';
import { readFileSync, writeFileSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { matchesIpv4Peer } from './android_connection_audit.mjs';

const [journey, countText = '5'] = process.argv.slice(2);
const count = Number(countText);
if (!['chat', 'rapid', 'background'].includes(journey) || !Number.isInteger(count) || count < 1 || count > 10) {
  throw new Error('Usage: node tool/android_connection_journey.mjs chat|rapid|background 1..10');
}
const device = process.env.AUDIT_ANDROID_DEVICE || 'd2e084e7';
const adb = process.env.AUDIT_ADB || join(process.env.LOCALAPPDATA, 'Android/Sdk/platform-tools/adb.exe');
const app = 'com.silarah.app';
const out = resolve(process.env.AUDIT_OUTPUT_DIR || 'audit_artifacts/connection-audit-20260906');
const report = { journey, requestedCycles: count, startedAt: new Date().toISOString(), events: [], completedCycles: 0 };
const wait = ms => new Promise(done => setTimeout(done, ms));
function shell(...args) {
  const r = spawnSync(adb, ['-s', device, 'shell', ...args], { encoding: 'utf8', timeout: 20000, windowsHide: true, maxBuffer: 4e6 });
  if (r.status !== 0 || r.error) throw new Error('ADB unavailable; stopping journey');
  return r.stdout;
}
function record(event) {
  const row = { at: new Date().toISOString(), ...event };
  report.events.push(row);
  writeFileSync(join(out, `journey-${journey}.json`), JSON.stringify(report, null, 2));
  console.log(JSON.stringify(row));
}
function nodes() {
  shell('uiautomator', 'dump', '/sdcard/silarah-audit.xml');
  const xml = shell('cat', '/sdcard/silarah-audit.xml');
  return [...xml.matchAll(/<node\b[^>]+>/g)].map(n => Object.fromEntries(
    [...n[0].matchAll(/([\w-]+)="([^"]*)"/g)].map(m => [m[1], m[2]])))
    .filter(n => n.package === app);
}
function hasUi(ns, screen) {
  return screen === 'inbox' ? ns.some(n => n['content-desc'] === 'Messages') :
    ns.some(n => n['content-desc']?.includes('Private conversation'));
}
async function verify(screen) {
  for (let i = 0; i < 4; i++) {
    const ns = nodes();
    if (hasUi(ns, screen)) return ns;
    await wait(750);
  }
  throw new Error(`Expected ${screen} not visible; stopping without further taps`);
}
async function openChat() {
  const ns = await verify('inbox');
  // This existing active row was inspected on this device before automation.
  const row = ns.find(n => n.clickable === 'true' && n['content-desc']?.startsWith('Imran Ahmed&#10;') && !n['content-desc'].includes('Ended by you'));
  if (!row) throw new Error('Previously observed active chat row is unavailable');
  const b = row.bounds.match(/\d+/g).map(Number);
  shell('input', 'tap', String(Math.floor((b[0] + b[2]) / 2)), String(Math.floor((b[1] + b[3]) / 2)));
  await verify('conversation');
}
async function backToInbox() {
  await verify('conversation');
  shell('input', 'keyevent', 'KEYCODE_BACK');
  await verify('inbox');
}
function measure(label, seconds) {
  const r = spawnSync(process.execPath, ['tool/android_connection_audit.mjs', 'watch', label, String(seconds)],
    { encoding: 'utf8', windowsHide: true, timeout: (seconds + 45) * 1000, maxBuffer: 2e6 });
  if (r.status !== 0 || r.error) throw new Error(`Measurement failed: ${label}`);
  const m = JSON.parse(readFileSync(join(out, `${label}.json`), 'utf8'));
  if (m.versionCode !== 42038 || m.debuggable) throw new Error('Unexpected installed build');
  const last = m.samples.at(-1);
  // These two A records were freshly resolved before this run. Both kernel
  // inventories are retained; IP-level counts include HTTPS, not only Realtime.
  const supabase = last.sockets.filter(s => s.state === 'ESTABLISHED' &&
    matchesIpv4Peer(s.remote, ['0A261268', 'F69540AC']));
  record({ phase: label, established: last.established, supabaseIpEstablished: supabase.length,
    supabaseInodes: supabase.map(s => s.inode), closeWait: last.closeWait, pssKb: last.pssKb });
}
try {
  if (journey === 'background') {
    if (hasUi(nodes(), 'inbox')) await openChat();
    else await verify('conversation');
    measure('background-initial-chat', 25);
  } else await verify('inbox');
  for (let i = 1; i <= count; i++) {
    if (journey === 'background') {
      shell('input', 'keyevent', 'KEYCODE_HOME');
      const activity = shell('dumpsys', 'activity', 'activities');
      if (/mResumedActivity:.*com\.silarah\.app/.test(activity)) throw new Error('App did not background');
      measure(`background-${i}-paused`, 25);
      shell('am', 'start', '-n', `${app}/.MainActivity`);
      await verify('conversation');
      measure(`background-${i}-resumed`, 25);
    } else {
      await openChat();
      if (journey === 'chat') measure(`cycle-${i}-open`, 25);
      await backToInbox();
      if (journey === 'chat') measure(`cycle-${i}-closed`, 25);
      else record({ phase: `rapid-${i}`, verifiedReturnToInbox: true });
    }
    report.completedCycles = i;
  }
  if (journey === 'rapid') measure('rapid-final-idle', 30);
  report.finishedAt = new Date().toISOString();
  record({ finished: true, completedCycles: report.completedCycles });
} catch (error) {
  record({ failed: true, message: error.message });
  process.exitCode = 1;
}
