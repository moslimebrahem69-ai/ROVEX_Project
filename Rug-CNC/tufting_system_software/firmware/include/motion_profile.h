/*
 * motion_profile.h
 * ----------------
 * Trapezoidal velocity-profile motion planning for a single linear
 * segment. Used by the real-time control loop to convert a straight
 * move (distance only) into a smooth accelerate -> cruise -> decelerate
 * motion that respects the machine's velocity and acceleration limits.
 */

#ifndef TUFTING_MOTION_PROFILE_H
#define TUFTING_MOTION_PROFILE_H

typedef struct {
    double distance_mm;
    double v_max_mm_s;
    double a_max_mm_s2;

    /* Derived, filled in by motion_profile_compute() */
    double t_accel_s;
    double t_cruise_s;
    double t_total_s;
} MotionProfile;

/*
 * Computes the trapezoidal (or triangular, if the segment is too
 * short to reach v_max) motion profile for `distance_mm` mm of travel.
 */
void motion_profile_compute(MotionProfile *profile);

/*
 * Returns the distance travelled along the segment at time `t`
 * seconds after the move started (0 <= result <= profile->distance_mm).
 */
double motion_profile_position_at(const MotionProfile *profile, double t);

/*
 * Returns the instantaneous velocity (mm/s) at time `t`.
 */
double motion_profile_velocity_at(const MotionProfile *profile, double t);

#endif /* TUFTING_MOTION_PROFILE_H */
