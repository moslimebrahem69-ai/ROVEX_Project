import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/design.dart';
import '../models/machine_status.dart';
import '../l10n/l10n.dart';
import '../services/machine_service.dart';
import '../theme/hmi_colors.dart';
import 'machines_screen.dart';


/// Isometric 3D-ish view of gantry + embroidery needle.

class Needle3dAreaBody extends StatelessWidget {
  const Needle3dAreaBody({super.key});

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<MachineService>();
    final t = context.watch<LocaleController>().l10n;
    final s = svc.status;

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ============================================================
          // HEADER
          // ============================================================

          Row(
            children: [
              Container(
                width: 4,
                height: 22,
                decoration: BoxDecoration(
                  color: HmiColors.gold,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  t.t('needle3d_title'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: HmiColors.gold,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 7),

          // ============================================================
          // MACHINE POSITION
          // ============================================================

          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 7,
            ),
            decoration: BoxDecoration(
              color: HmiColors.panel,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: HmiColors.border,
              ),
            ),
            child: Row(
              children: [
                _positionItem(
                  'X',
                  s.x.toStringAsFixed(2),
                ),
                const SizedBox(width: 14),
                _positionItem(
                  'Y',
                  s.y.toStringAsFixed(2),
                ),
                const SizedBox(width: 14),
                _positionItem(
                  'Z',
                  s.z.toStringAsFixed(2),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: s.needle
                        ? HmiColors.alarm.withValues(alpha: 0.15)
                        : HmiColors.ready.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: s.needle
                          ? HmiColors.alarm.withValues(alpha: 0.45)
                          : HmiColors.ready.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    s.needle ? 'NEEDLE DOWN' : 'NEEDLE UP',
                    style: TextStyle(
                      color: s.needle
                          ? HmiColors.alarm
                          : HmiColors.ready,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // ============================================================
          // 3D WORKSPACE
          // ============================================================

          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: HmiColors.panelAlt,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: HmiColors.gold.withValues(alpha: 0.28),
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: CustomPaint(
                painter: _Machine3dPainter(
                  x: s.x,
                  y: s.y,
                  z: s.z,
                  needleDown: s.needle,
                  programPoints: svc.programPoints,
                  pathIndex: s.pathIndex,
                  running: s.state == MachineState.running,
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _positionItem(String axis, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          axis,
          style: const TextStyle(
            color: HmiColors.gold,
            fontSize: 10,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '$value mm',
          style: const TextStyle(
            color: HmiColors.textDim,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _Machine3dPainter extends CustomPainter {
  final double x;
  final double y;
  final double z;
  final bool needleDown;
  final List<TuftPoint> programPoints;
  final int pathIndex;
  final bool running;

  _Machine3dPainter({
    required this.x,
    required this.y,
    required this.z,
    required this.needleDown,
    required this.programPoints,
    required this.pathIndex,
    required this.running,
  });

  // ============================================================
  // MACHINE BED
  // ============================================================

  static const double bedWidth = 600.0;
  static const double bedHeight = 400.0;

  // ============================================================
  // ISOMETRIC PROJECTION
  // ============================================================

  Offset _project(
    double x,
    double y,
    double z,
    Size size,
    double scale,
  ) {
    // Center relative to machine bed center
    final cx = x - (bedWidth / 2);
    final cy = y - (bedHeight / 2);

    final isoX = (cx - cy) * 0.52 * scale;
    final isoY = (cx + cy) * 0.25 * scale - z * 0.65 * scale;

    return Offset(
      size.width * 0.5 + isoX,
      size.height * 0.5 + isoY, // Centered vertically and horizontally
    );
  }

  // ============================================================
  // CALCULATE SCALE TO FIT THE COMPLETE BED
  // ============================================================

  double _calculateScale(Size size) {
    final points = [
      const Offset(0, 0),
      const Offset(bedWidth, 0),
      const Offset(bedWidth, bedHeight),
      const Offset(0, bedHeight),
    ];

    double minX = double.infinity;
    double maxX = double.negativeInfinity;
    double minY = double.infinity;
    double maxY = double.negativeInfinity;

    for (final point in points) {
      final cx = point.dx - (bedWidth / 2);
      final cy = point.dy - (bedHeight / 2);

      final px = (cx - cy) * 0.52;
      final py = (cx + cy) * 0.25;

      minX = math.min(minX, px);
      maxX = math.max(maxX, px);
      minY = math.min(minY, py);
      maxY = math.max(maxY, py);
    }

    final projectedWidth = maxX - minX;
    final projectedHeight = maxY - minY;

    const padding = 40.0; // Safety margin around the machine bed

    final availableWidth = math.max(1.0, size.width - padding * 2);
    final availableHeight = math.max(1.0, size.height - padding * 2);

    final scaleX = availableWidth / projectedWidth;
    final scaleY = availableHeight / projectedHeight;

    return math.min(scaleX, scaleY);
  }

  // ============================================================
  // PAINT
  // ============================================================

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) {
      return;
    }

    final scale = _calculateScale(size);

    // ------------------------------------------------------------
    // BACKGROUND GRID
    // ------------------------------------------------------------

    final gridPaint = Paint()
      ..color = HmiColors.border.withValues(alpha: 0.16)
      ..strokeWidth = 1;

    const gridStep = 50.0;

    for (double gx = 0; gx <= bedWidth; gx += gridStep) {
      final a = _project(
        gx,
        0,
        0,
        size,
        scale,
      );

      final b = _project(
        gx,
        bedHeight,
        0,
        size,
        scale,
      );

      canvas.drawLine(a, b, gridPaint);
    }

    for (double gy = 0; gy <= bedHeight; gy += gridStep) {
      final a = _project(
        0,
        gy,
        0,
        size,
        scale,
      );

      final b = _project(
        bedWidth,
        gy,
        0,
        size,
        scale,
      );

      canvas.drawLine(a, b, gridPaint);
    }

    // ------------------------------------------------------------
    // RUG / MACHINE BED
    // ------------------------------------------------------------

    final b0 = _project(
      0,
      0,
      0,
      size,
      scale,
    );

    final b1 = _project(
      bedWidth,
      0,
      0,
      size,
      scale,
    );

    final b2 = _project(
      bedWidth,
      bedHeight,
      0,
      size,
      scale,
    );

    final b3 = _project(
      0,
      bedHeight,
      0,
      size,
      scale,
    );

    final rugPath = Path()
      ..moveTo(b0.dx, b0.dy)
      ..lineTo(b1.dx, b1.dy)
      ..lineTo(b2.dx, b2.dy)
      ..lineTo(b3.dx, b3.dy)
      ..close();

    // Rug surface
    final rugPaint = Paint()
      ..color = HmiColors.accent.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;

    canvas.drawPath(rugPath, rugPaint);

    // Rug border
    final borderPaint = Paint()
      ..color = HmiColors.gold.withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawPath(rugPath, borderPaint);

    // ------------------------------------------------------------
    // RUG CORNER MARKERS
    // ------------------------------------------------------------

    final cornerPaint = Paint()
      ..color = HmiColors.gold
      ..style = PaintingStyle.fill;

    for (final point in [b0, b1, b2, b3]) {
      canvas.drawCircle(
        point,
        3,
        cornerPaint,
      );
    }

    // ------------------------------------------------------------
    // PROGRAM DRAWING PATH
    // ------------------------------------------------------------

    if (programPoints.isNotEmpty) {
      // 1. Draw complete design path preview
      final pathPaint = Paint()
        ..color = HmiColors.gold.withValues(alpha: 0.35)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;

      final path = Path();
      for (int i = 0; i < programPoints.length; i++) {
        final pt = programPoints[i];
        final projected = _project(pt.x, pt.y, 0, size, scale);
        if (i == 0) {
          path.moveTo(projected.dx, projected.dy);
        } else {
          path.lineTo(projected.dx, projected.dy);
        }
      }
      canvas.drawPath(path, pathPaint);

      // 2. Draw executed path during execution
      if (pathIndex > 0) {
        final executedPaint = Paint()
          ..color = HmiColors.ready
          ..strokeWidth = 2.0
          ..style = PaintingStyle.stroke;

        final executedPath = Path();
        final maxIdx = math.min(pathIndex, programPoints.length - 1);
        for (int i = 0; i <= maxIdx; i++) {
          final pt = programPoints[i];
          final projected = _project(pt.x, pt.y, 0, size, scale);
          if (i == 0) {
            executedPath.moveTo(projected.dx, projected.dy);
          } else {
            executedPath.lineTo(projected.dx, projected.dy);
          }
        }
        canvas.drawPath(executedPath, executedPaint);
      }

      // 3. Draw individual tuft points
      final pointPaint = Paint()
        ..color = HmiColors.accent
        ..style = PaintingStyle.fill;

      for (int i = 0; i < programPoints.length; i++) {
        final pt = programPoints[i];
        final projected = _project(pt.x, pt.y, 0, size, scale);
        final isCurrent = i == pathIndex;

        canvas.drawCircle(
          projected,
          isCurrent ? 4.0 : 1.5,
          isCurrent ? (Paint()..color = HmiColors.alarm) : pointPaint,
        );
      }
    }

    // ------------------------------------------------------------
    // GANTRY
    // ------------------------------------------------------------

    final currentY = y.clamp(
      0.0,
      bedHeight,
    );

    final gantryLeft = _project(
      0,
      currentY,
      40,
      size,
      scale,
    );

    final gantryRight = _project(
      bedWidth,
      currentY,
      40,
      size,
      scale,
    );

    final gantryPaint = Paint()
      ..color = HmiColors.gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      gantryLeft,
      gantryRight,
      gantryPaint,
    );

    // ------------------------------------------------------------
    // CARRIAGE
    // ------------------------------------------------------------

    final currentX = x.clamp(
      0.0,
      bedWidth,
    );

    final carriage = _project(
      currentX,
      currentY,
      55,
      size,
      scale,
    );

    final carriagePaint = Paint()
      ..color = HmiColors.sand
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      carriage,
      8,
      carriagePaint,
    );

    // ------------------------------------------------------------
    // NEEDLE
    // ------------------------------------------------------------

    final needleZ = needleDown
        ? 0.0
        : z.clamp(0.0, 25.0);

    final needleTip = _project(
      currentX,
      currentY,
      needleZ,
      size,
      scale,
    );

    final needlePaint = Paint()
      ..color = needleDown
          ? HmiColors.alarm
          : HmiColors.dro
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      carriage,
      needleTip,
      needlePaint,
    );

    canvas.drawCircle(
      needleTip,
      4,
      Paint()
        ..color = needleDown
            ? HmiColors.alarm
            : HmiColors.dro,
    );

    // ------------------------------------------------------------
    // NEEDLE SHADOW
    // ------------------------------------------------------------

    final shadow = _project(
      currentX,
      currentY,
      0,
      size,
      scale,
    );

    canvas.drawCircle(
      shadow,
      7,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.28),
    );

    // ------------------------------------------------------------
    // CENTER CROSSHAIR
    // ------------------------------------------------------------

    final center = _project(
      bedWidth / 2,
      bedHeight / 2,
      0,
      size,
      scale,
    );

    final crossPaint = Paint()
      ..color = HmiColors.textMute.withValues(alpha: 0.35)
      ..strokeWidth = 1;

    canvas.drawLine(
      Offset(center.dx - 8, center.dy),
      Offset(center.dx + 8, center.dy),
      crossPaint,
    );

    canvas.drawLine(
      Offset(center.dx, center.dy - 8),
      Offset(center.dx, center.dy + 8),
      crossPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _Machine3dPainter oldDelegate) {
    return oldDelegate.x != x ||
        oldDelegate.y != y ||
        oldDelegate.z != z ||
        oldDelegate.needleDown != needleDown ||
        oldDelegate.pathIndex != pathIndex ||
        oldDelegate.programPoints != programPoints ||
        oldDelegate.running != running;
  }
}

class ErrorsAreaBody extends StatelessWidget {
  const ErrorsAreaBody({super.key});

  static const _catalog = [
    (
      'E001',
      'Soft limit',
      'Axis outside work area',
      'Reduce jog step or re-home. Check work_area in machine_config.',
    ),
    (
      'E002',
      'Not connected',
      'Machine is not connected',
      'SETUP → CONNECT (SIM or SERIAL COM). Start machine_server.exe.',
    ),
    (
      'E003',
      'Path empty',
      'No path available',
      'DESIGN → extract path, or PROGRAM → open CSV, then AUTO.',
    ),
    (
      'E004',
      'EMERGENCY STOP',
      'Emergency stop',
      'Clear hazard, press RESET, then re-home before Cycle Start.',
    ),
    (
      'E005',
      'Serial lost',
      'Serial connection lost',
      'Check USB/COM cable, baud rate, GRBL power.',
    ),
    (
      'E006',
      'JOG mode required',
      'JOG mode is required',
      'Select JOG mode before axis jog.',
    ),
    (
      'E007',
      'AUTO mode required',
      'AUTO mode is required',
      'Select AUTO before Cycle Start for programs.',
    ),
    (
      'E008',
      'MDI mode required',
      'MDI mode is required',
      'Select MDI to execute single G/M lines.',
    ),
    (
      'E009',
      'Needle fault',
      'Needle fault',
      'Check M8/M9 actuator wiring and Z clearance.',
    ),
    (
      'E010',
      'Not referenced',
      'Machine is not referenced',
      'Run HOME / REF before production AUTO.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LocaleController>().l10n;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          t.t('errors_title'),
          style: const TextStyle(
            color: HmiColors.gold,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        for (final e in _catalog)
          Card(
            color: HmiColors.panelAlt,
            margin: const EdgeInsets.only(bottom: 8),
            child: ExpansionTile(
              iconColor: HmiColors.gold,
              collapsedIconColor: HmiColors.textDim,
              title: Text(
                '${e.$1}  ${e.$2}',
                style: const TextStyle(
                  color: HmiColors.text,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                e.$3,
                style: const TextStyle(
                  color: HmiColors.textDim,
                  fontSize: 12,
                ),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  child: Text(
                    e.$4,
                    style: const TextStyle(
                      color: HmiColors.sand,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class PlcAreaBody extends StatefulWidget {
  const PlcAreaBody({super.key});

  @override
  State<PlcAreaBody> createState() => _PlcAreaBodyState();
}

class _PlcAreaBodyState extends State<PlcAreaBody> {
  final _name = TextEditingController();
  final _code = TextEditingController(text: 'M8');
  final _note = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<MachineService>();
    final t = context.watch<LocaleController>().l10n;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.t('plc_title'),
              style: const TextStyle(
                  color: HmiColors.gold,
                  fontSize: 18,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text(
            'M8/M9 = needle engage/retract (embroidery). Add custom M-codes for your PLC map.',
            style: TextStyle(color: HmiColors.textDim, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              itemCount: svc.plcMacros.length + 1,
              itemBuilder: (context, i) {
                if (i == svc.plcMacros.length) {
                  // Last button on this page: connect to a machine over
                  // WiFi (one phone/app, several machines to switch between).
                  final active = svc.activeMachine;
                  return Card(
                    color: HmiColors.panel,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: const BorderSide(color: HmiColors.accent),
                    ),
                    child: ListTile(
                      leading: Icon(
                        Icons.wifi_tethering,
                        color: svc.runtimeLinked
                            ? HmiColors.ready
                            : HmiColors.textDim,
                      ),
                      title: Text(t.t('connect_to_machine'),
                          style: const TextStyle(
                              color: HmiColors.text,
                              fontWeight: FontWeight.w700)),
                      subtitle: Text(
                          '${active.name} — ${active.host}:${active.port}'
                          '${svc.runtimeLinked ? '  ·  LINKED' : ''}',
                          style: const TextStyle(color: HmiColors.textDim)),
                      trailing: ElevatedButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const MachinesScreen()),
                        ),
                        child: Text(t.t('machines_title')),
                      ),
                    ),
                  );
                }
                final m = svc.plcMacros[i];
                return Card(
                  color: HmiColors.panelAlt,
                  child: ListTile(
                    title: Text(m.name,
                        style: const TextStyle(
                            color: HmiColors.text,
                            fontWeight: FontWeight.w700)),
                    subtitle: Text('${m.code}  —  ${m.note}',
                        style: const TextStyle(color: HmiColors.textDim)),
                    trailing: ElevatedButton(
                      onPressed: () => svc.runPlcMacro(m),
                      child: const Text('RUN'),
                    ),
                  ),
                );
              },
            ),
          ),
          const Divider(color: HmiColors.border),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _name,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  style: const TextStyle(color: HmiColors.text),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 100,
                child: TextField(
                  controller: _code,
                  decoration: const InputDecoration(
                    labelText: 'M / G',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  style: const TextStyle(color: HmiColors.gold),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _note,
                  decoration: const InputDecoration(
                    labelText: 'Note',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  style: const TextStyle(color: HmiColors.text),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  if (_name.text.trim().isEmpty || _code.text.trim().isEmpty) {
                    return;
                  }
                  svc.addPlcMacro(PlcMacro(
                    name: _name.text.trim(),
                    code: _code.text.trim().toUpperCase(),
                    note: _note.text.trim(),
                  ));
                  _name.clear();
                  _note.clear();
                },
                child: const Text('ADD'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}