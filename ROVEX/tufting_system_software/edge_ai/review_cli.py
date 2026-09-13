"""Command-line preflight review for a tufting path."""

from __future__ import annotations

import argparse
import json
import sys

from edge_ai.config import SystemConfig
from edge_ai.design_review import review_job
from edge_ai.pattern_loader import load_pattern


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description="Review a ROVEX path before CNC execution.")
    parser.add_argument("--pattern", required=True, help="Original or planned JSON/CSV points")
    parser.add_argument("--gcode", default=None, help="Optional G-code file to inspect")
    parser.add_argument("--image", default=None, help="Optional source design image for AI review")
    parser.add_argument("--config", default=None, help="Path to machine_config.yaml")
    parser.add_argument("--ai", action="store_true", help="Run the optional OpenRouter visual review")
    parser.add_argument("--model", default="openrouter/free", help="OpenRouter model id")
    parser.add_argument("--report", default=None, help="Write the JSON report to this path")
    args = parser.parse_args(argv)

    config = SystemConfig.load(args.config) if args.config else SystemConfig.load()
    points = load_pattern(args.pattern)
    gcode = ""
    if args.gcode:
        with open(args.gcode, "r", encoding="utf-8") as gcode_file:
            gcode = gcode_file.read()

    report = review_job(
        points,
        gcode,
        work_area_x_mm=config.machine.work_area_x_mm,
        work_area_y_mm=config.machine.work_area_y_mm,
        image_path=args.image,
        use_ai=args.ai,
        ai_model=args.model,
    )
    output = json.dumps(report.to_dict(), indent=2, ensure_ascii=True)
    print(output)
    if args.report:
        with open(args.report, "w", encoding="utf-8") as report_file:
            report_file.write(output + "\n")
    return 0 if report.can_start else 2


if __name__ == "__main__":
    sys.exit(main())
