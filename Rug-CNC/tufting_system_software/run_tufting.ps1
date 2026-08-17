#!/usr/bin/env powershell
# DTU Tufting System - Quick Runner Script
# Usage: .\run_tufting.ps1 [design_file] [output_file]

param(
    [string]$DesignFile = "examples/sample_flower_design.json",
    [string]$OutputFile = "examples/optimized_path.csv"
)

# Setup PATH for GCC and Make
$env:PATH = "$env:USERPROFILE\scoop\shims;$env:USERPROFILE\scoop\apps\gcc\current\bin;$env:PATH"

Write-Host ""
Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "🎯 DTU TUFTING SYSTEM - AUTOMATED RUNNER" -ForegroundColor Yellow
Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Step 1: Check if design file exists
if (-not (Test-Path $DesignFile)) {
    Write-Host "❌ ERROR: Design file not found: $DesignFile" -ForegroundColor Red
    Write-Host "Available designs:" -ForegroundColor Yellow
    Get-ChildItem "examples/" -Filter "*.json" | ForEach-Object { Write-Host "  • $_" }
    exit 1
}

# Step 2: Run Path Optimizer
Write-Host "[STEP 1] Path Optimization (Edge-AI)" -ForegroundColor Green
Write-Host "Input: $DesignFile" -ForegroundColor White
Write-Host ""

python -m edge_ai.cli --pattern $DesignFile --out $OutputFile

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Path optimization failed!" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "✅ Optimized path saved to: $OutputFile" -ForegroundColor Green
Write-Host ""

# Step 3: Run Simulation
$SimulationLog = $OutputFile -replace "\.csv$", "_sim.log"
Write-Host "[STEP 2] Machine Simulation (Real-Time Control)" -ForegroundColor Green
Write-Host "Input: $OutputFile" -ForegroundColor White
Write-Host "Output: $SimulationLog" -ForegroundColor White
Write-Host ""

.\firmware\bin\ROVEX.exe $OutputFile sim $SimulationLog

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Simulation failed!" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "✅ Simulation completed successfully!" -ForegroundColor Green
Write-Host ""

# Step 4: Display Results
Write-Host "[STEP 3] Results Summary" -ForegroundColor Green
Write-Host ""

if (Test-Path $OutputFile) {
    $optimizedLines = @(Get-Content $OutputFile | Measure-Object -Line).Lines
    Write-Host "Optimized Path Points: $($optimizedLines - 1)"
}

if (Test-Path $SimulationLog) {
    $logLines = @(Get-Content $SimulationLog | Measure-Object -Line).Lines
    Write-Host "Motor Commands Generated: $($logLines - 1)"
}

Write-Host ""
Write-Host "First 10 Motor Commands:" -ForegroundColor Yellow
Write-Host ""
Get-Content $SimulationLog | Select-Object -First 11

Write-Host ""
Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "SUCCESS! Ready for deployment" -ForegroundColor Green
Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Cyan
Write-Host "  1. Review motor commands in: $SimulationLog" -ForegroundColor White
Write-Host "  2. For real machine: .\firmware\bin\ROVEX.exe $OutputFile serial COM3 115200" -ForegroundColor White
Write-Host "  3. For visualization: python create_visualizations.py" -ForegroundColor White
Write-Host ""
