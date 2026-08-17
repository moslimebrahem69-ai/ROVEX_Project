/*
 * hal_serial_win.c
 * ----------------
 * Windows COM-port HAL for GRBL-compatible boards (CreateFile / WriteFile).
 */
#ifdef _WIN32

#include <stdio.h>
#include <string.h>
#include <windows.h>
#include "../include/hal.h"

#define MAX_LINE_LEN_LOCAL 128

static HANDLE g_port = INVALID_HANDLE_VALUE;

static int serial_init(const char *connection_string, int baud_rate) {
    const char *port = (connection_string && connection_string[0])
        ? connection_string : "COM3";

    char path[64];
    /* \\.\COMx required for COM10+ */
    if (strncmp(port, "\\\\.\\", 4) == 0)
        snprintf(path, sizeof(path), "%s", port);
    else
        snprintf(path, sizeof(path), "\\\\.\\%s", port);

    g_port = CreateFileA(path, GENERIC_READ | GENERIC_WRITE, 0, NULL,
                         OPEN_EXISTING, 0, NULL);
    if (g_port == INVALID_HANDLE_VALUE) {
        fprintf(stderr, "[hal_serial_win] ERROR: open '%s' failed (%lu)\n",
                path, GetLastError());
        return -1;
    }

    DCB dcb;
    ZeroMemory(&dcb, sizeof(dcb));
    dcb.DCBlength = sizeof(dcb);
    if (!GetCommState(g_port, &dcb)) {
        CloseHandle(g_port);
        g_port = INVALID_HANDLE_VALUE;
        return -1;
    }
    dcb.BaudRate = baud_rate > 0 ? (DWORD)baud_rate : CBR_115200;
    dcb.ByteSize = 8;
    dcb.Parity = NOPARITY;
    dcb.StopBits = ONESTOPBIT;
    dcb.fBinary = TRUE;
    dcb.fParity = FALSE;
    dcb.fOutxCtsFlow = FALSE;
    dcb.fOutxDsrFlow = FALSE;
    dcb.fDtrControl = DTR_CONTROL_ENABLE;
    dcb.fRtsControl = RTS_CONTROL_ENABLE;
    if (!SetCommState(g_port, &dcb)) {
        CloseHandle(g_port);
        g_port = INVALID_HANDLE_VALUE;
        return -1;
    }

    COMMTIMEOUTS timeouts;
    ZeroMemory(&timeouts, sizeof(timeouts));
    timeouts.ReadIntervalTimeout = 50;
    timeouts.ReadTotalTimeoutConstant = 500;
    timeouts.ReadTotalTimeoutMultiplier = 10;
    timeouts.WriteTotalTimeoutConstant = 500;
    timeouts.WriteTotalTimeoutMultiplier = 10;
    SetCommTimeouts(g_port, &timeouts);

    /* GRBL resets on open — wait for banner */
    Sleep(2000);
    printf("[hal_serial_win] Connected to %s @ %d baud\n", port, baud_rate);
    return 0;
}

static int send_line(const char *line) {
    if (g_port == INVALID_HANDLE_VALUE) return -1;
    char buf[MAX_LINE_LEN_LOCAL + 2];
    int n = snprintf(buf, sizeof(buf), "%s\n", line);
    if (n <= 0) return -1;
    DWORD written = 0;
    if (!WriteFile(g_port, buf, (DWORD)n, &written, NULL) || (int)written != n) {
        fprintf(stderr, "[hal_serial_win] ERROR: write failed (%lu)\n", GetLastError());
        return -1;
    }
    return 0;
}

static int serial_move_to(double x_mm, double y_mm, double feedrate_mm_s) {
    char line[MAX_LINE_LEN_LOCAL];
    snprintf(line, sizeof(line), "G1 X%.3f Y%.3f F%.1f",
             x_mm, y_mm, feedrate_mm_s * 60.0);
    return send_line(line);
}

static int serial_set_needle(int engaged) {
    return send_line(engaged ? "M8" : "M9");
}

static void serial_shutdown(void) {
    if (g_port != INVALID_HANDLE_VALUE) {
        CloseHandle(g_port);
        g_port = INVALID_HANDLE_VALUE;
    }
    printf("[hal_serial_win] Hardware link closed.\n");
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

#endif /* _WIN32 */
