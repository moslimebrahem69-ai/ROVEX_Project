import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../models/design.dart';

class PathExtractor {
  static const int _maxSide = 420;
  static const int _maxColors = 8;
  static const int _alphaThreshold = 10;
  static const int _grayscaleTolerance = 12;
  static const int _colorMergeDist = 46;

  static List<TuftPoint> extractFromBytes(
    Uint8List bytes, {
    double workWidthMm = 600,
    double workHeightMm = 400,
    double pitchMm = 3,
    int maxPoints = 0,
  }) {
    return extractMultiColor(
      bytes,
      workWidthMm: workWidthMm,
      workHeightMm: workHeightMm,
      pitchMm: pitchMm,
      maxPoints: maxPoints,
    ).points;
  }

  static ExtractResult extractMultiColor(
    Uint8List bytes, {
    double workWidthMm = 600,
    double workHeightMm = 400,
    double pitchMm = 3,
    int maxPoints = 0,
  }) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      return const ExtractResult(points: [], colors: []);
    }

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
    if (w < 2 || h < 2) {
      return const ExtractResult(points: [], colors: []);
    }

    final visible = Uint8List(w * h);
    var visibleCount = 0;

    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final pixel = src.getPixel(x, y);
        if (pixel.a.toInt() > _alphaThreshold) {
          visible[y * w + x] = 1;
          visibleCount++;
        }
      }
    }

    if (visibleCount == 0) {
      return const ExtractResult(points: [], colors: []);
    }

    final background = _estimateBackgroundColor(src, visible, w, h);
    final foreground = Uint8List(w * h);
    var foregroundCount = 0;

    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final index = y * w + x;
        if (visible[index] == 0) continue;

        final pixel = src.getPixel(x, y);
        if (_isBackgroundPixel(pixel, background)) continue;

        foreground[index] = 1;
        foregroundCount++;
      }
    }

    if (foregroundCount == 0) {
      return const ExtractResult(points: [], colors: []);
    }

    final grayscale = _isMostlyGrayscale(src, foreground, w, h);
    final palette = grayscale
        ? _buildGrayscaleForegroundPalette(src, foreground, w, h)
        : _buildPalette(src, foreground, w, h, _maxColors);

    if (palette.isEmpty) {
      return const ExtractResult(points: [], colors: []);
    }

    final labels = Int16List(w * h)..fillRange(0, w * h, -1);
    final areaByColor = List<int>.filled(palette.length, 0);

    final grayscaleThreshold =
        grayscale && palette.length > 1
            ? _otsuThreshold(src, foreground, w, h)
            : -1;

    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final index = y * w + x;
        if (foreground[index] == 0) continue;

        final pixel = src.getPixel(x, y);
        final rgb = (pixel.r.toInt() << 16) |
            (pixel.g.toInt() << 8) |
            pixel.b.toInt();

        var best = 0;

        if (grayscale && palette.length == 2) {
          best = _luma(pixel) <= grayscaleThreshold ? 0 : 1;
        } else {
          var bestDistance = 1 << 30;
          for (var colorIndex = 0;
              colorIndex < palette.length;
              colorIndex++) {
            final distance = _rgbDist(rgb, palette[colorIndex]);
            if (distance < bestDistance) {
              bestDistance = distance;
              best = colorIndex;
            }
          }
        }

        labels[index] = best;
        areaByColor[best]++;
      }
    }

    final colorOrder = List<int>.generate(
      palette.length,
      (index) => index,
    )..sort(
        (a, b) => areaByColor[b].compareTo(areaByColor[a]),
      );

    final pxPerMmX = w / workWidthMm;
    final pxPerMmY = h / workHeightMm;
    final safePitchMm = pitchMm.clamp(1.0, 5.0);
    final averagePxPerMm = (pxPerMmX + pxPerMmY) / 2.0;
    final pitchPx = math.max(1.0, safePitchMm * averagePxPerMm);

    final groups = <ColorGroup>[];
    final allPoints = <TuftPoint>[];
    var order = 0;

    for (final paletteIndex in colorOrder) {
      final area = areaByColor[paletteIndex];
      if (area <= 0) continue;

      final colorMask = Uint8List(w * h);
      for (var index = 0; index < w * h; index++) {
        if (labels[index] == paletteIndex) {
          colorMask[index] = 1;
        }
      }

      final regionPoints = _pathForColorMask(
        colorMask,
        w,
        h,
        workWidthMm,
        workHeightMm,
        pitchPx,
      );

      if (regionPoints.isEmpty) continue;

      order++;
      final paletteColor = 0xFF000000 | palette[paletteIndex];

      for (final point in regionPoints) {
        allPoints.add(
          TuftPoint(
            x: point.x,
            y: point.y,
            colorValue: paletteColor,
            colorOrder: order,
          ),
        );
      }

      groups.add(
        ColorGroup(
          colorValue: paletteColor,
          order: order,
          pointCount: regionPoints.length,
        ),
      );
    }

    final resultPoints =
        maxPoints > 0 && allPoints.length > maxPoints
            ? _limitPoints(allPoints, maxPoints)
            : allPoints;

    return ExtractResult(
      points: resultPoints,
      colors: groups,
    );
  }

  static int _estimateBackgroundColor(
    img.Image src,
    Uint8List visible,
    int w,
    int h,
  ) {
    final histogram = <int, int>{};

    void addPixel(int x, int y) {
      final index = y * w + x;
      if (visible[index] == 0) return;

      final normalized = _normalizeRgb(src.getPixel(x, y), 32);
      histogram[normalized] = (histogram[normalized] ?? 0) + 1;
    }

    for (var x = 0; x < w; x++) {
      addPixel(x, 0);
      addPixel(x, h - 1);
    }

    for (var y = 1; y < h - 1; y++) {
      addPixel(0, y);
      addPixel(w - 1, y);
    }

    if (histogram.isEmpty) return 0xFFFFFF;

    var bestColor = 0xFFFFFF;
    var bestCount = -1;

    for (final entry in histogram.entries) {
      if (entry.value > bestCount) {
        bestCount = entry.value;
        bestColor = entry.key;
      }
    }

    return bestColor;
  }

  static bool _isBackgroundPixel(
    img.Pixel pixel,
    int background,
  ) {
    final rgb = (pixel.r.toInt() << 16) |
        (pixel.g.toInt() << 8) |
        pixel.b.toInt();

    final distance = _rgbDist(rgb, background);

    final r = pixel.r.toInt();
    final g = pixel.g.toInt();
    final b = pixel.b.toInt();

    final backgroundR = (background >> 16) & 0xFF;
    final backgroundG = (background >> 8) & 0xFF;
    final backgroundB = background & 0xFF;

    final maxDifference = math.max(
      (r - backgroundR).abs(),
      math.max(
        (g - backgroundG).abs(),
        (b - backgroundB).abs(),
      ),
    );

    return distance <= 45 * 45 || maxDifference <= 18;
  }

  static List<int> _buildPalette(
    img.Image src,
    Uint8List foreground,
    int w,
    int h,
    int maxColors,
  ) {
    const levels = 6;
    const step = 256 / levels;
    final histogram = <int, int>{};

    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        if (foreground[y * w + x] == 0) continue;

        final key = _normalizeRgb(src.getPixel(x, y), step);
        histogram[key] = (histogram[key] ?? 0) + 1;
      }
    }

    final entries = histogram.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final palette = <int>[];

    for (final entry in entries) {
      if (palette.length >= maxColors) break;

      var tooClose = false;
      for (final color in palette) {
        if (_rgbDist(entry.key, color) <
            _colorMergeDist * _colorMergeDist) {
          tooClose = true;
          break;
        }
      }

      if (!tooClose) {
        palette.add(entry.key);
      }
    }

    return palette;
  }

  static List<int> _buildGrayscaleForegroundPalette(
    img.Image src,
    Uint8List foreground,
    int w,
    int h,
  ) {
    var darkest = 255;
    var lightest = 0;

    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        if (foreground[y * w + x] == 0) continue;

        final luma = _luma(src.getPixel(x, y));
        darkest = math.min(darkest, luma);
        lightest = math.max(lightest, luma);
      }
    }

    if (darkest == 255) return [];

    if ((lightest - darkest) < 20) {
      return [_grayToRgb(darkest)];
    }

    final histogram = List<int>.filled(256, 0);

    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        if (foreground[y * w + x] == 0) continue;
        histogram[_luma(src.getPixel(x, y))]++;
      }
    }

    var first = -1;
    var last = -1;

    for (var i = 0; i < histogram.length; i++) {
      if (histogram[i] > 0) {
        if (first == -1) first = i;
        last = i;
      }
    }

    if (first == -1 || last == -1) return [];

    var lowCount = 0;
    var highCount = 0;

    for (var i = first; i <= last; i++) {
      if (i <= (first + last) ~/ 2) {
        lowCount += histogram[i];
      } else {
        highCount += histogram[i];
      }
    }

    if (lowCount == 0 || highCount == 0) {
      return [_grayToRgb((first + last) ~/ 2)];
    }

    return [0x000000, 0xFFFFFF];
  }

  static bool _isMostlyGrayscale(
    img.Image src,
    Uint8List foreground,
    int w,
    int h,
  ) {
    var checked = 0;
    var grayscalePixels = 0;

    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        if (foreground[y * w + x] == 0) continue;

        final pixel = src.getPixel(x, y);
        final maxChannel = math.max(
          pixel.r.toInt(),
          math.max(pixel.g.toInt(), pixel.b.toInt()),
        );
        final minChannel = math.min(
          pixel.r.toInt(),
          math.min(pixel.g.toInt(), pixel.b.toInt()),
        );

        checked++;

        if (maxChannel - minChannel <= _grayscaleTolerance) {
          grayscalePixels++;
        }

        if (checked >= 20000) break;
      }

      if (checked >= 20000) break;
    }

    return checked > 0 && grayscalePixels / checked >= 0.95;
  }

  static int _grayToRgb(int value) {
    final v = value.clamp(0, 255);
    return (v << 16) | (v << 8) | v;
  }

  static int _normalizeRgb(
    img.Pixel pixel,
    double step,
  ) {
    final r = pixel.r.toInt();
    final g = pixel.g.toInt();
    final b = pixel.b.toInt();

    final maxChannel = math.max(r, math.max(g, b));
    final minChannel = math.min(r, math.min(g, b));

    if (maxChannel - minChannel <= _grayscaleTolerance) {
      final luma = _luma(pixel);

      if (luma >= 245) return 0xFFFFFF;
      if (luma <= 10) return 0x000000;
    }

    final qr = ((r / step).floor() * step + step / 2)
        .clamp(0, 255)
        .toInt();
    final qg = ((g / step).floor() * step + step / 2)
        .clamp(0, 255)
        .toInt();
    final qb = ((b / step).floor() * step + step / 2)
        .clamp(0, 255)
        .toInt();

    return (qr << 16) | (qg << 8) | qb;
  }

  static int _rgbDist(int a, int b) {
    final ar = (a >> 16) & 0xFF;
    final ag = (a >> 8) & 0xFF;
    final ab = a & 0xFF;

    final br = (b >> 16) & 0xFF;
    final bg = (b >> 8) & 0xFF;
    final bb = b & 0xFF;

    final dr = ar - br;
    final dg = ag - bg;
    final db = ab - bb;

    return dr * dr + dg * dg + db * db;
  }

  static int _otsuThreshold(
    img.Image src,
    Uint8List foreground,
    int w,
    int h,
  ) {
    final histogram = List<int>.filled(256, 0);

    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        if (foreground[y * w + x] == 0) continue;
        histogram[_luma(src.getPixel(x, y))]++;
      }
    }

    var total = 0;
    var sumTotal = 0.0;

    for (var i = 0; i < 256; i++) {
      total += histogram[i];
      sumTotal += i * histogram[i];
    }

    if (total == 0) return 127;

    var weightBackground = 0;
    var sumBackground = 0.0;
    var bestThreshold = 127;
    var bestVariance = -1.0;

    for (var threshold = 0; threshold < 256; threshold++) {
      weightBackground += histogram[threshold];
      if (weightBackground == 0) continue;

      final weightForeground = total - weightBackground;
      if (weightForeground == 0) break;

      sumBackground += threshold * histogram[threshold];

      final meanBackground =
          sumBackground / weightBackground;
      final meanForeground =
          (sumTotal - sumBackground) / weightForeground;

      final variance = weightBackground *
          weightForeground *
          math.pow(meanBackground - meanForeground, 2);

      if (variance > bestVariance) {
        bestVariance = variance.toDouble();
        bestThreshold = threshold;
      }
    }

    return bestThreshold;
  }

  static int _luma(img.Pixel pixel) {
    return (0.299 * pixel.r +
            0.587 * pixel.g +
            0.114 * pixel.b)
        .round()
        .clamp(0, 255);
  }

  static List<TuftPoint> _pathForColorMask(
    Uint8List mask,
    int w,
    int h,
    double workW,
    double workH,
    double pitchPx,
  ) {
    final out = <TuftPoint>[];

    if (!_containsForeground(mask)) return out;

    final rowStep = math.max(1.0, pitchPx);
    var reverse = false;

    for (var y = 0.0; y < h; y += rowStep) {
      final row = y.round().clamp(0, h - 1);
      final runs = _findRuns(mask, w, row);

      if (runs.isEmpty) continue;

      final orderedRuns = reverse ? runs.reversed.toList() : runs;

      for (final run in orderedRuns) {
        final startX = run[0].toDouble();
        final endX = run[1].toDouble();
        final width = endX - startX;

        if (width <= 0) {
          out.add(
            _pxToMm(
              startX,
              y,
              w,
              h,
              workW,
              workH,
            ),
          );
          continue;
        }

        final count = math.max(1, (width / pitchPx).round());

        for (var i = 0; i <= count; i++) {
          final t = count == 0 ? 0.0 : i / count;
          final x = startX + width * t;

          out.add(
            _pxToMm(
              x,
              y,
              w,
              h,
              workW,
              workH,
            ),
          );
        }
      }

      reverse = !reverse;
    }

    return _removeTooClosePoints(
      out,
      pitchPx,
      w,
      h,
      workW,
      workH,
    );
  }

  static List<List<int>> _findRuns(
    Uint8List mask,
    int w,
    int y,
  ) {
    final runs = <List<int>>[];
    var x = 0;

    while (x < w) {
      while (x < w && mask[y * w + x] == 0) {
        x++;
      }

      if (x >= w) break;

      final start = x;

      while (x + 1 < w && mask[y * w + x + 1] == 1) {
        x++;
      }

      runs.add([start, x]);
      x++;
    }

    return runs;
  }

  static bool _containsForeground(Uint8List mask) {
    for (final value in mask) {
      if (value == 1) return true;
    }
    return false;
  }

  static List<TuftPoint> _removeTooClosePoints(
    List<TuftPoint> points,
    double pitchPx,
    int w,
    int h,
    double workW,
    double workH,
  ) {
    if (points.length < 2) return points;

    final pitchMmX = workW / math.max(1, w - 1);
    final pitchMmY = workH / math.max(1, h - 1);
    final pixelDistance = math.max(1.0, pitchPx * 0.75);
    final minDistanceSquared = pixelDistance * pixelDistance;

    final out = <TuftPoint>[];
    double? lastX;
    double? lastY;

    for (final point in points) {
      if (lastX == null || lastY == null) {
        out.add(point);
        lastX = point.x / pitchMmX;
        lastY = (workH - point.y) / pitchMmY;
        continue;
      }

      final px = point.x / pitchMmX;
      final py = (workH - point.y) / pitchMmY;
      final dx = px - lastX;
      final dy = py - lastY;
      final distanceSquared = dx * dx + dy * dy;

      if (distanceSquared >= minDistanceSquared) {
        out.add(point);
        lastX = px;
        lastY = py;
      }
    }

    return out;
  }

  static List<TuftPoint> _limitPoints(
    List<TuftPoint> points,
    int maxPoints,
  ) {
    if (maxPoints <= 0 || points.length <= maxPoints) {
      return points;
    }

    final result = <TuftPoint>[];
    final step = points.length / maxPoints;

    for (var i = 0; i < maxPoints; i++) {
      final index = (i * step)
          .floor()
          .clamp(0, points.length - 1);

      result.add(points[index]);
    }

    return result;
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
      x: px / math.max(1, w - 1) * workW,
      y: (1.0 - py / math.max(1, h - 1)) * workH,
    );
  }

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

    int? lastColorOrder;
    TuftPoint? previousPoint;

    for (final point in points) {
      final colorChanged =
          point.colorOrder != null &&
          point.colorOrder != lastColorOrder;

      if (colorChanged) {
        if (lastColorOrder != null) {
          if (embroidery) {
            b.writeln('M9 ; needle up');
          }

          b.writeln('G0 Z${safeZ.toStringAsFixed(2)}');

          final hex = point.colorValue != null
              ? '#${(point.colorValue! & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}'
              : '?';

          b.writeln(
            'M0 ; THREAD CHANGE -> '
            'color ${point.colorOrder} ($hex)',
          );
        }

        b.writeln(
          'G0 X${point.x.toStringAsFixed(2)} '
          'Y${point.y.toStringAsFixed(2)}',
        );

        if (embroidery) {
          b.writeln('M8 ; needle engage');
        }

        lastColorOrder = point.colorOrder;
      } else if (previousPoint == null) {
        b.writeln(
          'G0 X${point.x.toStringAsFixed(2)} '
          'Y${point.y.toStringAsFixed(2)}',
        );

        if (embroidery) {
          b.writeln('M8 ; needle engage');
        }
      }

      b.writeln(
        'G1 X${point.x.toStringAsFixed(2)} '
        'Y${point.y.toStringAsFixed(2)} '
        'F${feedMmMin.toStringAsFixed(0)}',
      );

      previousPoint = point;
    }

    if (embroidery) {
      b.writeln('M9 ; needle up');
      b.writeln('G0 Z${safeZ.toStringAsFixed(2)}');
    }

    b.writeln('M2');
    return b.toString();
  }
}

ExtractResult extractPathFromImageBytes(
  Uint8List bytes, {
  double pitch = 3.0,
}) {
  return PathExtractor.extractMultiColor(
    bytes,
    pitchMm: pitch.clamp(1.0, 5.0),
  );
}
