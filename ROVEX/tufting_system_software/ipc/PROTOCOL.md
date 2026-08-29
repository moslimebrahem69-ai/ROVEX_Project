# Inter-Process Contract: Edge-AI &lt;-&gt; Firmware

This document is the single source of truth for every data format that
crosses the boundary between the Python planning stage (`edge_ai/`)
and the C real-time firmware (`firmware/`). If you change one side,
update this file first, then update the other side to match.

## 1. Path interchange file (`optimized_path.csv`)

Produced by: `edge_ai/path_writer.py`
Consumed by: `firmware/src/path_loader.c`

Plain CSV, UTF-8, comma-separated, one point per line:

```
x_mm,y_mm
12.500,8.250
14.000,8.250
14.000,10.000
...
```

Rules:
- The header line must be exactly `x_mm,y_mm`.
- Coordinates are in millimeters, relative to the machine's work-area
  origin (0, 0) -- normally the home corner of the X/Y gantry.
- Coordinates must be non-negative and within `work_area_x_mm` /
  `work_area_y_mm` from `config/machine_config.yaml`. The firmware
  does not currently soft-limit this; out-of-range values will drive
  the gantry into its physical end stops. Validating this on the
  Python side before handing the file to the firmware is the
  recommended safety practice (see `docs/EXTENDING.md`).
- Row order is the exact head-travel order; the firmware does not
  re-order points.

Rationale for choosing plain CSV over JSON or a binary format: it
requires no parser beyond `fscanf`/`sscanf` on the C side, which keeps
the firmware portable to resource-constrained targets, and it is
trivially human-readable for debugging on the shop floor.

## 2. Hardware command stream (G-code over serial)

Produced by: `firmware/src/hal_serial.c`
Consumed by: the machine's controller board (GRBL or GRBL-compatible
firmware)

Every control tick emits one line of standard G-code over the serial
connection:

```
G1 X<x_mm> Y<y_mm> F<feedrate_mm_per_min>
```

- `G1` = linear interpolated move.
- `F` is in **millimeters per minute** (the G-code convention), even
  though the rest of this codebase uses mm/second internally --
  `hal_serial.c` performs the `* 60` conversion at the hardware
  boundary so that no other file has to think about units in mm/min.

Needle/clutch control:

```
M8   -> engage needle actuator
M9   -> disengage needle actuator
```

`M8`/`M9` are the GRBL coolant-control codes, repurposed here as a
widely-supported, zero-firmware-modification way to toggle a digital
output pin on stock GRBL boards. If your controller board's firmware
maps the needle actuator to a different pin/M-code, change the two
string literals in `hal_serial.c` (`serial_set_needle`) -- this is the
only file that needs to change.

## 3. Simulation log file (`motor_commands.log`)

Produced by: `firmware/src/hal_sim.c` (used when
`hardware.backend: "sim"` in `machine_config.yaml`)

```
tick,time_ms,x_mm,y_mm,feedrate_mm_s,needle
0,445526.833,-,-,-,ENGAGED
1,445526.838,860.000,500.000,0.000,-
...
```

This file is for development, testing, and post-run analysis. It is
NOT read by any other part of the system -- it is a one-way debugging
artifact.

## 4. Configuration file (`config/machine_config.yaml`)

Read by: `edge_ai/config.py` (Python) and, at present, only used as a
compile-time reference by the firmware (`firmware/include/config.h`
mirrors it). See `docs/EXTENDING.md` for how to make the firmware
parse this file at runtime instead, which is recommended once you
move past the simulator.

Both the Python planner and the C firmware MUST be tuned from the same
`max_velocity_mm_s` / `max_acceleration_mm_s2` values, or the
optimizer's assumptions and the firmware's actual motion will drift
apart over time as the machine is re-tuned.
