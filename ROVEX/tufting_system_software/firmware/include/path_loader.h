/*
 * path_loader.h
 * -------------
 * Reads the optimized path CSV produced by the Python Edge-AI stage
 * (see /ipc/PROTOCOL.md for the exact file format contract).
 */

#ifndef TUFTING_PATH_LOADER_H
#define TUFTING_PATH_LOADER_H

typedef struct {
    double x;
    double y;
} PathPoint;

/*
 * Loads up to `max_points` points from `filename` into `out_points`.
 * Returns the number of points loaded, or -1 on error (file not
 * found, malformed header, etc.). Errors are also printed to stderr.
 */
int path_loader_load(const char *filename, PathPoint *out_points, int max_points);

#endif /* TUFTING_PATH_LOADER_H */
