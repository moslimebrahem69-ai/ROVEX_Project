# ROVEX

Tufting / embroidery CNC control for a new GRBL carpet machine.

**Flutter HMI** + **C runtime** (`machine_server`, TCP `:9100`).

This repository is **source only** (no `build/`, no caches, no compiled `.exe`). Mentors: clone, then run the steps below.

---

## Requirements

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (stable)
- Chrome (preview) or Visual Studio C++ (Windows desktop)
- Optional: `gcc` (MinGW) to build the C runtime

---

## Run (mentors)

```powershell
cd flutter_tufting_system
flutter pub get
flutter run -d chrome
```

Or double-click `RUN_ME.bat`.

Do **not** run `lib/main.dart` with the Dart debugger — use Flutter.

Optional machine runtime:

```powershell
.\run_machine_server.ps1
```

If `machine_server.exe` is missing, the script builds it from C source.

Default UI language: **English**.

---

## Layout

```
flutter_tufting_system/          HMI (Dart/Flutter)
tufting_system_software/
  firmware/                      C runtime + GRBL/sim
  edge_ai/                       optional Python path planner
```

---

## License

See `tufting_system_software/LICENSE`.
