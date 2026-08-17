/*
 * kinematics.h
 * ------------
 * Converts a target position in "design space" (X/Y millimeters on
 * the carpet) into machine-space actuator targets.
 *
 * This build ships a Cartesian (X-Y gantry) implementation, which is
 * the most common layout for tufting machines. If your locally-built
 * machine uses a different geometry (e.g. CoreXY belt drive, or a
 * polar/rotary frame), implement the same function signatures in a
 * new kinematics_<type>.c file and swap it in the Makefile -- nothing
 * else in the firmware needs to change, because main.c only ever
 * talks to this interface, never to raw motor coordinates.
 */

#ifndef TUFTING_KINEMATICS_H
#define TUFTING_KINEMATICS_H

typedef struct {
    double axis_x_steps_per_mm;
    double axis_y_steps_per_mm;
} KinematicsConfig;

typedef struct {
    long steps_x;
    long steps_y;
} ActuatorTarget;

/*
 * Converts a design-space (x_mm, y_mm) coordinate into actuator
 * step targets for a Cartesian X-Y gantry.
 */
ActuatorTarget kinematics_cartesian_transform(
    const KinematicsConfig *cfg, double x_mm, double y_mm);

#endif /* TUFTING_KINEMATICS_H */
