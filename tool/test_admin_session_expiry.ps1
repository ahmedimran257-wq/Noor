param(
  [string]$PgBin = (Join-Path $env:LOCALAPPDATA 'Silarah/postgresql-17.10/pgsql/bin'),
  [int]$Port = 55463,
  [switch]$Baseline
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$scratch = Join-Path ([IO.Path]::GetTempPath()) ('silarah-admin-session-test-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $scratch | Out-Null
$started = $false
function Invoke-Sql([string]$Sql) {
  $Sql | & "$PgBin/psql.exe" -X -h 127.0.0.1 -p $Port -U postgres -d postgres -v ON_ERROR_STOP=1
  if ($LASTEXITCODE -ne 0) { throw 'Isolated staff session test failed.' }
}
try {
  & "$PgBin/initdb.exe" -D "$scratch/data" -U postgres -A trust --encoding=UTF8 --locale=C
  if ($LASTEXITCODE -ne 0) { throw 'initdb failed' }
  & "$PgBin/pg_ctl.exe" -D "$scratch/data" -l "$scratch/server.log" -o "-h 127.0.0.1 -p $Port" -w start
  if ($LASTEXITCODE -ne 0) { throw 'Isolated PostgreSQL startup failed' }
  $started = $true
  Invoke-Sql (Get-Content "$repo/tool/testdata/privacy_bootstrap.sql" -Raw)
  Invoke-Sql (Get-Content "$repo/tool/testdata/admin_session_bootstrap.sql" -Raw)
  foreach ($item in @(
    @{ Path = '146_member_write_security_boundary.sql'; Function = 'private.assert_authenticated' },
    @{ Path = '147_admin_aal2_and_governance_boundary.sql'; Function = 'public.is_active_admin' }
  )) {
    $source = Get-Content "$repo/supabase/migrations/$($item.Path)" -Raw
    $pattern = '(?s)CREATE OR REPLACE FUNCTION ' + [regex]::Escape($item.Function) + '.*?\$\$;'
    $definition = [regex]::Match($source, $pattern).Value
    if (-not $definition) { throw "Missing production function: $($item.Function)" }
    Invoke-Sql $definition
  }
  Invoke-Sql (Get-Content "$repo/supabase/migrations/242_absolute_admin_session_boundary.sql" -Raw)
  if (-not $Baseline) {
    Invoke-Sql (Get-Content "$repo/supabase/migrations/265_enforce_staff_session_expiry_at_database.sql" -Raw)
  }
  Invoke-Sql (Get-Content "$repo/tool/testdata/admin_session_expiry.sql" -Raw)
  Write-Output 'PASS: isolated PostgreSQL staff session tests. Full Supabase reset remains a separate release gate.'
} finally {
  if ($started) { & "$PgBin/pg_ctl.exe" -D "$scratch/data" -m fast -w stop }
  Write-Output "Synthetic test cluster/log retained at $scratch (no member data)."
}
