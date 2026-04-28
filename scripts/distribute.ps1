# Build a release APK and ship it to Firebase App Distribution.
# Usage: .\scripts\distribute.ps1 ["sürüm notu"]
#
# Prereqs (one-time):
#   1. npm install -g firebase-tools     (already done)
#   2. firebase login                    (browser auth)
#   3. Firebase Console → App Distribution → enable
#   4. Add tester emails to a group called "testers"

param(
    [string]$ReleaseNotes = "Yeni beta sürümü"
)

$ErrorActionPreference = "Stop"

$AppId = "1:81824094355:android:043a2083456151f6975566"
$Group = "testers"
$Apk   = "build/app/outputs/flutter-apk/app-release.apk"

Write-Host "==> flutter build apk --release" -ForegroundColor Cyan
flutter build apk --release
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

if (-not (Test-Path $Apk)) {
    Write-Error "APK not found at $Apk"
    exit 1
}

Write-Host "==> firebase appdistribution:distribute" -ForegroundColor Cyan
firebase appdistribution:distribute $Apk `
    --app $AppId `
    --groups $Group `
    --release-notes $ReleaseNotes
