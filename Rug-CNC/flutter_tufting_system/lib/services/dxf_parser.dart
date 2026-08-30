import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import '../models/design.dart';

/// Converts an ASCII DXF drawing into the ordered tufting path used by ROVEX.
///
/// Supported entities:
/// - LINE
/// - CIRCLE
/// - ARC
/// - LWPOLYLINE, including bulge arcs
/// - POLYLINE, including vertex bulge arcs
///
/// DXF layers are kept as separate color/thread groups and their first
/// appearance in the file determines the processing order.
class DxfExtractor {
  static const int _maxTotalPoints = 6000;
  static const double _arcSegmentDegrees = 6.0;
  static const double _epsilon = 1e-9;

  static ExtractResult extractFromBytes(
    Uint8List bytes, {
    double workWidthMm = 600,
    double workHeightMm = 400,
  }) {
    final text = _decode(bytes);
    return extractFromString(
      text,
      workWidthMm: workWidthMm,
      workHeightMm: workHeightMm,
    );
  }

  static ExtractResult extractFromString(
    String text, {
    double workWidthMm = 600,
    double workHeightMm = 400,
  }) {
    if (text.trim().isEmpty) {
      return const ExtractResult(points: [], colors: []);
    }

    final tokens = _DxfTokenizer.tokenize(text);
    final entities = _DxfEntityReader(tokens).read();
    if (entities.isEmpty) {
      return const ExtractResult(points: [], colors: []);
    }

    final layerGroups = _groupByLayer(entities);
    final bounds = _Bounds.fromEntities(entities);
    if (bounds == null) {
      return const ExtractResult(points: [], colors: []);
    }

    final transform = _CoordinateTransform(
      bounds: bounds,
      workWidthMm: workWidthMm,
      workHeightMm: workHeightMm,
    );
    final stride = _samplingStride(entities);

    final points = <TuftPoint>[];
    final colors = <ColorGroup>[];
    var colorOrder = 0;

    for (final group in layerGroups) {
      if (group.polylines.isEmpty) continue;

      colorOrder++;
      final color = _colorFor(colorOrder - 1, group.colorIndex);
      final orderedPolylines = _chainNearest(group.polylines);
      final startCount = points.length;

      for (final polyline in orderedPolylines) {
        _appendPolyline(
          points,
          polyline,
          transform,
          color,
          colorOrder,
          stride,
        );
      }

      final pointCount = points.length - startCount;
      if (pointCount == 0) {
        colorOrder--;
        continue;
      }

      colors.add(
        ColorGroup(
          colorValue: color,
          order: colorOrder,
          pointCount: pointCount,
        ),
      );
    }

    return ExtractResult(points: points, colors: colors);
  }

  static String _decode(Uint8List bytes) {
    try {
      return utf8.decode(bytes, allowMalformed: true);
    } catch (_) {
      return latin1.decode(bytes);
    }
  }

  static Map<String, _LayerGroup> _groupByLayer(
    List<_DxfEntity> entities,
  ) {
    final groups = <String, _LayerGroup>{};

    for (final entity in entities) {
      if (entity.points.length < 2) continue;

      final group = groups.putIfAbsent(
        entity.layer,
        () => _LayerGroup(
          layer: entity.layer,
          colorIndex: entity.colorIndex,
        ),
      );

      group.polylines.add(entity.points);
    }

    return groups;
  }

  static int _samplingStride(List<_DxfEntity> entities) {
    final rawPointCount = entities.fold<int>(
      0,
      (total, entity) => total + entity.points.length,
    );

    if (rawPointCount <= _maxTotalPoints) return 1;
    return math.max(1, (rawPointCount / _maxTotalPoints).ceil());
  }

  static void _appendPolyline(
    List<TuftPoint> output,
    List<List<double>> polyline,
    _CoordinateTransform transform,
    int color,
    int colorOrder,
    int stride,
  ) {
    if (polyline.length < 2) return;

    for (var i = 0; i < polyline.length; i += stride) {
      final point = transform.toMillimeters(polyline[i]);
      output.add(
        TuftPoint(
          x: point.x,
          y: point.y,
          colorValue: color,
          colorOrder: colorOrder,
        ),
      );
    }

    // Always preserve the geometric end point of each entity.
    final last = transform.toMillimeters(polyline.last);
    final previous = output.isEmpty ? null : output.last;
    if (previous == null ||
        (previous.x - last.x).abs() > _epsilon ||
        (previous.y - last.y).abs() > _epsilon) {
      output.add(
        TuftPoint(
          x: last.x,
          y: last.y,
          colorValue: color,
          colorOrder: colorOrder,
        ),
      );
    }
  }

  static List<List<List<double>>> _chainNearest(
    List<List<List<double>>> polylines,
  ) {
    if (polylines.length < 2) {
      return List<List<List<double>>>.from(polylines);
    }

    final remaining = List<List<List<double>>>.from(polylines);
    final ordered = <List<List<double>>>[];

    var current = remaining.removeAt(0);
    ordered.add(current);

    var cursorX = current.last[0];
    var cursorY = current.last[1];

    while (remaining.isNotEmpty) {
      var bestIndex = 0;
      var bestDistance = double.infinity;
      var reverse = false;

      for (var i = 0; i < remaining.length; i++) {
        final candidate = remaining[i];
        final startDistance = _distance(
          cursorX,
          cursorY,
          candidate.first[0],
          candidate.first[1],
        );
        final endDistance = _distance(
          cursorX,
          cursorY,
          candidate.last[0],
          candidate.last[1],
        );

        if (startDistance < bestDistance) {
          bestDistance = startDistance;
          bestIndex = i;
          reverse = false;
        }

        if (endDistance < bestDistance) {
          bestDistance = endDistance;
          bestIndex = i;
          reverse = true;
        }
      }

      current = remaining.removeAt(bestIndex);
      if (reverse) {
        current = current.reversed.toList();
      }

      ordered.add(current);
      cursorX = current.last[0];
      cursorY = current.last[1];
    }

    return ordered;
  }

  static double _distance(
    double x1,
    double y1,
    double x2,
    double y2,
  ) {
    final dx = x2 - x1;
    final dy = y2 - y1;
    return math.sqrt(dx * dx + dy * dy);
  }

  static int _colorFor(int index, int? aci) {
    final aciColor = _aciPalette[aci];
    if (aciColor != null) {
      return 0xFF000000 | aciColor;
    }

    final hue = (index * 47) % 360;
    return 0xFF000000 | _hsvToRgb(hue.toDouble(), 0.65, 0.85);
  }

  static int _hsvToRgb(double hue, double saturation, double value) {
    final chroma = value * saturation;
    final huePart = hue / 60.0;
    final x = chroma * (1 - ((huePart % 2) - 1).abs());
    final match = value - chroma;

    double red = 0;
    double green = 0;
    double blue = 0;

    if (hue < 60) {
      red = chroma;
      green = x;
    } else if (hue < 120) {
      red = x;
      green = chroma;
    } else if (hue < 180) {
      green = chroma;
      blue = x;
    } else if (hue < 240) {
      green = x;
      blue = chroma;
    } else if (hue < 300) {
      red = x;
      blue = chroma;
    } else {
      red = chroma;
      blue = x;
    }

    final r = ((red + match) * 255).round().clamp(0, 255);
    final g = ((green + match) * 255).round().clamp(0, 255);
    final b = ((blue + match) * 255).round().clamp(0, 255);

    return (r << 16) | (g << 8) | b;
  }

  static const Map<int, int> _aciPalette = {
    1: 0xFF0000,
    2: 0xFFFF00,
    3: 0x00FF00,
    4: 0x00FFFF,
    5: 0x0000FF,
    6: 0xFF00FF,
    7: 0xFFFFFF,
    8: 0x808080,
    9: 0xC0C0C0,
  };
}

class _DxfTokenizer {
  static List<MapEntry<int, String>> tokenize(String text) {
    final lines = text.split(RegExp(r'\r\n|\r|\n'));
    final tokens = <MapEntry<int, String>>[];

    for (var i = 0; i + 1 < lines.length; i += 2) {
      final code = int.tryParse(lines[i].trim());
      if (code == null) continue;
      tokens.add(MapEntry(code, lines[i + 1].trim()));
    }

    return tokens;
  }
}

class _DxfEntityReader {
  _DxfEntityReader(this.tokens);

  final List<MapEntry<int, String>> tokens;

  List<_DxfEntity> read() {
    final range = _findEntitiesRange();
    final entities = <_DxfEntity>[];
    var index = range.start;

    while (index < range.end) {
      if (tokens[index].key != 0) {
        index++;
        continue;
      }

      final type = tokens[index].value.toUpperCase();
      index++;

      final blockStart = index;
      while (index < range.end && tokens[index].key != 0) {
        index++;
      }

      final block = tokens.sublist(blockStart, index);

      switch (type) {
        case 'LINE':
          _addLine(entities, block);
          break;
        case 'CIRCLE':
          _addCircle(entities, block);
          break;
        case 'ARC':
          _addArc(entities, block);
          break;
        case 'LWPOLYLINE':
          _addEntity(entities, _readLwPolyline(block));
          break;
        case 'POLYLINE':
          index = _readPolyline(entities, block, index, range.end);
          break;
      }
    }

    return entities;
  }

  _TokenRange _findEntitiesRange() {
    var start = 0;
    var end = tokens.length;

    for (var i = 0; i < tokens.length; i++) {
      if (tokens[i].key == 2 && tokens[i].value.toUpperCase() == 'ENTITIES') {
        start = i + 1;
        break;
      }
    }

    for (var i = start; i < tokens.length; i++) {
      if (tokens[i].key == 0 && tokens[i].value.toUpperCase() == 'ENDSEC') {
        end = i;
        break;
      }
    }

    return _TokenRange(start, end);
  }

  void _addLine(List<_DxfEntity> entities, List<MapEntry<int, String>> block) {
    final x1 = _number(block, 10) ?? 0;
    final y1 = _number(block, 20) ?? 0;
    final x2 = _number(block, 11) ?? 0;
    final y2 = _number(block, 21) ?? 0;

    _addEntity(
      entities,
      _DxfEntity(
        layer: _layer(block),
        colorIndex: _colorIndex(block),
        points: [
          [x1, y1],
          [x2, y2],
        ],
      ),
    );
  }

  void _addCircle(List<_DxfEntity> entities, List<MapEntry<int, String>> block) {
    final centerX = _number(block, 10) ?? 0;
    final centerY = _number(block, 20) ?? 0;
    final radius = _number(block, 40) ?? 0;
    if (radius <= 0) return;

    final steps = math.max(
      12,
      (360.0 / DxfExtractor._arcSegmentDegrees).round(),
    );
    final points = <List<double>>[];

    for (var i = 0; i <= steps; i++) {
      final angle = 2 * math.pi * i / steps;
      points.add([
        centerX + radius * math.cos(angle),
        centerY + radius * math.sin(angle),
      ]);
    }

    _addEntity(
      entities,
      _DxfEntity(
        layer: _layer(block),
        colorIndex: _colorIndex(block),
        points: points,
      ),
    );
  }

  void _addArc(List<_DxfEntity> entities, List<MapEntry<int, String>> block) {
    final centerX = _number(block, 10) ?? 0;
    final centerY = _number(block, 20) ?? 0;
    final radius = _number(block, 40) ?? 0;
    if (radius <= 0) return;

    final start = (_number(block, 50) ?? 0) * math.pi / 180;
    var end = (_number(block, 51) ?? 0) * math.pi / 180;
    if (end < start) end += 2 * math.pi;

    final sweep = end - start;
    final steps = math.max(
      2,
      (sweep.abs() * 180 / math.pi / DxfExtractor._arcSegmentDegrees).round(),
    );
    final points = <List<double>>[];

    for (var i = 0; i <= steps; i++) {
      final angle = start + sweep * i / steps;
      points.add([
        centerX + radius * math.cos(angle),
        centerY + radius * math.sin(angle),
      ]);
    }

    _addEntity(
      entities,
      _DxfEntity(
        layer: _layer(block),
        colorIndex: _colorIndex(block),
        points: points,
      ),
    );
  }

  _DxfEntity _readLwPolyline(List<MapEntry<int, String>> block) {
    final vertices = <_PolylineVertex>[];
    double? currentX;
    double? currentY;
    var currentBulge = 0.0;
    var closed = false;

    for (final token in block) {
      switch (token.key) {
        case 70:
          closed = (int.tryParse(token.value) ?? 0) & 1 != 0;
          break;
        case 10:
          if (currentX != null && currentY != null) {
            vertices.add(_PolylineVertex(currentX, currentY, currentBulge));
          }
          currentX = double.tryParse(token.value);
          currentBulge = 0;
          break;
        case 20:
          currentY = double.tryParse(token.value);
          break;
        case 42:
          currentBulge = double.tryParse(token.value) ?? 0;
          break;
      }
    }

    if (currentX != null && currentY != null) {
      vertices.add(_PolylineVertex(currentX, currentY, currentBulge));
    }

    return _verticesToEntity(
      layer: _layer(block),
      colorIndex: _colorIndex(block),
      vertices: vertices,
      closed: closed,
    );
  }

  int _readPolyline(
    List<_DxfEntity> entities,
    List<MapEntry<int, String>> block,
    int index,
    int end,
  ) {
    final vertices = <_PolylineVertex>[];

    while (index < end) {
      final token = tokens[index];
      if (token.key != 0) {
        index++;
        continue;
      }

      final type = token.value.toUpperCase();
      if (type == 'VERTEX') {
        index++;
        final vertexStart = index;
        while (index < end && tokens[index].key != 0) {
          index++;
        }
        final vertexBlock = tokens.sublist(vertexStart, index);
        final x = _number(vertexBlock, 10);
        final y = _number(vertexBlock, 20);
        if (x != null && y != null) {
          vertices.add(_PolylineVertex(x, y, _number(vertexBlock, 42) ?? 0));
        }
        continue;
      }

      if (type == 'SEQEND') {
        index++;
        break;
      }

      break;
    }

    if (vertices.length >= 2) {
      _addEntity(
        entities,
        _verticesToEntity(
          layer: _layer(block),
          colorIndex: _colorIndex(block),
          vertices: vertices,
          closed: false,
        ),
      );
    }

    return index;
  }

  _DxfEntity _verticesToEntity({
    required String layer,
    required int? colorIndex,
    required List<_PolylineVertex> vertices,
    required bool closed,
  }) {
    if (vertices.length < 2) {
      return _DxfEntity(layer: layer, colorIndex: colorIndex, points: const []);
    }

    final points = <List<double>>[
      [vertices.first.x, vertices.first.y],
    ];

    final segmentCount = closed ? vertices.length : vertices.length - 1;
    for (var i = 0; i < segmentCount; i++) {
      final start = vertices[i];
      final end = vertices[(i + 1) % vertices.length];

      if (start.bulge.abs() < DxfExtractor._epsilon) {
        points.add([end.x, end.y]);
      } else {
        points.addAll(
          _bulgeArcPoints(
            start.x,
            start.y,
            end.x,
            end.y,
            start.bulge,
          ),
        );
      }
    }

    return _DxfEntity(layer: layer, colorIndex: colorIndex, points: points);
  }

  List<List<double>> _bulgeArcPoints(
    double x1,
    double y1,
    double x2,
    double y2,
    double bulge,
  ) {
    final theta = 4 * math.atan(bulge);
    final dx = x2 - x1;
    final dy = y2 - y1;
    final chord = math.sqrt(dx * dx + dy * dy);

    if (chord < DxfExtractor._epsilon || bulge.abs() < DxfExtractor._epsilon) {
      return [
        [x2, y2],
      ];
    }

    final sinHalfTheta = math.sin(theta / 2).abs();
    if (sinHalfTheta < DxfExtractor._epsilon) {
      return [
        [x2, y2],
      ];
    }

    final radius = chord / (2 * sinHalfTheta);
    final offset = math.sqrt(
      math.max(0, radius * radius - (chord / 2) * (chord / 2)),
    );
    final midX = (x1 + x2) / 2;
    final midY = (y1 + y2) / 2;
    final unitPerpX = -dy / chord;
    final unitPerpY = dx / chord;
    final side = bulge >= 0 ? 1.0 : -1.0;

    final centerX = midX + unitPerpX * offset * side;
    final centerY = midY + unitPerpY * offset * side;
    final startAngle = math.atan2(y1 - centerY, x1 - centerX);
    final endAngle = startAngle + theta;
    final steps = math.max(
      2,
      (theta.abs() * 180 / math.pi / DxfExtractor._arcSegmentDegrees).round(),
    );

    final points = <List<double>>[];
    for (var i = 1; i <= steps; i++) {
      final angle = startAngle + theta * i / steps;
      points.add([
        centerX + radius * math.cos(angle),
        centerY + radius * math.sin(angle),
      ]);
    }

    return points;
  }

  static void _addEntity(List<_DxfEntity> entities, _DxfEntity entity) {
    if (entity.points.length >= 2) entities.add(entity);
  }

  static String _layer(List<MapEntry<int, String>> block) {
    for (final token in block) {
      if (token.key == 8 && token.value.isNotEmpty) return token.value;
    }
    return '0';
  }

  static int? _colorIndex(List<MapEntry<int, String>> block) {
    for (final token in block) {
      if (token.key == 62) return int.tryParse(token.value);
    }
    return null;
  }

  static double? _number(List<MapEntry<int, String>> block, int code) {
    for (final token in block) {
      if (token.key == code) return double.tryParse(token.value);
    }
    return null;
  }
}

class _CoordinateTransform {
  _CoordinateTransform({
    required _Bounds bounds,
    required double workWidthMm,
    required double workHeightMm,
  })  : _scale = math.min(
          workWidthMm / bounds.width,
          workHeightMm / bounds.height,
        ),
        _offsetX = (workWidthMm - bounds.width *
                    math.min(workWidthMm / bounds.width, workHeightMm / bounds.height)) /
            2,
        _offsetY = (workHeightMm - bounds.height *
                    math.min(workWidthMm / bounds.width, workHeightMm / bounds.height)) /
            2,
        _minX = bounds.minX,
        _minY = bounds.minY;

  final double _scale;
  final double _offsetX;
  final double _offsetY;
  final double _minX;
  final double _minY;

  _Point toMillimeters(List<double> point) {
    return _Point(
      (point[0] - _minX) * _scale + _offsetX,
      (point[1] - _minY) * _scale + _offsetY,
    );
  }
}

class _Bounds {
  _Bounds({
    required this.minX,
    required this.minY,
    required this.maxX,
    required this.maxY,
  });

  final double minX;
  final double minY;
  final double maxX;
  final double maxY;

  double get width => math.max(DxfExtractor._epsilon, maxX - minX);
  double get height => math.max(DxfExtractor._epsilon, maxY - minY);

  static _Bounds? fromEntities(List<_DxfEntity> entities) {
    var minX = double.infinity;
    var minY = double.infinity;
    var maxX = -double.infinity;
    var maxY = -double.infinity;

    for (final entity in entities) {
      for (final point in entity.points) {
        minX = math.min(minX, point[0]);
        minY = math.min(minY, point[1]);
        maxX = math.max(maxX, point[0]);
        maxY = math.max(maxY, point[1]);
      }
    }

    if (!minX.isFinite || !minY.isFinite || !maxX.isFinite || !maxY.isFinite) {
      return null;
    }

    return _Bounds(
      minX: minX,
      minY: minY,
      maxX: maxX,
      maxY: maxY,
    );
  }
}

class _LayerGroup {
  _LayerGroup({required this.layer, required this.colorIndex});

  final String layer;
  final int? colorIndex;
  final List<List<List<double>>> polylines = [];
}

class _DxfEntity {
  _DxfEntity({
    required this.layer,
    required this.colorIndex,
    required this.points,
  });

  final String layer;
  final int? colorIndex;
  final List<List<double>> points;
}

class _PolylineVertex {
  const _PolylineVertex(this.x, this.y, this.bulge);

  final double x;
  final double y;
  final double bulge;
}

class _Point {
  const _Point(this.x, this.y);

  final double x;
  final double y;
}

class _TokenRange {
  const _TokenRange(this.start, this.end);

  final int start;
  final int end;
}

/// Global top-level function used by [MachineService] isolates.
ExtractResult extractPathFromDxfBytes(
  Uint8List bytes, {
  double workWidthMm = 600,
  double workHeightMm = 400,
}) {
  return DxfExtractor.extractFromBytes(
    bytes,
    workWidthMm: workWidthMm,
    workHeightMm: workHeightMm,
  );
}

/// Alias kept for compatibility with existing [MachineService] code.
ExtractResult parseDxfEntities(
  Uint8List bytes, {
  double workWidthMm = 600,
  double workHeightMm = 400,
}) {
  return extractPathFromDxfBytes(
    bytes,
    workWidthMm: workWidthMm,
    workHeightMm: workHeightMm,
  );
}
