import 'package:flutter/material.dart';

import '../config/branding.dart';

enum AppLang { en, ar }

class L10n {
  final AppLang lang;

  const L10n(this.lang);

  bool get isRtl => lang == AppLang.ar;

  String get code => lang == AppLang.en ? 'EN' : 'AR';

  String t(String key) {
    return _tables[lang]?[key] ?? _tables[AppLang.en]?[key] ?? key;
  }

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
      'mcode': 'M-CODE',
      'view_code': 'VIEW CODE',
      'code_studio_title': 'PROGRAM CODE',
      'copy_code': 'COPY',
      'regenerate': '↻ REGENERATE',
      'copied': 'Copied to clipboard',
      'no_mcode': 'No M-codes in the current program.',
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
          'Connect to any machine on your WiFi network. '
          'Add each machine once, then tap it to switch — '
          'one phone, one app, several machines.',
      'connecting': 'CONNECTING…',
      'remove_machine': 'Remove machine',
      'add_machine': 'Add machine',
      'machine_name': 'Machine name',
      'connect_to_machine': 'CONNECT TO MACHINE',
    },
    AppLang.ar: {
      'brand': Branding.appName,
      'brand_sub': 'نظام التحكم في التطريز',
      'machine': 'الماكينة',
      'program': 'البرنامج',
      'design': 'التصميم',
      'diagnosis': 'التشخيص',
      'setup': 'الإعداد',
      'needle3d': 'الإبرة 3D',
      'errors': 'الأخطاء',
      'plc': 'PLC / M',
      'cycle_start': 'بدء الدورة',
      'feed_hold': 'إيقاف التغذية',
      'cycle_stop': 'إيقاف الدورة',
      'reset': 'إعادة ضبط',
      'estop': 'إيقاف طارئ',
      'home': 'المرجع / HOME',
      'connect': 'اتصال',
      'disc': 'فصل',
      'jog': 'تحريك يدوي',
      'actual_pos': 'الموضع الفعلي',
      'gcode': 'G-CODE',
      'mcode': 'M-CODE',
      'view_code': 'عرض الكود',
      'code_studio_title': 'كود البرنامج',
      'copy_code': 'نسخ',
      'regenerate': '↻ إعادة توليد',
      'copied': 'تم النسخ إلى الحافظة',
      'no_mcode': 'لا توجد أوامر M في البرنامج الحالي.',
      'extract_path': 'استخراج المسار من الصورة',
      'optimize_load': 'تحسين → تحميل تلقائي',
      'drop_image': 'ضع تصميم الصورة أو DXF هنا\nأو اضغط للتصفح',
      'language': 'اللغة',
      'needle_axis': 'محور الإبرة Z (التطريز)',
      'plc_title': 'مبرمج PLC / M-CODE',
      'errors_title': 'موسوعة الأخطاء',
      'needle3d_title': 'موضع الإبرة (3D)',
      'path_points': 'نقاط الوبر / الغرز',
      'work_area': 'منطقة العمل',
      'internal_sample': 'نموذج مدمج',
      'extracting_path': 'جاري استخراج المسار بدقة عالية…',
      'extract_done': 'تم استخراج {n} نقطة (المسافة {p} مم)',
      'extract_failed': 'فشل استخراج المسار: {e}',
      'colors_detected': 'الألوان المكتشفة',
      'machines_title': 'الماكينات (WiFi)',
      'machines_hint':
          'اتصل بأي ماكينة على شبكة WiFi الخاصة بك. '
          'أضف كل ماكينة مرة واحدة، ثم اضغط عليها للتبديل — '
          'هاتف واحد، تطبيق واحد، عدة ماكينات.',
      'connecting': 'جاري الاتصال…',
      'remove_machine': 'إزالة الماكينة',
      'add_machine': 'إضافة ماكينة',
      'machine_name': 'اسم الماكينة',
      'connect_to_machine': 'الاتصال بالماكينة',
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
    if (_lang == lang) {
      return;
    }

    _lang = lang;
    notifyListeners();
  }

  void cycleLang() {
    _lang = _lang == AppLang.en ? AppLang.ar : AppLang.en;
    notifyListeners();
  }
}