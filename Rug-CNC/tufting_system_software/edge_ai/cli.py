"""
cli.py
------
Command-line entrypoint for the Edge-AI planning stage.

Usage:
    python -m edge_ai.cli --pattern design.json --out optimized_path.csv
    python -m edge_ai.cli --pattern design.csv --strategy nearest_neighbor

This is the process a machine operator (or an upstream design-import
tool) runs before starting a job. Its only responsibility is:
  design file  -->  optimized_path.csv  (consumed by the firmware)
"""

from __future__ import annotations

import argparse
import sys
import time

from edge_ai.config import SystemConfig
from edge_ai.pattern_loader import load_pattern
from edge_ai.path_optimizer import optimize, path_length, nearest_neighbor
from edge_ai.path_writer import write_path_csv


def build_arg_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="edge_ai",
        description="Optimize a carpet tuft pattern into a machine-ready path.",
    )
    parser.add_argument(
        "--pattern", required=True, help="Path to the design file (.json or .csv)"
    )
    parser.add_argument(
        "--out",
        default="optimized_path.csv",
        help="Output path file consumed by the firmware (default: optimized_path.csv)",
    )
    parser.add_argument(
        "--strategy",
        default=None,
        choices=["nearest_neighbor", "two_opt"],
        help="Optimization strategy (default: value from machine_config.yaml)",
    )
    parser.add_argument(
        "--config",
        default=None,
        help="Path to machine_config.yaml (default: config/machine_config.yaml)",
    )
    return parser


def main(argv=None) -> int:
    args = build_arg_parser().parse_args(argv)

    cfg = SystemConfig.load(args.config) if args.config else SystemConfig.load()
    strategy = args.strategy or cfg.planner.strategy

    print(f"[edge_ai] Loading pattern: {args.pattern}")
    points = load_pattern(args.pattern)
    print(f"[edge_ai] Loaded {len(points)} tuft points")

    naive_order = list(range(len(points)))
    naive_len = path_length(points, naive_order)

    t0 = time.perf_counter()
    order = optimize(
        points,
        strategy=strategy,
        max_iterations=cfg.planner.two_opt_max_iterations,
    ) if strategy == "two_opt" else optimize(points, strategy=strategy)
    elapsed_ms = (time.perf_counter() - t0) * 1000.0

    optimized_len = path_length(points, order)
    improvement_pct = (1 - optimized_len / naive_len) * 100 if naive_len > 0 else 0.0

    print(f"[edge_ai] Strategy: {strategy}")
    print(f"[edge_ai] Planning time: {elapsed_ms:.2f} ms")
    print(f"[edge_ai] Path length (unordered):  {naive_len:9.2f} mm")
    print(f"[edge_ai] Path length (optimized):   {optimized_len:9.2f} mm")
    print(f"[edge_ai] Improvement: {improvement_pct:.1f}%")

    write_path_csv(points, order, args.out)
    print(f"[edge_ai] Optimized path written to: {args.out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
