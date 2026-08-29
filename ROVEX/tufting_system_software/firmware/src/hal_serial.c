/*
 * hal_serial.c
 * ------------
 * Real-hardware backend for the Hardware Abstraction Layer.
 *
 * This is the actual physical link to the locally-manufactured
 * machine: it opens a USB-serial connection to a GRBL-compatible
 * microcontroller board (an Arduino/ATmega or STM32 running GRBL or
 * a GRBL-derivative firmware is the standard, globally-documented,
 * open-source choice for driving stepper/servo drivers on a
 * self-built CNC-style machine), and streams standard G-code motion
 * commands to it.
 *
 * Why G-code over serial, and not raw step/dir pulses from this
 * program directly?
 *   - It is a universally recognized, vendor-neutral interface: any
 *     controller board that speaks GRBL (or Marlin, which uses the
 *     same command subset for linear motion) will work, so the
 *     machine shop is free to choose/replace controller boards
 *     without touching this file.
 *   - The low-level, truly hard-real-time step pulse generation is
 *     delegated to the microcontroller, which is what such boards are
 *     built for; this program remains the high-level real-time
 *     *trajectory* planner (see motion_profile.c) rather than a
 *     hard-real-time pulse generator, which is the correct division
 *     of responsibility on commodity Linux hardware.
 *
 * Wiring & command reference: see /ipc/PROTOCOL.md and the
 * See ROVEX training manual (docs/) for GRBL serial wiring.
 *
 * Build: this file is only compiled on POSIX systems (Linux/macOS),
 * since it uses <termios.h>. See firmware/Makefile.
 */

#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <termios.h>
#include <errno.h>
#include "../include/hal.h"

/* Local line-buffer size; kept separate from firmware/include/config.h
   so this file has no compile-time dependency beyond hal.h. */
#define MAX_LINE_LEN_LOCAL 128

static int g_fd = -1;

static speed_t baud_to_speed(int baud) {
    switch (baud) {
        case 9600:   return B9600;
        case 19200:  return B19200;
        case 38400:  return B38400;
        case 57600:  return B57600;
        case 115200: return B115200;
        default:     return B115200;
    }
}

static int serial_init(const char *connection_string, int baud_rate) {
    const char *port = (connection_string && connection_string[0])
        ? connection_string : "/dev/ttyUSB0";

    g_fd = open(port, O_RDWR | O_NOCTTY | O_SYNC);
    if (g_fd < 0) {
        fprintf(stderr,
                "[hal_serial] ERROR: could not open serial port '%s': %s\n"
                "[hal_serial] Check that the controller board is connected "
                "and that this process has permission to access it "
                "(on Linux: add the user to the 'dialout' group).\n",
                port, strerror(errno));
        return -1;
    }

    struct termios tty;
    memset(&tty, 0, sizeof(tty));
    if (tcgetattr(g_fd, &tty) != 0) {
        fprintf(stderr, "[hal_serial] ERROR: tcgetattr failed: %s\n", strerror(errno));
        close(g_fd);
        g_fd = -1;
        return -1;
    }

    speed_t speed = baud_to_speed(baud_rate);
    cfsetospeed(&tty, speed);
    cfsetispeed(&tty, speed);

    tty.c_cflag = (tty.c_cflag & ~CSIZE) | CS8; /* 8 data bits */
    tty.c_cflag &= ~PARENB;                     /* no parity   */
    tty.c_cflag &= ~CSTOPB;                     /* 1 stop bit  */
    tty.c_cflag &= ~CRTSCTS;                    /* no hw flow control */
    tty.c_cflag |= (CLOCAL | CREAD);

    tty.c_lflag = 0;   /* raw mode, no line-discipline processing */
    tty.c_iflag = 0;
    tty.c_oflag = 0;

    tty.c_cc[VMIN]  = 0;
    tty.c_cc[VTIME] = 5; /* 0.5s read timeout */

    if (tcsetattr(g_fd, TCSANOW, &tty) != 0) {
        fprintf(stderr, "[hal_serial] ERROR: tcsetattr failed: %s\n", strerror(errno));
        close(g_fd);
        g_fd = -1;
        return -1;
    }

    printf("[hal_serial] Connected to controller board on %s @ %d baud\n",
           port, baud_rate);

    /* GRBL-style boards reset on port open; give the bootloader time
       to finish and the controller time to report its "Grbl vX.Y"
       banner before we start streaming motion commands. */
    usleep(2000000);

    return 0;
}

static int send_line(const char *line) {
    if (g_fd < 0) return -1;
    size_t len = strlen(line);
    if (write(g_fd, line, len) != (ssize_t) len) {
        fprintf(stderr, "[hal_serial] ERROR: write failed: %s\n", strerror(errno));
        return -1;
    }
    if (write(g_fd, "\n", 1) != 1) {
        return -1;
    }
    return 0;
}

static int serial_move_to(double x_mm, double y_mm, double feedrate_mm_s) {
    char line[MAX_LINE_LEN_LOCAL];
    /* G1 = linear move at feedrate F (mm/min, hence the *60). This is
       standard G-code understood by GRBL, Marlin, and virtually every
       other motion controller firmware in existence. */
    snprintf(line, sizeof(line), "G1 X%.3f Y%.3f F%.1f",
              x_mm, y_mm, feedrate_mm_s * 60.0);
    return send_line(line);
}

static int serial_set_needle(int engaged) {
    /* M8/M9 (or whatever pin was configured) toggles the needle
       solenoid/clutch output. The exact M-code is read from
       machine_config.yaml (hardware.needle_actuator_pin) by main.c
       and passed down; here we use the GRBL-conventional coolant
       pins M8 (on) / M9 (off) as a sane, widely-supported default. */
    return send_line(engaged ? "M8" : "M9");
}

static void serial_shutdown(void) {
    if (g_fd >= 0) {
        close(g_fd);
        g_fd = -1;
    }
    printf("[hal_serial] Hardware link closed.\n");
}

static const HardwareInterface SERIAL_BACKEND = {
    .init = serial_init,
    .move_to = serial_move_to,
    .set_needle = serial_set_needle,
    .shutdown = serial_shutdown,
};

const HardwareInterface *hal_get_serial_backend(void) {
    return &SERIAL_BACKEND;
}
