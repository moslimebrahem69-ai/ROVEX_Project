# تغيير اسم التطبيق / اللوجو لاحقًا

الاسم الحالي مؤقت: **ROVEX**. لو حبيت تغيّره لاسم نهائي، دول الأماكن (كلها بسيطة):

## 1) الاسم الظاهر في التطبيق (المكان الأساسي)
عدّل الملف ده بس:
```
flutter_tufting_system/lib/config/branding.dart
```
غيّر قيمة `appName` و `appTagline` وخلاص — هيتغير عنوان النافذة وكل شاشات الواجهة تلقائيًا.

## 2) اللوجو والأيقونة
- اللوجو الظاهر جوه التطبيق:
  `flutter_tufting_system/assets/brand/dar_kareem_logo.png`
  `flutter_tufting_system/assets/brand/dar_kareem_mark.png`
  (الاسم القديم للملف اتسيب عشان مانلمسش pubspec.yaml — تقدر تستبدل الصورة نفسها بنفس الاسم، أو تغيّر المسار في pubspec.yaml + splash_screen.dart لو عايز اسم ملف جديد).
- أيقونة الويب: `flutter_tufting_system/web/icons/Icon-*.png` و `web/favicon.png`
- أيقونة ويندوز: `flutter_tufting_system/windows/runner/resources/app_icon.ico`

لو عندك صورة لوجو جاهزة، ابعتهالي وهبدلها في الأماكن دي كلها بمقاساتها الصح تلقائيًا.

## 3) أماكن إضافية (تجميلية، مش لازم تتغير أول بأول)
- `flutter_tufting_system/web/manifest.json` (اسم PWA)
- `flutter_tufting_system/windows/runner/Runner.rc` (بيانات ملف EXE على ويندوز)
- `flutter_tufting_system/windows/runner/main.cpp` (عنوان نافذة ويندوز الأصلي، سطر `window.Create(...)`)
