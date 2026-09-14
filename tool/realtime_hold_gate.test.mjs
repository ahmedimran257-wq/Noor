import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createRealtimeHoldGate } from '../load-tests/realtime_hold_gate.js';

const join = { event: 'phx_reply', ref: '1', payload: { status: 'ok' } };
const subscribed = { event: 'system', payload: { extension: 'postgres_changes', status: 'ok' } };
const heartbeat = { event: 'phx_reply', ref: 'hb-1', payload: { status: 'ok' } };
function ready() {
  const gate = createRealtimeHoldGate(60000, 120000);
  gate.message(join, 1000);
  gate.message(subscribed, 2000);
  gate.message(heartbeat, 55000);
  return gate;
}
function hold(gate) {
  gate.begin(60000);
  for (let now = 65000; now < 120000; now += 5000) {
    gate.message(heartbeat, now);
    gate.sample(now);
  }
  return gate.finish(120000, true);
}
test('requires a live PostgreSQL subscription throughout the common hold', () => {
  assert.equal(hold(ready()).sustained, true);
});
test('transport upgrade and join without PostgreSQL subscription fails', () => {
  const gate = createRealtimeHoldGate(60000, 120000);
  gate.message(join, 1000);
  gate.message(heartbeat, 55000);
  assert.equal(hold(gate).sustained, false);
});
test('late join cannot count as part of the full common hold', () => {
  const gate = createRealtimeHoldGate(60000, 120000);
  gate.message(join, 60001);
  gate.message(subscribed, 60002);
  gate.message(heartbeat, 60003);
  assert.equal(hold(gate).sustained, false);
});
test('half-open transport without heartbeats fails even if join succeeded', () => {
  const gate = ready();
  gate.begin(60000);
  gate.sample(90000);
  gate.message(heartbeat, 119000);
  assert.equal(gate.finish(120000, true).failure, 'hold_health_lost');
});
test('closing early or remotely does not pass', () => {
  assert.equal(ready().finish(119999, true).sustained, false);
  assert.equal(ready().finish(120000, false).sustained, false);
});
test('connection quota rejection is classified without logging credentials', () => {
  const gate = ready();
  gate.message({ event: 'phx_reply', ref: '1', payload: {
    status: 'error', response: { reason: 'too_many_connections' },
  } }, 3000);
  assert.equal(hold(gate).failure, 'too_many_connections');
});
test('channel closure remains failed even after later success frames', () => {
  const gate = ready();
  gate.message({ event: 'phx_error' }, 3000);
  gate.message(subscribed, 4000);
  assert.equal(hold(gate).failure, 'channel_closed');
});
test('database subscription errors cannot be mistaken for successful auth', () => {
  const gate = ready();
  gate.message({ event: 'system', payload: {
    extension: 'postgres_changes', status: 'error',
  } }, 3000);
  assert.equal(hold(gate).failure, 'postgres_subscription_error');
});
test('missing the shared hold start fails even when healthy at completion', () => {
  const gate = ready();
  gate.begin(62000);
  gate.message(heartbeat, 119000);
  assert.equal(gate.finish(120000, true).sustained, false);
});
