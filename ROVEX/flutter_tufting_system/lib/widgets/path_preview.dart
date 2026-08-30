import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/design.dart';
import '../services/machine_service.dart';
import '../theme/hmi_colors.dart';

class PathPreview extends StatefulWidget {
  const PathPreview({super.key});

  @override
  State<PathPreview> createState() => _PathPreviewState();
}

class _PathPreviewState extends State<PathPreview>
    with SingleTickerProviderStateMixin {
  late final AnimationController _needleController;
  bool _colorDialogOpen = false;
  int _lastSpeed = -1;

  @override
  void initState() {
    super.initState();
    _needleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _needleController.dispose();
    super.dispose();
  }

  void _syncNeedleSpeed(int speed) {
    final safeSpeed = speed.clamp(10, 200);
    if (safeSpeed == _lastSpeed) return;

    _lastSpeed = safeSpeed;
    _needleController.duration = Duration(
      milliseconds: (42000 / safeSpeed).round().clamp(100, 1200),
    );

    if (!_needleController.isAnimating) {
      _needleController.repeat(reverse: true);
    }
  }

  void _showColorChangeDialog(
    BuildContext context,
    MachineService svc,
  ) {
    if (_colorDialogOpen || !svc.colorCompletionPending) return;

    _colorDialogOpen = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      final completedGroup = svc.completedColorGroup;
      final nextGroup = svc.nextColorGroup;
      final completedName = svc.completedColorName;
      final nextName = svc.nextColorName;

      final result = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            backgroundColor: HmiColors.panel,
            title: const Text(
              'COLOR CHANGE',
              style: TextStyle(
                color: HmiColors.accent,
                fontWeight: FontWeight.w700,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _ColorDot(
                      color: completedGroup == null
                          ? HmiColors.accent
                          : Color(completedGroup.colorValue),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '$completedName completed',
                        style: const TextStyle(
                          color: HmiColors.textDim,
                        ),
                      ),
                    ),
                  ],
                ),
                if (nextGroup != null) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _ColorDot(
                        color: Color(nextGroup.colorValue),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Next: $nextName',
                          style: const TextStyle(
                            color: HmiColors.text,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Change the thread before continuing.',
                    style: TextStyle(
                      color: HmiColors.textMute,
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('CANCEL'),
              ),
              if (nextGroup != null)
                ElevatedButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('CONTINUE'),
                ),
            ],
          );
        },
      );

      if (!mounted) return;

      _colorDialogOpen = false;

      if (result == true) {
        await svc.continueNextColor();
      } else if (result == false) {
        await svc.cancelColorRun();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<MachineService>();
    final pts = svc.programPoints;
    final s = svc.status;
    final colorGroups = svc.colorGroups;
    final activeColor = svc.activeColorOrder;

    _syncNeedleSpeed(s.feedOverride);

    if (svc.colorCompletionPending) {
      _showColorChangeDialog(context, svc);
    }

    return Container(
      color: HmiColors.bg,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(
            painter: _PathPainter(
              points: pts,
              colorGroups: colorGroups,
              headX: s.x,
              headY: s.y,
              progressIndex: s.pathIndex,
              needleProgress: _needleController.value,
              needleDown: s.needle,
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
                  svc.loadedProgramName ?? svc.designName ?? 'PROGRAM',
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
          if (pts.isNotEmpty)
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
                child: _PreviewSpeedControl(
                  speed: s.feedOverride,
                  enabled: !svc.runtimeLinked,
                  onChanged: (value) {
                    svc.setFeedOverride(value.round());
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PreviewSpeedControl extends StatelessWidget {
  final int speed;
  final bool enabled;
  final ValueChanged<double> onChanged;

  const _PreviewSpeedControl({
    required this.speed,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final value = speed.clamp(10, 200).toDouble();

    return Container(
      width: 360,
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
      decoration: BoxDecoration(
        color: HmiColors.panel.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: HmiColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(
                Icons.speed,
                size: 16,
                color: HmiColors.accent,
              ),
              const SizedBox(width: 7),
              const Expanded(
                child: Text(
                  'PREVIEW SPEED',
                  style: TextStyle(
                    color: HmiColors.textDim,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '$speed%',
                style: const TextStyle(
                  color: HmiColors.text,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: enabled
                    ? () => onChanged((value - 10).clamp(10, 200))
                    : null,
                icon: const Icon(Icons.remove),
                color: HmiColors.textDim,
              ),
              Expanded(
                child: Slider(
                  value: value,
                  min: 10,
                  max: 200,
                  divisions: 19,
                  onChanged: enabled ? onChanged : null,
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: enabled
                    ? () => onChanged((value + 10).clamp(10, 200))
                    : null,
                icon: const Icon(Icons.add),
                color: HmiColors.textDim,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  final Color color;

  const _ColorDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: HmiColors.border),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: HmiColors.panel.withValues(alpha: 0.92),
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
                    color: isActive ? HmiColors.accent : HmiColors.border,
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
  final List<ColorGroup> colorGroups;
  final double headX;
  final double headY;
  final int progressIndex;
  final double needleProgress;
  final bool needleDown;

  const _PathPainter({
    required this.points,
    required this.colorGroups,
    required this.headX,
    required this.headY,
    required this.progressIndex,
    required this.needleProgress,
    required this.needleDown,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawGrid(canvas, size);

    if (points.isEmpty) return;

    final bounds = _getBounds();
    final minX = bounds[0];
    final maxX = bounds[1];
    final minY = bounds[2];
    final maxY = bounds[3];
    final spanX = (maxX - minX).abs() < 1 ? 1.0 : maxX - minX;
    final spanY = (maxY - minY).abs() < 1 ? 1.0 : maxY - minY;
    const pad = 40.0;

    Offset map(double x, double y) {
      final nx = pad + ((x - minX) / spanX) * (size.width - pad * 2);
      final ny = size.height -
          pad -
          ((y - minY) / spanY) * (size.height - pad * 2);
      return Offset(nx, ny);
    }

    _drawUnexecutedPath(canvas, map, progressIndex);
    _drawStitches(canvas, map, progressIndex);
    _drawGun(canvas, map);
  }

  void _drawGrid(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = HmiColors.border.withValues(alpha: 0.35)
      ..strokeWidth = 1;

    for (double x = 0; x < size.width; x += 40) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }

    for (double y = 0; y < size.height; y += 40) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
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

  Color _colorForPoint(TuftPoint point) {
    final order = point.colorOrder;

    if (order != null) {
      for (final group in colorGroups) {
        if (group.order == order) {
          return Color(group.colorValue);
        }
      }
    }

    if (point.colorValue != null) {
      return Color(point.colorValue!);
    }

    return HmiColors.accent;
  }

  void _drawUnexecutedPath(
    Canvas canvas,
    Offset Function(double, double) map,
    int progressIndex,
  ) {
    final paint = Paint()..style = PaintingStyle.fill;
    final start = progressIndex.clamp(0, points.length);

    for (int i = start; i < points.length; i++) {
      final point = points[i];
      paint.color = _colorForPoint(point).withValues(alpha: 0.24);
      canvas.drawCircle(
        map(point.x, point.y),
        2.4,
        paint,
      );
    }
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
      paint.color = _colorForPoint(point);

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
    final movement = needleDown
        ? math.sin(needleProgress * math.pi) * 12
        : 0.0;

    canvas.save();
    canvas.translate(head.dx, head.dy - movement);
    canvas.scale(0.65);

    const gunSize = Size(80, 70);
    const gunPainter = _TuftingGunPainter();
    gunPainter.paint(canvas, gunSize);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PathPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.headX != headX ||
        oldDelegate.headY != headY ||
        oldDelegate.progressIndex != progressIndex ||
        oldDelegate.needleProgress != needleProgress ||
        oldDelegate.needleDown != needleDown;
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

    canvas.drawPath(handle, bodyPaint);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(27, 6, 20, 8),
        const Radius.circular(3),
      ),
      metalPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _TuftingGunPainter oldDelegate) => false;
}
