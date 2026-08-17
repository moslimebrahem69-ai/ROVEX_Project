# Launch ROVEX industrial HMI (Windows) + ensure machine_server is up
$ErrorActionPreference = "Continue"
$here = $PSScriptRoot
$root = Split-Path -Parent $here
$exe = Join-Path $root "tufting_system_software\firmware\bin\machine_server.exe"

$listening = Get-NetTCPConnection -LocalPort 9100 -State Listen -ErrorAction SilentlyContinue
if (-not $listening) {
  if (Test-Path $exe) {
    Start-Process -FilePath $exe -ArgumentList "9100" -WorkingDirectory (Split-Path $exe)
    Start-Sleep -Seconds 1
    Write-Host "machine_server started on :9100"
  } else {
    Write-Host "WARNING: machine_server.exe missing — HMI will use local sim"
  }
}

Set-Location $here
flutter run -d windows
