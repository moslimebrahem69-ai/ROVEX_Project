"""
config.py
---------
Loads machine and planner configuration from config/machine_config.yaml.

Keeping all machine-specific numbers (axis limits, units, optimizer
choice) in one YAML file means the Python planner and the C firmware
can both be re-tuned for a different physical machine without touching
any source code -- only the config file changes.
"""

from __future__ import annotations

import os
from dataclasses import dataclass
from typing import Any, Dict

import yaml

DEFAULT_CONFIG_PATH = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "config",
    "machine_config.yaml",
)


@dataclass
class PlannerConfig:
    strategy: str
    two_opt_max_iterations: int
    units: str


@dataclass
class MachineConfig:
    max_velocity_mm_s: float
    max_acceleration_mm_s2: float
    work_area_x_mm: float
    work_area_y_mm: float
    control_frequency_hz: int


@dataclass
class SystemConfig:
    machine: MachineConfig
    planner: PlannerConfig
    raw: Dict[str, Any]

    @classmethod
    def load(cls, path: str = DEFAULT_CONFIG_PATH) -> "SystemConfig":
        with open(path, "r", encoding="utf-8") as f:
            raw = yaml.safe_load(f)

        machine = MachineConfig(
            max_velocity_mm_s=float(raw["machine"]["max_velocity_mm_s"]),
            max_acceleration_mm_s2=float(raw["machine"]["max_acceleration_mm_s2"]),
            work_area_x_mm=float(raw["machine"]["work_area_x_mm"]),
            work_area_y_mm=float(raw["machine"]["work_area_y_mm"]),
            control_frequency_hz=int(raw["machine"]["control_frequency_hz"]),
        )
        planner = PlannerConfig(
            strategy=raw["planner"]["strategy"],
            two_opt_max_iterations=int(raw["planner"]["two_opt_max_iterations"]),
            units=raw["planner"]["units"],
        )
        return cls(machine=machine, planner=planner, raw=raw)
