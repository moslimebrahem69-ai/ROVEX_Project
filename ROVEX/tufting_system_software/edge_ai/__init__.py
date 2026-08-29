"""
edge_ai
=======
Edge-AI path planning package for the autonomous tufting system.

This package converts a raw carpet design (a set of tuft coordinates)
into an optimized, machine-executable stitch path, and writes that
path to the interchange format consumed by the real-time firmware
(see /firmware and /ipc/PROTOCOL.md).

Public API:
    edge_ai.pattern_loader.load_pattern(path)
    edge_ai.path_optimizer.optimize(points, strategy="two_opt")
    edge_ai.path_writer.write_path_csv(points, order, out_path)
"""

__version__ = "1.0.0"
