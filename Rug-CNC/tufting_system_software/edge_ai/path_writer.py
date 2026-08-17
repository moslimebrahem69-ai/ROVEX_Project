"""
path_writer.py
--------------
Writes an optimized tuft path to the interchange file format defined
in /ipc/PROTOCOL.md. This is the single hand-off point between the
Python planning stage and the C real-time control firmware.

File format (CSV):
    x_mm,y_mm
    12.500,8.250
    14.000,8.250
    ...

Keeping this format simple (plain CSV, no external dependencies) means
the firmware can parse it with nothing but the C standard library --
there is no JSON parser, no shared binary struct layout, and no
version negotiation to get wrong on a resource-constrained controller.
"""

from __future__ import annotations

from typing import List, Tuple

Point = Tuple[float, float]


def write_path_csv(points: List[Point], order: List[int], out_path: str) -> None:
    with open(out_path, "w", encoding="utf-8", newline="") as f:
        f.write("x_mm,y_mm\n")
        for idx in order:
            x, y = points[idx]
            f.write(f"{x:.3f},{y:.3f}\n")
