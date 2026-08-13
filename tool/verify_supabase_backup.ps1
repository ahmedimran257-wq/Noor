[CmdletBinding()]
param(
    [string]$BackupDirectory = '',
    [string]$ProjectRef = '',
    [string]$BackupRoot = '',
    [string]$PgRestorePath = (Join-Path $env:LOCALAPPDATA 'Silarah\postgresql-17.10\pgsql\bin\pg_restore.exe')
)

$ErrorActionPreference = 'Stop'
$repository = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if ([string]::IsNullOrWhiteSpace($BackupRoot)) {
    $BackupRoot = Join-Path $repository 'supabase\backups'
}

if ([string]::IsNullOrWhiteSpace($BackupDirectory)) {
    if ([string]::IsNullOrWhiteSpace($ProjectRef)) {
        $projectRefPath = Join-Path $repository 'supabase\.temp\project-ref'
        if (-not (Test-Path -LiteralPath $projectRefPath)) {
            throw 'Pass -ProjectRef or -BackupDirectory.'
        }
        $ProjectRef = (Get-Content -LiteralPath $projectRefPath -Raw).Trim()
    }
    $projectDirectory = Join-Path $BackupRoot $ProjectRef
    $latest = Get-ChildItem -LiteralPath $projectDirectory -Directory |
        Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'manifest.json') } |
        Sort-Object Name -Descending |
        Select-Object -First 1
    if (-not $latest) {
        throw "No complete backup was found under $projectDirectory."
    }
    $BackupDirectory = $latest.FullName
}

$resolvedBackup = (Resolve-Path -LiteralPath $BackupDirectory).Path
$manifestPath = Join-Path $resolvedBackup 'manifest.json'
if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    throw "Backup manifest is missing: $manifestPath"
}
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
if ([string]::IsNullOrWhiteSpace([string]$manifest.project_ref) -or
    -not $manifest.files -or $manifest.files.Count -lt 3) {
    throw 'Backup manifest is incomplete.'
}

foreach ($file in $manifest.files) {
    $path = Join-Path $resolvedBackup ([string]$file.name)
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Backup file is missing: $($file.name)"
    }
    $item = Get-Item -LiteralPath $path
    if ($item.Length -ne [int64]$file.bytes) {
        throw "Backup length mismatch: $($file.name)"
    }
    $hash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($hash -ne ([string]$file.sha256).ToLowerInvariant()) {
        throw "Backup checksum mismatch: $($file.name)"
    }
}

if (-not (Test-Path -LiteralPath $PgRestorePath -PathType Leaf)) {
    $pgRestore = Get-Command pg_restore.exe -ErrorAction SilentlyContinue
    if (-not $pgRestore) {
        throw 'pg_restore.exe was not found. Pass -PgRestorePath.'
    }
    $PgRestorePath = $pgRestore.Source
}

$archivePath = Join-Path $resolvedBackup 'public.dump'
$archiveEntries = & $PgRestorePath --list $archivePath 2>&1
if ($LASTEXITCODE -ne 0 -or -not ($archiveEntries | Select-String 'TABLE')) {
    throw 'The custom-format archive catalogue could not be read.'
}

Write-Output "Backup verified: $resolvedBackup"
Write-Output "Project: $($manifest.project_ref)"
Write-Output "Files: $($manifest.files.Count); checksums and archive catalogue passed"
