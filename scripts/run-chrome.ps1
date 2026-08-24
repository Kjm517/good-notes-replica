# Run Notably in Chrome with .env loaded (Supabase, file endpoint, Google login).
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root
& "$PSScriptRoot\sync-env.ps1"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
flutter.bat run -d chrome --web-port=5000 --dart-define-from-file="$Root\.dart_defines.json"
