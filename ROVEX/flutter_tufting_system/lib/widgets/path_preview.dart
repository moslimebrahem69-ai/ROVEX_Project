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
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(
            painter: _PathPainter(
              points: pts,
              headX: s.x,
              headY: s.y,
              progressIndex: s.pathIndex,
            ),
          ),

          if (pts.isEmpty)
            const Center(
              child: Text(
                'No toolpath loaded\nOpen DESIGN → Optimize → Load to AUTO',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: HmiColors.textMute,
                  fontSize: 13,
                ),
              ),
            ),

          if (pts.isNotEmpty)
            Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Text(
                  svc.loadedProgramName ??
                      svc.designName ??
                      'PROGRAM',
                  style: const TextStyle(
                    color: HmiColors.textDim,
                    fontSize: 12,
                  ),
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
    );
  }
}

class _ColorLegend extends StatelessWidget {
  final List<ColorGroup> groups;
  final int? activeOrder;

  const _ColorLegend({
    required this.groups,
    required this.activeOrder,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: HmiColors.panel.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: HmiColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Colors: ${groups.length}'
            '${activeOrder != null ? '  ·  now: $activeOrder/${groups.length}' : ''}',
            style: const TextStyle(
              color: HmiColors.textDim,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 5),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: groups.map((group) {
              final isActive = group.order == activeOrder;

              return Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: Color(group.colorValue),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isActive
                        ? HmiColors.accent
                        : HmiColors.border,
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

  const _PathPainter({
    required this.points,
    required this.headX,
    required this.headY,
    required this.progressIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawGrid(canvas, size);

    if (points.isEmpty) {
      return;
    }

    final bounds = _getBounds();
    final minX = bounds[0];
    final maxX = bounds[1];
    final minY = bounds[2];
    final maxY = bounds[3];

    final spanX = (maxX - minX).abs() < 1 ? 1.0 : maxX - minX;
    final spanY = (maxY - minY).abs() < 1 ? 1.0 : maxY - minY;

    const pad = 40.0;

    Offset map(double x, double y) {
      final nx = pad +
          ((x - minX) / spanX) *
              (size.width - pad * 2);

      final ny = size.height -
          pad -
          ((y - minY) / spanY) *
              (size.height - pad * 2);

      return Offset(nx, ny);
    }

    _drawStitches(canvas, map, progressIndex);
    _drawGun(canvas, map);
  }

  void _drawGrid(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = HmiColors.border.withValues(alpha: 0.35)
      ..strokeWidth = 1;

    for (double x = 0; x < size.width; x += 40) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        grid,
      );
    }

    for (double y = 0; y < size.height; y += 40) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        grid,
      );
    }
  }

  List<double> _getBounds() {
    double minX = points.first.x;
    double maxX = points.first.x;
    double minY = points.first.y;
    double maxY = points.first.y;

    for (final point in points) {
      if (point.x < minX) minX = point.x;
      if (point.x > maxX) maxX = point.x;
      if (point.y < minY) minY = point.y;
      if (point.y > maxY) maxY = point.y;
    }

    return [minX, maxX, minY, maxY];
  }

  void _drawStitches(
    Canvas canvas,
    Offset Function(double, double) map,
    int progressIndex,
  ) {
    final paint = Paint()..style = PaintingStyle.fill;
    final visibleCount = progressIndex.clamp(0, points.length);

    for (int i = 0; i < visibleCount; i++) {
      final point = points[i];
      final colorValue = point.colorValue;

      if (colorValue == null) {
        paint.color = HmiColors.accent;
      } else {
        paint.color = Color(colorValue);
      }

      canvas.drawCircle(
        map(point.x, point.y),
        3.0,
        paint,
      );
    }
  }

  void _drawGun(
    Canvas canvas,
    Offset Function(double, double) map,
  ) {
    final head = map(headX, headY);

    canvas.save();
    canvas.translate(head.dx, head.dy);
    canvas.scale(0.65);

    const gunSize = Size(80, 70);

    const gunPainter = _TuftingGunPainter();

    gunPainter.paint(
      canvas,
      gunSize,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PathPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.headX != headX ||
        oldDelegate.headY != headY ||
        oldDelegate.progressIndex != progressIndex;
  }
}

class _TuftingGunPainter extends CustomPainter {
  const _TuftingGunPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 80.0;
    canvas.scale(scale, scale);

    final bodyPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = HmiColors.panelAlt;

    final metalPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = HmiColors.accent;

    final darkPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = HmiColors.bg;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(15, 12, 42, 25),
        const Radius.circular(5),
      ),
      bodyPaint,
    );

    canvas.drawRect(
      const Rect.fromLTWH(54, 17, 13, 14),
      metalPaint,
    );

    canvas.drawRect(
      const Rect.fromLTWH(65, 22, 10, 3),
      darkPaint,
    );

    final handle = Path()
      ..moveTo(25, 35)
      ..lineTo(43, 35)
      ..lineTo(49, 62)
      ..lineTo(31, 62)
      ..close();

    canvas.drawPath(
      handle,
      bodyPaint,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(27, 6, 20, 8),
        const Radius.circular(3),
      ),
      metalPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _TuftingGunPainter oldDelegate) {
    return false;
  }
}