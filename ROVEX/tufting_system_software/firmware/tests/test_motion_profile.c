/*
 * test_motion_profile.c
 * ----------------------
 * Minimal unit tests for motion_profile.c, using a tiny hand-rolled
 * assertion harness so the firmware test suite has zero external
 * dependencies (no need to vendor a C test framework onto a build
 * machine that may not have internet access).
 *
 * Run:  make test   (from the firmware/ directory)
 */

#include <stdio.h>
#include <math.h>
#include "../include/motion_profile.h"

static int g_failures = 0;
static int g_checks = 0;

#define CHECK(cond, msg) do { \
    g_checks++; \
    if (!(cond)) { \
        g_failures++; \
        printf("  FAIL: %s (line %d)\n", msg, __LINE__); \
    } \
} while (0)

#define CHECK_CLOSE(a, b, tol, msg) \
    CHECK(fabs((a) - (b)) < (tol), msg)

static void test_reaches_full_distance(void) {
    printf("test_reaches_full_distance\n");
    MotionProfile p = { .distance_mm = 100.0, .v_max_mm_s = 50.0, .a_max_mm_s2 = 500.0 };
    motion_profile_compute(&p);
    double final_pos = motion_profile_position_at(&p, p.t_total_s);
    CHECK_CLOSE(final_pos, 100.0, 1e-6, "final position should equal total distance");
}

static void test_starts_and_ends_at_zero_velocity(void) {
    printf("test_starts_and_ends_at_zero_velocity\n");
    MotionProfile p = { .distance_mm = 200.0, .v_max_mm_s = 100.0, .a_max_mm_s2 = 1000.0 };
    motion_profile_compute(&p);
    CHECK_CLOSE(motion_profile_velocity_at(&p, 0.0), 0.0, 1e-6, "velocity at t=0 should be 0");
    CHECK_CLOSE(motion_profile_velocity_at(&p, p.t_total_s), 0.0, 1e-6, "velocity at t=t_total should be 0");
}

static void test_trapezoidal_reaches_v_max_on_long_segment(void) {
    printf("test_trapezoidal_reaches_v_max_on_long_segment\n");
    MotionProfile p = { .distance_mm = 1000.0, .v_max_mm_s = 250.0, .a_max_mm_s2 = 1500.0 };
    motion_profile_compute(&p);
    CHECK(p.t_cruise_s > 0.0, "long segment should have a nonzero cruise phase");
    double v_mid = motion_profile_velocity_at(&p, p.t_accel_s + p.t_cruise_s / 2.0);
    CHECK_CLOSE(v_mid, 250.0, 1e-6, "velocity during cruise phase should equal v_max");
}

static void test_triangular_profile_on_short_segment(void) {
    printf("test_triangular_profile_on_short_segment\n");
    /* Segment too short to ever reach v_max=250 given a_max=1500 */
    MotionProfile p = { .distance_mm = 1.0, .v_max_mm_s = 250.0, .a_max_mm_s2 = 1500.0 };
    motion_profile_compute(&p);
    CHECK_CLOSE(p.t_cruise_s, 0.0, 1e-9, "short segment should have zero cruise time");
    double final_pos = motion_profile_position_at(&p, p.t_total_s);
    CHECK_CLOSE(final_pos, 1.0, 1e-6, "short segment should still reach full distance");
}

static void test_position_is_monotonic_nondecreasing(void) {
    printf("test_position_is_monotonic_nondecreasing\n");
    MotionProfile p = { .distance_mm = 500.0, .v_max_mm_s = 250.0, .a_max_mm_s2 = 1500.0 };
    motion_profile_compute(&p);
    double prev = -1.0;
    int ok = 1;
    for (double t = 0.0; t <= p.t_total_s; t += p.t_total_s / 200.0) {
        double s = motion_profile_position_at(&p, t);
        if (s < prev - 1e-9) { ok = 0; break; }
        prev = s;
    }
    CHECK(ok, "position should never decrease over time");
}

int main(void) {
    test_reaches_full_distance();
    test_starts_and_ends_at_zero_velocity();
    test_trapezoidal_reaches_v_max_on_long_segment();
    test_triangular_profile_on_short_segment();
    test_position_is_monotonic_nondecreasing();

    printf("\n%d checks, %d failures\n", g_checks, g_failures);
    return g_failures == 0 ? 0 : 1;
}
