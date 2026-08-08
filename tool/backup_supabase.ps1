[CmdletBinding()]
param(
    [string]$ProjectRef,
    [string]$OutputRoot = '',
    [string]$PgDumpPath = (Join-Path $env:LOCALAPPDATA 'Silarah\postgresql-17.10\pgsql\bin\pg_dump.exe'),
    [string]$SupabaseCliPath = (Join-Path $env:LOCALAPPDATA 'Silarah\supabase\supabase.exe')
)

$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
    $OutputRoot = Join-Path $PSScriptRoot '..\supabase\backups'
}
$runLogDirectory = Join-Path $PSScriptRoot '..\supabase\backups\logs'
$runLogPath = Join-Path $runLogDirectory 'weekly-task.log'
New-Item -ItemType Directory -Force -Path $runLogDirectory | Out-Null
"[$((Get-Date).ToUniversalTime().ToString('o'))] Backup started." |
    Set-Content -LiteralPath $runLogPath -Encoding UTF8
trap {
    "[$((Get-Date).ToUniversalTime().ToString('o'))] Backup failed: $($_.Exception.Message)" |
        Add-Content -LiteralPath $runLogPath -Encoding UTF8
    exit 1
}

function Get-DryRunSetting {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [Parameter(Mandatory = $true)][string]$Name
    )

    $pattern = '(?m)(?:^|\s)' + [regex]::Escape($Name) + '=(?:"(?<double>[^"]*)"|''(?<single>[^'']*)''|(?<bare>\S+))'
    $match = [regex]::Match($Text, $pattern)
    if (-not $match.Success) {
        throw "Supabase CLI did not provide $Name in its temporary connection command."
    }

    foreach ($groupName in @('double', 'single', 'bare')) {
        if ($match.Groups[$groupName].Success) {
            return $match.Groups[$groupName].Value
        }
    }

    throw "Supabase CLI returned an empty $Name setting."
}

function Invoke-PgDump {
    param(
        [Parameter(Mandatory = $true)][string[]]$Arguments,
        [Parameter(Mandatory = $true)][string]$Description
    )

    & $script:ResolvedPgDump @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$Description failed with exit code $LASTEXITCODE."
    }
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$linkedRefPath = Join-Path $repoRoot 'supabase\.temp\project-ref'

if (-not (Test-Path -LiteralPath $SupabaseCliPath -PathType Leaf)) {
    $supabaseCommand = Get-Command supabase.exe -ErrorAction SilentlyContinue
    if (-not $supabaseCommand) {
        throw 'supabase.exe was not found. Install the standalone Supabase CLI or pass -SupabaseCliPath.'
    }
    $SupabaseCliPath = $supabaseCommand.Source
}
$resolvedSupabaseCli = (Resolve-Path -LiteralPath $SupabaseCliPath).Path

Push-Location $repoRoot
try {
    if ($ProjectRef) {
        $linkedRef = if (Test-Path $linkedRefPath) {
            (Get-Content -LiteralPath $linkedRefPath -Raw).Trim()
        } else {
            ''
        }
        if ($linkedRef -ne $ProjectRef) {
            & $resolvedSupabaseCli link --project-ref $ProjectRef
            if ($LASTEXITCODE -ne 0) {
                throw "Could not link Supabase project $ProjectRef."
            }
        }
    } elseif (Test-Path $linkedRefPath) {
        $ProjectRef = (Get-Content -LiteralPath $linkedRefPath -Raw).Trim()
    }

    if (-not $ProjectRef) {
        throw 'Pass -ProjectRef or link the repository to a Supabase project first.'
    }

    if (-not (Test-Path -LiteralPath $PgDumpPath -PathType Leaf)) {
        $pgDumpCommand = Get-Command pg_dump.exe -ErrorAction SilentlyContinue
        if (-not $pgDumpCommand) {
            throw 'pg_dump.exe was not found. Install PostgreSQL 17 client tools or pass -PgDumpPath.'
        }
        $PgDumpPath = $pgDumpCommand.Source
    }
    $script:ResolvedPgDump = (Resolve-Path -LiteralPath $PgDumpPath).Path

    # Windows PowerShell 5 wraps any native stderr line as an ErrorRecord when
    # stderr is captured. Supabase writes harmless progress there, so judge the
    # command by its exit code and still retain the generated connection line.
    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $dryRunOutput = (& $resolvedSupabaseCli db dump --linked --dry-run 2>&1 | Out-String)
    $dryRunExitCode = $LASTEXITCODE
    $ErrorActionPreference = $previousErrorActionPreference
    if ($dryRunExitCode -ne 0) {
        throw 'Supabase CLI could not create temporary backup credentials.'
    }

    $connectionNames = @('PGHOST', 'PGPORT', 'PGUSER', 'PGPASSWORD', 'PGDATABASE')
    $previousEnvironment = @{}
    foreach ($name in $connectionNames) {
        $previousEnvironment[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
        [Environment]::SetEnvironmentVariable(
            $name,
            (Get-DryRunSetting -Text $dryRunOutput -Name $name),
            'Process'
        )
    }

    try {
        $timestamp = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
        $backupDirectory = Join-Path (Join-Path $OutputRoot $ProjectRef) $timestamp
        New-Item -ItemType Directory -Force -Path $backupDirectory | Out-Null

        $archivePath = Join-Path $backupDirectory 'public.dump'
        $schemaPath = Join-Path $backupDirectory 'public_schema.sql'
        $dataPath = Join-Path $backupDirectory 'public_data.sql'

        Invoke-PgDump -Description 'Custom-format public schema backup' -Arguments @(
            '--format=custom', '--schema=public', '--role=postgres',
            '--no-owner', '--no-privileges',
            "--file=$archivePath"
        )
        Invoke-PgDump -Description 'Readable public schema export' -Arguments @(
            '--schema-only', '--schema=public', '--role=postgres',
            '--no-owner', '--no-privileges', '--clean', '--if-exists',
            "--file=$schemaPath"
        )
        Invoke-PgDump -Description 'Readable public data export' -Arguments @(
            '--data-only', '--schema=public', '--role=postgres',
            '--no-owner', '--no-privileges', "--file=$dataPath"
        )

        $files = @($archivePath, $schemaPath, $dataPath) | ForEach-Object {
            $item = Get-Item -LiteralPath $_
            $hash = Get-FileHash -LiteralPath $_ -Algorithm SHA256
            [ordered]@{
                name = $item.Name
                bytes = $item.Length
                sha256 = $hash.Hash.ToLowerInvariant()
            }
        }

        $manifest = [ordered]@{
            created_at_utc = (Get-Date).ToUniversalTime().ToString('o')
            project_ref = $ProjectRef
            scope = 'public schema and data; Supabase-managed auth/storage schemas and Storage objects require separate procedures'
            pg_dump_version = (& $script:ResolvedPgDump --version | Out-String).Trim()
            files = $files
        }
        $manifestPath = Join-Path $backupDirectory 'manifest.json'
        $manifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $manifestPath -Encoding UTF8

        Write-Output "Backup completed: $backupDirectory"
        Write-Output "Manifest: $manifestPath"
        "[$((Get-Date).ToUniversalTime().ToString('o'))] Backup completed: $backupDirectory" |
            Add-Content -LiteralPath $runLogPath -Encoding UTF8
    } finally {
        foreach ($name in $connectionNames) {
            [Environment]::SetEnvironmentVariable($name, $previousEnvironment[$name], 'Process')
        }
    }
} finally {
    Pop-Location
}
