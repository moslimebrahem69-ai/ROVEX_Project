import 'package:flutter/material.dart';

import '../config/branding.dart';

enum AppLang { en }

class L10n {
  final AppLang lang;
  const L10n(this.lang);

  bool get isRtl => false;

  String get code => 'EN';

  String t(String key) => _tables[AppLang.en]![key] ?? key;

  static const Map<AppLang, Map<String, String>> _tables = {
    AppLang.en: {
      'brand': Branding.appName,
      'brand_sub': 'Tufting Control',

      'machine': 'MACHINE',
      'program': 'PROGRAM',
      'design': 'DESIGN',
      'diagnosis': 'DIAGNOSIS',
      'setup': 'SETUP',
      'needle3d': 'NEEDLE 3D',
      'errors': 'ERRORS',
      'plc': 'PLC / M',

      'cycle_start': 'CYCLE START',
      'feed_hold': 'FEED HOLD',
      'cycle_stop': 'CYCLE STOP',
      'reset': 'RESET',
      'estop': 'E-STOP',
      'home': 'HOME / REF',

      'connect': 'CONNECT',
      'disc': 'DISC',
      'jog': 'JOG',

      'actual_pos': 'ACTUAL POSITION',
      'gcode': 'G-CODE',

      'extract_path': 'EXTRACT PATH FROM IMAGE',
      'optimize_load': 'OPTIMIZE → LOAD AUTO',

      'drop_image':
          'Drop image or DXF design here\nor click to browse',

      'language': 'Language',

      'needle_axis': 'Needle Z (embroidery)',

      'plc_title': 'PLC / M-CODE PROGRAMMER',
      'errors_title': 'ERROR ENCYCLOPEDIA',
      'needle3d_title': 'NEEDLE POSITION (3D)',

      'path_points': 'Tuft / stitch points',
      'work_area': 'Work area',
      'internal_sample': 'Built-in sample',

      'extracting_path':
          'Extracting high-accuracy path…',

      'extract_done':
          'Extracted {n} points (pitch {p} mm)',

      'extract_failed':
          'Extraction failed: {e}',

      'colors_detected': 'Colors detected',

      'machines_title': 'Machines (WiFi)',

      'machines_hint':
          'Connect to any machine on your WiFi network. '
          'Add each machine once, then tap it to switch — '
          'one phone, one app, several machines.',

      'connecting': 'CONNECTING…',

      'remove_machine': 'Remove machine',
      'add_machine': 'Add machine',
      'machine_name': 'Machine name',
      'connect_to_machine': 'CONNECT TO MACHINE',
    },
  };
}

class LocaleController extends ChangeNotifier {
  AppLang _lang = AppLang.en;

  AppLang get lang => _lang;

  L10n get l10n => const L10n(AppLang.en);

  TextDirection get textDirection => TextDirection.ltr;

  void setLang(AppLang lang) {
    // English only
    _lang = AppLang.en;
    notifyListeners();
  }

  void cycleLang() {
    // English only
    _lang = AppLang.en;
    notifyListeners();
  }
}