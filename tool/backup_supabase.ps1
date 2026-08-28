[CmdletBinding()]
param(
    [string]$ProjectRef,
    [string]$OutputRoot = '',
    [string]$PgDumpPath = (Join-Path $env:LOCALAPPDATA 'Silarah\postgresql-17.10\pgsql\bin\pg_dump.exe'),
    [string]$PgRestorePath = (Join-Path $env:LOCALAPPDATA 'Silarah\postgresql-17.10\pgsql\bin\pg_restore.exe'),
    [string]$SupabaseCliPath = (Join-Path $env:LOCALAPPDATA 'Silarah\supabase\supabase.exe')
)

$ErrorActionPreference = 'Stop'
$repository = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
    $OutputRoot = Join-Path $repository 'supabase\backups'
}
$runLogDirectory = Join-Path $OutputRoot 'logs'
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

function Resolve-RequiredTool {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$CommandName
    )
    if (Test-Path -LiteralPath $Path -PathType Leaf) {
        return (Resolve-Path -LiteralPath $Path).Path
    }
    $command = Get-Command $CommandName -ErrorAction SilentlyContinue
    if (-not $command) { throw "$CommandName was not found." }
    return $command.Source
}

function Invoke-NativeChecked {
    param(
        [Parameter(Mandatory = $true)][string]$Executable,
        [Parameter(Mandatory = $true)][string[]]$Arguments,
        [Parameter(Mandatory = $true)][string]$Description
    )
    & $Executable @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$Description failed with exit code $LASTEXITCODE."
    }
}

function Get-ArchiveTableRows {
    param([Parameter(Mandatory = $true)][string]$DataSqlPath)
    $rows = [ordered]@{}
    $activeKey = $null
    foreach ($line in [System.IO.File]::ReadLines($DataSqlPath)) {
        if ($null -eq $activeKey) {
            $match = [regex]::Match(
                $line,
                '^COPY (?<schema>[a-z_][a-z0-9_]*)\.(?<table>[a-z_][a-z0-9_]*) \(.*\) FROM stdin;$'
            )
            if ($match.Success) {
                $activeKey = "$($match.Groups['schema'].Value).$($match.Groups['table'].Value)"
                $rows[$activeKey] = [int64]0
            }
            continue
        }
        if ($line -eq '\.') {
            $activeKey = $null
        } else {
            $rows[$activeKey] = [int64]$rows[$activeKey] + 1
        }
    }
    if ($null -ne $activeKey) { throw 'The archive data export ended inside a COPY block.' }
    return $rows
}

$resolvedSupabaseCli = Resolve-RequiredTool -Path $SupabaseCliPath -CommandName 'supabase.exe'
$resolvedPgDump = Resolve-RequiredTool -Path $PgDumpPath -CommandName 'pg_dump.exe'
$resolvedPgRestore = Resolve-RequiredTool -Path $PgRestorePath -CommandName 'pg_restore.exe'
$linkedRefPath = Join-Path $repository 'supabase\.temp\project-ref'
$previousLinkedRef = if (Test-Path -LiteralPath $linkedRefPath) {
    (Get-Content -LiteralPath $linkedRefPath -Raw).Trim()
} else { '' }
$linkChanged = $false
$connectionNames = @('PGHOST', 'PGPORT', 'PGUSER', 'PGPASSWORD', 'PGDATABASE')
$previousEnvironment = @{}
$environmentApplied = $false

try {
    Push-Location $repository
    try {
        if ([string]::IsNullOrWhiteSpace($ProjectRef)) {
            $ProjectRef = $previousLinkedRef
        }
        if ($ProjectRef -notmatch '^[a-z]{20}$') {
            throw 'Pass a valid 20-character Supabase project reference.'
        }
        if ($previousLinkedRef -ne $ProjectRef) {
            & $resolvedSupabaseCli link --project-ref $ProjectRef
            if ($LASTEXITCODE -ne 0) { throw "Could not link Supabase project $ProjectRef." }
            $linkChanged = $true
        }

        $previousErrorActionPreference = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        $dryRunOutput = (& $resolvedSupabaseCli db dump --linked --dry-run 2>&1 | Out-String)
        $dryRunExitCode = $LASTEXITCODE
        $ErrorActionPreference = $previousErrorActionPreference
        if ($dryRunExitCode -ne 0) {
            throw 'Supabase CLI could not create temporary backup credentials.'
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

    $timestamp = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
    $backupDirectory = Join-Path (Join-Path $OutputRoot $ProjectRef) $timestamp
    New-Item -ItemType Directory -Force -Path $backupDirectory | Out-Null
    $archivePath = Join-Path $backupDirectory 'app.dump'
    $schemaPath = Join-Path $backupDirectory 'app_schema.sql'
    $dataPath = Join-Path $backupDirectory 'app_data.sql'

    Invoke-NativeChecked -Executable $resolvedPgDump `
        -Description 'Custom-format app-owned database backup' `
        -Arguments @(
            '--format=custom', '--role=postgres', '--no-owner', '--no-privileges',
            '--schema=public', '--schema=private', '--schema=api_private',
            '--exclude-table-data=public.spatial_ref_sys',
            "--file=$archivePath"
        )
    Invoke-NativeChecked -Executable $resolvedPgRestore `
        -Description 'Readable app-owned schema extraction' `
        -Arguments @('--schema-only', '--no-owner', '--no-privileges', "--file=$schemaPath", $archivePath)
    Invoke-NativeChecked -Executable $resolvedPgRestore `
        -Description 'Readable app-owned data extraction' `
        -Arguments @('--data-only', '--no-owner', '--no-privileges', "--file=$dataPath", $archivePath)

    $tableRows = Get-ArchiveTableRows -DataSqlPath $dataPath
    if ($tableRows.Count -lt 1) { throw 'The archive contains no app-owned table data sections.' }
    $archiveCatalogue = @(& $resolvedPgRestore --list $archivePath 2>&1)
    if ($LASTEXITCODE -ne 0) { throw 'Could not read the custom archive catalogue.' }
    $catalogueKinds = [ordered]@{}
    foreach ($line in $archiveCatalogue) {
        if ([string]$line -match '^\d+; \d+ \d+ (?<kind>.+?) (?<schema>public|private|api_private) ') {
            $kind = $matches['kind']
            if (-not $catalogueKinds.Contains($kind)) { $catalogueKinds[$kind] = 0 }
            $catalogueKinds[$kind] = [int]$catalogueKinds[$kind] + 1
        }
    }

    $files = @($archivePath, $schemaPath, $dataPath) | ForEach-Object {
        $item = Get-Item -LiteralPath $_
        $hash = Get-FileHash -LiteralPath $_ -Algorithm SHA256
        [ordered]@{
            name = $item.Name
            bytes = $item.Length
            sha256 = $hash.Hash.ToLowerInvariant()
        }
    }
    $rowManifest = @($tableRows.GetEnumerator() | Sort-Object Name | ForEach-Object {
        $parts = $_.Name.Split('.', 2)
        [ordered]@{ schema = $parts[0]; table = $parts[1]; rows = [int64]$_.Value }
    })
    $inventoryManifest = @($catalogueKinds.GetEnumerator() | Sort-Object Name | ForEach-Object {
        [ordered]@{ kind = $_.Name; count = [int]$_.Value }
    })
    $manifest = [ordered]@{
        format_version = 2
        created_at_utc = (Get-Date).ToUniversalTime().ToString('o')
        project_ref = $ProjectRef
        scope = 'app-owned public, private, and api_private schemas; managed Auth, Storage metadata/objects, Vault secrets, and platform extensions require Supabase-managed recovery procedures'
        pg_dump_version = (& $resolvedPgDump --version | Out-String).Trim()
        table_rows = $rowManifest
        archive_inventory = $inventoryManifest
        files = $files
    }
    $manifestPath = Join-Path $backupDirectory 'manifest.json'
    $manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $manifestPath -Encoding UTF8

    Write-Output "Backup completed: $backupDirectory"
    Write-Output "Manifest: $manifestPath"
    Write-Output "Snapshot inventory: $($rowManifest.Count) app-owned tables"
    "[$((Get-Date).ToUniversalTime().ToString('o'))] Backup completed: $backupDirectory" |
        Add-Content -LiteralPath $runLogPath -Encoding UTF8
} finally {
    if ($environmentApplied) {
        foreach ($name in $connectionNames) {
            [Environment]::SetEnvironmentVariable($name, $previousEnvironment[$name], 'Process')
        }
    }
    if ($linkChanged) {
        Push-Location $repository
        try {
            if ($previousLinkedRef -match '^[a-z]{20}$') {
                & $resolvedSupabaseCli link --project-ref $previousLinkedRef | Out-Null
                if ($LASTEXITCODE -ne 0) { throw 'Could not restore the previous Supabase project link.' }
            } else {
                & $resolvedSupabaseCli unlink --yes | Out-Null
                if ($LASTEXITCODE -ne 0) { throw 'Could not remove the temporary Supabase project link.' }
            }
        } finally {
            Pop-Location
        }
    }
}
