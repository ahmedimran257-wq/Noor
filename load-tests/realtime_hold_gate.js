// Pure evidence oracle shared by the live k6 workload and offline tests.
// A transport upgrade or a transient join is not a sustained subscription.
export function createRealtimeHoldGate(holdStartMs, holdEndMs) {
  let joinedAt = null;
  let subscribedAt = null;
  let lastHeartbeatAt = null;
  let began = false;
  let failure = null;
  const fail = (reason) => { failure ??= reason; };
  const healthy = (now) => joinedAt !== null && joinedAt <= holdStartMs &&
    subscribedAt !== null && subscribedAt <= holdStartMs &&
    lastHeartbeatAt !== null && now - lastHeartbeatAt <= 20000;
  return {
    fail,
    message(message, now) {
      if (message.event === 'phx_reply' && message.ref === '1') {
        if (message.payload?.status === 'ok') joinedAt ??= now;
        else {
          const reason = message.payload?.response?.reason;
          fail(['too_many_connections', 'too_many_joins', 'too_many_channels'].includes(reason)
            ? reason : 'join_rejected');
        }
      }
      if (message.event === 'system' && message.payload?.extension === 'postgres_changes') {
        if (message.payload.status === 'ok') subscribedAt ??= now;
        else fail('postgres_subscription_error');
      }
      if (message.event === 'phx_error' || message.event === 'phx_close') fail('channel_closed');
      if (message.event === 'phx_reply' && String(message.ref).startsWith('hb-') &&
          message.payload?.status === 'ok') lastHeartbeatAt = now;
    },
    begin(now) {
      began = now >= holdStartMs && now <= holdStartMs + 1000;
      if (!began || !healthy(now)) fail('not_ready_at_common_hold_start');
    },
    sample(now) {
      if (now >= holdStartMs && now < holdEndMs && !healthy(now)) fail('hold_health_lost');
    },
    finish(now, intentionalClose) {
      if (!intentionalClose || now < holdEndMs) fail('early_disconnect');
      if (!began || !healthy(now)) fail('hold_incomplete');
      return {
        joined: joinedAt !== null,
        subscribed: subscribedAt !== null,
        sustained: failure === null,
        failure,
      };
    },
  };
}
