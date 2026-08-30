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

            // ==========================================================
            // GLOBAL THEME
            // ==========================================================

            theme: ThemeData(
              useMaterial3: true,
              brightness: Brightness.dark,

              scaffoldBackgroundColor: HmiColors.bg,
              canvasColor: HmiColors.bg,

              colorScheme: const ColorScheme.dark(
                primary: HmiColors.accent,
                onPrimary: HmiColors.bg,
                primaryContainer: HmiColors.accentSurface,
                onPrimaryContainer: HmiColors.accentStrong,
                secondary: HmiColors.dro,
                onSecondary: HmiColors.bg,
                secondaryContainer: HmiColors.panelAlt,
                onSecondaryContainer: HmiColors.text,
                surface: HmiColors.panel,
                onSurface: HmiColors.text,
                surfaceContainerHighest: HmiColors.panelAlt,
                outline: HmiColors.border,
                outlineVariant: HmiColors.divider,
                error: HmiColors.alarm,
                onError: HmiColors.textOnDark,
              ),

              // ========================================================
              // TYPOGRAPHY
              // ========================================================

              textTheme: const TextTheme(
                displayLarge: TextStyle(
                  color: HmiColors.text,
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                ),
                displayMedium: TextStyle(
                  color: HmiColors.text,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                ),
                headlineLarge: TextStyle(
                  color: HmiColors.text,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                ),
                headlineMedium: TextStyle(
                  color: HmiColors.text,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
                headlineSmall: TextStyle(
                  color: HmiColors.text,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
                titleLarge: TextStyle(
                  color: HmiColors.text,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
                titleMedium: TextStyle(
                  color: HmiColors.text,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.15,
                ),
                titleSmall: TextStyle(
                  color: HmiColors.textDim,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
                bodyLarge: TextStyle(
                  color: HmiColors.text,
                  fontSize: 14,
                  height: 1.35,
                ),
                bodyMedium: TextStyle(
                  color: HmiColors.textDim,
                  fontSize: 13,
                  height: 1.35,
                ),
                bodySmall: TextStyle(
                  color: HmiColors.textMute,
                  fontSize: 11,
                  height: 1.3,
                ),
                labelLarge: TextStyle(
                  color: HmiColors.text,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.25,
                ),
                labelMedium: TextStyle(
                  color: HmiColors.textDim,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
                labelSmall: TextStyle(
                  color: HmiColors.textMute,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),

              // ========================================================
              // APP BAR
              // ========================================================

              appBarTheme: const AppBarTheme(
                backgroundColor: HmiColors.panel,
                foregroundColor: HmiColors.text,
                elevation: 0,
                scrolledUnderElevation: 0,
                surfaceTintColor: Colors.transparent,
                centerTitle: false,
                toolbarHeight: 56,
              ),

              // ========================================================
              // DIVIDERS
              // ========================================================

              dividerTheme: const DividerThemeData(
                color: HmiColors.divider,
                thickness: 1,
                space: 1,
              ),

              // ========================================================
              // ICONS
              // ========================================================

              iconTheme: const IconThemeData(
                color: HmiColors.textDim,
                size: 20,
              ),

              // ========================================================
              // CARDS
              // ========================================================

              cardTheme: CardThemeData(
                color: HmiColors.panel,
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                margin: EdgeInsets.zero,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    HmiColors.radiusMedium,
                  ),
                  side: const BorderSide(
                    color: HmiColors.border,
                    width: HmiColors.borderThin,
                  ),
                ),
              ),

              // ========================================================
              // ELEVATED BUTTONS
              // ========================================================

              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ButtonStyle(
                  backgroundColor:
                      WidgetStateProperty.resolveWith<Color>((states) {
                    if (states.contains(WidgetState.disabled)) {
                      return HmiColors.softkeyDisabled;
                    }

                    if (states.contains(WidgetState.pressed)) {
                      return HmiColors.softkeyActive;
                    }

                    if (states.contains(WidgetState.hovered)) {
                      return HmiColors.softkeyHover;
                    }

                    return HmiColors.softkey;
                  }),
                  foregroundColor:
                      WidgetStateProperty.resolveWith<Color>((states) {
                    if (states.contains(WidgetState.disabled)) {
                      return HmiColors.textDisabled;
                    }

                    return HmiColors.text;
                  }),
                  overlayColor: WidgetStateProperty.all(
                    HmiColors.accent.withValues(alpha: 0.08),
                  ),
                  elevation:
                      WidgetStateProperty.resolveWith<double>((states) {
                    if (states.contains(WidgetState.pressed)) {
                      return 0;
                    }

                    if (states.contains(WidgetState.hovered)) {
                      return 2;
                    }

                    return 0;
                  }),
                  padding: WidgetStateProperty.all(
                    const EdgeInsets.symmetric(
                      horizontal: HmiColors.space4,
                      vertical: HmiColors.space3,
                    ),
                  ),
                  minimumSize: WidgetStateProperty.all(
                    const Size(100, 44),
                  ),
                  shape: WidgetStateProperty.all(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        HmiColors.radiusMedium,
                      ),
                      side: const BorderSide(
                        color: HmiColors.border,
                        width: HmiColors.borderThin,
                      ),
                    ),
                  ),
                  textStyle: WidgetStateProperty.all(
                    const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                  animationDuration: HmiColors.motionStandard,
                ),
              ),

              // ========================================================
              // OUTLINED BUTTONS
              // ========================================================

              outlinedButtonTheme: OutlinedButtonThemeData(
                style: ButtonStyle(
                  foregroundColor:
                      WidgetStateProperty.resolveWith<Color>((states) {
                    if (states.contains(WidgetState.disabled)) {
                      return HmiColors.textDisabled;
                    }

                    return HmiColors.text;
                  }),
                  backgroundColor:
                      WidgetStateProperty.resolveWith<Color>((states) {
                    if (states.contains(WidgetState.pressed)) {
                      return HmiColors.softkeyActive;
                    }

                    if (states.contains(WidgetState.hovered)) {
                      return HmiColors.surfaceHover;
                    }

                    return Colors.transparent;
                  }),
                  overlayColor: WidgetStateProperty.all(
                    HmiColors.accent.withValues(alpha: 0.07),
                  ),
                  side: WidgetStateProperty.resolveWith<BorderSide>((states) {
                    if (states.contains(WidgetState.disabled)) {
                      return const BorderSide(
                        color: HmiColors.textDisabled,
                        width: HmiColors.borderThin,
                      );
                    }

                    if (states.contains(WidgetState.focused) ||
                        states.contains(WidgetState.pressed)) {
                      return const BorderSide(
                        color: HmiColors.accent,
                        width: HmiColors.borderMedium,
                      );
                    }

                    if (states.contains(WidgetState.hovered)) {
                      return const BorderSide(
                        color: HmiColors.borderStrong,
                        width: HmiColors.borderThin,
                      );
                    }

                    return const BorderSide(
                      color: HmiColors.border,
                      width: HmiColors.borderThin,
                    );
                  }),
                  padding: WidgetStateProperty.all(
                    const EdgeInsets.symmetric(
                      horizontal: HmiColors.space4,
                      vertical: HmiColors.space3,
                    ),
                  ),
                  minimumSize: WidgetStateProperty.all(
                    const Size(100, 44),
                  ),
                  shape: WidgetStateProperty.all(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        HmiColors.radiusMedium,
                      ),
                    ),
                  ),
                  textStyle: WidgetStateProperty.all(
                    const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                  animationDuration: HmiColors.motionStandard,
                ),
              ),

              // ========================================================
              // TEXT BUTTONS
              // ========================================================

              textButtonTheme: TextButtonThemeData(
                style: ButtonStyle(
                  foregroundColor:
                      WidgetStateProperty.resolveWith<Color>((states) {
                    if (states.contains(WidgetState.disabled)) {
                      return HmiColors.textDisabled;
                    }

                    if (states.contains(WidgetState.pressed)) {
                      return HmiColors.accentStrong;
                    }

                    return HmiColors.textDim;
                  }),
                  overlayColor: WidgetStateProperty.all(
                    HmiColors.accent.withValues(alpha: 0.07),
                  ),
                  padding: WidgetStateProperty.all(
                    const EdgeInsets.symmetric(
                      horizontal: HmiColors.space3,
                      vertical: HmiColors.space2,
                    ),
                  ),
                  shape: WidgetStateProperty.all(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        HmiColors.radiusSmall,
                      ),
                    ),
                  ),
                  textStyle: WidgetStateProperty.all(
                    const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  animationDuration: HmiColors.motionFast,
                ),
              ),

              // ========================================================
              // INPUTS
              // ========================================================

              inputDecorationTheme: InputDecorationTheme(
                filled: true,
                fillColor: HmiColors.panelAlt,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: HmiColors.space3,
                  vertical: HmiColors.space3,
                ),
                labelStyle: const TextStyle(
                  color: HmiColors.textDim,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                floatingLabelStyle: const TextStyle(
                  color: HmiColors.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
                hintStyle: const TextStyle(
                  color: HmiColors.textMute,
                  fontSize: 13,
                ),
                prefixIconColor: HmiColors.textDim,
                suffixIconColor: HmiColors.textDim,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                    HmiColors.radiusMedium,
                  ),
                  borderSide: const BorderSide(
                    color: HmiColors.border,
                    width: HmiColors.borderThin,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                    HmiColors.radiusMedium,
                  ),
                  borderSide: const BorderSide(
                    color: HmiColors.accent,
                    width: HmiColors.borderMedium,
                  ),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                    HmiColors.radiusMedium,
                  ),
                  borderSide: const BorderSide(
                    color: HmiColors.alarm,
                    width: HmiColors.borderThin,
                  ),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                    HmiColors.radiusMedium,
                  ),
                  borderSide: const BorderSide(
                    color: HmiColors.alarm,
                    width: HmiColors.borderMedium,
                  ),
                ),
                disabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                    HmiColors.radiusMedium,
                  ),
                  borderSide: const BorderSide(
                    color: HmiColors.divider,
                    width: HmiColors.borderThin,
                  ),
                ),
              ),

              // ========================================================
              // SLIDER
              // ========================================================

              sliderTheme: SliderThemeData(
                activeTrackColor: HmiColors.accent,
                inactiveTrackColor: HmiColors.border,
                secondaryActiveTrackColor: HmiColors.accentStrong,
                thumbColor: HmiColors.accent,
                overlayColor: HmiColors.accent.withValues(alpha: 0.10),
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 6,
                ),
                overlayShape: const RoundSliderOverlayShape(
                  overlayRadius: 16,
                ),
              ),

              // ========================================================
              // CHECKBOX
              // ========================================================

              checkboxTheme: CheckboxThemeData(
                fillColor: WidgetStateProperty.resolveWith<Color>((states) {
                  if (states.contains(WidgetState.disabled)) {
                    return HmiColors.softkeyDisabled;
                  }

                  if (states.contains(WidgetState.selected)) {
                    return HmiColors.accent;
                  }

                  return HmiColors.panelAlt;
                }),
                checkColor: WidgetStateProperty.all(HmiColors.bg),
                side: const BorderSide(
                  color: HmiColors.borderStrong,
                  width: HmiColors.borderThin,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    HmiColors.radiusSmall,
                  ),
                ),
              ),

              // ========================================================
              // SWITCH
              // ========================================================

              switchTheme: SwitchThemeData(
                thumbColor:
                    WidgetStateProperty.resolveWith<Color>((states) {
                  if (states.contains(WidgetState.selected)) {
                    return HmiColors.text;
                  }

                  return HmiColors.textMute;
                }),
                trackColor:
                    WidgetStateProperty.resolveWith<Color>((states) {
                  if (states.contains(WidgetState.selected)) {
                    return HmiColors.accent;
                  }

                  return HmiColors.panelAlt;
                }),
                trackOutlineColor:
                    WidgetStateProperty.resolveWith<Color>((states) {
                  if (states.contains(WidgetState.selected)) {
                    return HmiColors.borderAccent;
                  }

                  return HmiColors.border;
                }),
              ),

              // ========================================================
              // TOOLTIP
              // ========================================================

              tooltipTheme: TooltipThemeData(
                waitDuration: const Duration(milliseconds: 450),
                showDuration: const Duration(seconds: 3),
                padding: const EdgeInsets.symmetric(
                  horizontal: HmiColors.space3,
                  vertical: HmiColors.space2,
                ),
                decoration: BoxDecoration(
                  color: HmiColors.panelElevated,
                  borderRadius: BorderRadius.circular(
                    HmiColors.radiusSmall,
                  ),
                  border: Border.all(
                    color: HmiColors.border,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: HmiColors.shadow,
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                textStyle: const TextStyle(
                  color: HmiColors.text,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),

              // ========================================================
              // SCROLLBARS
              // ========================================================

              scrollbarTheme: ScrollbarThemeData(
                thumbColor: WidgetStateProperty.resolveWith<Color>((states) {
                  if (states.contains(WidgetState.hovered)) {
                    return HmiColors.borderStrong;
                  }

                  return HmiColors.border;
                }),
                trackColor: WidgetStateProperty.all(
                  HmiColors.panel,
                ),
                radius: const Radius.circular(
                  HmiColors.radiusSmall,
                ),
                thickness: WidgetStateProperty.all(5),
                minThumbLength: 36,
              ),

              // ========================================================
              // FOCUS
              // ========================================================

              focusColor: HmiColors.accent.withValues(alpha: 0.08),
              hoverColor: HmiColors.accent.withValues(alpha: 0.06),
              splashColor: HmiColors.accent.withValues(alpha: 0.10),
            ),

            // ============================================================
            // GLOBAL DIRECTION
            // ============================================================

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