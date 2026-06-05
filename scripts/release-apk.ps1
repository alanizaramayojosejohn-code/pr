# release-apk.ps1 — Builds a signed Flutter APK, uploads to GitHub Releases,
#                   updates public/app-version.json, and deploys Firebase Hosting.
#
# Prerequisites:
#   - flutter, firebase, gh (GitHub CLI) in PATH
#   - gh auth login done once
#   - key.properties configured (see mobile/android/RELEASE.md)
#
# Usage:
#   .\scripts\release-apk.ps1 -Notes "• Fix X"
#   .\scripts\release-apk.ps1 -Notes "• Critical fix" -MinSupported 5
#   .\scripts\release-apk.ps1 -Notes "• Fix X" -SkipBuild   # re-use last APK

param(
    [Parameter(Mandatory = $true)]
    [string]$Notes,
    [int]$MinSupported = -1,
    [switch]$SkipBuild
)

$ErrorActionPreference = 'Stop'
$root       = Split-Path $PSScriptRoot -Parent
$ghRepo     = "alanizaramayojosejohn-code/pr"
$hostingUrl = "https://pr-app-efa2f.web.app"

# ── 0. Check prerequisites ────────────────────────────────────────────────────
foreach ($tool in @('flutter', 'firebase', 'gh')) {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
        Write-Error "'$tool' not found in PATH. Install: winget install GitHub.cli"
    }
}

# ── 1. Read version from pubspec.yaml ─────────────────────────────────────────
$pubspec = Get-Content "$root\mobile\pubspec.yaml" -Raw
if ($pubspec -notmatch 'version:\s*(\d+\.\d+\.\d+)\+(\d+)') {
    Write-Error "Cannot parse version from mobile/pubspec.yaml"
}
$versionName = $Matches[1]
$versionCode  = [int]$Matches[2]
Write-Host "`nBuilding PR v$versionName+$versionCode" -ForegroundColor Cyan

# ── 2. Build release APK ──────────────────────────────────────────────────────
if (-not $SkipBuild) {
    Push-Location "$root\mobile"
    try {
        & "$root\mobile\build_release.ps1"
        if ($LASTEXITCODE -ne 0) { throw "APK build failed" }
    } finally {
        Pop-Location
    }
} else {
    Write-Host "Skipping build (-SkipBuild)" -ForegroundColor DarkYellow
}

# ── 3. Locate APK ─────────────────────────────────────────────────────────────
$apkSrc  = "$root\mobile\build\app\outputs\flutter-apk\app-release.apk"
$apkName = "pr-$versionName.apk"
if (-not (Test-Path $apkSrc)) { Write-Error "APK not found at: $apkSrc" }

# ── 4. Compute sha256 and size ────────────────────────────────────────────────
$hash   = (Get-FileHash $apkSrc -Algorithm SHA256).Hash.ToLower()
$sizeMb = [math]::Round((Get-Item $apkSrc).Length / 1MB, 1)
Write-Host "SHA-256 : $hash" -ForegroundColor DarkGray
Write-Host "Size    : $sizeMb MB" -ForegroundColor DarkGray

# ── 5. Upload APK to GitHub Releases ──────────────────────────────────────────
$tag = "v$versionName"
Write-Host "`nCreando GitHub Release $tag ..." -ForegroundColor Cyan

# Delete existing release+tag if present (upsert behavior — ignore errors)
$prev = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
gh release delete $tag --repo $ghRepo --yes --cleanup-tag 2>&1 | Out-Null
$ErrorActionPreference = $prev

gh release create $tag "${apkSrc}#${apkName}" `
    --repo $ghRepo `
    --title "PR v$versionName" `
    --notes $Notes `
    --latest
if ($LASTEXITCODE -ne 0) { throw "gh release create failed" }

$apkUrl = "https://github.com/$ghRepo/releases/download/$tag/$apkName"
Write-Host "APK disponible en: $apkUrl" -ForegroundColor Green

# ── 6. Resolve min_supported_build ────────────────────────────────────────────
$manifestPath = "$root\public\app-version.json"
if ($MinSupported -lt 0) {
    $existing     = Get-Content $manifestPath -Raw | ConvertFrom-Json
    $MinSupported = $existing.min_supported_build
}

# ── 7. Write public/app-version.json ──────────────────────────────────────────
$manifest = [ordered]@{
    latest_version      = $versionName
    latest_build        = $versionCode
    min_supported_build = $MinSupported
    apk_url             = $apkUrl
    apk_size_mb         = $sizeMb
    sha256              = $hash
    release_notes_es    = $Notes
    released_at         = (Get-Date -Format 'yyyy-MM-dd')
}
$manifest | ConvertTo-Json | Set-Content $manifestPath -Encoding utf8
Write-Host "public/app-version.json actualizado" -ForegroundColor Green

# ── 8. Build PWA ──────────────────────────────────────────────────────────────
Push-Location $root
try {
    npm run build
    if ($LASTEXITCODE -ne 0) { throw "npm run build failed" }
} finally {
    Pop-Location
}

# ── 9. Deploy Firebase Hosting ────────────────────────────────────────────────
Push-Location $root
try {
    firebase deploy --only hosting
    if ($LASTEXITCODE -ne 0) { throw "firebase deploy failed" }
} finally {
    Pop-Location
}

# ── 10. Summary ───────────────────────────────────────────────────────────────
Write-Host "`nRelease completo!" -ForegroundColor Green
Write-Host "  Version  : $versionName+$versionCode"
Write-Host "  Min build: $MinSupported"
Write-Host "  Manifest : $hostingUrl/app-version.json"
Write-Host "  APK URL  : $apkUrl"
Write-Host "  SHA-256  : $hash"
Write-Host ""
Write-Host "Próximos pasos:" -ForegroundColor Yellow
Write-Host "  git add public/app-version.json && git commit -m 'chore: release v$versionName'"
