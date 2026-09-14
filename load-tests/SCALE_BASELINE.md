# Staging scale baseline

Recorded on 2026-09-03 against the separate `Silarah Staging` Supabase
project (`ykmgkrveucslglxvcyss`), a Nano instance in AWS Tokyo. Production was
excluded by independent runner and k6 guards.

## Proven workload

- Ramped through 50, 150, 300, 600, 800 and 1,000 concurrent virtual users.
- Held 600, 800 and 1,000 users for three minutes each.
- Each virtual user performed one authenticated app read followed by 8-16
  seconds of think time.
- Weighted routes covered Discovery, notifications, interest quota, profile
  view quota, premium-filter access and the country catalogue.
- Forty disposable, complete male/female member sessions were rotated across
  the virtual users. All remaining fixtures were removed and zero remained.

## Result

| Metric | Result | Gate |
| --- | ---: | ---: |
| Peak virtual users | 1,000 | 1,000 |
| Completed requests/actions | 57,204 | n/a |
| Interrupted iterations | 0 | 0 |
| Successful checks | 99.949% | >99% |
| Request failure rate | 0.0507% (29/57,204) | <1% |
| Overall average latency | 415.97 ms | informational |
| Overall p95 latency | 789.10 ms | <2,500 ms |
| Overall p99 latency | 990.12 ms | <5,000 ms |
| Discovery p95 latency | 787.96 ms | <3,500 ms |
| Network received | 97 MB | informational |
| Network sent | 8.2 MB | informational |

The 29 failures were sparse connection resets/timeouts: 12 Discovery, 8
notification inbox, 4 interest quota, 2 profile-view quota, 2 filter access and
1 country catalogue request. They remained well inside the error budget.

## Interpretation

This proves that the current staging Auth/PostgREST/database read architecture
can sustain **1,000 concurrently active, human-paced sessions** at the tested
feature mix (about 51 requests/second on average). It does not establish the
absolute breaking point, 1,000 simultaneous requests in one instant, or the
capacity of untested external systems such as FCM delivery, RevenueCat/Google
Play billing, Storage uploads, email delivery or long-lived Realtime sockets.

Machine-readable evidence is generated locally at
`build/staging-scale-1000-summary.json` and is intentionally not committed.

## Extended capacity gate — 2026-09-04

The app no longer holds account-wide Realtime channels for chat inbox,
notifications, or account standing. Realtime is reserved for the conversation
currently on screen; foreground FCM and lifecycle reconciliation refresh durable
PostgREST state. This keeps the early-launch architecture within the Free-plan
connection budget without weakening the database as the source of truth.

| Workload | Result | Evidence |
| --- | --- | --- |
| 1,000 active chat clients over a two-minute human-paced window | 1,000/1,000 sends and reads; send p95 969.28 ms; read p95 419.18 ms | `build/staging-capacity-optimized-1000-120s/extended-1000-report.json` |
| 150 simultaneous open-chat Realtime clients held for 45 seconds | 150/150 WebSocket upgrades and authenticated joins; connect p95 500.5 ms | `build/staging-capacity-optimized-realtime-150/extended-150-report.json` |
| 1,000 notification queue writes at 200 VUs | 1,000/1,000 writes; p95 890.65 ms; 100/100 unique worker leases | `build/staging-capacity-optimized-notifications-1000-final/extended-1000-report.json` |
| 1,000 private-object uploads at 250 VUs | 1,000/1,000 uploads; p95 2.73 s | `build/staging-capacity-optimized-extended-1000/extended-1000-report.json` |
| 1,000 subscription-event requests at 200 VUs | 1,000/1,000 accepted; p95 422.66 ms; 500 duplicate pairs reduced to 500 unique events; monotonic entitlement state verified | `build/staging-capacity-optimized-billing-1000-final/extended-1000-report.json` |

All extended runs used disposable staging-only identities and report successful
cleanup. The canonical 1,000-client chat gate now uses a 120-second spread.

### Capacity boundary

These isolated workload passes are useful early-launch evidence, not proof of
1,000 people concurrently using all features together. The 1,000-client runs
reused 40 identities, and the upload, notification, chat, and billing scenarios
ran separately. Billing exercised database RPC handling, not the actual Play
or RevenueCat purchase flow. The older Realtime metrics counted upgrades and
joins, not a shared uninterrupted hold window.

The published Free-plan Realtime limit is 200 connections. An operational
budget of 150 open-chat connections leaves headroom, but the application cannot
guarantee that users stay within it. Supporting 1,000 concurrent open-chat
connections requires sufficient provider quota and a fresh sustained-connection
gate; unrelated API successes cannot override that requirement.

## Shared-hold Realtime retest — 2026-09-05

No paid upgrade, spend-cap change, or production mutation was performed. The
dashboard required renewed sign-in, so the account's current paid-plan/settings
could not be independently read. This test used staging's existing effective
limits; it is **not** a post-upgrade certification.

The updated gate requires both authenticated channel and PostgreSQL subscription
acknowledgements before a shared hold starts, fresh heartbeat responses during
the hold, and no subscription errors or early disconnects. Nine offline oracle
tests and five Flutter harness-contract tests passed. A live 10-socket smoke
passed its shared 10-second hold and cleaned up all 10 temporary accounts.

The full retest attempted 1,000 separate WebSockets using 40 disposable identities,
ramped over 40 seconds, allowed 20 seconds to settle, then held a common
60-second window:

| Check | Result |
| --- | ---: |
| WebSocket upgrades | 287 / 1,000 |
| Successful channel joins at any time | 286 / 1,000 |
| PostgreSQL subscription acknowledgements at any time | 271 / 1,000 |
| Full shared-hold gate without errors | **150 / 1,000 — FAIL** |
| HTTP 429 upgrade rejections | 713 |
| First failure: PostgreSQL subscription error | 136 |
| First failure: channel join rejected | 1 |
| Disposable accounts cleaned | 40 / 40 |

The 271 subscription acknowledgements are cumulative, not evidence that 271
subscriptions remained healthy together. The 150 passing clients are a proven
error-free subset, not an estimate of the absolute maximum. HTTP 429s and
subscription errors demonstrate that the current staging configuration cannot
pass the requested 1,000-connection workload. The exact cause of each server-side
subscription error needs Realtime logs; this report does not label them all as a
single quota error. A quota increase followed by the same gate is still required.

Evidence: `build/staging-realtime-hold-1000-20260905/extended-1000-report.json`
and `build/staging-realtime-hold-smoke-20260905/extended-10-report.json`.
An independent post-run read also found zero extended-test Auth fixtures and
zero `silarah-load-*` storage buckets.
