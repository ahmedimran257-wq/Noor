# Executes synthetic fixtures in rollback-only transactions on the named staging
# project. Never replaces auth functions and never accepts a production target.
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$stagingRef = 'ykmgkrveucslglxvcyss'
$cli = Join-Path $env:LOCALAPPDATA 'Silarah/supabase/supabase.exe'
$psql = Join-Path $env:LOCALAPPDATA 'Silarah/postgresql-17.10/pgsql/bin/psql.exe'
if ((Get-Content "$repo/supabase/.temp/project-ref" -Raw).Trim() -ne $stagingRef) {
  throw 'Link to the verified Silarah Staging project before running this test.'
}
$saved = @{}
try {
  $dry = (& $cli db dump --linked --dry-run 2>&1 | Out-String)
  if ($LASTEXITCODE -ne 0) { throw 'Could not acquire temporary staging connection.' }
  foreach ($name in @('PGHOST','PGPORT','PGUSER','PGPASSWORD','PGDATABASE')) {
    $saved[$name] = [Environment]::GetEnvironmentVariable($name,'Process')
    $pattern = '(?m)(?:^|\s)' + $name + '=(?:"(?<double>[^"]*)"|''(?<single>[^'']*)''|(?<bare>\S+))'
    $match = [regex]::Match($dry,$pattern)
    if (-not $match.Success) { throw "Missing temporary setting $name" }
    $value = @('double','single','bare') | ForEach-Object { if ($match.Groups[$_].Success) { $match.Groups[$_].Value } }
    [Environment]::SetEnvironmentVariable($name,[string]$value,'Process')
  }
  if ($env:PGHOST -ne "db.$stagingRef.supabase.co" -and
      -not ($env:PGHOST -match '(^|\.)pooler\.supabase\.com$' -and $env:PGUSER.EndsWith(".$stagingRef"))) {
    throw 'Temporary connection does not identify staging.'
  }
  $env:PGDATABASE = 'postgres'
  $bootstrap = Get-Content "$repo/tool/testdata/privacy_bootstrap.sql" -Raw
  $helpers = $bootstrap.Substring($bootstrap.IndexOf('CREATE SCHEMA test;'))
  foreach ($file in @('privacy_requests.sql','privacy_retention.sql','policy_250.sql')) {
    $sql = Get-Content "$repo/tool/testdata/$file" -Raw
    $sql = $sql -replace '(?m)^BEGIN;\s*','' -replace '(?m)^ROLLBACK;\s*',''
    $sql = $sql.Replace('RESET ROLE;', 'SET LOCAL ROLE postgres;')
    # Supabase auth.jwt reads the combined claims object; update it whenever
    # a fixture switches identity or assurance. The real auth functions remain.
    $sql = [regex]::Replace($sql, '(?m)^(SET LOCAL request\.jwt\.claim\.(?:sub|aal|role|session_id) = [^;]+;)', {
      param($match)
      $match.Value + "`nSELECT set_config('request.jwt.claims', jsonb_build_object('sub', current_setting('request.jwt.claim.sub', true), 'aal', current_setting('request.jwt.claim.aal', true), 'role', current_setting('request.jwt.claim.role', true), 'session_id', current_setting('request.jwt.claim.session_id', true))::text, true);"
    })
    $wrapped = "BEGIN;`nSET LOCAL ROLE postgres;`nSET LOCAL statement_timeout = '30s';`n$helpers`n$sql`nROLLBACK;"
    $wrapped | & $psql -X -q -v ON_ERROR_STOP=1
    if ($LASTEXITCODE -ne 0) { throw "Staging test failed: $file (transaction rolled back on disconnect)" }
  }
  Write-Output 'PASS: real Supabase staging auth/RLS/retention fixtures; every fixture transaction rolled back.'
} finally {
  foreach ($name in $saved.Keys) { [Environment]::SetEnvironmentVariable($name,$saved[$name],'Process') }
}
