# ROVEX HMI (Flutter)

Operator panel for the ROVEX tufting machine.

## Features

- Softkey areas: MACHINE, PROGRAM, DESIGN, NEEDLE 3D, ERRORS, PLC, DIAGNOSIS, SETUP
- Modes: JOG / AUTO / MDI / REF
- DRO (X / Y / Z), MCP (Cycle Start / Hold / Stop / Reset / E-Stop), alarms, feed override
- TCP link to C `machine_server` (`127.0.0.1:9100`) with local sim fallback
- Design path extract from image + sample cartouche
- AR / EN / DE localization
- Brand splash + ambient audio

## Run

**Important:** This is a Flutter app. Do **not** press Run on `lib/main.dart` with the Dart VM / “Dart” debugger — that causes `dart:ui is not available on this platform`.

Easiest on Windows: double-click `RUN_ME.bat`

```powershell
cd flutter_tufting_system
flutter pub get
flutter run -d chrome
```

Optional machine runtime (TCP `:9100`):

```powershell
.\run_machine_server.ps1
```

Windows desktop: `.\run_hmi.ps1` (requires Visual Studio C++ desktop tools).

## Quality

```powershell
flutter analyze lib
flutter test
```
