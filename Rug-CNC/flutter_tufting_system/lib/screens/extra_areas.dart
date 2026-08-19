import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.t('needle3d_title'),
              style: const TextStyle(
                  color: HmiColors.gold,
                  fontSize: 18,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
            'X ${s.x.toStringAsFixed(2)}  Y ${s.y.toStringAsFixed(2)}  Z ${s.z.toStringAsFixed(2)} mm  ·  Needle ${s.needle ? "DOWN" : "UP"}',
            style: const TextStyle(color: HmiColors.textDim),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: HmiColors.panelAlt,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: HmiColors.gold.withValues(alpha: 0.35)),
              ),
              child: CustomPaint(
                painter: _Machine3dPainter(
                  x: s.x,
                  y: s.y,
                  z: s.z,
                  needleDown: s.needle,
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

class _Machine3dPainter extends CustomPainter {
  final double x, y, z;
  final bool needleDown;

  _Machine3dPainter({
    required this.x,
    required this.y,
    required this.z,
    required this.needleDown,
  });

  Offset iso(double X, double Y, double Z, Size size) {
    // Simple isometric projection into view
    final sx = (X - Y) * 0.55;
    final sy = (X + Y) * 0.28 - Z * 0.7;
    return Offset(size.width * 0.5 + sx, size.height * 0.62 + sy);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final frame = Paint()
      ..color = HmiColors.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final bed = Paint()..color = HmiColors.accent.withValues(alpha: 0.15);
    final gold = Paint()
      ..color = HmiColors.gold
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final head = Paint()..color = HmiColors.sand;
    final needle = Paint()
      ..color = needleDown ? HmiColors.alarm : HmiColors.dro
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    // Bed rectangle in machine mm mapped to isometric
    const W = 600.0, H = 400.0;
    final b0 = iso(0, 0, 0, size);
    final b1 = iso(W, 0, 0, size);
    final b2 = iso(W, H, 0, size);
    final b3 = iso(0, H, 0, size);
    final bedPath = Path()
      ..moveTo(b0.dx, b0.dy)
      ..lineTo(b1.dx, b1.dy)
      ..lineTo(b2.dx, b2.dy)
      ..lineTo(b3.dx, b3.dy)
      ..close();
    canvas.drawPath(bedPath, bed);
    canvas.drawPath(bedPath, frame);

    // Gantry beam along X at current Y
    final gL = iso(0, y.clamp(0.0, H), 40, size);
    final gR = iso(W, y.clamp(0.0, H), 40, size);
    canvas.drawLine(gL, gR, gold);

    // Carriage at X,Y
    final cx = x.clamp(0.0, W);
    final cy = y.clamp(0.0, H);
    final top = iso(cx, cy, 55, size);
    final tipZ = needleDown ? 0.0 : z.clamp(0.0, 25.0);
    final tip = iso(cx, cy, tipZ, size);

    canvas.drawCircle(top, 8, head);
    canvas.drawLine(top, tip, needle);
    canvas.drawCircle(tip, 3, Paint()..color = HmiColors.alarm);

    // Shadow on bed
    final shadow = iso(cx, cy, 0, size);
    canvas.drawCircle(
        shadow, 6, Paint()..color = Colors.black.withValues(alpha: 0.25));
  }

  @override
  bool shouldRepaint(covariant _Machine3dPainter old) =>
      old.x != x || old.y != y || old.z != z || old.needleDown != needleDown;
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
