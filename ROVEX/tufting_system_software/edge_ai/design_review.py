"""Deterministic and optional AI review of a tufting job.

The deterministic checks are authoritative. The language model can explain
visual or G-code concerns, but it can never approve a job that fails machine
limits or replace the real-time controller.
"""

from __future__ import annotations

import base64
import json
import math
import os
import re
import urllib.error
import urllib.request
from dataclasses import asdict, dataclass, field
from typing import Any, Dict, List, Optional, Sequence, Tuple

Point = Tuple[float, float]


@dataclass
class ReviewReport:
    point_count: int
    bounds: Dict[str, float]
    duplicate_points: int
    out_of_bounds: int
    large_jumps: int
    motion_commands: int
    needle_on_commands: int
    needle_off_commands: int
    deterministic_errors: List[str] = field(default_factory=list)
    warnings: List[str] = field(default_factory=list)
    ai_review: Optional[Dict[str, Any]] = None

    @property
    def can_start(self) -> bool:
        return not self.deterministic_errors and self.point_count >= 2

    def to_dict(self) -> Dict[str, Any]:
        result = asdict(self)
        result["can_load"] = self.can_start
        result["can_start"] = self.can_start
        return result


def review_job(
    points: Sequence[Point],
    gcode: str = "",
    *,
    work_area_x_mm: float,
    work_area_y_mm: float,
    max_jump_mm: float = 50.0,
    image_path: Optional[str] = None,
    use_ai: bool = False,
    ai_model: str = "openrouter/free",
    api_key: Optional[str] = None,
) -> ReviewReport:
    """Review a planned job without sending anything to the machine."""
    errors: List[str] = []
    warnings: List[str] = []
    points = list(points)

    if len(points) < 2:
        errors.append("The path must contain at least two points.")

    duplicate_points = sum(
        1 for previous, current in zip(points, points[1:]) if previous == current
    )
    if duplicate_points:
        warnings.append(f"{duplicate_points} consecutive duplicate point(s).")

    out_of_bounds = sum(
        1
        for x, y in points
        if x < 0 or y < 0 or x > work_area_x_mm or y > work_area_y_mm
    )
    if out_of_bounds:
        errors.append(f"{out_of_bounds} point(s) are outside the configured work area.")

    large_jumps = sum(
        1
        for previous, current in zip(points, points[1:])
        if math.dist(previous, current) > max_jump_mm
    )
    if large_jumps:
        warnings.append(f"{large_jumps} jump(s) exceed {max_jump_mm:.1f} mm.")

    xs = [point[0] for point in points]
    ys = [point[1] for point in points]
    bounds = {
        "min_x_mm": min(xs, default=0.0),
        "max_x_mm": max(xs, default=0.0),
        "min_y_mm": min(ys, default=0.0),
        "max_y_mm": max(ys, default=0.0),
    }

    motion_commands = len(re.findall(r"(?m)^\s*G(?:0|1|2|3)\b", gcode))
    needle_on_commands = len(re.findall(r"(?m)^\s*M8\b", gcode))
    needle_off_commands = len(re.findall(r"(?m)^\s*M9\b", gcode))
    if gcode and motion_commands == 0:
        errors.append("The G-code contains no motion commands.")
    if needle_on_commands != needle_off_commands:
        warnings.append("M8 and M9 counts do not match; inspect needle state transitions.")

    report = ReviewReport(
        point_count=len(points),
        bounds=bounds,
        duplicate_points=duplicate_points,
        out_of_bounds=out_of_bounds,
        large_jumps=large_jumps,
        motion_commands=motion_commands,
        needle_on_commands=needle_on_commands,
        needle_off_commands=needle_off_commands,
        deterministic_errors=errors,
        warnings=warnings,
    )

    if use_ai:
        report.ai_review = _request_ai_review(
            report,
            gcode,
            image_path=image_path,
            model=ai_model,
            api_key=api_key or os.getenv("OPENROUTER_API_KEY"),
        )
    return report


def _request_ai_review(
    report: ReviewReport,
    gcode: str,
    *,
    image_path: Optional[str],
    model: str,
    api_key: Optional[str],
) -> Dict[str, Any]:
    if not api_key:
        return {"status": "skipped", "reason": "OPENROUTER_API_KEY is not set."}

    prompt = (
        "You are a cautious CNC tufting design reviewer. Review the supplied "
        "design image, path metrics, and G-code. Do not invent coordinates and "
        "do not approve machine execution. Return JSON with keys: "
        "visual_match (0..1), concerns (array), recommendations (array), "
        "confidence (0..1). The deterministic can_start result is authoritative.\n\n"
        f"Deterministic report: {json.dumps(report.to_dict(), ensure_ascii=True)}\n"
        f"G-code excerpt:\n{gcode[:12000]}"
    )
    content: List[Dict[str, Any]] = [{"type": "text", "text": prompt}]
    if image_path:
        with open(image_path, "rb") as image_file:
            encoded = base64.b64encode(image_file.read()).decode("ascii")
        content.append(
            {
                "type": "image_url",
                "image_url": {"url": f"data:image/png;base64,{encoded}"},
            }
        )

    payload = json.dumps(
        {
            "model": model,
            "temperature": 0,
            "messages": [{"role": "user", "content": content}],
        }
    ).encode("utf-8")
    request = urllib.request.Request(
        "https://openrouter.ai/api/v1/chat/completions",
        data=payload,
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
            "HTTP-Referer": "https://rovex.local",
            "X-Title": "ROVEX CNC Design Review",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=45) as response:
            response_data = json.loads(response.read().decode("utf-8"))
        text = response_data["choices"][0]["message"]["content"]
        try:
            return {"status": "ok", "result": json.loads(text)}
        except json.JSONDecodeError:
            return {"status": "ok", "raw": text}
    except (urllib.error.URLError, TimeoutError, KeyError, ValueError) as error:
        return {"status": "error", "reason": str(error)}
