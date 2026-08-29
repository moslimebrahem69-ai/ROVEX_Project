import 'dart:typed_data';
import 'package:image/image.dart' as img;

class GCodeService {
  static img.Image resizeToTargetRatio(Uint8List imageBytes) {
    img.Image? original = img.decodeImage(imageBytes);
    if (original == null) throw Exception("Failed to decode image");

    int targetWidth = 1500;
    int targetHeight = 2000;
    double targetAspect = targetWidth / targetHeight; // 1.5 / 2.0 = 0.75

    int cropWidth = original.width;
    int cropHeight = original.height;
    int offsetX = 0;
    int offsetY = 0;

    if (original.width / original.height > targetAspect) {
      cropWidth = (original.height * targetAspect).round();
      offsetX = ((original.width - cropWidth) / 2).round();
    } else {
      cropHeight = (original.width / targetAspect).round();
      offsetY = ((original.height - cropHeight) / 2).round();
    }

    img.Image cropped = img.copyCrop(
      original,
      x: offsetX,
      y: offsetY,
      width: cropWidth,
      height: cropHeight,
    );

    return img.copyResize(
      cropped,
      width: targetWidth,
      height: targetHeight,
      interpolation: img.Interpolation.cubic,
    );
  }

  static String generateFullImageGCode(img.Image image) {
    StringBuffer gcode = StringBuffer();

    double targetWidthMm = 1500.0;
    double targetHeightMm = 2000.0;

    double scaleX = targetWidthMm / image.width;
    double scaleY = targetHeightMm / image.height;

    Map<int, List<Map<String, double>>> colorGroups = {};

    int step = 8;

    for (int y = 0; y < image.height; y += step) {
      for (int x = 0; x < image.width; x += step) {
        img.Pixel pixel = image.getPixel(x, y);
        
        int r = (pixel.r / 64).round() * 64;
        int g = (pixel.g / 64).round() * 64;
        int b = (pixel.b / 64).round() * 64;
        int colorKey = (r << 16) | (g << 8) | b;

        double posX = x * scaleX;
        double posY = y * scaleY;

        if (!colorGroups.containsKey(colorKey)) {
          colorGroups[colorKey] = [];
        }

        colorGroups[colorKey]!.add({'x': posX, 'y': posY});
      }
    }

    gcode.writeln("G21");
    gcode.writeln("G90");
    gcode.writeln("G0 Z5 F500");

    int colorIndex = 1;
    colorGroups.forEach((colorHex, points) {
      gcode.writeln("(--- COLOR SECTION $colorIndex ---)");
      gcode.writeln("M0 ; Pause for changing thread/color $colorIndex");
      gcode.writeln("M3 S1000");

      for (var pt in points) {
        gcode.writeln("G0 X${pt['x']!.toStringAsFixed(2)} Y${pt['y']!.toStringAsFixed(2)}");
        gcode.writeln("G1 Z-2.00 F1200");
        gcode.writeln("G0 Z5.00 F500");
      }

      colorIndex++;
    });

    gcode.writeln("G0 Z10 F500");
    gcode.writeln("G0 X0 Y0");
    gcode.writeln("M5");

    return gcode.toString();
  }
}