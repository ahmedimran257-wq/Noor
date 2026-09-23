param(
  [string]$PgBin = (Join-Path $env:LOCALAPPDATA 'Silarah/postgresql-17.10/pgsql/bin'),
  [int]$Port = 55462
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$scratch = Join-Path ([IO.Path]::GetTempPath()) ('silarah-privacy-test-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $scratch | Out-Null
$started = $false
function Invoke-Sql([string]$Sql) {
  $Sql | & "$PgBin/psql.exe" -X -h 127.0.0.1 -p $Port -U postgres -d postgres -v ON_ERROR_STOP=1
  if ($LASTEXITCODE -ne 0) { throw 'Isolated privacy database test failed.' }
}
try {
  & "$PgBin/initdb.exe" -D "$scratch/data" -U postgres -A trust --encoding=UTF8 --locale=C
  if ($LASTEXITCODE -ne 0) { throw 'initdb failed' }
  & "$PgBin/pg_ctl.exe" -D "$scratch/data" -l "$scratch/server.log" -o "-h 127.0.0.1 -p $Port" -w start
  if ($LASTEXITCODE -ne 0) { throw 'Isolated PostgreSQL startup failed' }
  $started = $true
  Invoke-Sql (Get-Content "$repo/tool/testdata/privacy_bootstrap.sql" -Raw)
  # Exercise the real production staff-MFA predicate, not an always-true stub.
  $adminMigration = Get-Content "$repo/supabase/migrations/147_admin_aal2_and_governance_boundary.sql" -Raw
  $predicate = [regex]::Match($adminMigration, '(?s)CREATE OR REPLACE FUNCTION public\.is_active_admin.*?\$\$;').Value
  if (-not $predicate) { throw 'Could not locate the staff predicate' }
  Invoke-Sql $predicate
  Invoke-Sql (Get-Content "$repo/supabase/migrations/262_privacy_rights_requests.sql" -Raw)
  Invoke-Sql (Get-Content "$repo/supabase/migrations/263_privacy_request_retention.sql" -Raw)
  Invoke-Sql (Get-Content "$repo/tool/testdata/privacy_requests.sql" -Raw)
  Invoke-Sql (Get-Content "$repo/tool/testdata/privacy_retention.sql" -Raw)
  Write-Output 'PASS: isolated PostgreSQL privacy behavior tests. This is not a full Supabase reset or production smoke test.'
} finally {
  if ($started) { & "$PgBin/pg_ctl.exe" -D "$scratch/data" -m fast -w stop }
  Write-Output "Synthetic test cluster/log retained at $scratch (no member data)."
}
