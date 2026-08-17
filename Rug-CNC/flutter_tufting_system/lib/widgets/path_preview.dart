import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/design.dart';
import '../services/machine_service.dart';
import '../theme/hmi_colors.dart';

class PathPreview extends StatelessWidget {
  const PathPreview({super.key});

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<MachineService>();
    final pts = svc.programPoints;
    final s = svc.status;
    final colorGroups = svc.colorGroups;
    final activeColor = svc.activeColorOrder;

    return Container(
      color: HmiColors.bg,
      child: CustomPaint(
        painter: _PathPainter(
          points: pts,
          headX: s.x,
          headY: s.y,
          progressIndex: s.pathIndex,
        ),
        child: pts.isEmpty
            ? const Center(
                child: Text(
                  'No program loaded\nOpen DESIGN → Optimize → Load to AUTO',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: HmiColors.textMute, fontSize: 13),
                ),
              )
            : Stack(
                children: [
                  Align(
                    alignment: Alignment.topLeft,
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Text(
                        svc.loadedProgramName ?? 'PROGRAM',
                        style: const TextStyle(
                            color: HmiColors.textDim, fontSize: 12),
                      ),
                    ),
                  ),
                  if (colorGroups.isNotEmpty)
                    Align(
                      alignment: Alignment.topRight,
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: _ColorLegend(
                          groups: colorGroups,
                          activeOrder: activeColor,
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

/// Shows the detected thread colors and highlights which one is
/// currently under the needle — this is the "thread change" readout.
class _ColorLegend extends StatelessWidget {
  final List<ColorGroup> groups;
  final int? activeOrder;

  const _ColorLegend({required this.groups, required this.activeOrder});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: HmiColors.panel.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: HmiColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Colors: ${groups.length}'
            '${activeOrder != null ? '  ·  now: $activeOrder/${groups.length}' : ''}',
            style: const TextStyle(color: HmiColors.textDim, fontSize: 11),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: groups.map((g) {
              final isActive = g.order == activeOrder;
              return Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: Color(g.colorValue),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isActive ? HmiColors.warn : HmiColors.border,
                    width: isActive ? 2.5 : 1,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _PathPainter extends CustomPainter {
  final List<TuftPoint> points;
  final double headX;
  final double headY;
  final int progressIndex;

  _PathPainter({
    required this.points,
    required this.headX,
    required this.headY,
    required this.progressIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // grid
    final grid = Paint()
      ..color = const Color(0xFFDCE3EA)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 40) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = 0; y < size.height; y += 40) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    if (points.isEmpty) return;

    double minX = points.first.x, maxX = points.first.x;
    double minY = points.first.y, maxY = points.first.y;
    for (final p in points) {
      if (p.x < minX) minX = p.x;
      if (p.x > maxX) maxX = p.x;
      if (p.y < minY) minY = p.y;
      if (p.y > maxY) maxY = p.y;
    }
    final spanX = (maxX - minX).abs() < 1 ? 1.0 : (maxX - minX);
    final spanY = (maxY - minY).abs() < 1 ? 1.0 : (maxY - minY);
    const pad = 40.0;

    Offset map(double x, double y) {
      final nx = pad + (x - minX) / spanX * (size.width - 2 * pad);
      final ny = size.height - pad - (y - minY) / spanY * (size.height - 2 * pad);
      return Offset(nx, ny);
    }

    for (var i = 0; i < points.length - 1; i++) {
      final a = map(points[i].x, points[i].y);
      final b = map(points[i + 1].x, points[i + 1].y);
      final done = i < progressIndex;
      final threadColor = points[i].colorValue != null
          ? Color(points[i].colorValue!)
          : (done ? HmiColors.modeActive : HmiColors.accent);
      final paint = Paint()
        ..color = threadColor.withValues(alpha: done ? 1.0 : 0.55)
        ..strokeWidth = done ? 2.4 : 1.6
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(a, b, paint);
    }

    final head = map(headX, headY);
    canvas.drawCircle(
        head,
        7,
        Paint()
          ..color = HmiColors.alarm
          ..style = PaintingStyle.fill);
    canvas.drawCircle(
        head,
        10,
        Paint()
          ..color = HmiColors.warn
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(covariant _PathPainter old) =>
      old.points != points ||
      old.headX != headX ||
      old.headY != headY ||
      old.progressIndex != progressIndex;
}
