# Silarah staging load tests

These harnesses measure Supabase capacity using disposable staging identities.
The baseline exercises reads; extended scenarios also create and clean up
test-only writes. They deliberately refuse to run against the production project.

## Prerequisites

1. Create a separate Supabase staging project from the migrations.
2. Install the free open-source `k6` CLI.
3. Provide the staging project keys through process environment variables.

## Run

PowerShell example:

```powershell
$env:STAGING_PROJECT_REF='your-staging-project-ref'
$env:PRODUCTION_PROJECT_REF='your-production-project-ref'
$env:STAGING_SUPABASE_URL='https://your-staging-project-ref.supabase.co'
$env:STAGING_SUPABASE_ANON_KEY='your-staging-anon-key'
$env:STAGING_SUPABASE_SERVICE_ROLE_KEY='your-staging-service-role-key'
$env:LOAD_TEST_MAX_VUS='1'
$env:LOAD_TEST_SMOKE_MODE='true'
node tool/run_staging_load_test.mjs
```

The baseline runner creates disposable authenticated accounts and always
deletes them. Smoke mode runs for 50 seconds; the full profile runs for three
minutes. This baseline profile is capped at 50 VUs and applies one second of
member think time. It fails if more than 1% of requests error, end-to-end p95
latency exceeds 1 second, or p99 exceeds 1.5 seconds. Increase concurrency only
after the previous stage passes.

## 600–1,000 concurrent-user capacity test

The scale profile models live, authenticated member sessions and can peak at
600, 800, or 1,000 concurrent virtual users. It ramps through the lower stages
first, performs one bounded read per member action, uses 8–16 seconds of think
time, and exercises Discovery, notifications, quota checks, Premium filter
access, Auth, and the country catalogue. It does not send interests, messages,
push notifications, emails, uploads, or purchases.

The runner creates 40 complete disposable members and rotates their sessions
across the VUs. This is deliberate: it measures concurrent API capacity without
adding 1,000 artificial monthly active users. The 1,000-VU mix averages roughly
83 HTTP requests per second and limits Discovery pages to 10 rows to control
database and egress cost.

```powershell
$env:LOAD_TEST_PROFILE='scale'
$env:LOAD_TEST_MAX_VUS='1000'
$env:LOAD_TEST_SCALE_ACK='I_UNDERSTAND_STAGING_SCALE_LOAD'
$env:STAGING_LOAD_REPORT_PATH='build/staging-scale-1000-summary.json'
node tool/run_staging_load_test.mjs
```

Run it manually through `Staging 600-1000 user capacity test` in GitHub Actions,
or with the command above after the five staging variables are configured.
The run automatically stops if the error rate reaches 1% or p95 latency exceeds
2.5 seconds after warm-up. A 1,000-VU pass means this specific staging workload
passed; it does not by itself prove unlimited production capacity or exercise
FCM, RevenueCat, Storage uploads, Realtime sockets, or physical-device UI.

Never place tokens in this repository and never point this harness at the live
Silarah project. A production blocklist and staging-reference match are both
enforced by the script.

## Sustained 1,000-connection Realtime gate

With the same staging credentials configured, run:

```powershell
$env:EXTENDED_LOAD_ACK='I_UNDERSTAND_STAGING_EXTENDED_LOAD'
$env:EXTENDED_TARGET_VUS='1000'
$env:EXTENDED_SCENARIOS='realtime'
$env:EXTENDED_REPORT_DIR='build/staging-realtime-hold-1000'
node tool/run_staging_extended_load_test.mjs
```

Use target `10` first for a smoke check. At target 1,000 the gate creates
1,000 separate WebSockets using 40 disposable authenticated identities. It
ramps over 40 seconds (25 attempts/second), allows 20 seconds for subscriptions
to settle, and requires all 1,000 to remain healthy throughout the **same
60-second window**. Each must receive both the channel-join acknowledgement
and a successful PostgreSQL subscription acknowledgement before the hold.
Heartbeat responses must remain fresh; early disconnects and channel errors
fail the gate. Successful upgrades at different times do not establish capacity.

This measures concurrent authenticated subscriptions, not 1,000 distinct
accounts or end-to-end chat-event/FCM delivery. It performs no purchase or plan
upgrade. Free/Pro connection quotas can prevent a pass; never weaken the gate
to hide that result. Reports include the shared hold duration, sustained
connection count, failure categories, and fixture-cleanup outcome. Realtime-only
runs do not register synthetic FCM tokens.

Offline evidence-oracle tests: `node --test tool/realtime_hold_gate.test.mjs`.
## Retry and reconnect architecture verification

For a bounded staging functional check of retry-safe member/guardian sends,
set `EXTENDED_TARGET_VUS=10`, `EXTENDED_SCENARIOS=chat`, and
`EXTENDED_VERIFY_CHAT_RECOVERY=true` when running
`node tool/run_staging_extended_load_test.mjs` with the documented staging-only
credentials and acknowledgement. This additionally verifies concurrent retries,
guardian consent/approval/revocation, unauthorized access and the shared send cap.
It waits for a fresh server minute for the exact rate-limit assertion, creates
only disposable fixtures and cleans them in the runner's `finally` block.

This is functional evidence, not a 1,000-socket capacity pass. See
`docs/architecture_upgrade_readiness.md` for the deployment ordering and remaining
post-upgrade capacity gate. Never set this option on a 1,000-VU load run.
