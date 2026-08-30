class SampleProject {
  final String id;
  final String titleEn;
  final String assetPath;
  final String blurbEn;

  const SampleProject({
    required this.id,
    required this.titleEn,
    required this.assetPath,
    required this.blurbEn,
  });

  String get title => titleEn;

  String get blurb => blurbEn;

  static const List<SampleProject> catalog = [
    SampleProject(
      id: 'cartouche_dtu',
      titleEn: 'DTU Cartouche',
      assetPath: 'assets/designs/pharaoh_cartouche_dtu.png',
      blurbEn: 'Sample project — high-accuracy path extract',
    ),
  ];
}