import 'dart:typed_data';
import 'package:image/image.dart' as img;

class GCodeService {
  // 1. إعادة ضبط أبعاد الصورة إلى نسبة (1.5 * 2 متر)
  static img.Image resizeToTargetRatio(Uint8List imageBytes) {
    img.Image? original = img.decodeImage(imageBytes);
    if (original == null) throw Exception("تعذر قراءة الصورة");

    // تحجم الصورة بدقة مناسبة لتطابق مقاس 1.5متر × 2متر (1500px * 2000px)
    return img.copyResize(
      original,
      width: 1500,
      height: 2000,
      interpolation: img.Interpolation.cubic,
    );
  }

  // 2. توليد G-code يغطي الصورة بالكامل (Raster Scan) على السجاد
  static String generateFullImageGCode(img.Image image) {
    StringBuffer gcode = StringBuffer();

    // أبعاد السجاد بالمليمتر (1.5م = 1500مم ، 2م = 2000مم)
    double targetWidthMm = 1500.0;
    double targetHeightMm = 2000.0;

    double scaleX = targetWidthMm / image.width;
    double scaleY = targetHeightMm / image.height;

    // أوامر البداية للماكينة
    gcode.writeln("G21 ; استخدام المليمتر");
    gcode.writeln("G90 ; إحداثيات مطلقة");
    gcode.writeln("G0 Z5 F500 ; رفع الرأس بأمان");
    gcode.writeln("M3 S1000 ; تشغيل أداة الرسم/القص");

    // المسح الكامل للصورة بالكامل بدون حذف الخلفية (كل 5 بكسل خطوة)
    for (int y = 0; y < image.height; y += 5) {
      double currentY = y * scaleY;

      // حركة ترددية (ذهاب وإياد) لسرعة التنفيذ
      bool leftToRight = ((y / 5).floor() % 2 == 0);
      int startX = leftToRight ? 0 : image.width - 1;
      int endX = leftToRight ? image.width : -1;
      int stepX = leftToRight ? 5 : -5;

      for (int x = startX; x != endX; x += stepX) {
        double currentX = x * scaleX;

        // قراءة قيمة درجة اللون لكل نقطة في الصورة
        img.Pixel pixel = image.getPixel(x, y);
        double luminance = img.getLuminance(pixel) / 255.0;

        // تحديد عمق الغرزة/الرسم بناءً على درجة اللون (بدون استثناء أي جزء)
        double zDepth = -0.5 - ((1.0 - luminance) * 1.5);

        gcode.writeln("G1 X${currentX.toStringAsFixed(2)} Y${currentY.toStringAsFixed(2)} Z${zDepth.toStringAsFixed(2)} F1200");
      }
    }

    // إيقاف والعودة
    gcode.writeln("G0 Z10 F500");
    gcode.writeln("G0 X0 Y0");
    gcode.writeln("M5");

    return gcode.toString();
  }
}