param(
    [string]$Config = 'config/dev.local.json'
)

$ErrorActionPreference = 'Stop'
$configPath = Resolve-Path -LiteralPath $Config -ErrorAction Stop
$configuration = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
$publicKey = [string]$configuration.REVENUECAT_TEST_KEY
if (-not $publicKey.StartsWith('test_')) {
    throw 'REVENUECAT_TEST_KEY is missing or is not a RevenueCat Test Store key.'
}

$headers = @{
    Authorization = "Bearer $publicKey"
    'X-Platform' = 'android'
    'Content-Type' = 'application/json'
}
$syntheticUser = "pre-release-$([guid]::NewGuid())"
$response = Invoke-RestMethod `
    -Headers $headers `
    -Uri "https://api.revenuecat.com/v1/subscribers/$syntheticUser/offerings"

$current = $response.offerings |
    Where-Object identifier -eq $response.current_offering_id |
    Select-Object -First 1
if (-not $current) {
    throw 'RevenueCat Test Store has no current offering.'
}
$packageIds = @($current.packages.identifier)
if ('$rc_monthly' -notin $packageIds -or '$rc_annual' -notin $packageIds) {
    throw 'The current Test Store offering must include monthly and annual packages.'
}

Write-Host "RevenueCat Test Store ready: $($current.identifier)"
Write-Host "Packages: $($packageIds -join ', ')"
