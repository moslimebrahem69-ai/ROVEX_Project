# Autonomous Tufting System -- Software

Software stack for an autonomous cyber-physical tufting machine:
adaptive path planning (Edge-AI) paired with a sub-millisecond
real-time motion control firmware, connected to the physical machine
over a globally standard hardware interface (G-code over USB-serial to
a GRBL-compatible controller board).

This repository contains two components, each independently built and
tested, connected by one plain-text file (see `ipc/PROTOCOL.md`):

| Component  | Language | Role                                         |
|------------|----------|-----------------------------------------------|
| `edge_ai/` | Python 3 | Turns a design into an optimized stitch path  |
| `firmware/`| C (C11)  | Drives the machine in real time, 1000 Hz loop |

See `docs/ARCHITECTURE.md` for a full diagram and rationale, and
`docs/EXTENDING.md` before adding a new machine geometry, hardware
backend, or optimization strategy.

For operator manual and wiring notes, see  
`../docs/ROVEX_DarKareem_Machine_Training_Manual.pdf` in the repo root `docs/` folder.

## Requirements

- Python 3.9+
- `gcc` (or any C11 compiler) and `make`
- Linux or macOS (the serial hardware backend uses POSIX `termios`)

## Quick start (no physical machine required)

```bash
# 1. Install Python dependencies
pip install -r requirements.txt

# 2. Run the Python test suite
python -m unittest discover -s edge_ai/tests -v

# 3. Plan a path from the example design
python -m edge_ai.cli --pattern examples/sample_flower_design.json \
                       --out examples/optimized_path.csv

# 4. Build the firmware
cd firmware && make all && cd ..

# 5. Run the C unit tests
cd firmware && make test && cd ..

# 6. Execute the path against the simulated hardware backend
./firmware/bin/ROVEX examples/optimized_path.csv sim examples/motor_commands.log
```

Step 6 requires no physical machine: it logs every motor command to
`examples/motor_commands.log` exactly as it would send them to real
hardware, so the entire pipeline can be developed and validated before
the machine is wired up.

## Running on the real machine

Once the locally-manufactured machine's controller board is wired and
flashed with GRBL (or a GRBL-compatible firmware):

1. Set `hardware.backend: "serial"` in `config/machine_config.yaml`
   (or pass it on the command line, see below).
2. Set `hardware.serial_port` to the board's device path (e.g.
   `/dev/ttyUSB0`) and confirm `hardware.serial_baud_rate` matches the
   board's configuration (GRBL default: 115200).
3. Run:

```bash
./firmware/bin/ROVEX examples/optimized_path.csv serial /dev/ttyUSB0 115200
```

See `../docs/ROVEX_DarKareem_Machine_Training_Manual.pdf` for GRBL setup and first-run checklist.

## Repository layout

```
tufting_system/
├── README.md                 <- you are here
├── requirements.txt
├── config/
│   └── machine_config.yaml   <- single source of truth for machine limits
├── edge_ai/                  <- Python planning stage
│   ├── cli.py
│   ├── config.py
│   ├── pattern_loader.py
│   ├── path_optimizer.py
│   ├── path_writer.py
│   └── tests/
├── firmware/                 <- C real-time control stage
│   ├── Makefile
│   ├── include/
│   ├── src/
│   │   ├── main.c
│   │   ├── motion_profile.c
│   │   ├── kinematics.c
│   │   ├── path_loader.c
│   │   ├── hal_sim.c         <- no-hardware simulation backend
│   │   └── hal_serial.c      <- real hardware backend (G-code/serial)
│   └── tests/
├── ipc/
│   └── PROTOCOL.md           <- file-format contract between the two stages
├── docs/
│   ├── ARCHITECTURE.md
│   └── EXTENDING.md
├── examples/
│   └── sample_flower_design.json
└── scripts/
    └── run_full_pipeline.sh  <- runs steps 3-6 above in one command
```

## Design principles this codebase follows

1. **One-directional, file-based hand-off** between planning (Python)
   and control (C) -- each stage is independently testable and
   replaceable.
2. **Hardware Abstraction Layer (`firmware/include/hal.h`)** -- all
   physical I/O goes through one interface, so the simulator and the
   real machine run the exact same control-loop code.
3. **A globally standard hardware link** -- G-code over USB-serial to
   a GRBL-compatible board, rather than a proprietary protocol, so the
   machine shop can source or replace controller boards freely.
4. **Config, not hard-coded constants** -- machine limits live in
   `config/machine_config.yaml`, not scattered through source files.
5. **Every module has a test.** `edge_ai/tests/` (Python,
   `unittest`) and `firmware/tests/` (C, a minimal built-in harness --
   no external dependency required).
