class TuftPoint {
  final double x;
  final double y;

  /// ARGB color of the thread/region this point belongs to.
  /// Null means "no color info" (e.g. legacy/manual points).
  final int? colorValue;

  /// 1-based sequence of the color group this point belongs to
  /// (all points of colorOrder == 1 are stitched fully before any
  /// point of colorOrder == 2, and so on). Used to drive thread
  /// changes and the "color N of M" progress readout.
  final int? colorOrder;

  const TuftPoint({
    required this.x,
    required this.y,
    this.colorValue,
    this.colorOrder,
  });

  factory TuftPoint.fromJson(Map<String, dynamic> json) => TuftPoint(
        x: (json['x'] as num).toDouble(),
        y: (json['y'] as num).toDouble(),
        colorValue: json['colorValue'] as int?,
        colorOrder: json['colorOrder'] as int?,
      );

  Map<String, dynamic> toJson() => {
        'x': x,
        'y': y,
        if (colorValue != null) 'colorValue': colorValue,
        if (colorOrder != null) 'colorOrder': colorOrder,
      };
}

/// Summary of one color/thread group inside an extracted design.
/// `order` is 1-based and matches [TuftPoint.colorOrder].
class ColorGroup {
  final int colorValue; // 0xAARRGGBB
  final int order;
  final int pointCount;

  const ColorGroup({
    required this.colorValue,
    required this.order,
    required this.pointCount,
  });
}

/// Result of extracting a stitch path from an image or a DXF file:
/// the ordered points (grouped color-by-color) plus a summary of each
/// color/thread group.
class ExtractResult {
  final List<TuftPoint> points;
  final List<ColorGroup> colors;
  const ExtractResult({required this.points, required this.colors});
}

class Design {
  final String id;
  final String name;
  final String description;
  final List<TuftPoint> tufts;
  final DateTime createdAt;
  final String? imagePath;
  final int? imageWidth;
  final int? imageHeight;

  Design({
    required this.id,
    required this.name,
    required this.description,
    required this.tufts,
    DateTime? createdAt,
    this.imagePath,
    this.imageWidth,
    this.imageHeight,
  }) : createdAt = createdAt ?? DateTime.now();

  int get pointCount => tufts.length;

  factory Design.fromJson(Map<String, dynamic> json) => Design(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String? ?? '',
        tufts: (json['tufts'] as List<dynamic>? ?? [])
            .map((e) => TuftPoint.fromJson(e as Map<String, dynamic>))
            .toList(),
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : DateTime.now(),
        imagePath: json['imagePath'] as String?,
        imageWidth: json['imageWidth'] as int?,
        imageHeight: json['imageHeight'] as int?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'tufts': tufts.map((t) => t.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'imagePath': imagePath,
        'imageWidth': imageWidth,
        'imageHeight': imageHeight,
      };

  Design copyWith({
    String? id,
    String? name,
    String? description,
    List<TuftPoint>? tufts,
    DateTime? createdAt,
    String? imagePath,
    int? imageWidth,
    int? imageHeight,
  }) {
    return Design(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      tufts: tufts ?? this.tufts,
      createdAt: createdAt ?? this.createdAt,
      imagePath: imagePath ?? this.imagePath,
      imageWidth: imageWidth ?? this.imageWidth,
      imageHeight: imageHeight ?? this.imageHeight,
    );
  }
}
