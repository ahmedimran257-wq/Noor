import test from 'node:test';
import assert from 'node:assert/strict';
import { parseUidSockets, matchesIpv4Peer } from './android_connection_audit.mjs';
const header = ' sl local_address rem_address st tx_queue rx_queue tr tm->when retrnsmt uid timeout inode\n';
const row = (uid, state = '01', inode = '123') =>
  ` 0: 0100007F:1234 0100007F:01BB ${state} 00000000:00000000 00:00000000 00000000 ${uid} 0 ${inode} 1\n`;
test('counts only the specified app UID, not other apps or detached TIME_WAIT rows', () => {
  const sockets = parseUidSockets(header + row(10357) + row(10358) + row(0, '06'), 10357, 'tcp');
  assert.equal(sockets.length, 1);
  assert.equal(sockets[0].state, 'ESTABLISHED');
  assert.equal(sockets[0].inode, '123');
});
test('keeps established and closing states distinct for IPv6 too', () => {
  const sockets = parseUidSockets(header + row(10357, '08') + row(10357, '02'), 10357, 'tcp6');
  assert.deepEqual(sockets.map(s => s.state), ['CLOSE_WAIT', 'SYN_SENT']);
});
test('empty valid inventory is zero, denied or malformed output is not zero', () => {
  assert.deepEqual(parseUidSockets(header, 10357, 'tcp'), []);
  assert.throws(() => parseUidSockets('Permission denied', 10357, 'tcp'));
  assert.throws(() => parseUidSockets(header + 'malformed row', 10357, 'tcp'));
});
test('peer classification includes native IPv4, mapped IPv6 and mobile DNS64', () => {
  const peers = ['0A261268', 'F69540AC'];
  assert.equal(matchesIpv4Peer('0A261268:01BB', peers), true);
  assert.equal(matchesIpv4Peer('0000000000000000FFFF0000F69540AC:01BB', peers), true);
  assert.equal(matchesIpv4Peer('9BFF640000000000000000000A261268:01BB', peers), true);
  assert.equal(matchesIpv4Peer('9BFF640000000000000000004BB65663:01BB', peers), false);
  assert.equal(matchesIpv4Peer('0A261268:0050', peers), false);
  assert.equal(matchesIpv4Peer('0068042400081340000000005E000000:01BB', peers), false);
});
