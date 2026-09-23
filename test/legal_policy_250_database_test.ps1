param(
  [string]$PgBin = (Join-Path $env:LOCALAPPDATA 'Silarah/postgresql-17.10/pgsql/bin'),
  [int]$Port = 55464
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$scratch = Join-Path ([IO.Path]::GetTempPath()) ('silarah-policy-250-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $scratch | Out-Null
$started = $false
function Invoke-Sql([string]$Sql) {
  $Sql | & "$PgBin/psql.exe" -X -h 127.0.0.1 -p $Port -U postgres -d postgres -v ON_ERROR_STOP=1
  if ($LASTEXITCODE -ne 0) { throw 'Isolated policy database test failed' }
}
try {
  & "$PgBin/initdb.exe" -D "$scratch/data" -U postgres -A trust --encoding=UTF8 --locale=C
  if ($LASTEXITCODE -ne 0) { throw 'initdb failed' }
  & "$PgBin/pg_ctl.exe" -D "$scratch/data" -l "$scratch/server.log" -o "-h 127.0.0.1 -p $Port" -w start
  if ($LASTEXITCODE -ne 0) { throw 'PostgreSQL startup failed' }
  $started = $true
  Invoke-Sql (Get-Content "$repo/test/legal_policy_250_bootstrap.sql" -Raw)
  foreach ($migration in @('162_signup_consent_transactions.sql', '212_quarterly_policy_reminder_and_consent_alignment.sql', '214_policy_230_subscription_and_privacy_consents.sql', '239_require_consent_before_member_provisioning.sql')) {
    Invoke-Sql (Get-Content "$repo/supabase/migrations/$migration" -Raw)
  }
  $m249 = Get-Content "$repo/supabase/migrations/249_release_gate_security_cost_and_index_hardening.sql" -Raw
  $begin = [regex]::Match($m249, '(?s)CREATE OR REPLACE FUNCTION public\.begin_signup_consent_transaction.*?\$\$;').Value
  if (-not $begin) { throw 'Missing actual production intake function' }
  Invoke-Sql $begin
  Invoke-Sql (Get-Content "$repo/supabase/migrations/252_policy_240_premium_relationship_privacy.sql" -Raw)
  Invoke-Sql (Get-Content "$repo/test/legal_policy_250_pre_rollout.sql" -Raw)
  Invoke-Sql (Get-Content "$repo/supabase/migrations/264_policy_250_compatible_consent_rollout.sql" -Raw)
  Invoke-Sql @'
SET ROLE authenticated;
SET request.jwt.claim.sub = '00000000-0000-4000-8000-000000000001';
SELECT public.finalize_signup_and_provision_my_user((SELECT id FROM test.pending));
RESET ROLE;
SELECT test.assert((SELECT count(*) = 5 FROM public.user_consents WHERE user_id = '00000000-0000-4000-8000-000000000001' AND version = '2.4.0'), 'pre-rollout pending transaction preserved');
SET ROLE authenticated;
SET request.jwt.claim.sub = '00000000-0000-4000-8000-000000000003';
SELECT test.reject($q$SELECT public.finalize_signup_and_provision_my_user('00000000-0000-4000-8000-000000000099')$q$, 'required_consent_missing');
RESET ROLE;
SELECT test.assert(NOT EXISTS(SELECT 1 FROM public.users WHERE id = '00000000-0000-4000-8000-000000000003'), 'malformed legacy transaction rolls back provisional account');
'@
  Invoke-Sql (Get-Content "$repo/tool/testdata/policy_250.sql" -Raw)
  Write-Output 'PASS: isolated policy rollout behavior. Synthetic auth/schema/rate-limit/export boundaries, actual consent/provisioning RPCs; not a full Supabase reset or live smoke test.'
} finally {
  if ($started) { & "$PgBin/pg_ctl.exe" -D "$scratch/data" -m fast -w stop }
  Write-Output "Synthetic cluster/log retained at $scratch (no member data)."
}
