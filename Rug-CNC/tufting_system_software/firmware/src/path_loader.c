/*
 * path_loader.c
 * -------------
 * See path_loader.h. Parses the simple "x_mm,y_mm" CSV interchange
 * format shared with the Python planning stage.
 */

#include <stdio.h>
#include <string.h>
#include "../include/path_loader.h"
#include "../include/config.h"

int path_loader_load(const char *filename, PathPoint *out_points, int max_points) {
    FILE *f = fopen(filename, "r");
    if (!f) {
        fprintf(stderr, "[path_loader] ERROR: could not open '%s'\n", filename);
        return -1;
    }

    char line[MAX_LINE_LEN];
    if (!fgets(line, sizeof(line), f)) {
        fprintf(stderr, "[path_loader] ERROR: file '%s' is empty\n", filename);
        fclose(f);
        return -1;
    }
    if (strncmp(line, "x_mm,y_mm", 9) != 0) {
        fprintf(stderr,
                "[path_loader] ERROR: unexpected header in '%s' "
                "(expected 'x_mm,y_mm')\n", filename);
        fclose(f);
        return -1;
    }

    int n = 0;
    while (n < max_points && fgets(line, sizeof(line), f)) {
        double x, y;
        if (sscanf(line, "%lf,%lf", &x, &y) == 2) {
            out_points[n].x = x;
            out_points[n].y = y;
            n++;
        }
    }
    fclose(f);

    if (n < 2) {
        fprintf(stderr,
                "[path_loader] ERROR: '%s' contains fewer than 2 valid points\n",
                filename);
        return -1;
    }
    return n;
}
