/*
 * machine_runtime.h
 * -----------------
 * Persistent CNC machine runtime: modes, path execution, jog, status.
 * Served to the Flutter HMI over TCP (JSON lines).
 */
#ifndef MACHINE_RUNTIME_H
#define MACHINE_RUNTIME_H

#include "hal.h"

typedef enum {
    MODE_JOG = 0,
    MODE_AUTO,
    MODE_MDI,
    MODE_REF
} MachineMode;

typedef enum {
    STATE_IDLE = 0,
    STATE_RUNNING,
    STATE_HOLD,
    STATE_ALARM,
    STATE_HOMING
} MachineState;

typedef struct {
    MachineMode mode;
    MachineState state;
    int connected;
    int referenced;
    int needle;
    double x_mm;
    double y_mm;
    double wcs_x;
    double wcs_y;
    int feed_override; /* 0..120 */
    double jog_step_mm;
    double jog_feed_mm_s;
    double prog_pct;
    int path_loaded;
    int path_count;
    int path_index;
    char alarm[128];
    char backend[16]; /* "sim" or "serial" */
    char port[64];
    int baud;
    char last_mdi[256];
} MachineStatus;

void runtime_init(void);
void runtime_shutdown(void);

int runtime_connect(const char *backend, const char *port, int baud);
void runtime_disconnect(void);

int runtime_set_mode(MachineMode mode);
int runtime_jog(const char *axis, int dir); /* axis "X"/"Y", dir +1/-1 */
int runtime_home(void);
int runtime_load_path(const char *csv_path);
int runtime_cycle_start(void);
int runtime_feed_hold(void);
int runtime_cycle_stop(void);
int runtime_reset(void);
int runtime_estop(void);
int runtime_set_feed_override(int pct);
int runtime_mdi(const char *line);
void runtime_set_jog_step(double step_mm);

/* Advance simulation / motion one step; call from server loop. */
void runtime_tick(double dt_s);

void runtime_get_status(MachineStatus *out);
/* Write one JSON status line into buf (null-terminated). Returns length. */
int runtime_status_json(char *buf, int buflen);

#endif /* MACHINE_RUNTIME_H */
