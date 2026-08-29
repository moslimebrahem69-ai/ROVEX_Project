/*
 * motion_profile.c
 * -----------------
 * See motion_profile.h.
 *
 * Trapezoidal profile shape:
 *
 *   velocity
 *     ^
 *     |        ______________
 *     |       /              \
 *     |      /                \
 *     |     /                  \
 *     |    /                    \
 *     +---+----------------------+----> time
 *         0   t_accel  t_accel   t_total
 *                     +t_cruise
 *
 * If the segment is too short to ever reach v_max, the profile
 * degenerates to a triangle (t_cruise = 0) with a lower peak velocity.
 */

#include <math.h>
#include "../include/motion_profile.h"

void motion_profile_compute(MotionProfile *p) {
    double t_accel = p->v_max_mm_s / p->a_max_mm_s2;
    double d_accel = 0.5 * p->a_max_mm_s2 * t_accel * t_accel;

    if (2.0 * d_accel >= p->distance_mm) {
        /* Triangular profile: never reaches v_max */
        t_accel = sqrt(p->distance_mm / p->a_max_mm_s2);
        p->t_accel_s = t_accel;
        p->t_cruise_s = 0.0;
        p->t_total_s = 2.0 * t_accel;
    } else {
        double d_cruise = p->distance_mm - 2.0 * d_accel;
        double t_cruise = d_cruise / p->v_max_mm_s;
        p->t_accel_s = t_accel;
        p->t_cruise_s = t_cruise;
        p->t_total_s = 2.0 * t_accel + t_cruise;
    }
}

static double peak_velocity(const MotionProfile *p) {
    /* Works for both the trapezoidal case (peak == v_max) and the
       triangular case (peak < v_max), since t_accel was recomputed
       accordingly in motion_profile_compute(). */
    return p->a_max_mm_s2 * p->t_accel_s;
}

double motion_profile_position_at(const MotionProfile *p, double t) {
    if (t < 0.0) t = 0.0;
    if (t > p->t_total_s) t = p->t_total_s;

    if (t <= p->t_accel_s) {
        return 0.5 * p->a_max_mm_s2 * t * t;
    }
    if (t <= p->t_accel_s + p->t_cruise_s) {
        double d_accel = 0.5 * p->a_max_mm_s2 * p->t_accel_s * p->t_accel_s;
        return d_accel + peak_velocity(p) * (t - p->t_accel_s);
    }
    double t_remaining = p->t_total_s - t;
    if (t_remaining < 0.0) t_remaining = 0.0;
    return p->distance_mm - 0.5 * p->a_max_mm_s2 * t_remaining * t_remaining;
}

double motion_profile_velocity_at(const MotionProfile *p, double t) {
    if (t < 0.0) t = 0.0;
    if (t > p->t_total_s) t = p->t_total_s;

    if (t <= p->t_accel_s) {
        return p->a_max_mm_s2 * t;
    }
    if (t <= p->t_accel_s + p->t_cruise_s) {
        return peak_velocity(p);
    }
    double t_remaining = p->t_total_s - t;
    if (t_remaining < 0.0) t_remaining = 0.0;
    return p->a_max_mm_s2 * t_remaining;
}
