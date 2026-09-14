// Local, read-only measurements from a signed Android app. No server requests,
// packet interception, rooting, app-private files, tokens or message bodies.
import { spawnSync } from 'node:child_process';
import { mkdirSync, writeFileSync, appendFileSync } from 'node:fs';
import { resolve, join } from 'node:path';
import { pathToFileURL } from 'node:url';

const states = { '01': 'ESTABLISHED', '02': 'SYN_SENT', '03': 'SYN_RECV',
  '04': 'FIN_WAIT1', '05': 'FIN_WAIT2', '06': 'TIME_WAIT', '07': 'CLOSE',
  '08': 'CLOSE_WAIT', '09': 'LAST_ACK', '0A': 'LISTEN', '0B': 'CLOSING' };

// /proc/net uses little-endian words. Include IPv4-mapped IPv6 and the
// well-known DNS64 prefix observed on this handset's mobile network.
export function matchesIpv4Peer(remote, peers) {
  const [address, port] = remote.toUpperCase().split(':');
  if (port !== '01BB') return false;
  if (address.length === 8) return peers.includes(address);
  if (address.length === 32 &&
      ['0000000000000000FFFF0000', '9BFF64000000000000000000'].includes(address.slice(0, 24))) {
    return peers.includes(address.slice(24));
  }
  return false;
}

export function parseUidSockets(text, uid, family) {
  if (!text.includes('local_address') || !text.includes('uid')) {
    throw new Error(`Socket inventory ${family} unavailable; cannot claim zero connections`);
  }
  return text.split(/\r?\n/).slice(1).filter(line => line.trim()).flatMap(line => {
    const fields = line.trim().split(/\s+/);
    if (fields.length < 10 || !/^\d+:$/.test(fields[0])) {
      throw new Error(`Malformed ${family} socket row`);
    }
    if (Number(fields[7]) !== uid) return [];
    return [{ family, state: states[fields[3]] ?? fields[3],
      local: fields[1], remote: fields[2], inode: fields[9] }];
  });
}

async function main() {
  const [action = 'sample', label = 'sample', durationArg = '0'] = process.argv.slice(2);
  if (!['sample', 'watch', 'screen'].includes(action) || !/^[a-z0-9_-]+$/i.test(label)) {
    throw new Error('Usage: node tool/android_connection_audit.mjs sample|watch|screen label [seconds]');
  }
  const duration = Number(durationArg);
  if (!Number.isFinite(duration) || duration < 0 || duration > 600) throw new Error('Invalid duration');
  const device = process.env.AUDIT_ANDROID_DEVICE || 'd2e084e7';
  const app = 'com.silarah.app';
  const adb = process.env.AUDIT_ADB || join(process.env.LOCALAPPDATA, 'Android/Sdk/platform-tools/adb.exe');
  const outDir = resolve(process.env.AUDIT_OUTPUT_DIR || 'audit_artifacts/connection-audit-20260906');
  mkdirSync(outDir, { recursive: true });
  function command(args, { binary = false, optional = false } = {}) {
    const result = spawnSync(adb, ['-s', device, ...args], {
      encoding: binary ? undefined : 'utf8', timeout: 20000, maxBuffer: 8 * 1024 * 1024,
      windowsHide: true,
    });
    if (result.error || (!optional && result.status !== 0)) {
      throw new Error(`ADB ${args.slice(0, 3).join(' ')} failed; measurement unavailable`);
    }
    return result.stdout ?? (binary ? Buffer.alloc(0) : '');
  }
  const packageInfo = command(['shell', 'dumpsys', 'package', app]);
  const uid = Number(packageInfo.match(/\buserId=(\d+)/)?.[1]);
  const versionCode = Number(packageInfo.match(/\bversionCode=(\d+)/)?.[1]);
  if (!uid || !versionCode) throw new Error('App UID/version unavailable');
  const base = { device, app, uid, versionCode,
    debuggable: /\bDEBUGGABLE\b/.test(packageInfo),
    android: command(['shell', 'getprop', 'ro.build.version.release']).trim() };
  if (base.debuggable) throw new Error('Refusing to certify a debug build');
  if (action === 'screen') {
    const screenPath = join(outDir, `${label}.png`);
    writeFileSync(screenPath, command(['exec-out', 'screencap', '-p'], { binary: true }));
    command(['shell', 'uiautomator', 'dump', '/sdcard/silarah-audit.xml']);
    const xml = command(['shell', 'cat', '/sdcard/silarah-audit.xml']);
    writeFileSync(join(outDir, `${label}.xml`), xml);
    console.log(JSON.stringify({ ...base, screenPath }));
    // Only app-owned accessibility labels, not other apps' UI.
    for (const node of xml.matchAll(/<node\b[^>]+>/g)) {
      if (!node[0].includes(`package="${app}"`)) continue;
      const attrs = Object.fromEntries([...node[0].matchAll(/([\w-]+)="([^"]*)"/g)]
        .map(match => [match[1], match[2]]));
      if (attrs.text || attrs['content-desc']) console.log(JSON.stringify({
        text: attrs.text?.replace(/\b[A-F0-9]{10}\b/g, '[private code]'),
        description: attrs['content-desc']?.replace(/\b[A-F0-9]{10}\b/g, '[private code]'), bounds: attrs.bounds,
        clickable: attrs.clickable,
      }));
    }
    return;
  }
  const report = { ...base, label, startedAt: new Date().toISOString(), samples: [],
    caveat: 'UID-owned TCP sockets, not an SDK channel counter. HTTP keep-alive is also counted. This is not a memory-leak or universal-capacity certification.' };
  const started = Date.now();
  do {
    const sockets = ['tcp', 'tcp6'].flatMap(family =>
      parseUidSockets(command(['shell', 'cat', `/proc/net/${family}`]), uid, family));
    const pid = command(['shell', 'pidof', app], { optional: true }).trim();
    const mem = pid ? command(['shell', 'dumpsys', 'meminfo', app]) : '';
    const pss = mem.match(/TOTAL PSS:\s+(\d+)/)?.[1];
    const rss = mem.match(/TOTAL RSS:\s+(\d+)/)?.[1];
    const sample = { at: new Date().toISOString(), elapsedMs: Date.now() - started,
      pid: pid || null, established: sockets.filter(s => s.state === 'ESTABLISHED').length,
      connecting: sockets.filter(s => s.state === 'SYN_SENT').length,
      closeWait: sockets.filter(s => s.state === 'CLOSE_WAIT').length,
      pssKb: pss ? Number(pss) : null, rssKb: rss ? Number(rss) : null, sockets };
    report.samples.push(sample);
    appendFileSync(join(outDir, 'measurements.ndjson'), JSON.stringify({ ...base, label, ...sample }) + '\n');
    console.log(JSON.stringify({ label, ...sample, sockets: undefined }));
    if (action !== 'watch' || Date.now() - started >= duration * 1000) break;
    await new Promise(resolveSleep => setTimeout(resolveSleep, Math.min(5000, duration * 1000 - (Date.now() - started))));
  } while (true);
  report.finishedAt = new Date().toISOString();
  report.maximumEstablished = Math.max(...report.samples.map(s => s.established));
  report.finalEstablished = report.samples.at(-1).established;
  writeFileSync(join(outDir, `${label}.json`), JSON.stringify(report, null, 2));
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  main().catch(error => { console.error(error.message); process.exitCode = 1; });
}
