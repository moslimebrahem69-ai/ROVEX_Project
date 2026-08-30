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
            locale: locale,
            supportedLocales: const [
              Locale('en'),
              Locale('ar'),
            ],
            theme: ThemeData(
              useMaterial3: true,
              brightness: Brightness.dark,

              scaffoldBackgroundColor: HmiColors.bg,

              colorScheme: const ColorScheme.dark(
                primary: HmiColors.accent,
                onPrimary: HmiColors.text,
                secondary: HmiColors.softkeyActive,
                onSecondary: HmiColors.text,
                surface: HmiColors.panel,
                onSurface: HmiColors.text,
                surfaceContainerHighest: HmiColors.panelAlt,
                outline: HmiColors.border,
                error: HmiColors.alarm,
                onError: HmiColors.text,
              ),

              dividerTheme: const DividerThemeData(
                color: HmiColors.border,
                thickness: 1,
                space: 1,
              ),

              iconTheme: const IconThemeData(
                color: HmiColors.textDim,
                size: 20,
              ),

              textTheme: const TextTheme(
                bodyLarge: TextStyle(
                  color: HmiColors.text,
                  fontSize: 14,
                ),
                bodyMedium: TextStyle(
                  color: HmiColors.textDim,
                  fontSize: 13,
                ),
                bodySmall: TextStyle(
                  color: HmiColors.textMute,
                  fontSize: 11,
                ),
                titleMedium: TextStyle(
                  color: HmiColors.text,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
                titleSmall: TextStyle(
                  color: HmiColors.textDim,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),

              appBarTheme: const AppBarTheme(
                backgroundColor: HmiColors.panel,
                foregroundColor: HmiColors.text,
                elevation: 0,
                surfaceTintColor: Colors.transparent,
              ),

              cardTheme: CardThemeData(
                color: HmiColors.panel,
                elevation: 0,
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: const BorderSide(
                    color: HmiColors.border,
                    width: 1,
                  ),
                ),
              ),

              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ButtonStyle(
                  backgroundColor:
                      WidgetStateProperty.resolveWith<Color>((states) {
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
                  }),
                  foregroundColor:
                      WidgetStateProperty.resolveWith<Color>((states) {
                    if (states.contains(WidgetState.disabled)) {
                      return HmiColors.textMute;
                    }

                    return HmiColors.text;
                  }),
                  overlayColor: WidgetStateProperty.all(
                    HmiColors.accent.withValues(alpha: 0.10),
                  ),
                  elevation:
                      WidgetStateProperty.resolveWith<double>((states) {
                    if (states.contains(WidgetState.pressed)) {
                      return 0;
                    }

                    if (states.contains(WidgetState.hovered)) {
                      return 3;
                    }

                    return 1;
                  }),
                  padding: WidgetStateProperty.all(
                    const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 13,
                    ),
                  ),
                  minimumSize: WidgetStateProperty.all(
                    const Size(110, 46),
                  ),
                  shape: WidgetStateProperty.all(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: const BorderSide(
                        color: HmiColors.border,
                        width: 1,
                      ),
                    ),
                  ),
                  textStyle: WidgetStateProperty.all(
                    const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                  animationDuration: const Duration(
                    milliseconds: 120,
                  ),
                ),
              ),

              outlinedButtonTheme: OutlinedButtonThemeData(
                style: ButtonStyle(
                  foregroundColor: WidgetStateProperty.all(
                    HmiColors.text,
                  ),
                  side: WidgetStateProperty.resolveWith<BorderSide>(
                    (states) {
                      if (states.contains(WidgetState.hovered) ||
                          states.contains(WidgetState.pressed)) {
                        return const BorderSide(
                          color: HmiColors.accent,
                          width: 1.2,
                        );
                      }

                      return const BorderSide(
                        color: HmiColors.border,
                        width: 1,
                      );
                    },
                  ),
                  backgroundColor: WidgetStateProperty.resolveWith<Color>(
                    (states) {
                      if (states.contains(WidgetState.pressed)) {
                        return HmiColors.softkeyActive;
                      }

                      if (states.contains(WidgetState.hovered)) {
                        return HmiColors.panelAlt;
                      }

                      return Colors.transparent;
                    },
                  ),
                  shape: WidgetStateProperty.all(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),

              inputDecorationTheme: InputDecorationTheme(
                filled: true,
                fillColor: HmiColors.panelAlt,
                labelStyle: const TextStyle(
                  color: HmiColors.textDim,
                ),
                hintStyle: const TextStyle(
                  color: HmiColors.textMute,
                ),
                prefixIconColor: HmiColors.textDim,
                suffixIconColor: HmiColors.textDim,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(7),
                  borderSide: const BorderSide(
                    color: HmiColors.border,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(7),
                  borderSide: const BorderSide(
                    color: HmiColors.accent,
                    width: 1.2,
                  ),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(7),
                  borderSide: const BorderSide(
                    color: HmiColors.alarm,
                  ),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(7),
                  borderSide: const BorderSide(
                    color: HmiColors.alarm,
                    width: 1.2,
                  ),
                ),
              ),

              sliderTheme: SliderThemeData(
                activeTrackColor: HmiColors.accent,
                inactiveTrackColor: HmiColors.border,
                thumbColor: HmiColors.accent,
                overlayColor: HmiColors.accent.withValues(alpha: 0.12),
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 6,
                ),
              ),

              checkboxTheme: CheckboxThemeData(
                fillColor: WidgetStateProperty.resolveWith<Color>(
                  (states) {
                    if (states.contains(WidgetState.selected)) {
                      return HmiColors.accent;
                    }

                    return HmiColors.panelAlt;
                  },
                ),
                checkColor: WidgetStateProperty.all(
                  HmiColors.bg,
                ),
                side: const BorderSide(
                  color: HmiColors.border,
                ),
              ),

              switchTheme: SwitchThemeData(
                thumbColor: WidgetStateProperty.resolveWith<Color>(
                  (states) {
                    if (states.contains(WidgetState.selected)) {
                      return HmiColors.text;
                    }

                    return HmiColors.textMute;
                  },
                ),
                trackColor: WidgetStateProperty.resolveWith<Color>(
                  (states) {
                    if (states.contains(WidgetState.selected)) {
                      return HmiColors.accent;
                    }

                    return HmiColors.panelAlt;
                  },
                ),
              ),

              tooltipTheme: TooltipThemeData(
                decoration: BoxDecoration(
                  color: HmiColors.panelAlt,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                    color: HmiColors.border,
                  ),
                ),
                textStyle: const TextStyle(
                  color: HmiColors.text,
                  fontSize: 11,
                ),
              ),

              scrollbarTheme: ScrollbarThemeData(
                thumbColor: WidgetStateProperty.all(
                  HmiColors.border,
                ),
                trackColor: WidgetStateProperty.all(
                  HmiColors.panel,
                ),
                radius: const Radius.circular(4),
                thickness: WidgetStateProperty.all(5),
              ),
            ),

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