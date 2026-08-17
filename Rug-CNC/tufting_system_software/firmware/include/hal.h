/*
 * hal.h
 * -----
 * Hardware Abstraction Layer (HAL).
 *
 * This is THE hardware link boundary of the whole system: every other
 * file in /firmware only ever talks to this interface, never directly
 * to a serial port, a GPIO pin, or a motor driver. That means the
 * locally-manufactured machine can be connected in whatever way is
 * physically available (serial/USB to a GRBL-style controller board,
 * raw GPIO on an embedded Linux SBC, SPI to a dedicated motion
 * controller, ...) by writing ONE new .c file that implements this
 * struct -- nothing in main.c, motion_profile.c, or kinematics.c has
 * to change.
 *
 * Two backends ship with this project out of the box:
 *
 *   hal_sim.c    - no physical hardware required. Every command is
 *                  logged to motor_commands.log. Use this to develop
 *                  and test the whole pipeline on a laptop before any
 *                  hardware exists.
 *
 *   hal_serial.c - the real hardware backend. Talks to a
 *                  GRBL-compatible microcontroller board (the de
 *                  facto open, global standard for CNC/stepper
 *                  controllers) over a USB-serial connection using
 *                  plain G-code. This is the backend to select
 *                  (hardware.backend: "serial" in machine_config.yaml)
 *                  once the locally-manufactured machine's controller
 *                  board is wired up. See /ipc/PROTOCOL.md and
 *                  /docs/HARDWARE_LINK.md (in the usage PDF) for the
 *                  wiring and command reference.
 */

#ifndef TUFTING_HAL_H
#define TUFTING_HAL_H

typedef struct HardwareInterface {
    /* Opens/initializes the hardware link. Returns 0 on success. */
    int (*init)(const char *connection_string, int baud_rate);

    /*
     * Commands the head to move toward (x_mm, y_mm) at the given
     * feedrate (mm/s). For a real controller this is a single motion
     * command per control tick; for the simulator it is a log line.
     */
    int (*move_to)(double x_mm, double y_mm, double feedrate_mm_s);

    /* Engages (1) or disengages (0) the tufting needle/clutch. */
    int (*set_needle)(int engaged);

    /* Cleanly closes the hardware link. */
    void (*shutdown)(void);
} HardwareInterface;

/* Factory functions -- one per backend. Selected at startup in main.c
   based on machine_config.yaml's hardware.backend value. */
const HardwareInterface *hal_get_sim_backend(void);
const HardwareInterface *hal_get_serial_backend(void);

#endif /* TUFTING_HAL_H */
