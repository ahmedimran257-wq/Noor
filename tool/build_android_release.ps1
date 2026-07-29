param(
    [string]$Config = 'config/dev.local.json',
    [switch]$UploadCrashlyticsSymbols
)

$ErrorActionPreference = 'Stop'
$workspace = Split-Path -Parent $PSScriptRoot
Set-Location $workspace

$configPath = Resolve-Path -LiteralPath $Config -ErrorAction Stop
$defines = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
foreach ($key in @(
    'SUPABASE_URL',
    'SUPABASE_ANON_KEY',
    'REVENUECAT_ANDROID_KEY',
    'FIREBASE_PROJECT_ID',
    'FIREBASE_MESSAGING_SENDER_ID',
    'FIREBASE_STORAGE_BUCKET',
    'FIREBASE_ANDROID_API_KEY',
    'FIREBASE_ANDROID_APP_ID',
    'FIREBASE_IOS_API_KEY',
    'FIREBASE_IOS_APP_ID',
    'FIREBASE_IOS_BUNDLE_ID'
)) {
    $value = [string]$defines.$key
    if ([string]::IsNullOrWhiteSpace($value) -or
        $value.Contains('YOUR_') -or
        $value.Contains('PLACEHOLDER')) {
        throw "$key is missing or is a placeholder in $configPath."
    }
}
if (-not ([string]$defines.REVENUECAT_ANDROID_KEY).StartsWith('goog_')) {
    throw 'Release builds require the RevenueCat Google Play public SDK key.'
}

& python 'tool/verify_firebase_config.py' $configPath
if ($LASTEXITCODE -ne 0) {
    throw 'Firebase release configuration verification failed.'
}

$versionLine = Get-Content -LiteralPath 'pubspec.yaml' |
    Where-Object { $_ -match '^version:\s*(\S+)' } |
    Select-Object -First 1
if ($versionLine -notmatch '^version:\s*(\S+)') {
    throw 'Could not determine the Flutter version from pubspec.yaml.'
}
$version = $Matches[1]
$symbolDirectory = Join-Path $env:USERPROFILE ".silarah\release-symbols\$version"
New-Item -ItemType Directory -Force -Path $symbolDirectory | Out-Null

& flutter clean
if ($LASTEXITCODE -ne 0) { throw 'Flutter clean failed.' }
& flutter pub get
if ($LASTEXITCODE -ne 0) { throw 'Flutter dependency restore failed.' }

$arguments = @(
    'build',
    'appbundle',
    '--release',
    "--dart-define-from-file=$configPath",
    "--split-debug-info=$symbolDirectory"
)
if ($UploadCrashlyticsSymbols) {
    $arguments += '--android-project-arg=uploadCrashlyticsSymbols=true'
}
& flutter @arguments
if ($LASTEXITCODE -ne 0) { throw 'Android App Bundle build failed.' }

$bundle = Join-Path $workspace 'build\app\outputs\bundle\release\app-release.aab'
if (-not (Test-Path -LiteralPath $bundle)) {
    throw "Release bundle was not found at $bundle."
}

Write-Host "Release bundle: $bundle"
Write-Host "Dart symbols: $symbolDirectory"
