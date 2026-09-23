param(
    [string]$Config = 'config/prod.local.json'
)

$ErrorActionPreference = 'Stop'
$configPath = Resolve-Path -LiteralPath $Config -ErrorAction Stop
$configuration = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
$publicKey = [string]$configuration.REVENUECAT_ANDROID_KEY
if (-not $publicKey.StartsWith('goog_')) {
    throw 'REVENUECAT_ANDROID_KEY must be a Google Play app key.'
}

# Only read offering configuration. This does not purchase or grant access.
$headers = @{
    Authorization = "Bearer $publicKey"
    'X-Platform' = 'android'
}
$syntheticUser = "pre-release-offering-check-$([guid]::NewGuid())"
$response = Invoke-RestMethod -Headers $headers -Uri (
    "https://api.revenuecat.com/v1/subscribers/$syntheticUser/offerings"
)
$current = @($response.offerings | Where-Object identifier -eq $response.current_offering_id)
if ($current.Count -ne 1) {
    throw 'Expected exactly one current Google Play offering.'
}
$expected = @{
    '$rc_monthly' = @('silarah_monthly', 'monthly')
    '$rc_three_month' = @('silarah_three_month', 'three-month')
}
$packages = @($current[0].packages)
if ($packages.Count -ne $expected.Count) {
    throw 'The current Play offering must contain exactly two launch packages.'
}
foreach ($packageId in $expected.Keys) {
    $matching = @($packages | Where-Object identifier -eq $packageId)
    if ($matching.Count -ne 1) {
        throw "Missing or duplicate Play package: $packageId"
    }
    $package = $matching[0]
    if ($package.platform_product_identifier -cne $expected[$packageId][0] -or
        $package.platform_product_plan_identifier -cne $expected[$packageId][1]) {
        throw "Incorrect Play product/base-plan mapping for $packageId"
    }
    Write-Host "$packageId -> $($package.platform_product_identifier):$($package.platform_product_plan_identifier)"
}
Write-Host "Google Play offering verified: $($current[0].identifier)"
Write-Host 'This is configuration evidence, not a Play purchase or entitlement test.'
