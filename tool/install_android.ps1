param(
    [ValidateSet('debug', 'release')]
    [string]$Mode = 'release',
    [string]$Config = 'config/prod.local.json',
    [string]$Device = '',
    [int]$BuildNumber = 0
)

$ErrorActionPreference = 'Stop'
$workspace = Split-Path -Parent $PSScriptRoot
Set-Location $workspace

$configPath = Resolve-Path -LiteralPath $Config -ErrorAction Stop
$defines = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json

foreach ($key in @('SUPABASE_URL', 'SUPABASE_ANON_KEY')) {
    $value = [string]$defines.$key
    if ([string]::IsNullOrWhiteSpace($value) -or
        $value.Contains('YOUR_') -or
        $value.Contains('PLACEHOLDER')) {
        throw "$key is missing or is a placeholder in $configPath. Build cancelled."
    }
}

$revenueCatKeyName = if ($Mode -eq 'debug') {
    'REVENUECAT_TEST_KEY'
} else {
    'REVENUECAT_ANDROID_KEY'
}
$revenueCatKey = [string]$defines.$revenueCatKeyName
if ([string]::IsNullOrWhiteSpace($revenueCatKey) -or
    $revenueCatKey.Contains('YOUR_') -or
    $revenueCatKey.Contains('PLACEHOLDER')) {
    throw "$revenueCatKeyName is missing or is a placeholder in $configPath. Build cancelled."
}

if ($Mode -eq 'debug' -and -not $revenueCatKey.StartsWith('test_')) {
    throw 'Debug builds must use a RevenueCat Test Store key. Build cancelled.'
}

if ($Mode -eq 'release' -and -not $revenueCatKey.StartsWith('goog_')) {
    throw 'Android release builds must use a RevenueCat Play Store key. Build cancelled.'
}

if (-not ([string]$defines.SUPABASE_URL).StartsWith('https://')) {
    throw 'SUPABASE_URL must use HTTPS. Build cancelled.'
}

$firebasePath = Join-Path $workspace 'android\app\google-services.json'
if (-not (Test-Path -LiteralPath $firebasePath)) {
    throw 'Firebase android/app/google-services.json is missing. Build cancelled.'
}
$firebase = Get-Content -LiteralPath $firebasePath -Raw | ConvertFrom-Json
$firebasePackages = @(
    $firebase.client |
        ForEach-Object { [string]$_.client_info.android_client_info.package_name }
)
if ('com.silarah.app' -notin $firebasePackages) {
    throw 'Firebase configuration does not contain com.silarah.app. Build cancelled.'
}

& python 'tool/verify_firebase_config.py' $configPath
if ($LASTEXITCODE -ne 0) {
    throw 'Firebase release configuration verification failed. Build cancelled.'
}

$deviceArgs = @()
if (-not [string]::IsNullOrWhiteSpace($Device)) {
    $deviceArgs = @('-d', $Device)
}

Write-Host "Building Silarah $Mode with configuration $configPath..."
if ($Mode -eq 'release') {
    # A release must never reuse plugin bytecode produced by a debug build.
    # Recreate Flutter's plugin registry and every Android release artifact so
    # missing/stale plugin classes fail here, before anything reaches a device.
    & flutter clean
    if ($LASTEXITCODE -ne 0) { throw 'Flutter clean failed.' }

    & flutter pub get
    if ($LASTEXITCODE -ne 0) { throw 'Flutter dependency restore failed.' }

    # Integration tests generate a registrant that can contain dev-only native
    # plugins. Remove that ignored artifact after dependency restore so the
    # release command generates a production-only registry.
    $generatedRegistrant = Join-Path $workspace `
        'android\app\src\main\java\io\flutter\plugins\GeneratedPluginRegistrant.java'
    if (Test-Path -LiteralPath $generatedRegistrant) {
        Remove-Item -LiteralPath $generatedRegistrant -Force
    }
}

if ($Mode -eq 'release') {
    # Never ship/install a universal release APK containing every CPU runtime.
    # Play distributes equivalent ABI splits from an AAB; local release
    # installs should use the same per-device footprint.
    $buildArgs = @(
        'build',
        'apk',
        "--$Mode",
        '--split-per-abi',
        "--dart-define-from-file=$configPath"
    )
} else {
    $buildArgs = @(
        'build',
        'apk',
        "--$Mode",
        "--dart-define-from-file=$configPath"
    )
}
if ($BuildNumber -gt 0) {
    $buildArgs += "--build-number=$BuildNumber"
}
& flutter @buildArgs
if ($LASTEXITCODE -ne 0) { throw 'Flutter build failed.' }

Write-Host 'Installing APK without clearing app data...'
$adbCandidates = @()
$adbCommand = Get-Command adb -ErrorAction SilentlyContinue
if ($adbCommand) {
    $adbCandidates += $adbCommand.Source
}
$adbCandidates += Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'
if ($env:ANDROID_SDK_ROOT) {
    $adbCandidates += Join-Path $env:ANDROID_SDK_ROOT 'platform-tools\adb.exe'
}
if ($env:ANDROID_HOME) {
    $adbCandidates += Join-Path $env:ANDROID_HOME 'platform-tools\adb.exe'
}
$adbCandidates = $adbCandidates |
    Where-Object { $_ -and (Test-Path -LiteralPath $_) } |
    Select-Object -Unique

$adb = $adbCandidates | Select-Object -First 1
if (-not $adb) {
    throw 'Android Debug Bridge (adb) was not found. Install Android platform-tools or configure ANDROID_SDK_ROOT.'
}

$adbArgs = @()
if (-not [string]::IsNullOrWhiteSpace($Device)) {
    $adbArgs = @('-s', $Device)
}

$apkPath = if ($Mode -eq 'release') {
    $deviceAbi = (& $adb @adbArgs shell getprop ro.product.cpu.abi).Trim()
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($deviceAbi)) {
        throw 'Could not determine the connected device CPU architecture.'
    }
    $supportedAbis = @('arm64-v8a', 'armeabi-v7a', 'x86_64')
    if ($deviceAbi -notin $supportedAbis) {
        throw "Unsupported device CPU architecture: $deviceAbi"
    }
    Join-Path $workspace "build\app\outputs\flutter-apk\app-$deviceAbi-release.apk"
} else {
    Join-Path $workspace "build\app\outputs\flutter-apk\app-debug.apk"
}
if (-not (Test-Path -LiteralPath $apkPath)) {
    throw "Built APK was not found at $apkPath."
}

& $adb @adbArgs install -r $apkPath
if ($LASTEXITCODE -ne 0) {
    throw 'APK replace-in-place install failed. Existing app data was left untouched.'
}

Write-Host 'Silarah installed successfully.'
