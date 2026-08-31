import 'dart:math' as math;
import 'dart:typed_data';

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
    final safeSpeed = speed.clamp(10, 200).toInt();

    if (safeSpeed == _lastSpeed) {
      return;
    }

    _lastSpeed = safeSpeed;

    final durationMs =
        (42000 / safeSpeed).round().clamp(100, 1200).toInt();

    _needleController.duration = Duration(
      milliseconds: durationMs,
    );

    if (!_needleController.isAnimating) {
      _needleController.repeat(reverse: true);
    }
  }

  void _showColorChangeDialog(
    BuildContext context,
    MachineService svc,
  ) {
    if (_colorDialogOpen || !svc.colorCompletionPending) {
      return;
    }

    _colorDialogOpen = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        return;
      }

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
                onPressed: () {
                  Navigator.of(dialogContext).pop(false);
                },
                child: const Text('CANCEL'),
              ),
              if (nextGroup != null)
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop(true);
                  },
                  child: const Text('CONTINUE'),
                ),
            ],
          );
        },
      );

      if (!mounted) {
        return;
      }

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

    final points = svc.programPoints;
    final status = svc.status;
    final colorGroups = svc.colorGroups;
    final activeColor = svc.activeColorOrder;
    final gCode = svc.gCode;
    final designImage = svc.designImage;

    _syncNeedleSpeed(status.feedOverride);

    if (svc.colorCompletionPending) {
      _showColorChangeDialog(context, svc);
    }

    return Container(
      color: HmiColors.bg,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (designImage != null && !svc.isDxfDesign)
            _DesignBackground(
              bytes: designImage,
            ),

          CustomPaint(
            painter: _PathPainter(
              points: points,
              colorGroups: colorGroups,
              gCode: gCode,
              headX: status.x,
              headY: status.y,
              headZ: status.z,
              progressIndex: status.pathIndex,
              needleProgress: _needleController.value,
              needleDown: status.needle,
            ),
          ),

          if (points.isEmpty)
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

          if (points.isNotEmpty)
            Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: _ProgramInfo(
                  name: svc.loadedProgramName ??
                      svc.designName ??
                      'PROGRAM',
                  z: status.z,
                  gCodeLoaded: gCode.isNotEmpty,
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

          if (points.isNotEmpty)
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  12,
                  12,
                  12,
                  14,
                ),
                child: _PreviewSpeedControl(
                  speed: status.feedOverride,
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

class _DesignBackground extends StatelessWidget {
  final Uint8List bytes;

  const _DesignBackground({
    required this.bytes,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: Opacity(
          opacity: 0.22,
          child: Image.memory(
            bytes,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            gaplessPlayback: true,
          ),
        ),
      ),
    );
  }
}

class _ProgramInfo extends StatelessWidget {
  final String name;
  final double z;
  final bool gCodeLoaded;

  const _ProgramInfo({
    required this.name,
    required this.z,
    required this.gCodeLoaded,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: HmiColors.panel.withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: HmiColors.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            name,
            style: const TextStyle(
              color: HmiColors.textDim,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 1,
            height: 15,
            color: HmiColors.border,
          ),
          const SizedBox(width: 10),
          Text(
            'Z ${z.toStringAsFixed(2)}',
            style: TextStyle(
              color: z <= 2.5
                  ? HmiColors.accent
                  : HmiColors.textDim,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (gCodeLoaded) ...[
            const SizedBox(width: 10),
            const Icon(
              Icons.route,
              size: 14,
              color: HmiColors.accent,
            ),
          ],
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
      padding: const EdgeInsets.fromLTRB(
        14,
        8,
        14,
        10,
      ),
      decoration: BoxDecoration(
        color: HmiColors.panel.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: HmiColors.border,
        ),
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
                '${speed.clamp(10, 200)}%',
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
                    ? () => onChanged(
                          (value - 10).clamp(10, 200),
                        )
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
                    ? () => onChanged(
                          (value + 10).clamp(10, 200),
                        )
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

  const _ColorDot({
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: HmiColors.border,
        ),
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
    final activeText = activeOrder == null
        ? ''
        : '  ·  now: $activeOrder/${groups.length}';

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
            'Colors: ${groups.length}$activeText',
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

enum _GCodeMotionType {
  rapid,
  linear,
  clockwiseArc,
  counterClockwiseArc,
}

class _GCodeMotion {
  final _GCodeMotionType type;
  final double fromX;
  final double fromY;
  final double toX;
  final double toY;
  final double? i;
  final double? j;
  final double z;
  final int sequence;

  const _GCodeMotion({
    required this.type,
    required this.fromX,
    required this.fromY,
    required this.toX,
    required this.toY,
    required this.z,
    required this.sequence,
    this.i,
    this.j,
  });

  bool get isCutting {
    return type == _GCodeMotionType.linear ||
        type == _GCodeMotionType.clockwiseArc ||
        type == _GCodeMotionType.counterClockwiseArc;
  }
}

class _GCodeParser {
  static final RegExp _commandPattern = RegExp(
    r'\b(G0|G00|G1|G01|G2|G02|G3|G03)\b',
    caseSensitive: false,
  );

  static final RegExp _xPattern = RegExp(
    r'\bX\s*(-?\d+(?:\.\d+)?)',
    caseSensitive: false,
  );

  static final RegExp _yPattern = RegExp(
    r'\bY\s*(-?\d+(?:\.\d+)?)',
    caseSensitive: false,
  );

  static final RegExp _zPattern = RegExp(
    r'\bZ\s*(-?\d+(?:\.\d+)?)',
    caseSensitive: false,
  );

  static final RegExp _iPattern = RegExp(
    r'\bI\s*(-?\d+(?:\.\d+)?)',
    caseSensitive: false,
  );

  static final RegExp _jPattern = RegExp(
    r'\bJ\s*(-?\d+(?:\.\d+)?)',
    caseSensitive: false,
  );

  static List<_GCodeMotion> parse(String source) {
    if (source.trim().isEmpty) {
      return const [];
    }

    final motions = <_GCodeMotion>[];

    double x = 0;
    double y = 0;
    double z = 5;

    _GCodeMotionType? modalType;

    var sequence = 0;

    for (final rawLine in source.split(RegExp(r'\r?\n'))) {
      final withoutComment = rawLine.split(';').first.trim();

      if (withoutComment.isEmpty) {
        continue;
      }

      final commandMatch = _commandPattern.firstMatch(
        withoutComment,
      );

      if (commandMatch != null) {
        final command = commandMatch.group(1)!.toUpperCase();

        switch (command) {
          case 'G0':
          case 'G00':
            modalType = _GCodeMotionType.rapid;
            break;

          case 'G1':
          case 'G01':
            modalType = _GCodeMotionType.linear;
            break;

          case 'G2':
          case 'G02':
            modalType = _GCodeMotionType.clockwiseArc;
            break;

          case 'G3':
          case 'G03':
            modalType = _GCodeMotionType.counterClockwiseArc;
            break;
        }
      }

      final xMatch = _xPattern.firstMatch(withoutComment);
      final yMatch = _yPattern.firstMatch(withoutComment);
      final zMatch = _zPattern.firstMatch(withoutComment);

      final newX = xMatch == null
          ? x
          : double.tryParse(xMatch.group(1)!);

      final newY = yMatch == null
          ? y
          : double.tryParse(yMatch.group(1)!);

      final newZ = zMatch == null
          ? z
          : double.tryParse(zMatch.group(1)!);

      if (newX == null || newY == null || newZ == null) {
        continue;
      }

      final hasXY = xMatch != null || yMatch != null;

      if (!hasXY && zMatch == null) {
        continue;
      }

      final motionType = modalType;

      if (motionType == null) {
        x = newX;
        y = newY;
        z = newZ;
        continue;
      }

      final iMatch = _iPattern.firstMatch(withoutComment);
      final jMatch = _jPattern.firstMatch(withoutComment);

      final i = iMatch == null
          ? null
          : double.tryParse(iMatch.group(1)!);

      final j = jMatch == null
          ? null
          : double.tryParse(jMatch.group(1)!);

      if (newX != x ||
          newY != y ||
          motionType != null) {
        motions.add(
          _GCodeMotion(
            type: motionType,
            fromX: x,
            fromY: y,
            toX: newX,
            toY: newY,
            z: newZ,
            sequence: sequence++,
            i: i,
            j: j,
          ),
        );
      }

      x = newX;
      y = newY;
      z = newZ;
    }

    return motions;
  }
}

class _PathPainter extends CustomPainter {
  final List<TuftPoint> points;
  final List<ColorGroup> colorGroups;
  final String gCode;

  final double headX;
  final double headY;
  final double headZ;

  final int progressIndex;

  final double needleProgress;
  final bool needleDown;

  const _PathPainter({
    required this.points,
    required this.colorGroups,
    required this.gCode,
    required this.headX,
    required this.headY,
    required this.headZ,
    required this.progressIndex,
    required this.needleProgress,
    required this.needleDown,
  });

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    if (points.isEmpty && gCode.trim().isEmpty) {
      _drawGrid(canvas, size);
      return;
    }

    final motions = _GCodeParser.parse(gCode);

    if (motions.isEmpty) {
      _paintPointFallback(
        canvas,
        size,
      );
      return;
    }

    final bounds = _getMotionBounds(motions);

    final map = _createMapper(
      size,
      bounds,
    );

    _drawGrid(
      canvas,
      size,
    );

    _drawGCodePath(
      canvas,
      map,
      motions,
    );

    _drawExecutedGCode(
      canvas,
      map,
      motions,
    );

    _drawGun(
      canvas,
      map,
    );
  }

  void _drawGrid(
    Canvas canvas,
    Size size,
  ) {
    final grid = Paint()
      ..color = HmiColors.border.withValues(alpha: 0.16)
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

  List<double> _getMotionBounds(
    List<_GCodeMotion> motions,
  ) {
    double minX = motions.first.fromX;
    double maxX = motions.first.fromX;
    double minY = motions.first.fromY;
    double maxY = motions.first.fromY;

    void include(
      double x,
      double y,
    ) {
      if (x < minX) {
        minX = x;
      }

      if (x > maxX) {
        maxX = x;
      }

      if (y < minY) {
        minY = y;
      }

      if (y > maxY) {
        maxY = y;
      }
    }

    for (final motion in motions) {
      include(
        motion.fromX,
        motion.fromY,
      );

      include(
        motion.toX,
        motion.toY,
      );

      if (motion.isCutting &&
          (motion.type == _GCodeMotionType.clockwiseArc ||
              motion.type ==
                  _GCodeMotionType.counterClockwiseArc)) {
        final samples = _arcSamples(
          motion,
          sampleCount: 48,
        );

        for (final point in samples) {
          include(
            point.dx,
            point.dy,
          );
        }
      }
    }

    if ((maxX - minX).abs() < 1) {
      maxX = minX + 1;
    }

    if ((maxY - minY).abs() < 1) {
      maxY = minY + 1;
    }

    return [
      minX,
      maxX,
      minY,
      maxY,
    ];
  }

  Offset Function(double, double) _createMapper(
    Size size,
    List<double> bounds,
  ) {
    final minX = bounds[0];
    final maxX = bounds[1];
    final minY = bounds[2];
    final maxY = bounds[3];

    final spanX = math.max(
      1.0,
      maxX - minX,
    );

    final spanY = math.max(
      1.0,
      maxY - minY,
    );

    const pad = 42.0;

    final availableWidth = math.max(
      1.0,
      size.width - pad * 2,
    );

    final availableHeight = math.max(
      1.0,
      size.height - pad * 2,
    );

    final scale = math.min(
      availableWidth / spanX,
      availableHeight / spanY,
    );

    final drawnWidth = spanX * scale;
    final drawnHeight = spanY * scale;
    final offsetX =
        (size.width - drawnWidth) / 2;

    final offsetY =
        (size.height - drawnHeight) / 2;

    return (
      double x,
      double y,
    ) {
      return Offset(
        offsetX + (x - minX) * scale,
        size.height -
            offsetY -
            (y - minY) * scale,
      );
    };
  }

  void _drawGCodePath(
    Canvas canvas,
    Offset Function(double, double) map,
    List<_GCodeMotion> motions,
  ) {
    for (final motion in motions) {
      if (motion.fromX == motion.toX &&
          motion.fromY == motion.toY) {
        continue;
      }

      if (motion.type == _GCodeMotionType.rapid) {
        _drawRapidMove(
          canvas,
          map,
          motion,
        );
        continue;
      }

      final color = _colorForSequence(
        motion.sequence,
      );

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round
        ..color = color.withValues(alpha: 0.28);

      if (motion.type == _GCodeMotionType.linear) {
        canvas.drawLine(
          map(
            motion.fromX,
            motion.fromY,
          ),
          map(
            motion.toX,
            motion.toY,
          ),
          paint,
        );
      } else {
        _drawArc(
          canvas,
          map,
          motion,
          paint,
        );
      }
    }
  }

  void _drawExecutedGCode(
    Canvas canvas,
    Offset Function(double, double) map,
    List<_GCodeMotion> motions,
  ) {
    final cuttingMotions =
        motions.where((motion) => motion.isCutting).toList();

    if (cuttingMotions.isEmpty) {
      return;
    }

    final progress = points.isEmpty
        ? 0.0
        : (progressIndex / points.length)
            .clamp(0.0, 1.0)
            .toDouble();

    final visibleCount =
        (cuttingMotions.length * progress)
            .round()
            .clamp(0, cuttingMotions.length)
            .toInt();

    for (var i = 0; i < visibleCount; i++) {
      final motion = cuttingMotions[i];

      final color = _colorForSequence(
        motion.sequence,
      );

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color;

      if (motion.type == _GCodeMotionType.linear) {
        canvas.drawLine(
          map(
            motion.fromX,
            motion.fromY,
          ),
          map(
            motion.toX,
            motion.toY,
          ),
          paint,
        );
      } else {
        _drawArc(
          canvas,
          map,
          motion,
          paint,
        );
      }
    }

    if (visibleCount > 0 &&
        visibleCount <= cuttingMotions.length) {
      final current =
          cuttingMotions[visibleCount - 1];

      final currentOffset = map(
        current.toX,
        current.toY,
      );

      final markerPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = HmiColors.accent;

      canvas.drawCircle(
        currentOffset,
        4.5,
        markerPaint,
      );
    }
  }

  void _drawRapidMove(
    Canvas canvas,
    Offset Function(double, double) map,
    _GCodeMotion motion,
  ) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = HmiColors.textMute.withValues(alpha: 0.20);

    const dashLength = 5.0;
    const gapLength = 5.0;

    final start = map(
      motion.fromX,
      motion.fromY,
    );

    final end = map(
      motion.toX,
      motion.toY,
    );

    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;

    final distance = math.sqrt(
      dx * dx + dy * dy,
    );

    if (distance <= 0.1) {
      return;
    }

    final ux = dx / distance;
    final uy = dy / distance;

    double position = 0;

    while (position < distance) {
      final segmentStart = position;

      final segmentEnd =
          math.min(
        position + dashLength,
        distance,
      );

      canvas.drawLine(
        Offset(
          start.dx + ux * segmentStart,
          start.dy + uy * segmentStart,
        ),
        Offset(
          start.dx + ux * segmentEnd,
          start.dy + uy * segmentEnd,
        ),
        paint,
      );

      position += dashLength + gapLength;
    }
  }

  void _drawArc(
    Canvas canvas,
    Offset Function(double, double) map,
    _GCodeMotion motion,
    Paint paint,
  ) {
    final samples = _arcSamples(
      motion,
      sampleCount: 64,
    );

    if (samples.length < 2) {
      return;
    }

    final path = Path();

    final first = samples.first;

    final firstMapped = map(
      first.dx,
      first.dy,
    );

    path.moveTo(
      firstMapped.dx,
      firstMapped.dy,
    );

    for (var i = 1; i < samples.length; i++) {
      final point = samples[i];

      final mapped = map(
        point.dx,
        point.dy,
      );

      path.lineTo(
        mapped.dx,
        mapped.dy,
      );
    }

    canvas.drawPath(
      path,
      paint,
    );
  }

  List<Offset> _arcSamples(
    _GCodeMotion motion, {
    required int sampleCount,
  }) {
    if (motion.i == null || motion.j == null) {
      return [
        Offset(
          motion.fromX,
          motion.fromY,
        ),
        Offset(
          motion.toX,
          motion.toY,
        ),
      ];
    }

    final centerX =
        motion.fromX + motion.i!;

    final centerY =
        motion.fromY + motion.j!;

    final startX =
        motion.fromX - centerX;

    final startY =
        motion.fromY - centerY;

    final endX =
        motion.toX - centerX;

    final endY =
        motion.toY - centerY;

    final radius = math.sqrt(
      startX * startX +
          startY * startY,
    );

    if (radius <= 0.0001) {
      return [
        Offset(
          motion.fromX,
          motion.fromY,
        ),
        Offset(
          motion.toX,
          motion.toY,
        ),
      ];
    }

    final startAngle = math.atan2(
      startY,
      startX,
    );

    final endAngle = math.atan2(
      endY,
      endX,
    );

    var delta =
        endAngle - startAngle;

    if (motion.type ==
        _GCodeMotionType.clockwiseArc) {
      while (delta >= 0) {
        delta -= math.pi * 2;
      }
    } else {
      while (delta <= 0) {
        delta += math.pi * 2;
      }
    }

    final steps = math.max(
      12,
      (sampleCount *
              delta.abs() /
              (math.pi * 2))
          .round(),
    );

    final result = <Offset>[];

    for (var i = 0; i <= steps; i++) {
      final t = i / steps;

      final angle =
          startAngle + delta * t;

      result.add(
        Offset(
          centerX +
              math.cos(angle) * radius,
          centerY +
              math.sin(angle) * radius,
        ),
      );
    }

    return result;
  }

  Color _colorForSequence(int sequence) {
  if (points.isEmpty) {
    return HmiColors.accent;
  }

  final index = sequence.clamp(
    0,
    points.length - 1,
  ).toInt();

  return _colorForPoint(points[index]);
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

  return Color(point.colorValue!);
  
}

  void _paintPointFallback(
    Canvas canvas,
    Size size,
  ) {
    _drawGrid(
      canvas,
      size,
    );

    if (points.isEmpty) {
      return;
    }

    final bounds = _getPointBounds();

    final map = _createMapper(
      size,
      bounds,
    );

    final progress =
        (progressIndex / points.length)
            .clamp(0.0, 1.0)
            .toDouble();

    final visibleCount =
        (points.length * progress)
            .round()
            .clamp(0, points.length)
            .toInt();

    for (var i = 1; i < points.length; i++) {
      final a = points[i - 1];
      final b = points[i];

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth =
            i <= visibleCount ? 2.5 : 1.2
        ..strokeCap = StrokeCap.round
        ..color = _colorForPoint(b).withValues(
          alpha: i <= visibleCount
              ? 1.0
              : 0.25,
        );

      canvas.drawLine(
        map(
          a.x,
          a.y,
        ),
        map(
          b.x,
          b.y,
        ),
        paint,
      );
    }

    _drawGun(
      canvas,
      map,
    );
  }

  List<double> _getPointBounds() {
    double minX = points.first.x;
    double maxX = points.first.x;
    double minY = points.first.y;
    double maxY = points.first.y;

    for (final point in points) {
      if (point.x < minX) {
        minX = point.x;
      }

      if (point.x > maxX) {
        maxX = point.x;
      }

      if (point.y < minY) {
        minY = point.y;
      }

      if (point.y > maxY) {
        maxY = point.y;
      }
    }

    return [
      minX,
      maxX,
      minY,
      maxY,
    ];
  }

  void _drawGun(
    Canvas canvas,
    Offset Function(double, double) map,
  ) {
    final head = map(
      headX,
      headY,
    );

    final movement = needleDown
        ? math.sin(
              needleProgress * math.pi,
            ) *
            14.0
        : 0.0;

    canvas.save();

    canvas.translate(
      head.dx,
      head.dy - movement,
    );

    canvas.scale(
      0.65,
    );

    const gunSize = Size(
      80,
      70,
    );

    const gunPainter =
        _TuftingGunPainter();

    gunPainter.paint(
      canvas,
      gunSize,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(
    covariant _PathPainter oldDelegate,
  ) {
    return oldDelegate.points != points ||
        oldDelegate.colorGroups != colorGroups ||
        oldDelegate.gCode != gCode ||
        oldDelegate.headX != headX ||
        oldDelegate.headY != headY ||
        oldDelegate.headZ != headZ ||
        oldDelegate.progressIndex != progressIndex ||
        oldDelegate.needleProgress !=
            needleProgress ||
        oldDelegate.needleDown != needleDown;
  }
}

class _TuftingGunPainter extends CustomPainter {
  const _TuftingGunPainter();

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    final scale = size.width / 80.0;

    canvas.scale(
      scale,
      scale,
    );

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
        const Rect.fromLTWH(
          15,
          12,
          42,
          25,
        ),
        const Radius.circular(5),
      ),
      bodyPaint,
    );

    canvas.drawRect(
      const Rect.fromLTWH(
        54,
        17,
        13,
        14,
      ),
      metalPaint,
    );

    canvas.drawRect(
      const Rect.fromLTWH(
        65,
        22,
        10,
        3,
      ),
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
        const Rect.fromLTWH(
          27,
          6,
          20,
          8,
        ),
        const Radius.circular(3),
      ),
      metalPaint,
    );
  }

  @override
  bool shouldRepaint(
    covariant _TuftingGunPainter oldDelegate,
  ) {
    return false;
  }
}