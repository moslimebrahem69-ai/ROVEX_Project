import 'dart:typed_data';
import 'dart:ui' as ui;

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
    final designImage = svc.designImage;

    return Container(
      color: HmiColors.bg,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ---------------------------------------------------------
          // ORIGINAL DESIGN IMAGE
          // ---------------------------------------------------------
          if (designImage != null)
            _DesignImage(bytes: designImage),

          // ---------------------------------------------------------
          // TOOLPATH + NEEDLE
          // ---------------------------------------------------------
          CustomPaint(
            painter: _PathPainter(
              points: pts,
              headX: s.x,
              headY: s.y,
              progressIndex: s.pathIndex,
            ),
          ),

          // ---------------------------------------------------------
          // EMPTY STATE
          // ---------------------------------------------------------
          if (pts.isEmpty && designImage == null)
            const Center(
              child: Text(
                'No program loaded\nOpen DESIGN → Optimize → Load to AUTO',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: HmiColors.textMute,
                  fontSize: 13,
                ),
              ),
            ),

          // ---------------------------------------------------------
          // PROGRAM NAME
          // ---------------------------------------------------------
          if (pts.isNotEmpty || designImage != null)
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

          // ---------------------------------------------------------
          // COLOR LEGEND
          // ---------------------------------------------------------
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

/// Displays the original uploaded design image.
class _DesignImage extends StatelessWidget {
  final Uint8List bytes;

  const _DesignImage({
    required this.bytes,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Image.memory(
          bytes,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }
}

/// Shows detected thread colors and highlights
/// the color currently under the needle.
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
        color: HmiColors.panel.withValues(alpha: 0.85),
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
            ),
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
                    color: isActive
                        ? HmiColors.warn
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

  _PathPainter({
    required this.points,
    required this.headX,
    required this.headY,
    required this.progressIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) {
      return;
    }

    // ---------------------------------------------------------------
    // PATH BOUNDS
    // ---------------------------------------------------------------

    double minX = points.first.x;
    double maxX = points.first.x;
    double minY = points.first.y;
    double maxY = points.first.y;

    for (final p in points) {
      if (p.x < minX) minX = p.x;
      if (p.x > maxX) maxX = p.x;
      if (p.y < minY) minY = p.y;
      if (p.y > maxY) maxY = p.y;
    }

    final spanX =
        (maxX - minX).abs() < 1
            ? 1.0
            : maxX - minX;

    final spanY =
        (maxY - minY).abs() < 1
            ? 1.0
            : maxY - minY;

    const pad = 40.0;

    Offset map(double x, double y) {
      final nx = pad +
          (x - minX) /
              spanX *
              (size.width - 2 * pad);

      final ny = size.height -
          pad -
          (y - minY) /
              spanY *
              (size.height - 2 * pad);

      return Offset(nx, ny);
    }

    // ---------------------------------------------------------------
    // TOOLPATH
    // ---------------------------------------------------------------

    for (var i = 0; i < points.length - 1; i++) {
      final a = map(
        points[i].x,
        points[i].y,
      );

      final b = map(
        points[i + 1].x,
        points[i + 1].y,
      );

      final done = i < progressIndex;

      final threadColor =
          points[i].colorValue != null
              ? Color(points[i].colorValue!)
              : (done
                  ? HmiColors.modeActive
                  : HmiColors.accent);

      final paint = Paint()
        ..color = threadColor.withValues(
          alpha: done ? 1.0 : 0.65,
        )
        ..strokeWidth = done ? 2.8 : 1.8
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(
        a,
        b,
        paint,
      );
    }

    // ---------------------------------------------------------------
    // NEEDLE / MACHINE HEAD
    // ---------------------------------------------------------------

    final head = map(
      headX,
      headY,
    );

    canvas.drawCircle(
      head,
      8,
      Paint()
        ..color = HmiColors.alarm
        ..style = PaintingStyle.fill,
    );

    canvas.drawCircle(
      head,
      13,
      Paint()
        ..color = HmiColors.warn
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  @override
  bool shouldRepaint(
    covariant _PathPainter old,
  ) {
    return old.points != points ||
        old.headX != headX ||
        old.headY != headY ||
        old.progressIndex != progressIndex;
  }
}