import 'package:flutter/material.dart';

import '../config/branding.dart';

enum AppLang { en, ar, de }

class L10n {
  final AppLang lang;
  const L10n(this.lang);

  bool get isRtl => lang == AppLang.ar;

  String get code {
    switch (lang) {
      case AppLang.en:
        return 'EN';
      case AppLang.ar:
        return 'ع';
      case AppLang.de:
        return 'DE';
    }
  }

  String t(String key) => _tables[lang]![key] ?? _tables[AppLang.en]![key] ?? key;

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
      'drop_image': 'Drop image or DXF design here\nor click to browse',
      'language': 'Language',
      'needle_axis': 'Needle Z (embroidery)',
      'plc_title': 'PLC / M-CODE PROGRAMMER',
      'errors_title': 'ERROR ENCYCLOPEDIA',
      'needle3d_title': 'NEEDLE POSITION (3D)',
      'path_points': 'Tuft / stitch points',
      'work_area': 'Work area',
      'internal_sample': 'Built-in sample',
      'extracting_path': 'Extracting high-accuracy path…',
      'extract_done': 'Extracted {n} points (pitch {p} mm)',
      'extract_failed': 'Extraction failed: {e}',
      'colors_detected': 'Colors detected',
      'machines_title': 'Machines (WiFi)',
      'machines_hint':
          'Connect to any machine on your WiFi network. Add each machine once, then tap it to switch — one phone, one app, several machines.',
      'connecting': 'CONNECTING…',
      'remove_machine': 'Remove machine',
      'add_machine': 'Add machine',
      'machine_name': 'Machine name',
      'connect_to_machine': 'CONNECT TO MACHINE',
    },
    AppLang.ar: {
      'brand': Branding.appName,
      'brand_sub': 'نظام تطريز وسجاد',
      'machine': 'الماكينة',
      'program': 'البرنامج',
      'design': 'التصميم',
      'diagnosis': 'التشخيص',
      'setup': 'الإعداد',
      'needle3d': 'الإبرة 3D',
      'errors': 'الأخطاء',
      'plc': 'PLC / M',
      'cycle_start': 'تشغيل الدورة',
      'feed_hold': 'إيقاف تغذية',
      'cycle_stop': 'إيقاف الدورة',
      'reset': 'إعادة ضبط',
      'estop': 'إيقاف طارئ',
      'home': 'رجوع / مرجع',
      'connect': 'توصيل',
      'disc': 'فصل',
      'jog': 'تحريك يدوي',
      'actual_pos': 'الموضع الفعلي',
      'gcode': 'كود G',
      'extract_path': 'استخراج المسار من الرسمة',
      'optimize_load': 'تحسين → تحميل أوتو',
      'drop_image': 'أسقط صورة أو تصميم DXF هنا\nأو اضغط للاختيار',
      'language': 'اللغة',
      'needle_axis': 'محور الإبرة Z (تطريز)',
      'plc_title': 'برمجة PLC / أكواد M',
      'errors_title': 'موسوعة الأخطاء',
      'needle3d_title': 'موضع الإبرة (مجسم 3D)',
      'path_points': 'نقاط التطريز/الوبرة',
      'work_area': 'منطقة العمل',
      'internal_sample': 'مشروع داخلي',
      'extracting_path': 'جاري استخراج مسار بدقة عالية…',
      'extract_done': 'تم الاستخراج: {n} نقطة (pitch {p} mm)',
      'extract_failed': 'فشل الاستخراج: {e}',
      'colors_detected': 'الألوان المكتشفة',
      'machines_title': 'المكينات (واي فاي)',
      'machines_hint':
          'اتصل بأي مكينة على شبكة الواي فاي بتاعتك. ضيف كل مكينة مرة واحدة، وبعدين دوس عليها للتبديل — تليفون واحد، برنامج واحد، أكتر من مكينة.',
      'connecting': 'جاري الاتصال…',
      'remove_machine': 'حذف المكينة',
      'add_machine': 'إضافة مكينة',
      'machine_name': 'اسم المكينة',
      'connect_to_machine': 'الاتصال بالمكينة',
    },
    AppLang.de: {
      'brand': Branding.appName,
      'brand_sub': 'Tufting-Steuerung',
      'machine': 'MASCHINE',
      'program': 'PROGRAMM',
      'design': 'DESIGN',
      'diagnosis': 'DIAGNOSE',
      'setup': 'SETUP',
      'needle3d': 'NADEL 3D',
      'errors': 'FEHLER',
      'plc': 'PLC / M',
      'cycle_start': 'ZYKLUS START',
      'feed_hold': 'VORSCHUB HALT',
      'cycle_stop': 'ZYKLUS STOP',
      'reset': 'RESET',
      'estop': 'NOT-AUS',
      'home': 'HOME / REF',
      'connect': 'VERBINDEN',
      'disc': 'TRENNEN',
      'jog': 'JOG',
      'actual_pos': 'IST-POSITION',
      'gcode': 'G-CODE',
      'extract_path': 'PFAD AUS BILD EXTRAHIEREN',
      'optimize_load': 'OPTIMIEREN → AUTO LADEN',
      'drop_image': 'Bild oder DXF-Design hier ablegen\noder klicken',
      'language': 'Sprache',
      'needle_axis': 'Nadel-Z (Stickerei)',
      'plc_title': 'PLC / M-CODE PROGRAMMIERER',
      'errors_title': 'FEHLER-ENCYCLOPÄDIE',
      'needle3d_title': 'NADELPOSITION (3D)',
      'path_points': 'Tuft-/Stichpunkte',
      'work_area': 'Arbeitsbereich',
      'internal_sample': 'Integriertes Muster',
      'extracting_path': 'Hochgenauer Pfad wird extrahiert…',
      'extract_done': '{n} Punkte extrahiert (Teilung {p} mm)',
      'extract_failed': 'Extraktion fehlgeschlagen: {e}',
      'colors_detected': 'Erkannte Farben',
      'machines_title': 'Maschinen (WLAN)',
      'machines_hint':
          'Mit jeder Maschine im WLAN verbinden. Jede Maschine einmal hinzufügen, dann zum Wechseln antippen.',
      'connecting': 'VERBINDE…',
      'remove_machine': 'Maschine entfernen',
      'add_machine': 'Maschine hinzufügen',
      'machine_name': 'Maschinenname',
      'connect_to_machine': 'MIT MASCHINE VERBINDEN',
    },
  };
}

class LocaleController extends ChangeNotifier {
  AppLang _lang = AppLang.en;
  AppLang get lang => _lang;
  L10n get l10n => L10n(_lang);
  TextDirection get textDirection =>
      _lang == AppLang.ar ? TextDirection.rtl : TextDirection.ltr;

  void setLang(AppLang lang) {
    _lang = lang;
    notifyListeners();
  }

  void cycleLang() {
    switch (_lang) {
      case AppLang.en:
        _lang = AppLang.ar;
        break;
      case AppLang.ar:
        _lang = AppLang.de;
        break;
      case AppLang.de:
        _lang = AppLang.en;
        break;
    }
    notifyListeners();
  }
}
