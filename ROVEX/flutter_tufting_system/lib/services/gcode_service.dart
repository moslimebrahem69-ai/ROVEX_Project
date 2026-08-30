import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Service responsible for preparing images and generating G-code.
class GCodeService {
  // ---------------------------------------------------------------------------
  // Image configuration
  // ---------------------------------------------------------------------------

  static const int _targetImageWidth = 1500;
  static const int _targetImageHeight = 2000;

  // ---------------------------------------------------------------------------
  // Machine/work-area configuration
  // ---------------------------------------------------------------------------

  static const double _workWidthMm = 1500.0;
  static const double _workHeightMm = 2000.0;

  static const double _safeZ = 5.0;
  static const double _cutZ = -2.0;

  static const int _rasterStep = 8;

  static const int _spindleSpeed = 1000;
  static const int _rapidFeedRate = 3000;
  static const int _safeZFeedRate = 500;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Decodes the image, crops it to the required aspect ratio,
  /// then resizes it to the target resolution.
  static img.Image resizeToTargetRatio(Uint8List imageBytes) {
    final original = img.decodeImage(imageBytes);

    if (original == null) {
      throw Exception('Failed to decode image');
    }

    final cropRect = _calculateCenteredCrop(
      imageWidth: original.width,
      imageHeight: original.height,
      targetWidth: _targetImageWidth,
      targetHeight: _targetImageHeight,
    );

    final cropped = img.copyCrop(
      original,
      x: cropRect.x,
      y: cropRect.y,
      width: cropRect.width,
      height: cropRect.height,
    );

    return img.copyResize(
      cropped,
      width: _targetImageWidth,
      height: _targetImageHeight,
      interpolation: img.Interpolation.cubic,
    );
  }

  /// Generates G-code for the complete image using a color-grouped
  /// raster-style toolpath.
  static String generateFullImageGCode(img.Image image) {
    final buffer = StringBuffer();

    final scaleX = _workWidthMm / image.width;
    final scaleY = _workHeightMm / image.height;

    _writeHeader(buffer);

    final colorGroups = _extractColorGroups(
      image,
      scaleX: scaleX,
      scaleY: scaleY,
    );

    _writeColorGroups(buffer, colorGroups);

    _writeFooter(buffer);

    return buffer.toString();
  }

  // ---------------------------------------------------------------------------
  // Image processing
  // ---------------------------------------------------------------------------

  static _CropRect _calculateCenteredCrop({
    required int imageWidth,
    required int imageHeight,
    required int targetWidth,
    required int targetHeight,
  }) {
    final targetAspectRatio = targetWidth / targetHeight;
    final imageAspectRatio = imageWidth / imageHeight;

    if (imageAspectRatio > targetAspectRatio) {
      final cropWidth = (imageHeight * targetAspectRatio).round();

      return _CropRect(
        x: ((imageWidth - cropWidth) / 2).round(),
        y: 0,
        width: cropWidth,
        height: imageHeight,
      );
    }

    final cropHeight = (imageWidth / targetAspectRatio).round();

    return _CropRect(
      x: 0,
      y: ((imageHeight - cropHeight) / 2).round(),
      width: imageWidth,
      height: cropHeight,
    );
  }

  // ---------------------------------------------------------------------------
  // Color extraction
  // ---------------------------------------------------------------------------

  static Map<int, List<_GCodePoint>> _extractColorGroups(
    img.Image image, {
    required double scaleX,
    required double scaleY,
  }) {
    final groups = <int, List<_GCodePoint>>{};

    for (var y = 0; y < image.height; y += _rasterStep) {
      for (var x = 0; x < image.width; x += _rasterStep) {
        final pixel = image.getPixel(x, y);
        final color = _quantizeColor(pixel);

        groups
            .putIfAbsent(color, () => <_GCodePoint>[])
            .add(
              _GCodePoint(
                x: x * scaleX,
                y: y * scaleY,
              ),
            );
      }
    }

    return groups;
  }

  /// Reduces the image color depth to keep the number of color groups
  /// manageable for G-code generation.
  static int _quantizeColor(img.Pixel pixel) {
    final red = _quantizeChannel(pixel.r);
    final green = _quantizeChannel(pixel.g);
    final blue = _quantizeChannel(pixel.b);

    return (red << 16) | (green << 8) | blue;
  }

  static int _quantizeChannel(num value) {
    return (value / 64).round() * 64;
  }

  // ---------------------------------------------------------------------------
  // G-code generation
  // ---------------------------------------------------------------------------

  static void _writeHeader(StringBuffer buffer) {
    buffer
      ..writeln('; FULL CARPET RASTER SCAN 1.5m x 2m')
      ..writeln('G21')
      ..writeln('G90')
      ..writeln('G0 Z${_format(_safeZ)} F$_safeZFeedRate');
  }

  static void _writeColorGroups(
    StringBuffer buffer,
    Map<int, List<_GCodePoint>> colorGroups,
  ) {
    var colorIndex = 1;

    for (final points in colorGroups.values) {
      _writeColorGroup(
        buffer,
        colorIndex: colorIndex,
        points: points,
      );

      colorIndex++;
    }
  }

  static void _writeColorGroup(
    StringBuffer buffer, {
    required int colorIndex,
    required List<_GCodePoint> points,
  }) {
    buffer
      ..writeln('(--- COLOR $colorIndex START ---)')
      ..writeln('M0 ; Pause for color change $colorIndex')
      ..writeln('M3 S$_spindleSpeed');

    for (final point in points) {
      _writePoint(buffer, point);
    }
  }

  static void _writePoint(
    StringBuffer buffer,
    _GCodePoint point,
  ) {
    buffer
      ..writeln(
        'G0 X${_format(point.x)} Y${_format(point.y)}',
      )
      ..writeln(
        'G1 Z${_format(_cutZ)} F$_rapidFeedRate',
      )
      ..writeln(
        'G0 Z${_format(_safeZ)} F$_rapidFeedRate',
      );
  }

  static void _writeFooter(StringBuffer buffer) {
    buffer
      ..writeln('G0 Z${_format(10.0)} F$_safeZFeedRate')
      ..writeln('G0 X0 Y0')
      ..writeln('M5');
  }

  // ---------------------------------------------------------------------------
  // Formatting
  // ---------------------------------------------------------------------------

  static String _format(double value) {
    return value.toStringAsFixed(2);
  }
}

// =============================================================================
// Internal models
// =============================================================================

class _GCodePoint {
  final double x;
  final double y;

  const _GCodePoint({
    required this.x,
    required this.y,
  });
}

class _CropRect {
  final int x;
  final int y;
  final int width;
  final int height;

  const _CropRect({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });
}
