# Silarah staging load tests

This harness measures authenticated Supabase read paths without creating,
editing, messaging, matching, or deleting user data. It deliberately refuses
to run against the production project.

## Prerequisites

1. Create a separate Supabase staging project from the migrations.
2. Add several synthetic, non-production test accounts.
3. Install the free open-source `k6` CLI.
4. Collect short-lived access tokens for only those synthetic accounts.

## Run

PowerShell example:

```powershell
$env:TARGET_ENV='staging'
$env:STAGING_PROJECT_REF='your-staging-project-ref'
$env:SUPABASE_URL='https://your-staging-project-ref.supabase.co'
$env:SUPABASE_ANON_KEY='your-staging-anon-key'
$env:TEST_USER_TOKENS='token-one,token-two,token-three'
$env:MAX_VUS='25'
k6 run load-tests/staging_read_paths.js
```

The test ramps to 25 virtual users by default and is capped at 50. It fails if
more than 1% of requests error, p95 latency exceeds 750 ms, or p99 exceeds
1.5 seconds. Increase concurrency only after the previous stage passes.

Never place tokens in this repository and never point this harness at the live
Silarah project. A production blocklist and staging-reference match are both
enforced by the script.
