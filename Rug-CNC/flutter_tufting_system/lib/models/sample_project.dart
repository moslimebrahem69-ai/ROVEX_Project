import '../l10n/l10n.dart';

class SampleProject {
  final String id;
  final String titleAr;
  final String titleEn;
  final String assetPath;
  final String blurbAr;
  final String blurbEn;

  const SampleProject({
    required this.id,
    required this.titleAr,
    required this.titleEn,
    required this.assetPath,
    required this.blurbAr,
    required this.blurbEn,
  });

  String title(AppLang lang) =>
      lang == AppLang.ar ? titleAr : titleEn;

  String blurb(AppLang lang) =>
      lang == AppLang.ar ? blurbAr : blurbEn;

  static const catalog = <SampleProject>[
    SampleProject(
      id: 'cartouche_dtu',
      titleAr: 'خرطوشة DTU',
      titleEn: 'DTU Cartouche',
      assetPath: 'assets/designs/pharaoh_cartouche_dtu.png',
      blurbAr: 'مشروع تجريبي — استخراج مسار عالي الدقة',
      blurbEn: 'Sample project — high-accuracy path extract',
    ),
  ];
}
