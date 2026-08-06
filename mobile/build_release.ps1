# Self-healing release build for Windows.
# Root cause: Windows Defender holds file handles on newly written files,
# preventing Gradle's ATOMIC_MOVE from renaming {hash}-{uuid} -> {hash}.
# This script commits orphaned temp dirs and retries until the build passes.
#
# For a permanent fix, run once as Administrator:
#   Add-MpPreference -ExclusionPath "C:\gradle-home"
#   Add-MpPreference -ExclusionPath "$env:LOCALAPPDATA\Android\sdk"

param(
    [int]$MaxRetries = 10,
    [string]$TransformsDir = "C:\gradle-home\caches\8.14\transforms"
)

function Add-DefenderExclusion {
    try {
        Add-MpPreference -ExclusionPath "C:\gradle-home" -ErrorAction Stop
        Add-MpPreference -ExclusionPath "$env:LOCALAPPDATA\Android\sdk" -ErrorAction Stop
        Write-Host "  [defender] Exclusiones de Windows Defender agregadas." -ForegroundColor Green
    } catch {
        Write-Host "  [defender] No se pudo agregar exclusion (ejecutar como Administrador para fix permanente)." -ForegroundColor DarkYellow
    }
}

function Repair-TransformCache {
    if (-not (Test-Path $TransformsDir)) { return }
    $entries = Get-ChildItem $TransformsDir -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match "^([0-9a-f]{32})-[0-9a-f-]{36}$" }
    if ($entries.Count -eq 0) { return }
    $committed = 0
    foreach ($entry in $entries) {
        $hash = $entry.Name.Substring(0, 32)
        $dest = Join-Path $TransformsDir $hash
        if (-not (Test-Path $dest)) {
            try { Copy-Item -Path $entry.FullName -Destination $dest -Recurse -Force -ErrorAction Stop; $committed++ }
            catch { }
        }
        # Remove temp dir — Gradle re-tries commit every run if it still exists
        try { Remove-Item -Path $entry.FullName -Recurse -Force -ErrorAction Stop } catch { }
    }
    Write-Host "  [transform-fix] $committed nuevos / $($entries.Count) temps eliminados." -ForegroundColor DarkCyan
}

Set-Location $PSScriptRoot

Add-DefenderExclusion

for ($attempt = 1; $attempt -le $MaxRetries; $attempt++) {
    Write-Host "`n=== Intento $attempt / $MaxRetries ===" -ForegroundColor Cyan
    Repair-TransformCache

    flutter build apk --release
    if ($LASTEXITCODE -eq 0) {
        Write-Host "`nBuild exitoso." -ForegroundColor Green
        exit 0
    }

    Write-Host "`nFalló (exit $LASTEXITCODE). Reparando cache..." -ForegroundColor Yellow
    Repair-TransformCache
}

Write-Host "`nTodos los $MaxRetries intentos fallaron." -ForegroundColor Red
Write-Host "Fix permanente: ejecutar como Administrador y correr:" -ForegroundColor Yellow
Write-Host '  Add-MpPreference -ExclusionPath "C:\gradle-home"' -ForegroundColor White
exit 1
