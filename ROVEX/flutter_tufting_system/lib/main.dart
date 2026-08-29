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
          final locale = loc.lang == AppLang.ar
              ? const Locale('ar')
              : const Locale('en');

          return MaterialApp(
            title: Branding.fullTitle,
            debugShowCheckedModeBanner: false,

            // English is the default language.
            // Arabic switches the app to Arabic.
            locale: locale,

            // Supported application languages.
            supportedLocales: const [
              Locale('en'),
              Locale('ar'),
            ],

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
                style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith<Color>(
                  (states) {
                    if (states.contains(WidgetState.disabled)) {
                     return HmiColors.panelAlt;
                }

            if (states.contains(WidgetState.pressed)) {
              return HmiColors.softkeyActive;
            }

            if (states.contains(WidgetState.hovered)) {
              return HmiColors.panelAlt;
            }

                return HmiColors.softkey;
          },
        ),

        foregroundColor: WidgetStateProperty.resolveWith<Color>(
          (states) {
            if (states.contains(WidgetState.disabled)) {
          return HmiColors.textMute;
            }

            return HmiColors.text;
          },
        ),
    
        overlayColor: WidgetStateProperty.all(
          HmiColors.accent.withValues(alpha: 0.10),
        ),

         elevation: WidgetStateProperty.resolveWith<double>(
           (states) {
            if (states.contains(WidgetState.pressed)) {
          return 0;
            }

            if (states.contains(WidgetState.hovered)) {
              return 4;
            }

            return 2;
          },
        ),
    
    padding: WidgetStateProperty.all(
      const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 14,
      ),
    ),

    minimumSize: WidgetStateProperty.all(
      const Size(120, 48),
    ),

    shape: WidgetStateProperty.all(
      RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(
          color: HmiColors.border,
          width: 1,
        ),
      ),
    ),

    textStyle: WidgetStateProperty.all(
      const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.4,
      ),
    ),

    animationDuration: const Duration(milliseconds: 120),
  ),
   ),
              inputDecorationTheme: const InputDecorationTheme(
                labelStyle: TextStyle(
                  color: HmiColors.textDim,
                ),
                hintStyle: TextStyle(
                  color: HmiColors.textMute,
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: HmiColors.border,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: HmiColors.gold,
                  ),
                ),
              ),
              useMaterial3: true,
            ),

            // Makes the entire application switch between
            // LTR for English and RTL for Arabic.
            builder: (context, child) {
              return Directionality(
                textDirection: loc.textDirection,
                child: child ?? const SizedBox.shrink(),
              );
            },

            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}
