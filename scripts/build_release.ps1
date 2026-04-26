# ═══════════════════════════════════════════════════════════════
#  Talaa — Release build helper
#  Reads SENTRY_DSN from a local .env.flutter file (NOT committed)
#  and forwards it to flutter build via --dart-define.
#
#  Usage:
#    .\scripts\build_release.ps1              # build APK
#    .\scripts\build_release.ps1 -Target ios  # build iOS
#    .\scripts\build_release.ps1 -Target appbundle  # Play Store AAB
# ═══════════════════════════════════════════════════════════════

param(
    [ValidateSet('apk','appbundle','ios')]
    [string]$Target = 'apk'
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$envFile = Join-Path $repoRoot '.env.flutter'

if (-not (Test-Path $envFile)) {
    Write-Host "Creating .env.flutter template (this file is gitignored)" -ForegroundColor Yellow
    @"
# Flutter build-time secrets — NEVER commit this file.
# Add it to .gitignore.
SENTRY_DSN=
APP_ENV=production
"@ | Set-Content -Path $envFile
    Write-Host "Edit $envFile and re-run this script." -ForegroundColor Yellow
    exit 1
}

# Load env file
$defines = @()
Get-Content $envFile | ForEach-Object {
    if ($_ -match '^\s*([A-Z_]+)\s*=\s*(.+)\s*$') {
        $key = $Matches[1]
        $val = $Matches[2].Trim('"').Trim("'")
        if ($val) {
            $defines += "--dart-define=$key=$val"
        }
    }
}

Write-Host "Building flutter $Target with:" -ForegroundColor Cyan
$defines | ForEach-Object {
    if ($_ -match 'SENTRY_DSN') {
        Write-Host "  SENTRY_DSN=*** (loaded)" -ForegroundColor Green
    } else {
        Write-Host "  $_" -ForegroundColor Green
    }
}
Write-Host ""

flutter build $Target --release @defines
