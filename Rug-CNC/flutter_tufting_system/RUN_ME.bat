@echo off
title ROVEX HMI
cd /d "%~dp0"

echo.
echo  ========================================
echo   ROVEX - ROVEX HMI
echo  ========================================
echo.
echo  Do NOT run main.dart with Dart.
echo  Always use: flutter run -d chrome
echo.

where flutter >nul 2>&1
if errorlevel 1 (
  echo ERROR: Flutter not found in PATH.
  echo Install Flutter and reopen this window.
  pause
  exit /b 1
)

echo [1/2] flutter pub get ...
call flutter pub get
if errorlevel 1 (
  echo pub get failed.
  pause
  exit /b 1
)

echo [2/2] Starting on Chrome ...
call flutter run -d chrome
pause
