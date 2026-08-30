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

         
          // =========================================================
          // TOOLPATH + MACHINE HEAD
          // =========================================================

          CustomPaint(
            painter: _PathPainter(
              points: pts,
              headX: s.x,
              headY: s.y,
              progressIndex: s.pathIndex,
            ),
          ),

          // =========================================================
          // EMPTY STATE
          // =========================================================

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

          // =========================================================
          // PROGRAM NAME
          // =========================================================

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

          // =========================================================
          // COLOR LEGEND
          // =========================================================

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

// ===================================================================
// COLOR LEGEND
// ===================================================================

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

// ===================================================================
// PATH PAINTER
// ===================================================================

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
    // ===============================================================
    // GRID
    // ===============================================================

    final grid = Paint()
      ..color = const Color(0xFFDCE3EA).withValues(alpha: 0.35)
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

    if (points.isEmpty) {
      return;
    }

    // ===============================================================
    // FIND PATH BOUNDS
    // ===============================================================

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

    final spanX = (maxX - minX).abs() < 1
        ? 1.0
        : maxX - minX;

    final spanY = (maxY - minY).abs() < 1
        ? 1.0
        : maxY - minY;

    const pad = 40.0;

    // ===============================================================
    // MAP MACHINE COORDINATES → SCREEN
    // ===============================================================

    Offset map(double x, double y) {
      final nx = pad +
          ((x - minX) / spanX) *
              (size.width - (pad * 2));

      final ny = size.height -
          pad -
          ((y - minY) / spanY) *
              (size.height - (pad * 2));

      return Offset(nx, ny);
    }

        // ===============================================================
       // DRAW STITCHES ONLY AS THE MACHINE REACHES THEM
       // ===============================================================

    final tuftPaint = Paint()..style = PaintingStyle.fill;

    final visibleCount = progressIndex.clamp(0, points.length);

    for (int i = 0; i < visibleCount; i++) {
      final point = points[i];

     final ptOffset = map(
     point.x,
      point.y,
     );

     final Color tuftColor = Color(point.colorValue!);

  tuftPaint.color = tuftColor;

  canvas.drawCircle(
    ptOffset,
    3.0,
    tuftPaint,
  );
}
  

    // ===============================================================
    // MACHINE HEAD / NEEDLE
    // ===============================================================

    // ===============================================================
// TUFTING GUN
// ===============================================================

final head = map(
  headX,
  headY,
);

canvas.save();

canvas.translate(
  head.dx,
  head.dy,
);

 
const gunScale = 0.65;

canvas.scale(
  gunScale,
  gunScale,
);

 _TuftingGunPainter(
  active: progressIndex > 0,
).paint(
  canvas,
  const Size(80, 70),
);

canvas.restore();
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
// ===================================================================
// TUFTING GUN PAINTER
// ===================================================================

class _TuftingGunPainter extends CustomPainter {
  final bool active;

  const _TuftingGunPainter({
    required this.active,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 80.0;

    canvas.scale(scale, scale);

    final bodyPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF30343A);

    final metalPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFFB8BEC6);

    final darkPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF15181C);

    // جسم مسدس التطريز
    final body = RRect.fromRectAndRadius(
      const Rect.fromLTWH(15, 12, 42, 25),
      const Radius.circular(5),
    );

    canvas.drawRRect(
      body,
      bodyPaint,
    );

    // الجزء الأمامي
    canvas.drawRect(
      const Rect.fromLTWH(54, 17, 13, 14),
      metalPaint,
    );

    // الإبرة
    canvas.drawRect(
      const Rect.fromLTWH(65, 22, 10, 3),
      darkPaint,
    );

    // المقبض
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

    // الجزء العلوي
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(27, 6, 20, 8),
        const Radius.circular(3),
      ),
      metalPaint,
    );

    // مؤشر الحركة / الإبرة
    if (active) {
      final needlePaint = Paint()
        ..color = HmiColors.accent
        ..strokeWidth = 2;

      canvas.drawLine(
        const Offset(75, 20),
        const Offset(75, 30),
        needlePaint,
      );
    }
  }

  @override
  bool shouldRepaint(
    covariant _TuftingGunPainter oldDelegate,
  ) {
    return oldDelegate.active != active;
  }
}