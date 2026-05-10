# Wave 30 — release-build helper for memory-constrained machines.
#
# The flutter_tools and frontend_server VMs default to a ~1G heap,
# which is not enough on this project after the Wave 30 admin pages
# were added (the dart compiler OOMs in CSE/AllocationSinking pass
# while compiling file_store.dart).
#
# This script:
#   1. Kills any leftover Gradle / Dart daemons that might still
#      hold memory from a previous failed build.
#   2. Bumps the flutter tool's old-gen heap to 4 GB via
#      FLUTTER_VM_OPTIONS so the JIT optimisation pass has room.
#   3. Builds *only* an arm64 APK (saves ~30-40 % memory and
#      shaves minutes off the build versus a fat universal APK).
#   4. Prints the install command at the end.

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot

Write-Host ""
Write-Host "[1/4] Killing leftover dart / java daemons..." -ForegroundColor Cyan
Get-Process -Name dart, java, kotlin-compile-daemon -ErrorAction SilentlyContinue |
    Stop-Process -Force
Start-Sleep -Seconds 1

Write-Host "[2/4] Bumping FLUTTER_VM_OPTIONS for the build..." -ForegroundColor Cyan
# old_gen_heap_size is in MB.  4 GB is comfortable for the optimising
# JIT passes that crash on the default ~1 GB.
$env:FLUTTER_VM_OPTIONS = "--old_gen_heap_size=4096"
$env:DART_VM_OPTIONS    = "--old_gen_heap_size=4096"
Write-Host ("    FLUTTER_VM_OPTIONS = {0}" -f $env:FLUTTER_VM_OPTIONS)

Write-Host "[3/4] Building release APK (arm64-only)..." -ForegroundColor Cyan
Push-Location $projectRoot
try {
    & flutter build apk --release --target-platform android-arm64 --no-tree-shake-icons
    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Host "Build FAILED. Try one of these escape hatches:" -ForegroundColor Yellow
        Write-Host "  1. Close Chrome / Edge / Android Studio to free RAM."
        Write-Host "  2. flutter build apk --release --no-shrink   # disables R8."
        Write-Host "  3. flutter run --profile                     # lighter than --release."
        exit 1
    }
} finally {
    Pop-Location
}

$apkPath = Join-Path $projectRoot "build\app\outputs\flutter-apk\app-release.apk"
Write-Host ""
Write-Host "[4/4] APK ready:" -ForegroundColor Green
Write-Host ("    {0}" -f $apkPath)
$size = (Get-Item $apkPath).Length / 1MB
Write-Host ("    Size: {0:N2} MB" -f $size)
Write-Host ""
Write-Host "Install on the connected phone with:" -ForegroundColor Cyan
Write-Host ("    adb install -r `"{0}`"" -f $apkPath)
