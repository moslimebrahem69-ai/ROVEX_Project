/*
 * config.h
 * --------
 * Compile-time defaults for the real-time firmware.
 *
 * These values mirror config/machine_config.yaml. They exist as
 * compile-time fallbacks (used when no config file is supplied, e.g.
 * on a microcontroller build with no filesystem) and as documentation
 * of the expected value ranges. On a Linux/embedded-Linux target,
 * main.c may override these at runtime by parsing the YAML file --
 * see docs/EXTENDING.md for how to wire that up if your build target
 * has a filesystem and you want single-source-of-truth config.
 */

#ifndef TUFTING_CONFIG_H
#define TUFTING_CONFIG_H

/* ---- Motion limits (must match config/machine_config.yaml) ---- */
#define DEFAULT_MAX_VELOCITY_MM_S     250.0
#define DEFAULT_MAX_ACCEL_MM_S2       1500.0
#define DEFAULT_WORK_AREA_X_MM        1000.0
#define DEFAULT_WORK_AREA_Y_MM        1000.0

/* ---- Real-time control loop ---- */
#define DEFAULT_CONTROL_FREQUENCY_HZ  1000
#define TICK_SECONDS  (1.0 / DEFAULT_CONTROL_FREQUENCY_HZ)

/* ---- Limits / buffer sizes ---- */
#define MAX_PATH_POINTS   8192
#define MAX_LINE_LEN      128

#endif /* TUFTING_CONFIG_H */
