/*
 * hal_sim.c
 * ---------
 * Simulation backend for the Hardware Abstraction Layer.
 *
 * Every command that WOULD have been sent to a real machine is
 * instead written to motor_commands.log, with a timestamp column.
 * This makes it possible to develop, test, and demo the entire
 * pipeline (Edge-AI planning -> real-time control loop) without any
 * physical machine attached -- and to diff/replay logs when bringing
 * up real hardware for the first time.
 */

#include <stdio.h>
#include <string.h>
#include <time.h>
#ifdef _WIN32
#include <windows.h>
#endif
#include "../include/hal.h"

static FILE *g_log = NULL;
static long g_tick = 0;

static double now_ms(void) {
#ifdef _WIN32
    return (double)GetTickCount();
#else
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec * 1000.0 + ts.tv_nsec / 1e6;
#endif
}

static int sim_init(const char *connection_string, int baud_rate) {
    (void) baud_rate;
    const char *path = (connection_string && connection_string[0])
        ? connection_string : "motor_commands.log";
    g_log = fopen(path, "w");
    if (!g_log) {
        fprintf(stderr, "[hal_sim] ERROR: could not open '%s' for writing\n", path);
        return -1;
    }
    fprintf(g_log, "tick,time_ms,x_mm,y_mm,feedrate_mm_s,needle\n");
    g_tick = 0;
    printf("[hal_sim] Simulated hardware link ready. Logging to '%s'\n", path);
    return 0;
}

static int sim_move_to(double x_mm, double y_mm, double feedrate_mm_s) {
    if (!g_log) return -1;
    fprintf(g_log, "%ld,%.3f,%.3f,%.3f,%.3f,-\n",
            g_tick, now_ms(), x_mm, y_mm, feedrate_mm_s);
    g_tick++;
    return 0;
}

static int sim_set_needle(int engaged) {
    if (!g_log) return -1;
    fprintf(g_log, "%ld,%.3f,-,-,-,%s\n",
            g_tick, now_ms(), engaged ? "ENGAGED" : "DISENGAGED");
    g_tick++;
    return 0;
}

static void sim_shutdown(void) {
    if (g_log) {
        fclose(g_log);
        g_log = NULL;
    }
    printf("[hal_sim] Hardware link closed. Total commands logged: %ld\n", g_tick);
}

static const HardwareInterface SIM_BACKEND = {
    .init = sim_init,
    .move_to = sim_move_to,
    .set_needle = sim_set_needle,
    .shutdown = sim_shutdown,
};

const HardwareInterface *hal_get_sim_backend(void) {
    return &SIM_BACKEND;
}
