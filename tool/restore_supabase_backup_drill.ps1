[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$BackupDirectory,
    [Parameter(Mandatory = $true)][string]$StagingProjectRef,
    [string]$ProductionProjectRef = 'jukpscfxzwttgtxvrbmj',
    [switch]$Execute,
    [string]$SupabaseCliPath = (Join-Path $env:LOCALAPPDATA 'Silarah\supabase\supabase.exe'),
    [string]$PsqlPath = (Join-Path $env:LOCALAPPDATA 'Silarah\postgresql-17.10\pgsql\bin\psql.exe'),
    [string]$PgRestorePath = (Join-Path $env:LOCALAPPDATA 'Silarah\postgresql-17.10\pgsql\bin\pg_restore.exe')
)

$ErrorActionPreference = 'Stop'
$repository = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$knownProductionRef = 'jukpscfxzwttgtxvrbmj'
if ($StagingProjectRef -notmatch '^[a-z]{20}$') {
    throw 'StagingProjectRef must be a 20-character Supabase project reference.'
}
if ($StagingProjectRef -eq $ProductionProjectRef -or
    $StagingProjectRef -eq $knownProductionRef) {
    throw 'Restore drills are forbidden against production.'
}
foreach ($tool in @($SupabaseCliPath, $PsqlPath, $PgRestorePath)) {
    if (-not (Test-Path -LiteralPath $tool -PathType Leaf)) {
        throw "Required tool not found: $tool"
    }
}

$resolvedBackup = (Resolve-Path -LiteralPath $BackupDirectory).Path
$manifestPath = Join-Path $resolvedBackup 'manifest.json'
$archivePath = Join-Path $resolvedBackup 'app.dump'
if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf) -or
    -not (Test-Path -LiteralPath $archivePath -PathType Leaf)) {
    throw 'A version 2 manifest or app.dump archive is missing.'
}
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
if ([int]$manifest.format_version -lt 2 -or
    [string]$manifest.project_ref -notmatch '^[a-z]{20}$') {
    throw 'Restore drills require a version 2 app-owned backup manifest.'
}

& (Join-Path $PSScriptRoot 'verify_supabase_backup.ps1') `
    -BackupDirectory $resolvedBackup `
    -PgRestorePath $PgRestorePath
if ($LASTEXITCODE -ne 0) { throw 'Backup integrity verification failed.' }

function Get-DryRunSetting {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [Parameter(Mandatory = $true)][string]$Name
    )
    $pattern = '(?m)(?:^|\s)' + [regex]::Escape($Name) +
        '=(?:"(?<double>[^"]*)"|''(?<single>[^'']*)''|(?<bare>\S+))'
    $match = [regex]::Match($Text, $pattern)
    if (-not $match.Success) {
        throw "Supabase CLI did not provide temporary $Name credentials."
    }
    foreach ($groupName in @('double', 'single', 'bare')) {
        if ($match.Groups[$groupName].Success) {
            return $match.Groups[$groupName].Value
        }
    }
    throw "Supabase CLI returned an empty $Name setting."
}

function Invoke-PsqlStatements {
    param(
        [Parameter(Mandatory = $true)][string]$Database,
        [Parameter(Mandatory = $true)][string[]]$Statements
    )
    $previousDatabase = [Environment]::GetEnvironmentVariable('PGDATABASE', 'Process')
    [Environment]::SetEnvironmentVariable('PGDATABASE', $Database, 'Process')
    try {
        $arguments = @('-X', '-q', '-A', '-t', '-v', 'ON_ERROR_STOP=1')
        foreach ($statement in $Statements) {
            $arguments += @('-c', $statement)
        }
        $output = @(& $PsqlPath @arguments 2>&1)
        if ($LASTEXITCODE -ne 0) {
            $detail = (@($output | ForEach-Object { [string]$_ }) -join ' ').Trim()
            throw "psql failed for database $Database. $detail"
        }
        return @($output | ForEach-Object { ([string]$_).Trim() } | Where-Object { $_ -ne '' })
    } finally {
        [Environment]::SetEnvironmentVariable('PGDATABASE', $previousDatabase, 'Process')
    }
}

$linkedRefPath = Join-Path $repository 'supabase\.temp\project-ref'
$previousLinkedRef = if (Test-Path -LiteralPath $linkedRefPath) {
    (Get-Content -LiteralPath $linkedRefPath -Raw).Trim()
} else { '' }
$linkChanged = $false
$connectionNames = @('PGHOST', 'PGPORT', 'PGUSER', 'PGPASSWORD', 'PGDATABASE')
$previousEnvironment = @{}
$environmentApplied = $false
$cleanupArmed = $false
$temporaryDirectory = $null
$databaseName = 'silarah_restore_drill_' +
    (Get-Date).ToUniversalTime().ToString('yyyyMMdd_HHmmss')
if ($databaseName -notmatch '^silarah_restore_drill_[0-9]{8}_[0-9]{6}$') {
    throw 'Generated restore database name failed its safety check.'
}

try {
    Push-Location $repository
    try {
        if ($previousLinkedRef -ne $StagingProjectRef) {
            & $SupabaseCliPath link --project-ref $StagingProjectRef
            if ($LASTEXITCODE -ne 0) { throw 'Could not link the staging project.' }
            $linkChanged = $true
        }
        $previousErrorActionPreference = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        $dryRunOutput = (& $SupabaseCliPath db dump --linked --dry-run 2>&1 | Out-String)
        $dryRunExitCode = $LASTEXITCODE
        $ErrorActionPreference = $previousErrorActionPreference
        if ($dryRunExitCode -ne 0) {
            throw 'Supabase CLI could not create temporary staging credentials.'
        }
    } finally {
        Pop-Location
    }

    foreach ($name in $connectionNames) {
        $previousEnvironment[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
        [Environment]::SetEnvironmentVariable(
            $name,
            (Get-DryRunSetting -Text $dryRunOutput -Name $name),
            'Process'
        )
    }
    $environmentApplied = $true
    $pgHost = [Environment]::GetEnvironmentVariable('PGHOST', 'Process')
    $pgUser = [Environment]::GetEnvironmentVariable('PGUSER', 'Process')
    $directHostMatches = $pgHost -eq "db.$StagingProjectRef.supabase.co"
    $poolerMatches = $pgHost -match '(^|\.)pooler\.supabase\.com$' -and
        $pgUser -match ('\.' + [regex]::Escape($StagingProjectRef) + '$')
    if (-not ($directHostMatches -or $poolerMatches)) {
        throw 'Temporary database credentials do not identify the staging project.'
    }
    $connectionEvidence = @(Invoke-PsqlStatements -Database 'postgres' -Statements @(
        'SET ROLE postgres',
        "SELECT current_database() || '|' || current_user || '|' || current_setting('server_version_num') || '|' || (SELECT rolcreatedb::text FROM pg_roles WHERE rolname = current_user);"
    ))
    if ($connectionEvidence.Count -ne 1 -or
        $connectionEvidence[0] -notmatch '^postgres\|postgres\|[0-9]+\|true$') {
        throw 'Temporary credentials did not reach the expected staging postgres role.'
    }

    $toc = @(& $PgRestorePath --list $archivePath 2>&1)
    if ($LASTEXITCODE -ne 0) { throw 'Could not read the restore archive catalogue.' }
    $allowedKinds = @(
        'TYPE', 'TABLE', 'SEQUENCE', 'SEQUENCE OWNED BY', 'DEFAULT',
        'TABLE DATA', 'SEQUENCE SET', 'CHECK CONSTRAINT', 'CONSTRAINT', 'INDEX'
    )
    $filteredToc = @()
    $restorableEntries = 0
    $tableDataEntries = 0
    foreach ($lineObject in $toc) {
        $line = [string]$lineObject
        if ($line.StartsWith(';')) {
            $filteredToc += $line
            continue
        }
        $match = [regex]::Match(
            $line,
            '^\d+; \d+ \d+ (?<kind>.+?) (?<schema>public|private|api_private) (?<name>\S+) '
        )
        if (-not $match.Success) { continue }
        $kind = $match.Groups['kind'].Value
        $schema = $match.Groups['schema'].Value
        $name = $match.Groups['name'].Value
        if ($allowedKinds -notcontains $kind) { continue }
        if ($schema -eq 'public' -and $name -eq 'spatial_ref_sys') { continue }
        $filteredToc += $line
        $restorableEntries++
        if ($kind -eq 'TABLE DATA') { $tableDataEntries++ }
    }
    if ($restorableEntries -lt 20 -or $tableDataEntries -lt 1) {
        throw 'The filtered archive does not contain a credible app-owned data restore set.'
    }

    Write-Output "Restore drill source: $($manifest.project_ref)"
    Write-Output "Restore drill host: staging $StagingProjectRef"
    Write-Output "Ephemeral database: $databaseName"
    Write-Output "Restorable entries: $restorableEntries; table data sections: $tableDataEntries"
    Write-Output 'Excluded: routines/policies/triggers, managed Auth/Storage/Vault objects, and PostGIS spatial_ref_sys.'
    if (-not $Execute) {
        Write-Output 'Dry run passed. Re-run with -Execute to create, restore, validate, and drop the ephemeral database.'
        return
    }

    $temporaryDirectory = Join-Path ([System.IO.Path]::GetTempPath()) $databaseName
    New-Item -ItemType Directory -Force -Path $temporaryDirectory | Out-Null
    $tocPath = Join-Path $temporaryDirectory 'restore.toc'
    [System.IO.File]::WriteAllLines(
        $tocPath,
        $filteredToc,
        [System.Text.UTF8Encoding]::new($false)
    )

    $cleanupArmed = $true
    Invoke-PsqlStatements -Database 'postgres' -Statements @(
        'SET ROLE postgres',
        "CREATE DATABASE `"$databaseName`" TEMPLATE template0 ENCODING 'UTF8'"
    ) | Out-Null

    $bootstrap = @'
SET ROLE postgres;
CREATE SCHEMA extensions;
CREATE SCHEMA auth;
CREATE SCHEMA private;
CREATE SCHEMA api_private;
CREATE EXTENSION postgis WITH SCHEMA public;
CREATE EXTENSION pgcrypto WITH SCHEMA extensions;
CREATE EXTENSION pg_trgm WITH SCHEMA extensions;
CREATE EXTENSION "uuid-ossp" WITH SCHEMA extensions;
CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS 'SELECT NULL::uuid';
CREATE FUNCTION auth.role() RETURNS text LANGUAGE sql STABLE AS 'SELECT ''anon''::text';
CREATE FUNCTION auth.jwt() RETURNS jsonb LANGUAGE sql STABLE AS 'SELECT ''{}''::jsonb';
'@
    Invoke-PsqlStatements -Database $databaseName -Statements @($bootstrap) | Out-Null

    $previousDatabase = [Environment]::GetEnvironmentVariable('PGDATABASE', 'Process')
    [Environment]::SetEnvironmentVariable('PGDATABASE', $databaseName, 'Process')
    try {
        & $PgRestorePath `
            --exit-on-error `
            --no-owner `
            --no-privileges `
            --role=postgres `
            "--use-list=$tocPath" `
            --dbname $databaseName `
            $archivePath
        if ($LASTEXITCODE -ne 0) {
            throw "pg_restore failed with exit code $LASTEXITCODE."
        }
    } finally {
        [Environment]::SetEnvironmentVariable('PGDATABASE', $previousDatabase, 'Process')
    }

    $countStatements = @('SET ROLE postgres')
    foreach ($tableEntry in $manifest.table_rows) {
        $schema = [string]$tableEntry.schema
        $table = [string]$tableEntry.table
        if ($schema -notmatch '^(public|private|api_private)$' -or
            $table -notmatch '^[a-z_][a-z0-9_]*$') {
            throw 'Refusing an unsafe table identifier from the backup manifest.'
        }
        $countStatements += "SELECT '$schema.$table|' || count(*)::text FROM `"$schema`".`"$table`""
    }
    $restoredRows = @(Invoke-PsqlStatements -Database $databaseName -Statements $countStatements)
    $restoredMap = @{}
    foreach ($row in $restoredRows) {
        $parts = ([string]$row).Split('|', 2)
        if ($parts.Count -eq 2) { $restoredMap[$parts[0]] = [int64]$parts[1] }
    }
    foreach ($tableEntry in $manifest.table_rows) {
        $key = "$($tableEntry.schema).$($tableEntry.table)"
        $expected = [int64]$tableEntry.rows
        if (-not $restoredMap.ContainsKey($key) -or $restoredMap[$key] -ne $expected) {
            throw "Restored row count mismatch for ${key}: expected=$expected actual=$($restoredMap[$key])"
        }
    }
    if ($restoredMap.Count -ne $manifest.table_rows.Count) {
        throw 'The restored table inventory differs from the backup manifest.'
    }
    Write-Output "Restore drill passed: $($restoredMap.Count) app-owned table snapshots match the archive manifest."
} finally {
    $cleanupFailure = $null
    if ($cleanupArmed -and $environmentApplied) {
        try {
            $exists = @(Invoke-PsqlStatements -Database 'postgres' -Statements @(
                'SET ROLE postgres',
                "SELECT count(*)::text FROM pg_database WHERE datname = '$databaseName'"
            ))
            if ($exists.Count -eq 1 -and $exists[0] -eq '1') {
                Invoke-PsqlStatements -Database 'postgres' -Statements @(
                    'SET ROLE postgres',
                    "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '$databaseName' AND pid <> pg_backend_pid()",
                    "DROP DATABASE `"$databaseName`""
                ) | Out-Null
                Write-Output "Ephemeral restore database removed: $databaseName"
            }
        } catch {
            $cleanupFailure = $_
            Write-Warning "Cleanup failed for exact database ${databaseName}: $($_.Exception.Message)"
        }
    }
    if ($null -ne $temporaryDirectory -and
        (Test-Path -LiteralPath $temporaryDirectory -PathType Container)) {
        $resolvedTemporaryDirectory = (Resolve-Path -LiteralPath $temporaryDirectory).Path
        $resolvedSystemTemp = [System.IO.Path]::GetFullPath(
            [System.IO.Path]::GetTempPath()
        ).TrimEnd('\')
        if (-not $resolvedTemporaryDirectory.StartsWith(
            $resolvedSystemTemp + '\silarah_restore_drill_',
            [System.StringComparison]::OrdinalIgnoreCase
        )) {
            throw 'Refusing to remove a restore-drill directory outside the system temp boundary.'
        }
        $tocFile = Join-Path $resolvedTemporaryDirectory 'restore.toc'
        if (Test-Path -LiteralPath $tocFile -PathType Leaf) {
            Remove-Item -LiteralPath $tocFile -Force
        }
        Remove-Item -LiteralPath $resolvedTemporaryDirectory -Force
    }
    if ($environmentApplied) {
        foreach ($name in $connectionNames) {
            [Environment]::SetEnvironmentVariable($name, $previousEnvironment[$name], 'Process')
        }
    }
    if ($linkChanged) {
        Push-Location $repository
        try {
            if ($previousLinkedRef -match '^[a-z]{20}$') {
                & $SupabaseCliPath link --project-ref $previousLinkedRef | Out-Null
                if ($LASTEXITCODE -ne 0) { throw 'Could not restore the previous Supabase project link.' }
            } else {
                & $SupabaseCliPath unlink --yes | Out-Null
                if ($LASTEXITCODE -ne 0) { throw 'Could not remove the temporary Supabase project link.' }
            }
        } finally {
            Pop-Location
        }
    }
    if ($null -ne $cleanupFailure) { throw $cleanupFailure }
}
