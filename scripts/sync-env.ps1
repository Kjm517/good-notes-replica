# Reads .env and writes .dart_defines.json + assets/env for Flutter web.
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
$EnvFile = Join-Path $Root ".env"
$Out = Join-Path $Root ".dart_defines.json"

if (-not (Test-Path $EnvFile)) {
    Write-Host "No .env found. Copy .env.example to .env and fill in your keys:"
    Write-Host "  copy .env.example .env"
    exit 1
}

$values = [ordered]@{}
Get-Content -Path $EnvFile -Encoding UTF8 | ForEach-Object {
    $line = $_.Trim()
    if (-not $line -or $line.StartsWith("#") -or -not $line.Contains("=")) { return }
    $key, $val = $line.Split("=", 2)
    $key = $key.Trim()
    $val = $val.Trim().Trim('"').Trim("'")
    if ($key) { $values[$key] = $val }
}

$json = $values | ConvertTo-Json -Depth 4
# ConvertTo-Json on a hashtable of strings is an object; keep insertion order via PSCustomObject
$obj = New-Object PSCustomObject
foreach ($k in $values.Keys) {
    $obj | Add-Member -NotePropertyName $k -NotePropertyValue $values[$k]
}
($obj | ConvertTo-Json -Depth 4) + "`n" | Out-File -FilePath $Out -Encoding utf8

$assetDir = Join-Path $Root "assets"
New-Item -ItemType Directory -Force -Path $assetDir | Out-Null
$assetEnv = Join-Path $assetDir "env"
$lines = foreach ($k in $values.Keys) { "$k=$($values[$k])" }
($lines -join "`n") + "`n" | Out-File -FilePath $assetEnv -Encoding utf8

Write-Host "Wrote $Out ($($values.Count) key(s))"
Write-Host "Wrote $assetEnv"
