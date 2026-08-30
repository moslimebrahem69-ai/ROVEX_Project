#include "path_optimizer.h"

#include <math.h>
#include <stdlib.h>

typedef struct
{
    double x;
    double y;
} Point;

static double distance_between(const Point *a, const Point *b)
{
    const double dx = a->x - b->x;
    const double dy = a->y - b->y;

    return sqrt(dx * dx + dy * dy);
}

static double calculate_path_length(
    const Point *points,
    int count,
    const int *order)
{
    double total_length = 0.0;

    for (int i = 0; i < count - 1; ++i)
    {
        total_length += distance_between(
            &points[order[i]],
            &points[order[i + 1]]);
    }

    return total_length;
}

static void reverse_order_segment(int *order, int start, int end)
{
    while (start < end)
    {
        const int temp = order[start];
        order[start] = order[end];
        order[end] = temp;

        ++start;
        --end;
    }
}

static void apply_two_opt(
    const Point *points,
    int count,
    int *order,
    double *path_length)
{
    int improved = 1;

    while (improved)
    {
        improved = 0;

        for (int i = 0; i < count - 1; ++i)
        {
            for (int j = i + 2; j < count; ++j)
            {
                if (j == count - 1)
                {
                    continue;
                }

                const double current_distance =
                    distance_between(&points[order[i]], &points[order[i + 1]]) +
                    distance_between(&points[order[j]], &points[order[j + 1]]);

                const double new_distance =
                    distance_between(&points[order[i]], &points[order[j]]) +
                    distance_between(&points[order[i + 1]], &points[order[j + 1]]);

                const double delta = new_distance - current_distance;

                if (delta < -1e-9)
                {
                    reverse_order_segment(order, i + 1, j);

                    *path_length += delta;
                    improved = 1;
                }
            }
        }
    }
}

void optimize_path(Point *points, int count, int *order)
{
    for (int i = 0; i < count; ++i)
    {
        order[i] = i;
    }

    double path_length = calculate_path_length(points, count, order);

    apply_two_opt(points, count, order, &path_length);
}

void nearest_neighbor(Point *points, int count, int *order)
{
    int *visited = calloc((size_t)count, sizeof(*visited));

    if (visited == NULL || count <= 0)
    {
        free(visited);
        return;
    }

    order[0] = 0;
    visited[0] = 1;

    for (int i = 1; i < count; ++i)
    {
        double nearest_distance = 1e9;
        int nearest_point = -1;

        for (int j = 0; j < count; ++j)
        {
            if (visited[j])
            {
                continue;
            }

            const double current_distance =
                distance_between(&points[order[i - 1]], &points[j]);

            if (current_distance < nearest_distance)
            {
                nearest_distance = current_distance;
                nearest_point = j;
            }
        }

        if (nearest_point != -1)
        {
            order[i] = nearest_point;
            visited[nearest_point] = 1;
        }
    }

    free(visited);
}