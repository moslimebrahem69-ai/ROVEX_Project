/// Single source of truth for the app's name/branding text.
///
/// To rename the app later: edit ONLY the values below.
/// (The Windows .exe title/metadata and web manifest.json are separate
/// native files — see BRANDING_README.md at the project root for the
/// two extra spots to update if you rebrand again.)
class Branding {
  Branding._();

  static const String appName = 'ROVEX';
  static const String appTagline = 'Multi-Machine Tufting Control';

  /// Shown together, e.g. in the window title bar.
  static const String fullTitle = '$appName · $appTagline';
}
