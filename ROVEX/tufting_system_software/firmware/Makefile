# Makefile for the real-time control firmware + machine_server.
#
# Targets:
#   make                 - build bin/ROVEX
#   make machine_server  - build bin/machine_server (HMI TCP runtime)
#   make test            - unit tests
#   make clean

CC      := gcc
CFLAGS  := -std=c11 -D_WIN32 -O2 -Wall -Wextra -Iinclude
LDFLAGS := -lm
WINLIBS := -lws2_32

SRC_DIR  := src
BIN_DIR  := bin
TEST_DIR := tests

CORE_SRCS := \
	$(SRC_DIR)/motion_profile.c \
	$(SRC_DIR)/kinematics.c \
	$(SRC_DIR)/path_loader.c \
	$(SRC_DIR)/hal_sim.c

SERIAL_WIN := $(SRC_DIR)/hal_serial_win.c
RUNTIME_SRC := $(SRC_DIR)/machine_runtime.c
SERVER_SRC := $(SRC_DIR)/machine_server.c
MAIN_SRC := $(SRC_DIR)/main.c

.PHONY: all clean test machine_server

all: $(BIN_DIR)/ROVEX $(BIN_DIR)/machine_server

machine_server: $(BIN_DIR)/machine_server

$(BIN_DIR):
	mkdir -p $(BIN_DIR)

$(BIN_DIR)/ROVEX: $(MAIN_SRC) $(CORE_SRCS) | $(BIN_DIR)
	$(CC) $(CFLAGS) -o $@ $(MAIN_SRC) $(CORE_SRCS) $(LDFLAGS)

$(BIN_DIR)/machine_server: $(SERVER_SRC) $(RUNTIME_SRC) $(CORE_SRCS) $(SERIAL_WIN) | $(BIN_DIR)
	$(CC) $(CFLAGS) -o $@ $(SERVER_SRC) $(RUNTIME_SRC) $(CORE_SRCS) $(SERIAL_WIN) $(LDFLAGS) $(WINLIBS)

test: $(BIN_DIR)/test_motion_profile
	./$(BIN_DIR)/test_motion_profile

$(BIN_DIR)/test_motion_profile: $(TEST_DIR)/test_motion_profile.c $(SRC_DIR)/motion_profile.c | $(BIN_DIR)
	$(CC) $(CFLAGS) -o $@ $(TEST_DIR)/test_motion_profile.c $(SRC_DIR)/motion_profile.c $(LDFLAGS)

clean:
	rm -rf $(BIN_DIR)
