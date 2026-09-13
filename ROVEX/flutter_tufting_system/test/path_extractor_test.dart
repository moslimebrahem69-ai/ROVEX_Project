import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:rovex/services/path_extractor.dart';

void main() {
  test('keeps foreground details at both image edges', () {
    final image = img.Image(width: 1000, height: 400);
    img.fill(image, color: img.ColorRgb8(255, 255, 255));
    img.drawLine(
      image,
      x1: 8,
      y1: 40,
      x2: 8,
      y2: 360,
      color: img.ColorRgb8(0, 0, 0),
      thickness: 8,
    );
    img.drawLine(
      image,
      x1: 991,
      y1: 40,
      x2: 991,
      y2: 360,
      color: img.ColorRgb8(0, 0, 0),
      thickness: 8,
    );

    final result = PathExtractor.extractMultiColor(
      Uint8List.fromList(img.encodePng(image)),
      workWidthMm: 600,
      workHeightMm: 400,
      pitchMm: 3,
    );

    expect(result.points, isNotEmpty);
    expect(result.points.any((point) => point.x < 30), isTrue);
    expect(result.points.any((point) => point.x > 570), isTrue);
  });
}
