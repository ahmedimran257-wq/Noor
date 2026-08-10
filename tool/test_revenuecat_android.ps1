param(
    [ValidateSet('valid', 'cancel', 'failed')]
    [string]$Action = 'valid',
    [string]$Device = 'emulator-5554',
    [string]$Config = 'config/dev.local.json'
)

$ErrorActionPreference = 'Stop'
$workspace = Split-Path -Parent $PSScriptRoot
Set-Location $workspace

$configPath = Resolve-Path -LiteralPath $Config -ErrorAction Stop
$configuration = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
$testKey = [string]$configuration.REVENUECAT_TEST_KEY
if (-not $testKey.StartsWith('test_')) {
    throw 'REVENUECAT_TEST_KEY must be a RevenueCat Test Store key.'
}

$connectedDevices = & flutter devices --machine | ConvertFrom-Json
if ($Device -notin @($connectedDevices.id)) {
    throw "Flutter device '$Device' is not connected."
}

& "$PSScriptRoot\verify_revenuecat_test_store.ps1" -Config $configPath
if ($LASTEXITCODE -ne 0) {
    throw 'RevenueCat Test Store offering verification failed.'
}

$button = switch ($Action) {
    'valid' { 'Test valid purchase' }
    'cancel' { 'Cancel' }
    'failed' { 'Test failed purchase' }
}
Write-Host "When the native Test Store dialog opens, select: $button"

& flutter test `
    'integration_test/revenuecat_test_store_smoke_test.dart' `
    -d $Device `
    "--dart-define-from-file=$configPath" `
    "--dart-define=REVENUECAT_TEST_ACTION=$Action"
if ($LASTEXITCODE -ne 0) {
    throw "RevenueCat Android '$Action' scenario failed."
}

Write-Host "RevenueCat Android '$Action' scenario passed."
