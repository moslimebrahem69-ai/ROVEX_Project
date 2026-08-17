/*
 * machine_server.c
 * ----------------
 * TCP JSON-line machine runtime server for the Flutter HMI.
 * Default bind: 127.0.0.1:9100
 *
 * Build: see Makefile target bin/machine_server
 */
#ifdef _WIN32
#define _WINSOCK_DEPRECATED_NO_WARNINGS
#include <winsock2.h>
#include <ws2tcpip.h>
#include <windows.h>
typedef SOCKET socket_t;
#define CLOSESOCK closesocket
#define SOCKERR SOCKET_ERROR
#else
#include <arpa/inet.h>
#include <netinet/in.h>
#include <sys/socket.h>
#include <unistd.h>
typedef int socket_t;
#define CLOSESOCK close
#define INVALID_SOCKET (-1)
#define SOCKERR (-1)
#endif

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#include "../include/machine_runtime.h"

#define DEFAULT_PORT 9100
#define BUF_SIZE 4096

static int json_get_string(const char *json, const char *key, char *out, int outlen) {
    char pat[64];
    snprintf(pat, sizeof(pat), "\"%s\"", key);
    const char *p = strstr(json, pat);
    if (!p) return -1;
    p = strchr(p + strlen(pat), ':');
    if (!p) return -1;
    p++;
    while (*p == ' ' || *p == '\t') p++;
    if (*p != '"') return -1;
    p++;
    int i = 0;
    while (*p && *p != '"' && i + 1 < outlen) {
        if (*p == '\\' && p[1]) p++;
        out[i++] = *p++;
    }
    out[i] = '\0';
    return 0;
}

static int json_get_int(const char *json, const char *key, int *out) {
    char pat[64];
    snprintf(pat, sizeof(pat), "\"%s\"", key);
    const char *p = strstr(json, pat);
    if (!p) return -1;
    p = strchr(p + strlen(pat), ':');
    if (!p) return -1;
    p++;
    while (*p == ' ' || *p == '\t') p++;
    *out = atoi(p);
    return 0;
}

static void send_line(socket_t client, const char *line) {
    char out[BUF_SIZE];
    int n = snprintf(out, sizeof(out), "%s\n", line);
    if (n > 0) {
#ifdef _WIN32
        send(client, out, n, 0);
#else
        send(client, out, (size_t)n, 0);
#endif
    }
}

static void send_ok(socket_t client, const char *cmd) {
    char buf[256];
    snprintf(buf, sizeof(buf), "{\"type\":\"ack\",\"cmd\":\"%s\",\"ok\":true}", cmd);
    send_line(client, buf);
}

static void send_err(socket_t client, const char *cmd, const char *msg) {
    char buf[320];
    snprintf(buf, sizeof(buf),
             "{\"type\":\"ack\",\"cmd\":\"%s\",\"ok\":false,\"error\":\"%s\"}",
             cmd, msg ? msg : "error");
    send_line(client, buf);
}

static void push_status(socket_t client) {
    char buf[BUF_SIZE];
    runtime_status_json(buf, sizeof(buf));
    send_line(client, buf);
}

static void handle_cmd(socket_t client, const char *line) {
    char cmd[64] = {0};
    if (json_get_string(line, "cmd", cmd, sizeof(cmd)) != 0) {
        /* also accept {"type":"command","cmd":...} already covered */
        send_err(client, "?", "missing cmd");
        return;
    }

    if (strcmp(cmd, "ping") == 0) {
        send_ok(client, cmd);
        return;
    }
    if (strcmp(cmd, "get_status") == 0) {
        push_status(client);
        return;
    }
    if (strcmp(cmd, "connect") == 0) {
        char backend[16] = "sim";
        char port[64] = "";
        int baud = 115200;
        json_get_string(line, "backend", backend, sizeof(backend));
        json_get_string(line, "port", port, sizeof(port));
        json_get_int(line, "baud", &baud);
        if (runtime_connect(backend, port, baud) == 0)
            send_ok(client, cmd);
        else
            send_err(client, cmd, "connect failed");
        push_status(client);
        return;
    }
    if (strcmp(cmd, "disconnect") == 0) {
        runtime_disconnect();
        send_ok(client, cmd);
        push_status(client);
        return;
    }
    if (strcmp(cmd, "set_mode") == 0) {
        char mode[16] = "JOG";
        json_get_string(line, "mode", mode, sizeof(mode));
        MachineMode m = MODE_JOG;
        if (strcmp(mode, "AUTO") == 0) m = MODE_AUTO;
        else if (strcmp(mode, "MDI") == 0) m = MODE_MDI;
        else if (strcmp(mode, "REF") == 0) m = MODE_REF;
        if (runtime_set_mode(m) == 0) send_ok(client, cmd);
        else send_err(client, cmd, "mode change failed");
        push_status(client);
        return;
    }
    if (strcmp(cmd, "jog") == 0) {
        char axis[8] = "X";
        int dir = 1;
        json_get_string(line, "axis", axis, sizeof(axis));
        json_get_int(line, "dir", &dir);
        if (runtime_jog(axis, dir) == 0) send_ok(client, cmd);
        else send_err(client, cmd, "jog failed");
        push_status(client);
        return;
    }
    if (strcmp(cmd, "home") == 0) {
        if (runtime_home() == 0) send_ok(client, cmd);
        else send_err(client, cmd, "home failed");
        push_status(client);
        return;
    }
    if (strcmp(cmd, "load_path") == 0) {
        char path[512] = {0};
        json_get_string(line, "path", path, sizeof(path));
        if (runtime_load_path(path) == 0) send_ok(client, cmd);
        else send_err(client, cmd, "load failed");
        push_status(client);
        return;
    }
    if (strcmp(cmd, "cycle_start") == 0) {
        if (runtime_cycle_start() == 0) send_ok(client, cmd);
        else send_err(client, cmd, "start failed");
        push_status(client);
        return;
    }
    if (strcmp(cmd, "feed_hold") == 0) {
        if (runtime_feed_hold() == 0) send_ok(client, cmd);
        else send_err(client, cmd, "hold failed");
        push_status(client);
        return;
    }
    if (strcmp(cmd, "cycle_stop") == 0) {
        runtime_cycle_stop();
        send_ok(client, cmd);
        push_status(client);
        return;
    }
    if (strcmp(cmd, "reset") == 0) {
        runtime_reset();
        send_ok(client, cmd);
        push_status(client);
        return;
    }
    if (strcmp(cmd, "estop") == 0) {
        runtime_estop();
        send_ok(client, cmd);
        push_status(client);
        return;
    }
    if (strcmp(cmd, "set_feed_override") == 0) {
        int pct = 100;
        json_get_int(line, "percent", &pct);
        runtime_set_feed_override(pct);
        send_ok(client, cmd);
        push_status(client);
        return;
    }
    if (strcmp(cmd, "mdi") == 0) {
        char mdi[256] = {0};
        json_get_string(line, "line", mdi, sizeof(mdi));
        if (runtime_mdi(mdi) == 0) send_ok(client, cmd);
        else send_err(client, cmd, "mdi failed");
        push_status(client);
        return;
    }
    if (strcmp(cmd, "set_jog_step") == 0) {
        char step_s[32] = "1.0";
        json_get_string(line, "step", step_s, sizeof(step_s));
        runtime_set_jog_step(atof(step_s));
        send_ok(client, cmd);
        push_status(client);
        return;
    }

    send_err(client, cmd, "unknown cmd");
}

#ifdef _WIN32
static DWORD g_last_tick_ms = 0;
#else
static struct timespec g_last_tick;
#endif

static double elapsed_s(void) {
#ifdef _WIN32
    DWORD now = GetTickCount();
    DWORD d = now - g_last_tick_ms;
    g_last_tick_ms = now;
    return d / 1000.0;
#else
    struct timespec now;
    clock_gettime(CLOCK_MONOTONIC, &now);
    double dt = (now.tv_sec - g_last_tick.tv_sec) +
                (now.tv_nsec - g_last_tick.tv_nsec) / 1e9;
    g_last_tick = now;
    return dt;
#endif
}

int main(int argc, char **argv) {
    int port = DEFAULT_PORT;
    if (argc >= 2) port = atoi(argv[1]);
    if (port <= 0) port = DEFAULT_PORT;

#ifdef _WIN32
    WSADATA wsa;
    if (WSAStartup(MAKEWORD(2, 2), &wsa) != 0) {
        fprintf(stderr, "WSAStartup failed\n");
        return 1;
    }
    g_last_tick_ms = GetTickCount();
#else
    clock_gettime(CLOCK_MONOTONIC, &g_last_tick);
#endif

    runtime_init();
    /* Auto-connect sim so HMI has a live machine immediately */
    runtime_connect("sim", "motor_commands.log", 115200);

    socket_t server = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
    if (server == INVALID_SOCKET) {
        fprintf(stderr, "socket() failed\n");
        return 1;
    }

    int yes = 1;
    setsockopt(server, SOL_SOCKET, SO_REUSEADDR, (const char *)&yes, sizeof(yes));

    struct sockaddr_in addr;
    memset(&addr, 0, sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_port = htons((unsigned short)port);
    addr.sin_addr.s_addr = htonl(INADDR_LOOPBACK);

    if (bind(server, (struct sockaddr *)&addr, sizeof(addr)) == SOCKERR) {
        fprintf(stderr, "bind() failed on port %d\n", port);
        return 1;
    }
    if (listen(server, 2) == SOCKERR) {
        fprintf(stderr, "listen() failed\n");
        return 1;
    }

    printf("[machine_server] ROVEX runtime listening on 127.0.0.1:%d (sim connected)\n",
           port);
    fflush(stdout);

    /* Non-blocking accept loop with single client focus */
#ifdef _WIN32
    u_long nonblock = 1;
    ioctlsocket(server, FIONBIO, &nonblock);
#else
    /* leave blocking accept for simplicity on POSIX alternate path */
#endif

    socket_t client = INVALID_SOCKET;
    char recvbuf[BUF_SIZE * 2];
    int recvlen = 0;
    double status_accum = 0.0;

    for (;;) {
        double dt = elapsed_s();
        if (dt > 0.05) dt = 0.05; /* clamp */
        if (dt < 0) dt = 0.01;
        runtime_tick(dt);

        status_accum += dt;
        if (client != INVALID_SOCKET && status_accum >= 0.1) {
            status_accum = 0.0;
            push_status(client);
        }

#ifdef _WIN32
        if (client == INVALID_SOCKET) {
            struct sockaddr_in caddr;
            int clen = sizeof(caddr);
            socket_t c = accept(server, (struct sockaddr *)&caddr, &clen);
            if (c != INVALID_SOCKET) {
                client = c;
                u_long nb = 1;
                ioctlsocket(client, FIONBIO, &nb);
                recvlen = 0;
                printf("[machine_server] HMI connected\n");
                push_status(client);
            }
        } else {
            char tmp[1024];
            int n = recv(client, tmp, sizeof(tmp) - 1, 0);
            if (n == 0 || (n < 0 && WSAGetLastError() != WSAEWOULDBLOCK)) {
                CLOSESOCK(client);
                client = INVALID_SOCKET;
                recvlen = 0;
                printf("[machine_server] HMI disconnected\n");
            } else if (n > 0) {
                if (recvlen + n >= (int)sizeof(recvbuf)) recvlen = 0;
                memcpy(recvbuf + recvlen, tmp, (size_t)n);
                recvlen += n;
                recvbuf[recvlen] = '\0';
                char *start = recvbuf;
                char *nl;
                while ((nl = strchr(start, '\n')) != NULL) {
                    *nl = '\0';
                    if (nl > start && nl[-1] == '\r') nl[-1] = '\0';
                    if (start[0]) handle_cmd(client, start);
                    start = nl + 1;
                }
                int remain = (int)strlen(start);
                memmove(recvbuf, start, (size_t)remain + 1);
                recvlen = remain;
            }
        }
        Sleep(10);
#else
        /* POSIX simplified: blocking accept then serve one client */
        if (client == INVALID_SOCKET) {
            client = accept(server, NULL, NULL);
            if (client < 0) continue;
            printf("[machine_server] HMI connected\n");
            push_status(client);
        }
        fd_set fds;
        FD_ZERO(&fds);
        FD_SET(client, &fds);
        struct timeval tv = {0, 10000};
        int sel = select(client + 1, &fds, NULL, NULL, &tv);
        if (sel > 0 && FD_ISSET(client, &fds)) {
            char tmp[1024];
            int n = (int)recv(client, tmp, sizeof(tmp) - 1, 0);
            if (n <= 0) {
                CLOSESOCK(client);
                client = INVALID_SOCKET;
                continue;
            }
            tmp[n] = '\0';
            char *save = NULL;
            char *tok = strtok_r(tmp, "\n", &save);
            while (tok) {
                handle_cmd(client, tok);
                tok = strtok_r(NULL, "\n", &save);
            }
        }
#endif
    }

    runtime_shutdown();
#ifdef _WIN32
    WSACleanup();
#endif
    return 0;
}
