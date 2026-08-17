# Start ROVEX C machine runtime (TCP 127.0.0.1:9100)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$exe = Join-Path $root "tufting_system_software\firmware\bin\machine_server.exe"
if (-not (Test-Path $exe)) {
  Write-Host "Building machine_server..."
  Push-Location (Join-Path $root "tufting_system_software\firmware")
  New-Item -ItemType Directory -Force -Path bin | Out-Null
  gcc -std=c11 -D_WIN32 -O2 -Wall -Wextra -Iinclude -o bin/machine_server.exe `
    src/machine_server.c src/machine_runtime.c src/motion_profile.c `
    src/kinematics.c src/path_loader.c src/hal_sim.c src/hal_serial_win.c `
    -lm -lws2_32
  Pop-Location
}
Write-Host "Starting $exe"
& $exe 9100
