#include "path_optimizer.h"
#include <math.h>
#include <stdlib.h>
#include <string.h>

typedef struct
{
    double x;
    double y;
} Point;

typedef struct
{
    Point *points;
    int count;
} Path;

static double distance(Point a, Point b)
{
    double dx = a.x - b.x;
    double dy = a.y - b.y;
    return sqrt(dx * dx + dy * dy);
}

static double path_length(Point *points, int count, int *order)
{
    double total = 0.0;
    for (int i = 0; i < count - 1; i++)
    {
        total += distance(points[order[i]], points[order[i + 1]]);
    }
    return total;
}

static void two_opt_pass(Point *points, int count, int *order, double *best_length)
{
    int improved = 1;
    while (improved)
    {
        improved = 0;
        for (int i = 0; i < count - 1; i++)
        {
            for (int j = i + 2; j < count; j++)
            {
                if (j == count - 1)
                    continue;

                double delta = -distance(points[order[i]], points[order[i + 1]]) - distance(points[order[j]], points[order[j + 1]]) + distance(points[order[i]], points[order[j]]) + distance(points[order[i + 1]], points[order[j + 1]]);

                if (delta < -1e-9)
                {
                    for (int k = i + 1; k <= j; k++)
                    {
                        int temp = order[k];
                        order[k] = order[j + i + 1 - k];
                        order[j + i + 1 - k] = temp;
                    }
                    *best_length += delta;
                    improved = 1;
                }
            }
        }
    }
}

void optimize_path(Point *points, int count, int *order)
{
    for (int i = 0; i < count; i++)
    {
        order[i] = i;
    }

    double best_length = path_length(points, count, order);
    two_opt_pass(points, count, order, &best_length);
}

void nearest_neighbor(Point *points, int count, int *order)
{
    int *visited = calloc(count, sizeof(int));
    order[0] = 0;
    visited[0] = 1;

    for (int i = 1; i < count; i++)
    {
        double min_dist = 1e9;
        int next = -1;

        for (int j = 0; j < count; j++)
        {
            if (!visited[j])
            {
                double d = distance(points[order[i - 1]], points[j]);
                if (d < min_dist)
                {
                    min_dist = d;
                    next = j;
                }
            }
        }

        if (next != -1)
        {
            order[i] = next;
            visited[next] = 1;
        }
    }

    free(visited);
}
