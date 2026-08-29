"""
pattern_loader.py
------------------
Reads a carpet design and returns the list of tuft points that the
planner must visit.

Two input formats are supported out of the box:

  1. JSON  -- [{"x": 10.0, "y": 20.0}, ...]
  2. CSV   -- header "x,y" followed by rows of coordinates

This module is intentionally the ONLY place that knows about file
formats. To support a new design source (e.g. parsing an SVG export
from a CAD tool, or a proprietary loom-design format), add a new
`load_xxx()` function here and register it in `load_pattern()`.
That keeps `path_optimizer.py` and the firmware completely decoupled
from how designs are authored.
"""

from __future__ import annotations

import csv
import json
import os
from typing import List, Tuple

Point = Tuple[float, float]


def load_pattern(path: str) -> List[Point]:
    """Load a design file and return a list of (x, y) tuft points in mm."""
    ext = os.path.splitext(path)[1].lower()
    if ext == ".json":
        return _load_json(path)
    if ext == ".csv":
        return _load_csv(path)
    raise ValueError(
        f"Unsupported pattern format '{ext}'. Supported: .json, .csv"
    )


def _load_json(path: str) -> List[Point]:
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)
    points: List[Point] = []
    for entry in data:
        points.append((float(entry["x"]), float(entry["y"])))
    _validate(points)
    return points


def _load_csv(path: str) -> List[Point]:
    points: List[Point] = []
    with open(path, "r", encoding="utf-8", newline="") as f:
        reader = csv.DictReader(f)
        for row in reader:
            points.append((float(row["x"]), float(row["y"])))
    _validate(points)
    return points


def _validate(points: List[Point]) -> None:
    if len(points) < 2:
        raise ValueError("A pattern must contain at least 2 tuft points.")
    for i, (x, y) in enumerate(points):
        if x < 0 or y < 0:
            raise ValueError(
                f"Point {i} has a negative coordinate ({x}, {y}); "
                "the work area origin is (0, 0)."
            )
