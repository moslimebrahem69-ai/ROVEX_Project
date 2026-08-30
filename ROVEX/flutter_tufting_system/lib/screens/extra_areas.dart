import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
import '../models/design.dart';
import '../models/machine_status.dart';
import '../services/machine_service.dart';
import '../theme/hmi_colors.dart';
import 'machines_screen.dart';

class Needle3dAreaBody extends StatelessWidget {
  const Needle3dAreaBody({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.watch<MachineService>();
    final localization = context.watch<LocaleController>().l10n;
    final status = service.status;

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
                  localization.t('needle3d_title'),
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
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 7,
            ),
            decoration: BoxDecoration(
              color: HmiColors.panel,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: HmiColors.border),
            ),
            child: Row(
              children: [
                _PositionItem(
                  axis: 'X',
                  value: status.x.toStringAsFixed(2),
                ),
                const SizedBox(width: 14),
                _PositionItem(
                  axis: 'Y',
                  value: status.y.toStringAsFixed(2),
                ),
                const SizedBox(width: 14),
                _PositionItem(
                  axis: 'Z',
                  value: status.z.toStringAsFixed(2),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: status.needle
                        ? HmiColors.alarm.withValues(alpha: 0.15)
                        : HmiColors.ready.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: status.needle
                          ? HmiColors.alarm.withValues(alpha: 0.45)
                          : HmiColors.ready.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    status.needle ? 'NEEDLE DOWN' : 'NEEDLE UP',
                    style: TextStyle(
                      color: status.needle
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
                  x: status.x,
                  y: status.y,
                  z: status.z,
                  needleDown: status.needle,
                  programPoints: service.programPoints,
                  pathIndex: status.pathIndex,
                  running: status.state == MachineState.running,
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PositionItem extends StatelessWidget {
  final String axis;
  final String value;

  const _PositionItem({
    required this.axis,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
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

  static const double bedWidth = 600.0;
  static const double bedHeight = 400.0;

  Offset _project(
    double x,
    double y,
    double z,
    Size size,
    double scale,
  ) {
    final centeredX = x - bedWidth / 2;
    final centeredY = y - bedHeight / 2;

    final projectedX = (centeredX - centeredY) * 0.52 * scale;
    final projectedY =
        (centeredX + centeredY) * 0.25 * scale - z * 0.65 * scale;

    return Offset(
      size.width * 0.5 + projectedX,
      size.height * 0.5 + projectedY,
    );
  }

  double _calculateScale(Size size) {
    const corners = [
      Offset(0, 0),
      Offset(bedWidth, 0),
      Offset(bedWidth, bedHeight),
      Offset(0, bedHeight),
    ];

    double minX = double.infinity;
    double maxX = double.negativeInfinity;
    double minY = double.infinity;
    double maxY = double.negativeInfinity;

    for (final corner in corners) {
      final centeredX = corner.dx - bedWidth / 2;
      final centeredY = corner.dy - bedHeight / 2;

      final projectedX = (centeredX - centeredY) * 0.52;
      final projectedY = (centeredX + centeredY) * 0.25;

      minX = math.min(minX, projectedX);
      maxX = math.max(maxX, projectedX);
      minY = math.min(minY, projectedY);
      maxY = math.max(maxY, projectedY);
    }

    final projectedWidth = maxX - minX;
    final projectedHeight = maxY - minY;

    const padding = 40.0;

    final availableWidth = math.max(
      1.0,
      size.width - padding * 2,
    );
    final availableHeight = math.max(
      1.0,
      size.height - padding * 2,
    );

    final widthScale = availableWidth / projectedWidth;
    final heightScale = availableHeight / projectedHeight;

    return math.min(widthScale, heightScale);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) {
      return;
    }

    final scale = _calculateScale(size);

    _drawGrid(canvas, size, scale);
    _drawWorkArea(canvas, size, scale);
    _drawProgramPath(canvas, size, scale);
    _drawGantry(canvas, size, scale);
    _drawCarriage(canvas, size, scale);
    _drawNeedle(canvas, size, scale);
    _drawNeedleShadow(canvas, size, scale);
    _drawCenterCrosshair(canvas, size, scale);
  }

  void _drawGrid(
    Canvas canvas,
    Size size,
    double scale,
  ) {
    final gridPaint = Paint()
      ..color = HmiColors.border.withValues(alpha: 0.16)
      ..strokeWidth = 1;

    const gridStep = 50.0;

    for (double x = 0; x <= bedWidth; x += gridStep) {
      canvas.drawLine(
        _project(x, 0, 0, size, scale),
        _project(x, bedHeight, 0, size, scale),
        gridPaint,
      );
    }

    for (double y = 0; y <= bedHeight; y += gridStep) {
      canvas.drawLine(
        _project(0, y, 0, size, scale),
        _project(bedWidth, y, 0, size, scale),
        gridPaint,
      );
    }
  }

  void _drawWorkArea(
    Canvas canvas,
    Size size,
    double scale,
  ) {
    final corners = [
      _project(0, 0, 0, size, scale),
      _project(bedWidth, 0, 0, size, scale),
      _project(bedWidth, bedHeight, 0, size, scale),
      _project(0, bedHeight, 0, size, scale),
    ];

    final workAreaPath = Path()
      ..moveTo(corners[0].dx, corners[0].dy)
      ..lineTo(corners[1].dx, corners[1].dy)
      ..lineTo(corners[2].dx, corners[2].dy)
      ..lineTo(corners[3].dx, corners[3].dy)
      ..close();

    final fillPaint = Paint()
      ..color = HmiColors.accent.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = HmiColors.gold.withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final cornerPaint = Paint()
      ..color = HmiColors.gold
      ..style = PaintingStyle.fill;

    canvas.drawPath(workAreaPath, fillPaint);
    canvas.drawPath(workAreaPath, borderPaint);

    for (final corner in corners) {
      canvas.drawCircle(corner, 3, cornerPaint);
    }
  }

  void _drawProgramPath(
    Canvas canvas,
    Size size,
    double scale,
  ) {
    if (programPoints.isEmpty) {
      return;
    }

    _drawFullProgramPath(canvas, size, scale);
    _drawExecutedPath(canvas, size, scale);
    _drawProgramPoints(canvas, size, scale);
  }

  void _drawFullProgramPath(
    Canvas canvas,
    Size size,
    double scale,
  ) {
    final pathPaint = Paint()
      ..color = HmiColors.gold.withValues(alpha: 0.25)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final path = Path();

    for (int i = 0; i < programPoints.length; i++) {
      final projected = _projectPoint(
        programPoints[i],
        size,
        scale,
      );

      if (i == 0) {
        path.moveTo(projected.dx, projected.dy);
      } else {
        path.lineTo(projected.dx, projected.dy);
      }
    }

    canvas.drawPath(path, pathPaint);
  }

  void _drawExecutedPath(
    Canvas canvas,
    Size size,
    double scale,
  ) {
    if (pathIndex <= 0) {
      return;
    }

    final executedPaint = Paint()
      ..color = HmiColors.ready
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;

    final executedPath = Path();
    final maxIndex = math.min(
      pathIndex,
      programPoints.length - 1,
    );

    for (int i = 0; i <= maxIndex; i++) {
      final projected = _projectPoint(
        programPoints[i],
        size,
        scale,
      );

      if (i == 0) {
        executedPath.moveTo(projected.dx, projected.dy);
      } else {
        executedPath.lineTo(projected.dx, projected.dy);
      }
    }

    canvas.drawPath(executedPath, executedPaint);
  }

  void _drawProgramPoints(
    Canvas canvas,
    Size size,
    double scale,
  ) {
    for (int i = 0; i < programPoints.length; i++) {
      final point = programPoints[i];
      final projected = _projectPoint(point, size, scale);
      final isCurrent = i == pathIndex;
      final colorIndex = point.colorOrder ?? 0;

      final pointColor = colorIndex == 1
          ? HmiColors.sand.withValues(alpha: 0.85)
          : HmiColors.accent;

      final pointPaint = Paint()
        ..color = isCurrent ? HmiColors.alarm : pointColor
        ..style = PaintingStyle.fill;

      canvas.drawCircle(
        projected,
        isCurrent
            ? 4.5
            : colorIndex == 1
                ? 1.2
                : 1.8,
        pointPaint,
      );
    }
  }

  Offset _projectPoint(
    TuftPoint point,
    Size size,
    double scale,
  ) {
    return _project(
      point.x,
      point.y,
      0,
      size,
      scale,
    );
  }

  void _drawGantry(
    Canvas canvas,
    Size size,
    double scale,
  ) {
    final currentY = y.clamp(0.0, bedHeight);

    final left = _project(
      0,
      currentY,
      40,
      size,
      scale,
    );

    final right = _project(
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

    canvas.drawLine(left, right, gantryPaint);
  }

  void _drawCarriage(
    Canvas canvas,
    Size size,
    double scale,
  ) {
    final currentX = x.clamp(0.0, bedWidth);
    final currentY = y.clamp(0.0, bedHeight);

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
  }

  void _drawNeedle(
    Canvas canvas,
    Size size,
    double scale,
  ) {
    final currentX = x.clamp(0.0, bedWidth);
    final currentY = y.clamp(0.0, bedHeight);
    final needleZ = needleDown ? 0.0 : z.clamp(0.0, 25.0);

    final carriage = _project(
      currentX,
      currentY,
      55,
      size,
      scale,
    );

    final needleTip = _project(
      currentX,
      currentY,
      needleZ,
      size,
      scale,
    );

    final needleColor =
        needleDown ? HmiColors.alarm : HmiColors.dro;

    final needlePaint = Paint()
      ..color = needleColor
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
      Paint()..color = needleColor,
    );
  }

  void _drawNeedleShadow(
    Canvas canvas,
    Size size,
    double scale,
  ) {
    final currentX = x.clamp(0.0, bedWidth);
    final currentY = y.clamp(0.0, bedHeight);

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
      Paint()..color = Colors.black.withValues(alpha: 0.28),
    );
  }

  void _drawCenterCrosshair(
    Canvas canvas,
    Size size,
    double scale,
  ) {
    final center = _project(
      bedWidth / 2,
      bedHeight / 2,
      0,
      size,
      scale,
    );

    final crosshairPaint = Paint()
      ..color = HmiColors.textMute.withValues(alpha: 0.35)
      ..strokeWidth = 1;

    canvas.drawLine(
      Offset(center.dx - 8, center.dy),
      Offset(center.dx + 8, center.dy),
      crosshairPaint,
    );

    canvas.drawLine(
      Offset(center.dx, center.dy - 8),
      Offset(center.dx, center.dy + 8),
      crosshairPaint,
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
    final localization = context.watch<LocaleController>().l10n;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          localization.t('errors_title'),
          style: const TextStyle(
            color: HmiColors.gold,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        for (final error in _catalog)
          Card(
            color: HmiColors.panelAlt,
            margin: const EdgeInsets.only(bottom: 8),
            child: ExpansionTile(
              iconColor: HmiColors.gold,
              collapsedIconColor: HmiColors.textDim,
              title: Text(
                '${error.$1}  ${error.$2}',
                style: const TextStyle(
                  color: HmiColors.text,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                error.$3,
                style: const TextStyle(
                  color: HmiColors.textDim,
                  fontSize: 12,
                ),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    16,
                    0,
                    16,
                    14,
                  ),
                  child: Text(
                    error.$4,
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
  final _nameController = TextEditingController();
  final _codeController = TextEditingController(text: 'M8');
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<MachineService>();
    final localization = context.watch<LocaleController>().l10n;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            localization.t('plc_title'),
            style: const TextStyle(
              color: HmiColors.gold,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'M8/M9 = needle engage/retract (embroidery). '
            'Add custom M-codes for your PLC map.',
            style: TextStyle(
              color: HmiColors.textDim,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              itemCount: service.plcMacros.length + 1,
              itemBuilder: (context, index) {
                if (index == service.plcMacros.length) {
                  return _MachineConnectionCard(
                    service: service,
                    localization: localization,
                  );
                }

                final macro = service.plcMacros[index];

                return Card(
                  color: HmiColors.panelAlt,
                  child: ListTile(
                    title: Text(
                      macro.name,
                      style: const TextStyle(
                        color: HmiColors.text,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      '${macro.code}  —  ${macro.note}',
                      style: const TextStyle(
                        color: HmiColors.textDim,
                      ),
                    ),
                    trailing: ElevatedButton(
                      onPressed: () => service.runPlcMacro(macro),
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
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  style: const TextStyle(
                    color: HmiColors.text,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 100,
                child: TextField(
                  controller: _codeController,
                  decoration: const InputDecoration(
                    labelText: 'M / G',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  style: const TextStyle(
                    color: HmiColors.gold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _noteController,
                  decoration: const InputDecoration(
                    labelText: 'Note',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  style: const TextStyle(
                    color: HmiColors.text,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  final name = _nameController.text.trim();
                  final code = _codeController.text.trim();

                  if (name.isEmpty || code.isEmpty) {
                    return;
                  }

                  service.addPlcMacro(
                    PlcMacro(
                      name: name,
                      code: code.toUpperCase(),
                      note: _noteController.text.trim(),
                    ),
                  );

                  _nameController.clear();
                  _noteController.clear();
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

class _MachineConnectionCard extends StatelessWidget {
  final MachineService service;
  final L10n localization;

  const _MachineConnectionCard({
    required this.service,
    required this.localization,
  });

  @override
  Widget build(BuildContext context) {
    final machine = service.activeMachine;

    return Card(
      color: HmiColors.panel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(
          color: HmiColors.accent,
        ),
      ),
      child: ListTile(
        leading: Icon(
          Icons.wifi_tethering,
          color: service.runtimeLinked
              ? HmiColors.ready
              : HmiColors.textDim,
        ),
        title: Text(
          localization.t('connect_to_machine'),
          style: const TextStyle(
            color: HmiColors.text,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          '${machine.name} — ${machine.host}:${machine.port}'
          '${service.runtimeLinked ? '  ·  LINKED' : ''}',
          style: const TextStyle(
            color: HmiColors.textDim,
          ),
        ),
        trailing: ElevatedButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const MachinesScreen(),
              ),
            );
          },
          child: Text(
            localization.t('machines_title'),
          ),
        ),
      ),
    );
  }
}