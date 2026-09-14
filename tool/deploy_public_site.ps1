param(
    [string]$ProjectName = 'silarah',
    [string]$Branch = 'main',
    [string]$CommitMessage = 'Deploy current Ivory and Emerald public site',
    [switch]$ValidateOnly
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$workspace = Split-Path -Parent $PSScriptRoot
$siteSource = Join-Path $workspace 'site'

function Assert-Contains {
    param(
        [string]$Path,
        [string]$Expected,
        [string]$Description
    )

    $content = [System.IO.File]::ReadAllText($Path)
    if (-not $content.Contains($Expected)) {
        throw "Public-site validation failed: $Description is missing from $Path."
    }
}

function Assert-CurrentSite {
    param([string]$Root)

    $indexPath = Join-Path $Root 'index.html'
    $stylesPath = Join-Path $Root 'styles.css'
    $privacyPath = Join-Path $Root 'privacy\index.html'
    $wordmarkPath = Join-Path $Root 'assets\silarah-wordmark-v2.png'
    $appIconPath = Join-Path $Root 'assets\silarah-app-icon-v2.png'

    foreach ($requiredPath in @(
        $indexPath,
        $stylesPath,
        $privacyPath,
        $wordmarkPath,
        $appIconPath
    )) {
        if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
            throw "Public-site validation failed: required file is missing: $requiredPath"
        }
    }

    Assert-Contains $stylesPath 'Ivory & Emerald' 'the current theme marker'
    Assert-Contains $stylesPath '#175c45' 'the emerald palette'
    Assert-Contains $stylesPath '/assets/silarah-wordmark-v2.png' 'the current wordmark asset'
    Assert-Contains $indexPath '"price": "299"' 'the monthly launch price'
    Assert-Contains $indexPath '"price": "749"' 'the quarterly launch price'
    Assert-Contains $privacyPath 'Chat translation is no longer offered' 'the translation-retirement disclosure'

    $privacyContent = [System.IO.File]::ReadAllText($privacyPath)
    if ($privacyContent.Contains('MyMemory')) {
        throw 'Public-site validation failed: retired MyMemory disclosure is still present.'
    }
}

if (-not (Test-Path -LiteralPath $siteSource -PathType Container)) {
    throw "Public-site source directory is missing: $siteSource"
}

# Validate the working tree first. Deploying a Git archive or another stale copy
# cannot pass this gate unless it contains the current signed-app visual system.
Assert-CurrentSite $siteSource

$tempRoot = [System.IO.Path]::GetFullPath($env:TEMP).TrimEnd(
    [System.IO.Path]::DirectorySeparatorChar,
    [System.IO.Path]::AltDirectorySeparatorChar
)
$deployDirectory = Join-Path $tempRoot (
    'silarah-site-deploy-' + [Guid]::NewGuid().ToString('N')
)
New-Item -ItemType Directory -Path $deployDirectory | Out-Null

try {
    Get-ChildItem -LiteralPath $siteSource -Force |
        Where-Object { $_.Name -ne '.wrangler' } |
        Copy-Item -Destination $deployDirectory -Recurse -Force

    Assert-CurrentSite $deployDirectory

    $sourceWranglerPrefix = Join-Path $siteSource '.wrangler'
    $sourceFileCount = @(
        Get-ChildItem -LiteralPath $siteSource -Recurse -File -Force |
            Where-Object { -not $_.FullName.StartsWith(
                $sourceWranglerPrefix,
                [StringComparison]::OrdinalIgnoreCase
            ) }
    ).Count
    $packageFileCount = @(
        Get-ChildItem -LiteralPath $deployDirectory -Recurse -File -Force
    ).Count
    if ($sourceFileCount -ne $packageFileCount) {
        throw "Public-site packaging failed: source has $sourceFileCount files but package has $packageFileCount."
    }

    foreach ($relativePath in @('index.html', 'styles.css', 'privacy\index.html')) {
        $sourceHash = (Get-FileHash -LiteralPath (
            Join-Path $siteSource $relativePath
        ) -Algorithm SHA256).Hash
        $packageHash = (Get-FileHash -LiteralPath (
            Join-Path $deployDirectory $relativePath
        ) -Algorithm SHA256).Hash
        if ($sourceHash -ne $packageHash) {
            throw "Public-site packaging failed: $relativePath differs from the working tree."
        }
    }

    Write-Host "Validated current Ivory & Emerald site package ($packageFileCount files)."
    if (-not $ValidateOnly) {
        & npx --yes wrangler pages deploy $deployDirectory `
            --project-name $ProjectName `
            --branch $Branch `
            --commit-message $CommitMessage `
            --commit-dirty=true
        if ($LASTEXITCODE -ne 0) {
            throw 'Cloudflare Pages deployment failed.'
        }
    }
} finally {
    if (Test-Path -LiteralPath $deployDirectory) {
        $resolvedDeployDirectory = [System.IO.Path]::GetFullPath($deployDirectory)
        $requiredPrefix = $tempRoot + [System.IO.Path]::DirectorySeparatorChar
        $safeTemporaryPackage =
            $resolvedDeployDirectory.StartsWith(
                $requiredPrefix,
                [StringComparison]::OrdinalIgnoreCase
            ) -and
            ([System.IO.Path]::GetFileName($resolvedDeployDirectory)).StartsWith(
                'silarah-site-deploy-',
                [StringComparison]::OrdinalIgnoreCase
            )
        if (-not $safeTemporaryPackage) {
            throw "Refusing to remove unexpected deployment path: $resolvedDeployDirectory"
        }
        Remove-Item -LiteralPath $resolvedDeployDirectory -Recurse -Force
    }
}
