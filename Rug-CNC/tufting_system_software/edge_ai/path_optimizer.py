"""
path_optimizer.py
------------------
Adaptive path optimization for the tufting head.

Given the unordered set of tuft points that make up a design, this
module decides the order in which to visit them so that total head
travel (and therefore cycle time and thread wear) is minimized.

Design goals:
  * Deterministic and dependency-free (pure Python + stdlib `math`).
  * Pluggable: new optimization strategies can be added without
    touching the CLI or the firmware.
  * Safe to call on very small (2-point) or very large (thousands of
    points) patterns.

Strategies implemented:
  - "nearest_neighbor" : fast greedy construction, O(n^2)
  - "two_opt"           : nearest_neighbor followed by 2-opt local
                           search that removes path self-crossings

To add a new strategy (e.g. a learned/RL-based planner), implement a
function with the signature `Strategy(points: List[Point]) -> List[int]`
and register it in `STRATEGIES` at the bottom of this file.
"""

from __future__ import annotations

import math
from typing import Callable, Dict, List, Tuple

Point = Tuple[float, float]


def _distance(a: Point, b: Point) -> float:
    return math.hypot(a[0] - b[0], a[1] - b[1])


def path_length(points: List[Point], order: List[int]) -> float:
    """Total travel distance of the head for a given visiting order."""
    return sum(
        _distance(points[order[i]], points[order[i + 1]])
        for i in range(len(order) - 1)
    )


def nearest_neighbor(points: List[Point]) -> List[int]:
    """
    Greedy construction heuristic: starting from point 0, always move
    to the closest unvisited point. Fast (O(n^2)) and gives a
    reasonable starting tour for further refinement.
    """
    n = len(points)
    visited = [False] * n
    order = [0]
    visited[0] = True
    for _ in range(n - 1):
        last = order[-1]
        best_idx, best_dist = -1, float("inf")
        for j in range(n):
            if visited[j]:
                continue
            d = _distance(points[last], points[j])
            if d < best_dist:
                best_dist, best_idx = d, j
        order.append(best_idx)
        visited[best_idx] = True
    return order


def two_opt(
    points: List[Point],
    order: List[int] | None = None,
    max_iterations: int = 2000,
) -> List[int]:
    """
    2-opt local search: repeatedly reverses a segment of the tour if
    doing so shortens total path length. This removes the crossed
    lines that greedy construction tends to leave behind.

    If `order` is not provided, nearest_neighbor() is used to build
    the initial tour.
    """
    if order is None:
        order = nearest_neighbor(points)
    else:
        order = list(order)

    n = len(order)
    improved = True
    iterations = 0
    while improved and iterations < max_iterations:
        improved = False
        for i in range(1, n - 2):
            for j in range(i + 1, n - 1):
                a, b = points[order[i - 1]], points[order[i]]
                c, d = points[order[j]], points[order[j + 1]]
                before = _distance(a, b) + _distance(c, d)
                after = _distance(a, c) + _distance(b, d)
                if after < before - 1e-9:
                    order[i : j + 1] = order[i : j + 1][::-1]
                    improved = True
                iterations += 1
                if iterations >= max_iterations:
                    break
            if iterations >= max_iterations:
                break
    return order


Strategy = Callable[[List[Point]], List[int]]

STRATEGIES: Dict[str, Strategy] = {
    "nearest_neighbor": nearest_neighbor,
    "two_opt": two_opt,
}


def optimize(points: List[Point], strategy: str = "two_opt", **kwargs) -> List[int]:
    """
    Run the named optimization strategy and return the visiting order
    (a permutation of indices into `points`).

    Raises:
        KeyError: if `strategy` is not a registered strategy name.
    """
    if strategy not in STRATEGIES:
        raise KeyError(
            f"Unknown strategy '{strategy}'. Available: {list(STRATEGIES)}"
        )
    return STRATEGIES[strategy](points, **kwargs)
