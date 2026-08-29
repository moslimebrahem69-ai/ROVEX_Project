import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import '../models/design.dart';

/// Parses an ASCII DXF file straight into an exact stitch path — no
/// pixel tracing involved, so every line is exactly where the drawing
/// says it is and every arc/circle comes out as a true curve.
///
/// Each DXF **layer** becomes one "thread color" group, in the order
/// the layers first appear in the file — this is how a lot of CNC/
/// embroidery workflows already organize colors when they draw in
/// AutoCAD/LibreCAD (one layer per thread), so it lines up naturally
/// with the "finish one color, then move to the next" behavior the
/// image importer already has.
class DxfExtractor {
  static const int _maxTotalPoints = 6000;
  static const double _arcSegmentDeg = 6; // curve smoothness for arcs/circles

  static ExtractResult extractFromBytes(
    Uint8List bytes, {
    double workWidthMm = 600,
    double workHeightMm = 400,
  }) {
    late String text;
    try {
      text = utf8.decode(bytes, allowMalformed: true);
    } catch (_) {
      text = latin1.decode(bytes);
    }
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
    final tokens = _tokenize(text);
    final entities = _readEntities(tokens);
    if (entities.isEmpty) return const ExtractResult(points: [], colors: []);

    // Group polylines by layer, preserving first-appearance order.
    final layerOrder = <String>[];
    final byLayer = <String, List<List<List<double>>>>{};
    final aciByLayer = <String, int?>{};
    for (final e in entities) {
      if (!byLayer.containsKey(e.layer)) {
        byLayer[e.layer] = [];
        layerOrder.add(e.layer);
        aciByLayer[e.layer] = e.colorIndex;
      }
      if (e.points.length >= 2) byLayer[e.layer]!.add(e.points);
    }
    if (layerOrder.isEmpty) return const ExtractResult(points: [], colors: []);

    // Overall bounding box across every layer, so all colors share one
    // consistent scale/centering (like laying one drawing on the bed).
    double minX = double.infinity, minY = double.infinity;
    double maxX = -double.infinity, maxY = -double.infinity;
    for (final polylines in byLayer.values) {
      for (final poly in polylines) {
        for (final p in poly) {
          if (p[0] < minX) minX = p[0];
          if (p[0] > maxX) maxX = p[0];
          if (p[1] < minY) minY = p[1];
          if (p[1] > maxY) maxY = p[1];
        }
      }
    }
    final spanX = math.max(1e-6, maxX - minX);
    final spanY = math.max(1e-6, maxY - minY);
    final scale = math.min(workWidthMm / spanX, workHeightMm / spanY);
    final offX = (workWidthMm - spanX * scale) / 2;
    final offY = (workHeightMm - spanY * scale) / 2;

    List<double> toMm(List<double> p) => [
          (p[0] - minX) * scale + offX,
          (p[1] - minY) * scale + offY,
        ];

    final totalRaw = entities.fold<int>(0, (s, e) => s + e.points.length);
    final budgetScale =
        totalRaw > _maxTotalPoints ? _maxTotalPoints / totalRaw : 1.0;

    final allPoints = <TuftPoint>[];
    final groups = <ColorGroup>[];
    var order = 0;
    for (final layer in layerOrder) {
      final polylines = byLayer[layer]!;
      if (polylines.isEmpty) continue;
      order++;
      final argb = _colorFor(order - 1, aciByLayer[layer]);

      // Chain this layer's separate polylines nearest-neighbor so the
      // whole color is stitched as one continuous sweep.
      final ordered = _chainNearest(polylines);
      var count = 0;
      for (final poly in ordered) {
        final step = math.max(1, (1 / budgetScale).round());
        for (var i = 0; i < poly.length; i += step) {
          final mm = toMm(poly[i]);
          allPoints.add(TuftPoint(x: mm[0], y: mm[1], colorValue: argb, colorOrder: order));
          count++;
        }
        // always keep the exact last point of each polyline (don't let
        // decimation cut a shape short)
        final last = toMm(poly.last);
        if (allPoints.isEmpty ||
            allPoints.last.x != last[0] ||
            allPoints.last.y != last[1]) {
          allPoints.add(TuftPoint(x: last[0], y: last[1], colorValue: argb, colorOrder: order));
          count++;
        }
      }
      if (count == 0) {
        order--;
        continue;
      }
      groups.add(ColorGroup(colorValue: argb, order: order, pointCount: count));
    }

    return ExtractResult(points: allPoints, colors: groups);
  }

  // ---------------------------------------------------------------------
  // Tokenizing: DXF is (group code, value) pairs, one per line.
  // ---------------------------------------------------------------------

  static List<MapEntry<int, String>> _tokenize(String text) {
    final lines = text.split(RegExp(r'\r\n|\r|\n'));
    final out = <MapEntry<int, String>>[];
    for (var i = 0; i + 1 < lines.length; i += 2) {
      final codeStr = lines[i].trim();
      final value = lines[i + 1].trim();
      final code = int.tryParse(codeStr);
      if (code == null) continue;
      out.add(MapEntry(code, value));
    }
    return out;
  }

  static List<_DxfEntity> _readEntities(List<MapEntry<int, String>> tokens) {
    // Find the ENTITIES section (falls back to scanning the whole file
    // if the section markers are missing/non-standard).
    var start = 0, end = tokens.length;
    for (var i = 0; i < tokens.length - 1; i++) {
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

    final entities = <_DxfEntity>[];
    var i = start;
    while (i < end) {
      if (tokens[i].key != 0) {
        i++;
        continue;
      }
      final type = tokens[i].value.toUpperCase();
      i++;
      final block = <MapEntry<int, String>>[];
      while (i < end && tokens[i].key != 0) {
        block.add(tokens[i]);
        i++;
      }

      switch (type) {
        case 'LINE':
          entities.add(_readLine(block));
          break;
        case 'CIRCLE':
          entities.add(_readCircle(block));
          break;
        case 'ARC':
          entities.add(_readArc(block));
          break;
        case 'LWPOLYLINE':
          entities.add(_readLwPolyline(block));
          break;
        case 'POLYLINE':
          final layer = _layerOf(block);
          final color = _colorIndexOf(block);
          final verts = <List<double>>[];
          // consume following VERTEX...SEQEND entities
          while (i < end) {
            if (tokens[i].key == 0 && tokens[i].value.toUpperCase() == 'VERTEX') {
              i++;
              final vb = <MapEntry<int, String>>[];
              while (i < end && tokens[i].key != 0) {
                vb.add(tokens[i]);
                i++;
              }
              final x = _get(vb, 10);
              final y = _get(vb, 20);
              if (x != null && y != null) verts.add([x, y]);
            } else if (tokens[i].key == 0 &&
                tokens[i].value.toUpperCase() == 'SEQEND') {
              i++;
              break;
            } else {
              break;
            }
          }
          if (verts.length >= 2) {
            entities.add(_DxfEntity(layer: layer, colorIndex: color, points: verts));
          }
          break;
        default:
          // SPLINE, TEXT, HATCH, INSERT, DIMENSION, etc. are skipped —
          // not needed for a stitch path and safe to ignore.
          break;
      }
    }
    return entities;
  }

  static String _layerOf(List<MapEntry<int, String>> block) {
    for (final t in block) {
      if (t.key == 8 && t.value.trim().isNotEmpty) return t.value.trim();
    }
    return '0';
  }

  static int? _colorIndexOf(List<MapEntry<int, String>> block) {
    for (final t in block) {
      if (t.key == 62) return int.tryParse(t.value.trim());
    }
    return null;
  }

  static double? _get(List<MapEntry<int, String>> block, int code) {
    for (final t in block) {
      if (t.key == code) return double.tryParse(t.value.trim());
    }
    return null;
  }

  static _DxfEntity _readLine(List<MapEntry<int, String>> block) {
    final x1 = _get(block, 10) ?? 0, y1 = _get(block, 20) ?? 0;
    final x2 = _get(block, 11) ?? 0, y2 = _get(block, 21) ?? 0;
    return _DxfEntity(
      layer: _layerOf(block),
      colorIndex: _colorIndexOf(block),
      points: [
        [x1, y1],
        [x2, y2],
      ],
    );
  }

  static _DxfEntity _readCircle(List<MapEntry<int, String>> block) {
    final cx = _get(block, 10) ?? 0, cy = _get(block, 20) ?? 0;
    final r = _get(block, 40) ?? 0;
    final pts = <List<double>>[];
    final steps = math.max(12, (360 / _arcSegmentDeg).round());
    for (var i = 0; i <= steps; i++) {
      final a = 2 * math.pi * i / steps;
      pts.add([cx + r * math.cos(a), cy + r * math.sin(a)]);
    }
    return _DxfEntity(layer: _layerOf(block), colorIndex: _colorIndexOf(block), points: pts);
  }

  static _DxfEntity _readArc(List<MapEntry<int, String>> block) {
    final cx = _get(block, 10) ?? 0, cy = _get(block, 20) ?? 0;
    final r = _get(block, 40) ?? 0;
    final a0 = (_get(block, 50) ?? 0) * math.pi / 180;
    var a1 = (_get(block, 51) ?? 0) * math.pi / 180;
    if (a1 < a0) a1 += 2 * math.pi; // DXF arcs run CCW from start to end
    final sweep = a1 - a0;
    final steps = math.max(2, (sweep.abs() * 180 / math.pi / _arcSegmentDeg).round());
    final pts = <List<double>>[];
    for (var i = 0; i <= steps; i++) {
      final a = a0 + sweep * i / steps;
      pts.add([cx + r * math.cos(a), cy + r * math.sin(a)]);
    }
    return _DxfEntity(layer: _layerOf(block), colorIndex: _colorIndexOf(block), points: pts);
  }

  static _DxfEntity _readLwPolyline(List<MapEntry<int, String>> block) {
    final layer = _layerOf(block);
    final color = _colorIndexOf(block);
    final verts = <List<double>>[]; // [x, y, bulge]
    double? curX, curY;
    double curBulge = 0;
    var closed = false;
    for (final t in block) {
      switch (t.key) {
        case 70:
          closed = (int.tryParse(t.value.trim()) ?? 0) & 1 == 1;
          break;
        case 10:
          if (curX != null && curY != null) {
            verts.add([curX, curY, curBulge]);
          }
          curX = double.tryParse(t.value.trim());
          curBulge = 0;
          break;
        case 20:
          curY = double.tryParse(t.value.trim());
          break;
        case 42:
          curBulge = double.tryParse(t.value.trim()) ?? 0;
          break;
      }
    }
    if (curX != null && curY != null) verts.add([curX, curY, curBulge]);
    if (closed && verts.isNotEmpty) {
      verts.add([verts.first[0], verts.first[1], verts.first[2]]);
    }

    if (verts.length < 2) {
      return _DxfEntity(layer: layer, colorIndex: color, points: const []);
    }

    final pts = <List<double>>[
      [verts.first[0], verts.first[1]]
    ];
    for (var i = 0; i < verts.length - 1; i++) {
      final p1 = verts[i];
      final p2 = verts[i + 1];
      final bulge = p1[2];
      if (bulge.abs() < 1e-9) {
        pts.add([p2[0], p2[1]]);
      } else {
        pts.addAll(_bulgeArcPoints(p1[0], p1[1], p2[0], p2[1], bulge));
      }
    }
    return _DxfEntity(layer: layer, colorIndex: color, points: pts);
  }

  /// Converts a DXF "bulge" (an arc bulging between two polyline
  /// vertices) into sampled curve points — this is what makes rounded
  /// corners in a DXF come out as real curves instead of straight cuts.
  static List<List<double>> _bulgeArcPoints(
      double x1, double y1, double x2, double y2, double bulge) {
    final theta = 4 * math.atan(bulge); // signed included angle
    final dx = x2 - x1, dy = y2 - y1;
    final chord = math.sqrt(dx * dx + dy * dy);
    if (chord < 1e-9) return [[x2, y2]];
    final radius = chord / (2 * math.sin(theta / 2).abs());
    final a = math.sqrt(math.max(0, radius * radius - (chord / 2) * (chord / 2)));
    final mx = (x1 + x2) / 2, my = (y1 + y2) / 2;
    // unit perpendicular to the chord
    var ux = -dy / chord, uy = dx / chord;
    final sign = bulge >= 0 ? 1.0 : -1.0;
    final cx = mx + ux * a * sign;
    final cy = my + uy * a * sign;
    final startAngle = math.atan2(y1 - cy, x1 - cx);
    final endAngle = startAngle + theta;
    final steps = math.max(2, (theta.abs() * 180 / math.pi / _arcSegmentDeg).round());
    final pts = <List<double>>[];
    for (var i = 1; i <= steps; i++) {
      final a2 = startAngle + (endAngle - startAngle) * i / steps;
      pts.add([cx + radius * math.cos(a2), cy + radius * math.sin(a2)]);
    }
    return pts;
  }

  /// Greedy nearest-neighbor chaining so a layer's separate polylines
  /// are stitched as one continuous sweep instead of jumping randomly.
  static List<List<List<double>>> _chainNearest(List<List<List<double>>> polylines) {
    final remaining = List<List<List<double>>>.from(polylines);
    final ordered = <List<List<double>>>[];
    var cursor = remaining.removeAt(0);
    ordered.add(cursor);
    var cx = cursor.last[0], cy = cursor.last[1];
    while (remaining.isNotEmpty) {
      var bestIdx = 0;
      var bestDist = double.infinity;
      var bestReversed = false;
      for (var i = 0; i < remaining.length; i++) {
        final poly = remaining[i];
        final dStart = _dist(cx, cy, poly.first[0], poly.first[1]);
        final dEnd = _dist(cx, cy, poly.last[0], poly.last[1]);
        if (dStart < bestDist) {
          bestDist = dStart;
          bestIdx = i;
          bestReversed = false;
        }
        if (dEnd < bestDist) {
          bestDist = dEnd;
          bestIdx = i;
          bestReversed = true;
        }
      }
      var next = remaining.removeAt(bestIdx);
      if (bestReversed) next = next.reversed.toList();
      ordered.add(next);
      cx = next.last[0];
      cy = next.last[1];
    }
    return ordered;
  }

  static double _dist(double x1, double y1, double x2, double y2) {
    final dx = x2 - x1, dy = y2 - y1;
    return math.sqrt(dx * dx + dy * dy);
  }

  /// Picks a thread color for a layer: uses the DXF's own ACI color
  /// index when the layer specifies one, otherwise cycles an evenly
  /// spaced palette so different layers are always visually distinct.
  static int _colorFor(int index, int? aci) {
    if (aci != null && _aciPalette.containsKey(aci)) {
      return 0xFF000000 | _aciPalette[aci]!;
    }
    final hue = (index * 47) % 360; // 47° step keeps consecutive hues apart
    return 0xFF000000 | _hsvToRgb(hue.toDouble(), 0.65, 0.85);
  }

  static int _hsvToRgb(double h, double s, double v) {
    final c = v * s;
    final x = c * (1 - ((h / 60) % 2 - 1).abs());
    final m = v - c;
    double r = 0, g = 0, b = 0;
    if (h < 60) {
      r = c; g = x; b = 0;
    } else if (h < 120) {
      r = x; g = c; b = 0;
    } else if (h < 180) {
      r = 0; g = c; b = x;
    } else if (h < 240) {
      r = 0; g = x; b = c;
    } else if (h < 300) {
      r = x; g = 0; b = c;
    } else {
      r = c; g = 0; b = x;
    }
    final ri = ((r + m) * 255).round().clamp(0, 255);
    final gi = ((g + m) * 255).round().clamp(0, 255);
    final bi = ((b + m) * 255).round().clamp(0, 255);
    return (ri << 16) | (gi << 8) | bi;
  }

  static const Map<int, int> _aciPalette = {
    1: 0xFF0000, // red
    2: 0xFFFF00, // yellow
    3: 0x00FF00, // green
    4: 0x00FFFF, // cyan
    5: 0x0000FF, // blue
    6: 0xFF00FF, // magenta
    7: 0xFFFFFF, // white
    8: 0x808080, // gray
    9: 0xC0C0C0, // light gray
  };
}

class _DxfEntity {
  final String layer;
  final int? colorIndex;
  final List<List<double>> points;
  _DxfEntity({required this.layer, required this.colorIndex, required this.points});
}

/// Global top-level function called by [MachineService] isolates.
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

/// Alias top-level function expected by [MachineService] isolates.
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