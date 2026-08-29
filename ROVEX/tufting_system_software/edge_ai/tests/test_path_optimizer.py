"""
test_path_optimizer.py
-----------------------
Unit tests for edge_ai.path_optimizer.

Built on the standard library `unittest` so the test suite has zero
extra dependencies. Run with either:

    python -m unittest discover -s edge_ai/tests -v
    pytest edge_ai/tests -v          # also works, pytest can run
                                      # unittest.TestCase classes directly
"""

import unittest

from edge_ai.path_optimizer import (
    nearest_neighbor,
    two_opt,
    optimize,
    path_length,
)


def square_points():
    # A unit square, visited in a "bad" scrambled order on purpose.
    return [(0, 0), (10, 10), (10, 0), (0, 10)]


class TestNearestNeighbor(unittest.TestCase):
    def test_visits_every_point_exactly_once(self):
        points = square_points()
        order = nearest_neighbor(points)
        self.assertEqual(sorted(order), list(range(len(points))))


class TestTwoOpt(unittest.TestCase):
    def test_never_makes_the_path_longer(self):
        points = square_points()
        nn_order = nearest_neighbor(points)
        nn_len = path_length(points, nn_order)

        opt_order = two_opt(points, nn_order)
        opt_len = path_length(points, opt_order)

        self.assertLessEqual(opt_len, nn_len + 1e-9)

    def test_finds_the_perimeter_on_a_square(self):
        # For a unit square the optimal open-path tour is the
        # perimeter, i.e. any tour with no diagonal ("crossing") edges.
        points = [(0, 0), (0, 10), (10, 10), (10, 0)]
        order = two_opt(points, list(range(len(points))))
        opt_len = path_length(points, order)
        # Perimeter walk length for 4 square corners visited in order: 3 * 10
        self.assertAlmostEqual(opt_len, 30.0, places=6)


class TestOptimizeDispatch(unittest.TestCase):
    def test_dispatches_to_registered_strategy(self):
        points = square_points()
        order_a = optimize(points, strategy="nearest_neighbor")
        order_b = nearest_neighbor(points)
        self.assertEqual(order_a, order_b)

    def test_rejects_unknown_strategy(self):
        points = square_points()
        with self.assertRaises(KeyError):
            optimize(points, strategy="does_not_exist")


class TestPathLength(unittest.TestCase):
    def test_two_points_equals_euclidean_distance(self):
        points = [(0, 0), (3, 4)]
        self.assertAlmostEqual(path_length(points, [0, 1]), 5.0)


if __name__ == "__main__":
    unittest.main()
