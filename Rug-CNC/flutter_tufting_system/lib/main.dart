import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'config/branding.dart';
import 'l10n/l10n.dart';
import 'screens/splash_screen.dart';
import 'services/machine_service.dart';
import 'theme/hmi_colors.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ROVEXApp());
}

class ROVEXApp extends StatelessWidget {
  const ROVEXApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MachineService()),
        ChangeNotifierProvider(create: (_) => LocaleController()),
      ],
      child: Consumer<LocaleController>(
        builder: (context, loc, _) {
          return MaterialApp(
            title: Branding.fullTitle,
            debugShowCheckedModeBanner: false,
            locale: Locale(loc.lang == AppLang.ar
                ? 'ar'
                : (loc.lang == AppLang.de ? 'de' : 'en')),
            theme: ThemeData(
              brightness: Brightness.dark,
              scaffoldBackgroundColor: HmiColors.bg,
              colorScheme: const ColorScheme.dark(
            primary: HmiColors.accent,
            secondary: HmiColors.softkeyActive,
            surface: HmiColors.panel,
            surfaceContainerHighest: HmiColors.panelAlt,
            outline: HmiColors.border,
            error: HmiColors.alarm,
          ),
              elevatedButtonTheme: ElevatedButtonThemeData(
  style: ElevatedButton.styleFrom(
    backgroundColor: HmiColors.softkey,
    foregroundColor: HmiColors.text,
    disabledBackgroundColor: HmiColors.panelAlt,
    disabledForegroundColor: HmiColors.textMute,
    elevation: 2,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: const BorderSide(
        color: HmiColors.border,
      ),
    ),
    textStyle: const TextStyle(
      fontWeight: FontWeight.w700,
    ),
  ),
),
              inputDecorationTheme: const InputDecorationTheme(
                labelStyle: TextStyle(color: HmiColors.textDim),
                hintStyle: TextStyle(color: HmiColors.textMute),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: HmiColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: HmiColors.gold),
                ),
              ),
              useMaterial3: true,
            ),
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}
