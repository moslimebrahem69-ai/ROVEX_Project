/*
 * machine_runtime.c
 * -----------------
 * Core machine state machine for the industrial tufting CNC runtime.
 */
#include "../include/machine_runtime.h"
#include "../include/path_loader.h"
#include "../include/config.h"

#include <math.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

static MachineStatus g;
static const HardwareInterface *g_hal = NULL;
static PathPoint g_path[MAX_PATH_POINTS];
static double g_seg_t = 0.0;
static double g_seg_dur = 0.0;
static double g_from_x = 0.0, g_from_y = 0.0;
static double g_to_x = 0.0, g_to_y = 0.0;
static int g_have_seg = 0;

static void clear_alarm(void) {
    g.alarm[0] = '\0';
    if (g.state == STATE_ALARM)
        g.state = STATE_IDLE;
}

static void set_alarm(const char *msg) {
    snprintf(g.alarm, sizeof(g.alarm), "%s", msg);
    g.state = STATE_ALARM;
}

static int in_work_area(double x, double y) {
    return x >= 0.0 && y >= 0.0 &&
           x <= DEFAULT_WORK_AREA_X_MM &&
           y <= DEFAULT_WORK_AREA_Y_MM;
}

static double clampf(double v, double lo, double hi) {
    if (v < lo) return lo;
    if (v > hi) return hi;
    return v;
}

void runtime_init(void) {
    memset(&g, 0, sizeof(g));
    g.mode = MODE_JOG;
    g.state = STATE_IDLE;
    g.feed_override = 100;
    g.jog_step_mm = 1.0;
    g.jog_feed_mm_s = 50.0;
    g.referenced = 0;
    snprintf(g.backend, sizeof(g.backend), "sim");
    snprintf(g.port, sizeof(g.port), "motor_commands.log");
    g.baud = 115200;
    g_hal = NULL;
    g_have_seg = 0;
}

void runtime_shutdown(void) {
    runtime_disconnect();
}

int runtime_connect(const char *backend, const char *port, int baud) {
    runtime_disconnect();
    if (!backend) backend = "sim";
    if (!port || !port[0]) {
        port = (strcmp(backend, "serial") == 0) ? "COM3" : "motor_commands.log";
    }
    if (baud <= 0) baud = 115200;

    if (strcmp(backend, "serial") == 0) {
        g_hal = hal_get_serial_backend();
        snprintf(g.backend, sizeof(g.backend), "serial");
    } else {
        g_hal = hal_get_sim_backend();
        snprintf(g.backend, sizeof(g.backend), "sim");
    }

    snprintf(g.port, sizeof(g.port), "%s", port);
    g.baud = baud;

    if (!g_hal || g_hal->init(port, baud) != 0) {
        g_hal = NULL;
        g.connected = 0;
        set_alarm("Connect failed");
        return -1;
    }

    g.connected = 1;
    clear_alarm();
    g.state = STATE_IDLE;
    return 0;
}

void runtime_disconnect(void) {
    if (g_hal) {
        g_hal->shutdown();
        g_hal = NULL;
    }
    g.connected = 0;
    g.state = STATE_IDLE;
    g_have_seg = 0;
}

int runtime_set_mode(MachineMode mode) {
    if (g.state == STATE_RUNNING) {
        set_alarm("Cannot change mode while RUNNING");
        return -1;
    }
    g.mode = mode;
    clear_alarm();
    return 0;
}

int runtime_jog(const char *axis, int dir) {
    if (!g.connected) {
        set_alarm("Not connected");
        return -1;
    }
    if (g.mode != MODE_JOG) {
        set_alarm("JOG mode required");
        return -1;
    }
    if (g.state == STATE_RUNNING || g.state == STATE_ALARM) {
        return -1;
    }

    double nx = g.x_mm;
    double ny = g.y_mm;
    double step = g.jog_step_mm * (dir >= 0 ? 1.0 : -1.0);
    if (axis && (axis[0] == 'X' || axis[0] == 'x'))
        nx += step;
    else if (axis && (axis[0] == 'Y' || axis[0] == 'y'))
        ny += step;
    else {
        set_alarm("Bad jog axis");
        return -1;
    }

    if (!in_work_area(nx, ny)) {
        set_alarm("Soft limit");
        return -1;
    }

    double feed = g.jog_feed_mm_s * (g.feed_override / 100.0);
    if (g_hal && g_hal->move_to(nx, ny, feed) != 0) {
        set_alarm("Jog move failed");
        return -1;
    }
    g.x_mm = nx;
    g.y_mm = ny;
    return 0;
}

int runtime_home(void) {
    if (!g.connected) {
        set_alarm("Not connected");
        return -1;
    }
    if (g.mode != MODE_REF && g.mode != MODE_JOG) {
        /* allow home from REF primarily; also JOG for convenience */
        runtime_set_mode(MODE_REF);
    }
    g.state = STATE_HOMING;
    double feed = 80.0 * (g.feed_override / 100.0);
    if (g_hal) {
        g_hal->move_to(0.0, 0.0, feed);
        g_hal->set_needle(0);
    }
    g.x_mm = 0.0;
    g.y_mm = 0.0;
    g.wcs_x = 0.0;
    g.wcs_y = 0.0;
    g.needle = 0;
    g.referenced = 1;
    g.state = STATE_IDLE;
    clear_alarm();
    return 0;
}

int runtime_load_path(const char *csv_path) {
    if (!csv_path) {
        set_alarm("Path empty");
        return -1;
    }
    int n = path_loader_load(csv_path, g_path, MAX_PATH_POINTS);
    if (n <= 0) {
        g.path_loaded = 0;
        g.path_count = 0;
        set_alarm("Path empty");
        return -1;
    }
    g.path_count = n;
    g.path_index = 0;
    g.path_loaded = 1;
    g.prog_pct = 0.0;
    g_have_seg = 0;
    clear_alarm();
    return 0;
}

static void begin_segment(void) {
    if (g.path_index >= g.path_count - 1) {
        g_have_seg = 0;
        g.state = STATE_IDLE;
        g.prog_pct = 100.0;
        if (g_hal) g_hal->set_needle(0);
        g.needle = 0;
        return;
    }
    g_from_x = g_path[g.path_index].x;
    g_from_y = g_path[g.path_index].y;
    g_to_x = g_path[g.path_index + 1].x;
    g_to_y = g_path[g.path_index + 1].y;
    double dx = g_to_x - g_from_x;
    double dy = g_to_y - g_from_y;
    double dist = sqrt(dx * dx + dy * dy);
    double vmax = DEFAULT_MAX_VELOCITY_MM_S * (g.feed_override / 100.0);
    if (vmax < 1.0) vmax = 1.0;
    g_seg_dur = (dist < 1e-6) ? 0.01 : (dist / vmax);
    g_seg_t = 0.0;
    g_have_seg = 1;
    if (g_hal) {
        g_hal->set_needle(1);
        g.needle = 1;
    }
}

int runtime_cycle_start(void) {
    if (!g.connected) {
        set_alarm("Not connected");
        return -1;
    }
    if (g.mode == MODE_MDI) {
        if (g.last_mdi[0] == '\0') {
            set_alarm("No MDI line");
            return -1;
        }
        /* Re-parse last MDI */
        return runtime_mdi(g.last_mdi);
    }
    if (g.mode != MODE_AUTO) {
        set_alarm("AUTO mode required");
        return -1;
    }
    if (!g.path_loaded || g.path_count < 2) {
        set_alarm("Path empty");
        return -1;
    }
    if (g.state == STATE_HOLD) {
        g.state = STATE_RUNNING;
        clear_alarm();
        return 0;
    }
    if (g.state == STATE_RUNNING) return 0;

    g.path_index = 0;
    g.x_mm = g_path[0].x;
    g.y_mm = g_path[0].y;
    g.state = STATE_RUNNING;
    begin_segment();
    clear_alarm();
    return 0;
}

int runtime_feed_hold(void) {
    if (g.state == STATE_RUNNING) {
        g.state = STATE_HOLD;
        if (g_hal) {
            g_hal->set_needle(0);
            g.needle = 0;
        }
        return 0;
    }
    return -1;
}

int runtime_cycle_stop(void) {
    g.state = STATE_IDLE;
    g_have_seg = 0;
    if (g_hal) {
        g_hal->set_needle(0);
        g.needle = 0;
    }
    return 0;
}

int runtime_reset(void) {
    runtime_cycle_stop();
    g.path_index = 0;
    g.prog_pct = 0.0;
    clear_alarm();
    g.state = STATE_IDLE;
    return 0;
}

int runtime_estop(void) {
    runtime_cycle_stop();
    set_alarm("EMERGENCY STOP");
    g.state = STATE_ALARM;
    return 0;
}

int runtime_set_feed_override(int pct) {
    if (pct < 0) pct = 0;
    if (pct > 120) pct = 120;
    g.feed_override = pct;
    return 0;
}

void runtime_set_jog_step(double step_mm) {
    if (step_mm < 0.001) step_mm = 0.001;
    if (step_mm > 100.0) step_mm = 100.0;
    g.jog_step_mm = step_mm;
}

int runtime_mdi(const char *line) {
    if (!g.connected) {
        set_alarm("Not connected");
        return -1;
    }
    if (g.mode != MODE_MDI) {
        set_alarm("MDI mode required");
        return -1;
    }
    if (!line || !line[0]) {
        set_alarm("No MDI line");
        return -1;
    }
    snprintf(g.last_mdi, sizeof(g.last_mdi), "%s", line);

    double x = g.x_mm, y = g.y_mm, f = 100.0;
    int has_x = 0, has_y = 0;
    const char *p = line;
    while (*p) {
        if (*p == 'X' || *p == 'x') {
            x = atof(p + 1);
            has_x = 1;
        } else if (*p == 'Y' || *p == 'y') {
            y = atof(p + 1);
            has_y = 1;
        } else if (*p == 'F' || *p == 'f') {
            f = atof(p + 1) / 60.0; /* mm/min -> mm/s */
        }
        p++;
    }
    if (!has_x && !has_y) {
        set_alarm("MDI needs X/Y");
        return -1;
    }
    if (!in_work_area(x, y)) {
        set_alarm("Soft limit");
        return -1;
    }
    f *= (g.feed_override / 100.0);
    if (g_hal && g_hal->move_to(x, y, f) != 0) {
        set_alarm("MDI move failed");
        return -1;
    }
    g.x_mm = x;
    g.y_mm = y;
    clear_alarm();
    return 0;
}

void runtime_tick(double dt_s) {
    if (g.state != STATE_RUNNING || !g_have_seg) return;

    g_seg_t += dt_s;
    double u = g_seg_t / g_seg_dur;
    if (u > 1.0) u = 1.0;
    double x = g_from_x + (g_to_x - g_from_x) * u;
    double y = g_from_y + (g_to_y - g_from_y) * u;

    if (!in_work_area(x, y)) {
        set_alarm("Soft limit");
        runtime_cycle_stop();
        return;
    }

    double feed = DEFAULT_MAX_VELOCITY_MM_S * (g.feed_override / 100.0);
    if (g_hal) g_hal->move_to(x, y, feed);
    g.x_mm = x;
    g.y_mm = y;

    if (g.path_count > 1) {
        g.prog_pct = 100.0 * ((double)g.path_index + u) / (double)(g.path_count - 1);
        g.prog_pct = clampf(g.prog_pct, 0.0, 100.0);
    }

    if (u >= 1.0) {
        g.path_index++;
        begin_segment();
    }
}

void runtime_get_status(MachineStatus *out) {
    if (out) *out = g;
}

static const char *mode_str(MachineMode m) {
    switch (m) {
        case MODE_JOG: return "JOG";
        case MODE_AUTO: return "AUTO";
        case MODE_MDI: return "MDI";
        case MODE_REF: return "REF";
        default: return "JOG";
    }
}

static const char *state_str(MachineState s) {
    switch (s) {
        case STATE_IDLE: return "IDLE";
        case STATE_RUNNING: return "RUNNING";
        case STATE_HOLD: return "HOLD";
        case STATE_ALARM: return "ALARM";
        case STATE_HOMING: return "HOMING";
        default: return "IDLE";
    }
}

int runtime_status_json(char *buf, int buflen) {
    char alarm_esc[160];
    const char *a = g.alarm;
    size_t j = 0;
    for (size_t i = 0; a[i] && j + 1 < sizeof(alarm_esc); i++) {
        if (a[i] == '"' || a[i] == '\\') {
            if (j + 2 >= sizeof(alarm_esc)) break;
            alarm_esc[j++] = '\\';
        }
        alarm_esc[j++] = a[i];
    }
    alarm_esc[j] = '\0';

    return snprintf(buf, buflen,
        "{\"type\":\"status\",\"mode\":\"%s\",\"state\":\"%s\","
        "\"x\":%.3f,\"y\":%.3f,\"wcs_x\":%.3f,\"wcs_y\":%.3f,"
        "\"feed_override\":%d,\"connected\":%s,\"referenced\":%s,"
        "\"needle\":%s,\"alarm\":\"%s\",\"prog_pct\":%.1f,"
        "\"path_loaded\":%s,\"path_count\":%d,\"path_index\":%d,"
        "\"backend\":\"%s\",\"port\":\"%s\",\"baud\":%d,"
        "\"jog_step\":%.3f}",
        mode_str(g.mode), state_str(g.state),
        g.x_mm, g.y_mm, g.wcs_x, g.wcs_y,
        g.feed_override,
        g.connected ? "true" : "false",
        g.referenced ? "true" : "false",
        g.needle ? "true" : "false",
        alarm_esc,
        g.prog_pct,
        g.path_loaded ? "true" : "false",
        g.path_count, g.path_index,
        g.backend, g.port, g.baud,
        g.jog_step_mm);
}
