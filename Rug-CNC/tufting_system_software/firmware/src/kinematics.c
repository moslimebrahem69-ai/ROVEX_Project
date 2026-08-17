/*
 * kinematics.c
 * ------------
 * See kinematics.h. Cartesian (X-Y gantry) implementation.
 */

#include <math.h>
#include "../include/kinematics.h"

ActuatorTarget kinematics_cartesian_transform(
    const KinematicsConfig *cfg, double x_mm, double y_mm) {

    ActuatorTarget target;
    target.steps_x = lround(x_mm * cfg->axis_x_steps_per_mm);
    target.steps_y = lround(y_mm * cfg->axis_y_steps_per_mm);
    return target;
}
