import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../models/design.dart';

/// Bitmap -> multi-color stitch path.
///
/// Pipeline:
///  1. Detect the foreground (non-background) pixels of the image.
///  2. Quantize the foreground into a small palette of dominant colors
///     (this is the "thread colors").
///  3. For each color, find its connected regions and trace their
///     boundary by *walking the edge of the shape* (Moore-neighbor
///     contour tracing) instead of scanning fixed horizontal rows.
///     Filled regions get concentric contour-following rings instead
///     of a raster zig-zag fill.
///  4. Every contour is smoothed (Chaikin corner-cutting) so curved
///     parts of the artwork come out as curves, not staircases of
///     straight segments.
///  5. Colors are emitted one completely after another: every point of
///     color #1 comes before any point of color #2, etc. Each point
///     carries its color + 1-based color order so the HMI can show
///     "color 2 / 5" and pause for a thread change between groups.
class PathExtractor {
  static const int _maxSide = 420;
  static const int _maxColors = 8;
  static const int _colorMergeDist = 46; // RGB distance to merge similar shades
  static const int _bgLuma = 235; // pixels lighter than this = background/canvas

  static List<TuftPoint> extractFromBytes(
    Uint8List bytes, {
    double workWidthMm = 600,
    double workHeightMm = 400,
    double pitchMm = 10,
    int maxPoints = 900,
  }) {
    return extractMultiColor(
      bytes,
      workWidthMm: workWidthMm,
      workHeightMm: workHeightMm,
      pitchMm: pitchMm,
      maxPoints: maxPoints,
    ).points;
  }

  /// Full multi-color extraction. Returns both the flattened, ordered
  /// point list (grouped color-by-color) and a summary of each color
  /// group for UI / thread-change purposes.
  static ExtractResult extractMultiColor(
    Uint8List bytes, {
    double workWidthMm = 600,
    double workHeightMm = 400,
    double pitchMm = 10,
    int maxPoints = 900,
  }) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return const ExtractResult(points: [], colors: []);

    img.Image src = decoded;
    if (src.width > _maxSide || src.height > _maxSide) {
      src = img.copyResize(
        src,
        width: src.width >= src.height ? _maxSide : null,
        height: src.height > src.width ? _maxSide : null,
        interpolation: img.Interpolation.average,
      );
    }
    final w = src.width;
    final h = src.height;
    if (w < 2 || h < 2) return const ExtractResult(points: [], colors: []);

    // ---- 1. foreground mask (anything that isn't near-white / transparent) ----
    final fg = Uint8List(w * h);
    var fgCount = 0;
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final p = src.getPixel(x, y);
        final a = p.a.toInt();
        final luma = (0.299 * p.r + 0.587 * p.g + 0.114 * p.b);
        final isFg = a > 10 && luma < _bgLuma;
        if (isFg) {
          fg[y * w + x] = 1;
          fgCount++;
        }
      }
    }
    if (fgCount == 0) return const ExtractResult(points: [], colors: []);

    // ---- 2. quantize into a small thread-color palette ----
    final palette = _buildPalette(src, fg, w, h, _maxColors);
    if (palette.isEmpty) return const ExtractResult(points: [], colors: []);

    // Assign every foreground pixel to its nearest palette color.
    final labelOf = Int16List(w * h)..fillRange(0, w * h, -1);
    final areaByColor = List<int>.filled(palette.length, 0);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final idx = y * w + x;
        if (fg[idx] == 0) continue;
        final p = src.getPixel(x, y);
        final rgb = (p.r.toInt() << 16) | (p.g.toInt() << 8) | p.b.toInt();
        var best = 0;
        var bestD = 1 << 30;
        for (var ci = 0; ci < palette.length; ci++) {
          final d = _rgbDist(rgb, palette[ci]);
          if (d < bestD) {
            bestD = d;
            best = ci;
          }
        }
        labelOf[idx] = best;
        areaByColor[best]++;
      }
    }

    // Order colors: largest area (main fields) first, detail colors after.
    final colorOrderIdx = List<int>.generate(palette.length, (i) => i)
      ..sort((a, b) => areaByColor[b].compareTo(areaByColor[a]));

    // pixel spacing in px that corresponds to the requested pitch (mm)
    final pxPerMmX = w / workWidthMm;
    final pxPerMmY = h / workHeightMm;
    final pitchPx =
        math.max(1.0, pitchMm * (pxPerMmX + pxPerMmY) / 2).roundToDouble();

    final totalFg = fgCount;
    final groups = <ColorGroup>[];
    final allPoints = <TuftPoint>[];
    var order = 0;

    for (final ci in colorOrderIdx) {
      final area = areaByColor[ci];
      if (area < math.max(6, (w * h * 0.0012).round())) continue; // noise
      order++;

      final colorMask = Uint8List(w * h);
      for (var i = 0; i < w * h; i++) {
        if (labelOf[i] == ci) colorMask[i] = 1;
      }

      // Fair share of the point budget, proportional to area, with a floor
      // so every color stays visible even on a tight budget.
      final share =
          (maxPoints * (area / totalFg)).round().clamp(24, maxPoints).toInt();

      final regionPoints = _pathForColorMask(
        colorMask,
        w,
        h,
        workWidthMm,
        workHeightMm,
        pitchPx,
        share,
      );
      if (regionPoints.isEmpty) {
        order--;
        continue;
      }

      final argb = 0xFF000000 | palette[ci];
      for (final p in regionPoints) {
        allPoints.add(TuftPoint(
          x: p.x,
          y: p.y,
          colorValue: argb,
          colorOrder: order,
        ));
      }
      groups.add(ColorGroup(
        colorValue: argb,
        order: order,
        pointCount: regionPoints.length,
      ));
    }

    return ExtractResult(points: allPoints, colors: groups);
  }

  // ---------------------------------------------------------------------
  // Palette building
  // ---------------------------------------------------------------------

  static List<int> _buildPalette(
    img.Image src,
    Uint8List fg,
    int w,
    int h,
    int maxColors,
  ) {
    // Bucket colors on a coarse grid to find dominant shades quickly.
    const levels = 6;
    const step = 256 / levels;
    final hist = <int, int>{};
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        if (fg[y * w + x] == 0) continue;
        final p = src.getPixel(x, y);
        final r = ((p.r.toInt() / step).floor() * step + step / 2).clamp(0, 255).toInt();
        final g = ((p.g.toInt() / step).floor() * step + step / 2).clamp(0, 255).toInt();
        final b = ((p.b.toInt() / step).floor() * step + step / 2).clamp(0, 255).toInt();
        final key = (r << 16) | (g << 8) | b;
        hist[key] = (hist[key] ?? 0) + 1;
      }
    }
    final entries = hist.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final palette = <int>[];
    for (final e in entries) {
      if (palette.length >= maxColors) break;
      var tooClose = false;
      for (final p in palette) {
        if (_rgbDist(e.key, p) < _colorMergeDist * _colorMergeDist) {
          tooClose = true;
          break;
        }
      }
      if (!tooClose) palette.add(e.key);
    }
    return palette;
  }

  static int _rgbDist(int a, int b) {
    final ar = (a >> 16) & 0xFF, ag = (a >> 8) & 0xFF, ab = a & 0xFF;
    final br = (b >> 16) & 0xFF, bg = (b >> 8) & 0xFF, bb = b & 0xFF;
    final dr = ar - br, dg = ag - bg, db = ab - bb;
    return dr * dr + dg * dg + db * db;
  }

  // ---------------------------------------------------------------------
  // Contour extraction for a single color's mask
  // ---------------------------------------------------------------------

  static List<TuftPoint> _pathForColorMask(
    Uint8List mask,
    int w,
    int h,
    double workW,
    double workH,
    double pitchPx,
    int pointBudget,
  ) {
    final regions = _connectedComponents(mask, w, h);
    if (regions.isEmpty) return [];

    // Visit regions nearest-neighbor (by centroid) so the color is finished
    // as one continuous sweep instead of jumping randomly across the art.
    regions.sort((a, b) => b.pixelCount.compareTo(a.pixelCount));
    final visited = List<bool>.filled(regions.length, false);
    final orderedRegions = <_Region>[];
    var cursor = 0.0, cursorY = 0.0;
    for (var n = 0; n < regions.length; n++) {
      var best = -1;
      var bestD = double.infinity;
      for (var i = 0; i < regions.length; i++) {
        if (visited[i]) continue;
        final dx = regions[i].cx - cursor;
        final dy = regions[i].cy - cursorY;
        final d = dx * dx + dy * dy;
        if (d < bestD) {
          bestD = d;
          best = i;
        }
      }
      if (best == -1) break;
      visited[best] = true;
      orderedRegions.add(regions[best]);
      cursor = regions[best].cx;
      cursorY = regions[best].cy;
    }

    final totalPixels =
        regions.fold<int>(0, (sum, r) => sum + r.pixelCount);
    final out = <TuftPoint>[];

    for (final region in orderedRegions) {
      final regionBudget = math.max(
        6,
        (pointBudget * (region.pixelCount / totalPixels)).round(),
      );

      final rings = <List<List<int>>>[];
      var ringMask = _extractRegionMask(mask, w, h, region);
      var safety = 0;
      while (safety < 40) {
        safety++;
        final start = _topLeftForeground(ringMask, w, h);
        if (start == null) break;
        final boundary = _traceMoore(ringMask, w, h, start[0], start[1]);
        if (boundary.length >= 3) rings.add(boundary);
        // shrink the mask by ~1 pitch step for the next inner ring
        final erodeSteps = math.max(1, pitchPx.round());
        var eroded = ringMask;
        for (var s = 0; s < erodeSteps; s++) {
          eroded = _erode(eroded, w, h);
        }
        if (_isEmpty(eroded)) break;
        ringMask = eroded;
        // Thin outlines (fillRatio small) don't need concentric fill --
        // one ring is already the whole shape.
        if (region.fillRatio < 0.18) break;
      }

      if (rings.isEmpty) continue;

      // Smooth + resample every ring, then chain them (outer -> inner)
      // with short connective hops so travel stays continuous.
      final ringBudget = math.max(4, regionBudget ~/ rings.length);
      for (final ring in rings) {
        final smooth = _chaikin(ring, iterations: 2);
        final resampled = _resampleByCount(smooth, ringBudget);
        for (final pt in resampled) {
          out.add(_pxToMm(pt[0], pt[1], w, h, workW, workH));
        }
      }
    }

    return out;
  }

  // ---------------------------------------------------------------------
  // Connected components (per color)
  // ---------------------------------------------------------------------

  static List<_Region> _connectedComponents(Uint8List mask, int w, int h) {
    final labels = Int32List(w * h)..fillRange(0, w * h, -1);
    final regions = <_Region>[];
    final minPixels = math.max(6, (w * h * 0.0012).round());
    final queue = <int>[];

    for (var start = 0; start < w * h; start++) {
      if (mask[start] == 0 || labels[start] != -1) continue;
      final seedIndex = start;
      queue.clear();
      queue.add(start);
      labels[start] = regions.length;
      var minX = start % w, maxX = start % w, minY = start ~/ w, maxY = start ~/ w;
      var sumX = 0.0, sumY = 0.0, count = 0;
      var qi = 0;
      while (qi < queue.length) {
        final idx = queue[qi++];
        final x = idx % w, y = idx ~/ w;
        sumX += x;
        sumY += y;
        count++;
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
        const dirs = [-1, 1];
        for (final d in dirs) {
          final nx = x + d;
          if (nx >= 0 && nx < w) {
            final ni = y * w + nx;
            if (mask[ni] == 1 && labels[ni] == -1) {
              labels[ni] = regions.length;
              queue.add(ni);
            }
          }
          final ny = y + d;
          if (ny >= 0 && ny < h) {
            final ni = ny * w + x;
            if (mask[ni] == 1 && labels[ni] == -1) {
              labels[ni] = regions.length;
              queue.add(ni);
            }
          }
        }
      }
      if (count < minPixels) continue;
      final boxW = (maxX - minX + 1);
      final boxH = (maxY - minY + 1);
      final fillRatio = count / math.max(1, boxW * boxH);
      regions.add(_Region(
        id: regions.length,
        seedIndex: seedIndex,
        pixelCount: count,
        cx: sumX / count,
        cy: sumY / count,
        minX: minX,
        minY: minY,
        maxX: maxX,
        maxY: maxY,
        fillRatio: fillRatio,
      ));
    }
    return regions;
  }

  /// Re-derives exactly this region's pixel footprint (and nothing from a
  /// neighbouring same-color blob that might share the same bounding box)
  /// via a single flood fill from the region's known seed pixel.
  static Uint8List _extractRegionMask(Uint8List mask, int w, int h, _Region r) {
    final out = Uint8List(w * h);
    final visited = Uint8List(w * h);
    final queue = <int>[r.seedIndex];
    visited[r.seedIndex] = 1;
    var qi = 0;
    while (qi < queue.length) {
      final idx = queue[qi++];
      out[idx] = 1;
      final x = idx % w, y = idx ~/ w;
      const dirs = [-1, 1];
      for (final d in dirs) {
        final nx = x + d;
        if (nx >= 0 && nx < w) {
          final ni = y * w + nx;
          if (mask[ni] == 1 && visited[ni] == 0) {
            visited[ni] = 1;
            queue.add(ni);
          }
        }
        final ny = y + d;
        if (ny >= 0 && ny < h) {
          final ni = ny * w + x;
          if (mask[ni] == 1 && visited[ni] == 0) {
            visited[ni] = 1;
            queue.add(ni);
          }
        }
      }
    }
    return out;
  }

  // ---------------------------------------------------------------------
  // Moore-neighbor boundary tracing (walks the actual edge of the shape)
  // ---------------------------------------------------------------------

  static const List<List<int>> _nb = [
    [0, -1], [1, -1], [1, 0], [1, 1], // N, NE, E, SE
    [0, 1], [-1, 1], [-1, 0], [-1, -1], // S, SW, W, NW
  ];

  static bool _on(Uint8List mask, int w, int h, int x, int y) {
    if (x < 0 || y < 0 || x >= w || y >= h) return false;
    return mask[y * w + x] == 1;
  }

  static List<int>? _topLeftForeground(Uint8List mask, int w, int h) {
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        if (mask[y * w + x] == 1) return [x, y];
      }
    }
    return null;
  }

  static List<List<int>> _traceMoore(Uint8List mask, int w, int h, int sx, int sy) {
    final boundary = <List<int>>[[sx, sy]];
    var cx = sx, cy = sy;
    var bgx = sx - 1, bgy = sy; // background pixel that led us to start (west)
    var steps = 0;
    const maxSteps = 6000;
    while (steps < maxSteps) {
      steps++;
      var bgDir = -1;
      for (var i = 0; i < 8; i++) {
        if (cx + _nb[i][0] == bgx && cy + _nb[i][1] == bgy) {
          bgDir = i;
          break;
        }
      }
      if (bgDir == -1) bgDir = 6; // fallback: west

      var nx = -1, ny = -1, foundIdx = -1;
      for (var i = 1; i <= 8; i++) {
        final d = (bgDir + i) % 8;
        final tx = cx + _nb[d][0];
        final ty = cy + _nb[d][1];
        if (_on(mask, w, h, tx, ty)) {
          nx = tx;
          ny = ty;
          foundIdx = d;
          break;
        }
      }
      if (foundIdx == -1) break; // isolated pixel, nothing more to trace

      final prevIdx = (foundIdx - 1 + 8) % 8;
      bgx = cx + _nb[prevIdx][0];
      bgy = cy + _nb[prevIdx][1];
      cx = nx;
      cy = ny;
      if (cx == sx && cy == sy) break; // closed the loop
      boundary.add([cx, cy]);
    }
    return boundary;
  }

  static Uint8List _erode(Uint8List mask, int w, int h) {
    final out = Uint8List(w * h);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        if (mask[y * w + x] == 0) continue;
        if (_on(mask, w, h, x - 1, y) &&
            _on(mask, w, h, x + 1, y) &&
            _on(mask, w, h, x, y - 1) &&
            _on(mask, w, h, x, y + 1)) {
          out[y * w + x] = 1;
        }
      }
    }
    return out;
  }

  static bool _isEmpty(Uint8List mask) {
    for (final v in mask) {
      if (v == 1) return false;
    }
    return true;
  }

  // ---------------------------------------------------------------------
  // Curve smoothing + resampling
  // ---------------------------------------------------------------------

  /// Chaikin corner-cutting: turns a jagged pixel-stair boundary into a
  /// smooth curve that follows the actual shape of the artwork.
  static List<List<double>> _chaikin(List<List<int>> pts, {int iterations = 2}) {
    List<List<double>> cur =
        pts.map((p) => [p[0].toDouble(), p[1].toDouble()]).toList();
    for (var it = 0; it < iterations; it++) {
      if (cur.length < 3) break;
      final next = <List<double>>[];
      for (var i = 0; i < cur.length; i++) {
        final a = cur[i];
        final b = cur[(i + 1) % cur.length];
        next.add([a[0] * 0.75 + b[0] * 0.25, a[1] * 0.75 + b[1] * 0.25]);
        next.add([a[0] * 0.25 + b[0] * 0.75, a[1] * 0.25 + b[1] * 0.75]);
      }
      cur = next;
    }
    return cur;
  }

  static List<List<double>> _resampleByCount(List<List<double>> pts, int count) {
    if (pts.length <= 2 || count <= 0) return pts;
    // arc-length parametrize, then sample evenly -> constant point density
    // along the curve regardless of local pixel noise.
    final dist = List<double>.filled(pts.length, 0);
    for (var i = 1; i < pts.length; i++) {
      final dx = pts[i][0] - pts[i - 1][0];
      final dy = pts[i][1] - pts[i - 1][1];
      dist[i] = dist[i - 1] + math.sqrt(dx * dx + dy * dy);
    }
    final total = dist.last;
    if (total <= 0) return [pts.first];
    final out = <List<double>>[];
    var seg = 0;
    for (var k = 0; k < count; k++) {
      final target = total * k / (count - 1 == 0 ? 1 : count - 1);
      while (seg < dist.length - 2 && dist[seg + 1] < target) {
        seg++;
      }
      final segLen = dist[seg + 1] - dist[seg];
      final t = segLen <= 0 ? 0.0 : (target - dist[seg]) / segLen;
      final a = pts[seg];
      final b = pts[seg + 1];
      out.add([a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t]);
    }
    return out;
  }

  static TuftPoint _pxToMm(
    double px,
    double py,
    int w,
    int h,
    double workW,
    double workH,
  ) {
    return TuftPoint(
      x: px / (w - 1) * workW,
      y: (1.0 - py / (h - 1)) * workH,
    );
  }

  // ---------------------------------------------------------------------
  // G-code emission (pauses for a thread change between color groups)
  // ---------------------------------------------------------------------

  static String toGCode(
    List<TuftPoint> points, {
    double feedMmMin = 3000,
    double safeZ = 5,
    bool embroidery = true,
  }) {
    final b = StringBuffer();
    b.writeln('; ROVEX path — ${points.length} pts');
    b.writeln('G21');
    b.writeln('G90');
    b.writeln('G0 Z${safeZ.toStringAsFixed(2)}');
    if (points.isEmpty) {
      b.writeln('M2');
      return b.toString();
    }
    b.writeln(
        'G0 X${points.first.x.toStringAsFixed(2)} Y${points.first.y.toStringAsFixed(2)}');
    if (embroidery) b.writeln('M8 ; needle engage');

    int? lastColorOrder;
    for (final p in points) {
      if (p.colorOrder != null && p.colorOrder != lastColorOrder) {
        if (lastColorOrder != null) {
          if (embroidery) b.writeln('M9 ; needle up');
          b.writeln('G0 Z${safeZ.toStringAsFixed(2)}');
          final hex = p.colorValue != null
              ? '#${(p.colorValue! & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}'
              : '?';
          b.writeln('M0 ; THREAD CHANGE -> color ${p.colorOrder} ($hex)');
          if (embroidery) b.writeln('M8 ; needle engage');
        }
        lastColorOrder = p.colorOrder;
      }
      b.writeln(
          'G1 X${p.x.toStringAsFixed(2)} Y${p.y.toStringAsFixed(2)} F${feedMmMin.toStringAsFixed(0)}');
    }
    if (embroidery) {
      b.writeln('M9 ; needle up');
      b.writeln('G0 Z${safeZ.toStringAsFixed(2)}');
    }
    b.writeln('M2');
    return b.toString();
  }
}

class _Region {
  final int id;
  final int seedIndex;
  final int pixelCount;
  final double cx;
  final double cy;
  final int minX, minY, maxX, maxY;
  final double fillRatio;

  _Region({
    required this.id,
    required this.seedIndex,
    required this.pixelCount,
    required this.cx,
    required this.cy,
    required this.minX,
    required this.minY,
    required this.maxX,
    required this.maxY,
    required this.fillRatio,
  });
}

/// Global top-level function called by [MachineService] isolates.
ExtractResult extractPathFromImageBytes(Uint8List bytes, {double pitch = 10.0}) {
  return PathExtractor.extractMultiColor(
    bytes,
    pitchMm: pitch,
  );
}