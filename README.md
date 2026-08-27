# ROVEX

### CNC Tufting Control & Design-to-Path HMI

> **ROVEX** is a desktop Human-Machine Interface (HMI) designed to control and manage CNC tufting workflows, from importing a digital design to generating an ordered tufting path and communicating with the machine runtime.

---

## 🚀 Overview

ROVEX is a CNC-oriented software platform built around a **Flutter desktop HMI** with a supporting **C backend** for path optimization.

The main idea is to provide a single interface for operating a computerized tufting machine while keeping the workflow organized:

**Design → Processing → Path Extraction → Color Ordering → Program → Machine Control**

ROVEX is designed to bridge the gap between a digital rug/design file and the physical tufting machine.

The application provides an HMI-style interface for:

* Machine control
* Jogging and manual movement
* Automatic execution
* MDI commands
* Machine referencing / homing
* Machine status monitoring
* Design importing
* Image-based path extraction
* DXF processing
* Multi-color path organization
* Program/path management
* Machine configuration
* PLC-style macros
* Diagnostics and error monitoring
* Local machine simulation

---

## 🎯 Project Goal

The goal of ROVEX is to create a dedicated software environment for CNC tufting machines instead of relying on generic CNC interfaces.

The system is intended to make the complete workflow easier:

1. Import a rug or tufting design.
2. Analyze the design.
3. Extract the required geometry.
4. Detect and organize colors.
5. Convert the design into an ordered tufting path.
6. Prepare the machine program.
7. Connect to the machine controller/runtime.
8. Execute the path while monitoring machine status.
9. Handle color/thread changes in an organized sequence.

---

## 🧠 How ROVEX Works

The overall architecture can be viewed as several connected layers:

```text
                 ┌─────────────────────┐
                 │      User / HMI      │
                 │     Flutter UI       │
                 └──────────┬──────────┘
                            │
                            ▼
                 ┌─────────────────────┐
                 │   Machine Service   │
                 │  Control & State    │
                 └──────────┬──────────┘
                            │
             ┌──────────────┼──────────────┐
             │              │              │
             ▼              ▼              ▼
       Design Engine    DXF Extractor   Runtime Link
             │              │              │
             ▼              ▼              ▼
       Image → Path      DXF → Path     TCP / Runtime
             │              │              │
             └──────────────┼──────────────┘
                            ▼
                 ┌─────────────────────┐
                 │   Ordered Toolpath  │
                 │   / Machine Program │
                 └──────────┬──────────┘
                            │
                            ▼
                 ┌─────────────────────┐
                 │   CNC Machine /     │
                 │   Machine Runtime   │
                 └─────────────────────┘
```

---

# 🖥️ HMI

ROVEX is built as a Flutter desktop application with an industrial HMI-oriented interface.

The application includes multiple operational areas:

* Machine
* Program
* Design
* Needle / 3D visualization
* Errors
* PLC
* Diagnosis
* Setup

The machine state model supports:

```text
IDLE
RUNNING
HOLD
ALARM
HOMING
```

and machine modes include:

```text
JOG
AUTO
MDI
REF
```

---

# 🎨 Design Processing

ROVEX supports processing digital designs before sending them to the machine.

## Image Workflow

For bitmap/image designs, the system performs a multi-stage extraction process.

### Processing pipeline

```text
Image
  │
  ▼
Foreground Detection
  │
  ▼
Color Quantization
  │
  ▼
Color Grouping
  │
  ▼
Connected Region Detection
  │
  ▼
Contour Extraction
  │
  ▼
Contour Smoothing
  │
  ▼
Ordered Tuft Points
```

The image path extractor:

* Detects foreground pixels.
* Separates the foreground from the background.
* Quantizes the design into dominant colors.
* Groups similar colors.
* Detects connected regions.
* Extracts contours.
* Smooths extracted contours.
* Produces an ordered list of tuft points.

The implementation limits the processing image size and the number of color groups/points to keep the extraction manageable.

---

# 🌈 Multi-Color Tufting

One of the important concepts in ROVEX is **color-aware toolpath generation**.

Instead of treating the entire design as one path, the system organizes points into color groups.

Example:

```text
Color 1
 ├── Point 1
 ├── Point 2
 ├── Point 3
 └── ...

Color 2
 ├── Point 1
 ├── Point 2
 ├── Point 3
 └── ...

Color 3
 ├── Point 1
 ├── Point 2
 ├── Point 3
 └── ...
```

The color groups are processed sequentially.

This allows the HMI to know which color is currently being processed and supports a workflow where the machine can pause between color/thread groups for a thread change.

---

# 📐 DXF Support

ROVEX also includes an ASCII DXF extractor.

Unlike bitmap processing, DXF processing works directly with vector geometry.

The DXF workflow is:

```text
DXF File
   │
   ▼
DXF Tokenization
   │
   ▼
Entity Parsing
   │
   ▼
Layer Detection
   │
   ▼
Geometry Extraction
   │
   ▼
Path Generation
```

DXF layers are used as logical color/thread groups.

This makes DXF useful for designs created in CAD software where different layers can represent different thread colors.

The DXF extractor also supports geometric curves such as arcs/circles by converting them into smooth path segments.

---

# 🛣️ Path Generation

The extracted geometry is converted into a sequence of machine points.

A point can contain information such as:

```text
X
Y
Color
Color Order
```

The HMI can therefore track the current position inside the program and determine the active color group.

This provides the foundation for:

* Path visualization
* Program execution
* Progress tracking
* Color-change handling
* Machine synchronization

---

# ⚙️ Path Optimization

ROVEX contains a C backend for path optimization.

The current backend includes optimization approaches such as:

* Nearest Neighbor
* 2-opt optimization

The objective is to reduce unnecessary travel between points.

Conceptually:

```text
Raw Path
   │
   ▼
Path Optimization
   │
   ├── Nearest Neighbor
   │
   └── 2-Opt Improvement
   │
   ▼
Optimized Path
```

Reducing unnecessary movement can help improve machine efficiency and reduce non-production travel.

---

# 🔌 Machine Communication

The machine control layer is handled primarily by `MachineService`.

The system is designed around a shared line-based communication protocol.

The architecture supports communication with:

* A local machine runtime
* A network-connected machine controller
* Arduino/ESP-based controller architecture
* Desktop C runtime

The runtime communication uses a TCP socket connection.

Conceptually:

```text
ROVEX HMI
   │
   │ JSON Lines / Commands
   ▼
Runtime Link
   │
   ▼
Machine Runtime
   │
   ▼
CNC Controller / Hardware
```

The runtime link uses:

```text
Host
Port
TCP Socket
Line-Based Messages
```

The default local runtime profile uses:

```text
Host: 127.0.0.1
Port: 9100
```

---

# 🧪 Local Simulation

ROVEX does not require a physical machine for every development/testing session.

When a real runtime is not available, the application can fall back to a local simulation.

This makes it possible to develop and test:

* HMI screens
* Machine states
* Program execution
* Position updates
* UI behavior
* Path progress
* Machine workflow

without having the physical CNC machine connected.

---

# 🧰 Technology Stack

## Frontend / HMI

* Flutter
* Dart
* Material 3
* Provider

## Image Processing

* Dart image processing
* Bitmap analysis
* Color quantization
* Contour extraction
* Path generation

## Vector Processing

* ASCII DXF parser
* CAD geometry extraction
* Layer-based color grouping

## Native Backend

* C
* Path optimization
* Nearest Neighbor
* 2-opt

## Runtime Communication

* TCP sockets
* Line-based communication
* JSON messages

## Desktop

The current application is structured primarily as a Flutter desktop HMI.

---

# 📦 Main Dependencies

The current Flutter application uses packages including:

```text
provider
file_picker
uuid
ffi
desktop_drop
image
cross_file
audioplayers
```

These provide state management, file selection, native interoperability, drag-and-drop, image processing and audio functionality.

---

# 📁 Project Structure

The repository is currently organized around the following structure:

```text
ROVEX_Project/
│
├── Rug-CNC/
│   │
│   ├── README.md
│   ├── BRANDING_README.md
│   ├── START_HERE.txt
│   │
│   └── flutter_tufting_system/
│       │
│       ├── assets/
│       │   ├── audio/
│       │   ├── brand/
│       │   └── designs/
│       │
│       ├── c_backend/
│       │   └── src/
│       │       └── path_optimizer.c
│       │
│       ├── lib/
│       │   ├── config/
│       │   ├── l10n/
│       │   ├── models/
│       │   ├── screens/
│       │   ├── services/
│       │   └── theme/
│       │
│       ├── pubspec.yaml
│       ├── analysis_options.yaml
│       └── RUN_ME.bat
│
└── README.md
```

---

# 🧩 Important Modules

## `lib/main.dart`

Application entry point.

Responsible for:

* Initializing Flutter.
* Creating the ROVEX application.
* Registering providers.
* Configuring the Material theme.
* Loading the splash screen.

---

## `lib/services/machine_service.dart`

One of the core modules of the project.

Responsible for:

* Machine state management.
* Runtime connection.
* Reconnection attempts.
* Local simulation.
* Machine profiles.
* Program points.
* Color groups.
* Design state.
* G-code/program data.
* Machine control workflow.

---

## `lib/services/path_extractor.dart`

Responsible for converting bitmap designs into multi-color tufting paths.

Main stages:

```text
Image
→ Foreground
→ Colors
→ Regions
→ Contours
→ Smoothing
→ Ordered Points
```

---

## `lib/services/dxf_parser.dart`

Responsible for extracting machine paths from ASCII DXF designs.

DXF layers are treated as logical color groups.

---

## `lib/services/runtime_link.dart`

Provides the runtime communication abstraction.

The implementation can use platform-specific runtime communication while keeping the machine service independent from the underlying transport implementation.

---

## `c_backend/src/path_optimizer.c`

Native C implementation for path optimization.

Includes:

* Distance calculations
* Path-length calculation
* Nearest-neighbor ordering
* 2-opt optimization

---

# 🖥️ Getting Started

## Requirements

Before running ROVEX, make sure you have:

* Flutter SDK
* Dart SDK
* Git
* A supported desktop development environment
* C toolchain if native backend functionality is required

---

## Clone the Repository

```bash
git clone https://github.com/moslimebrahem69-ai/ROVEX_Project.git
cd ROVEX_Project
```

---

## Enter the Flutter Application

```bash
cd Rug-CNC/flutter_tufting_system
```

---

## Install Dependencies

```bash
flutter pub get
```

---

## Check Flutter Environment

```bash
flutter doctor
```

Resolve any missing desktop development dependencies reported by Flutter.

---

## Run the Application

You can use:

```bash
flutter run
```

or, on Windows:

```bash
flutter run -d windows
```

The project also contains a `RUN_ME.bat` helper script.

---

# 🧪 Development Workflow

A typical development workflow is:

```text
1. Start ROVEX
       │
       ▼
2. Configure / select machine
       │
       ▼
3. Import design
       │
       ├── Bitmap
       │
       └── DXF
       │
       ▼
4. Extract geometry
       │
       ▼
5. Organize colors
       │
       ▼
6. Generate ordered path
       │
       ▼
7. Optimize path
       │
       ▼
8. Load program
       │
       ▼
9. Connect to runtime
       │
       ▼
10. Execute / monitor machine
```

---

# 🏭 Target Application

ROVEX is intended for CNC tufting and automated rug production workflows.

The architecture is designed around the needs of a dedicated tufting machine:

* Digital rug designs
* Multiple thread colors
* CNC movement
* Needle operation
* Machine coordinates
* Work coordinates
* Program execution
* Machine status
* Referencing
* Diagnostics
* Runtime communication

---

# ⚠️ Current Development Status

ROVEX is an **active development project**.

The repository currently contains a functional Flutter HMI architecture, design/path processing components, DXF extraction, machine-service infrastructure, local simulation and a C path-optimization component.

The complete physical-machine production pipeline should be considered under development until the final controller firmware, machine hardware, communication protocol and production validation are fully integrated.

> **Important:** Software simulation and path generation should not be considered proof of safe physical machine operation.

Before connecting ROVEX to a real CNC machine, validate:

* Axis directions
* Coordinate limits
* Emergency-stop behavior
* Homing/reference procedure
* Feed rates
* Needle movement
* Motor configuration
* Communication reliability
* Limit switches
* Machine offsets
* Dry-run behavior

---

# 🗺️ Roadmap

Potential future development areas include:

* [ ] Complete ESP32 machine controller integration
* [ ] Production-ready CNC communication protocol
* [ ] Real-time machine telemetry
* [ ] Improved G-code generation
* [ ] Advanced toolpath optimization
* [ ] Better color-change automation
* [ ] Needle control integration
* [ ] End-stop and safety integration
* [ ] Machine calibration workflow
* [ ] Advanced 3D machine visualization
* [ ] Job/project management
* [ ] Production statistics
* [ ] Error logging
* [ ] Automatic recovery
* [ ] Hardware-in-the-loop testing
* [ ] Production validation

---

# 🔐 Safety

ROVEX is software for controlling physical machinery.

Never connect experimental software directly to production hardware without proper testing and safety controls.

Always use:

* Emergency stop
* Physical limit switches
* Safe machine limits
* Controlled feed rates
* Dry runs
* Hardware interlocks
* Proper machine grounding
* Manual supervision during testing

The software must never be considered a replacement for physical machine safety systems.

---

# 🤝 Contributing

Contributions, improvements and technical feedback are welcome.

For major changes:

1. Create a branch.
2. Implement the change.
3. Test the application.
4. Verify that existing functionality still works.
5. Commit the changes.
6. Open a Pull Request.

Example:

```bash
git checkout -b feature/my-feature
git add .
git commit -m "Add: my feature"
git push origin feature/my-feature
```

---

# 📜 License

The licensing model for ROVEX should be defined by the project owner before the project is distributed publicly as an open-source project.

Until an explicit license is added, the repository should not be assumed to grant broad rights to copy, modify, redistribute or commercially use the code.

---

# 👨‍💻 Project

**ROVEX — CNC Tufting Control System**

Built as a dedicated HMI and software control layer for automated CNC tufting workflows.

**Repository:** `moslimebrahem69-ai/ROVEX_Project`

---

## ⭐ ROVEX

```text
DESIGN
   ↓
PROCESS
   ↓
EXTRACT
   ↓
OPTIMIZE
   ↓
PROGRAM
   ↓
CONTROL
   ↓
TUFT
```

**From digital design to automated tufting.**
