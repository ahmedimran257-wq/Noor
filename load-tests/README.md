# Silarah staging load tests

This harness measures authenticated Supabase read paths without creating,
editing, messaging, matching, or deleting user data. It deliberately refuses
to run against the production project.

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

The runner creates disposable authenticated accounts and always deletes them.
Smoke mode runs for 50 seconds; the full profile runs for three minutes. The
test is capped at 50 VUs and applies one second of member think time. It fails
if more than 1% of requests error, end-to-end p95 latency exceeds 1 second, or
p99 exceeds 1.5 seconds. Increase concurrency only after the previous stage
passes.

Never place tokens in this repository and never point this harness at the live
Silarah project. A production blocklist and staging-reference match are both
enforced by the script.
