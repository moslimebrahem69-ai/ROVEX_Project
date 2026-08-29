/*
 * main.c
 * ------
 * Real-time control loop entrypoint.
 *
 * Pipeline position: this is STAGE 2. Stage 1 (edge_ai, in Python)
 * has already turned a design into optimized_path.csv. This program:
 *
 *   1. Loads that path (path_loader.c)
 *   2. For every segment, computes a trapezoidal velocity profile
 *      that respects the machine's speed/acceleration limits
 *      (motion_profile.c)
 *   3. Converts each intermediate design-space position into
 *      machine-space actuator targets (kinematics.c)
 *   4. Sends each target to the hardware, one control tick at a time,
 *      through the Hardware Abstraction Layer (hal.h) -- either the
 *      simulator (hal_sim.c) or the real serial link (hal_serial.c)
 *
 * Usage:
 *   ./ROVEX <path.csv> [sim|serial] [port_or_logfile] [baud]
 *
 * Examples:
 *   ./ROVEX optimized_path.csv sim
 *   ./ROVEX optimized_path.csv serial /dev/ttyUSB0 115200
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <math.h>
#include "../include/config.h"
#include "../include/path_loader.h"
#include "../include/motion_profile.h"
#include "../include/kinematics.h"
#include "../include/hal.h"

static double elapsed_ms(struct timespec start, struct timespec end)
{
    return (end.tv_sec - start.tv_sec) * 1000.0 + (end.tv_nsec - start.tv_nsec) / 1e6;
}

int main(int argc, char **argv)
{
    if (argc < 2)
    {
        fprintf(stderr,
                "Usage: %s <path.csv> [sim|serial] [port_or_logfile] [baud]\n",
                argv[0]);
        return 1;
    }

    const char *path_file = argv[1];
    const char *backend_name = (argc > 2) ? argv[2] : "sim";
    const char *connection = (argc > 3) ? argv[3] : "";
    int baud = (argc > 4) ? atoi(argv[4]) : 115200;

    static PathPoint points[MAX_PATH_POINTS];
    int n = path_loader_load(path_file, points, MAX_PATH_POINTS);
    if (n < 0)
    {
        return 1;
    }

    printf("== Tufting System Real-Time Control Firmware ==\n");
    printf("Path points loaded: %d\n", n);
    printf("Control loop frequency: %d Hz (tick = %.3f ms)\n",
           DEFAULT_CONTROL_FREQUENCY_HZ, TICK_SECONDS * 1000.0);

    const HardwareInterface *hal;
    if (strcmp(backend_name, "serial") == 0)
    {
#ifdef _WIN32
        fprintf(stderr, "Serial mode not supported on Windows. Using simulator.\n");
        hal = hal_get_sim_backend();
#else
        hal = hal_get_serial_backend();
#endif
    }
    else
    {
        hal = hal_get_sim_backend();
    }

    if (hal->init(connection, baud) != 0)
    {
        fprintf(stderr, "FATAL: hardware link initialization failed.\n");
        return 1;
    }

    hal->set_needle(1); /* engage needle at job start */

    long total_ticks = 0;
    double total_motion_time_s = 0.0;

    struct timespec t0, t1;
    clock_gettime(CLOCK_MONOTONIC, &t0);

    for (int i = 0; i < n - 1; i++)
    {
        double dx = points[i + 1].x - points[i].x;
        double dy = points[i + 1].y - points[i].y;
        double dist = sqrt(dx * dx + dy * dy);
        if (dist < 1e-9)
            continue;

        double ux = dx / dist;
        double uy = dy / dist;

        MotionProfile profile = {
            .distance_mm = dist,
            .v_max_mm_s = DEFAULT_MAX_VELOCITY_MM_S,
            .a_max_mm_s2 = DEFAULT_MAX_ACCEL_MM_S2,
        };
        motion_profile_compute(&profile);

        int ticks_this_segment = (int)(profile.t_total_s / TICK_SECONDS) + 1;

        for (int k = 0; k <= ticks_this_segment; k++)
        {
            double t = k * TICK_SECONDS;
            if (t > profile.t_total_s)
                t = profile.t_total_s;

            double s = motion_profile_position_at(&profile, t);
            double v = motion_profile_velocity_at(&profile, t);

            double x = points[i].x + ux * s;
            double y = points[i].y + uy * s;

            hal->move_to(x, y, v);

            total_ticks++;
        }
        total_motion_time_s += profile.t_total_s;
    }

    hal->set_needle(0); /* disengage needle at job end */

    clock_gettime(CLOCK_MONOTONIC, &t1);
    double wall_ms = elapsed_ms(t0, t1);

    printf("\n-- Job summary --\n");
    printf("Total control ticks executed : %ld\n", total_ticks);
    printf("Simulated machine motion time: %.2f s\n", total_motion_time_s);
    printf("Actual host processing time  : %.3f ms\n", wall_ms);
    printf("Average time per control tick: %.6f ms\n",
           wall_ms / (double)(total_ticks > 0 ? total_ticks : 1));

    hal->shutdown();
    return 0;
}
